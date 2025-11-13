# Activities API

FastAPI-based REST API for managing activities, built with 100% stored procedures architecture.

## 🎯 Status

**✅ COMPLETE - All 18 Endpoints Implemented!**

✅ **Categories** (3 endpoints)
- GET `/api/v1/categories` - List all categories
- POST `/api/v1/categories` - Create category (admin)
- PUT `/api/v1/categories/{id}` - Update category (admin)

✅ **Activities CRUD** (5 endpoints)
- POST `/api/v1/activities` - Create activity
- GET `/api/v1/activities/{id}` - Get activity by ID
- PUT `/api/v1/activities/{id}` - Update activity
- POST `/api/v1/activities/{id}/cancel` - Cancel activity
- DELETE `/api/v1/activities/{id}` - Delete activity

✅ **Search & Discovery** (4 endpoints)
- GET `/api/v1/activities/search` - Search with filters
- GET `/api/v1/activities/nearby` - Nearby activities (geospatial)
- GET `/api/v1/activities/feed` - Personalized feed
- GET `/api/v1/activities/recommendations` - AI recommendations

✅ **Participants** (2 endpoints)
- GET `/api/v1/activities/{id}/participants` - List participants
- GET `/api/v1/activities/{id}/waitlist` - Get waitlist

✅ **Reviews** (4 endpoints)
- POST `/api/v1/activities/{id}/reviews` - Create review
- GET `/api/v1/activities/{id}/reviews` - List reviews
- PUT `/api/v1/reviews/{id}` - Update review
- DELETE `/api/v1/reviews/{id}` - Delete review

✅ **Tags** (1 endpoint)
- GET `/api/v1/activities/tags/popular` - Get popular tags

## 🚀 Quick Start

### Prerequisites
- Python 3.11+
- PostgreSQL 15+ with PostGIS
- Docker (optional)

### Local Development

1. **Clone and install dependencies**:
```bash
cd activity-api
python -m venv venv
source venv/bin/activate  # or venv\Scripts\activate on Windows
pip install -r requirements.txt
```

2. **Setup database**:
```bash
# Start PostgreSQL with PostGIS
docker run -d \
  --name activities-db \
  -e POSTGRES_USER=activities_user \
  -e POSTGRES_PASSWORD=activities_pass \
  -e POSTGRES_DB=activities_db \
  -p 5432:5432 \
  postgis/postgis:15-3.3

# Load schema
psql -h localhost -U activities_user -d activities_db -f sqlschema

# Load stored procedures
psql -h localhost -U activities_user -d activities_db -f database/procedures/01_categories.sql
psql -h localhost -U activities_user -d activities_db -f database/procedures/02_activities_crud.sql
psql -h localhost -U activities_user -d activities_db -f database/procedures/03_activities_get_update.sql
psql -h localhost -U activities_user -d activities_db -f database/procedures/04_tags.sql
psql -h localhost -U activities_user -d activities_db -f database/procedures/05_participants.sql
psql -h localhost -U activities_user -d activities_db -f database/procedures/06_reviews.sql
psql -h localhost -U activities_user -d activities_db -f database/procedures/07_search_discovery.sql
```

3. **Configure environment**:
```bash
# .env file is already created
# Update JWT_SECRET_KEY for production!
```

4. **Run the API**:
```bash
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

5. **Access API documentation**:
- Swagger UI: http://localhost:8000/docs
- ReDoc: http://localhost:8000/redoc
- Health check: http://localhost:8000/health

### Docker Compose

```bash
docker-compose up -d
```

Access API at http://localhost:8000

## 📚 Architecture

### Core Principles

1. **100% Stored Procedures** - NO direct SQL in Python code
2. **Clean Architecture** - Routes → Services → Stored Procedures
3. **JWT Authentication** - Token-based auth from Auth API
4. **Structured Logging** - JSON logging with correlation IDs
5. **Comprehensive Error Handling** - PostgreSQL errors mapped to HTTP codes

### Project Structure

```
activity-api/
├── app/
│   ├── core/           # Database, security, logging, exceptions
│   ├── middleware/     # Correlation ID middleware
│   ├── routes/         # FastAPI route handlers
│   ├── services/       # Business logic layer
│   ├── schemas/        # Pydantic models
│   ├── config.py       # Configuration management
│   ├── dependencies.py # Dependency injection
│   └── main.py         # FastAPI application
├── database/
│   └── procedures/     # PostgreSQL stored procedures
├── tests/              # Test suites
├── docker-compose.yml
├── Dockerfile
├── requirements.txt
└── sqlschema           # Database schema
```

## 🔐 Authentication

All protected endpoints require JWT token in Authorization header:

```
Authorization: Bearer <jwt_token>
```

Token payload contains:
- `user_id` - User UUID
- `subscription_level` - free, club, or premium
- `ghost_mode` - Premium feature flag
- `roles` - Array of roles (user, admin, moderator)

## 📝 API Examples

### Create Activity

```bash
curl -X POST http://localhost:8000/api/v1/activities \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Morning Hike",
    "description": "Join us for a refreshing morning hike in the mountains",
    "activity_type": "standard",
    "activity_privacy_level": "public",
    "scheduled_at": "2025-12-01T10:00:00Z",
    "max_participants": 10,
    "location": {
      "venue_name": "Mountain Trail",
      "city": "Amsterdam",
      "latitude": 52.370216,
      "longitude": 4.895168
    },
    "tags": ["hiking", "outdoor", "nature"],
    "language": "en"
  }'
```

### List Categories

```bash
curl http://localhost:8000/api/v1/categories
```

### Get Popular Tags

```bash
curl "http://localhost:8000/api/v1/activities/tags/popular?limit=10&prefix=hik"
```

## 🧪 Testing

```bash
# Run tests
pytest

# With coverage
pytest --cov=app --cov-report=html
```

## 📊 Database Schema

Complete schema in `sqlschema` file includes:

- **30 tables** with proper indexes
- **15+ enum types** for type safety
- **Foreign keys and constraints**
- **Utility functions** (UUIDv7, update_timestamp)
- **PostGIS** for location queries

Key tables:
- `users` - User accounts with subscription levels
- `activities` - Core activities table
- `participants` - Activity participation
- `user_blocks` - Asymmetric blocking system
- `activity_reviews` - Reviews and ratings
- `categories` - Activity categories

## 🔒 Security Features

- JWT token validation
- SQL injection prevention (stored procedures only)
- Rate limiting (optional)
- CORS configuration
- Error message sanitization
- Structured logging for audit trails

## ✅ Implementation Complete

All 18 endpoints have been successfully implemented with:
- 100% Stored Procedures architecture
- Comprehensive error handling
- Blocking system enforcement
- Privacy level checks
- Subscription-based features
- Geospatial search capabilities
- Collaborative filtering recommendations

Total: 18 stored procedures covering all business logic

## 📖 API Documentation

Complete API specifications available in:
- `werkzaamheden.md` - Full endpoint specifications
- `auth-api-specifications` - JWT token structure
- `/docs` - Interactive Swagger UI (when running)

## 🤝 Integration

This API integrates with:
- **Auth API** - JWT token generation
- **Chat API** - External chat via `external_chat_id`
- **Email API** - Notifications
- **Image API** - Photo uploads

## 📄 License

[Your License Here]

## 👥 Support

For issues or questions, please open an issue in the GitHub repository.

---

**Built with FastAPI, PostgreSQL, and 100% Stored Procedures Architecture**
