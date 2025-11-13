"""Review service for business logic."""

from typing import Optional
from uuid import UUID
import structlog

from app.core.database import Database
from app.core.exceptions import NotFoundException, map_db_error
from app.schemas.review import ReviewCreate, ReviewUpdate

logger = structlog.get_logger()


class ReviewService:
    """Service for review operations."""

    def __init__(self, db: Database):
        self.db = db

    async def create_review(
        self,
        activity_id: UUID,
        user_id: UUID,
        data: ReviewCreate
    ) -> dict:
        """
        Create a review for an activity.

        Calls: activity.sp_create_activity_review()

        Args:
            activity_id: Activity ID
            user_id: Reviewer user ID (from JWT)
            data: Review creation data

        Returns:
            Created review dictionary
        """
        try:
            rows = await self.db.fetch_all(
                """
                SELECT * FROM activity.sp_create_activity_review(
                    p_activity_id := $1,
                    p_reviewer_user_id := $2,
                    p_rating := $3,
                    p_review_text := $4,
                    p_is_anonymous := $5
                )
                """,
                activity_id,
                user_id,
                data.rating,
                data.review_text,
                data.is_anonymous
            )

            if not rows:
                raise NotFoundException("Review creation failed")

            logger.info("review_created", review_id=str(rows[0]['review_id']), activity_id=str(activity_id))
            return rows[0]

        except Exception as e:
            logger.error("create_review_failed", activity_id=str(activity_id), error=str(e))
            raise map_db_error(e)

    async def list_reviews(
        self,
        activity_id: UUID,
        requesting_user_id: Optional[UUID] = None,
        limit: int = 50,
        offset: int = 0
    ) -> dict:
        """
        List reviews for an activity.

        Calls: activity.sp_get_activity_reviews()

        Args:
            activity_id: Activity ID
            requesting_user_id: User ID making the request (optional, for marking own reviews)
            limit: Maximum number of reviews to return
            offset: Number of reviews to skip (pagination)

        Returns:
            Dictionary with reviews list and metadata
        """
        try:
            rows = await self.db.fetch_all(
                """
                SELECT * FROM activity.sp_get_activity_reviews(
                    p_activity_id := $1,
                    p_requesting_user_id := $2,
                    p_limit := $3,
                    p_offset := $4
                )
                """,
                activity_id,
                requesting_user_id,
                limit,
                offset
            )

            if not rows:
                # Activity might not exist or have no reviews
                # Check if activity exists
                activity_check = await self.db.fetch_one(
                    "SELECT activity_id FROM activity.activities WHERE activity_id = $1",
                    activity_id
                )
                if not activity_check:
                    raise NotFoundException("Activity")

                # Activity exists but has no reviews
                return {
                    'activity_id': activity_id,
                    'total_reviews': 0,
                    'average_rating': None,
                    'reviews': []
                }

            # Build result
            result = {
                'activity_id': rows[0]['activity_id'],
                'total_reviews': rows[0]['total_reviews'],
                'average_rating': float(rows[0]['average_rating']) if rows[0]['average_rating'] else None,
                'reviews': []
            }

            for row in rows:
                if row['review_id']:  # Check if there are actual reviews
                    review_data = {
                        'review_id': row['review_id'],
                        'activity_id': row['activity_id'],
                        'rating': row['rating'],
                        'review_text': row['review_text'],
                        'is_anonymous': row['is_anonymous'],
                        'created_at': row['created_at'],
                        'updated_at': row['updated_at'],
                        'is_own_review': row['is_own_review']
                    }

                    # Add reviewer info if not anonymous
                    if not row['is_anonymous'] and row['reviewer_user_id']:
                        review_data['reviewer'] = {
                            'user_id': row['reviewer_user_id'],
                            'username': row['reviewer_username'],
                            'first_name': row['reviewer_first_name'],
                            'main_photo_url': row['reviewer_main_photo_url'],
                            'is_verified': row['reviewer_is_verified']
                        }
                    else:
                        review_data['reviewer'] = None

                    result['reviews'].append(review_data)

            logger.info("reviews_listed", activity_id=str(activity_id), count=len(result['reviews']))
            return result

        except Exception as e:
            logger.error("list_reviews_failed", activity_id=str(activity_id), error=str(e))
            raise map_db_error(e)

    async def update_review(
        self,
        review_id: UUID,
        user_id: UUID,
        data: ReviewUpdate
    ) -> dict:
        """
        Update a review.

        Calls: activity.sp_update_review()

        Args:
            review_id: Review ID to update
            user_id: User ID (from JWT, must be reviewer)
            data: Review update data

        Returns:
            Updated review dictionary
        """
        try:
            rows = await self.db.fetch_all(
                """
                SELECT * FROM activity.sp_update_review(
                    p_review_id := $1,
                    p_user_id := $2,
                    p_rating := $3,
                    p_review_text := $4,
                    p_is_anonymous := $5
                )
                """,
                review_id,
                user_id,
                data.rating,
                data.review_text,
                data.is_anonymous
            )

            if not rows:
                raise NotFoundException("Review")

            logger.info("review_updated", review_id=str(review_id))
            return rows[0]

        except Exception as e:
            logger.error("update_review_failed", review_id=str(review_id), error=str(e))
            raise map_db_error(e)

    async def delete_review(
        self,
        review_id: UUID,
        user_id: UUID
    ) -> dict:
        """
        Delete a review.

        Calls: activity.sp_delete_review()

        Args:
            review_id: Review ID to delete
            user_id: User ID (from JWT, must be reviewer)

        Returns:
            Deletion result dictionary
        """
        try:
            rows = await self.db.fetch_all(
                """
                SELECT * FROM activity.sp_delete_review(
                    p_review_id := $1,
                    p_user_id := $2
                )
                """,
                review_id,
                user_id
            )

            if not rows:
                raise NotFoundException("Review")

            logger.info("review_deleted", review_id=str(review_id))
            return rows[0]

        except Exception as e:
            logger.error("delete_review_failed", review_id=str(review_id), error=str(e))
            raise map_db_error(e)
