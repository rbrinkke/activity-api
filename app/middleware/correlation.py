"""Correlation ID middleware for request tracking."""

import uuid
from typing import Callable
from fastapi import Request, Response
from starlette.middleware.base import BaseHTTPMiddleware
import structlog

from app.core.logging_config import add_correlation_id, clear_correlation_id

logger = structlog.get_logger()


class CorrelationMiddleware(BaseHTTPMiddleware):
    """
    Middleware to add correlation ID to all requests.

    Adds X-Correlation-ID header to requests and responses for tracing.
    """

    async def dispatch(self, request: Request, call_next: Callable) -> Response:
        # Get correlation ID from header or generate new one
        correlation_id = request.headers.get("X-Correlation-ID") or str(uuid.uuid4())

        # Add to logging context
        add_correlation_id(correlation_id)

        try:
            # Log request
            logger.info(
                "request_started",
                method=request.method,
                path=request.url.path,
                client_host=request.client.host if request.client else None
            )

            # Process request
            response = await call_next(request)

            # Add correlation ID to response headers
            response.headers["X-Correlation-ID"] = correlation_id

            # Log response
            logger.info(
                "request_completed",
                method=request.method,
                path=request.url.path,
                status_code=response.status_code
            )

            return response

        except Exception as e:
            logger.error(
                "request_failed",
                method=request.method,
                path=request.url.path,
                error=str(e)
            )
            raise

        finally:
            # Clear correlation ID from context
            clear_correlation_id()
