"""Search service for discovery and recommendations."""

from typing import List, Optional
from uuid import UUID
from decimal import Decimal
from datetime import datetime
import json
import structlog

from app.core.database import Database
from app.core.exceptions import map_db_error
from app.schemas.search import ActivitySearchFilters, NearbySearchFilters

logger = structlog.get_logger()


class SearchService:
    """Service for search and discovery operations."""

    def __init__(self, db: Database):
        self.db = db

    async def search_activities(
        self,
        user_id: UUID,
        filters: ActivitySearchFilters
    ) -> dict:
        """
        Search activities with filters.

        Calls: activity.sp_search_activities()

        Args:
            user_id: User ID (from JWT)
            filters: Search filters

        Returns:
            Dictionary with search results and pagination info
        """
        try:
            # Convert tags to JSONB if provided
            tags_json = json.dumps(filters.tags) if filters.tags else None

            rows = await self.db.fetch_all(
                """
                SELECT * FROM activity.sp_search_activities(
                    p_user_id := $1,
                    p_query := $2,
                    p_category_id := $3,
                    p_activity_type := $4,
                    p_city := $5,
                    p_language := $6,
                    p_tags := $7::jsonb,
                    p_date_from := $8,
                    p_date_to := $9,
                    p_has_spots_available := $10,
                    p_limit := $11,
                    p_offset := $12
                )
                """,
                user_id,
                filters.query,
                filters.category_id,
                filters.activity_type.value if filters.activity_type else None,
                filters.city,
                filters.language,
                tags_json,
                filters.date_from,
                filters.date_to,
                filters.has_spots_available,
                filters.limit,
                filters.offset
            )

            # Get total count from first row
            total_results = rows[0]['total_count'] if rows else 0

            # Build activities list
            activities = []
            for row in rows:
                if row['activity_id']:  # Check if there are actual results
                    activities.append({
                        'activity_id': row['activity_id'],
                        'title': row['title'],
                        'description': row['description'],
                        'activity_type': row['activity_type'],
                        'scheduled_at': row['scheduled_at'],
                        'duration_minutes': row['duration_minutes'],
                        'max_participants': row['max_participants'],
                        'current_participants_count': row['current_participants_count'],
                        'city': row['city'],
                        'language': row['language'],
                        'tags': row['tags'] or [],
                        'organizer_username': row['organizer_username'],
                        'organizer_is_verified': row['organizer_is_verified'],
                        'category_name': row['category_name']
                    })

            logger.info("activities_searched", count=len(activities), total=total_results)
            return {
                'total_results': total_results,
                'limit': filters.limit,
                'offset': filters.offset,
                'activities': activities
            }

        except Exception as e:
            logger.error("search_activities_failed", error=str(e))
            raise map_db_error(e)

    async def nearby_activities(
        self,
        user_id: UUID,
        filters: NearbySearchFilters
    ) -> dict:
        """
        Search nearby activities using geospatial queries.

        Calls: activity.sp_nearby_activities()

        Args:
            user_id: User ID (from JWT)
            filters: Nearby search filters

        Returns:
            Dictionary with nearby activities
        """
        try:
            rows = await self.db.fetch_all(
                """
                SELECT * FROM activity.sp_nearby_activities(
                    p_user_id := $1,
                    p_latitude := $2,
                    p_longitude := $3,
                    p_radius_km := $4,
                    p_category_id := $5,
                    p_date_from := $6,
                    p_limit := $7,
                    p_offset := $8
                )
                """,
                user_id,
                float(filters.latitude),
                float(filters.longitude),
                filters.radius_km,
                filters.category_id,
                filters.date_from,
                filters.limit,
                filters.offset
            )

            # Get total count
            total_results = rows[0]['total_count'] if rows else 0

            # Build activities list
            activities = []
            for row in rows:
                if row['activity_id']:
                    activities.append({
                        'activity_id': row['activity_id'],
                        'title': row['title'],
                        'description': row['description'],
                        'activity_type': row['activity_type'],
                        'scheduled_at': row['scheduled_at'],
                        'duration_minutes': row['duration_minutes'],
                        'max_participants': row['max_participants'],
                        'current_participants_count': row['current_participants_count'],
                        'city': row['city'],
                        'language': row['language'],
                        'tags': row['tags'] or [],
                        'organizer_username': row['organizer_username'],
                        'organizer_is_verified': row['organizer_is_verified'],
                        'category_name': row['category_name'],
                        'distance_km': float(row['distance_km']) if row['distance_km'] else None
                    })

            logger.info("nearby_activities_searched", count=len(activities))
            return {
                'total_results': total_results,
                'limit': filters.limit,
                'offset': filters.offset,
                'activities': activities
            }

        except Exception as e:
            logger.error("nearby_activities_failed", error=str(e))
            raise map_db_error(e)

    async def personalized_feed(
        self,
        user_id: UUID,
        limit: int = 20
    ) -> dict:
        """
        Get personalized activity feed based on user interests.

        Calls: activity.sp_personalized_feed()

        Args:
            user_id: User ID (from JWT)
            limit: Maximum activities to return

        Returns:
            Dictionary with personalized activities
        """
        try:
            rows = await self.db.fetch_all(
                """
                SELECT * FROM activity.sp_personalized_feed(
                    p_user_id := $1,
                    p_limit := $2
                )
                """,
                user_id,
                limit
            )

            # Build activities list
            activities = []
            for row in rows:
                if row['activity_id']:
                    activities.append({
                        'activity_id': row['activity_id'],
                        'title': row['title'],
                        'description': row['description'],
                        'activity_type': row['activity_type'],
                        'scheduled_at': row['scheduled_at'],
                        'duration_minutes': row['duration_minutes'],
                        'max_participants': row['max_participants'],
                        'current_participants_count': row['current_participants_count'],
                        'city': row['city'],
                        'language': row['language'],
                        'tags': row['tags'] or [],
                        'organizer_username': row['organizer_username'],
                        'organizer_is_verified': row['organizer_is_verified'],
                        'category_name': row['category_name']
                    })

            logger.info("personalized_feed_generated", count=len(activities))
            return {
                'activities': activities,
                'reason': 'Based on your interests and past activities'
            }

        except Exception as e:
            logger.error("personalized_feed_failed", error=str(e))
            raise map_db_error(e)

    async def recommendations(
        self,
        user_id: UUID,
        limit: int = 10
    ) -> dict:
        """
        Get AI-powered activity recommendations.

        Calls: activity.sp_recommendations()

        Args:
            user_id: User ID (from JWT)
            limit: Maximum recommendations

        Returns:
            Dictionary with recommended activities
        """
        try:
            rows = await self.db.fetch_all(
                """
                SELECT * FROM activity.sp_recommendations(
                    p_user_id := $1,
                    p_limit := $2
                )
                """,
                user_id,
                limit
            )

            # Build activities list
            activities = []
            for row in rows:
                if row['activity_id']:
                    activities.append({
                        'activity_id': row['activity_id'],
                        'title': row['title'],
                        'description': row['description'],
                        'activity_type': row['activity_type'],
                        'scheduled_at': row['scheduled_at'],
                        'duration_minutes': row['duration_minutes'],
                        'max_participants': row['max_participants'],
                        'current_participants_count': row['current_participants_count'],
                        'city': row['city'],
                        'language': row['language'],
                        'tags': row['tags'] or [],
                        'organizer_username': row['organizer_username'],
                        'organizer_is_verified': row['organizer_is_verified'],
                        'category_name': row['category_name']
                    })

            logger.info("recommendations_generated", count=len(activities))
            return {
                'activities': activities,
                'recommendation_reason': 'Based on collaborative filtering and interest matching'
            }

        except Exception as e:
            logger.error("recommendations_failed", error=str(e))
            raise map_db_error(e)
