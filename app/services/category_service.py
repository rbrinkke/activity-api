"""Category service for business logic."""

from typing import List, Optional
from uuid import UUID
import structlog

from app.core.database import Database
from app.core.exceptions import NotFoundException, ConflictException, map_db_error
from app.schemas.category import CategoryCreate, CategoryUpdate

logger = structlog.get_logger()


class CategoryService:
    """Service for category operations."""

    def __init__(self, db: Database):
        self.db = db

    async def list_categories(self) -> List[dict]:
        """
        List all active categories.

        Calls: activity.sp_list_categories()

        Returns:
            List of category dictionaries
        """
        try:
            rows = await self.db.fetch_all(
                "SELECT * FROM activity.sp_list_categories()"
            )
            logger.info("categories_listed", count=len(rows))
            return rows

        except Exception as e:
            logger.error("list_categories_failed", error=str(e))
            raise map_db_error(e)

    async def create_category(
        self,
        data: CategoryCreate
    ) -> dict:
        """
        Create a new category.

        Calls: activity.sp_create_category()

        Args:
            data: Category creation data

        Returns:
            Created category dictionary
        """
        try:
            rows = await self.db.fetch_all(
                """
                SELECT * FROM activity.sp_create_category(
                    p_name := $1,
                    p_slug := $2,
                    p_description := $3,
                    p_icon_url := $4,
                    p_display_order := $5
                )
                """,
                data.name,
                data.slug,
                data.description,
                data.icon_url,
                data.display_order
            )

            if not rows:
                raise NotFoundException("Category creation failed")

            logger.info("category_created", category_id=str(rows[0]['category_id']))
            return rows[0]

        except Exception as e:
            logger.error("create_category_failed", error=str(e))
            raise map_db_error(e)

    async def update_category(
        self,
        category_id: UUID,
        data: CategoryUpdate
    ) -> dict:
        """
        Update an existing category.

        Calls: activity.sp_update_category()

        Args:
            category_id: Category ID to update
            data: Category update data

        Returns:
            Updated category dictionary
        """
        try:
            rows = await self.db.fetch_all(
                """
                SELECT * FROM activity.sp_update_category(
                    p_category_id := $1,
                    p_name := $2,
                    p_slug := $3,
                    p_description := $4,
                    p_icon_url := $5,
                    p_display_order := $6,
                    p_is_active := $7
                )
                """,
                category_id,
                data.name,
                data.slug,
                data.description,
                data.icon_url,
                data.display_order,
                data.is_active
            )

            if not rows:
                raise NotFoundException("Category")

            logger.info("category_updated", category_id=str(category_id))
            return rows[0]

        except Exception as e:
            logger.error("update_category_failed", category_id=str(category_id), error=str(e))
            raise map_db_error(e)
