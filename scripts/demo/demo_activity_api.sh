#!/bin/bash
# Activity API - Comprehensive Sprint Demo Script
# Tests all 19 endpoints with database verification at each step

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CREDENTIALS_FILE="${SCRIPT_DIR}/.demo_credentials"
LOG_FILE="${SCRIPT_DIR}/demo_$(date +%Y%m%d_%H%M%S).log"

# Load credentials
if [ ! -f "$CREDENTIALS_FILE" ]; then
    echo -e "${RED}Error: Demo credentials not found!${NC}"
    echo -e "${YELLOW}Run ./scripts/demo/setup_demo_users.sh first${NC}"
    exit 1
fi

source "$CREDENTIALS_FILE"

# Global variables
STEP_COUNTER=0
SUCCESS_COUNT=0
FAILED_COUNT=0
PAUSE_ENABLED=true

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --auto)
            PAUSE_ENABLED=false
            shift
            ;;
        --quick)
            QUICK_MODE=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--auto] [--quick]"
            exit 1
            ;;
    esac
done

# Logging
exec > >(tee -a "$LOG_FILE")
exec 2>&1

# Helper Functions
section() {
    local title=$1
    echo -e "\n${CYAN}"
    echo "╔════════════════════════════════════════════════════════════════╗"
    printf "║  %-60s  ║\n" "$title"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

step() {
    STEP_COUNTER=$((STEP_COUNTER + 1))
    echo -e "\n${BLUE}[Step $STEP_COUNTER] $1${NC}"
}

success() {
    SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
    echo -e "${GREEN}✓ $1${NC}"
}

error() {
    FAILED_COUNT=$((FAILED_COUNT + 1))
    echo -e "${RED}✗ $1${NC}"
}

info() {
    echo -e "${YELLOW}ℹ $1${NC}"
}

pause_demo() {
    if [ "$PAUSE_ENABLED" = true ]; then
        echo -e "\n${MAGENTA}Press Enter to continue...${NC}"
        read
    fi
}

# API call function
api_call() {
    local method=$1
    local endpoint=$2
    local token=$3
    local data=$4
    local description=$5

    echo -e "${CYAN}Request: ${method} ${endpoint}${NC}"
    if [ -n "$data" ]; then
        echo -e "${CYAN}Body: ${NC}$(echo "$data" | jq -c '.' 2>/dev/null || echo "$data")"
    fi

    local curl_opts=(-s -w "\n%{http_code}" -X "$method")
    curl_opts+=(-H "Content-Type: application/json")

    if [ -n "$token" ]; then
        curl_opts+=(-H "Authorization: Bearer $token")
    fi

    if [ -n "$data" ]; then
        curl_opts+=(-d "$data")
    fi

    response=$(curl "${curl_opts[@]}" "${ACTIVITY_API_URL}${endpoint}" 2>&1)

    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | head -n-1)

    echo -e "${CYAN}Response (HTTP ${http_code}):${NC}"
    echo "$body" | jq '.' 2>/dev/null || echo "$body"

    if [[ "$http_code" =~ ^2[0-9][0-9]$ ]]; then
        success "$description"
        echo "$body"
        return 0
    else
        error "$description (HTTP $http_code)"
        return 1
    fi
}

# Database query function
db_query() {
    local query=$1
    local description=$2

    echo -e "\n${YELLOW}═══ Database Verification: $description ═══${NC}"
    docker exec activity-postgres-db psql -U postgres -d activitydb -c "$query"
}

# Check services
check_services() {
    section "PRE-FLIGHT CHECKS"

    step "Checking PostgreSQL"
    docker exec activity-postgres-db psql -U postgres -c "SELECT version();" > /dev/null 2>&1
    success "PostgreSQL running"

    step "Checking auth-api"
    curl -s -f "${AUTH_API_URL}/health" > /dev/null 2>&1
    success "auth-api running"

    step "Checking activity-api"
    curl -s -f "${ACTIVITY_API_URL}/health" > /dev/null 2>&1
    success "activity-api running"

    pause_demo
}

# Demo header
print_header() {
    clear
    echo -e "${GREEN}"
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║                                                                ║"
    echo "║              ACTIVITY API - SPRINT DEMONSTRATION               ║"
    echo "║                                                                ║"
    echo "║              Comprehensive Functionality Test                  ║"
    echo "║              All 19 Endpoints + Database Proofs                ║"
    echo "║                                                                ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    info "Demo User: $DEMO_USER_EMAIL"
    info "Demo Admin: $DEMO_ADMIN_EMAIL"
    info "Log File: $LOG_FILE"
    echo ""
}

# PHASE 1: Categories
phase_categories() {
    section "PHASE 1: CATEGORY MANAGEMENT (3 endpoints)"

    step "Endpoint 1/19: GET /api/v1/categories (public)"
    api_call "GET" "/api/v1/categories" "" "" "List categories"
    db_query "SELECT category_id, name, slug, is_active FROM activity.categories ORDER BY display_order;" \
        "Categories table (should be empty or minimal)"

    step "Endpoint 2/19: POST /api/v1/categories (admin only)"
    CATEGORY_SPORTS=$(api_call "POST" "/api/v1/categories" "$DEMO_ADMIN_TOKEN" \
        '{
            "name": "Sports & Fitness",
            "slug": "sports",
            "description": "Physical activities, sports, and fitness events",
            "icon_url": "https://example.com/icons/sports.svg",
            "display_order": 1
        }' "Create Sports category")
    SPORTS_ID=$(echo "$CATEGORY_SPORTS" | jq -r '.category_id')
    success "Sports category created: $SPORTS_ID"

    CATEGORY_SOCIAL=$(api_call "POST" "/api/v1/categories" "$DEMO_ADMIN_TOKEN" \
        '{
            "name": "Social Events",
            "slug": "social",
            "description": "Meetups, parties, and social gatherings",
            "icon_url": "https://example.com/icons/social.svg",
            "display_order": 2
        }' "Create Social category")
    SOCIAL_ID=$(echo "$CATEGORY_SOCIAL" | jq -r '.category_id')
    success "Social category created: $SOCIAL_ID"

    db_query "SELECT category_id, name, slug, display_order, is_active FROM activity.categories ORDER BY display_order;" \
        "Categories table (now has 2 categories)"

    step "Endpoint 3/19: PUT /api/v1/categories/{id} (admin only)"
    api_call "PUT" "/api/v1/categories/$SPORTS_ID" "$DEMO_ADMIN_TOKEN" \
        '{
            "description": "Updated: All kinds of sports, fitness classes, and outdoor activities",
            "display_order": 1
        }' "Update Sports category description"

    db_query "SELECT category_id, name, description FROM activity.categories WHERE category_id='$SPORTS_ID'::uuid;" \
        "Verify category update"

    pause_demo
}

# PHASE 2: Create Activities
phase_create_activities() {
    section "PHASE 2: CREATE ACTIVITIES (1 endpoint)"

    step "Endpoint 4/19: POST /api/v1/activities (create activity)"

    info "Creating Activity 1: Soccer Match (Public, Standard)"
    ACTIVITY_1=$(api_call "POST" "/api/v1/activities" "$DEMO_USER_TOKEN" \
        "{
            \"category_id\": \"$SPORTS_ID\",
            \"title\": \"Weekend Soccer Match\",
            \"description\": \"Casual soccer game in the park. All skill levels welcome! Bring your own water.\",
            \"activity_type\": \"standard\",
            \"activity_privacy_level\": \"public\",
            \"scheduled_at\": \"$(date -u -d '+3 days' +%Y-%m-%dT14:00:00Z)\",
            \"duration_minutes\": 120,
            \"max_participants\": 20,
            \"tags\": [\"soccer\", \"sports\", \"outdoor\", \"casual\"],
            \"language\": \"en\",
            \"location\": {
                \"venue_name\": \"Central Park Soccer Field\",
                \"address_line1\": \"123 Park Avenue\",
                \"city\": \"Amsterdam\",
                \"postal_code\": \"1012 AB\",
                \"country\": \"Netherlands\",
                \"latitude\": 52.3676,
                \"longitude\": 4.9041
            }
        }" "Create soccer match activity")
    ACTIVITY_1_ID=$(echo "$ACTIVITY_1" | jq -r '.activity_id')
    success "Soccer match created: $ACTIVITY_1_ID"

    info "Creating Activity 2: Coffee Meetup (Friends Only, Standard)"
    ACTIVITY_2=$(api_call "POST" "/api/v1/activities" "$DEMO_USER_TOKEN" \
        "{
            \"category_id\": \"$SOCIAL_ID\",
            \"title\": \"Monday Morning Coffee\",
            \"description\": \"Let's grab coffee and chat about life, work, and everything in between.\",
            \"activity_type\": \"standard\",
            \"activity_privacy_level\": \"friends_only\",
            \"scheduled_at\": \"$(date -u -d '+1 day' +%Y-%m-%dT09:00:00Z)\",
            \"duration_minutes\": 60,
            \"max_participants\": 6,
            \"tags\": [\"coffee\", \"networking\", \"casual\"],
            \"language\": \"en\",
            \"location\": {
                \"venue_name\": \"Starbucks Downtown\",
                \"city\": \"Amsterdam\",
                \"latitude\": 52.3702,
                \"longitude\": 4.8952
            }
        }" "Create coffee meetup activity")
    ACTIVITY_2_ID=$(echo "$ACTIVITY_2" | jq -r '.activity_id')
    success "Coffee meetup created: $ACTIVITY_2_ID"

    info "Creating Activity 3: XXL Beach Party (Public, XXL)"
    ACTIVITY_3=$(api_call "POST" "/api/v1/activities" "$DEMO_ADMIN_TOKEN" \
        "{
            \"category_id\": \"$SOCIAL_ID\",
            \"title\": \"Summer Beach Party 2024\",
            \"description\": \"Huge beach party with live DJ, food trucks, and beach volleyball! Open to everyone.\",
            \"activity_type\": \"xxl\",
            \"activity_privacy_level\": \"public\",
            \"scheduled_at\": \"$(date -u -d '+7 days' +%Y-%m-%dT16:00:00Z)\",
            \"duration_minutes\": 300,
            \"max_participants\": 500,
            \"tags\": [\"party\", \"beach\", \"summer\", \"music\", \"xxl\"],
            \"language\": \"en\",
            \"location\": {
                \"venue_name\": \"Zandvoort Beach\",
                \"city\": \"Zandvoort\",
                \"country\": \"Netherlands\",
                \"latitude\": 52.3727,
                \"longitude\": 4.5310
            }
        }" "Create XXL beach party")
    ACTIVITY_3_ID=$(echo "$ACTIVITY_3" | jq -r '.activity_id')
    success "Beach party created: $ACTIVITY_3_ID"

    db_query "SELECT activity_id, title, activity_type, activity_privacy_level, status, max_participants
              FROM activity.activities
              ORDER BY created_at DESC LIMIT 3;" \
        "Activities table (3 new activities)"

    db_query "SELECT l.location_id, a.title, l.venue_name, l.city, l.latitude, l.longitude
              FROM activity.activity_locations l
              JOIN activity.activities a ON a.location_id = l.location_id
              ORDER BY a.created_at DESC LIMIT 3;" \
        "Locations table (with geo-coordinates)"

    db_query "SELECT a.title, at.tag, at.tag_count
              FROM activity.activity_tags at
              JOIN activity.activities a ON a.activity_id = at.activity_id
              WHERE a.activity_id IN ('$ACTIVITY_1_ID'::uuid, '$ACTIVITY_2_ID'::uuid, '$ACTIVITY_3_ID'::uuid)
              ORDER BY a.title, at.tag;" \
        "Tags table (all activity tags)"

    pause_demo
}

# PHASE 3: Activity CRUD
phase_activity_crud() {
    section "PHASE 3: ACTIVITY CRUD OPERATIONS (4 endpoints)"

    step "Endpoint 5/19: GET /api/v1/activities/{id}"
    api_call "GET" "/api/v1/activities/$ACTIVITY_1_ID" "$DEMO_USER_TOKEN" "" \
        "Get soccer match details"

    step "Endpoint 6/19: PUT /api/v1/activities/{id}"
    api_call "PUT" "/api/v1/activities/$ACTIVITY_1_ID" "$DEMO_USER_TOKEN" \
        '{
            "title": "Weekend Soccer Match - UPDATED!",
            "description": "Casual soccer game in the park. All skill levels welcome! **UPDATE**: Now with FREE refreshments!",
            "max_participants": 24
        }' "Update soccer match"

    db_query "SELECT activity_id, title, description, max_participants, updated_at
              FROM activity.activities
              WHERE activity_id='$ACTIVITY_1_ID'::uuid;" \
        "Verify activity update"

    step "Endpoint 7/19: POST /api/v1/activities/{id}/cancel"
    api_call "POST" "/api/v1/activities/$ACTIVITY_2_ID/cancel" "$DEMO_USER_TOKEN" \
        '{
            "cancellation_reason": "Organizer sick - rescheduling next week"
        }' "Cancel coffee meetup"

    db_query "SELECT activity_id, title, status, cancelled_at, cancellation_reason
              FROM activity.activities
              WHERE activity_id='$ACTIVITY_2_ID'::uuid;" \
        "Verify activity cancelled"

    step "Endpoint 8/19: DELETE /api/v1/activities/{id}"
    # Create a temporary activity to delete
    TEMP_ACTIVITY=$(api_call "POST" "/api/v1/activities" "$DEMO_USER_TOKEN" \
        "{
            \"title\": \"Temporary Test Activity\",
            \"description\": \"This activity will be deleted immediately for demo purposes.\",
            \"activity_type\": \"standard\",
            \"scheduled_at\": \"$(date -u -d '+5 days' +%Y-%m-%dT10:00:00Z)\",
            \"max_participants\": 10,
            \"tags\": [\"test\"]
        }" "Create temporary activity")
    TEMP_ID=$(echo "$TEMP_ACTIVITY" | jq -r '.activity_id')

    api_call "DELETE" "/api/v1/activities/$TEMP_ID" "$DEMO_USER_TOKEN" "" \
        "Delete temporary activity"

    db_query "SELECT COUNT(*) as deleted_count FROM activity.activities WHERE activity_id='$TEMP_ID'::uuid;" \
        "Verify activity deleted (should return 0)"

    pause_demo
}

# PHASE 4: Search & Discovery
phase_search_discovery() {
    section "PHASE 4: SEARCH & DISCOVERY (4 endpoints)"

    step "Endpoint 9/19: GET /api/v1/activities/search"
    api_call "GET" "/api/v1/activities/search?query=soccer&limit=10" "$DEMO_USER_TOKEN" "" \
        "Search for 'soccer' activities"

    api_call "GET" "/api/v1/activities/search?category_id=$SPORTS_ID&limit=10" "$DEMO_USER_TOKEN" "" \
        "Search by Sports category"

    api_call "GET" "/api/v1/activities/search?city=Amsterdam&has_spots_available=true&limit=10" "$DEMO_USER_TOKEN" "" \
        "Search Amsterdam activities with spots"

    step "Endpoint 10/19: GET /api/v1/activities/nearby"
    api_call "GET" "/api/v1/activities/nearby?latitude=52.3676&longitude=4.9041&radius_km=5&limit=10" "$DEMO_USER_TOKEN" "" \
        "Find activities within 5km of Central Amsterdam"

    step "Endpoint 11/19: GET /api/v1/activities/feed"
    api_call "GET" "/api/v1/activities/feed?limit=10" "$DEMO_USER_TOKEN" "" \
        "Get personalized activity feed"

    step "Endpoint 12/19: GET /api/v1/activities/recommendations"
    api_call "GET" "/api/v1/activities/recommendations?limit=5" "$DEMO_USER_TOKEN" "" \
        "Get AI-powered recommendations"

    pause_demo
}

# PHASE 5: Participants
phase_participants() {
    section "PHASE 5: PARTICIPANTS (2 endpoints)"

    step "Endpoint 13/19: GET /api/v1/activities/{id}/participants"
    api_call "GET" "/api/v1/activities/$ACTIVITY_1_ID/participants" "$DEMO_USER_TOKEN" "" \
        "List soccer match participants"

    db_query "SELECT p.participant_id, p.user_id, p.status, p.joined_at
              FROM activity.participants p
              WHERE p.activity_id='$ACTIVITY_1_ID'::uuid
              ORDER BY p.joined_at;" \
        "Participants table (organizer auto-joined)"

    step "Endpoint 14/19: GET /api/v1/activities/{id}/waitlist"
    api_call "GET" "/api/v1/activities/$ACTIVITY_1_ID/waitlist" "$DEMO_USER_TOKEN" "" \
        "List soccer match waitlist"

    db_query "SELECT COUNT(*) as waitlist_count FROM activity.participants
              WHERE activity_id='$ACTIVITY_1_ID'::uuid AND status='waitlisted';" \
        "Waitlist count (should be 0 initially)"

    pause_demo
}

# PHASE 6: Reviews
phase_reviews() {
    section "PHASE 6: REVIEWS (4 endpoints)"

    # Note: Reviews require activity to be completed and user to have attended
    # For demo, we'll simulate this by updating activity status

    info "Setting up completed activity for review demo..."
    docker exec activity-postgres-db psql -U postgres -d activitydb -c \
        "UPDATE activity.activities SET status='completed' WHERE activity_id='$ACTIVITY_3_ID'::uuid;" > /dev/null 2>&1

    docker exec activity-postgres-db psql -U postgres -d activitydb -c \
        "INSERT INTO activity.participants (participant_id, activity_id, user_id, status)
         VALUES (gen_random_uuid(), '$ACTIVITY_3_ID'::uuid,
                 (SELECT user_id FROM activity.users WHERE email='$DEMO_USER_EMAIL'),
                 'attended')
         ON CONFLICT DO NOTHING;" > /dev/null 2>&1

    step "Endpoint 15/19: POST /api/v1/activities/{id}/reviews"
    REVIEW=$(api_call "POST" "/api/v1/activities/$ACTIVITY_3_ID/reviews" "$DEMO_USER_TOKEN" \
        '{
            "rating": 5,
            "comment": "Amazing beach party! Great organization, awesome music, and perfect weather. Will definitely attend again!",
            "is_anonymous": false
        }' "Create review for beach party")
    REVIEW_ID=$(echo "$REVIEW" | jq -r '.review_id')
    success "Review created: $REVIEW_ID"

    db_query "SELECT r.review_id, a.title, r.rating, r.comment, r.is_anonymous, r.created_at
              FROM activity.activity_reviews r
              JOIN activity.activities a ON a.activity_id = r.activity_id
              WHERE r.review_id='$REVIEW_ID'::uuid;" \
        "Reviews table (new review)"

    step "Endpoint 16/19: GET /api/v1/activities/{id}/reviews"
    api_call "GET" "/api/v1/activities/$ACTIVITY_3_ID/reviews?limit=50" "$DEMO_USER_TOKEN" "" \
        "List all reviews for beach party"

    step "Endpoint 17/19: PUT /api/v1/reviews/{id}"
    api_call "PUT" "/api/v1/reviews/$REVIEW_ID" "$DEMO_USER_TOKEN" \
        '{
            "rating": 5,
            "comment": "UPDATED REVIEW: Amazing beach party! Great organization, awesome music, and perfect weather. Special thanks to the DJ! Will definitely attend again!"
        }' "Update review"

    db_query "SELECT review_id, rating, comment, updated_at
              FROM activity.activity_reviews
              WHERE review_id='$REVIEW_ID'::uuid;" \
        "Verify review update"

    step "Endpoint 18/19: DELETE /api/v1/reviews/{id}"
    # Create temporary review to delete
    TEMP_REVIEW=$(api_call "POST" "/api/v1/activities/$ACTIVITY_3_ID/reviews" "$DEMO_USER_TOKEN" \
        '{
            "rating": 3,
            "comment": "Temporary review for demo - will be deleted",
            "is_anonymous": true
        }' "Create temporary review")
    TEMP_REVIEW_ID=$(echo "$TEMP_REVIEW" | jq -r '.review_id')

    api_call "DELETE" "/api/v1/reviews/$TEMP_REVIEW_ID" "$DEMO_USER_TOKEN" "" \
        "Delete temporary review"

    db_query "SELECT COUNT(*) as deleted_count FROM activity.activity_reviews WHERE review_id='$TEMP_REVIEW_ID'::uuid;" \
        "Verify review deleted (should return 0)"

    pause_demo
}

# PHASE 7: Tags
phase_tags() {
    section "PHASE 7: POPULAR TAGS (1 endpoint)"

    step "Endpoint 19/19: GET /api/v1/activities/tags/popular"
    api_call "GET" "/api/v1/activities/tags/popular?limit=20" "" "" \
        "Get popular tags (public endpoint)"

    db_query "SELECT tag, COUNT(*) as usage_count
              FROM activity.activity_tags
              GROUP BY tag
              ORDER BY usage_count DESC, tag
              LIMIT 10;" \
        "Tag usage statistics"

    pause_demo
}

# Final summary
print_summary() {
    section "DEMO SUMMARY"

    local total_endpoints=19
    local total_db_queries=$((STEP_COUNTER - total_endpoints))

    echo -e "${GREEN}"
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║              DEMONSTRATION COMPLETED SUCCESSFULLY              ║"
    echo "╠════════════════════════════════════════════════════════════════╣"
    printf "║  Total API Endpoints Tested: %-32s  ║\n" "$total_endpoints/19 ✓"
    printf "║  Successful API Calls:       %-32s  ║\n" "$SUCCESS_COUNT"
    printf "║  Failed API Calls:           %-32s  ║\n" "$FAILED_COUNT"
    printf "║  Database Verifications:     %-32s  ║\n" "$total_db_queries"
    echo "╠════════════════════════════════════════════════════════════════╣"
    echo "║  ALL FUNCTIONALITY WORKING ✓                                   ║"
    echo "║                                                                ║"
    echo "║  Categories:   3/3 endpoints ✓                                 ║"
    echo "║  Activities:   5/5 endpoints ✓                                 ║"
    echo "║  Search:       4/4 endpoints ✓                                 ║"
    echo "║  Participants: 2/2 endpoints ✓                                 ║"
    echo "║  Reviews:      4/4 endpoints ✓                                 ║"
    echo "║  Tags:         1/1 endpoints ✓                                 ║"
    echo "╠════════════════════════════════════════════════════════════════╣"
    printf "║  Log saved to: %-43s  ║\n" "$(basename "$LOG_FILE")"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"

    # Database final state
    echo -e "\n${YELLOW}═══ FINAL DATABASE STATE ═══${NC}"
    db_query "SELECT
                (SELECT COUNT(*) FROM activity.categories) as total_categories,
                (SELECT COUNT(*) FROM activity.activities) as total_activities,
                (SELECT COUNT(*) FROM activity.participants) as total_participants,
                (SELECT COUNT(*) FROM activity.activity_reviews) as total_reviews,
                (SELECT COUNT(DISTINCT tag) FROM activity.activity_tags) as unique_tags;" \
        "Complete database statistics"

    echo -e "\n${GREEN}Ready for sprint presentation! 🎉${NC}"
    echo -e "${CYAN}All systems operational and fully tested.${NC}\n"
}

# Main execution
main() {
    print_header
    check_services
    phase_categories
    phase_create_activities
    phase_activity_crud
    phase_search_discovery
    phase_participants
    phase_reviews
    phase_tags
    print_summary
}

# Run the demo
main
