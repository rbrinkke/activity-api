"""Pydantic schemas for category endpoints."""

from datetime import datetime
from typing import Optional
from uuid import UUID
from pydantic import BaseModel, Field, field_validator


class CategoryBase(BaseModel):
    """Base category schema."""

    name: str = Field(..., min_length=1, max_length=100, description="Category name")
    slug: str = Field(..., min_length=1, max_length=100, description="URL-friendly slug")
    description: Optional[str] = Field(None, description="Category description")
    icon_url: Optional[str] = Field(None, max_length=500, description="Category icon URL")
    display_order: int = Field(0, ge=0, description="Display order")

    @field_validator('slug')
    @classmethod
    def validate_slug(cls, v: str) -> str:
        """Validate slug format (lowercase, hyphens, numbers only)."""
        if not v.replace('-', '').replace('_', '').isalnum():
            raise ValueError('Slug must contain only lowercase letters, numbers, and hyphens')
        return v.lower()


class CategoryCreate(CategoryBase):
    """Schema for creating a category."""
    pass


class CategoryUpdate(BaseModel):
    """Schema for updating a category."""

    name: Optional[str] = Field(None, min_length=1, max_length=100)
    slug: Optional[str] = Field(None, min_length=1, max_length=100)
    description: Optional[str] = None
    icon_url: Optional[str] = Field(None, max_length=500)
    display_order: Optional[int] = Field(None, ge=0)
    is_active: Optional[bool] = None

    @field_validator('slug')
    @classmethod
    def validate_slug(cls, v: Optional[str]) -> Optional[str]:
        """Validate slug format."""
        if v and not v.replace('-', '').replace('_', '').isalnum():
            raise ValueError('Slug must contain only lowercase letters, numbers, and hyphens')
        return v.lower() if v else None


class CategoryResponse(CategoryBase):
    """Schema for category response."""

    category_id: UUID
    is_active: bool
    created_at: datetime

    class Config:
        from_attributes = True


class CategoryListResponse(BaseModel):
    """Schema for category list response."""

    categories: list[CategoryResponse]
