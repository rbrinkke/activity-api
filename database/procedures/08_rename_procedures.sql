-- ============================================================================
-- RENAME STORED PROCEDURES TO MATCH SPECIFICATIONS
-- This file renames procedures to match the exact names in specifications
-- ============================================================================

-- 1. Participants: sp_list_participants → sp_get_activity_participants
ALTER FUNCTION activity.sp_list_participants(UUID, UUID)
RENAME TO sp_get_activity_participants;

-- Note: sp_get_waitlist → sp_get_activity_waitlist (already correct format, just add activity prefix)
ALTER FUNCTION activity.sp_get_waitlist(UUID, UUID)
RENAME TO sp_get_activity_waitlist;

-- 2. Reviews: Rename all review procedures
ALTER FUNCTION activity.sp_create_review(UUID, UUID, INT, TEXT, BOOLEAN)
RENAME TO sp_create_activity_review;

ALTER FUNCTION activity.sp_list_reviews(UUID, UUID, INT, INT)
RENAME TO sp_get_activity_reviews;

-- sp_update_review and sp_delete_review are already correct (no activity prefix in spec)

-- 3. Search & Discovery: Rename procedures
ALTER FUNCTION activity.sp_nearby_activities(UUID, DECIMAL, DECIMAL, DECIMAL, UUID, TIMESTAMP WITH TIME ZONE, INT, INT)
RENAME TO sp_get_nearby_activities;

ALTER FUNCTION activity.sp_personalized_feed(UUID, INT)
RENAME TO sp_get_activity_feed;

ALTER FUNCTION activity.sp_recommendations(UUID, INT)
RENAME TO sp_get_recommended_activities;

-- Verify all procedure names
COMMENT ON FUNCTION activity.sp_get_activity_participants IS 'RENAMED: List all registered participants with privacy and blocking checks';
COMMENT ON FUNCTION activity.sp_get_activity_waitlist IS 'RENAMED: Get activity waitlist (organizer/co-organizer only)';
COMMENT ON FUNCTION activity.sp_create_activity_review IS 'RENAMED: Create review for completed activity';
COMMENT ON FUNCTION activity.sp_get_activity_reviews IS 'RENAMED: List reviews for activity with average rating';
COMMENT ON FUNCTION activity.sp_get_nearby_activities IS 'RENAMED: Find activities near user location';
COMMENT ON FUNCTION activity.sp_get_activity_feed IS 'RENAMED: Personalized feed based on interests';
COMMENT ON FUNCTION activity.sp_get_recommended_activities IS 'RENAMED: AI recommendations using collaborative filtering';
