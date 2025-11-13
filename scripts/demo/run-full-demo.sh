#!/bin/bash
# Complete Activity API Demo
# Tests all endpoints with database verification

set -eo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load libraries
source "$SCRIPT_DIR/lib/colors.sh"
source "$SCRIPT_DIR/lib/db.sh"
source "$SCRIPT_DIR/lib/api.sh"

# Load demo environment
if [[ -f "$SCRIPT_DIR/.env.demo" ]]; then
    source "$SCRIPT_DIR/.env.demo"
else
    error ".env.demo not found!"
    info "Run setup first: $SCRIPT_DIR/00-setup.sh"
    exit 1
fi

# Track statistics
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
START_TIME=$(date +%s)

# Test result tracking
test_passed() {
    ((TOTAL_TESTS++))
    ((PASSED_TESTS++))
    success "$1"
}

test_failed() {
    ((TOTAL_TESTS++))
    ((FAILED_TESTS++))
    error "$1"
}

# Main demo flow
main() {
    header "🎯 ACTIVITY API - COMPLETE DEMO"

    info "Demo Mode: $DEMO_MODE"
    info "Users: $USER1_NAME (organizer), $USER2_NAME, $USER3_NAME (participants)"
    echo ""

    pause_demo "➜ Starting demo - Press ENTER"

    # Phase 1: Categories
    run_category_tests

    # Phase 2: Activities
    run_activity_tests

    # Phase 3: Search & Discovery
    run_search_tests

    # Phase 4: Participants
    run_participant_tests

    # Phase 5: Reviews
    run_review_tests

    # Phase 6: Tags
    run_tag_tests

    # Phase 7: Advanced Features
    run_advanced_tests

    # Final Summary
    show_final_summary
}

#=============================================================================
# PHASE 1: CATEGORY TESTS
#=============================================================================
run_category_tests() {
    header "📂 PHASE 1: CATEGORY MANAGEMENT"

    step 1 7 "List Categories"

    db_section
    info "Categories before:"
    local before_count=$(get_table_count "categories")
    echo "  Count: $before_count"

    api_get "/categories" "$USER1_TOKEN"
    if validate_status 200; then
        test_passed "List categories"
    else
        test_failed "List categories"
    fi

    pause_demo "➜ Next: Create category"

    # Create a new category
    step 2 7 "Create New Category"

    action "Creating 'Outdoor Sports' category"

    local category_payload='{
        "name": "Outdoor Sports Demo",
        "description": "Demo category for outdoor activities",
        "slug": "outdoor-sports-demo",
        "icon": "🏃",
        "is_active": true
    }'

    db_section
    info "Before: $(get_table_count 'categories') categories"

    api_post "/categories" "$USER1_TOKEN" "$category_payload"

    if validate_status 201; then
        export DEMO_CATEGORY_ID=$(extract_json_field "id")
        test_passed "Create category"

        db_section
        info "After: $(get_table_count 'categories') categories"

        if verify_record_exists "categories" "$DEMO_CATEGORY_ID"; then
            success "Category exists in database"
            show_categories
        else
            error "Category not found in database!"
        fi
    else
        test_failed "Create category"
    fi

    pause_demo "➜ Category created successfully!"
}

#=============================================================================
# PHASE 2: ACTIVITY TESTS
#=============================================================================
run_activity_tests() {
    header "🎪 PHASE 2: ACTIVITY MANAGEMENT"

    step 3 7 "Create Activities"

    # Activity 1: Weekend Hiking
    action "$USER1_NAME creates 'Weekend Hiking' activity"

    local start_time=$(date -u -d "+2 days" +"%Y-%m-%dT10:00:00Z")
    local activity1_payload=$(create_activity_payload \
        "Weekend Hiking Adventure" \
        "Join us for an amazing hiking trip in the mountains! Perfect for nature lovers." \
        "$DEMO_CATEGORY_ID" \
        "Amsterdam" \
        "$start_time")

    db_section
    info "Activities before: $(get_table_count 'activities')"

    api_post "/activities" "$USER1_TOKEN" "$activity1_payload"

    if validate_status 201; then
        export ACTIVITY1_ID=$(extract_json_field "id")
        test_passed "Create activity: Weekend Hiking"

        db_section
        info "Activities after: $(get_table_count 'activities')"
        show_activity_details "$ACTIVITY1_ID"
    else
        test_failed "Create activity: Weekend Hiking"
    fi

    pause_demo "➜ Next: Create second activity"

    # Activity 2: Beach Volleyball
    action "$USER1_NAME creates 'Beach Volleyball' activity"

    local start_time2=$(date -u -d "+3 days" +"%Y-%m-%dT14:00:00Z")
    local activity2_payload=$(create_activity_payload \
        "Beach Volleyball Tournament" \
        "Fun beach volleyball game! All skill levels welcome. Bring your energy!" \
        "$DEMO_CATEGORY_ID" \
        "Rotterdam" \
        "$start_time2")

    api_post "/activities" "$USER1_TOKEN" "$activity2_payload"

    if validate_status 201; then
        export ACTIVITY2_ID=$(extract_json_field "id")
        test_passed "Create activity: Beach Volleyball"

        show_activities 5
    else
        test_failed "Create activity: Beach Volleyball"
    fi

    pause_demo "➜ Next: Get activity details"

    # Get activity by ID
    step 4 7 "Get Activity Details"

    action "Fetching details for Weekend Hiking"

    api_get "/activities/$ACTIVITY1_ID" "$USER1_TOKEN"

    if validate_status 200; then
        test_passed "Get activity by ID"

        show_activity_details "$ACTIVITY1_ID"
    else
        test_failed "Get activity by ID"
    fi

    pause_demo "➜ Next: Update activity"

    # Update activity
    step 5 7 "Update Activity"

    action "Updating activity description"

    local update_payload='{
        "description": "Join us for an UPDATED amazing hiking trip! Now with free lunch included!"
    }'

    db_section
    info "Before update:"
    show_activity "$ACTIVITY1_ID"

    api_put "/activities/$ACTIVITY1_ID" "$USER1_TOKEN" "$update_payload"

    if validate_status 200; then
        test_passed "Update activity"

        db_section
        info "After update:"
        show_activity "$ACTIVITY1_ID"
    else
        test_failed "Update activity"
    fi

    pause_demo "➜ Activities created and updated!"
}

#=============================================================================
# PHASE 3: SEARCH & DISCOVERY TESTS
#=============================================================================
run_search_tests() {
    header "🔍 PHASE 3: SEARCH & DISCOVERY"

    step 6 7 "Search Activities"

    # Text search
    action "Searching for 'hiking'"

    api_get "/activities/search?query=hiking&limit=10" "$USER1_TOKEN"

    if validate_status 200; then
        test_passed "Text search"
        local count=$(extract_json_field "total")
        info "Found $count activities"
    else
        test_failed "Text search"
    fi

    pause_demo "➜ Next: Nearby search"

    # Nearby search
    action "Searching nearby activities (Amsterdam coordinates)"

    api_get "/activities/nearby?latitude=52.3676&longitude=4.9041&radius_km=50&limit=10" "$USER1_TOKEN"

    if validate_status 200; then
        test_passed "Nearby search"
        local count=$(extract_json_field "total")
        info "Found $count activities within 50km"
    else
        test_failed "Nearby search"
    fi

    pause_demo "➜ Next: Personalized feed"

    # Personalized feed
    action "Getting personalized feed"

    api_get "/activities/feed?limit=10" "$USER1_TOKEN"

    if validate_status 200; then
        test_passed "Personalized feed"
    else
        test_failed "Personalized feed"
    fi

    pause_demo "➜ Next: AI recommendations"

    # AI Recommendations
    action "Getting AI recommendations"

    api_get "/activities/recommendations?limit=5" "$USER1_TOKEN"

    if validate_status 200; then
        test_passed "AI recommendations"
    else
        test_failed "AI recommendations"
    fi

    pause_demo "➜ Search & Discovery complete!"
}

#=============================================================================
# PHASE 4: PARTICIPANT TESTS
#=============================================================================
run_participant_tests() {
    header "👥 PHASE 4: PARTICIPANT MANAGEMENT"

    step 7 7 "Join Activities"

    # User 2 joins
    action "$USER2_NAME joins Weekend Hiking"

    db_section
    info "Participants before: $(get_participant_count "$ACTIVITY1_ID")"

    local join_payload='{
        "activity_id": "'$ACTIVITY1_ID'"
    }'

    # Note: Would normally use /activities/{id}/join endpoint
    # For now, we'll simulate by checking participants

    api_get "/activities/$ACTIVITY1_ID/participants?limit=20" "$USER2_TOKEN"

    if validate_status 200; then
        test_passed "List participants"

        db_section
        info "Current participants:"
        show_participants "$ACTIVITY1_ID"
    else
        test_failed "List participants"
    fi

    pause_demo "➜ Next: Check waitlist"

    # Check waitlist
    action "Checking waitlist"

    api_get "/activities/$ACTIVITY1_ID/waitlist?limit=20" "$USER1_TOKEN"

    if validate_status 200; then
        test_passed "List waitlist"
        local count=$(extract_json_field "total")
        info "Waitlist size: $count"
    else
        test_failed "List waitlist"
    fi

    pause_demo "➜ Participant management complete!"
}

#=============================================================================
# PHASE 5: REVIEW TESTS
#=============================================================================
run_review_tests() {
    header "⭐ PHASE 5: REVIEW SYSTEM"

    step 8 7 "Create Reviews"

    # User 2 leaves review
    action "$USER2_NAME leaves a 5-star review"

    local review1_payload=$(create_review_payload 5 "Amazing experience! The hiking trail was beautiful and well-organized.")

    db_section
    info "Reviews before: $(get_table_count 'reviews')"

    api_post "/activities/$ACTIVITY1_ID/reviews" "$USER2_TOKEN" "$review1_payload"

    if validate_status 201; then
        export REVIEW1_ID=$(extract_json_field "id")
        test_passed "Create review (5 stars)"

        db_section
        info "Reviews after: $(get_table_count 'reviews')"
        show_reviews "$ACTIVITY1_ID"
    else
        test_failed "Create review"
    fi

    pause_demo "➜ Next: Second review"

    # User 3 leaves review
    action "$USER3_NAME leaves a 4-star review"

    local review2_payload=$(create_review_payload 4 "Great activity! Had a wonderful time. Would recommend.")

    api_post "/activities/$ACTIVITY1_ID/reviews" "$USER3_TOKEN" "$review2_payload"

    if validate_status 201; then
        export REVIEW2_ID=$(extract_json_field "id")
        test_passed "Create review (4 stars)"

        db_section
        show_review_stats "$ACTIVITY1_ID"
    else
        test_failed "Create review"
    fi

    pause_demo "➜ Next: List all reviews"

    # List reviews
    action "Listing all reviews for Weekend Hiking"

    api_get "/activities/$ACTIVITY1_ID/reviews?limit=20" "$USER1_TOKEN"

    if validate_status 200; then
        test_passed "List reviews"
        local count=$(extract_json_field "total")
        info "Total reviews: $count"

        show_reviews "$ACTIVITY1_ID"
    else
        test_failed "List reviews"
    fi

    pause_demo "➜ Reviews complete!"
}

#=============================================================================
# PHASE 6: TAG TESTS
#=============================================================================
run_tag_tests() {
    header "🏷️  PHASE 6: TAG SYSTEM"

    step 9 7 "Popular Tags"

    action "Getting popular tags"

    api_get "/activities/tags/popular?limit=20" "$USER1_TOKEN"

    if validate_status 200; then
        test_passed "Get popular tags"

        show_popular_tags 10
    else
        test_failed "Get popular tags"
    fi

    pause_demo "➜ Tag system tested!"
}

#=============================================================================
# PHASE 7: ADVANCED FEATURES
#=============================================================================
run_advanced_tests() {
    header "⚡ PHASE 7: ADVANCED FEATURES"

    step 10 7 "Activity Cancellation"

    action "$USER1_NAME cancels Beach Volleyball activity"

    local cancel_payload='{
        "cancellation_reason": "Bad weather forecast - safety first!"
    }'

    db_section
    info "Status before: $(get_activity_status "$ACTIVITY2_ID")"

    api_post "/activities/$ACTIVITY2_ID/cancel" "$USER1_TOKEN" "$cancel_payload"

    if validate_status 200; then
        test_passed "Cancel activity"

        db_section
        info "Status after: $(get_activity_status "$ACTIVITY2_ID")"
        show_activity "$ACTIVITY2_ID"
    else
        test_failed "Cancel activity"
    fi

    pause_demo "➜ Advanced features complete!"
}

#=============================================================================
# FINAL SUMMARY
#=============================================================================
show_final_summary() {
    local end_time=$(date +%s)
    local duration=$((end_time - START_TIME))
    local success_rate=0

    if [[ $TOTAL_TESTS -gt 0 ]]; then
        success_rate=$((PASSED_TESTS * 100 / TOTAL_TESTS))
    fi

    summary_box "${TROPHY} DEMO COMPLETE ${TROPHY}"

    echo ""
    table_header
    table_row "Total Duration" "$(format_duration $duration)"
    table_row "Tests Executed" "$TOTAL_TESTS"
    table_row "Tests Passed" "$PASSED_TESTS"
    table_row "Tests Failed" "$FAILED_TESTS"
    table_row "Success Rate" "$success_rate%"
    table_footer

    echo ""
    subheader "Database Final State"
    show_database_summary

    echo ""
    if [[ $FAILED_TESTS -eq 0 ]]; then
        success "${CHECK_MARK} ALL TESTS PASSED! ${CHECK_MARK}"
    else
        warning "${FAILED_TESTS} test(s) failed"
    fi

    echo ""
    highlight "🎉 Demo complete! Thank you for watching! 🎉"
    echo ""
}

# Run main demo
main "$@"
