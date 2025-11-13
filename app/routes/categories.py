"""Category API routes."""

from uuid import UUID
from fastapi import APIRouter, Depends, status
from typing import Annotated
import structlog

from app.core.database import db
from app.core.security import get_current_admin, get_optional_user, TokenPayload
from app.schemas.category import (
    CategoryCreate,
    CategoryUpdate,
    CategoryResponse,
    CategoryListResponse
)
from app.services.category_service import CategoryService

logger = structlog.get_logger()

router = APIRouter()


def get_category_service() -> CategoryService:
    """Dependency to get category service."""
    return CategoryService(db)


@router.get(
    "/categories",
    response_model=CategoryListResponse,
    summary="List all categories",
    description="Get all active activity categories. Public endpoint, no authentication required."
)
async def list_categories(
    service: Annotated[CategoryService, Depends(get_category_service)],
    current_user: Annotated[TokenPayload | None, Depends(get_optional_user)] = None
):
    """List all active categories."""
    categories = await service.list_categories()
    return CategoryListResponse(categories=categories)


@router.post(
    "/categories",
    response_model=CategoryResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Create category",
    description="Create a new activity category. Admin access required."
)
async def create_category(
    data: CategoryCreate,
    service: Annotated[CategoryService, Depends(get_category_service)],
    current_admin: Annotated[TokenPayload, Depends(get_current_admin)]
):
    """Create a new category (admin only)."""
    category = await service.create_category(data)
    return CategoryResponse(**category)


@router.put(
    "/categories/{category_id}",
    response_model=CategoryResponse,
    summary="Update category",
    description="Update an existing category. Admin access required."
)
async def update_category(
    category_id: UUID,
    data: CategoryUpdate,
    service: Annotated[CategoryService, Depends(get_category_service)],
    current_admin: Annotated[TokenPayload, Depends(get_current_admin)]
):
    """Update a category (admin only)."""
    category = await service.update_category(category_id, data)
    return CategoryResponse(**category)
