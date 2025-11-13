#!/bin/bash
# Setup Demo Users for Activity API Demo
# Creates demo users via auth-api for sprint demonstration

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
AUTH_API_URL="http://localhost:8000"
ACTIVITY_API_URL="http://localhost:8007"
CREDENTIALS_FILE=".demo_credentials"

# Demo user credentials (unique timestamp to avoid conflicts)
TIMESTAMP=$(date +%s)
DEMO_USER_EMAIL="sprint-demo-${TIMESTAMP}@activity.com"
DEMO_USER_PASSWORD="DemoPassword123"
DEMO_ADMIN_EMAIL="sprint-admin-${TIMESTAMP}@activity.com"
DEMO_ADMIN_PASSWORD="AdminPassword123"

echo -e "${BLUE}"
echo "╔════════════════════════════════════════════════════╗"
echo "║   Activity API - Demo User Setup                   ║"
echo "║   Sprint Demonstration Preparation                 ║"
echo "╚════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Function to check if service is running
check_service() {
    local url=$1
    local name=$2

    echo -ne "${BLUE}Checking ${name}...${NC} "
    if curl -s -f "${url}/health" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Running${NC}"
        return 0
    else
        echo -e "${RED}✗ Not running${NC}"
        return 1
    fi
}

# Function to register user
register_user() {
    local email=$1
    local password=$2
    local subscription=${3:-free}

    echo -ne "${BLUE}Registering ${email}...${NC} "

    response=$(curl -s -w "\n%{http_code}" -X POST "${AUTH_API_URL}/api/auth/register" \
        -H "Content-Type: application/json" \
        -d "{
            \"email\": \"${email}\",
            \"password\": \"${password}\",
            \"subscription_level\": \"${subscription}\"
        }" 2>&1)

    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | head -n-1)

    if [ "$http_code" = "201" ] || [ "$http_code" = "200" ]; then
        user_id=$(echo "$body" | grep -o '"user_id":"[^"]*' | cut -d'"' -f4)
        echo -e "${GREEN}✓ Created (ID: ${user_id})${NC}"
        echo "$user_id"
        return 0
    elif echo "$body" | grep -q "already exists"; then
        user_id=$(echo "$body" | grep -o '"user_id":"[^"]*' | cut -d'"' -f4 || echo "existing")
        echo -e "${YELLOW}⚠ Already exists${NC}"
        echo "$user_id"
        return 0
    else
        echo -e "${RED}✗ Failed (HTTP ${http_code})${NC}"
        echo "$body" | head -n 3
        return 1
    fi
}

# Function to verify user email
verify_user() {
    local user_id=$1
    local email=$2

    echo -ne "${BLUE}Verifying ${email}...${NC} "

    # Skip if user_id is 'existing'
    if [ "$user_id" = "existing" ]; then
        echo -e "${YELLOW}⚠ Skipped (already exists)${NC}"
        return 0
    fi

    # Direct database update for demo purposes
    result=$(docker exec activity-postgres-db psql -U postgres -d activitydb -c \
        "SELECT activity.sp_verify_user_email('${user_id}'::uuid);" 2>&1)

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Verified${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠ Skipped (likely already verified)${NC}"
        return 0
    fi
}

# Function to test login
test_login() {
    local email=$1
    local password=$2

    echo -ne "${BLUE}Testing login for ${email}...${NC} "

    response=$(curl -s -w "\n%{http_code}" -X POST "${AUTH_API_URL}/api/auth/login" \
        -H "Content-Type: application/json" \
        -d "{
            \"email\": \"${email}\",
            \"password\": \"${password}\"
        }" 2>&1)

    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | head -n-1)

    if [ "$http_code" = "200" ]; then
        token=$(echo "$body" | grep -o '"access_token":"[^"]*' | cut -d'"' -f4)
        if [ -n "$token" ]; then
            echo -e "${GREEN}✓ Success${NC}"
            echo "$token"
            return 0
        fi
    fi

    echo -e "${RED}✗ Failed (HTTP ${http_code})${NC}"
    echo "$body" | head -n 3
    return 1
}

# Main execution
echo -e "\n${YELLOW}[1] Checking Services${NC}"
check_service "$AUTH_API_URL" "auth-api" || { echo -e "${RED}Error: auth-api not running!${NC}"; exit 1; }
check_service "$ACTIVITY_API_URL" "activity-api" || { echo -e "${RED}Error: activity-api not running!${NC}"; exit 1; }

echo -e "\n${YELLOW}[2] Creating Demo Users${NC}"

# Register demo user (free tier)
user_id=$(register_user "$DEMO_USER_EMAIL" "$DEMO_USER_PASSWORD" "free")
if [ $? -eq 0 ] && [ "$user_id" != "existing" ]; then
    verify_user "$user_id" "$DEMO_USER_EMAIL"
fi

# Register demo admin (premium tier for full features)
admin_id=$(register_user "$DEMO_ADMIN_EMAIL" "$DEMO_ADMIN_PASSWORD" "premium")
if [ $? -eq 0 ] && [ "$admin_id" != "existing" ]; then
    verify_user "$admin_id" "$DEMO_ADMIN_EMAIL"
fi

echo -e "\n${YELLOW}[3] Testing Authentication${NC}"

# Test login and get tokens
user_token=$(test_login "$DEMO_USER_EMAIL" "$DEMO_USER_PASSWORD")
admin_token=$(test_login "$DEMO_ADMIN_EMAIL" "$DEMO_ADMIN_PASSWORD")

# Save credentials to file
echo -e "\n${YELLOW}[4] Saving Credentials${NC}"
cat > "$CREDENTIALS_FILE" <<EOF
# Demo User Credentials - Generated $(date)
# DO NOT COMMIT THIS FILE

DEMO_USER_EMAIL="$DEMO_USER_EMAIL"
DEMO_USER_PASSWORD="$DEMO_USER_PASSWORD"
DEMO_USER_TOKEN="$user_token"

DEMO_ADMIN_EMAIL="$DEMO_ADMIN_EMAIL"
DEMO_ADMIN_PASSWORD="$DEMO_ADMIN_PASSWORD"
DEMO_ADMIN_TOKEN="$admin_token"

AUTH_API_URL="$AUTH_API_URL"
ACTIVITY_API_URL="$ACTIVITY_API_URL"
EOF

chmod 600 "$CREDENTIALS_FILE"
echo -e "${GREEN}✓ Credentials saved to ${CREDENTIALS_FILE}${NC}"

# Database verification
echo -e "\n${YELLOW}[5] Database Verification${NC}"
echo -e "${BLUE}Demo users in database:${NC}"
docker exec activity-postgres-db psql -U postgres -d activitydb -c \
    "SELECT user_id, email, is_verified, subscription_level
     FROM activity.users
     WHERE email LIKE 'demo-%@activity.com'
     ORDER BY email;"

echo -e "\n${GREEN}"
echo "╔════════════════════════════════════════════════════╗"
echo "║              Setup Complete! ✓                     ║"
echo "╠════════════════════════════════════════════════════╣"
echo "║  Demo User:  ${DEMO_USER_EMAIL}       ║"
echo "║  Demo Admin: ${DEMO_ADMIN_EMAIL}      ║"
echo "║  Credentials stored in: ${CREDENTIALS_FILE}        ║"
echo "╠════════════════════════════════════════════════════╣"
echo "║  Ready for sprint demo! Run:                       ║"
echo "║  ./scripts/demo/demo_activity_api.sh               ║"
echo "╚════════════════════════════════════════════════════╝"
echo -e "${NC}"
