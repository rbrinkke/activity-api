"""Pydantic schemas for review endpoints."""

from datetime import datetime
from typing import Optional
from uuid import UUID
from pydantic import BaseModel, Field


class ReviewCreate(BaseModel):
    """Schema for creating a review."""
    rating: int = Field(..., ge=1, le=5, description="Rating from 1 to 5")
    review_text: Optional[str] = Field(None, max_length=2000, description="Review text")
    is_anonymous: bool = Field(False, description="Post review anonymously")


class ReviewUpdate(BaseModel):
    """Schema for updating a review."""
    rating: Optional[int] = Field(None, ge=1, le=5, description="Rating from 1 to 5")
    review_text: Optional[str] = Field(None, max_length=2000, description="Review text")
    is_anonymous: Optional[bool] = Field(None, description="Post review anonymously")


class ReviewerInfo(BaseModel):
    """Reviewer information (if not anonymous)."""
    user_id: UUID
    username: str
    first_name: Optional[str]
    main_photo_url: Optional[str]
    is_verified: bool


class ReviewResponse(BaseModel):
    """Schema for review response."""
    review_id: UUID
    activity_id: UUID
    reviewer: Optional[ReviewerInfo] = None  # None if anonymous
    rating: int
    review_text: Optional[str]
    is_anonymous: bool
    created_at: datetime
    updated_at: Optional[datetime]
    is_own_review: bool = False  # True if this is the requesting user's review


class ReviewsListResponse(BaseModel):
    """Schema for reviews list response."""
    activity_id: UUID
    total_reviews: int
    average_rating: Optional[float]
    reviews: list[ReviewResponse]


class ReviewDeleteResponse(BaseModel):
    """Schema for review deletion response."""
    deleted: bool
    message: str
