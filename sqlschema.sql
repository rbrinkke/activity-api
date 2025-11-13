# ACTIVITIES API - COMPLETE SPECIFICATIONS FOR AI CODE GENERATION

## TABLE OF CONTENTS
1. [API Overview](#api-overview)
2. [Authentication & Authorization](#authentication--authorization)
3. [Endpoint Specifications](#endpoint-specifications)
4. [Stored Procedure Specifications](#stored-procedure-specifications)
5. [Error Handling](#error-handling)
6. [Data Flow Diagrams](#data-flow-diagrams)

---

## API OVERVIEW

### Purpose
The Activities API manages the complete lifecycle of activities including creation, discovery, participation management, reviews, and recommendations.

### Technology Stack
- **Framework**: FastAPI (Python)
- **Database**: PostgreSQL (schema: `activity`)
- **Access Pattern**: 100% stored procedures (NO direct SQL queries allowed)
- **Authentication**: JWT tokens (from Auth API)

### Core Responsibilities
1. Activity CRUD operations
2. Activity search and discovery
3. Category management
4. Tag management
5. Location management
6. Review and rating system
7. Activity feed generation
8. Activity recommendations

---

## AUTHENTICATION & AUTHORIZATION

### JWT Token Structure
Every endpoint receives JWT token in Authorization header:
```
Authorization: Bearer <jwt_token>
```

### Token Payload (decoded)
```json
{
  "user_id": "uuid",
  "subscription_level": "free|club|premium",
  "ghost_mode": true|false,
  "roles": ["user", "admin", "moderator"],
  "exp": 1234567890
}
```

### Authorization Rules
- **Free users**: Basic activity access, view public activities
- **Club users**: Filter by category, priority participation (joinable_at_free)
- **Premium users**: All Club features + language filtering, category filtering
- **Admin/Moderator**: Additional moderation endpoints

---

## ENDPOINT SPECIFICATIONS

### SECTION 1: ACTIVITY CRUD OPERATIONS

---

#### ENDPOINT 1.1: CREATE ACTIVITY
**Purpose**: Create a new activity with full details including location, tags, and scheduling.

**HTTP Method**: `POST`  
**Path**: `/api/v1/activities`  
**Authentication**: Required (user role)

**Request Headers**:
```
Authorization: Bearer <jwt_token>
Content-Type: application/json
```

**Request Body**:
```json
{
  "category_id": "uuid | null",
  "title": "string (1-255 chars, required)",
  "description": "string (required, min 10 chars)",
  "activity_type": "standard | xxl | womens_only | mens_only",
  "activity_privacy_level": "public | friends_only | invite_only",
  "scheduled_at": "ISO8601 timestamp (future date required)",
  "duration_minutes": "integer | null (positive)",
  "joinable_at_free": "ISO8601 timestamp | null (for priority participation)",
  "max_participants": "integer (required, min 2, max 1000)",
  "location": {
    "venue_name": "string | null",
    "address_line1": "string | null",
    "address_line2": "string | null",
    "city": "string | null",
    "state_province": "string | null",
    "postal_code": "string | null",
    "country": "string | null",
    "latitude": "decimal | null (-90 to 90)",
    "longitude": "decimal | null (-180 to 180)",
    "place_id": "string | null"
  },
  "tags": ["string array, max 20 items, each max 100 chars"],
  "language": "string (ISO 639-1 code, default 'en')",
  "external_chat_id": "string | null"
}
```

**Stored Procedure**: `activity.sp_create_activity`

**SP Input Parameters**:
```sql
p_organizer_user_id UUID,
p_category_id UUID,
p_title VARCHAR(255),
p_description TEXT,
p_activity_type activity.activity_type,
p_activity_privacy_level activity.activity_privacy_level,
p_scheduled_at TIMESTAMP WITH TIME ZONE,
p_duration_minutes INT,
p_joinable_at_free TIMESTAMP WITH TIME ZONE,
p_max_participants INT,
p_language VARCHAR(5),
p_external_chat_id VARCHAR(255),
-- Location parameters
p_venue_name VARCHAR(255),
p_address_line1 VARCHAR(255),
p_address_line2 VARCHAR(255),
p_city VARCHAR(100),
p_state_province VARCHAR(100),
p_postal_code VARCHAR(20),
p_country VARCHAR(100),
p_latitude DECIMAL(10, 8),
p_longitude DECIMAL(11, 8),
p_place_id VARCHAR(255),
-- Tags as JSON array
p_tags JSONB
```

**SP Output**:
```sql
-- Returns single row
activity_id UUID,
organizer_user_id UUID,
category_id UUID,
title VARCHAR(255),
description TEXT,
activity_type activity.activity_type,
activity_privacy_level activity.activity_privacy_level,
status activity.activity_status,
scheduled_at TIMESTAMP WITH TIME ZONE,
duration_minutes INT,
joinable_at_free TIMESTAMP WITH TIME ZONE,
max_participants INT,
current_participants_count INT,
waitlist_count INT,
location_name VARCHAR(255),
city VARCHAR(100),
language VARCHAR(5),
external_chat_id VARCHAR(255),
created_at TIMESTAMP WITH TIME ZONE,
location JSONB,  -- Full location object
tags TEXT[]  -- Array of tags
```

**SP Logic**:
1. Validate `p_organizer_user_id` exists in `activity.users` AND status = 'active'
2. Validate `p_category_id` exists in `activity.categories` AND is_active = TRUE (if provided)
3. Validate `p_scheduled_at` is in the future (> NOW())
4. Validate `p_joinable_at_free` >= NOW() (if provided)
5. Validate `p_max_participants` between 2 and 1000
6. Validate tags array has max 20 items
7. Insert into `activity.activities` with status = 'published'
8. Insert into `activity.activity_locations` (if location data provided)
9. Insert tags into `activity.activity_tags` (one row per tag)
10. Insert organizer as participant in `activity.participants` with role = 'organizer' and participation_status = 'registered'
11. Set `current_participants_count` = 1
12. Increment `activities_created_count` in `activity.users` for organizer
13. Return complete activity data with location and tags

**Success Response** (201 Created):
```json
{
  "activity_id": "uuid",
  "organizer_user_id": "uuid",
  "category_id": "uuid | null",
  "title": "string",
  "description": "string",
  "activity_type": "standard",
  "activity_privacy_level": "public",
  "status": "published",
  "scheduled_at": "ISO8601",
  "duration_minutes": 120,
  "joinable_at_free": "ISO8601 | null",
  "max_participants": 10,
  "current_participants_count": 1,
  "waitlist_count": 0,
  "location": {
    "location_id": "uuid",
    "venue_name": "string",
    "address_line1": "string",
    "city": "string",
    "latitude": 52.370216,
    "longitude": 4.895168
  },
  "tags": ["hiking", "outdoor", "nature"],
  "language": "en",
  "external_chat_id": "string | null",
  "created_at": "ISO8601"
}
```

**Error Responses**:
- `400 Bad Request`: Invalid input (see error handling section)
- `401 Unauthorized`: Invalid or missing JWT token
- `403 Forbidden`: User banned or suspended
- `404 Not Found`: Category not found or inactive
- `422 Unprocessable Entity`: Validation errors (scheduled_at in past, max_participants out of range)

---

#### ENDPOINT 1.2: GET ACTIVITY BY ID
**Purpose**: Retrieve complete details of a single activity.

**HTTP Method**: `GET`  
**Path**: `/api/v1/activities/{activity_id}`  
**Authentication**: Required (user role)

**Path Parameters**:
- `activity_id`: UUID (required)

**Query Parameters**: None

**Stored Procedure**: `activity.sp_get_activity_by_id`

**SP Input Parameters**:
```sql
p_activity_id UUID,
p_requesting_user_id UUID  -- From JWT token
```

**SP Output**:
```sql
-- Returns single row or NULL
activity_id UUID,
organizer_user_id UUID,
organizer_username VARCHAR(100),
organizer_first_name VARCHAR(100),
organizer_main_photo_url VARCHAR(500),
organizer_is_verified BOOLEAN,
category_id UUID,
category_name VARCHAR(100),
title VARCHAR(255),
description TEXT,
activity_type activity.activity_type,
activity_privacy_level activity.activity_privacy_level,
status activity.activity_status,
scheduled_at TIMESTAMP WITH TIME ZONE,
duration_minutes INT,
joinable_at_free TIMESTAMP WITH TIME ZONE,
max_participants INT,
current_participants_count INT,
waitlist_count INT,
location_name VARCHAR(255),
city VARCHAR(100),
language VARCHAR(5),
external_chat_id VARCHAR(255),
created_at TIMESTAMP WITH TIME ZONE,
updated_at TIMESTAMP WITH TIME ZONE,
completed_at TIMESTAMP WITH TIME ZONE,
cancelled_at TIMESTAMP WITH TIME ZONE,
location JSONB,  -- Full location details
tags TEXT[],  -- Array of tags
user_participation_status VARCHAR(50),  -- 'not_participating' | 'registered' | 'waitlisted' | etc
user_can_join BOOLEAN,  -- Business logic check
user_can_edit BOOLEAN,  -- Is organizer or co-organizer
is_blocked BOOLEAN  -- True if organizer blocked requesting user OR vice versa
```

**SP Logic**:
1. Validate `p_activity_id` exists in `activity.activities`
2. Check if `p_requesting_user_id` is blocked by organizer (in `activity.user_blocks`)
3. Check if organizer is blocked by `p_requesting_user_id`
4. If blocked (either direction) AND activity_type != 'xxl': Return `is_blocked = TRUE`, hide sensitive data
5. If activity_privacy_level = 'friends_only': Check friendship in `activity.friendships`
6. If activity_privacy_level = 'invite_only': Check invitation in `activity.activity_invitations`
7. Join with `activity.users` for organizer details
8. Join with `activity.categories` for category details
9. Join with `activity.activity_locations` for location details
10. Aggregate tags from `activity.activity_tags`
11. Check participation status in `activity.participants` for requesting user
12. Calculate `user_can_join` based on:
    - Activity not cancelled or completed
    - Not already participating
    - Not blocked
    - Privacy level allows access
    - If joinable_at_free is set AND user is free: check if NOW() >= joinable_at_free
13. Calculate `user_can_edit` based on:
    - User is organizer OR co_organizer in `activity.participants`

**Success Response** (200 OK):
```json
{
  "activity_id": "uuid",
  "organizer": {
    "user_id": "uuid",
    "username": "string",
    "first_name": "string",
    "main_photo_url": "string",
    "is_verified": true
  },
  "category": {
    "category_id": "uuid",
    "name": "string"
  },
  "title": "string",
  "description": "string",
  "activity_type": "standard",
  "activity_privacy_level": "public",
  "status": "published",
  "scheduled_at": "ISO8601",
  "duration_minutes": 120,
  "joinable_at_free": "ISO8601 | null",
  "max_participants": 10,
  "current_participants_count": 5,
  "waitlist_count": 2,
  "location": {
    "location_id": "uuid",
    "venue_name": "string",
    "address_line1": "string",
    "city": "string",
    "country": "string",
    "latitude": 52.370216,
    "longitude": 4.895168
  },
  "tags": ["hiking", "outdoor"],
  "language": "en",
  "external_chat_id": "string | null",
  "created_at": "ISO8601",
  "updated_at": "ISO8601",
  "user_participation_status": "registered",
  "user_can_join": false,
  "user_can_edit": false,
  "is_blocked": false
}
```

**Error Responses**:
- `401 Unauthorized`: Invalid or missing JWT token
- `403 Forbidden`: No access (privacy level restrictions, blocked)
- `404 Not Found`: Activity does not exist

---

#### ENDPOINT 1.3: UPDATE ACTIVITY
**Purpose**: Update existing activity details. Only organizer or co-organizers can update.

**HTTP Method**: `PUT`  
**Path**: `/api/v1/activities/{activity_id}`  
**Authentication**: Required (user role)

**Path Parameters**:
- `activity_id`: UUID (required)

**Request Body**: (All fields optional except activity_id)
```json
{
  "category_id": "uuid | null",
  "title": "string (1-255 chars)",
  "description": "string (min 10 chars)",
  "activity_type": "standard | xxl | womens_only | mens_only",
  "activity_privacy_level": "public | friends_only | invite_only",
  "scheduled_at": "ISO8601 timestamp",
  "duration_minutes": "integer | null",
  "joinable_at_free": "ISO8601 timestamp | null",
  "max_participants": "integer (min current_participants_count)",
  "location": {
    "venue_name": "string | null",
    "address_line1": "string | null",
    "address_line2": "string | null",
    "city": "string | null",
    "state_province": "string | null",
    "postal_code": "string | null",
    "country": "string | null",
    "latitude": "decimal | null",
    "longitude": "decimal | null",
    "place_id": "string | null"
  },
  "tags": ["string array, max 20 items"],
  "language": "string (ISO 639-1)",
  "external_chat_id": "string | null"
}
```

**Stored Procedure**: `activity.sp_update_activity`

**SP Input Parameters**:
```sql
p_activity_id UUID,
p_user_id UUID,  -- From JWT token
p_category_id UUID,
p_title VARCHAR(255),
p_description TEXT,
p_activity_type activity.activity_type,
p_activity_privacy_level activity.activity_privacy_level,
p_scheduled_at TIMESTAMP WITH TIME ZONE,
p_duration_minutes INT,
p_joinable_at_free TIMESTAMP WITH TIME ZONE,
p_max_participants INT,
p_language VARCHAR(5),
p_external_chat_id VARCHAR(255),
-- Location parameters
p_venue_name VARCHAR(255),
p_address_line1 VARCHAR(255),
p_address_line2 VARCHAR(255),
p_city VARCHAR(100),
p_state_province VARCHAR(100),
p_postal_code VARCHAR(20),
p_country VARCHAR(100),
p_latitude DECIMAL(10, 8),
p_longitude DECIMAL(11, 8),
p_place_id VARCHAR(255),
-- Tags
p_tags JSONB,
-- Flag to track what changed (for notifications)
OUT p_fields_changed TEXT[]
```

**SP Output**: Same as sp_get_activity_by_id

**SP Logic**:
1. Validate `p_activity_id` exists AND status NOT IN ('cancelled', 'completed')
2. Validate `p_user_id` is organizer OR co_organizer in `activity.participants`
3. If `p_max_participants` is being reduced: Validate it's >= current_participants_count
4. If `p_scheduled_at` changed: Validate new time is in future
5. If `p_category_id` changed: Validate category exists and is_active = TRUE
6. Update `activity.activities` table
7. UPSERT `activity.activity_locations` (INSERT if not exists, UPDATE if exists)
8. Delete all existing tags from `activity.activity_tags`
9. Insert new tags from `p_tags` array
10. Track which fields changed and return in `p_fields_changed`
11. If significant fields changed (scheduled_at, location, title): Generate notification records for all participants
12. Return updated activity data

**Success Response** (200 OK): Same structure as GET activity

**Error Responses**:
- `400 Bad Request`: Invalid input data
- `401 Unauthorized`: Invalid or missing JWT token
- `403 Forbidden`: User is not organizer/co-organizer
- `404 Not Found`: Activity does not exist
- `422 Unprocessable Entity`: Cannot reduce max_participants below current count, scheduled_at in past

---

#### ENDPOINT 1.4: CANCEL ACTIVITY
**Purpose**: Cancel an activity. Only organizer can cancel.

**HTTP Method**: `POST`  
**Path**: `/api/v1/activities/{activity_id}/cancel`  
**Authentication**: Required (user role)

**Path Parameters**:
- `activity_id`: UUID (required)

**Request Body**:
```json
{
  "cancellation_reason": "string (optional, max 500 chars)"
}
```

**Stored Procedure**: `activity.sp_cancel_activity`

**SP Input Parameters**:
```sql
p_activity_id UUID,
p_user_id UUID,  -- From JWT token, must be organizer
p_cancellation_reason TEXT
```

**SP Output**:
```sql
-- Returns confirmation
activity_id UUID,
status activity.activity_status,  -- Will be 'cancelled'
cancelled_at TIMESTAMP WITH TIME ZONE,
participants_notified_count INT  -- Number of participants who will receive notification
```

**SP Logic**:
1. Validate `p_activity_id` exists AND status = 'published'
2. Validate `p_user_id` is organizer (role = 'organizer' in `activity.participants`)
3. Validate activity scheduled_at has not passed (cannot cancel past activities)
4. Update `activity.activities`: SET status = 'cancelled', cancelled_at = NOW()
5. Update all participants in `activity.participants`: SET participation_status = 'cancelled'
6. Count participants for notification
7. Generate notification records for all participants (type = 'activity_update')
8. Return cancellation confirmation

**Success Response** (200 OK):
```json
{
  "activity_id": "uuid",
  "status": "cancelled",
  "cancelled_at": "ISO8601",
  "participants_notified": 8,
  "message": "Activity cancelled successfully. All participants have been notified."
}
```

**Error Responses**:
- `401 Unauthorized`: Invalid or missing JWT token
- `403 Forbidden`: User is not the organizer
- `404 Not Found`: Activity does not exist
- `422 Unprocessable Entity`: Activity already cancelled/completed, or in the past

---

#### ENDPOINT 1.5: DELETE ACTIVITY
**Purpose**: Permanently delete an activity. Only organizer can delete, only if no participants yet.

**HTTP Method**: `DELETE`  
**Path**: `/api/v1/activities/{activity_id}`  
**Authentication**: Required (user role)

**Path Parameters**:
- `activity_id`: UUID (required)

**Stored Procedure**: `activity.sp_delete_activity`

**SP Input Parameters**:
```sql
p_activity_id UUID,
p_user_id UUID  -- From JWT token
```

**SP Output**:
```sql
-- Returns success flag
deleted BOOLEAN,
message TEXT
```

**SP Logic**:
1. Validate `p_activity_id` exists
2. Validate `p_user_id` is organizer
3. Validate current_participants_count = 1 (only organizer, no other participants)
4. Validate activity status = 'draft' OR 'published'
5. Delete from `activity.activity_tags` (CASCADE)
6. Delete from `activity.activity_locations` (CASCADE)
7. Delete from `activity.participants` (CASCADE)
8. Delete from `activity.activities`
9. Decrement `activities_created_count` in `activity.users` for organizer
10. Return success message

**Success Response** (200 OK):
```json
{
  "deleted": true,
  "message": "Activity deleted successfully"
}
```

**Error Responses**:
- `401 Unauthorized`: Invalid or missing JWT token
- `403 Forbidden`: User is not organizer, or activity has other participants
- `404 Not Found`: Activity does not exist
- `422 Unprocessable Entity`: Cannot delete activity with participants other than organizer

---

### SECTION 2: ACTIVITY DISCOVERY & SEARCH

---

#### ENDPOINT 2.1: SEARCH ACTIVITIES
**Purpose**: Search and filter activities with multiple criteria.

**HTTP Method**: `GET`  
**Path**: `/api/v1/activities/search`  
**Authentication**: Required (user role)

**Query Parameters**:
```
q: string (optional, text search in title/description)
category_id: uuid (optional, Premium feature)
activity_type: standard|xxl|womens_only|mens_only (optional)
city: string (optional)
latitude: decimal (optional, requires longitude)
longitude: decimal (optional, requires latitude)
radius_km: integer (optional, default 10, max 100, requires lat/lng)
scheduled_from: ISO8601 (optional, default NOW())
scheduled_to: ISO8601 (optional)
language: string (optional, ISO 639-1, Premium feature)
tags: string (optional, comma-separated, match ANY tag)
min_spots_available: integer (optional, minimum spots left)
privacy_level: public|friends_only|invite_only (optional)
page: integer (optional, default 1, min 1)
page_size: integer (optional, default 20, min 1, max 100)
sort_by: scheduled_at|created_at|participants|distance (optional, default scheduled_at)
sort_order: asc|desc (optional, default asc)
```

**Stored Procedure**: `activity.sp_search_activities`

**SP Input Parameters**:
```sql
p_user_id UUID,  -- From JWT token
p_subscription_level activity.subscription_level,  -- From JWT token
p_search_text TEXT,
p_category_id UUID,
p_activity_type activity.activity_type,
p_city VARCHAR(100),
p_latitude DECIMAL(10, 8),
p_longitude DECIMAL(11, 8),
p_radius_km INT,
p_scheduled_from TIMESTAMP WITH TIME ZONE,
p_scheduled_to TIMESTAMP WITH TIME ZONE,
p_language VARCHAR(5),
p_tags TEXT[],  -- Array of tag strings
p_min_spots_available INT,
p_privacy_level activity.activity_privacy_level,
p_page INT,
p_page_size INT,
p_sort_by VARCHAR(50),
p_sort_order VARCHAR(4)
```

**SP Output**:
```sql
-- Returns result set
activity_id UUID,
title VARCHAR(255),
description TEXT,  -- Truncated to 200 chars for list view
activity_type activity.activity_type,
activity_privacy_level activity.activity_privacy_level,
status activity.activity_status,
scheduled_at TIMESTAMP WITH TIME ZONE,
duration_minutes INT,
joinable_at_free TIMESTAMP WITH TIME ZONE,
max_participants INT,
current_participants_count INT,
spots_available INT,  -- Calculated: max - current
waitlist_count INT,
city VARCHAR(100),
distance_km DECIMAL(10, 2),  -- NULL if no lat/lng provided
organizer_user_id UUID,
organizer_username VARCHAR(100),
organizer_first_name VARCHAR(100),
organizer_main_photo_url VARCHAR(500),
organizer_is_verified BOOLEAN,
category_id UUID,
category_name VARCHAR(100),
tags TEXT[],
language VARCHAR(5),
created_at TIMESTAMP WITH TIME ZONE,
user_can_join BOOLEAN,
is_blocked BOOLEAN,
-- Pagination metadata
total_count BIGINT,  -- Total matching results
page INT,
page_size INT,
total_pages INT
```

**SP Logic**:
1. Validate `p_user_id` exists and is active
2. If `p_category_id` provided AND subscription_level = 'free': IGNORE filter (Premium only)
3. If `p_language` provided AND subscription_level NOT IN ('club', 'premium'): IGNORE filter (Club/Premium only)
4. Build dynamic WHERE clause:
   - Filter by `p_search_text` using ILIKE on title and description
   - Filter by `p_category_id` if provided and allowed
   - Filter by `p_activity_type` if provided
   - Filter by `p_city` using ILIKE
   - Filter by location radius using ST_Distance_Sphere if lat/lng provided
   - Filter by scheduled_at range
   - Filter by `p_language` if provided and allowed
   - Filter by tags using ANY operator on tags array
   - Filter spots_available >= `p_min_spots_available`
   - Filter by privacy_level
5. Exclude activities where:
   - status IN ('cancelled', 'completed')
   - Organizer blocked requesting user (check `activity.user_blocks`)
   - Requesting user blocked organizer (check `activity.user_blocks`)
   - UNLESS activity_type = 'xxl' (blocking doesn't apply to XXL)
6. For friends_only activities: Only show if friendship exists
7. For invite_only activities: Only show if user has invitation
8. Calculate distance_km if lat/lng provided using ST_Distance_Sphere
9. Calculate spots_available = max_participants - current_participants_count
10. Join with users, categories, aggregate tags
11. Calculate user_can_join based on business rules
12. Apply sorting and pagination
13. Return result set with pagination metadata

**Success Response** (200 OK):
```json
{
  "results": [
    {
      "activity_id": "uuid",
      "title": "string",
      "description": "string (truncated)",
      "activity_type": "standard",
      "activity_privacy_level": "public",
      "status": "published",
      "scheduled_at": "ISO8601",
      "duration_minutes": 120,
      "joinable_at_free": "ISO8601 | null",
      "max_participants": 10,
      "current_participants_count": 5,
      "spots_available": 5,
      "waitlist_count": 0,
      "city": "Amsterdam",
      "distance_km": 2.5,
      "organizer": {
        "user_id": "uuid",
        "username": "string",
        "first_name": "string",
        "main_photo_url": "string",
        "is_verified": true
      },
      "category": {
        "category_id": "uuid",
        "name": "Outdoor"
      },
      "tags": ["hiking", "nature"],
      "language": "en",
      "created_at": "ISO8601",
      "user_can_join": true,
      "is_blocked": false
    }
  ],
  "pagination": {
    "total_count": 47,
    "page": 1,
    "page_size": 20,
    "total_pages": 3
  }
}
```

**Error Responses**:
- `400 Bad Request`: Invalid query parameters (e.g., latitude without longitude)
- `401 Unauthorized`: Invalid or missing JWT token

---

#### ENDPOINT 2.2: GET NEARBY ACTIVITIES
**Purpose**: Get activities near a location, sorted by distance.

**HTTP Method**: `GET`  
**Path**: `/api/v1/activities/nearby`  
**Authentication**: Required (user role)

**Query Parameters**:
```
latitude: decimal (required, -90 to 90)
longitude: decimal (required, -180 to 180)
radius_km: integer (optional, default 10, max 100)
scheduled_from: ISO8601 (optional, default NOW())
scheduled_to: ISO8601 (optional)
page: integer (optional, default 1)
page_size: integer (optional, default 20, max 100)
```

**Stored Procedure**: `activity.sp_get_nearby_activities`

**SP Input Parameters**:
```sql
p_user_id UUID,
p_latitude DECIMAL(10, 8),
p_longitude DECIMAL(11, 8),
p_radius_km INT,
p_scheduled_from TIMESTAMP WITH TIME ZONE,
p_scheduled_to TIMESTAMP WITH TIME ZONE,
p_page INT,
p_page_size INT
```

**SP Output**: Same as sp_search_activities

**SP Logic**:
1. Validate coordinates are within valid ranges
2. Query `activity.activities` JOIN `activity.activity_locations`
3. Calculate distance using PostGIS ST_Distance_Sphere function
4. Filter WHERE distance <= `p_radius_km` * 1000 (convert to meters)
5. Filter by scheduled_at range
6. Apply all blocking and privacy rules (same as search)
7. Sort by distance ASC
8. Apply pagination
9. Return results with distance_km populated

**Success Response** (200 OK): Same structure as search endpoint

**Error Responses**:
- `400 Bad Request`: Invalid coordinates, radius too large
- `401 Unauthorized`: Invalid or missing JWT token

---

#### ENDPOINT 2.3: GET ACTIVITY FEED (PERSONALIZED)
**Purpose**: Get personalized activity feed based on user interests and friends.

**HTTP Method**: `GET`  
**Path**: `/api/v1/activities/feed`  
**Authentication**: Required (user role)

**Query Parameters**:
```
page: integer (optional, default 1)
page_size: integer (optional, default 20, max 50)
include_friends: boolean (optional, default true)
include_interests: boolean (optional, default true)
```

**Stored Procedure**: `activity.sp_get_activity_feed`

**SP Input Parameters**:
```sql
p_user_id UUID,
p_page INT,
p_page_size INT,
p_include_friends BOOLEAN,
p_include_interests BOOLEAN
```

**SP Output**: Same as sp_search_activities

**SP Logic**:
1. Get user's interests from `activity.user_interests` (top 10 by weight)
2. Get user's friends from `activity.friendships` WHERE status = 'accepted'
3. Build query:
   - Base: All upcoming public activities (scheduled_at > NOW(), status = 'published')
   - Score boost if:
     - Activity tags match user interests (higher weight = higher score)
     - Organizer is user's friend (if `p_include_friends` = true)
     - Activity in user's city (from user profile)
   - Apply blocking rules (exclude blocked users)
4. Sort by calculated relevance score DESC, then scheduled_at ASC
5. Apply pagination
6. Return results

**Success Response** (200 OK): Same structure as search endpoint

---

#### ENDPOINT 2.4: GET RECOMMENDED ACTIVITIES
**Purpose**: AI/algorithm-based activity recommendations.

**HTTP Method**: `GET`  
**Path**: `/api/v1/activities/recommendations`  
**Authentication**: Required (user role)

**Query Parameters**:
```
limit: integer (optional, default 10, max 50)
```

**Stored Procedure**: `activity.sp_get_recommended_activities`

**SP Input Parameters**:
```sql
p_user_id UUID,
p_limit INT
```

**SP Output**: Same as sp_search_activities (without pagination)

**SP Logic**:
1. Analyze user's past participation (from `activity.participants` WHERE user_id = p_user_id AND attendance_status = 'attended')
2. Extract common patterns:
   - Most attended activity types
   - Most common tags from attended activities
   - Preferred cities/locations
   - Preferred time slots (day of week, time of day)
3. Calculate similarity score for each upcoming activity based on:
   - Tag overlap with user's interest profile
   - Activity type match
   - Location proximity to user's attended locations
   - Time slot preference match
4. Filter out:
   - Activities user is already participating in
   - Blocked organizers
   - Past dates
   - Cancelled/completed activities
5. Sort by similarity score DESC
6. Limit results to `p_limit`
7. Return recommendations

**Success Response** (200 OK):
```json
{
  "recommendations": [
    {
      "activity_id": "uuid",
      "title": "string",
      "similarity_score": 0.85,
      "match_reasons": ["matches your interests: hiking, outdoor", "similar to activities you attended"],
      ... (same fields as search results)
    }
  ]
}
```

---

### SECTION 3: ACTIVITY PARTICIPANTS

---

#### ENDPOINT 3.1: GET ACTIVITY PARTICIPANTS
**Purpose**: Get list of all participants for an activity.

**HTTP Method**: `GET`  
**Path**: `/api/v1/activities/{activity_id}/participants`  
**Authentication**: Required (user role)

**Path Parameters**:
- `activity_id`: UUID (required)

**Query Parameters**:
```
status: registered|waitlisted|declined|cancelled (optional, filter by status)
role: organizer|co_organizer|member (optional, filter by role)
page: integer (optional, default 1)
page_size: integer (optional, default 50, max 100)
```

**Stored Procedure**: `activity.sp_get_activity_participants`

**SP Input Parameters**:
```sql
p_activity_id UUID,
p_user_id UUID,  -- From JWT token
p_participation_status activity.participation_status,
p_role activity.participant_role,
p_page INT,
p_page_size INT
```

**SP Output**:
```sql
-- Returns result set
user_id UUID,
username VARCHAR(100),
first_name VARCHAR(100),
last_name VARCHAR(100),
main_photo_url VARCHAR(500),
is_verified BOOLEAN,
verification_count INT,
role activity.participant_role,
participation_status activity.participation_status,
attendance_status activity.attendance_status,
joined_at TIMESTAMP WITH TIME ZONE,
is_self BOOLEAN,  -- True if this is the requesting user
total_count BIGINT,
page INT,
page_size INT
```

**SP Logic**:
1. Validate `p_activity_id` exists
2. Validate `p_user_id` has access to view participants:
   - If privacy_level = 'invite_only': User must be participant or have invitation
   - If privacy_level = 'friends_only': User must be friend of organizer or participant
3. Check blocking: If user blocked by organizer (or vice versa) AND activity_type != 'xxl': DENY access
4. Query `activity.participants` for activity_id
5. JOIN with `activity.users` to get user details
6. Filter by `p_participation_status` if provided
7. Filter by `p_role` if provided
8. Sort by:
   - role (organizer first, then co_organizers, then members)
   - joined_at ASC
9. Apply pagination
10. Return participant list

**Success Response** (200 OK):
```json
{
  "participants": [
    {
      "user_id": "uuid",
      "username": "string",
      "first_name": "string",
      "last_name": "string",
      "main_photo_url": "string",
      "is_verified": true,
      "verification_count": 15,
      "role": "organizer",
      "participation_status": "registered",
      "attendance_status": "registered",
      "joined_at": "ISO8601",
      "is_self": false
    }
  ],
  "pagination": {
    "total_count": 8,
    "page": 1,
    "page_size": 50
  }
}
```

**Error Responses**:
- `401 Unauthorized`: Invalid or missing JWT token
- `403 Forbidden`: No access to view participants (privacy, blocking)
- `404 Not Found`: Activity does not exist

---

#### ENDPOINT 3.2: GET ACTIVITY WAITLIST
**Purpose**: Get waitlist for a full activity.

**HTTP Method**: `GET`  
**Path**: `/api/v1/activities/{activity_id}/waitlist`  
**Authentication**: Required (user role, must be organizer or co-organizer)

**Path Parameters**:
- `activity_id`: UUID (required)

**Stored Procedure**: `activity.sp_get_activity_waitlist`

**SP Input Parameters**:
```sql
p_activity_id UUID,
p_user_id UUID  -- Must be organizer or co_organizer
```

**SP Output**:
```sql
user_id UUID,
username VARCHAR(100),
first_name VARCHAR(100),
main_photo_url VARCHAR(500),
position INT,
notified_at TIMESTAMP WITH TIME ZONE,
expires_at TIMESTAMP WITH TIME ZONE,
created_at TIMESTAMP WITH TIME ZONE
```

**SP Logic**:
1. Validate `p_activity_id` exists
2. Validate `p_user_id` is organizer OR co_organizer
3. Query `activity.waitlist_entries` for activity_id
4. JOIN with `activity.users`
5. Sort by position ASC
6. Return waitlist ordered by position

**Success Response** (200 OK):
```json
{
  "waitlist": [
    {
      "user_id": "uuid",
      "username": "string",
      "first_name": "string",
      "main_photo_url": "string",
      "position": 1,
      "notified_at": "ISO8601 | null",
      "expires_at": "ISO8601 | null",
      "created_at": "ISO8601"
    }
  ]
}
```

**Error Responses**:
- `401 Unauthorized`: Invalid or missing JWT token
- `403 Forbidden`: User is not organizer/co-organizer
- `404 Not Found`: Activity does not exist

---

### SECTION 4: CATEGORIES

---

#### ENDPOINT 4.1: LIST ALL CATEGORIES
**Purpose**: Get all active activity categories.

**HTTP Method**: `GET`  
**Path**: `/api/v1/categories`  
**Authentication**: Optional (public endpoint)

**Query Parameters**: None

**Stored Procedure**: `activity.sp_list_categories`

**SP Input Parameters**: None

**SP Output**:
```sql
category_id UUID,
name VARCHAR(100),
slug VARCHAR(100),
description TEXT,
icon_url VARCHAR(500),
display_order INT,
is_active BOOLEAN
```

**SP Logic**:
1. Query `activity.categories` WHERE is_active = TRUE
2. Sort by display_order ASC, name ASC
3. Return all active categories

**Success Response** (200 OK):
```json
{
  "categories": [
    {
      "category_id": "uuid",
      "name": "Outdoor",
      "slug": "outdoor",
      "description": "Activities in nature and outdoor settings",
      "icon_url": "https://...",
      "display_order": 1
    }
  ]
}
```

---

#### ENDPOINT 4.2: CREATE CATEGORY (ADMIN ONLY)
**Purpose**: Create a new activity category.

**HTTP Method**: `POST`  
**Path**: `/api/v1/categories`  
**Authentication**: Required (admin role)

**Request Body**:
```json
{
  "name": "string (required, max 100 chars, unique)",
  "slug": "string (required, max 100 chars, unique, lowercase-hyphenated)",
  "description": "string (optional)",
  "icon_url": "string (optional, valid URL)",
  "display_order": "integer (optional, default 0)"
}
```

**Stored Procedure**: `activity.sp_create_category`

**SP Input Parameters**:
```sql
p_name VARCHAR(100),
p_slug VARCHAR(100),
p_description TEXT,
p_icon_url VARCHAR(500),
p_display_order INT
```

**SP Output**:
```sql
category_id UUID,
name VARCHAR(100),
slug VARCHAR(100),
description TEXT,
icon_url VARCHAR(500),
display_order INT,
is_active BOOLEAN,
created_at TIMESTAMP WITH TIME ZONE
```

**SP Logic**:
1. Validate `p_slug` matches format: ^[a-z0-9-]+$
2. Check uniqueness of `p_name` and `p_slug`
3. Insert into `activity.categories` with is_active = TRUE
4. Return created category

**Success Response** (201 Created):
```json
{
  "category_id": "uuid",
  "name": "Outdoor",
  "slug": "outdoor",
  "description": "string",
  "icon_url": "string",
  "display_order": 1,
  "is_active": true,
  "created_at": "ISO8601"
}
```

**Error Responses**:
- `400 Bad Request`: Invalid slug format
- `401 Unauthorized`: Invalid or missing JWT token
- `403 Forbidden`: User is not admin
- `409 Conflict`: Name or slug already exists

---

#### ENDPOINT 4.3: UPDATE CATEGORY (ADMIN ONLY)
**Purpose**: Update an existing category.

**HTTP Method**: `PUT`  
**Path**: `/api/v1/categories/{category_id}`  
**Authentication**: Required (admin role)

**Path Parameters**:
- `category_id`: UUID (required)

**Request Body**: (All fields optional)
```json
{
  "name": "string (max 100 chars)",
  "slug": "string (max 100 chars, lowercase-hyphenated)",
  "description": "string",
  "icon_url": "string (valid URL)",
  "display_order": "integer",
  "is_active": "boolean"
}
```

**Stored Procedure**: `activity.sp_update_category`

**SP Input Parameters**:
```sql
p_category_id UUID,
p_name VARCHAR(100),
p_slug VARCHAR(100),
p_description TEXT,
p_icon_url VARCHAR(500),
p_display_order INT,
p_is_active BOOLEAN
```

**SP Output**: Same as sp_create_category

**SP Logic**:
1. Validate `p_category_id` exists
2. If `p_slug` changed: Validate format and uniqueness
3. If `p_name` changed: Validate uniqueness
4. Update `activity.categories`
5. Return updated category

**Success Response** (200 OK): Same structure as create

**Error Responses**:
- `400 Bad Request`: Invalid slug format
- `401 Unauthorized`: Invalid or missing JWT token
- `403 Forbidden`: User is not admin
- `404 Not Found`: Category does not exist
- `409 Conflict`: Name or slug already exists

---

### SECTION 5: REVIEWS & RATINGS

---

#### ENDPOINT 5.1: CREATE ACTIVITY REVIEW
**Purpose**: Write a review for a completed activity user attended.

**HTTP Method**: `POST`  
**Path**: `/api/v1/activities/{activity_id}/reviews`  
**Authentication**: Required (user role)

**Path Parameters**:
- `activity_id`: UUID (required)

**Request Body**:
```json
{
  "rating": "integer (required, 1-5)",
  "review_text": "string (optional, max 1000 chars)",
  "is_anonymous": "boolean (optional, default false)"
}
```

**Stored Procedure**: `activity.sp_create_activity_review`

**SP Input Parameters**:
```sql
p_activity_id UUID,
p_reviewer_user_id UUID,  -- From JWT token
p_rating INT,
p_review_text TEXT,
p_is_anonymous BOOLEAN
```

**SP Output**:
```sql
review_id UUID,
activity_id UUID,
reviewer_user_id UUID,
reviewer_username VARCHAR(100),  -- NULL if anonymous
rating INT,
review_text TEXT,
is_anonymous BOOLEAN,
created_at TIMESTAMP WITH TIME ZONE
```

**SP Logic**:
1. Validate `p_activity_id` exists AND status = 'completed'
2. Validate `p_reviewer_user_id` attended activity (check `activity.participants` WHERE attendance_status = 'attended')
3. Validate activity scheduled_at has passed
4. Check if review already exists (UNIQUE constraint on activity_id + reviewer_user_id)
5. Validate `p_rating` is between 1 and 5
6. Insert into `activity.activity_reviews`
7. If not anonymous: Return reviewer username
8. If anonymous: Return NULL for reviewer details
9. Return created review

**Success Response** (201 Created):
```json
{
  "review_id": "uuid",
  "activity_id": "uuid",
  "reviewer": {
    "user_id": "uuid",
    "username": "string"
  },
  "rating": 5,
  "review_text": "Great activity!",
  "is_anonymous": false,
  "created_at": "ISO8601"
}
```

**Error Responses**:
- `400 Bad Request`: Invalid rating (not 1-5)
- `401 Unauthorized`: Invalid or missing JWT token
- `403 Forbidden`: User did not attend activity
- `404 Not Found`: Activity does not exist
- `409 Conflict`: Review already exists for this user and activity
- `422 Unprocessable Entity`: Activity not completed yet

---

#### ENDPOINT 5.2: GET ACTIVITY REVIEWS
**Purpose**: Get all reviews for an activity.

**HTTP Method**: `GET`  
**Path**: `/api/v1/activities/{activity_id}/reviews`  
**Authentication**: Optional (public endpoint)

**Path Parameters**:
- `activity_id`: UUID (required)

**Query Parameters**:
```
page: integer (optional, default 1)
page_size: integer (optional, default 20, max 50)
sort_by: rating|created_at (optional, default created_at)
sort_order: asc|desc (optional, default desc)
```

**Stored Procedure**: `activity.sp_get_activity_reviews`

**SP Input Parameters**:
```sql
p_activity_id UUID,
p_page INT,
p_page_size INT,
p_sort_by VARCHAR(20),
p_sort_order VARCHAR(4)
```

**SP Output**:
```sql
review_id UUID,
activity_id UUID,
reviewer_user_id UUID,
reviewer_username VARCHAR(100),  -- NULL if anonymous
reviewer_main_photo_url VARCHAR(500),  -- NULL if anonymous
rating INT,
review_text TEXT,
is_anonymous BOOLEAN,
created_at TIMESTAMP WITH TIME ZONE,
-- Aggregates
average_rating DECIMAL(3, 2),
total_reviews INT,
rating_distribution JSONB,  -- {"1": 0, "2": 1, "3": 2, "4": 5, "5": 10}
-- Pagination
total_count BIGINT,
page INT,
page_size INT
```

**SP Logic**:
1. Validate `p_activity_id` exists
2. Query `activity.activity_reviews` for activity
3. JOIN with `activity.users` ONLY if is_anonymous = FALSE
4. Calculate aggregates:
   - Average rating across all reviews
   - Total review count
   - Rating distribution (count per rating 1-5)
5. Sort by `p_sort_by` and `p_sort_order`
6. Apply pagination
7. Return reviews with aggregates

**Success Response** (200 OK):
```json
{
  "reviews": [
    {
      "review_id": "uuid",
      "reviewer": {
        "user_id": "uuid",
        "username": "string",
        "main_photo_url": "string"
      },
      "rating": 5,
      "review_text": "string",
      "is_anonymous": false,
      "created_at": "ISO8601"
    }
  ],
  "statistics": {
    "average_rating": 4.5,
    "total_reviews": 18,
    "rating_distribution": {
      "1": 0,
      "2": 1,
      "3": 2,
      "4": 5,
      "5": 10
    }
  },
  "pagination": {
    "total_count": 18,
    "page": 1,
    "page_size": 20
  }
}
```

---

#### ENDPOINT 5.3: UPDATE REVIEW
**Purpose**: Update user's own review.

**HTTP Method**: `PUT`  
**Path**: `/api/v1/reviews/{review_id}`  
**Authentication**: Required (user role, must be review author)

**Path Parameters**:
- `review_id`: UUID (required)

**Request Body**:
```json
{
  "rating": "integer (optional, 1-5)",
  "review_text": "string (optional, max 1000 chars)",
  "is_anonymous": "boolean (optional)"
}
```

**Stored Procedure**: `activity.sp_update_review`

**SP Input Parameters**:
```sql
p_review_id UUID,
p_user_id UUID,  -- From JWT token, must match reviewer_user_id
p_rating INT,
p_review_text TEXT,
p_is_anonymous BOOLEAN
```

**SP Output**: Same as sp_create_activity_review

**SP Logic**:
1. Validate `p_review_id` exists
2. Validate `p_user_id` = reviewer_user_id (owner check)
3. Validate `p_rating` is between 1 and 5 (if provided)
4. Update `activity.activity_reviews`
5. Return updated review

**Success Response** (200 OK): Same structure as create review

**Error Responses**:
- `400 Bad Request`: Invalid rating
- `401 Unauthorized`: Invalid or missing JWT token
- `403 Forbidden`: User is not the review author
- `404 Not Found`: Review does not exist

---

#### ENDPOINT 5.4: DELETE REVIEW
**Purpose**: Delete user's own review.

**HTTP Method**: `DELETE`  
**Path**: `/api/v1/reviews/{review_id}`  
**Authentication**: Required (user role, must be review author)

**Path Parameters**:
- `review_id`: UUID (required)

**Stored Procedure**: `activity.sp_delete_review`

**SP Input Parameters**:
```sql
p_review_id UUID,
p_user_id UUID  -- From JWT token
```

**SP Output**:
```sql
deleted BOOLEAN,
message TEXT
```

**SP Logic**:
1. Validate `p_review_id` exists
2. Validate `p_user_id` = reviewer_user_id (owner check)
3. Delete from `activity.activity_reviews`
4. Return success

**Success Response** (200 OK):
```json
{
  "deleted": true,
  "message": "Review deleted successfully"
}
```

**Error Responses**:
- `401 Unauthorized`: Invalid or missing JWT token
- `403 Forbidden`: User is not the review author
- `404 Not Found`: Review does not exist

---

### SECTION 6: ACTIVITY TAGS

---

#### ENDPOINT 6.1: GET POPULAR TAGS
**Purpose**: Get most popular activity tags for autocomplete/suggestions.

**HTTP Method**: `GET`  
**Path**: `/api/v1/activities/tags/popular`  
**Authentication**: Optional (public endpoint)

**Query Parameters**:
```
limit: integer (optional, default 50, max 100)
prefix: string (optional, filter tags starting with prefix)
```

**Stored Procedure**: `activity.sp_get_popular_tags`

**SP Input Parameters**:
```sql
p_limit INT,
p_prefix VARCHAR(100)
```

**SP Output**:
```sql
tag VARCHAR(100),
usage_count INT
```

**SP Logic**:
1. Query `activity.activity_tags` with GROUP BY tag
2. COUNT occurrences per tag
3. If `p_prefix` provided: Filter WHERE tag ILIKE 'prefix%'
4. Sort by usage_count DESC
5. LIMIT by `p_limit`
6. Return tags with usage counts

**Success Response** (200 OK):
```json
{
  "tags": [
    {
      "tag": "hiking",
      "usage_count": 342
    },
    {
      "tag": "outdoor",
      "usage_count": 298
    }
  ]
}
```

---

## STORED PROCEDURE SPECIFICATIONS

### Template for All Stored Procedures

Every stored procedure follows this structure:

```sql
CREATE OR REPLACE FUNCTION activity.sp_procedure_name(
    -- Input parameters
    p_param1 TYPE,
    p_param2 TYPE
)
RETURNS TABLE (
    -- Output columns
    col1 TYPE,
    col2 TYPE
) AS $$
DECLARE
    v_variable TYPE;
BEGIN
    -- 1. VALIDATION SECTION
    -- Validate all inputs
    -- Check existence of referenced entities
    -- Check permissions
    
    -- 2. BUSINESS LOGIC SECTION
    -- Perform core operations
    -- INSERT/UPDATE/DELETE as needed
    
    -- 3. RETURN SECTION
    -- SELECT and return results
    
    RETURN QUERY
    SELECT ...;
    
EXCEPTION
    WHEN OTHERS THEN
        -- Error handling
        RAISE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

### Error Handling in Stored Procedures

All stored procedures use PostgreSQL's exception handling:

```sql
-- Validation errors (user input)
IF condition THEN
    RAISE EXCEPTION 'ERR_VALIDATION_%', detail
        USING ERRCODE = '22000';  -- data_exception
END IF;

-- Not found errors
IF NOT FOUND THEN
    RAISE EXCEPTION 'ERR_NOT_FOUND_%', entity
        USING ERRCODE = '42704';  -- undefined_object
END IF;

-- Permission errors
IF no_permission THEN
    RAISE EXCEPTION 'ERR_FORBIDDEN_%', reason
        USING ERRCODE = '42501';  -- insufficient_privilege
END IF;

-- Business logic errors (state conflicts)
IF invalid_state THEN
    RAISE EXCEPTION 'ERR_CONFLICT_%', detail
        USING ERRCODE = '23505';  -- unique_violation
END IF;
```

### Common Validation Checks (Reusable Logic)

```sql
-- Check user exists and is active
IF NOT EXISTS (
    SELECT 1 FROM activity.users 
    WHERE user_id = p_user_id AND status = 'active'
) THEN
    RAISE EXCEPTION 'ERR_USER_NOT_FOUND'
        USING ERRCODE = '42704';
END IF;

-- Check blocking (asymmetric, XXL exception)
IF EXISTS (
    SELECT 1 FROM activity.user_blocks
    WHERE (blocker_user_id = p_user_a AND blocked_user_id = p_user_b)
       OR (blocker_user_id = p_user_b AND blocked_user_id = p_user_a)
) AND v_activity_type != 'xxl' THEN
    RAISE EXCEPTION 'ERR_BLOCKED'
        USING ERRCODE = '42501';
END IF;

-- Check category exists and is active
IF p_category_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM activity.categories
    WHERE category_id = p_category_id AND is_active = TRUE
) THEN
    RAISE EXCEPTION 'ERR_CATEGORY_NOT_FOUND'
        USING ERRCODE = '42704';
END IF;

-- Check subscription level for premium features
IF p_subscription_level = 'free' AND p_requires_premium THEN
    RAISE EXCEPTION 'ERR_PREMIUM_REQUIRED'
        USING ERRCODE = '42501';
END IF;

-- Check is organizer or co-organizer
IF NOT EXISTS (
    SELECT 1 FROM activity.participants
    WHERE activity_id = p_activity_id 
      AND user_id = p_user_id
      AND role IN ('organizer', 'co_organizer')
) THEN
    RAISE EXCEPTION 'ERR_NOT_ORGANIZER'
        USING ERRCODE = '42501';
END IF;
```

---

## ERROR HANDLING

### Error Response Format

All errors return this JSON structure:

```json
{
  "error": {
    "code": "ERROR_CODE",
    "message": "Human-readable error message",
    "details": {
      "field": "field_name",
      "constraint": "constraint_name",
      "additional_info": "value"
    }
  }
}
```

### HTTP Status Code Mapping

| HTTP Status | Error Type | Example Codes |
|-------------|------------|---------------|
| 400 Bad Request | Invalid input format, malformed JSON | `INVALID_INPUT`, `INVALID_FORMAT`, `INVALID_COORDINATES` |
| 401 Unauthorized | Missing or invalid JWT token | `MISSING_TOKEN`, `INVALID_TOKEN`, `TOKEN_EXPIRED` |
| 403 Forbidden | Permission denied, user banned | `FORBIDDEN`, `USER_BANNED`, `NOT_ORGANIZER`, `BLOCKED`, `PREMIUM_REQUIRED` |
| 404 Not Found | Resource does not exist | `ACTIVITY_NOT_FOUND`, `USER_NOT_FOUND`, `CATEGORY_NOT_FOUND` |
| 409 Conflict | Resource already exists, state conflict | `ALREADY_PARTICIPATING`, `REVIEW_EXISTS`, `ACTIVITY_FULL` |
| 422 Unprocessable Entity | Business logic validation failed | `ACTIVITY_IN_PAST`, `CANNOT_REDUCE_PARTICIPANTS`, `ACTIVITY_COMPLETED` |
| 500 Internal Server Error | Database errors, unexpected failures | `DATABASE_ERROR`, `INTERNAL_ERROR` |

### Error Code List

```
# Authentication & Authorization
MISSING_TOKEN - JWT token not provided
INVALID_TOKEN - JWT token invalid or malformed
TOKEN_EXPIRED - JWT token has expired
USER_NOT_FOUND - User ID from token not found
USER_BANNED - User account is banned
USER_SUSPENDED - User account is suspended
FORBIDDEN - Generic permission denied
NOT_ORGANIZER - User is not organizer/co-organizer
PREMIUM_REQUIRED - Feature requires premium subscription
BLOCKED - User is blocked

# Validation Errors
INVALID_INPUT - Generic input validation failure
INVALID_FORMAT - Data format incorrect (e.g., email, date)
INVALID_COORDINATES - Latitude/longitude out of range
INVALID_RATING - Rating not between 1-5
SCHEDULED_AT_PAST - Activity scheduled_at must be in future
MAX_PARTICIPANTS_TOO_LOW - Cannot set max lower than current count
MAX_TAGS_EXCEEDED - More than 20 tags provided
INVALID_SLUG_FORMAT - Slug must be lowercase-hyphenated
RADIUS_TOO_LARGE - Search radius exceeds maximum

# Not Found Errors
ACTIVITY_NOT_FOUND - Activity ID does not exist
CATEGORY_NOT_FOUND - Category ID does not exist
REVIEW_NOT_FOUND - Review ID does not exist
USER_NOT_FOUND - User ID does not exist

# Conflict Errors
ALREADY_PARTICIPATING - User already participating in activity
REVIEW_EXISTS - User already reviewed this activity
CATEGORY_EXISTS - Category name/slug already exists
ACTIVITY_FULL - Activity has reached max participants
ALREADY_WAITLISTED - User already on waitlist

# State Errors
ACTIVITY_CANCELLED - Activity has been cancelled
ACTIVITY_COMPLETED - Activity has been completed
CANNOT_DELETE_WITH_PARTICIPANTS - Cannot delete activity with participants
CANNOT_CANCEL_PAST_ACTIVITY - Cannot cancel activity in the past
ACTIVITY_NOT_COMPLETED - Review only allowed after activity completion
DID_NOT_ATTEND - Review only allowed for attendees

# Database Errors
DATABASE_ERROR - Generic database failure
CONSTRAINT_VIOLATION - Database constraint violated
FOREIGN_KEY_VIOLATION - Referenced entity does not exist
```

### FastAPI Error Handler Implementation

```python
from fastapi import HTTPException, status
from psycopg2 import errors as pg_errors

def map_db_error_to_http(error: Exception) -> HTTPException:
    """Map database errors to HTTP exceptions"""
    
    error_str = str(error)
    
    # Parse PostgreSQL error codes
    if isinstance(error, pg_errors.RaiseException):
        if 'ERR_NOT_FOUND' in error_str:
            return HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail={"error": {"code": "NOT_FOUND", "message": error_str}}
            )
        elif 'ERR_FORBIDDEN' in error_str:
            return HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail={"error": {"code": "FORBIDDEN", "message": error_str}}
            )
        elif 'ERR_VALIDATION' in error_str:
            return HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail={"error": {"code": "VALIDATION_ERROR", "message": error_str}}
            )
        elif 'ERR_CONFLICT' in error_str:
            return HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail={"error": {"code": "CONFLICT", "message": error_str}}
            )
    
    # Default to 500 for unexpected errors
    return HTTPException(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        detail={"error": {"code": "INTERNAL_ERROR", "message": "An unexpected error occurred"}}
    )
```

---

## DATA FLOW DIAGRAMS

### Flow 1: Create Activity

```
Client → FastAPI → JWT Validation → Extract user_id, subscription_level
                                  ↓
                          Call sp_create_activity
                                  ↓
                          Validate inputs
                          Check user active
                          Check category exists
                          Validate dates
                                  ↓
                          INSERT activities
                          INSERT activity_locations
                          INSERT activity_tags (loop)
                          INSERT participants (organizer)
                          UPDATE users.activities_created_count
                                  ↓
                          RETURN activity data
                                  ↓
FastAPI → Transform to JSON → Return 201 Created
```

### Flow 2: Search Activities with Blocking

```
Client → FastAPI → JWT Validation → Extract user_id
                                  ↓
                          Call sp_search_activities
                                  ↓
                          Build WHERE clause from filters
                                  ↓
                          JOIN activities + users + categories + locations
                                  ↓
                          Subquery: Get blocked user IDs
                          (SELECT blocked_user_id FROM user_blocks WHERE blocker_user_id = p_user_id
                           UNION
                           SELECT blocker_user_id FROM user_blocks WHERE blocked_user_id = p_user_id)
                                  ↓
                          EXCLUDE activities WHERE:
                            organizer_user_id IN (blocked_users)
                            AND activity_type != 'xxl'
                                  ↓
                          Check privacy level access
                          Calculate distance if lat/lng
                          Calculate user_can_join
                                  ↓
                          Apply pagination
                          RETURN results
                                  ↓
FastAPI → Transform to JSON → Return 200 OK
```

### Flow 3: Join Activity (covered in Participation API)

This is handled by the Participation API, not Activities API.

---

## IMPLEMENTATION CHECKLIST FOR AI CODE AGENT

### Phase 1: Setup
- [ ] Create FastAPI project structure
- [ ] Set up database connection pool (asyncpg)
- [ ] Implement JWT validation middleware
- [ ] Create Pydantic models for all request/response schemas
- [ ] Set up error handling middleware

### Phase 2: Core CRUD
- [ ] Implement sp_create_activity stored procedure
- [ ] Implement POST /api/v1/activities endpoint
- [ ] Implement sp_get_activity_by_id stored procedure
- [ ] Implement GET /api/v1/activities/{activity_id} endpoint
- [ ] Implement sp_update_activity stored procedure
- [ ] Implement PUT /api/v1/activities/{activity_id} endpoint
- [ ] Implement sp_cancel_activity stored procedure
- [ ] Implement POST /api/v1/activities/{activity_id}/cancel endpoint
- [ ] Implement sp_delete_activity stored procedure
- [ ] Implement DELETE /api/v1/activities/{activity_id} endpoint

### Phase 3: Search & Discovery
- [ ] Implement sp_search_activities stored procedure (complex!)
- [ ] Implement GET /api/v1/activities/search endpoint
- [ ] Implement sp_get_nearby_activities stored procedure
- [ ] Implement GET /api/v1/activities/nearby endpoint
- [ ] Implement sp_get_activity_feed stored procedure
- [ ] Implement GET /api/v1/activities/feed endpoint
- [ ] Implement sp_get_recommended_activities stored procedure
- [ ] Implement GET /api/v1/activities/recommendations endpoint

### Phase 4: Categories
- [ ] Implement sp_list_categories stored procedure
- [ ] Implement GET /api/v1/categories endpoint
- [ ] Implement sp_create_category stored procedure
- [ ] Implement POST /api/v1/categories endpoint (admin only)
- [ ] Implement sp_update_category stored procedure
- [ ] Implement PUT /api/v1/categories/{category_id} endpoint (admin only)

### Phase 5: Participants & Waitlist
- [ ] Implement sp_get_activity_participants stored procedure
- [ ] Implement GET /api/v1/activities/{activity_id}/participants endpoint
- [ ] Implement sp_get_activity_waitlist stored procedure
- [ ] Implement GET /api/v1/activities/{activity_id}/waitlist endpoint

### Phase 6: Reviews
- [ ] Implement sp_create_activity_review stored procedure
- [ ] Implement POST /api/v1/activities/{activity_id}/reviews endpoint
- [ ] Implement sp_get_activity_reviews stored procedure
- [ ] Implement GET /api/v1/activities/{activity_id}/reviews endpoint
- [ ] Implement sp_update_review stored procedure
- [ ] Implement PUT /api/v1/reviews/{review_id} endpoint
- [ ] Implement sp_delete_review stored procedure
- [ ] Implement DELETE /api/v1/reviews/{review_id} endpoint

### Phase 7: Tags
- [ ] Implement sp_get_popular_tags stored procedure
- [ ] Implement GET /api/v1/activities/tags/popular endpoint

### Phase 8: Testing
- [ ] Unit tests for all stored procedures
- [ ] Integration tests for all endpoints
- [ ] Test blocking logic thoroughly (including XXL exception)
- [ ] Test privacy levels (public, friends_only, invite_only)
- [ ] Test subscription level restrictions
- [ ] Test pagination
- [ ] Load testing for search endpoint

---

## CRITICAL BUSINESS RULES SUMMARY

### Blocking System (ASYMMETRIC)
- User A can block User B independently (B doesn't know)
- When blocked: cannot see profiles, activities, posts, or send messages
- **EXCEPTION**: Blocking does NOT apply to XXL activities (activity_type = 'xxl')
- Check blocking in BOTH directions: A blocks B OR B blocks A

### Activity Types
- **standard**: Normal activities (2-30 people typically)
- **xxl**: Large activities (100+ people) - blocking rules DON'T apply
- **womens_only**: Only female users can join
- **mens_only**: Only male users can join

### Privacy Levels
- **public**: Everyone can see and join (if not blocked)
- **friends_only**: Only accepted friends of organizer can see/join
- **invite_only**: Only explicitly invited users can see/join

### Subscription Levels
- **free**: Basic access, no category filter, no language filter, joinable_at_free restrictions apply
- **club**: Category filtering, priority participation (skip joinable_at_free wait)
- **premium**: All Club features + language filtering

### Priority Participation
- Field: `joinable_at_free` (timestamp)
- If set: Free users must wait until this time to join
- Club/Premium users: Can join immediately, no wait
- If NULL: No waiting period, all users can join immediately

### Main Photo Moderation
- Field: `main_photo_moderation_status` (pending, approved, rejected)
- Main photo MUST show clear face (functional safety requirement)
- Separate from extra profile photos (up to 8 additional)

### Verification System
- Users confirm each other's attendance after activities
- Builds trust score via `verification_count`
- Affects matching and recommendations

### No-Show Tracking
- Tracked via `no_show_count` field
- Impacts trust score negatively
- Can lead to temporary bans

---

## API COMMUNICATION PATTERNS

### Request Flow
```
1. Client sends HTTP request with JWT token
2. FastAPI validates JWT and extracts claims (user_id, subscription_level, roles)
3. FastAPI validates request body against Pydantic model
4. FastAPI calls stored procedure with validated parameters
5. PostgreSQL executes stored procedure (validation + business logic)
6. Stored procedure returns result set or raises exception
7. FastAPI transforms result to JSON response model
8. FastAPI returns HTTP response to client
```

### Authentication Header
```
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

### Standard Request Example
```http
POST /api/v1/activities HTTP/1.1
Host: api.example.com
Authorization: Bearer <jwt_token>
Content-Type: application/json

{
  "title": "Morning Hike",
  "description": "Join us for a refreshing morning hike in the mountains",
  "activity_type": "standard",
  ...
}
```

### Standard Response Example (Success)
```http
HTTP/1.1 201 Created
Content-Type: application/json

{
  "activity_id": "018c5f3e-4a7b-7c3d-9e2f-1a4b5c6d7e8f",
  "title": "Morning Hike",
  ...
}
```

### Standard Response Example (Error)
```http
HTTP/1.1 403 Forbidden
Content-Type: application/json

{
  "error": {
    "code": "USER_BANNED",
    "message": "Your account has been banned until 2025-12-01",
    "details": {
      "ban_expires_at": "2025-12-01T00:00:00Z",
      "reason": "Multiple no-shows reported"
    }
  }
}
```

---

## DATABASE CONNECTION CONFIGURATION

```python
# database.py
from asyncpg import create_pool
from contextlib import asynccontextmanager

class Database:
    def __init__(self):
        self.pool = None
    
    async def connect(self):
        self.pool = await create_pool(
            host='localhost',
            port=5432,
            database='activities_db',
            user='api_user',
            password='secure_password',
            min_size=10,
            max_size=50,
            command_timeout=60,
            server_settings={
                'search_path': 'activity,public',
                'timezone': 'UTC'
            }
        )
    
    async def disconnect(self):
        await self.pool.close()
    
    @asynccontextmanager
    async def transaction(self):
        async with self.pool.acquire() as conn:
            async with conn.transaction():
                yield conn

db = Database()
```

---

## ENDPOINT SUMMARY TABLE

| Method | Path | Auth | Purpose | Stored Procedure |
|--------|------|------|---------|------------------|
| POST | /api/v1/activities | User | Create activity | sp_create_activity |
| GET | /api/v1/activities/{id} | User | Get activity details | sp_get_activity_by_id |
| PUT | /api/v1/activities/{id} | User | Update activity | sp_update_activity |
| POST | /api/v1/activities/{id}/cancel | User | Cancel activity | sp_cancel_activity |
| DELETE | /api/v1/activities/{id} | User | Delete activity | sp_delete_activity |
| GET | /api/v1/activities/search | User | Search activities | sp_search_activities |
| GET | /api/v1/activities/nearby | User | Nearby activities | sp_get_nearby_activities |
| GET | /api/v1/activities/feed | User | Personalized feed | sp_get_activity_feed |
| GET | /api/v1/activities/recommendations | User | AI recommendations | sp_get_recommended_activities |
| GET | /api/v1/activities/{id}/participants | User | List participants | sp_get_activity_participants |
| GET | /api/v1/activities/{id}/waitlist | User | Get waitlist | sp_get_activity_waitlist |
| POST | /api/v1/activities/{id}/reviews | User | Create review | sp_create_activity_review |
| GET | /api/v1/activities/{id}/reviews | Public | Get reviews | sp_get_activity_reviews |
| PUT | /api/v1/reviews/{id} | User | Update review | sp_update_review |
| DELETE | /api/v1/reviews/{id} | User | Delete review | sp_delete_review |
| GET | /api/v1/categories | Public | List categories | sp_list_categories |
| POST | /api/v1/categories | Admin | Create category | sp_create_category |
| PUT | /api/v1/categories/{id} | Admin | Update category | sp_update_category |
| GET | /api/v1/activities/tags/popular | Public | Popular tags | sp_get_popular_tags |

---

## NOTES FOR AI CODE AGENT

### Key Implementation Points

1. **ALWAYS use stored procedures**: Never write raw SQL in the API layer. All database logic MUST be in stored procedures.

2. **JWT token handling**: Extract `user_id`, `subscription_level`, `ghost_mode`, and `roles` from JWT claims and pass to stored procedures.

3. **Blocking logic**: Check blocking in BOTH directions (A blocks B OR B blocks A) and remember the XXL exception.

4. **Privacy levels**: Enforce privacy_level checks in stored procedures, not in API layer.

5. **Subscription features**: Premium/Club features should be checked both in API (early rejection) and in stored procedures (security).

6. **Error mapping**: Map PostgreSQL exceptions to appropriate HTTP status codes using error handler middleware.

7. **Pagination**: All list endpoints must support pagination. Use consistent `page` and `page_size` parameters.

8. **Validation order**: Validate in this order: JWT → Request schema → Stored procedure → Business logic

9. **Performance**: Use indexes effectively. Search endpoint is performance-critical - optimize stored procedure.

10. **Testing**: Test blocking logic extensively. It's complex and critical for safety.

### Common Pitfalls to Avoid

- ❌ Writing SQL queries directly in API code
- ❌ Forgetting to check blocking in BOTH directions
- ❌ Ignoring XXL exception for blocking rules
- ❌ Not validating subscription level for premium features
- ❌ Returning sensitive data when blocked
- ❌ Forgetting to increment/decrement counters (activities_created_count, etc.)
- ❌ Not handling NULL values in location fields
- ❌ Forgetting pagination metadata in list responses
- ❌ Not validating date ranges (scheduled_at must be future)
- ❌ Allowing max_participants reduction below current count

### Recommended Libraries

```
fastapi==0.104.1
pydantic==2.5.0
asyncpg==0.29.0
python-jose[cryptography]==3.3.0  # JWT handling
python-multipart==0.0.6
uvicorn[standard]==0.24.0
pytest==7.4.3
pytest-asyncio==0.21.1
httpx==0.25.1  # For testing
```

---

END OF SPECIFICATIONS
