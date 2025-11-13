"""Participant service for business logic."""

from typing import List
from uuid import UUID
import structlog

from app.core.database import Database
from app.core.exceptions import NotFoundException, map_db_error

logger = structlog.get_logger()


class ParticipantService:
    """Service for participant operations."""

    def __init__(self, db: Database):
        self.db = db

    async def list_participants(
        self,
        activity_id: UUID,
        requesting_user_id: UUID
    ) -> dict:
        """
        List all participants of an activity.

        Calls: activity.sp_get_activity_participants()

        Args:
            activity_id: Activity ID
            requesting_user_id: User ID making the request (for privacy checks)

        Returns:
            Dictionary with activity info and participants list
        """
        try:
            rows = await self.db.fetch_all(
                """
                SELECT * FROM activity.sp_get_activity_participants(
                    p_activity_id := $1,
                    p_requesting_user_id := $2
                )
                """,
                activity_id,
                requesting_user_id
            )

            if not rows:
                raise NotFoundException("Activity")

            # Group participants
            result = {
                'activity_id': rows[0]['activity_id'],
                'total_participants': rows[0]['total_participants'],
                'max_participants': rows[0]['max_participants'],
                'participants': []
            }

            for row in rows:
                if row['user_id']:  # Check if there are actual participants
                    result['participants'].append({
                        'user_id': row['user_id'],
                        'username': row['username'],
                        'first_name': row['first_name'],
                        'main_photo_url': row['main_photo_url'],
                        'is_verified': row['is_verified'],
                        'role': row['role'],
                        'participation_status': row['participation_status'],
                        'attendance_status': row['attendance_status'],
                        'joined_at': row['joined_at']
                    })

            logger.info("participants_listed", activity_id=str(activity_id), count=len(result['participants']))
            return result

        except Exception as e:
            logger.error("list_participants_failed", activity_id=str(activity_id), error=str(e))
            raise map_db_error(e)

    async def get_waitlist(
        self,
        activity_id: UUID,
        requesting_user_id: UUID
    ) -> dict:
        """
        Get waitlist for an activity.

        Calls: activity.sp_get_activity_waitlist()

        Args:
            activity_id: Activity ID
            requesting_user_id: User ID making the request (for privacy checks)

        Returns:
            Dictionary with activity info and waitlist
        """
        try:
            rows = await self.db.fetch_all(
                """
                SELECT * FROM activity.sp_get_activity_waitlist(
                    p_activity_id := $1,
                    p_requesting_user_id := $2
                )
                """,
                activity_id,
                requesting_user_id
            )

            if not rows:
                raise NotFoundException("Activity")

            # Group waitlist entries
            result = {
                'activity_id': rows[0]['activity_id'],
                'total_waitlist': rows[0]['total_waitlist'],
                'waitlist': []
            }

            for row in rows:
                if row['user_id']:  # Check if there are actual waitlist entries
                    result['waitlist'].append({
                        'user_id': row['user_id'],
                        'username': row['username'],
                        'first_name': row['first_name'],
                        'main_photo_url': row['main_photo_url'],
                        'is_verified': row['is_verified'],
                        'position': row['position'],
                        'joined_at': row['created_at'],
                        'notified_at': row['notified_at']
                    })

            logger.info("waitlist_retrieved", activity_id=str(activity_id), count=len(result['waitlist']))
            return result

        except Exception as e:
            logger.error("get_waitlist_failed", activity_id=str(activity_id), error=str(e))
            raise map_db_error(e)
