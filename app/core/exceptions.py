"""Custom exceptions and error handlers."""

from typing import Any, Dict, Optional
from fastapi import HTTPException, Request, status
from fastapi.responses import JSONResponse
from fastapi.exceptions import RequestValidationError
import structlog
import asyncpg

logger = structlog.get_logger()


class APIException(HTTPException):
    """Base API exception."""

    def __init__(
        self,
        status_code: int,
        error_code: str,
        message: str,
        details: Optional[Dict[str, Any]] = None
    ):
        self.error_code = error_code
        self.message = message
        self.details = details or {}
        super().__init__(status_code=status_code, detail=message)


class NotFoundException(APIException):
    """Resource not found (404)."""

    def __init__(self, resource: str, details: Optional[Dict[str, Any]] = None):
        super().__init__(
            status_code=status.HTTP_404_NOT_FOUND,
            error_code="NOT_FOUND",
            message=f"{resource} not found",
            details=details
        )


class ForbiddenException(APIException):
    """Access forbidden (403)."""

    def __init__(self, message: str = "Access forbidden", details: Optional[Dict[str, Any]] = None):
        super().__init__(
            status_code=status.HTTP_403_FORBIDDEN,
            error_code="FORBIDDEN",
            message=message,
            details=details
        )


class ValidationException(APIException):
    """Validation error (422)."""

    def __init__(self, message: str, details: Optional[Dict[str, Any]] = None):
        super().__init__(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            error_code="VALIDATION_ERROR",
            message=message,
            details=details
        )


class ConflictException(APIException):
    """Resource conflict (409)."""

    def __init__(self, message: str, details: Optional[Dict[str, Any]] = None):
        super().__init__(
            status_code=status.HTTP_409_CONFLICT,
            error_code="CONFLICT",
            message=message,
            details=details
        )


class UnauthorizedException(APIException):
    """Unauthorized access (401)."""

    def __init__(self, message: str = "Unauthorized", details: Optional[Dict[str, Any]] = None):
        super().__init__(
            status_code=status.HTTP_401_UNAUTHORIZED,
            error_code="UNAUTHORIZED",
            message=message,
            details=details
        )


def map_db_error(error: Exception) -> APIException:
    """Map database errors to API exceptions."""

    error_str = str(error)

    # Check for custom error codes in the error message
    if 'ERR_NOT_FOUND' in error_str or 'NOT_FOUND' in error_str:
        return NotFoundException("Resource", {"database_error": error_str})
    elif 'ERR_FORBIDDEN' in error_str or 'FORBIDDEN' in error_str:
        return ForbiddenException(error_str)
    elif 'ERR_BLOCKED' in error_str or 'BLOCKED' in error_str:
        return ForbiddenException("User is blocked")
    elif 'ERR_VALIDATION' in error_str or 'VALIDATION' in error_str:
        return ValidationException(error_str)
    elif 'ERR_CONFLICT' in error_str or 'CONFLICT' in error_str:
        return ConflictException(error_str)
    elif 'ERR_UNAUTHORIZED' in error_str or 'UNAUTHORIZED' in error_str:
        return UnauthorizedException(error_str)
    elif 'ERR_PREMIUM_REQUIRED' in error_str:
        return ForbiddenException("Premium subscription required")
    elif 'ERR_USER_NOT_FOUND' in error_str:
        return NotFoundException("User")
    elif 'ERR_ACTIVITY_NOT_FOUND' in error_str:
        return NotFoundException("Activity")
    elif 'ERR_CATEGORY_NOT_FOUND' in error_str:
        return NotFoundException("Category")

    # Handle foreign key violations
    if isinstance(error, asyncpg.exceptions.ForeignKeyViolationError):
        return NotFoundException("Referenced resource")

    # Handle unique constraint violations
    if isinstance(error, asyncpg.exceptions.UniqueViolationError):
        return ConflictException("Resource already exists", {"database_error": error_str})

    # Default to internal server error
    logger.error("unhandled_database_error", error=error_str, error_type=type(error).__name__)

    # Import settings to check DEBUG mode
    from app.config import settings

    return APIException(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        error_code="DATABASE_ERROR",
        message="An internal error occurred",
        details={"error": error_str} if settings.DEBUG else {}
    )


async def api_exception_handler(request: Request, exc: APIException) -> JSONResponse:
    """Handle API exceptions."""
    logger.warning(
        "api_exception",
        error_code=exc.error_code,
        message=exc.message,
        status_code=exc.status_code,
        path=request.url.path
    )

    return JSONResponse(
        status_code=exc.status_code,
        content={
            "error": {
                "code": exc.error_code,
                "message": exc.message,
                "details": exc.details
            }
        }
    )


async def validation_exception_handler(request: Request, exc: RequestValidationError) -> JSONResponse:
    """Handle validation errors."""
    logger.warning(
        "validation_error",
        errors=exc.errors(),
        path=request.url.path
    )

    return JSONResponse(
        status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
        content={
            "error": {
                "code": "VALIDATION_ERROR",
                "message": "Request validation failed",
                "details": {
                    "errors": exc.errors()
                }
            }
        }
    )


async def generic_exception_handler(request: Request, exc: Exception) -> JSONResponse:
    """Handle generic exceptions."""
    logger.error(
        "unhandled_exception",
        error=str(exc),
        error_type=type(exc).__name__,
        path=request.url.path
    )

    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content={
            "error": {
                "code": "INTERNAL_ERROR",
                "message": "An internal error occurred"
            }
        }
    )


def setup_exception_handlers(app):
    """Register exception handlers with FastAPI app."""
    app.add_exception_handler(APIException, api_exception_handler)
    app.add_exception_handler(RequestValidationError, validation_exception_handler)
    app.add_exception_handler(Exception, generic_exception_handler)
