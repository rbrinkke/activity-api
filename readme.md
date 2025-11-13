# Activities API - Complete Specifications

Complete AI-optimized specifications for building a production-ready Activities Platform API with FastAPI and PostgreSQL.

## 📋 Repository Contents

```
├── specs/
│   ├── activities-api-specifications.md    # Complete API specifications (18 endpoints)
│   ├── database-schema.sql                 # Full PostgreSQL schema with all tables
│   ├── auth-api-specs.md                   # Auth API integration specs (JWT)
│   └── fastapi-blueprint.md                # Universal FastAPI best practices
├── CLAUDE_CODE_INSTRUCTION.md             # Step-by-step build instructions for AI
└── README.md                              # This file
```

## 🎯 What This Is

This repository contains **ultra-detailed specifications** for building the Activities API - a Meet5-style activities platform with features like:

- ✅ Activity CRUD with categories, tags, and locations
- ✅ Advanced search & discovery (nearby, feed, recommendations)
- ✅ Privacy levels (public, friends_only, invite_only)
- ✅ Subscription tiers (free, club, premium)
- ✅ Asymmetric blocking system (with XXL exception)
- ✅ Review & rating system
- ✅ Waitlist management
- ✅ Priority participation for premium users

## 🚀 Quick Start

### For AI Code Agents (Claude Code, Cursor, etc.)

**Read this file first**: [`CLAUDE_CODE_INSTRUCTION.md`](./CLAUDE_CODE_INSTRUCTION.md)

This file contains complete step-by-step instructions to build the entire API from these specifications.

### For Human Developers

1. **Read the specifications** in this order:
   - `specs/fastapi-blueprint.md` - Architecture & patterns
   - `specs/database-schema.sql` - Database structure
   - `specs/activities-api-specifications.md` - Complete API specs

2. **Set up your environment**:
   ```bash
   # Clone this repo
   git clone <repo-url>
   cd activities-api
   
   # Create Python environment
   python -m venv venv
   source venv/bin/activate  # or `venv\Scripts\activate` on Windows
   
   # Install dependencies
   pip install -r requirements.txt
   ```

3. **Set up database**:
   ```bash
   # Start PostgreSQL (with PostGIS for location queries)
   docker run -d \
     --name activities-db \
     -e POSTGRES_PASSWORD=yourpassword \
     -e POSTGRES_DB=activities_db \
     -p 5432:5432 \
     postgis/postgis:15-3.3
   
   # Load schema
   psql -h localhost -U postgres -d activities_db -f specs/database-schema.sql
   ```

4. **Follow the implementation checklist** in `activities-api-specifications.md`

## 📚 Documentation Structure

### 1. API Specifications (`specs/activities-api-specifications.md`)

**18 Complete Endpoints** with:
- Exact HTTP methods and paths
- Request/response schemas with all fields
- Stored procedure mappings (100% SP-based)
- Complete SP logic step-by-step
- Error handling specifications
- Data flow diagrams
- Business rules documentation

**Endpoint Categories**:
- **Activity CRUD**: Create, Read, Update, Cancel, Delete
- **Discovery**: Search, Nearby, Feed, Recommendations
- **Categories**: List, Create, Update (admin)
- **Participants**: List participants, View waitlist
- **Reviews**: Create, Read, Update, Delete
- **Tags**: Popular tags for autocomplete

### 2. Database Schema (`specs/database-schema.sql`)

**Complete PostgreSQL schema** with:
- 30 tables with all indexes
- 15+ enum types
- Utility functions (UUIDv7, update_timestamp)
- Foreign keys and constraints
- Detailed comments
- PostGIS for location queries

**Key Tables**:
- `users` - User accounts with subscription levels
- `activities` - Core activities table
- `participants` - Activity participation tracking
- `user_blocks` - Asymmetric blocking system
- `activity_reviews` - Reviews and ratings
- `categories` - Activity categories
- `communities` - Identity-based communities
- And 23 more...

### 3. Auth API Specs (`specs/auth-api-specs.md`)

**JWT Token Structure** for integration:
- Token payload format
- Subscription level claims
- Ghost mode flag
- Role-based access control

This API integrates with a separate Auth API for user authentication.

### 4. FastAPI Blueprint (`specs/fastapi-blueprint.md`)

**Universal best practices** for FastAPI projects:
- Project structure (routes, services, schemas)
- Responsibility per layer
- Configuration management
- Logging setup (structlog)
- Error handling patterns
- Middleware (correlation IDs)
- Docker setup
- Health checks

## 🏗️ Architecture Principles

### 1. 100% Stored Procedures
**NO direct SQL in application code**. All database operations through stored procedures for:
- Security (SQL injection prevention)
- Performance (query plan caching)
- Maintainability (business logic in one place)
- Testability (test SPs independently)

### 2. Clean Architecture
```
Routes (HTTP layer)
    ↓
Services (Business logic)
    ↓
Stored Procedures (Database operations)
    ↓
Database
```

### 3. JWT Authentication
- Tokens from separate Auth API
- Claims: `user_id`, `subscription_level`, `ghost_mode`, `roles`
- Passed to stored procedures for authorization

### 4. Comprehensive Error Handling
- PostgreSQL errors mapped to HTTP status codes
- Consistent error response format
- Error codes for client handling
- Structured logging with correlation IDs

## 🔐 Critical Business Rules

### Blocking System (ASYMMETRIC)
- User A can block User B independently
- Blocked users cannot see each other's content
- **EXCEPTION**: Blocking does NOT apply to XXL activities

### Privacy Levels
- **public**: Everyone can see (if not blocked)
- **friends_only**: Only accepted friends
- **invite_only**: Only explicitly invited users

### Subscription Tiers
- **free**: Basic features
- **club**: Category filter + priority participation
- **premium**: All features + language filter

### Priority Participation
- Premium/Club users can join immediately
- Free users wait until `joinable_at_free` timestamp

## 📊 Implementation Phases

The specifications include a complete implementation checklist:

**Phase 1**: Setup (project structure, config, database)  
**Phase 2**: Core CRUD (5 endpoints)  
**Phase 3**: Search & Discovery (4 endpoints)  
**Phase 4**: Categories (3 endpoints)  
**Phase 5**: Participants (2 endpoints)  
**Phase 6**: Reviews (4 endpoints)  
**Phase 7**: Testing  
**Phase 8**: Docker deployment

Total: **18 endpoints + 18 stored procedures**

## 🧪 Testing Requirements

Each endpoint requires tests for:
- ✅ Happy path (successful request)
- ✅ Authentication (missing/invalid token)
- ✅ Authorization (wrong permissions)
- ✅ Validation (invalid input)
- ✅ Not found (non-existent resource)
- ✅ Blocking scenarios
- ✅ Privacy level enforcement
- ✅ Subscription restrictions

## 🐳 Docker Setup

Included specifications for:
- Multi-stage Dockerfile
- docker-compose.yml with PostgreSQL + PostGIS
- Health checks
- Environment variables
- Volume management

## 📝 API Documentation

FastAPI provides automatic documentation:
- **Swagger UI**: `/docs`
- **ReDoc**: `/redoc`
- **OpenAPI JSON**: `/openapi.json`

## 🚨 Common Pitfalls (AVOID!)

The specifications include a comprehensive list of common mistakes:

1. ❌ SQL in Python code (use stored procedures!)
2. ❌ Unidirectional blocking check (check BOTH directions!)
3. ❌ Forgetting XXL exception for blocking
4. ❌ Not validating subscription levels
5. ❌ Returning sensitive data when blocked
6. ❌ Forgetting to update counters
7. ❌ Not handling NULL location fields
8. ❌ Missing pagination metadata
9. ❌ Not validating date ranges
10. ❌ Allowing max_participants below current count

## 🎯 Success Criteria

API is complete when:
1. ✅ All 18 endpoints return correct responses
2. ✅ Blocking logic works (including XXL exception)
3. ✅ Privacy levels enforced correctly
4. ✅ Subscription features gated properly
5. ✅ All stored procedures follow specs exactly
6. ✅ Error handling returns correct HTTP codes
7. ✅ JWT authentication works
8. ✅ Docker containers start successfully
9. ✅ `/health` endpoint returns 200
10. ✅ `/docs` shows all endpoints

## 💡 Why These Specifications?

These specifications are designed for **AI code generation** with:

1. **Zero Ambiguity**: Every parameter, type, and constraint specified
2. **Exact Mappings**: Endpoint → Stored Procedure → Database
3. **Complete Logic**: Step-by-step SP implementation
4. **Error Handling**: All error codes and HTTP mappings
5. **Testing Guide**: What and how to test
6. **Best Practices**: Production-ready patterns

A human or AI agent can build the **entire API** from these specifications without asking clarifying questions.

## 📦 Dependencies

```python
fastapi==0.104.1
pydantic==2.5.0
asyncpg==0.29.0
python-jose[cryptography]==3.3.0
uvicorn[standard]==0.24.0
structlog==23.2.0
pytest==7.4.3
pytest-asyncio==0.21.1
```

## 🤝 Integration Points

This API integrates with:
- **Auth API**: JWT token generation and validation
- **Chat API**: External chat service (via `external_chat_id`)
- **Email API**: Notifications and verifications
- **Image API**: Photo uploads and moderation

## 📖 Additional Resources

- [FastAPI Documentation](https://fastapi.tiangolo.com/)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/)
- [asyncpg Documentation](https://magicstack.github.io/asyncpg/)
- [Pydantic Documentation](https://docs.pydantic.dev/)

## 🔗 Related APIs

This is part of a larger platform. Other APIs:
- **Auth API**: User authentication and authorization
- **Participation API**: Join/leave activities, waitlist management
- **Social API**: Friendships, blocking, favorites
- **Communities API**: Posts, comments, reactions
- **Notifications API**: Push and email notifications
- **Moderation API**: Reports, bans, content moderation

## 📄 License

[Your License Here]

## 👥 Contributing

Contributions welcome! Please:
1. Read the specifications thoroughly
2. Follow the FastAPI blueprint
3. Write tests for new features
4. Update documentation

## ⚠️ Important Notes

- **Production Ready**: These specs are for production use
- **Security First**: No SQL injection, proper auth, error handling
- **Performance**: Indexes defined, pagination required, SP-based
- **Testability**: Dependency injection, clear interfaces
- **Maintainability**: Separation of concerns, documented

---

**Built for AI-assisted development while maintaining human readability.**

For questions or issues, please open an issue in this repository.
