#!/bin/bash
# Database helper functions for Activity API Demo
# PostgreSQL query functions with formatted output

# Load colors (if not already loaded)
if [[ -z "$GREEN" ]]; then
    LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    source "$LIB_DIR/colors.sh"
fi

# Database connection settings
DB_CONTAINER="activity-postgres-db"
DB_USER="postgres"
DB_NAME="activitydb"
DB_SCHEMA="activity"

# Execute SQL query
db_query() {
    local query="$1"
    docker exec -i "$DB_CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" -c "$query" 2>&1
}

# Execute SQL query and return only data (no headers)
db_query_raw() {
    local query="$1"
    docker exec -i "$DB_CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" -t -c "$query" 2>&1 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

# Check if database is accessible
check_database() {
    info "Checking database connection..."
    if docker exec "$DB_CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" -c "SELECT 1;" > /dev/null 2>&1; then
        success "Database connection OK"
        return 0
    else
        error "Cannot connect to database"
        return 1
    fi
}

# Get total count from table
get_table_count() {
    local table="$1"
    db_query_raw "SELECT COUNT(*) FROM ${DB_SCHEMA}.${table};"
}

# Show activity by ID
show_activity() {
    local activity_id="$1"
    db_section
    db_query "
        SELECT
            id,
            title,
            status,
            activity_type,
            participant_count,
            max_participants,
            TO_CHAR(created_at, 'YYYY-MM-DD HH24:MI:SS') as created_at
        FROM ${DB_SCHEMA}.activities
        WHERE id = '$activity_id';
    " | head -20
}

# Show all activities (limited)
show_activities() {
    local limit="${1:-10}"
    db_section
    info "Recent activities (limit: $limit):"
    db_query "
        SELECT
            LEFT(id::text, 8) as id,
            title,
            status,
            participant_count as participants,
            TO_CHAR(created_at, 'MM-DD HH24:MI') as created
        FROM ${DB_SCHEMA}.activities
        ORDER BY created_at DESC
        LIMIT $limit;
    "
}

# Show activity with full details
show_activity_details() {
    local activity_id="$1"
    db_section
    info "Activity details for ID: ${activity_id:0:8}..."

    local query="
        SELECT
            'ID' as field, LEFT(id::text, 36) as value FROM ${DB_SCHEMA}.activities WHERE id = '$activity_id'
        UNION ALL
        SELECT 'Title', title FROM ${DB_SCHEMA}.activities WHERE id = '$activity_id'
        UNION ALL
        SELECT 'Description', LEFT(description, 50) || '...' FROM ${DB_SCHEMA}.activities WHERE id = '$activity_id'
        UNION ALL
        SELECT 'Status', status FROM ${DB_SCHEMA}.activities WHERE id = '$activity_id'
        UNION ALL
        SELECT 'Type', activity_type FROM ${DB_SCHEMA}.activities WHERE id = '$activity_id'
        UNION ALL
        SELECT 'Participants', participant_count::text || '/' || max_participants::text FROM ${DB_SCHEMA}.activities WHERE id = '$activity_id'
        UNION ALL
        SELECT 'Location', city || ', ' || country FROM ${DB_SCHEMA}.activities WHERE id = '$activity_id'
        UNION ALL
        SELECT 'Created', TO_CHAR(created_at, 'YYYY-MM-DD HH24:MI:SS') FROM ${DB_SCHEMA}.activities WHERE id = '$activity_id';
    "

    db_query "$query"
}

# Show participants for activity
show_participants() {
    local activity_id="$1"
    db_section
    info "Participants for activity ${activity_id:0:8}..."

    db_query "
        SELECT
            LEFT(p.user_id::text, 8) as user,
            p.status,
            TO_CHAR(p.joined_at, 'YYYY-MM-DD HH24:MI') as joined
        FROM ${DB_SCHEMA}.participants p
        WHERE p.activity_id = '$activity_id'
        ORDER BY p.joined_at;
    "
}

# Get participant count
get_participant_count() {
    local activity_id="$1"
    db_query_raw "
        SELECT COUNT(*)
        FROM ${DB_SCHEMA}.participants
        WHERE activity_id = '$activity_id' AND status = 'confirmed';
    "
}

# Show reviews for activity
show_reviews() {
    local activity_id="$1"
    db_section
    info "Reviews for activity ${activity_id:0:8}..."

    db_query "
        SELECT
            LEFT(r.id::text, 8) as review_id,
            r.rating,
            LEFT(r.comment, 40) || '...' as comment,
            TO_CHAR(r.created_at, 'MM-DD HH24:MI') as created
        FROM ${DB_SCHEMA}.reviews r
        WHERE r.activity_id = '$activity_id'
        ORDER BY r.created_at DESC;
    "
}

# Get review statistics
show_review_stats() {
    local activity_id="$1"
    db_section
    info "Review statistics:"

    db_query "
        SELECT
            COUNT(*) as total_reviews,
            ROUND(AVG(rating)::numeric, 2) as avg_rating,
            MIN(rating) as min_rating,
            MAX(rating) as max_rating
        FROM ${DB_SCHEMA}.reviews
        WHERE activity_id = '$activity_id';
    "
}

# Show categories
show_categories() {
    db_section
    info "Available categories:"

    db_query "
        SELECT
            LEFT(id::text, 8) as id,
            name,
            slug,
            is_active
        FROM ${DB_SCHEMA}.categories
        ORDER BY name;
    "
}

# Get category by slug
get_category_by_slug() {
    local slug="$1"
    db_query_raw "
        SELECT id
        FROM ${DB_SCHEMA}.categories
        WHERE slug = '$slug';
    "
}

# Show popular tags
show_popular_tags() {
    local limit="${1:-10}"
    db_section
    info "Popular tags (limit: $limit):"

    db_query "
        SELECT
            t.name,
            COUNT(at.activity_id) as usage_count
        FROM ${DB_SCHEMA}.tags t
        LEFT JOIN ${DB_SCHEMA}.activity_tags at ON t.id = at.tag_id
        GROUP BY t.id, t.name
        ORDER BY usage_count DESC, t.name
        LIMIT $limit;
    "
}

# Verify record exists
verify_record_exists() {
    local table="$1"
    local id="$2"
    local exists=$(db_query_raw "SELECT EXISTS(SELECT 1 FROM ${DB_SCHEMA}.${table} WHERE id='$id');")

    if [[ "$exists" == "t" ]]; then
        return 0
    else
        return 1
    fi
}

# Compare counts before/after
compare_table_counts() {
    local table="$1"
    local before="$2"
    local after=$(get_table_count "$table")
    local diff=$((after - before))

    if [[ $diff -gt 0 ]]; then
        echo -e "${GREEN}+${diff}${NC} (${before} → ${after})"
    elif [[ $diff -lt 0 ]]; then
        echo -e "${RED}${diff}${NC} (${before} → ${after})"
    else
        echo -e "${GRAY}${diff}${NC} (unchanged: ${after})"
    fi
}

# Show database summary
show_database_summary() {
    db_section
    info "Database summary:"

    table_header
    table_row "Categories" "$(get_table_count 'categories')"
    table_row "Activities" "$(get_table_count 'activities')"
    table_row "Participants" "$(get_table_count 'participants')"
    table_row "Reviews" "$(get_table_count 'reviews')"
    table_row "Tags" "$(get_table_count 'tags')"
    table_footer
}

# Clean up test data (use with caution!)
cleanup_test_data() {
    warning "Cleaning up test data..."

    db_query "
        -- Delete in correct order due to foreign keys
        DELETE FROM ${DB_SCHEMA}.reviews WHERE activity_id IN (
            SELECT id FROM ${DB_SCHEMA}.activities WHERE title LIKE '%TEST%' OR title LIKE '%Demo%'
        );

        DELETE FROM ${DB_SCHEMA}.participants WHERE activity_id IN (
            SELECT id FROM ${DB_SCHEMA}.activities WHERE title LIKE '%TEST%' OR title LIKE '%Demo%'
        );

        DELETE FROM ${DB_SCHEMA}.activity_tags WHERE activity_id IN (
            SELECT id FROM ${DB_SCHEMA}.activities WHERE title LIKE '%TEST%' OR title LIKE '%Demo%'
        );

        DELETE FROM ${DB_SCHEMA}.activities WHERE title LIKE '%TEST%' OR title LIKE '%Demo%';
    " > /dev/null 2>&1

    success "Test data cleaned"
}

# Get activity status
get_activity_status() {
    local activity_id="$1"
    db_query_raw "SELECT status FROM ${DB_SCHEMA}.activities WHERE id='$activity_id';"
}

# Get user by email (for testing)
get_user_by_email() {
    local email="$1"
    db_query_raw "SELECT id FROM ${DB_SCHEMA}.users WHERE email='$email';"
}
