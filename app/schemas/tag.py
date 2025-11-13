"""Pydantic schemas for tag endpoints."""

from pydantic import BaseModel, Field


class TagResponse(BaseModel):
    """Schema for tag response."""
    tag: str
    usage_count: int


class PopularTagsResponse(BaseModel):
    """Schema for popular tags list response."""
    tags: list[TagResponse]
