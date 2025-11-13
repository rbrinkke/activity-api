-- ============================================================================
-- REVIEW STORED PROCEDURES
-- ============================================================================

-- SP 1: Create Review
CREATE OR REPLACE FUNCTION activity.sp_create_review(
    p_activity_id UUID,
    p_reviewer_user_id UUID,
    p_rating INT,
    p_review_text TEXT,
    p_is_anonymous BOOLEAN
)
RETURNS TABLE (
    review_id UUID,
    activity_id UUID,
    reviewer_user_id UUID,
    reviewer_username VARCHAR(100),
    reviewer_first_name VARCHAR(100),
    reviewer_main_photo_url VARCHAR(500),
    reviewer_is_verified BOOLEAN,
    rating INT,
    review_text TEXT,
    is_anonymous BOOLEAN,
    created_at TIMESTAMP WITH TIME ZONE,
    updated_at TIMESTAMP WITH TIME ZONE,
    is_own_review BOOLEAN
) AS $$
DECLARE
    v_activity RECORD;
    v_review_id UUID;
    v_participation RECORD;
BEGIN
    -- 1. VALIDATION
    -- Check if activity exists
    SELECT * INTO v_activity
    FROM activity.activities
    WHERE activities.activity_id = p_activity_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'ERR_NOT_FOUND_ACTIVITY' USING ERRCODE = '42704';
    END IF;

    -- Check if activity is completed
    IF v_activity.status != 'completed' THEN
        RAISE EXCEPTION 'ERR_FORBIDDEN_ACTIVITY_NOT_COMPLETED' USING ERRCODE = '42501';
    END IF;

    -- Check if user participated
    SELECT * INTO v_participation
    FROM activity.participants
    WHERE activity_id = p_activity_id
      AND user_id = p_reviewer_user_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'ERR_FORBIDDEN_NOT_PARTICIPANT' USING ERRCODE = '42501';
    END IF;

    -- Check if user attended (not no-show)
    IF v_participation.attendance_status = 'no_show' THEN
        RAISE EXCEPTION 'ERR_FORBIDDEN_NO_SHOW' USING ERRCODE = '42501';
    END IF;

    -- Check if review already exists
    IF EXISTS (
        SELECT 1 FROM activity.activity_reviews
        WHERE activity_id = p_activity_id
          AND reviewer_user_id = p_reviewer_user_id
    ) THEN
        RAISE EXCEPTION 'ERR_CONFLICT_REVIEW_EXISTS' USING ERRCODE = '23505';
    END IF;

    -- Validate rating range
    IF p_rating < 1 OR p_rating > 5 THEN
        RAISE EXCEPTION 'ERR_VALIDATION_INVALID_RATING' USING ERRCODE = '22000';
    END IF;

    -- 2. CREATE REVIEW
    INSERT INTO activity.activity_reviews (
        activity_id,
        reviewer_user_id,
        rating,
        review_text,
        is_anonymous
    ) VALUES (
        p_activity_id,
        p_reviewer_user_id,
        p_rating,
        p_review_text,
        COALESCE(p_is_anonymous, FALSE)
    ) RETURNING activity_reviews.review_id INTO v_review_id;

    -- 3. RETURN
    RETURN QUERY
    SELECT
        v_review_id,
        p_activity_id,
        CASE WHEN p_is_anonymous THEN NULL ELSE u.user_id END,
        CASE WHEN p_is_anonymous THEN NULL ELSE u.username END,
        CASE WHEN p_is_anonymous THEN NULL ELSE u.first_name END,
        CASE WHEN p_is_anonymous THEN NULL ELSE u.main_photo_url END,
        CASE WHEN p_is_anonymous THEN NULL ELSE u.is_verified END,
        p_rating,
        p_review_text,
        COALESCE(p_is_anonymous, FALSE),
        NOW(),
        NULL::TIMESTAMP WITH TIME ZONE,
        TRUE  -- is_own_review
    FROM activity.users u
    WHERE u.user_id = p_reviewer_user_id;

EXCEPTION
    WHEN OTHERS THEN
        RAISE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION activity.sp_create_review IS 'Create review for completed activity (participant only)';


-- SP 2: List Reviews
CREATE OR REPLACE FUNCTION activity.sp_list_reviews(
    p_activity_id UUID,
    p_requesting_user_id UUID,
    p_limit INT,
    p_offset INT
)
RETURNS TABLE (
    activity_id UUID,
    total_reviews BIGINT,
    average_rating NUMERIC,
    review_id UUID,
    reviewer_user_id UUID,
    reviewer_username VARCHAR(100),
    reviewer_first_name VARCHAR(100),
    reviewer_main_photo_url VARCHAR(500),
    reviewer_is_verified BOOLEAN,
    rating INT,
    review_text TEXT,
    is_anonymous BOOLEAN,
    created_at TIMESTAMP WITH TIME ZONE,
    updated_at TIMESTAMP WITH TIME ZONE,
    is_own_review BOOLEAN
) AS $$
DECLARE
    v_total_reviews BIGINT;
    v_average_rating NUMERIC;
BEGIN
    -- 1. VALIDATION
    -- Check if activity exists
    IF NOT EXISTS (
        SELECT 1 FROM activity.activities WHERE activities.activity_id = p_activity_id
    ) THEN
        RAISE EXCEPTION 'ERR_NOT_FOUND_ACTIVITY' USING ERRCODE = '42704';
    END IF;

    -- 2. GET STATISTICS
    SELECT
        COUNT(*)::BIGINT,
        AVG(r.rating)::NUMERIC(3,2)
    INTO v_total_reviews, v_average_rating
    FROM activity.activity_reviews r
    WHERE r.activity_id = p_activity_id;

    -- 3. RETURN REVIEWS
    RETURN QUERY
    SELECT
        p_activity_id,
        v_total_reviews,
        v_average_rating,
        r.review_id,
        CASE WHEN r.is_anonymous THEN NULL ELSE u.user_id END,
        CASE WHEN r.is_anonymous THEN NULL ELSE u.username END,
        CASE WHEN r.is_anonymous THEN NULL ELSE u.first_name END,
        CASE WHEN r.is_anonymous THEN NULL ELSE u.main_photo_url END,
        CASE WHEN r.is_anonymous THEN NULL ELSE u.is_verified END,
        r.rating,
        r.review_text,
        r.is_anonymous,
        r.created_at,
        r.updated_at,
        CASE WHEN p_requesting_user_id IS NOT NULL AND r.reviewer_user_id = p_requesting_user_id
            THEN TRUE ELSE FALSE END as is_own_review
    FROM activity.activity_reviews r
    JOIN activity.users u ON u.user_id = r.reviewer_user_id
    WHERE r.activity_id = p_activity_id
    ORDER BY r.created_at DESC
    LIMIT p_limit
    OFFSET p_offset;

EXCEPTION
    WHEN OTHERS THEN
        RAISE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION activity.sp_list_reviews IS 'List reviews for activity with average rating';


-- SP 3: Update Review
CREATE OR REPLACE FUNCTION activity.sp_update_review(
    p_review_id UUID,
    p_user_id UUID,
    p_rating INT,
    p_review_text TEXT,
    p_is_anonymous BOOLEAN
)
RETURNS TABLE (
    review_id UUID,
    activity_id UUID,
    reviewer_user_id UUID,
    reviewer_username VARCHAR(100),
    reviewer_first_name VARCHAR(100),
    reviewer_main_photo_url VARCHAR(500),
    reviewer_is_verified BOOLEAN,
    rating INT,
    review_text TEXT,
    is_anonymous BOOLEAN,
    created_at TIMESTAMP WITH TIME ZONE,
    updated_at TIMESTAMP WITH TIME ZONE,
    is_own_review BOOLEAN
) AS $$
DECLARE
    v_review RECORD;
    v_is_anonymous BOOLEAN;
BEGIN
    -- 1. VALIDATION
    -- Check if review exists
    SELECT * INTO v_review
    FROM activity.activity_reviews
    WHERE activity_reviews.review_id = p_review_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'ERR_NOT_FOUND_REVIEW' USING ERRCODE = '42704';
    END IF;

    -- Check if user is the reviewer
    IF v_review.reviewer_user_id != p_user_id THEN
        RAISE EXCEPTION 'ERR_FORBIDDEN_NOT_REVIEWER' USING ERRCODE = '42501';
    END IF;

    -- Validate rating if provided
    IF p_rating IS NOT NULL AND (p_rating < 1 OR p_rating > 5) THEN
        RAISE EXCEPTION 'ERR_VALIDATION_INVALID_RATING' USING ERRCODE = '22000';
    END IF;

    -- 2. UPDATE REVIEW
    UPDATE activity.activity_reviews
    SET
        rating = COALESCE(p_rating, rating),
        review_text = COALESCE(p_review_text, review_text),
        is_anonymous = COALESCE(p_is_anonymous, is_anonymous),
        updated_at = NOW()
    WHERE activity_reviews.review_id = p_review_id
    RETURNING is_anonymous INTO v_is_anonymous;

    -- 3. RETURN
    RETURN QUERY
    SELECT
        r.review_id,
        r.activity_id,
        CASE WHEN v_is_anonymous THEN NULL ELSE u.user_id END,
        CASE WHEN v_is_anonymous THEN NULL ELSE u.username END,
        CASE WHEN v_is_anonymous THEN NULL ELSE u.first_name END,
        CASE WHEN v_is_anonymous THEN NULL ELSE u.main_photo_url END,
        CASE WHEN v_is_anonymous THEN NULL ELSE u.is_verified END,
        r.rating,
        r.review_text,
        r.is_anonymous,
        r.created_at,
        r.updated_at,
        TRUE  -- is_own_review
    FROM activity.activity_reviews r
    JOIN activity.users u ON u.user_id = r.reviewer_user_id
    WHERE r.review_id = p_review_id;

EXCEPTION
    WHEN OTHERS THEN
        RAISE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION activity.sp_update_review IS 'Update review (reviewer only)';


-- SP 4: Delete Review
CREATE OR REPLACE FUNCTION activity.sp_delete_review(
    p_review_id UUID,
    p_user_id UUID
)
RETURNS TABLE (
    deleted BOOLEAN,
    message TEXT
) AS $$
DECLARE
    v_review RECORD;
BEGIN
    -- 1. VALIDATION
    -- Check if review exists
    SELECT * INTO v_review
    FROM activity.activity_reviews
    WHERE review_id = p_review_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'ERR_NOT_FOUND_REVIEW' USING ERRCODE = '42704';
    END IF;

    -- Check if user is the reviewer
    IF v_review.reviewer_user_id != p_user_id THEN
        RAISE EXCEPTION 'ERR_FORBIDDEN_NOT_REVIEWER' USING ERRCODE = '42501';
    END IF;

    -- 2. DELETE REVIEW
    DELETE FROM activity.activity_reviews WHERE review_id = p_review_id;

    -- 3. RETURN
    RETURN QUERY
    SELECT TRUE, 'Review deleted successfully'::TEXT;

EXCEPTION
    WHEN OTHERS THEN
        RAISE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION activity.sp_delete_review IS 'Delete review (reviewer only)';
