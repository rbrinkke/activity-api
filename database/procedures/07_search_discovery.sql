-- ============================================================================
-- SEARCH & DISCOVERY STORED PROCEDURES
-- Complex procedures for search, geospatial queries, feed, and recommendations
-- ============================================================================

-- SP 1: Search Activities
CREATE OR REPLACE FUNCTION activity.sp_search_activities(
    p_user_id UUID,
    p_query VARCHAR(255),
    p_category_id UUID,
    p_activity_type activity.activity_type,
    p_city VARCHAR(100),
    p_language VARCHAR(5),
    p_tags JSONB,
    p_date_from TIMESTAMP WITH TIME ZONE,
    p_date_to TIMESTAMP WITH TIME ZONE,
    p_has_spots_available BOOLEAN,
    p_limit INT,
    p_offset INT
)
RETURNS TABLE (
    total_count BIGINT,
    activity_id UUID,
    title VARCHAR(255),
    description TEXT,
    activity_type activity.activity_type,
    scheduled_at TIMESTAMP WITH TIME ZONE,
    duration_minutes INT,
    max_participants INT,
    current_participants_count INT,
    city VARCHAR(100),
    language VARCHAR(5),
    tags TEXT[],
    organizer_username VARCHAR(100),
    organizer_is_verified BOOLEAN,
    category_name VARCHAR(100)
) AS $$
DECLARE
    v_blocked_users UUID[];
    v_user_subscription VARCHAR(50);
    v_total_count BIGINT;
BEGIN
    -- 1. GET USER CONTEXT
    -- Get user subscription level
    SELECT subscription_level INTO v_user_subscription
    FROM activity.users
    WHERE user_id = p_user_id;

    -- Validate language filter (Premium only)
    IF p_language IS NOT NULL AND v_user_subscription NOT IN ('premium', 'club') THEN
        RAISE EXCEPTION 'ERR_PREMIUM_REQUIRED_LANGUAGE_FILTER' USING ERRCODE = '42501';
    END IF;

    -- Get blocked users (both directions)
    v_blocked_users := ARRAY(
        SELECT blocked_user_id FROM activity.user_blocks WHERE blocker_user_id = p_user_id
        UNION
        SELECT blocker_user_id FROM activity.user_blocks WHERE blocked_user_id = p_user_id
    );

    -- 2. SEARCH QUERY
    -- First get total count
    SELECT COUNT(*) INTO v_total_count
    FROM activity.activities a
    WHERE a.status = 'published'
      AND a.scheduled_at > NOW()
      -- Blocking filter (except XXL)
      AND (a.activity_type = 'xxl' OR a.organizer_user_id NOT IN (SELECT unnest(v_blocked_users)))
      -- Text search filter
      AND (p_query IS NULL OR (a.title ILIKE '%' || p_query || '%' OR a.description ILIKE '%' || p_query || '%'))
      -- Category filter
      AND (p_category_id IS NULL OR a.category_id = p_category_id)
      -- Activity type filter
      AND (p_activity_type IS NULL OR a.activity_type = p_activity_type)
      -- City filter
      AND (p_city IS NULL OR a.city ILIKE p_city)
      -- Language filter (Premium only)
      AND (p_language IS NULL OR a.language = p_language)
      -- Date range filters
      AND (p_date_from IS NULL OR a.scheduled_at >= p_date_from)
      AND (p_date_to IS NULL OR a.scheduled_at <= p_date_to)
      -- Spots available filter
      AND (p_has_spots_available IS NULL OR p_has_spots_available = FALSE
           OR a.current_participants_count < a.max_participants)
      -- Tag filter (match any tag)
      AND (p_tags IS NULL OR EXISTS (
          SELECT 1 FROM activity.activity_tags at
          WHERE at.activity_id = a.activity_id
            AND at.tag = ANY(ARRAY(SELECT jsonb_array_elements_text(p_tags)))
      ));

    -- 3. RETURN RESULTS
    RETURN QUERY
    SELECT
        v_total_count,
        a.activity_id,
        a.title,
        a.description,
        a.activity_type,
        a.scheduled_at,
        a.duration_minutes,
        a.max_participants,
        a.current_participants_count,
        a.city,
        a.language,
        ARRAY(
            SELECT tag FROM activity.activity_tags
            WHERE activity_tags.activity_id = a.activity_id
        ) as tags,
        u.username,
        u.is_verified,
        c.name as category_name
    FROM activity.activities a
    JOIN activity.users u ON u.user_id = a.organizer_user_id
    LEFT JOIN activity.categories c ON c.category_id = a.category_id
    WHERE a.status = 'published'
      AND a.scheduled_at > NOW()
      AND (a.activity_type = 'xxl' OR a.organizer_user_id NOT IN (SELECT unnest(v_blocked_users)))
      AND (p_query IS NULL OR (a.title ILIKE '%' || p_query || '%' OR a.description ILIKE '%' || p_query || '%'))
      AND (p_category_id IS NULL OR a.category_id = p_category_id)
      AND (p_activity_type IS NULL OR a.activity_type = p_activity_type)
      AND (p_city IS NULL OR a.city ILIKE p_city)
      AND (p_language IS NULL OR a.language = p_language)
      AND (p_date_from IS NULL OR a.scheduled_at >= p_date_from)
      AND (p_date_to IS NULL OR a.scheduled_at <= p_date_to)
      AND (p_has_spots_available IS NULL OR p_has_spots_available = FALSE
           OR a.current_participants_count < a.max_participants)
      AND (p_tags IS NULL OR EXISTS (
          SELECT 1 FROM activity.activity_tags at
          WHERE at.activity_id = a.activity_id
            AND at.tag = ANY(ARRAY(SELECT jsonb_array_elements_text(p_tags)))
      ))
    ORDER BY a.scheduled_at ASC
    LIMIT p_limit
    OFFSET p_offset;

EXCEPTION
    WHEN OTHERS THEN
        RAISE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION activity.sp_search_activities IS 'Search activities with filters, blocking check, and subscription-based features';


-- SP 2: Nearby Activities (Geospatial)
CREATE OR REPLACE FUNCTION activity.sp_nearby_activities(
    p_user_id UUID,
    p_latitude DECIMAL(10, 8),
    p_longitude DECIMAL(11, 8),
    p_radius_km DECIMAL,
    p_category_id UUID,
    p_date_from TIMESTAMP WITH TIME ZONE,
    p_limit INT,
    p_offset INT
)
RETURNS TABLE (
    total_count BIGINT,
    activity_id UUID,
    title VARCHAR(255),
    description TEXT,
    activity_type activity.activity_type,
    scheduled_at TIMESTAMP WITH TIME ZONE,
    duration_minutes INT,
    max_participants INT,
    current_participants_count INT,
    city VARCHAR(100),
    language VARCHAR(5),
    tags TEXT[],
    organizer_username VARCHAR(100),
    organizer_is_verified BOOLEAN,
    category_name VARCHAR(100),
    distance_km DECIMAL
) AS $$
DECLARE
    v_blocked_users UUID[];
    v_total_count BIGINT;
BEGIN
    -- 1. GET BLOCKED USERS
    v_blocked_users := ARRAY(
        SELECT blocked_user_id FROM activity.user_blocks WHERE blocker_user_id = p_user_id
        UNION
        SELECT blocker_user_id FROM activity.user_blocks WHERE blocked_user_id = p_user_id
    );

    -- 2. CALCULATE DISTANCES AND COUNT
    -- Note: This uses simplified distance calculation (Haversine formula approximation)
    -- For production, consider using PostGIS ST_Distance
    WITH nearby AS (
        SELECT
            a.activity_id,
            a.organizer_user_id,
            a.title,
            a.description,
            a.activity_type,
            a.scheduled_at,
            a.duration_minutes,
            a.max_participants,
            a.current_participants_count,
            a.city,
            a.language,
            a.category_id,
            al.latitude,
            al.longitude,
            -- Simplified distance calculation (km)
            (6371 * acos(
                cos(radians(p_latitude)) *
                cos(radians(al.latitude)) *
                cos(radians(al.longitude) - radians(p_longitude)) +
                sin(radians(p_latitude)) *
                sin(radians(al.latitude))
            ))::DECIMAL(10, 2) as distance_km
        FROM activity.activities a
        JOIN activity.activity_locations al ON al.activity_id = a.activity_id
        WHERE a.status = 'published'
          AND a.scheduled_at > NOW()
          AND al.latitude IS NOT NULL
          AND al.longitude IS NOT NULL
          AND (a.activity_type = 'xxl' OR a.organizer_user_id NOT IN (SELECT unnest(v_blocked_users)))
          AND (p_category_id IS NULL OR a.category_id = p_category_id)
          AND (p_date_from IS NULL OR a.scheduled_at >= p_date_from)
    )
    SELECT COUNT(*) INTO v_total_count
    FROM nearby
    WHERE distance_km <= p_radius_km;

    -- 3. RETURN RESULTS
    RETURN QUERY
    WITH nearby AS (
        SELECT
            a.activity_id,
            a.organizer_user_id,
            a.title,
            a.description,
            a.activity_type,
            a.scheduled_at,
            a.duration_minutes,
            a.max_participants,
            a.current_participants_count,
            a.city,
            a.language,
            a.category_id,
            (6371 * acos(
                cos(radians(p_latitude)) *
                cos(radians(al.latitude)) *
                cos(radians(al.longitude) - radians(p_longitude)) +
                sin(radians(p_latitude)) *
                sin(radians(al.latitude))
            ))::DECIMAL(10, 2) as distance_km
        FROM activity.activities a
        JOIN activity.activity_locations al ON al.activity_id = a.activity_id
        WHERE a.status = 'published'
          AND a.scheduled_at > NOW()
          AND al.latitude IS NOT NULL
          AND al.longitude IS NOT NULL
          AND (a.activity_type = 'xxl' OR a.organizer_user_id NOT IN (SELECT unnest(v_blocked_users)))
          AND (p_category_id IS NULL OR a.category_id = p_category_id)
          AND (p_date_from IS NULL OR a.scheduled_at >= p_date_from)
    )
    SELECT
        v_total_count,
        n.activity_id,
        n.title,
        n.description,
        n.activity_type,
        n.scheduled_at,
        n.duration_minutes,
        n.max_participants,
        n.current_participants_count,
        n.city,
        n.language,
        ARRAY(
            SELECT tag FROM activity.activity_tags
            WHERE activity_tags.activity_id = n.activity_id
        ) as tags,
        u.username,
        u.is_verified,
        c.name as category_name,
        n.distance_km
    FROM nearby n
    JOIN activity.users u ON u.user_id = n.organizer_user_id
    LEFT JOIN activity.categories c ON c.category_id = n.category_id
    WHERE n.distance_km <= p_radius_km
    ORDER BY n.distance_km ASC, n.scheduled_at ASC
    LIMIT p_limit
    OFFSET p_offset;

EXCEPTION
    WHEN OTHERS THEN
        RAISE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION activity.sp_nearby_activities IS 'Find activities near user location using geospatial distance calculation';


-- SP 3: Personalized Feed
CREATE OR REPLACE FUNCTION activity.sp_personalized_feed(
    p_user_id UUID,
    p_limit INT
)
RETURNS TABLE (
    activity_id UUID,
    title VARCHAR(255),
    description TEXT,
    activity_type activity.activity_type,
    scheduled_at TIMESTAMP WITH TIME ZONE,
    duration_minutes INT,
    max_participants INT,
    current_participants_count INT,
    city VARCHAR(100),
    language VARCHAR(5),
    tags TEXT[],
    organizer_username VARCHAR(100),
    organizer_is_verified BOOLEAN,
    category_name VARCHAR(100)
) AS $$
DECLARE
    v_blocked_users UUID[];
    v_user_interests TEXT[];
BEGIN
    -- 1. GET USER CONTEXT
    -- Get blocked users
    v_blocked_users := ARRAY(
        SELECT blocked_user_id FROM activity.user_blocks WHERE blocker_user_id = p_user_id
        UNION
        SELECT blocker_user_id FROM activity.user_blocks WHERE blocked_user_id = p_user_id
    );

    -- Get user interests
    SELECT ARRAY_AGG(interest_tag) INTO v_user_interests
    FROM activity.user_interests
    WHERE user_id = p_user_id;

    -- 2. RETURN PERSONALIZED ACTIVITIES
    -- Algorithm: Match based on user interests, friends' activities, and past participation
    RETURN QUERY
    SELECT DISTINCT
        a.activity_id,
        a.title,
        a.description,
        a.activity_type,
        a.scheduled_at,
        a.duration_minutes,
        a.max_participants,
        a.current_participants_count,
        a.city,
        a.language,
        ARRAY(
            SELECT tag FROM activity.activity_tags
            WHERE activity_tags.activity_id = a.activity_id
        ) as tags,
        u.username,
        u.is_verified,
        c.name as category_name
    FROM activity.activities a
    JOIN activity.users u ON u.user_id = a.organizer_user_id
    LEFT JOIN activity.categories c ON c.category_id = a.category_id
    WHERE a.status = 'published'
      AND a.scheduled_at > NOW()
      AND a.current_participants_count < a.max_participants
      AND (a.activity_type = 'xxl' OR a.organizer_user_id NOT IN (SELECT unnest(v_blocked_users)))
      AND (
          -- Match user interests
          EXISTS (
              SELECT 1 FROM activity.activity_tags at
              WHERE at.activity_id = a.activity_id
                AND at.tag = ANY(v_user_interests)
          )
          -- OR activities by friends
          OR EXISTS (
              SELECT 1 FROM activity.friendships f
              WHERE ((f.user_id_1 = p_user_id AND f.user_id_2 = a.organizer_user_id)
                 OR (f.user_id_2 = p_user_id AND f.user_id_1 = a.organizer_user_id))
                AND f.status = 'accepted'
          )
          -- OR similar to past activities
          OR a.category_id IN (
              SELECT DISTINCT a2.category_id
              FROM activity.participants p2
              JOIN activity.activities a2 ON a2.activity_id = p2.activity_id
              WHERE p2.user_id = p_user_id
                AND p2.attendance_status = 'attended'
          )
      )
    ORDER BY a.scheduled_at ASC
    LIMIT p_limit;

EXCEPTION
    WHEN OTHERS THEN
        RAISE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION activity.sp_personalized_feed IS 'Personalized feed based on interests, friends, and past activities';


-- SP 4: AI Recommendations
CREATE OR REPLACE FUNCTION activity.sp_recommendations(
    p_user_id UUID,
    p_limit INT
)
RETURNS TABLE (
    activity_id UUID,
    title VARCHAR(255),
    description TEXT,
    activity_type activity.activity_type,
    scheduled_at TIMESTAMP WITH TIME ZONE,
    duration_minutes INT,
    max_participants INT,
    current_participants_count INT,
    city VARCHAR(100),
    language VARCHAR(5),
    tags TEXT[],
    organizer_username VARCHAR(100),
    organizer_is_verified BOOLEAN,
    category_name VARCHAR(100)
) AS $$
DECLARE
    v_blocked_users UUID[];
BEGIN
    -- 1. GET BLOCKED USERS
    v_blocked_users := ARRAY(
        SELECT blocked_user_id FROM activity.user_blocks WHERE blocker_user_id = p_user_id
        UNION
        SELECT blocker_user_id FROM activity.user_blocks WHERE blocked_user_id = p_user_id
    );

    -- 2. COLLABORATIVE FILTERING
    -- Algorithm: Find users with similar activity participation and recommend their activities
    RETURN QUERY
    SELECT DISTINCT
        a.activity_id,
        a.title,
        a.description,
        a.activity_type,
        a.scheduled_at,
        a.duration_minutes,
        a.max_participants,
        a.current_participants_count,
        a.city,
        a.language,
        ARRAY(
            SELECT tag FROM activity.activity_tags
            WHERE activity_tags.activity_id = a.activity_id
        ) as tags,
        u.username,
        u.is_verified,
        c.name as category_name
    FROM activity.activities a
    JOIN activity.users u ON u.user_id = a.organizer_user_id
    LEFT JOIN activity.categories c ON c.category_id = a.category_id
    WHERE a.status = 'published'
      AND a.scheduled_at > NOW()
      AND a.current_participants_count < a.max_participants
      AND (a.activity_type = 'xxl' OR a.organizer_user_id NOT IN (SELECT unnest(v_blocked_users)))
      -- Find activities joined by similar users
      AND EXISTS (
          SELECT 1 FROM activity.participants p1
          WHERE p1.activity_id = a.activity_id
            AND p1.user_id IN (
                -- Find similar users (participated in same activities)
                SELECT DISTINCT p2.user_id
                FROM activity.participants p2
                WHERE p2.activity_id IN (
                    SELECT activity_id FROM activity.participants
                    WHERE user_id = p_user_id
                      AND attendance_status = 'attended'
                )
                AND p2.user_id != p_user_id
                AND p2.attendance_status = 'attended'
            )
      )
      -- Exclude activities user already joined
      AND NOT EXISTS (
          SELECT 1 FROM activity.participants p3
          WHERE p3.activity_id = a.activity_id
            AND p3.user_id = p_user_id
      )
    ORDER BY a.scheduled_at ASC
    LIMIT p_limit;

EXCEPTION
    WHEN OTHERS THEN
        RAISE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION activity.sp_recommendations IS 'AI recommendations using collaborative filtering based on similar users';
