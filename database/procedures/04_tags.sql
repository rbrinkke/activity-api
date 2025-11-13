-- ============================================================================
-- TAG STORED PROCEDURES
-- ============================================================================

-- SP 1: Get Popular Tags
CREATE OR REPLACE FUNCTION activity.sp_get_popular_tags(
    p_limit INT,
    p_prefix VARCHAR(100)
)
RETURNS TABLE (
    tag VARCHAR(100),
    usage_count BIGINT
) AS $$
BEGIN
    -- Query activity_tags and aggregate by tag
    RETURN QUERY
    SELECT
        at.tag,
        COUNT(*)::BIGINT as usage_count
    FROM activity.activity_tags at
    -- Filter by prefix if provided
    WHERE p_prefix IS NULL OR at.tag ILIKE (p_prefix || '%')
    GROUP BY at.tag
    ORDER BY usage_count DESC, at.tag ASC
    LIMIT p_limit;

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION activity.sp_get_popular_tags IS 'Get most popular tags for autocomplete/suggestions';
