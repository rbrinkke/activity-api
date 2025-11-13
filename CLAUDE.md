# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Activity API** is a FastAPI-based microservice for managing social activities with geo-spatial search, privacy controls, and subscription-based features. Part of a larger activity platform with 11+ microservices.

**Key Features**:
- Activity CRUD with geo-spatial proximity search (PostGIS)
- Privacy levels (public, friends_only, invite_only)
- Subscription tiers (free, club, premium) with gated features
- Asymmetric blocking system with XXL activity exception
- Review & rating system with attendance verification
- Category management and tag-based discovery
- Priority participation for premium users

## Architecture

### 100% Stored Procedure Pattern

**CRITICAL**: All database operations go through PostgreSQL stored procedures. NO direct SQL in Python code.

**Why?**
- SQL injection prevention
- Query plan caching (performance)
- Business logic centralized in database
- Independent testing of database logic

**Pattern**:
```python
# Service layer calls stored procedure
result = await self.db.fetch_one(
    "SELECT * FROM activity.sp_get_activity_by_id($1, $2)",
    activity_id, user_id
)
```

**Stored procedures location**: `database/procedures/*.sql` (19 procedures total)

### Layer Responsibilities

```
Routes (app/routes/*.py)
  ↓ HTTP request/response, parameter extraction
Services (app/services/*.py)
  ↓ Business logic, stored procedure calls
Stored Procedures (database/procedures/*.sql)
  ↓ Database operations, authorization, data access
Database (activitydb.activity schema)
```

**Never mix responsibilities**: Routes don't call database, services don't handle HTTP details.

### Database Connection

**Central Database**: Uses shared `activity-postgres-db` container (not service-specific database)
- Database: `activitydb`
- Schema: `activity` (search_path set automatically)
- Connection pool: 10-50 connections
- Port: 8007 (external), 8000 (internal)

**Connection management**:
- Pool created on startup (`app.main:lifespan`)
- Closed on shutdown
- `search_path` set to `activity,public` automatically

## Common Commands

### Development

```bash
# Start service (requires infrastructure first!)
docker compose up -d

# Rebuild after code changes (CRITICAL - restart alone doesn't update code!)
docker compose build activity-api --no-cache
docker compose restart activity-api

# View logs
docker compose logs -f activity-api

# Stop service
docker compose down
```

### Local Development (without Docker)

```bash
# Install dependencies
pip install -r requirements.txt

# Set environment variables
export $(cat .env | xargs)

# Run with auto-reload
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

# Run with custom log level
LOG_LEVEL=DEBUG uvicorn app.main:app --reload
```

### Database Operations

```bash
# Access central database
docker exec -it activity-postgres-db psql -U postgres -d activitydb

# Check schema
\dn
\dt activity.*
\df activity.*  # List stored procedures

# Test stored procedure
SELECT * FROM activity.sp_list_categories();

# Check activity count
SELECT COUNT(*) FROM activity.activities;
```

### Code Quality

```bash
# Format code
black app/

# Lint
ruff check app/

# Type check
mypy app/

# Run all quality checks
black app/ && ruff check app/ && mypy app/
```

### Health Checks

```bash
# Check API health
curl http://localhost:8007/health

# Check OpenAPI docs
open http://localhost:8007/docs

# Check specific endpoint with auth
export TOKEN="your-jwt-token"
curl -H "Authorization: Bearer $TOKEN" \
  http://localhost:8007/api/v1/activities
```

## Critical Business Rules

### 1. Asymmetric Blocking System

**CRITICAL**: Blocking is bidirectional but independent.

```sql
-- Check if EITHER user blocks the other
WHERE NOT EXISTS (
    SELECT 1 FROM activity.user_blocks
    WHERE (blocker_user_id = p_user_a AND blocked_user_id = p_user_b)
       OR (blocker_user_id = p_user_b AND blocked_user_id = p_user_a)
)
```

**XXL Activity Exception**: Blocking does NOT apply to XXL-sized activities.

```sql
-- Bypass blocking for XXL activities
AND (a.activity_type != 'xxl' OR NOT EXISTS (blocking check))
```

**Applies to**: All search, feed, recommendations, participant lists.

### 2. Privacy Level Enforcement

**Three levels**:
- `public`: Anyone can see (if not blocked)
- `friends_only`: Only accepted friends (`friend_status = 'accepted'`)
- `invite_only`: Only explicitly invited users

**Implementation**: Checked in stored procedures, not Python code.

### 3. Subscription-Based Features

**Tiers**:
- `free`: Basic features, wait for `joinable_at_free` timestamp
- `club`: Category filter, priority participation (join immediately)
- `premium`: All features, language filter

**Language filter**: Only premium users can filter by language in search.

**Priority participation**: Premium/Club users can join before `joinable_at_free`.

### 4. Review Attendance Verification

**Rule**: Only users who attended (status = 'attended') can leave reviews.

**Implementation**: Enforced in `sp_create_activity_review` stored procedure.

## API Endpoints

### Activities (9 endpoints)

| Method | Path | Stored Procedure | Auth |
|--------|------|------------------|------|
| POST | /api/v1/activities | sp_create_activity | Required |
| GET | /api/v1/activities/{id} | sp_get_activity_by_id | Required |
| PUT | /api/v1/activities/{id} | sp_update_activity | Required |
| POST | /api/v1/activities/{id}/cancel | sp_cancel_activity | Required |
| DELETE | /api/v1/activities/{id} | sp_delete_activity | Required |
| GET | /api/v1/activities/search | sp_search_activities | Required |
| GET | /api/v1/activities/nearby | sp_get_nearby_activities | Required |
| GET | /api/v1/activities/feed | sp_get_activity_feed | Required |
| GET | /api/v1/activities/recommendations | sp_get_recommended_activities | Required |

### Participants (2 endpoints)

| Method | Path | Stored Procedure | Auth |
|--------|------|------------------|------|
| GET | /api/v1/activities/{id}/participants | sp_get_activity_participants | Required |
| GET | /api/v1/activities/{id}/waitlist | sp_get_activity_waitlist | Required |

### Reviews (4 endpoints)

| Method | Path | Stored Procedure | Auth |
|--------|------|------------------|------|
| POST | /api/v1/activities/{id}/reviews | sp_create_activity_review | Required |
| GET | /api/v1/activities/{id}/reviews | sp_get_activity_reviews | Required |
| PUT | /api/v1/reviews/{id} | sp_update_review | Required |
| DELETE | /api/v1/reviews/{id} | sp_delete_review | Required |

### Categories (3 endpoints)

| Method | Path | Stored Procedure | Auth |
|--------|------|------------------|------|
| GET | /api/v1/categories | sp_list_categories | Optional |
| POST | /api/v1/categories | sp_create_category | Required (admin) |
| PUT | /api/v1/categories/{id} | sp_update_category | Required (admin) |

### Tags (1 endpoint)

| Method | Path | Stored Procedure | Auth |
|--------|------|------------------|------|
| GET | /api/v1/activities/tags/popular | sp_get_popular_tags | Optional |

**Total**: 19 endpoints, 19 stored procedures

## Project Structure

```
/mnt/d/activity/activity-api/
├── app/
│   ├── main.py                  # FastAPI app, lifespan, middleware
│   ├── config.py                # Pydantic settings from env vars
│   ├── dependencies.py          # JWT validation, CurrentUser
│   ├── core/
│   │   ├── database.py          # asyncpg pool, query execution
│   │   ├── exceptions.py        # Custom exceptions, error mapping
│   │   ├── logging_config.py    # Structlog setup (JSON logs)
│   │   └── security.py          # JWT decoding, token validation
│   ├── middleware/
│   │   └── correlation.py       # X-Correlation-ID injection
│   ├── routes/
│   │   ├── activities.py        # Activity CRUD + search endpoints
│   │   ├── participants.py      # Participant list endpoints
│   │   ├── reviews.py           # Review CRUD endpoints
│   │   ├── categories.py        # Category management
│   │   └── tags.py              # Popular tags endpoint
│   ├── services/
│   │   ├── activity_service.py  # Activity business logic
│   │   ├── participant_service.py
│   │   ├── review_service.py
│   │   ├── category_service.py
│   │   ├── search_service.py    # Search/nearby/feed/recommendations
│   │   └── tag_service.py
│   └── schemas/
│       ├── activity.py          # Activity Pydantic models
│       ├── participant.py
│       ├── review.py
│       ├── category.py
│       ├── search.py            # Search filters, responses
│       └── tag.py
├── database/
│   ├── activity_stored_procedures.sql  # Complete SP file (legacy)
│   └── procedures/              # Modular SP files
│       ├── 01_categories.sql
│       ├── 02_activities_crud.sql
│       ├── 03_activities_get_update.sql
│       ├── 04_tags.sql
│       ├── 05_participants.sql
│       ├── 06_reviews.sql
│       └── 07_search_discovery.sql
├── scripts/
│   └── demo/                    # Demo data scripts
├── docker-compose.yml           # Container definition
├── Dockerfile                   # Multi-stage build
├── requirements.txt             # Python dependencies
├── .env                         # Environment variables (git ignored)
├── .env.example                 # Example configuration
└── CLAUDE.md                    # This file
```

## Configuration

### Environment Variables

**Required**:
```bash
DATABASE_URL=postgresql://postgres:PASSWORD@activity-postgres-db:5432/activitydb
JWT_SECRET_KEY=your-secure-secret-min-32-chars  # MUST match auth-api!
```

**Optional**:
```bash
ENVIRONMENT=development          # development|staging|production
DEBUG=true                       # Enable debug mode
LOG_LEVEL=INFO                   # DEBUG|INFO|WARNING|ERROR
LOG_FORMAT=json                  # json|console
API_V1_PREFIX=/api/v1           # API path prefix
PORT=8000                        # Internal port (mapped to 8007)
ALLOWED_ORIGINS=*                # CORS origins (comma-separated)
```

**Database pool settings**:
```bash
DB_POOL_MIN_SIZE=10              # Minimum connections
DB_POOL_MAX_SIZE=50              # Maximum connections
DB_COMMAND_TIMEOUT=60            # Query timeout (seconds)
```

### JWT Token Structure

**Claims required** (from auth-api):
```json
{
  "sub": "user-uuid",              // Required: user_id
  "subscription_level": "premium",  // Required: free|club|premium
  "ghost_mode": false,             // Optional: privacy flag
  "roles": ["user"],               // Optional: role-based access
  "exp": 1234567890                // Required: expiration
}
```

**Validation**: JWT_SECRET_KEY must match auth-api exactly!

## Adding New Endpoints

### 1. Create Stored Procedure

```sql
-- database/procedures/XX_feature.sql
CREATE OR REPLACE FUNCTION activity.sp_your_operation(
    p_user_id UUID,
    p_param TEXT
)
RETURNS TABLE(...) AS $$
BEGIN
    -- Check blocking
    IF EXISTS (blocking check) THEN
        RAISE EXCEPTION 'ERR_FORBIDDEN: User is blocked';
    END IF;

    -- Check privacy level
    IF NOT EXISTS (privacy check) THEN
        RAISE EXCEPTION 'ERR_FORBIDDEN: Access denied';
    END IF;

    -- Business logic
    RETURN QUERY SELECT ...;
END;
$$ LANGUAGE plpgsql;
```

**Deploy**: Execute against `activitydb` database.

### 2. Create Pydantic Schemas

```python
# app/schemas/feature.py
from pydantic import BaseModel, Field
from uuid import UUID

class FeatureCreate(BaseModel):
    field: str = Field(..., min_length=1, max_length=255)

class FeatureResponse(BaseModel):
    id: UUID
    field: str
```

### 3. Create Service

```python
# app/services/feature_service.py
class FeatureService:
    def __init__(self, db: Database):
        self.db = db

    async def create_feature(self, user_id: UUID, data: FeatureCreate) -> dict:
        try:
            result = await self.db.fetch_one(
                "SELECT * FROM activity.sp_create_feature($1, $2)",
                user_id, data.field
            )
            if not result:
                raise NotFoundException("Feature not created")
            return result
        except Exception as e:
            raise map_db_error(e)
```

### 4. Create Route

```python
# app/routes/feature.py
from fastapi import APIRouter, Depends
from app.dependencies import CurrentUser

router = APIRouter()

@router.post("/features", response_model=FeatureResponse)
async def create_feature(
    data: FeatureCreate,
    current_user: CurrentUser,
    service: Annotated[FeatureService, Depends(get_feature_service)]
):
    return await service.create_feature(UUID(current_user.user_id), data)
```

### 5. Register Router

```python
# app/main.py
from app.routes import feature

app.include_router(feature.router, prefix=settings.API_V1_PREFIX, tags=["features"])
```

## Error Handling

### PostgreSQL Exception Mapping

**Pattern**: Stored procedures raise exceptions with `ERR_` prefix.

```sql
-- In stored procedure
RAISE EXCEPTION 'ERR_NOT_FOUND: Activity not found';
RAISE EXCEPTION 'ERR_FORBIDDEN: Access denied';
RAISE EXCEPTION 'ERR_CONFLICT: Already exists';
```

**Python mapping** (`app/core/exceptions.py`):
```python
def map_db_error(e: Exception) -> Exception:
    msg = str(e)
    if "ERR_NOT_FOUND" in msg:
        return NotFoundException(msg)
    if "ERR_FORBIDDEN" in msg:
        return ForbiddenException(msg)
    # ... more mappings
```

### Custom Exceptions

```python
# Defined in app/core/exceptions.py
raise NotFoundException("Activity not found")        # 404
raise ForbiddenException("Access denied")           # 403
raise ConflictException("Duplicate entry")          # 409
raise ValidationException("Invalid input")          # 422
```

**HTTP mapping**: Handled by exception handlers in `app/core/exceptions.py`.

## Logging

### Structured Logging with Structlog

**Pattern**:
```python
import structlog

logger = structlog.get_logger()

# Log with context
logger.info("activity_created",
           activity_id=str(activity_id),
           user_id=str(user_id),
           category="sports")

# Error logging
logger.error("database_error",
            error=str(e),
            query="sp_get_activity_by_id")
```

**Output format**: JSON in production, console in development.

**Correlation IDs**: Automatically added by `CorrelationMiddleware` (X-Correlation-ID header).

## Testing

**No test suite currently**: This is a greenfield project.

**Testing strategy** (when implemented):
```bash
# Create tests/ directory
mkdir -p tests/{routes,services,integration}

# Add pytest fixtures
# tests/conftest.py - database, auth mocks

# Run tests
pytest tests/ -v
pytest tests/ --cov=app --cov-report=html
```

## Deployment

### Infrastructure Requirements

**CRITICAL**: Start infrastructure before this service!

```bash
# From parent directory
cd /mnt/d/activity
./scripts/start-infra.sh  # Starts PostgreSQL, Redis, MailHog

# Verify infrastructure
./scripts/status.sh
docker ps | grep activity-postgres-db  # Should be running
```

### Start Service

```bash
cd /mnt/d/activity/activity-api

# Build and start
docker compose build
docker compose up -d

# Check logs
docker compose logs -f activity-api

# Verify health
curl http://localhost:8007/health
```

### Network Configuration

**External network**: `activity-network` (shared with all services)
- Created by infrastructure setup
- Allows service-to-service communication
- Must exist before starting service

```bash
# Check network exists
docker network ls | grep activity-network

# Create manually if needed
docker network create activity-network
```

## Common Issues

### "Database pool not initialized"

**Cause**: Application started before database connection established.

**Fix**: Check database connectivity, restart service.

```bash
docker logs activity-api  # Check startup logs
docker exec -it activity-postgres-db psql -U postgres -c "SELECT 1;"
docker compose restart activity-api
```

### Code Changes Not Reflected

**Cause**: Docker restart uses old image.

**Fix**: Always rebuild after code changes!

```bash
# Wrong
docker compose restart activity-api

# Right
docker compose build activity-api --no-cache
docker compose restart activity-api
```

### JWT Validation Failures

**Cause**: JWT_SECRET_KEY mismatch between auth-api and activity-api.

**Fix**: Ensure secrets match exactly.

```bash
# Check both services
cat /mnt/d/activity/auth-api/.env | grep JWT_SECRET_KEY
cat /mnt/d/activity/activity-api/.env | grep JWT_SECRET_KEY
# Must be identical!
```

### "Network activity-network not found"

**Cause**: Infrastructure not started or network not created.

**Fix**: Start infrastructure first.

```bash
cd /mnt/d/activity
./scripts/start-infra.sh
```

## Integration with Other Services

### Auth API

**Purpose**: JWT token generation and validation.

**Integration**:
- Shared JWT_SECRET_KEY (must match exactly)
- Token claims: user_id, subscription_level, roles
- Dependency: `app.dependencies.CurrentUser` validates token

### Participation API

**Purpose**: Join/leave activities, waitlist management.

**Integration**:
- Reads from `activity.activities` table
- Updates `activity.activity_participants` table
- Service-to-service calls for participant status

### Social API

**Purpose**: Friendships, blocking, favorites.

**Integration**:
- Blocking checks in stored procedures
- Friend status for privacy enforcement
- Favorites for recommendations

### Community API

**Purpose**: Posts, comments about activities.

**Integration**:
- Links activities to community posts
- Activity IDs referenced in posts table

## Performance Considerations

### Database Indexes

**Critical indexes** (defined in central schema):
- `activities.category_id` - Category filtering
- `activities.organizer_user_id` - User's activities
- `activities.status` - Published activities only
- `activities.scheduled_at` - Date range queries
- Spatial index on location - Proximity search

### Query Optimization

**Pagination**: Always use LIMIT/OFFSET in stored procedures.

**Filtering**: Apply WHERE clauses before JOINs when possible.

**Connection pooling**: Reuses connections, avoid creating new pools.

### Geo-Spatial Queries

**PostGIS optimization**:
- Use spatial indexes (GIST)
- `ST_DWithin` for distance-based filtering
- `ST_Distance` for exact distance calculation
- Combine with bounding box pre-filter

## Security Best Practices

### SQL Injection Prevention

**100% stored procedures**: No string concatenation, all parameterized.

### Error Message Sanitization

**Generic errors**: Don't leak internal details to clients.

```python
# Good
raise NotFoundException("Resource not found")

# Bad
raise Exception(f"Activity {activity_id} not found in database")
```

### Authorization Checks

**In stored procedures**: Not in Python code.

```sql
-- Check organizer
IF p_user_id != (SELECT organizer_user_id FROM activities WHERE id = p_activity_id) THEN
    RAISE EXCEPTION 'ERR_FORBIDDEN: Not activity organizer';
END IF;
```

### CORS Configuration

**Production**: Whitelist specific origins, not `*`.

```bash
ALLOWED_ORIGINS=https://app.example.com,https://mobile.example.com
```

## Documentation

**API documentation**: Auto-generated by FastAPI
- Swagger UI: http://localhost:8007/docs
- ReDoc: http://localhost:8007/redoc
- OpenAPI JSON: http://localhost:8007/openapi.json

**Additional docs**:
- `README_API.md` - Complete API specifications
- `VERIFICATION_COMPLETE.md` - Implementation verification
- `MIGRATION_TO_CENTRAL_DB.md` - Database migration notes

## Key Differences from Other Services

### vs. auth-api
- **auth-api**: User authentication, JWT issuance, password management
- **activity-api**: Activity CRUD, geo-search, privacy enforcement

### vs. participation-api
- **participation-api**: Join/leave activities, waitlist management, attendance tracking
- **activity-api**: Activity details, search, reviews (reads participant data)

### vs. social-api
- **social-api**: Friendships, blocking, user relationships
- **activity-api**: Uses blocking data, enforces privacy (reads social data)

**Pattern**: Activity-api is primarily READ from other domains, WRITE to activities domain.
