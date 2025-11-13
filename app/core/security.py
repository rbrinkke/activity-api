"""JWT token validation and security."""

from typing import Dict, Optional
from fastapi import Depends, Header
from jose import JWTError, jwt
import structlog

from app.config import settings
from app.core.exceptions import UnauthorizedException

logger = structlog.get_logger()


class TokenPayload:
    """Decoded JWT token payload."""

    def __init__(self, payload: Dict):
        self.user_id: str = payload.get("sub")
        self.email: Optional[str] = payload.get("email")
        self.subscription_level: str = payload.get("subscription_level", "free")
        self.ghost_mode: bool = payload.get("ghost_mode", False)
        self.roles: list = payload.get("roles", ["user"])
        self.org_id: Optional[str] = payload.get("org_id")
        self.exp: Optional[int] = payload.get("exp")
        self.iat: Optional[int] = payload.get("iat")
        self.token_type: str = payload.get("type", "access")

    def has_role(self, role: str) -> bool:
        """Check if user has a specific role."""
        return role in self.roles

    def is_admin(self) -> bool:
        """Check if user is an admin."""
        return "admin" in self.roles

    def is_premium(self) -> bool:
        """Check if user has premium or club subscription."""
        return self.subscription_level in ["premium", "club"]

    def is_club_or_premium(self) -> bool:
        """Check if user has club or premium subscription."""
        return self.subscription_level in ["premium", "club"]


def decode_token(token: str) -> TokenPayload:
    """Decode and validate JWT token."""
    try:
        payload = jwt.decode(
            token,
            settings.JWT_SECRET_KEY,
            algorithms=[settings.JWT_ALGORITHM]
        )
        return TokenPayload(payload)
    except JWTError as e:
        logger.warning("jwt_decode_failed", error=str(e))
        raise UnauthorizedException("Invalid or expired token")


async def get_current_user(
    authorization: Optional[str] = Header(None)
) -> TokenPayload:
    """
    Dependency to get current user from JWT token.

    Extracts token from Authorization header (Bearer <token>).
    """
    if not authorization:
        raise UnauthorizedException("Missing authorization header")

    # Extract token from "Bearer <token>" format
    parts = authorization.split()
    if len(parts) != 2 or parts[0].lower() != "bearer":
        raise UnauthorizedException("Invalid authorization header format")

    token = parts[1]
    return decode_token(token)


async def get_current_admin(
    current_user: TokenPayload = Depends(get_current_user)
) -> TokenPayload:
    """Dependency to require admin role."""
    if not current_user.is_admin():
        raise UnauthorizedException("Admin access required")
    return current_user


async def get_optional_user(
    authorization: Optional[str] = Header(None)
) -> Optional[TokenPayload]:
    """
    Dependency for optional authentication.

    Returns user if token is provided and valid, None otherwise.
    """
    if not authorization:
        return None

    try:
        parts = authorization.split()
        if len(parts) != 2 or parts[0].lower() != "bearer":
            return None

        token = parts[1]
        return decode_token(token)
    except Exception:
        return None
