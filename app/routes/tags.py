"""Tag API routes."""

from typing import Annotated, Optional
from fastapi import APIRouter, Depends, Query
import structlog

from app.core.database import db
from app.schemas.tag import PopularTagsResponse, TagResponse
from app.services.tag_service import TagService

logger = structlog.get_logger()

router = APIRouter()


def get_tag_service() -> TagService:
    """Dependency to get tag service."""
    return TagService(db)


@router.get(
    "/activities/tags/popular",
    response_model=PopularTagsResponse,
    summary="Get popular tags",
    description="Get most popular activity tags for autocomplete/suggestions. Public endpoint."
)
async def get_popular_tags(
    service: Annotated[TagService, Depends(get_tag_service)],
    limit: int = Query(50, ge=1, le=100, description="Maximum number of tags to return"),
    prefix: Optional[str] = Query(None, max_length=100, description="Filter tags starting with prefix")
):
    """Get popular tags for autocomplete."""
    tags = await service.get_popular_tags(limit=limit, prefix=prefix)
    return PopularTagsResponse(tags=tags)
