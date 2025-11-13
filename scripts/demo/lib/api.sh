#!/bin/bash
# API helper functions for Activity API Demo
# HTTP request helpers with response validation

# Load colors (if not already loaded)
if [[ -z "$GREEN" ]]; then
    LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    source "$LIB_DIR/colors.sh"
fi

# API Configuration
API_BASE_URL="${API_BASE_URL:-http://localhost:8007}"
API_PREFIX="/api/v1"

# Make API request and capture response + status code
api_request() {
    local method="$1"
    local endpoint="$2"
    local token="$3"
    local data="$4"

    local url="${API_BASE_URL}${API_PREFIX}${endpoint}"

    action "API Request: $method $endpoint"

    local response
    if [[ -n "$data" ]]; then
        response=$(curl -s -w "\n%{http_code}" -X "$method" "$url" \
            -H "Authorization: Bearer $token" \
            -H "Content-Type: application/json" \
            -d "$data" 2>&1)
    else
        response=$(curl -s -w "\n%{http_code}" -X "$method" "$url" \
            -H "Authorization: Bearer $token" 2>&1)
    fi

    # Split response body and status code
    local body=$(echo "$response" | head -n -1)
    local status=$(echo "$response" | tail -n 1)

    # Store in global variables for access
    export LAST_API_RESPONSE="$body"
    export LAST_API_STATUS="$status"

    # Print formatted response
    api_section
    echo -ne "Status: "
    format_http_status "$status"
    echo ""

    if [[ -n "$body" ]]; then
        echo "$body" | format_json 2>/dev/null || echo "$body"
    fi

    # Return status code
    return "$status"
}

# GET request
api_get() {
    local endpoint="$1"
    local token="$2"
    api_request "GET" "$endpoint" "$token" ""
}

# POST request
api_post() {
    local endpoint="$1"
    local token="$2"
    local data="$3"
    api_request "POST" "$endpoint" "$token" "$data"
}

# PUT request
api_put() {
    local endpoint="$1"
    local token="$2"
    local data="$3"
    api_request "PUT" "$endpoint" "$token" "$data"
}

# DELETE request
api_delete() {
    local endpoint="$1"
    local token="$2"
    api_request "DELETE" "$endpoint" "$token" ""
}

# Extract field from JSON response
extract_json_field() {
    local field="$1"
    local json="${2:-$LAST_API_RESPONSE}"

    if command -v jq &> /dev/null; then
        echo "$json" | jq -r ".$field"
    else
        # Fallback without jq (basic extraction)
        echo "$json" | grep -o "\"$field\":\"[^\"]*\"" | cut -d'"' -f4
    fi
}

# Validate HTTP status code
validate_status() {
    local expected="$1"
    local actual="${2:-$LAST_API_STATUS}"

    if [[ "$actual" == "$expected" ]]; then
        success "Status code: $actual (expected: $expected)"
        return 0
    else
        error "Status code: $actual (expected: $expected)"
        return 1
    fi
}

# Validate response contains field
validate_field_exists() {
    local field="$1"
    local value=$(extract_json_field "$field")

    if [[ -n "$value" && "$value" != "null" ]]; then
        success "Field '$field' exists with value: $value"
        echo "$value"
        return 0
    else
        error "Field '$field' not found in response"
        return 1
    fi
}

# Check API health
check_api_health() {
    info "Checking API health..."

    local response=$(curl -s "${API_BASE_URL}/health" 2>&1)
    local status=$?

    if [[ $status -eq 0 ]]; then
        success "Activity API is running"
        dim "Response: $response"
        return 0
    else
        error "Activity API is not responding"
        return 1
    fi
}

# Generate JWT token using Python
generate_jwt_token() {
    local user_id="$1"
    local email="$2"
    local jwt_secret="${JWT_SECRET_KEY:-dev-secret-change-in-production}"

    info "Generating JWT token for $email..."

    local token=$(python3 -c "
import jwt
import uuid
from datetime import datetime, timedelta

payload = {
    'sub': '$user_id',
    'email': '$email',
    'subscription_level': 'premium',
    'ghost_mode': False,
    'exp': datetime.utcnow() + timedelta(days=1)
}

token = jwt.encode(payload, '$jwt_secret', algorithm='HS256')
print(token)
" 2>/dev/null)

    if [[ -n "$token" ]]; then
        success "Token generated"
        echo "$token"
        return 0
    else
        error "Failed to generate token"
        return 1
    fi
}

# Create test user (generates UUID and token)
create_test_user() {
    local email="$1"
    local name="${2:-Test User}"

    info "Creating test user: $email"

    # Generate UUID for user
    local user_id=$(python3 -c "import uuid; print(uuid.uuid4())")

    # Generate token
    local token=$(generate_jwt_token "$user_id" "$email")

    if [[ -n "$token" ]]; then
        export TEST_USER_ID="$user_id"
        export TEST_USER_EMAIL="$email"
        export TEST_USER_TOKEN="$token"

        success "Test user created"
        info "  User ID: ${user_id:0:8}..."
        info "  Email: $email"
        dim "  Token: ${token:0:50}..."

        echo "$user_id:$email:$token"
        return 0
    else
        error "Failed to create test user"
        return 1
    fi
}

# Parse test user data
parse_user_data() {
    local data="$1"
    export TEST_USER_ID=$(echo "$data" | cut -d':' -f1)
    export TEST_USER_EMAIL=$(echo "$data" | cut -d':' -f2)
    export TEST_USER_TOKEN=$(echo "$data" | cut -d':' -f3)
}

# Format curl command for display (for documentation)
format_curl_command() {
    local method="$1"
    local endpoint="$2"
    local token="$3"
    local data="$4"

    echo "curl -X $method \\"
    echo "  ${API_BASE_URL}${API_PREFIX}${endpoint} \\"
    echo "  -H 'Authorization: Bearer \$TOKEN' \\"

    if [[ -n "$data" ]]; then
        echo "  -H 'Content-Type: application/json' \\"
        echo "  -d '$data'"
    fi
}

# Test endpoint with validation
test_endpoint() {
    local method="$1"
    local endpoint="$2"
    local token="$3"
    local data="$4"
    local expected_status="${5:-200}"

    step_description="Test $method $endpoint"
    action "$step_description"

    api_request "$method" "$endpoint" "$token" "$data"
    local status=$?

    if validate_status "$expected_status"; then
        success "Test passed: $step_description"
        return 0
    else
        error "Test failed: $step_description"
        return 1
    fi
}

# Measure response time
measure_response_time() {
    local method="$1"
    local endpoint="$2"
    local token="$3"
    local data="$4"

    local start_time=$(date +%s%N)
    api_request "$method" "$endpoint" "$token" "$data" > /dev/null 2>&1
    local end_time=$(date +%s%N)

    local duration_ns=$((end_time - start_time))
    local duration_ms=$((duration_ns / 1000000))

    echo "$duration_ms"
}

# Pretty print JSON payload for display
pretty_json() {
    local json="$1"
    if command -v jq &> /dev/null; then
        echo "$json" | jq '.'
    else
        echo "$json"
    fi
}

# Create activity payload
create_activity_payload() {
    local title="$1"
    local description="$2"
    local category_id="$3"
    local location="$4"
    local start_time="$5"

    cat <<EOF
{
  "title": "$title",
  "description": "$description",
  "category_id": "$category_id",
  "activity_type": "in_person",
  "start_time": "$start_time",
  "duration_minutes": 120,
  "location": {
    "address": "Test Address 123",
    "city": "$location",
    "country": "Netherlands",
    "latitude": 52.3676,
    "longitude": 4.9041
  },
  "max_participants": 10,
  "language": "en",
  "tags": ["demo", "test"]
}
EOF
}

# Create review payload
create_review_payload() {
    local rating="$1"
    local comment="$2"

    cat <<EOF
{
  "rating": $rating,
  "comment": "$comment",
  "is_anonymous": false
}
EOF
}
