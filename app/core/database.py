"""Database connection and query execution."""

import asyncpg
from contextlib import asynccontextmanager
from typing import Any, Dict, List, Optional
import structlog

from app.config import settings

logger = structlog.get_logger()


class Database:
    """Database connection pool manager."""

    def __init__(self):
        self.pool: Optional[asyncpg.Pool] = None

    async def connect(self):
        """Create database connection pool."""
        try:
            self.pool = await asyncpg.create_pool(
                dsn=settings.DATABASE_URL,
                min_size=settings.DB_POOL_MIN_SIZE,
                max_size=settings.DB_POOL_MAX_SIZE,
                command_timeout=settings.DB_COMMAND_TIMEOUT,
                server_settings={
                    'search_path': 'activity,public',
                    'timezone': 'UTC',
                    'application_name': 'activities_api'
                }
            )
            logger.info(
                "database_connected",
                pool_size=f"{settings.DB_POOL_MIN_SIZE}-{settings.DB_POOL_MAX_SIZE}"
            )
        except Exception as e:
            logger.error("database_connection_failed", error=str(e))
            raise

    async def disconnect(self):
        """Close database connection pool."""
        if self.pool:
            await self.pool.close()
            logger.info("database_disconnected")

    @asynccontextmanager
    async def transaction(self):
        """Context manager for database transactions."""
        if not self.pool:
            raise RuntimeError("Database pool not initialized")

        async with self.pool.acquire() as conn:
            async with conn.transaction():
                yield conn

    async def fetch_one(
        self,
        query: str,
        *args,
        timeout: Optional[float] = None
    ) -> Optional[Dict[str, Any]]:
        """Fetch single row from database."""
        if not self.pool:
            raise RuntimeError("Database pool not initialized")

        async with self.pool.acquire() as conn:
            row = await conn.fetchrow(query, *args, timeout=timeout)
            return dict(row) if row else None

    async def fetch_all(
        self,
        query: str,
        *args,
        timeout: Optional[float] = None
    ) -> List[Dict[str, Any]]:
        """Fetch all rows from database."""
        if not self.pool:
            raise RuntimeError("Database pool not initialized")

        async with self.pool.acquire() as conn:
            rows = await conn.fetch(query, *args, timeout=timeout)
            return [dict(row) for row in rows]

    async def execute(
        self,
        query: str,
        *args,
        timeout: Optional[float] = None
    ) -> str:
        """Execute query and return status."""
        if not self.pool:
            raise RuntimeError("Database pool not initialized")

        async with self.pool.acquire() as conn:
            return await conn.execute(query, *args, timeout=timeout)


# Global database instance
db = Database()
