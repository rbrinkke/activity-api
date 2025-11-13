"""Participant API routes."""

from uuid import UUID
from fastapi import APIRouter, Depends
from typing import Annotated
import structlog

from app.core.database import db
from app.dependencies import CurrentUser
from app.schemas.participant import ParticipantsListResponse, WaitlistResponse
from app.services.participant_service import ParticipantService

logger = structlog.get_logger()

router = APIRouter()


def get_participant_service() -> ParticipantService:
    """Dependency to get participant service."""
    return ParticipantService(db)


@router.get(
    "/activities/{activity_id}/participants",
    response_model=ParticipantsListResponse,
    summary="List activity participants",
    description="Get list of all participants for an activity. Respects privacy settings and blocking."
)
async def list_participants(
    activity_id: UUID,
    current_user: CurrentUser,
    service: Annotated[ParticipantService, Depends(get_participant_service)]
):
    """List all participants of an activity."""
    result = await service.list_participants(
        activity_id=activity_id,
        requesting_user_id=UUID(current_user.user_id)
    )
    return ParticipantsListResponse(**result)


@router.get(
    "/activities/{activity_id}/waitlist",
    response_model=WaitlistResponse,
    summary="Get activity waitlist",
    description="Get waitlist for a full activity. Only visible to organizer and co-organizers."
)
async def get_waitlist(
    activity_id: UUID,
    current_user: CurrentUser,
    service: Annotated[ParticipantService, Depends(get_participant_service)]
):
    """Get waitlist for an activity."""
    result = await service.get_waitlist(
        activity_id=activity_id,
        requesting_user_id=UUID(current_user.user_id)
    )
    return WaitlistResponse(**result)
