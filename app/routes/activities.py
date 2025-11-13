"""Activity API routes."""

from uuid import UUID
from fastapi import APIRouter, Depends, status
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


# Search & Discovery endpoints (to be implemented)
# - GET /activities/search
# - GET /activities/nearby
# - GET /activities/feed
# - GET /activities/recommendations
