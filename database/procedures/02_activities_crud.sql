-- ============================================================================
-- ACTIVITY CRUD STORED PROCEDURES
-- ============================================================================

-- SP 1: Create Activity
CREATE OR REPLACE FUNCTION activity.sp_create_activity(
    p_organizer_user_id UUID,
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
    -- Tags as JSONB array
    p_tags JSONB
)
RETURNS TABLE (
    activity_id UUID,
    organizer_user_id UUID,
    category_id UUID,
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
    location_name VARCHAR(255),
    city VARCHAR(100),
    language VARCHAR(5),
    external_chat_id VARCHAR(255),
    created_at TIMESTAMP WITH TIME ZONE,
    location JSONB,
    tags TEXT[]
) AS $$
DECLARE
    v_activity_id UUID;
    v_location_id UUID;
    v_tags_array TEXT[];
BEGIN
    -- 1. VALIDATION
    -- Check user exists and is active
    IF NOT EXISTS (
        SELECT 1 FROM activity.users
        WHERE users.user_id = p_organizer_user_id AND status = 'active'
    ) THEN
        RAISE EXCEPTION 'ERR_USER_NOT_FOUND' USING ERRCODE = '42704';
    END IF;

    -- Check category if provided
    IF p_category_id IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM activity.categories
        WHERE categories.category_id = p_category_id AND is_active = TRUE
    ) THEN
        RAISE EXCEPTION 'ERR_CATEGORY_NOT_FOUND' USING ERRCODE = '42704';
    END IF;

    -- Validate scheduled_at is in the future
    IF p_scheduled_at <= NOW() THEN
        RAISE EXCEPTION 'ERR_SCHEDULED_AT_PAST' USING ERRCODE = '22000';
    END IF;

    -- Validate joinable_at_free is not in the past
    IF p_joinable_at_free IS NOT NULL AND p_joinable_at_free < NOW() THEN
        RAISE EXCEPTION 'ERR_JOINABLE_AT_FREE_PAST' USING ERRCODE = '22000';
    END IF;

    -- Validate max_participants range
    IF p_max_participants < 2 OR p_max_participants > 1000 THEN
        RAISE EXCEPTION 'ERR_INVALID_MAX_PARTICIPANTS' USING ERRCODE = '22000';
    END IF;

    -- Validate tags count
    IF p_tags IS NOT NULL AND jsonb_array_length(p_tags) > 20 THEN
        RAISE EXCEPTION 'ERR_MAX_TAGS_EXCEEDED' USING ERRCODE = '22000';
    END IF;

    -- 2. BUSINESS LOGIC
    -- Insert activity
    INSERT INTO activity.activities (
        organizer_user_id,
        category_id,
        title,
        description,
        activity_type,
        activity_privacy_level,
        scheduled_at,
        duration_minutes,
        joinable_at_free,
        max_participants,
        language,
        external_chat_id,
        status,
        current_participants_count,
        location_name,
        city
    ) VALUES (
        p_organizer_user_id,
        p_category_id,
        p_title,
        p_description,
        p_activity_type,
        p_activity_privacy_level,
        p_scheduled_at,
        p_duration_minutes,
        p_joinable_at_free,
        p_max_participants,
        COALESCE(p_language, 'en'),
        p_external_chat_id,
        'published',
        1,  -- Organizer is first participant
        p_venue_name,
        p_city
    ) RETURNING activities.activity_id INTO v_activity_id;

    -- Insert location if provided
    IF p_venue_name IS NOT NULL OR p_latitude IS NOT NULL THEN
        INSERT INTO activity.activity_locations (
            activity_id,
            venue_name,
            address_line1,
            address_line2,
            city,
            state_province,
            postal_code,
            country,
            latitude,
            longitude,
            place_id
        ) VALUES (
            v_activity_id,
            p_venue_name,
            p_address_line1,
            p_address_line2,
            p_city,
            p_state_province,
            p_postal_code,
            p_country,
            p_latitude,
            p_longitude,
            p_place_id
        ) RETURNING location_id INTO v_location_id;
    END IF;

    -- Insert tags
    IF p_tags IS NOT NULL AND jsonb_array_length(p_tags) > 0 THEN
        INSERT INTO activity.activity_tags (activity_id, tag)
        SELECT v_activity_id, jsonb_array_elements_text(p_tags);
    END IF;

    -- Insert organizer as participant
    INSERT INTO activity.participants (
        activity_id,
        user_id,
        role,
        participation_status
    ) VALUES (
        v_activity_id,
        p_organizer_user_id,
        'organizer',
        'registered'
    );

    -- Increment activities_created_count
    UPDATE activity.users
    SET activities_created_count = activities_created_count + 1
    WHERE users.user_id = p_organizer_user_id;

    -- 3. RETURN
    -- Build tags array
    SELECT ARRAY_AGG(tag) INTO v_tags_array
    FROM activity.activity_tags
    WHERE activity_tags.activity_id = v_activity_id;

    RETURN QUERY
    SELECT
        a.activity_id,
        a.organizer_user_id,
        a.category_id,
        a.title,
        a.description,
        a.activity_type,
        a.activity_privacy_level,
        a.status,
        a.scheduled_at,
        a.duration_minutes,
        a.joinable_at_free,
        a.max_participants,
        a.current_participants_count,
        a.waitlist_count,
        a.location_name,
        a.city,
        a.language,
        a.external_chat_id,
        a.created_at,
        -- Location as JSONB
        (
            SELECT row_to_json(l.*)::JSONB
            FROM activity.activity_locations l
            WHERE l.activity_id = a.activity_id
        ) as location,
        -- Tags as array
        COALESCE(v_tags_array, ARRAY[]::TEXT[]) as tags
    FROM activity.activities a
    WHERE a.activity_id = v_activity_id;

EXCEPTION
    WHEN OTHERS THEN
        RAISE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION activity.sp_create_activity IS 'Create a new activity with location, tags, and automatic organizer participation';
