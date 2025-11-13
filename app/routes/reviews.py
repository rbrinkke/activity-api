"""Review API routes."""

from uuid import UUID
from typing import Optional
from fastapi import APIRouter, Depends, Query, status
from typing import Annotated
import structlog

from app.core.database import db
from app.dependencies import CurrentUser, OptionalUser
from app.schemas.review import (
    ReviewCreate,
    ReviewUpdate,
    ReviewResponse,
    ReviewsListResponse,
    ReviewDeleteResponse
)
from app.services.review_service import ReviewService

logger = structlog.get_logger()

router = APIRouter()


def get_review_service() -> ReviewService:
    """Dependency to get review service."""
    return ReviewService(db)


@router.post(
    "/activities/{activity_id}/reviews",
    response_model=ReviewResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Create review",
    description="Create a review for a completed activity. Only participants who attended can review."
)
async def create_review(
    activity_id: UUID,
    data: ReviewCreate,
    current_user: CurrentUser,
    service: Annotated[ReviewService, Depends(get_review_service)]
):
    """Create a review for an activity."""
    review = await service.create_review(
        activity_id=activity_id,
        user_id=UUID(current_user.user_id),
        data=data
    )
    return review


@router.get(
    "/activities/{activity_id}/reviews",
    response_model=ReviewsListResponse,
    summary="List reviews",
    description="Get all reviews for an activity. Anonymous reviews hide reviewer information."
)
async def list_reviews(
    activity_id: UUID,
    service: Annotated[ReviewService, Depends(get_review_service)],
    limit: int = Query(50, ge=1, le=100, description="Maximum reviews to return"),
    offset: int = Query(0, ge=0, description="Number of reviews to skip"),
    current_user: OptionalUser = None
):
    """List all reviews for an activity."""
    requesting_user_id = UUID(current_user.user_id) if current_user else None
    result = await service.list_reviews(
        activity_id=activity_id,
        requesting_user_id=requesting_user_id,
        limit=limit,
        offset=offset
    )
    return ReviewsListResponse(**result)


@router.put(
    "/reviews/{review_id}",
    response_model=ReviewResponse,
    summary="Update review",
    description="Update your own review. Only the reviewer can update their review."
)
async def update_review(
    review_id: UUID,
    data: ReviewUpdate,
    current_user: CurrentUser,
    service: Annotated[ReviewService, Depends(get_review_service)]
):
    """Update a review."""
    review = await service.update_review(
        review_id=review_id,
        user_id=UUID(current_user.user_id),
        data=data
    )
    return review


@router.delete(
    "/reviews/{review_id}",
    response_model=ReviewDeleteResponse,
    summary="Delete review",
    description="Delete your own review. Only the reviewer can delete their review."
)
async def delete_review(
    review_id: UUID,
    current_user: CurrentUser,
    service: Annotated[ReviewService, Depends(get_review_service)]
):
    """Delete a review."""
    result = await service.delete_review(
        review_id=review_id,
        user_id=UUID(current_user.user_id)
    )
    return ReviewDeleteResponse(
        deleted=result['deleted'],
        message=result['message']
    )
