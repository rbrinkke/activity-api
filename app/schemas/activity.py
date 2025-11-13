"""Pydantic schemas for activity endpoints."""

from datetime import datetime
from decimal import Decimal
from typing import Optional, List
from uuid import UUID
from pydantic import BaseModel, Field, field_validator
from enum import Enum


# Enums
class ActivityType(str, Enum):
    """Activity type enum."""
    STANDARD = "standard"
    XXL = "xxl"
    WOMENS_ONLY = "womens_only"
    MENS_ONLY = "mens_only"


class ActivityPrivacyLevel(str, Enum):
    """Activity privacy level enum."""
    PUBLIC = "public"
    FRIENDS_ONLY = "friends_only"
    INVITE_ONLY = "invite_only"


class ActivityStatus(str, Enum):
    """Activity status enum."""
    DRAFT = "draft"
    PUBLISHED = "published"
    CANCELLED = "cancelled"
    COMPLETED = "completed"


# Location schemas
class LocationBase(BaseModel):
    """Base location schema."""
    venue_name: Optional[str] = Field(None, max_length=255)
    address_line1: Optional[str] = Field(None, max_length=255)
    address_line2: Optional[str] = Field(None, max_length=255)
    city: Optional[str] = Field(None, max_length=100)
    state_province: Optional[str] = Field(None, max_length=100)
    postal_code: Optional[str] = Field(None, max_length=20)
    country: Optional[str] = Field(None, max_length=100)
    latitude: Optional[Decimal] = Field(None, ge=-90, le=90)
    longitude: Optional[Decimal] = Field(None, ge=-180, le=180)
    place_id: Optional[str] = Field(None, max_length=255)

    @field_validator('latitude', 'longitude')
    @classmethod
    def validate_coordinates(cls, v, info):
        """Validate that both lat and lng are provided together."""
        # This validation happens at model level
        return v


class LocationResponse(LocationBase):
    """Location response schema."""
    location_id: UUID


# Activity schemas
class ActivityCreate(BaseModel):
    """Schema for creating an activity."""

    category_id: Optional[UUID] = None
    title: str = Field(..., min_length=1, max_length=255)
    description: str = Field(..., min_length=10)
    activity_type: ActivityType = ActivityType.STANDARD
    activity_privacy_level: ActivityPrivacyLevel = ActivityPrivacyLevel.PUBLIC
    scheduled_at: datetime
    duration_minutes: Optional[int] = Field(None, gt=0)
    joinable_at_free: Optional[datetime] = None
    max_participants: int = Field(..., ge=2, le=1000)
    location: Optional[LocationBase] = None
    tags: List[str] = Field(default_factory=list, max_length=20)
    language: str = Field("en", min_length=2, max_length=5)
    external_chat_id: Optional[str] = Field(None, max_length=255)

    @field_validator('tags')
    @classmethod
    def validate_tags(cls, v: List[str]) -> List[str]:
        """Validate tags list."""
        if len(v) > 20:
            raise ValueError('Maximum 20 tags allowed')
        return [tag.strip()[:100] for tag in v if tag.strip()]


class ActivityUpdate(BaseModel):
    """Schema for updating an activity."""

    category_id: Optional[UUID] = None
    title: Optional[str] = Field(None, min_length=1, max_length=255)
    description: Optional[str] = Field(None, min_length=10)
    activity_type: Optional[ActivityType] = None
    activity_privacy_level: Optional[ActivityPrivacyLevel] = None
    scheduled_at: Optional[datetime] = None
    duration_minutes: Optional[int] = Field(None, gt=0)
    joinable_at_free: Optional[datetime] = None
    max_participants: Optional[int] = Field(None, ge=2, le=1000)
    location: Optional[LocationBase] = None
    tags: Optional[List[str]] = Field(None, max_length=20)
    language: Optional[str] = Field(None, min_length=2, max_length=5)
    external_chat_id: Optional[str] = Field(None, max_length=255)

    @field_validator('tags')
    @classmethod
    def validate_tags(cls, v: Optional[List[str]]) -> Optional[List[str]]:
        """Validate tags list."""
        if v is not None:
            if len(v) > 20:
                raise ValueError('Maximum 20 tags allowed')
            return [tag.strip()[:100] for tag in v if tag.strip()]
        return v


class ActivityCancel(BaseModel):
    """Schema for cancelling an activity."""
    cancellation_reason: Optional[str] = Field(None, max_length=500)


# Organizer info
class OrganizerInfo(BaseModel):
    """Organizer information."""
    user_id: UUID
    username: str
    first_name: Optional[str]
    main_photo_url: Optional[str]
    is_verified: bool


class CategoryInfo(BaseModel):
    """Category information."""
    category_id: UUID
    name: str


class ActivityResponse(BaseModel):
    """Schema for activity response."""

    activity_id: UUID
    organizer: OrganizerInfo
    category: Optional[CategoryInfo] = None
    title: str
    description: str
    activity_type: ActivityType
    activity_privacy_level: ActivityPrivacyLevel
    status: ActivityStatus
    scheduled_at: datetime
    duration_minutes: Optional[int]
    joinable_at_free: Optional[datetime]
    max_participants: int
    current_participants_count: int
    waitlist_count: int
    location: Optional[LocationResponse] = None
    tags: List[str]
    language: str
    external_chat_id: Optional[str]
    created_at: datetime
    updated_at: Optional[datetime] = None
    completed_at: Optional[datetime] = None
    cancelled_at: Optional[datetime] = None

    # User-specific fields (from stored procedure)
    user_participation_status: Optional[str] = None
    user_can_join: bool = False
    user_can_edit: bool = False
    is_blocked: bool = False

    class Config:
        from_attributes = True


class ActivityCancelResponse(BaseModel):
    """Schema for activity cancellation response."""
    activity_id: UUID
    status: ActivityStatus
    cancelled_at: datetime
    participants_notified: int
    message: str


class ActivityDeleteResponse(BaseModel):
    """Schema for activity deletion response."""
    deleted: bool
    message: str
