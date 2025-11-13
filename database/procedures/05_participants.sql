-- ============================================================================
-- PARTICIPANT STORED PROCEDURES
-- ============================================================================

-- SP 1: List Participants
CREATE OR REPLACE FUNCTION activity.sp_list_participants(
    p_activity_id UUID,
    p_requesting_user_id UUID
)
RETURNS TABLE (
    activity_id UUID,
    total_participants INT,
    max_participants INT,
    user_id UUID,
    username VARCHAR(100),
    first_name VARCHAR(100),
    main_photo_url VARCHAR(500),
    is_verified BOOLEAN,
    role activity.participant_role,
    participation_status activity.participation_status,
    attendance_status activity.attendance_status,
    joined_at TIMESTAMP WITH TIME ZONE
) AS $$
DECLARE
    v_activity RECORD;
    v_is_blocked BOOLEAN := FALSE;
BEGIN
    -- 1. VALIDATION
    -- Check if activity exists
    SELECT * INTO v_activity
    FROM activity.activities a
    WHERE a.activity_id = p_activity_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'ERR_NOT_FOUND_ACTIVITY' USING ERRCODE = '42704';
    END IF;

    -- 2. BLOCKING CHECK (except XXL)
    IF v_activity.activity_type != 'xxl' THEN
        IF EXISTS (
            SELECT 1 FROM activity.user_blocks
            WHERE (blocker_user_id = v_activity.organizer_user_id AND blocked_user_id = p_requesting_user_id)
               OR (blocker_user_id = p_requesting_user_id AND blocked_user_id = v_activity.organizer_user_id)
        ) THEN
            v_is_blocked := TRUE;
        END IF;

        IF v_is_blocked THEN
            RAISE EXCEPTION 'ERR_FORBIDDEN_BLOCKED' USING ERRCODE = '42501';
        END IF;
    END IF;

    -- 3. PRIVACY CHECK
    IF v_activity.activity_privacy_level = 'friends_only' THEN
        IF NOT EXISTS (
            SELECT 1 FROM activity.friendships
            WHERE ((user_id_1 = v_activity.organizer_user_id AND user_id_2 = p_requesting_user_id)
                OR (user_id_1 = p_requesting_user_id AND user_id_2 = v_activity.organizer_user_id))
              AND status = 'accepted'
        ) THEN
            -- Not a friend - check if user is participant
            IF NOT EXISTS (
                SELECT 1 FROM activity.participants
                WHERE activity_id = p_activity_id AND user_id = p_requesting_user_id
            ) THEN
                RAISE EXCEPTION 'ERR_FORBIDDEN_FRIENDS_ONLY' USING ERRCODE = '42501';
            END IF;
        END IF;
    END IF;

    IF v_activity.activity_privacy_level = 'invite_only' THEN
        IF NOT EXISTS (
            SELECT 1 FROM activity.activity_invitations
            WHERE activity_id = p_activity_id
              AND user_id = p_requesting_user_id
              AND status = 'accepted'
        ) THEN
            -- No invitation - check if user is participant
            IF NOT EXISTS (
                SELECT 1 FROM activity.participants
                WHERE activity_id = p_activity_id AND user_id = p_requesting_user_id
            ) THEN
                RAISE EXCEPTION 'ERR_FORBIDDEN_INVITE_ONLY' USING ERRCODE = '42501';
            END IF;
        END IF;
    END IF;

    -- 4. RETURN PARTICIPANTS
    RETURN QUERY
    SELECT
        p_activity_id,
        v_activity.current_participants_count,
        v_activity.max_participants,
        u.user_id,
        u.username,
        u.first_name,
        u.main_photo_url,
        u.is_verified,
        p.role,
        p.participation_status,
        p.attendance_status,
        p.joined_at
    FROM activity.participants p
    JOIN activity.users u ON u.user_id = p.user_id
    WHERE p.activity_id = p_activity_id
      AND p.participation_status = 'registered'
    ORDER BY
        CASE p.role
            WHEN 'organizer' THEN 1
            WHEN 'co_organizer' THEN 2
            ELSE 3
        END,
        p.joined_at ASC;

EXCEPTION
    WHEN OTHERS THEN
        RAISE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION activity.sp_list_participants IS 'List all registered participants with privacy and blocking checks';


-- SP 2: Get Waitlist
CREATE OR REPLACE FUNCTION activity.sp_get_waitlist(
    p_activity_id UUID,
    p_requesting_user_id UUID
)
RETURNS TABLE (
    activity_id UUID,
    total_waitlist INT,
    user_id UUID,
    username VARCHAR(100),
    first_name VARCHAR(100),
    main_photo_url VARCHAR(500),
    is_verified BOOLEAN,
    position INT,
    created_at TIMESTAMP WITH TIME ZONE,
    notified_at TIMESTAMP WITH TIME ZONE
) AS $$
DECLARE
    v_activity RECORD;
    v_is_organizer BOOLEAN := FALSE;
BEGIN
    -- 1. VALIDATION
    -- Check if activity exists
    SELECT * INTO v_activity
    FROM activity.activities a
    WHERE a.activity_id = p_activity_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'ERR_NOT_FOUND_ACTIVITY' USING ERRCODE = '42704';
    END IF;

    -- 2. AUTHORIZATION CHECK
    -- Only organizer and co-organizers can view waitlist
    SELECT EXISTS (
        SELECT 1 FROM activity.participants
        WHERE activity_id = p_activity_id
          AND user_id = p_requesting_user_id
          AND role IN ('organizer', 'co_organizer')
    ) INTO v_is_organizer;

    IF NOT v_is_organizer THEN
        RAISE EXCEPTION 'ERR_FORBIDDEN_NOT_ORGANIZER' USING ERRCODE = '42501';
    END IF;

    -- 3. RETURN WAITLIST
    RETURN QUERY
    SELECT
        p_activity_id,
        v_activity.waitlist_count,
        u.user_id,
        u.username,
        u.first_name,
        u.main_photo_url,
        u.is_verified,
        w.position,
        w.created_at,
        w.notified_at
    FROM activity.waitlist_entries w
    JOIN activity.users u ON u.user_id = w.user_id
    WHERE w.activity_id = p_activity_id
    ORDER BY w.position ASC;

EXCEPTION
    WHEN OTHERS THEN
        RAISE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION activity.sp_get_waitlist IS 'Get activity waitlist (organizer/co-organizer only)';
