"""Pydantic schemas for search and discovery endpoints."""

from datetime import datetime
from decimal import Decimal
from typing import Optional, List
from uuid import UUID
from pydantic import BaseModel, Field
from app.schemas.activity import ActivityType, ActivityPrivacyLevel, ActivityStatus


class ActivitySearchFilters(BaseModel):
    """Filters for activity search."""
    query: Optional[str] = Field(None, max_length=255, description="Search query (title, description)")
    category_id: Optional[UUID] = Field(None, description="Filter by category")
    activity_type: Optional[ActivityType] = Field(None, description="Filter by activity type")
    city: Optional[str] = Field(None, max_length=100, description="Filter by city")
    language: Optional[str] = Field(None, max_length=5, description="Filter by language (Premium)")
    tags: Optional[List[str]] = Field(None, max_length=10, description="Filter by tags (match any)")
    date_from: Optional[datetime] = Field(None, description="Filter activities from this date")
    date_to: Optional[datetime] = Field(None, description="Filter activities until this date")
    has_spots_available: Optional[bool] = Field(None, description="Only activities with available spots")
    limit: int = Field(20, ge=1, le=100, description="Maximum results")
    offset: int = Field(0, ge=0, description="Pagination offset")


class ActivitySummary(BaseModel):
    """Simplified activity information for lists."""
    activity_id: UUID
    title: str
    description: str
    activity_type: ActivityType
    scheduled_at: datetime
    duration_minutes: Optional[int]
    max_participants: int
    current_participants_count: int
    city: Optional[str]
    language: str
    tags: List[str]
    organizer_username: str
    organizer_is_verified: bool
    category_name: Optional[str]
    distance_km: Optional[float] = None  # For nearby search


class SearchResponse(BaseModel):
    """Schema for search response."""
    total_results: int
    limit: int
    offset: int
    activities: List[ActivitySummary]


class NearbySearchFilters(BaseModel):
    """Filters for nearby activities search."""
    latitude: Decimal = Field(..., ge=-90, le=90, description="User latitude")
    longitude: Decimal = Field(..., ge=-180, le=180, description="User longitude")
    radius_km: float = Field(10.0, ge=0.1, le=100, description="Search radius in km")
    category_id: Optional[UUID] = Field(None, description="Filter by category")
    date_from: Optional[datetime] = Field(None, description="Filter from this date")
    limit: int = Field(20, ge=1, le=100, description="Maximum results")
    offset: int = Field(0, ge=0, description="Pagination offset")


class FeedResponse(BaseModel):
    """Schema for personalized feed response."""
    activities: List[ActivitySummary]
    reason: Optional[str] = Field(None, description="Why this was recommended")


class RecommendationsResponse(BaseModel):
    """Schema for AI recommendations response."""
    activities: List[ActivitySummary]
    recommendation_reason: Optional[str] = Field(None, description="Recommendation algorithm used")
