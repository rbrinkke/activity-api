-- ============================================================================
-- ACTIVITY GET/UPDATE/CANCEL/DELETE STORED PROCEDURES
-- ============================================================================

-- SP 2: Get Activity by ID
CREATE OR REPLACE FUNCTION activity.sp_get_activity_by_id(
    p_activity_id UUID,
    p_requesting_user_id UUID
)
RETURNS TABLE (
    activity_id UUID,
    organizer_user_id UUID,
    organizer_username VARCHAR(100),
    organizer_first_name VARCHAR(100),
    organizer_main_photo_url VARCHAR(500),
    organizer_is_verified BOOLEAN,
    category_id UUID,
    category_name VARCHAR(100),
    title VARCHAR(255),
    description TEXT,
    activity_type activity.activity_type,
    activity_privacy_level activity.activity_privacy_level,
    status activity.activity_status,
    scheduled_at TIMESTAMP WITH TIME ZONE,
    duration_minutes INT,
    joinable_at_free TIMESTAMP WITH TIME ZONE,
    max_participants INT,
    current_participants_count INT,
    waitlist_count INT,
    location JSONB,
    tags TEXT[],
    language VARCHAR(5),
    external_chat_id VARCHAR(255),
    created_at TIMESTAMP WITH TIME ZONE,
    updated_at TIMESTAMP WITH TIME ZONE,
    completed_at TIMESTAMP WITH TIME ZONE,
    cancelled_at TIMESTAMP WITH TIME ZONE,
    user_participation_status VARCHAR(50),
    user_can_join BOOLEAN,
    user_can_edit BOOLEAN,
    is_blocked BOOLEAN
) AS $$
DECLARE
    v_activity RECORD;
    v_is_blocked BOOLEAN := FALSE;
    v_user_participation_status VARCHAR(50) := 'not_participating';
    v_user_can_join BOOLEAN := FALSE;
    v_user_can_edit BOOLEAN := FALSE;
    v_tags_array TEXT[];
BEGIN
    -- 1. VALIDATION
    -- Check if activity exists
    SELECT a.* INTO v_activity
    FROM activity.activities a
    WHERE a.activity_id = p_activity_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'ERR_NOT_FOUND_ACTIVITY' USING ERRCODE = '42704';
    END IF;

    -- 2. BLOCKING CHECK (both directions, except XXL)
    IF v_activity.activity_type != 'xxl' THEN
        IF EXISTS (
            SELECT 1 FROM activity.user_blocks
            WHERE (blocker_user_id = v_activity.organizer_user_id AND blocked_user_id = p_requesting_user_id)
               OR (blocker_user_id = p_requesting_user_id AND blocked_user_id = v_activity.organizer_user_id)
        ) THEN
            v_is_blocked := TRUE;
        END IF;
    END IF;

    -- 3. PRIVACY LEVEL CHECK
    IF v_activity.activity_privacy_level = 'friends_only' AND NOT v_is_blocked THEN
        -- Check if requesting user is friend of organizer
        IF NOT EXISTS (
            SELECT 1 FROM activity.friendships
            WHERE ((user_id_1 = v_activity.organizer_user_id AND user_id_2 = p_requesting_user_id)
                OR (user_id_1 = p_requesting_user_id AND user_id_2 = v_activity.organizer_user_id))
              AND status = 'accepted'
        ) THEN
            -- Not a friend - check if user is already a participant
            IF NOT EXISTS (
                SELECT 1 FROM activity.participants
                WHERE activity_id = p_activity_id AND user_id = p_requesting_user_id
            ) THEN
                RAISE EXCEPTION 'ERR_FORBIDDEN_FRIENDS_ONLY' USING ERRCODE = '42501';
            END IF;
        END IF;
    END IF;

    IF v_activity.activity_privacy_level = 'invite_only' AND NOT v_is_blocked THEN
        -- Check if user has invitation
        IF NOT EXISTS (
            SELECT 1 FROM activity.activity_invitations
            WHERE activity_id = p_activity_id
              AND user_id = p_requesting_user_id
              AND status = 'accepted'
        ) THEN
            -- No invitation - check if user is already a participant
            IF NOT EXISTS (
                SELECT 1 FROM activity.participants
                WHERE activity_id = p_activity_id AND user_id = p_requesting_user_id
            ) THEN
                RAISE EXCEPTION 'ERR_FORBIDDEN_INVITE_ONLY' USING ERRCODE = '42501';
            END IF;
        END IF;
    END IF;

    -- 4. CHECK USER PARTICIPATION
    SELECT p.participation_status INTO v_user_participation_status
    FROM activity.participants p
    WHERE p.activity_id = p_activity_id AND p.user_id = p_requesting_user_id;

    IF NOT FOUND THEN
        v_user_participation_status := 'not_participating';
    END IF;

    -- 5. CHECK IF USER CAN EDIT
    IF EXISTS (
        SELECT 1 FROM activity.participants
        WHERE activity_id = p_activity_id
          AND user_id = p_requesting_user_id
          AND role IN ('organizer', 'co_organizer')
    ) THEN
        v_user_can_edit := TRUE;
    END IF;

    -- 6. CHECK IF USER CAN JOIN
    IF v_activity.status = 'published'
       AND v_activity.scheduled_at > NOW()
       AND v_user_participation_status = 'not_participating'
       AND v_activity.current_participants_count < v_activity.max_participants
       AND NOT v_is_blocked
    THEN
        v_user_can_join := TRUE;
    END IF;

    -- Build tags array
    SELECT ARRAY_AGG(tag) INTO v_tags_array
    FROM activity.activity_tags
    WHERE activity_tags.activity_id = p_activity_id;

    -- 7. RETURN
    RETURN QUERY
    SELECT
        v_activity.activity_id,
        v_activity.organizer_user_id,
        u.username,
        u.first_name,
        u.main_photo_url,
        u.is_verified,
        v_activity.category_id,
        c.name as category_name,
        v_activity.title,
        v_activity.description,
        v_activity.activity_type,
        v_activity.activity_privacy_level,
        v_activity.status,
        v_activity.scheduled_at,
        v_activity.duration_minutes,
        v_activity.joinable_at_free,
        v_activity.max_participants,
        v_activity.current_participants_count,
        v_activity.waitlist_count,
        -- Location as JSONB
        (
            SELECT row_to_json(l.*)::JSONB
            FROM activity.activity_locations l
            WHERE l.activity_id = v_activity.activity_id
        ) as location,
        -- Tags
        COALESCE(v_tags_array, ARRAY[]::TEXT[]) as tags,
        v_activity.language,
        v_activity.external_chat_id,
        v_activity.created_at,
        v_activity.updated_at,
        v_activity.completed_at,
        v_activity.cancelled_at,
        v_user_participation_status,
        v_user_can_join,
        v_user_can_edit,
        v_is_blocked
    FROM activity.users u
    LEFT JOIN activity.categories c ON c.category_id = v_activity.category_id
    WHERE u.user_id = v_activity.organizer_user_id;

EXCEPTION
    WHEN OTHERS THEN
        RAISE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION activity.sp_get_activity_by_id IS 'Get activity by ID with user-specific permissions, blocking check, and privacy enforcement';


-- SP 3: Update Activity
CREATE OR REPLACE FUNCTION activity.sp_update_activity(
    p_activity_id UUID,
    p_user_id UUID,
    p_category_id UUID,
    p_title VARCHAR(255),
    p_description TEXT,
    p_activity_type activity.activity_type,
    p_activity_privacy_level activity.activity_privacy_level,
    p_scheduled_at TIMESTAMP WITH TIME ZONE,
    p_duration_minutes INT,
    p_joinable_at_free TIMESTAMP WITH TIME ZONE,
    p_max_participants INT,
    p_language VARCHAR(5),
    p_external_chat_id VARCHAR(255),
    -- Location parameters
    p_venue_name VARCHAR(255),
    p_address_line1 VARCHAR(255),
    p_address_line2 VARCHAR(255),
    p_city VARCHAR(100),
    p_state_province VARCHAR(100),
    p_postal_code VARCHAR(20),
    p_country VARCHAR(100),
    p_latitude DECIMAL(10, 8),
    p_longitude DECIMAL(11, 8),
    p_place_id VARCHAR(255),
    p_tags JSONB
)
RETURNS TABLE (
    activity_id UUID,
    title VARCHAR(255),
    description TEXT,
    scheduled_at TIMESTAMP WITH TIME ZONE,
    updated_at TIMESTAMP WITH TIME ZONE
) AS $$
DECLARE
    v_activity RECORD;
    v_location_exists BOOLEAN;
BEGIN
    -- 1. VALIDATION
    -- Check if activity exists
    SELECT * INTO v_activity
    FROM activity.activities a
    WHERE a.activity_id = p_activity_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'ERR_NOT_FOUND_ACTIVITY' USING ERRCODE = '42704';
    END IF;

    -- Check if activity is not cancelled or completed
    IF v_activity.status IN ('cancelled', 'completed') THEN
        RAISE EXCEPTION 'ERR_FORBIDDEN_ACTIVITY_CLOSED' USING ERRCODE = '42501';
    END IF;

    -- Check if user is organizer or co-organizer
    IF NOT EXISTS (
        SELECT 1 FROM activity.participants
        WHERE activity_id = p_activity_id
          AND user_id = p_user_id
          AND role IN ('organizer', 'co_organizer')
    ) THEN
        RAISE EXCEPTION 'ERR_FORBIDDEN_NOT_ORGANIZER' USING ERRCODE = '42501';
    END IF;

    -- Validate scheduled_at if provided
    IF p_scheduled_at IS NOT NULL AND p_scheduled_at <= NOW() THEN
        RAISE EXCEPTION 'ERR_SCHEDULED_AT_PAST' USING ERRCODE = '22000';
    END IF;

    -- Validate max_participants if provided
    IF p_max_participants IS NOT NULL THEN
        IF p_max_participants < v_activity.current_participants_count THEN
            RAISE EXCEPTION 'ERR_CANNOT_REDUCE_PARTICIPANTS' USING ERRCODE = '22000';
        END IF;
        IF p_max_participants < 2 OR p_max_participants > 1000 THEN
            RAISE EXCEPTION 'ERR_INVALID_MAX_PARTICIPANTS' USING ERRCODE = '22000';
        END IF;
    END IF;

    -- Validate category if provided
    IF p_category_id IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM activity.categories
        WHERE category_id = p_category_id AND is_active = TRUE
    ) THEN
        RAISE EXCEPTION 'ERR_CATEGORY_NOT_FOUND' USING ERRCODE = '42704';
    END IF;

    -- 2. UPDATE ACTIVITY
    UPDATE activity.activities
    SET
        category_id = COALESCE(p_category_id, category_id),
        title = COALESCE(p_title, title),
        description = COALESCE(p_description, description),
        activity_type = COALESCE(p_activity_type, activity_type),
        activity_privacy_level = COALESCE(p_activity_privacy_level, activity_privacy_level),
        scheduled_at = COALESCE(p_scheduled_at, scheduled_at),
        duration_minutes = COALESCE(p_duration_minutes, duration_minutes),
        joinable_at_free = COALESCE(p_joinable_at_free, joinable_at_free),
        max_participants = COALESCE(p_max_participants, max_participants),
        language = COALESCE(p_language, language),
        external_chat_id = COALESCE(p_external_chat_id, external_chat_id),
        location_name = COALESCE(p_venue_name, location_name),
        city = COALESCE(p_city, city),
        updated_at = NOW()
    WHERE activities.activity_id = p_activity_id;

    -- 3. UPDATE/INSERT LOCATION
    IF p_venue_name IS NOT NULL OR p_latitude IS NOT NULL THEN
        -- Check if location exists
        SELECT EXISTS (
            SELECT 1 FROM activity.activity_locations
            WHERE activity_locations.activity_id = p_activity_id
        ) INTO v_location_exists;

        IF v_location_exists THEN
            -- Update existing location
            UPDATE activity.activity_locations
            SET
                venue_name = COALESCE(p_venue_name, venue_name),
                address_line1 = COALESCE(p_address_line1, address_line1),
                address_line2 = COALESCE(p_address_line2, address_line2),
                city = COALESCE(p_city, city),
                state_province = COALESCE(p_state_province, state_province),
                postal_code = COALESCE(p_postal_code, postal_code),
                country = COALESCE(p_country, country),
                latitude = COALESCE(p_latitude, latitude),
                longitude = COALESCE(p_longitude, longitude),
                place_id = COALESCE(p_place_id, place_id),
                updated_at = NOW()
            WHERE activity_locations.activity_id = p_activity_id;
        ELSE
            -- Insert new location
            INSERT INTO activity.activity_locations (
                activity_id, venue_name, address_line1, address_line2,
                city, state_province, postal_code, country,
                latitude, longitude, place_id
            ) VALUES (
                p_activity_id, p_venue_name, p_address_line1, p_address_line2,
                p_city, p_state_province, p_postal_code, p_country,
                p_latitude, p_longitude, p_place_id
            );
        END IF;
    END IF;

    -- 4. UPDATE TAGS if provided
    IF p_tags IS NOT NULL THEN
        -- Delete existing tags
        DELETE FROM activity.activity_tags WHERE activity_tags.activity_id = p_activity_id;

        -- Insert new tags
        IF jsonb_array_length(p_tags) > 0 THEN
            INSERT INTO activity.activity_tags (activity_id, tag)
            SELECT p_activity_id, jsonb_array_elements_text(p_tags);
        END IF;
    END IF;

    -- 5. RETURN
    RETURN QUERY
    SELECT
        a.activity_id,
        a.title,
        a.description,
        a.scheduled_at,
        a.updated_at
    FROM activity.activities a
    WHERE a.activity_id = p_activity_id;

EXCEPTION
    WHEN OTHERS THEN
        RAISE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION activity.sp_update_activity IS 'Update activity details (organizer/co-organizer only)';


-- SP 4: Cancel Activity
CREATE OR REPLACE FUNCTION activity.sp_cancel_activity(
    p_activity_id UUID,
    p_user_id UUID,
    p_cancellation_reason TEXT
)
RETURNS TABLE (
    activity_id UUID,
    status activity.activity_status,
    cancelled_at TIMESTAMP WITH TIME ZONE,
    participants_notified_count INT
) AS $$
DECLARE
    v_activity RECORD;
    v_participants_count INT;
BEGIN
    -- 1. VALIDATION
    SELECT * INTO v_activity
    FROM activity.activities
    WHERE activities.activity_id = p_activity_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'ERR_NOT_FOUND_ACTIVITY' USING ERRCODE = '42704';
    END IF;

    -- Check if activity is published
    IF v_activity.status != 'published' THEN
        RAISE EXCEPTION 'ERR_FORBIDDEN_ACTIVITY_NOT_PUBLISHED' USING ERRCODE = '42501';
    END IF;

    -- Check if user is organizer
    IF NOT EXISTS (
        SELECT 1 FROM activity.participants
        WHERE activity_id = p_activity_id
          AND user_id = p_user_id
          AND role = 'organizer'
    ) THEN
        RAISE EXCEPTION 'ERR_FORBIDDEN_NOT_ORGANIZER' USING ERRCODE = '42501';
    END IF;

    -- Check if activity is in the past
    IF v_activity.scheduled_at < NOW() THEN
        RAISE EXCEPTION 'ERR_CANNOT_CANCEL_PAST_ACTIVITY' USING ERRCODE = '22000';
    END IF;

    -- 2. CANCEL ACTIVITY
    UPDATE activity.activities
    SET
        status = 'cancelled',
        cancelled_at = NOW()
    WHERE activities.activity_id = p_activity_id;

    -- Update all participants
    UPDATE activity.participants
    SET participation_status = 'cancelled'
    WHERE participants.activity_id = p_activity_id;

    -- Count participants for notification
    SELECT COUNT(*) INTO v_participants_count
    FROM activity.participants
    WHERE participants.activity_id = p_activity_id
      AND user_id != p_user_id;  -- Exclude organizer

    -- 3. RETURN
    RETURN QUERY
    SELECT
        p_activity_id,
        'cancelled'::activity.activity_status,
        NOW(),
        v_participants_count;

EXCEPTION
    WHEN OTHERS THEN
        RAISE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION activity.sp_cancel_activity IS 'Cancel activity and notify all participants (organizer only)';


-- SP 5: Delete Activity
CREATE OR REPLACE FUNCTION activity.sp_delete_activity(
    p_activity_id UUID,
    p_user_id UUID
)
RETURNS TABLE (
    deleted BOOLEAN,
    message TEXT
) AS $$
DECLARE
    v_activity RECORD;
BEGIN
    -- 1. VALIDATION
    SELECT * INTO v_activity
    FROM activity.activities
    WHERE activities.activity_id = p_activity_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'ERR_NOT_FOUND_ACTIVITY' USING ERRCODE = '42704';
    END IF;

    -- Check if user is organizer
    IF v_activity.organizer_user_id != p_user_id THEN
        RAISE EXCEPTION 'ERR_FORBIDDEN_NOT_ORGANIZER' USING ERRCODE = '42501';
    END IF;

    -- Check if only organizer is participant
    IF v_activity.current_participants_count > 1 THEN
        RAISE EXCEPTION 'ERR_CANNOT_DELETE_WITH_PARTICIPANTS' USING ERRCODE = '42501';
    END IF;

    -- 2. DELETE ACTIVITY (CASCADE will handle related records)
    DELETE FROM activity.activities WHERE activities.activity_id = p_activity_id;

    -- Decrement activities_created_count
    UPDATE activity.users
    SET activities_created_count = activities_created_count - 1
    WHERE users.user_id = p_user_id;

    -- 3. RETURN
    RETURN QUERY
    SELECT TRUE, 'Activity deleted successfully'::TEXT;

EXCEPTION
    WHEN OTHERS THEN
        RAISE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION activity.sp_delete_activity IS 'Delete activity (only if no other participants besides organizer)';
