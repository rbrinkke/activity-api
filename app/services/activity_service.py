"""Activity service for business logic."""

from typing import Optional
from uuid import UUID
import json
import structlog

from app.core.database import Database
from app.core.exceptions import NotFoundException, ForbiddenException, map_db_error
from app.schemas.activity import ActivityCreate, ActivityUpdate, ActivityCancel

logger = structlog.get_logger()


class ActivityService:
    """Service for activity operations."""

    def __init__(self, db: Database):
        self.db = db

    async def create_activity(
        self,
        user_id: UUID,
        data: ActivityCreate
    ) -> dict:
        """
        Create a new activity.

        Calls: activity.sp_create_activity()

        Args:
            user_id: Organizer user ID (from JWT)
            data: Activity creation data

        Returns:
            Created activity dictionary
        """
        try:
            # Prepare location parameters
            loc = data.location
            venue_name = loc.venue_name if loc else None
            address_line1 = loc.address_line1 if loc else None
            address_line2 = loc.address_line2 if loc else None
            city = loc.city if loc else None
            state_province = loc.state_province if loc else None
            postal_code = loc.postal_code if loc else None
            country = loc.country if loc else None
            latitude = float(loc.latitude) if loc and loc.latitude else None
            longitude = float(loc.longitude) if loc and loc.longitude else None
            place_id = loc.place_id if loc else None

            # Convert tags to JSONB
            tags_json = json.dumps(data.tags) if data.tags else None

            rows = await self.db.fetch_all(
                """
                SELECT * FROM activity.sp_create_activity(
                    p_organizer_user_id := $1,
                    p_category_id := $2,
                    p_title := $3,
                    p_description := $4,
                    p_activity_type := $5,
                    p_activity_privacy_level := $6,
                    p_scheduled_at := $7,
                    p_duration_minutes := $8,
                    p_joinable_at_free := $9,
                    p_max_participants := $10,
                    p_language := $11,
                    p_external_chat_id := $12,
                    p_venue_name := $13,
                    p_address_line1 := $14,
                    p_address_line2 := $15,
                    p_city := $16,
                    p_state_province := $17,
                    p_postal_code := $18,
                    p_country := $19,
                    p_latitude := $20,
                    p_longitude := $21,
                    p_place_id := $22,
                    p_tags := $23::jsonb
                )
                """,
                user_id,
                data.category_id,
                data.title,
                data.description,
                data.activity_type.value,
                data.activity_privacy_level.value,
                data.scheduled_at,
                data.duration_minutes,
                data.joinable_at_free,
                data.max_participants,
                data.language,
                data.external_chat_id,
                venue_name,
                address_line1,
                address_line2,
                city,
                state_province,
                postal_code,
                country,
                latitude,
                longitude,
                place_id,
                tags_json
            )

            if not rows:
                raise NotFoundException("Activity creation failed")

            logger.info("activity_created", activity_id=str(rows[0]['activity_id']))
            return rows[0]

        except Exception as e:
            logger.error("create_activity_failed", error=str(e))
            raise map_db_error(e)

    async def get_activity_by_id(
        self,
        activity_id: UUID,
        requesting_user_id: UUID
    ) -> dict:
        """
        Get activity by ID with user-specific information.

        Calls: activity.sp_get_activity_by_id()

        Args:
            activity_id: Activity ID
            requesting_user_id: Requesting user ID (from JWT)

        Returns:
            Activity dictionary
        """
        try:
            rows = await self.db.fetch_all(
                """
                SELECT * FROM activity.sp_get_activity_by_id(
                    p_activity_id := $1,
                    p_requesting_user_id := $2
                )
                """,
                activity_id,
                requesting_user_id
            )

            if not rows:
                raise NotFoundException("Activity")

            logger.info("activity_retrieved", activity_id=str(activity_id))
            return rows[0]

        except Exception as e:
            logger.error("get_activity_failed", activity_id=str(activity_id), error=str(e))
            raise map_db_error(e)

    async def update_activity(
        self,
        activity_id: UUID,
        user_id: UUID,
        data: ActivityUpdate
    ) -> dict:
        """
        Update an existing activity.

        Calls: activity.sp_update_activity()

        Args:
            activity_id: Activity ID to update
            user_id: User ID (from JWT, must be organizer)
            data: Activity update data

        Returns:
            Updated activity dictionary
        """
        try:
            # Prepare location parameters
            loc = data.location
            venue_name = loc.venue_name if loc else None
            address_line1 = loc.address_line1 if loc else None
            address_line2 = loc.address_line2 if loc else None
            city = loc.city if loc else None
            state_province = loc.state_province if loc else None
            postal_code = loc.postal_code if loc else None
            country = loc.country if loc else None
            latitude = float(loc.latitude) if loc and loc.latitude else None
            longitude = float(loc.longitude) if loc and loc.longitude else None
            place_id = loc.place_id if loc else None

            # Convert tags to JSONB
            tags_json = json.dumps(data.tags) if data.tags is not None else None

            # Convert enum values to strings
            activity_type = data.activity_type.value if data.activity_type else None
            privacy_level = data.activity_privacy_level.value if data.activity_privacy_level else None

            rows = await self.db.fetch_all(
                """
                SELECT * FROM activity.sp_update_activity(
                    p_activity_id := $1,
                    p_user_id := $2,
                    p_category_id := $3,
                    p_title := $4,
                    p_description := $5,
                    p_activity_type := $6,
                    p_activity_privacy_level := $7,
                    p_scheduled_at := $8,
                    p_duration_minutes := $9,
                    p_joinable_at_free := $10,
                    p_max_participants := $11,
                    p_language := $12,
                    p_external_chat_id := $13,
                    p_venue_name := $14,
                    p_address_line1 := $15,
                    p_address_line2 := $16,
                    p_city := $17,
                    p_state_province := $18,
                    p_postal_code := $19,
                    p_country := $20,
                    p_latitude := $21,
                    p_longitude := $22,
                    p_place_id := $23,
                    p_tags := $24::jsonb
                )
                """,
                activity_id,
                user_id,
                data.category_id,
                data.title,
                data.description,
                activity_type,
                privacy_level,
                data.scheduled_at,
                data.duration_minutes,
                data.joinable_at_free,
                data.max_participants,
                data.language,
                data.external_chat_id,
                venue_name,
                address_line1,
                address_line2,
                city,
                state_province,
                postal_code,
                country,
                latitude,
                longitude,
                place_id,
                tags_json
            )

            if not rows:
                raise NotFoundException("Activity")

            logger.info("activity_updated", activity_id=str(activity_id))
            return rows[0]

        except Exception as e:
            logger.error("update_activity_failed", activity_id=str(activity_id), error=str(e))
            raise map_db_error(e)

    async def cancel_activity(
        self,
        activity_id: UUID,
        user_id: UUID,
        data: ActivityCancel
    ) -> dict:
        """
        Cancel an activity.

        Calls: activity.sp_cancel_activity()

        Args:
            activity_id: Activity ID to cancel
            user_id: User ID (from JWT, must be organizer)
            data: Cancellation data (reason)

        Returns:
            Cancellation result dictionary
        """
        try:
            rows = await self.db.fetch_all(
                """
                SELECT * FROM activity.sp_cancel_activity(
                    p_activity_id := $1,
                    p_user_id := $2,
                    p_cancellation_reason := $3
                )
                """,
                activity_id,
                user_id,
                data.cancellation_reason
            )

            if not rows:
                raise NotFoundException("Activity")

            logger.info("activity_cancelled", activity_id=str(activity_id))
            return rows[0]

        except Exception as e:
            logger.error("cancel_activity_failed", activity_id=str(activity_id), error=str(e))
            raise map_db_error(e)

    async def delete_activity(
        self,
        activity_id: UUID,
        user_id: UUID
    ) -> dict:
        """
        Delete an activity (only if no other participants).

        Calls: activity.sp_delete_activity()

        Args:
            activity_id: Activity ID to delete
            user_id: User ID (from JWT, must be organizer)

        Returns:
            Deletion result dictionary
        """
        try:
            rows = await self.db.fetch_all(
                """
                SELECT * FROM activity.sp_delete_activity(
                    p_activity_id := $1,
                    p_user_id := $2
                )
                """,
                activity_id,
                user_id
            )

            if not rows:
                raise NotFoundException("Activity")

            logger.info("activity_deleted", activity_id=str(activity_id))
            return rows[0]

        except Exception as e:
            logger.error("delete_activity_failed", activity_id=str(activity_id), error=str(e))
            raise map_db_error(e)
