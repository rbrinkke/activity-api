"""Dependency injection for FastAPI routes."""

from fastapi import Depends
from typing import Annotated

from app.core.database import db
from app.core.security import TokenPayload, get_current_user, get_optional_user


# Database dependency
async def get_db():
    """Dependency to inject database connection."""
    return db


# Authentication dependencies
CurrentUser = Annotated[TokenPayload, Depends(get_current_user)]
OptionalUser = Annotated[TokenPayload | None, Depends(get_optional_user)]
DatabaseDep = Annotated[db.__class__, Depends(get_db)]
