"""Pydantic schemas for participant endpoints."""

from datetime import datetime
from typing import Optional
from uuid import UUID
from pydantic import BaseModel
from enum import Enum


class ParticipantRole(str, Enum):
    """Participant role enum."""
    ORGANIZER = "organizer"
    CO_ORGANIZER = "co_organizer"
    MEMBER = "member"


class ParticipationStatus(str, Enum):
    """Participation status enum."""
    REGISTERED = "registered"
    WAITLISTED = "waitlisted"
    DECLINED = "declined"
    CANCELLED = "cancelled"


class AttendanceStatus(str, Enum):
    """Attendance status enum."""
    REGISTERED = "registered"
    ATTENDED = "attended"
    NO_SHOW = "no_show"


# Participant info
class ParticipantInfo(BaseModel):
    """Participant information."""
    user_id: UUID
    username: str
    first_name: Optional[str]
    main_photo_url: Optional[str]
    is_verified: bool
    role: ParticipantRole
    participation_status: ParticipationStatus
    attendance_status: AttendanceStatus
    joined_at: datetime


class ParticipantsListResponse(BaseModel):
    """Schema for participants list response."""
    activity_id: UUID
    total_participants: int
    max_participants: int
    participants: list[ParticipantInfo]


# Waitlist
class WaitlistEntry(BaseModel):
    """Waitlist entry information."""
    user_id: UUID
    username: str
    first_name: Optional[str]
    main_photo_url: Optional[str]
    is_verified: bool
    position: int
    joined_at: datetime
    notified_at: Optional[datetime]


class WaitlistResponse(BaseModel):
    """Schema for waitlist response."""
    activity_id: UUID
    total_waitlist: int
    waitlist: list[WaitlistEntry]
