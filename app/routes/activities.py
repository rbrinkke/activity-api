"""Activity API routes."""

from uuid import UUID
from decimal import Decimal
from typing import Optional
from fastapi import APIRouter, Depends, Query, status
from typing import Annotated
import structlog

from app.core.database import db
from app.dependencies import CurrentUser
from app.schemas.activity import (
    ActivityCreate,
    ActivityUpdate,
    ActivityCancel,
    ActivityResponse,
    ActivityCancelResponse,
    ActivityDeleteResponse
)
from app.services.activity_service import ActivityService

logger = structlog.get_logger()

router = APIRouter()


def get_activity_service() -> ActivityService:
    """Dependency to get activity service."""
    return ActivityService(db)


@router.post(
    "/activities",
    response_model=ActivityResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Create activity",
    description="Create a new activity with full details including location, tags, and scheduling."
)
async def create_activity(
    data: ActivityCreate,
    current_user: CurrentUser,
    service: Annotated[ActivityService, Depends(get_activity_service)]
):
    """Create a new activity."""
    activity = await service.create_activity(
        user_id=UUID(current_user.user_id),
        data=data
    )
    return activity


@router.get(
    "/activities/{activity_id}",
    response_model=ActivityResponse,
    summary="Get activity by ID",
    description="Retrieve complete details of a single activity with user-specific information."
)
async def get_activity(
    activity_id: UUID,
    current_user: CurrentUser,
    service: Annotated[ActivityService, Depends(get_activity_service)]
):
    """Get activity by ID."""
    activity = await service.get_activity_by_id(
        activity_id=activity_id,
        requesting_user_id=UUID(current_user.user_id)
    )
    return activity


@router.put(
    "/activities/{activity_id}",
    response_model=ActivityResponse,
    summary="Update activity",
    description="Update existing activity details. Only organizer or co-organizers can update."
)
async def update_activity(
    activity_id: UUID,
    data: ActivityUpdate,
    current_user: CurrentUser,
    service: Annotated[ActivityService, Depends(get_activity_service)]
):
    """Update an activity."""
    activity = await service.update_activity(
        activity_id=activity_id,
        user_id=UUID(current_user.user_id),
        data=data
    )
    return activity


@router.post(
    "/activities/{activity_id}/cancel",
    response_model=ActivityCancelResponse,
    summary="Cancel activity",
    description="Cancel an activity. Only organizer can cancel."
)
async def cancel_activity(
    activity_id: UUID,
    data: ActivityCancel,
    current_user: CurrentUser,
    service: Annotated[ActivityService, Depends(get_activity_service)]
):
    """Cancel an activity."""
    result = await service.cancel_activity(
        activity_id=activity_id,
        user_id=UUID(current_user.user_id),
        data=data
    )
    return ActivityCancelResponse(
        activity_id=result['activity_id'],
        status=result['status'],
        cancelled_at=result['cancelled_at'],
        participants_notified=result['participants_notified_count'],
        message="Activity cancelled successfully. All participants have been notified."
    )


@router.delete(
    "/activities/{activity_id}",
    response_model=ActivityDeleteResponse,
    summary="Delete activity",
    description="Permanently delete an activity. Only organizer can delete, only if no other participants."
)
async def delete_activity(
    activity_id: UUID,
    current_user: CurrentUser,
    service: Annotated[ActivityService, Depends(get_activity_service)]
):
    """Delete an activity."""
    result = await service.delete_activity(
        activity_id=activity_id,
        user_id=UUID(current_user.user_id)
    )
    return ActivityDeleteResponse(
        deleted=result['deleted'],
        message=result['message']
    )


# Search & Discovery endpoints
from app.schemas.search import (
    ActivitySearchFilters,
    SearchResponse,
    NearbySearchFilters,
    FeedResponse,
    RecommendationsResponse
)
from app.services.search_service import SearchService


def get_search_service() -> SearchService:
    """Dependency to get search service."""
    return SearchService(db)


@router.get(
    "/activities/search",
    response_model=SearchResponse,
    summary="Search activities",
    description="Search activities with various filters. Language filter requires Premium subscription."
)
async def search_activities(
    current_user: CurrentUser,
    service: Annotated[SearchService, Depends(get_search_service)],
    query: Optional[str] = Query(None, max_length=255, description="Search in title/description"),
    category_id: Optional[UUID] = Query(None, description="Filter by category"),
    activity_type: Optional[str] = Query(None, description="Filter by type"),
    city: Optional[str] = Query(None, max_length=100, description="Filter by city"),
    language: Optional[str] = Query(None, max_length=5, description="Filter by language (Premium)"),
    has_spots_available: Optional[bool] = Query(None, description="Only with available spots"),
    limit: int = Query(20, ge=1, le=100, description="Maximum results"),
    offset: int = Query(0, ge=0, description="Pagination offset")
):
    """Search activities with filters."""
    from app.schemas.activity import ActivityType as ActivityTypeEnum

    # Parse activity type
    activity_type_enum = None
    if activity_type:
        try:
            activity_type_enum = ActivityTypeEnum(activity_type)
        except ValueError:
            pass

    filters = ActivitySearchFilters(
        query=query,
        category_id=category_id,
        activity_type=activity_type_enum,
        city=city,
        language=language,
        has_spots_available=has_spots_available,
        limit=limit,
        offset=offset
    )

    result = await service.search_activities(
        user_id=UUID(current_user.user_id),
        filters=filters
    )
    return SearchResponse(**result)


@router.get(
    "/activities/nearby",
    response_model=SearchResponse,
    summary="Find nearby activities",
    description="Find activities near a specific location using geospatial search."
)
async def nearby_activities(
    current_user: CurrentUser,
    service: Annotated[SearchService, Depends(get_search_service)],
    latitude: Decimal = Query(..., ge=-90, le=90, description="User latitude"),
    longitude: Decimal = Query(..., ge=-180, le=180, description="User longitude"),
    radius_km: float = Query(10.0, ge=0.1, le=100, description="Search radius in km"),
    category_id: Optional[UUID] = Query(None, description="Filter by category"),
    limit: int = Query(20, ge=1, le=100, description="Maximum results"),
    offset: int = Query(0, ge=0, description="Pagination offset")
):
    """Find nearby activities."""
    filters = NearbySearchFilters(
        latitude=latitude,
        longitude=longitude,
        radius_km=radius_km,
        category_id=category_id,
        limit=limit,
        offset=offset
    )

    result = await service.nearby_activities(
        user_id=UUID(current_user.user_id),
        filters=filters
    )
    return SearchResponse(**result)


@router.get(
    "/activities/feed",
    response_model=FeedResponse,
    summary="Personalized feed",
    description="Get personalized activity feed based on user interests and past activities."
)
async def personalized_feed(
    current_user: CurrentUser,
    service: Annotated[SearchService, Depends(get_search_service)],
    limit: int = Query(20, ge=1, le=100, description="Maximum activities")
):
    """Get personalized activity feed."""
    result = await service.personalized_feed(
        user_id=UUID(current_user.user_id),
        limit=limit
    )
    return FeedResponse(**result)


@router.get(
    "/activities/recommendations",
    response_model=RecommendationsResponse,
    summary="AI recommendations",
    description="Get AI-powered activity recommendations based on collaborative filtering."
)
async def get_recommendations(
    current_user: CurrentUser,
    service: Annotated[SearchService, Depends(get_search_service)],
    limit: int = Query(10, ge=1, le=50, description="Maximum recommendations")
):
    """Get AI-powered recommendations."""
    result = await service.recommendations(
        user_id=UUID(current_user.user_id),
        limit=limit
    )
    return RecommendationsResponse(**result)
