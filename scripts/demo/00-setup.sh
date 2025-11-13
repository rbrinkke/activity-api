#!/bin/bash
# Setup script for Activity API Demo
# Checks prerequisites and prepares test environment

set -eo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load libraries
source "$SCRIPT_DIR/lib/colors.sh"
source "$SCRIPT_DIR/lib/db.sh"
source "$SCRIPT_DIR/lib/api.sh"

# Configuration
export DEMO_MODE="${DEMO_MODE:-interactive}"
export JWT_SECRET_KEY="${JWT_SECRET_KEY:-dev-secret-change-in-production}"

# Demo users
DEMO_USERS=(
    "sarah@demo.com:Sarah:organizer"
    "john@demo.com:John:participant"
    "emma@demo.com:Emma:participant"
)

# Main setup function
main() {
    header "🚀 ACTIVITY API - DEMO SETUP"

    step 1 5 "Check Prerequisites"
    check_prerequisites

    step 2 5 "Check Services"
    check_services

    step 3 5 "Check Database Connection"
    check_database || exit 1

    step 4 5 "Show Initial Database State"
    show_database_summary

    step 5 5 "Generate Test Users & JWT Tokens"
    generate_test_users

    summary_box "SETUP COMPLETE"

    save_environment

    success "Demo environment is ready!"
    echo ""
    info "Test users have been created:"
    echo ""
    cat "$SCRIPT_DIR/.env.demo" | grep -E "USER[0-9]_EMAIL|USER[0-9]_ID" | head -6
    echo ""
    info "To run the full demo:"
    highlight "  cd $SCRIPT_DIR && ./run-full-demo.sh"
    echo ""
}

# Check prerequisites
check_prerequisites() {
    subheader "Checking Required Tools"

    local missing=()

    # Check curl
    if command -v curl &> /dev/null; then
        success "curl is installed"
    else
        missing+=("curl")
    fi

    # Check jq
    if command -v jq &> /dev/null; then
        success "jq is installed"
    else
        warning "jq not found (optional, for prettier JSON)"
    fi

    # Check python3
    if command -v python3 &> /dev/null; then
        success "python3 is installed"
    else
        missing+=("python3")
    fi

    # Check PyJWT
    if python3 -c "import jwt" 2> /dev/null; then
        success "PyJWT is installed"
    else
        warning "PyJWT not found, attempting to install..."
        pip3 install --quiet PyJWT 2> /dev/null || missing+=("PyJWT")
    fi

    # Check docker
    if command -v docker &> /dev/null; then
        success "docker is installed"
    else
        missing+=("docker")
    fi

    if [[ ${#missing[@]} -gt 0 ]]; then
        error "Missing required tools: ${missing[*]}"
        echo ""
        info "Please install missing tools:"
        for tool in "${missing[@]}"; do
            echo "  - $tool"
        done
        exit 1
    fi

    success "All prerequisites met"
}

# Check services are running
check_services() {
    subheader "Checking Services Status"

    # Check activity-api
    if check_api_health; then
        success "activity-api is running (port 8007)"
    else
        error "activity-api is not running"
        info "Start it with: cd /mnt/d/activity/activity-api && docker compose up -d"
        exit 1
    fi

    # Check PostgreSQL
    if docker ps | grep -q "$DB_CONTAINER"; then
        success "PostgreSQL is running ($DB_CONTAINER)"
    else
        error "PostgreSQL container is not running"
        info "Start infrastructure with: cd /mnt/d/activity && ./scripts/start-infra.sh"
        exit 1
    fi

    success "All services are running"
}

# Generate test users with JWT tokens
generate_test_users() {
    subheader "Creating Test Users"

    local user_data=()

    for user_info in "${DEMO_USERS[@]}"; do
        local email=$(echo "$user_info" | cut -d':' -f1)
        local name=$(echo "$user_info" | cut -d':' -f2)
        local role=$(echo "$user_info" | cut -d':' -f3)

        info "Creating user: $name ($email) - $role"

        # Generate UUID
        local user_id=$(python3 -c "import uuid; print(uuid.uuid4())")

        # Generate JWT token
        local subscription="free"
        if [[ "$role" == "organizer" ]]; then
            subscription="premium"
        fi

        local token=$(python3 -c "
import jwt
from datetime import datetime, timedelta

payload = {
    'sub': '$user_id',
    'email': '$email',
    'subscription_level': '$subscription',
    'ghost_mode': False,
    'exp': datetime.utcnow() + timedelta(days=7)
}

token = jwt.encode(payload, '$JWT_SECRET_KEY', algorithm='HS256')
print(token)
")

        if [[ -n "$token" ]]; then
            success "  ✓ Generated token for $name"
            user_data+=("$user_id:$email:$name:$role:$token")
        else
            error "  ✗ Failed to generate token for $name"
            exit 1
        fi
    done

    # Export to environment file
    local env_file="$SCRIPT_DIR/.env.demo"
    echo "# Demo Environment - Generated at $(date)" > "$env_file"
    echo "" >> "$env_file"

    for i in "${!user_data[@]}"; do
        local idx=$((i + 1))
        local data="${user_data[$i]}"
        local user_id=$(echo "$data" | cut -d':' -f1)
        local email=$(echo "$data" | cut -d':' -f2)
        local name=$(echo "$data" | cut -d':' -f3)
        local role=$(echo "$data" | cut -d':' -f4)
        local token=$(echo "$data" | cut -d':' -f5)

        echo "# User $idx: $name ($role)" >> "$env_file"
        echo "export USER${idx}_ID='$user_id'" >> "$env_file"
        echo "export USER${idx}_EMAIL='$email'" >> "$env_file"
        echo "export USER${idx}_NAME='$name'" >> "$env_file"
        echo "export USER${idx}_ROLE='$role'" >> "$env_file"
        echo "export USER${idx}_TOKEN='$token'" >> "$env_file"
        echo "" >> "$env_file"
    done

    success "Test users saved to .env.demo"

    # Source the environment file
    source "$env_file"
}

# Save environment for other scripts
save_environment() {
    local env_file="$SCRIPT_DIR/.env.demo"

    # Add additional config
    cat >> "$env_file" <<EOF
# API Configuration
export API_BASE_URL='http://localhost:8007'
export DEMO_MODE='$DEMO_MODE'

# Database Configuration
export DB_CONTAINER='$DB_CONTAINER'
export DB_USER='$DB_USER'
export DB_NAME='$DB_NAME'
export DB_SCHEMA='$DB_SCHEMA'
EOF

    success "Environment configuration saved"
}

# Run main
main "$@"
