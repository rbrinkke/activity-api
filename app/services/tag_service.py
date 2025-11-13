"""Tag service for business logic."""

from typing import List, Optional
import structlog

from app.core.database import Database
from app.core.exceptions import map_db_error

logger = structlog.get_logger()


class TagService:
    """Service for tag operations."""

    def __init__(self, db: Database):
        self.db = db

    async def get_popular_tags(
        self,
        limit: int = 50,
        prefix: Optional[str] = None
    ) -> List[dict]:
        """
        Get popular tags for autocomplete/suggestions.

        Calls: activity.sp_get_popular_tags()

        Args:
            limit: Maximum number of tags to return (default 50, max 100)
            prefix: Optional prefix filter (e.g., "hik" for "hiking")

        Returns:
            List of tag dictionaries with usage counts
        """
        try:
            # Ensure limit doesn't exceed maximum
            limit = min(limit, 100)

            rows = await self.db.fetch_all(
                """
                SELECT * FROM activity.sp_get_popular_tags(
                    p_limit := $1,
                    p_prefix := $2
                )
                """,
                limit,
                prefix
            )

            logger.info("popular_tags_retrieved", count=len(rows), prefix=prefix)
            return rows

        except Exception as e:
            logger.error("get_popular_tags_failed", error=str(e))
            raise map_db_error(e)
