"""Structured logging configuration using structlog."""

import logging
import sys
from typing import Any, Dict

import structlog
from pythonjsonlogger import jsonlogger

from app.config import settings


def setup_logging(environment: str = "development"):
    """Configure structured logging for the application."""

    # Configure standard logging
    log_level = getattr(logging, settings.LOG_LEVEL.upper(), logging.INFO)

    # Create handler based on log format
    if settings.LOG_FORMAT == "json":
        # JSON formatter for production
        handler = logging.StreamHandler(sys.stdout)
        formatter = jsonlogger.JsonFormatter(
            fmt="%(timestamp)s %(level)s %(name)s %(message)s",
            rename_fields={"levelname": "level", "asctime": "timestamp"}
        )
        handler.setFormatter(formatter)
    else:
        # Console formatter for development
        handler = logging.StreamHandler(sys.stdout)
        formatter = logging.Formatter(
            fmt="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
            datefmt="%Y-%m-%d %H:%M:%S"
        )
        handler.setFormatter(formatter)

    # Configure root logger
    root_logger = logging.getLogger()
    root_logger.handlers.clear()
    root_logger.addHandler(handler)
    root_logger.setLevel(log_level)

    # Silence noisy loggers
    logging.getLogger("uvicorn.access").setLevel(logging.WARNING)
    logging.getLogger("asyncpg").setLevel(logging.WARNING)

    # Configure structlog
    processors = [
        structlog.contextvars.merge_contextvars,
        structlog.processors.add_log_level,
        structlog.processors.TimeStamper(fmt="iso"),
        structlog.processors.StackInfoRenderer(),
    ]

    if settings.LOG_FORMAT == "json":
        # JSON output for production
        processors.extend([
            structlog.processors.format_exc_info,
            structlog.processors.JSONRenderer()
        ])
    else:
        # Console output for development
        processors.extend([
            structlog.processors.ExceptionPrettyPrinter(),
            structlog.dev.ConsoleRenderer()
        ])

    structlog.configure(
        processors=processors,
        wrapper_class=structlog.make_filtering_bound_logger(log_level),
        context_class=dict,
        logger_factory=structlog.PrintLoggerFactory(),
        cache_logger_on_first_use=True,
    )

    logger = structlog.get_logger()
    logger.info(
        "logging_configured",
        environment=environment,
        log_level=settings.LOG_LEVEL,
        log_format=settings.LOG_FORMAT
    )


def add_correlation_id(correlation_id: str):
    """Add correlation ID to logging context."""
    structlog.contextvars.bind_contextvars(correlation_id=correlation_id)


def clear_correlation_id():
    """Clear correlation ID from logging context."""
    structlog.contextvars.unbind_contextvars("correlation_id")
