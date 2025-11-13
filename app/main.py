"""Main FastAPI application."""

from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import structlog

from app.config import settings
from app.core.database import db
from app.core.logging_config import setup_logging
from app.core.exceptions import setup_exception_handlers
from app.middleware.correlation import CorrelationMiddleware

# Import routers (will be created)
from app.routes import categories, activities, reviews, participants, tags

logger = structlog.get_logger()


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan manager."""
    # Startup
    setup_logging(settings.ENVIRONMENT)
    logger.info("application_startup", version=settings.VERSION, environment=settings.ENVIRONMENT)

    # Connect to database
    await db.connect()

    yield

    # Shutdown
    logger.info("application_shutdown")
    await db.disconnect()


# Create FastAPI application
app = FastAPI(
    title=settings.PROJECT_NAME,
    version=settings.VERSION,
    lifespan=lifespan,
    docs_url="/docs",
    redoc_url="/redoc",
    openapi_url="/openapi.json"
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Correlation ID middleware
app.add_middleware(CorrelationMiddleware)

# Exception handlers
setup_exception_handlers(app)

# Health check endpoint
@app.get("/health", tags=["health"])
async def health_check():
    """Health check endpoint."""
    return {
        "status": "ok",
        "version": settings.VERSION,
        "environment": settings.ENVIRONMENT
    }


# API routes
app.include_router(categories.router, prefix=settings.API_V1_PREFIX, tags=["categories"])
app.include_router(activities.router, prefix=settings.API_V1_PREFIX, tags=["activities"])
app.include_router(participants.router, prefix=settings.API_V1_PREFIX, tags=["participants"])
app.include_router(reviews.router, prefix=settings.API_V1_PREFIX, tags=["reviews"])
app.include_router(tags.router, prefix=settings.API_V1_PREFIX, tags=["tags"])


@app.get("/", tags=["root"])
async def root():
    """Root endpoint with API information."""
    return {
        "name": settings.PROJECT_NAME,
        "version": settings.VERSION,
        "docs": "/docs",
        "health": "/health"
    }
