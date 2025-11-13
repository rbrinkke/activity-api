#!/bin/bash
# Color and formatting library for Activity API Demo
# Professional output with ANSI colors and Unicode symbols

# ANSI Color Codes
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export BLUE='\033[0;34m'
export MAGENTA='\033[0;35m'
export CYAN='\033[0;36m'
export WHITE='\033[1;37m'
export GRAY='\033[0;90m'
export NC='\033[0m' # No Color

# Bold variants
export BOLD='\033[1m'
export DIM='\033[2m'

# Unicode symbols
export CHECK_MARK="✓"
export CROSS_MARK="✗"
export ARROW="→"
export BULLET="•"
export STAR="★"
export ROCKET="🚀"
export TARGET="🎯"
export FIRE="🔥"
export TROPHY="🏆"
export CHART="📊"
export DATABASE="🗄️"
export CLOUD="☁️"
export LOCATION="📍"
export USER="👤"
export CLOCK="⏱️"

# Section header
header() {
    local title="$1"
    local width=60
    echo ""
    echo -e "${YELLOW}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    printf "${YELLOW}${BOLD}%s${NC}\n" "$(center_text "$title" $width)"
    echo -e "${YELLOW}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

# Subsection header
subheader() {
    local title="$1"
    echo ""
    echo -e "${CYAN}${BOLD}▼ ${title}${NC}"
    echo -e "${CYAN}─────────────────────────────────────────────────────${NC}"
}

# Success message
success() {
    echo -e "${GREEN}${CHECK_MARK} $1${NC}"
}

# Error message
error() {
    echo -e "${RED}${CROSS_MARK} ERROR: $1${NC}" >&2
}

# Warning message
warning() {
    echo -e "${YELLOW}⚠ WARNING: $1${NC}"
}

# Info message
info() {
    echo -e "${BLUE}${BULLET} $1${NC}"
}

# Step indicator
step() {
    local current=$1
    local total=$2
    local description=$3
    echo ""
    echo -e "${MAGENTA}${BOLD}${LOCATION} STEP $current/$total: ${description}${NC}"
    echo ""
}

# Action indicator
action() {
    echo -e "${CYAN}${ARROW} $1${NC}"
}

# Database section
db_section() {
    echo ""
    echo -e "${BLUE}${BOLD}${DATABASE} DATABASE STATE:${NC}"
}

# API section
api_section() {
    echo ""
    echo -e "${GREEN}${BOLD}${CLOUD} API RESPONSE:${NC}"
}

# Highlight important text
highlight() {
    echo -e "${YELLOW}${BOLD}$1${NC}"
}

# Dimmed text for less important info
dim() {
    echo -e "${GRAY}$1${NC}"
}

# Center text within given width
center_text() {
    local text="$1"
    local width=${2:-60}
    local text_length=${#text}
    local padding=$(( (width - text_length) / 2 ))
    printf "%*s%s%*s" $padding "" "$text" $((width - text_length - padding)) ""
}

# Format JSON with colors (requires jq)
format_json() {
    if command -v jq &> /dev/null; then
        jq -C '.'
    else
        cat
    fi
}

# Print table header
table_header() {
    echo -e "${BOLD}${BLUE}┌─────────────────────────────────────────────────────────────┐${NC}"
}

# Print table row
table_row() {
    local label="$1"
    local value="$2"
    printf "${BLUE}│${NC} ${BOLD}%-20s${NC} │ %-35s ${BLUE}│${NC}\n" "$label" "$value"
}

# Print table footer
table_footer() {
    echo -e "${BLUE}└─────────────────────────────────────────────────────────────┘${NC}"
}

# Progress bar
progress_bar() {
    local current=$1
    local total=$2
    local width=40
    local percentage=$((current * 100 / total))
    local filled=$((width * current / total))
    local empty=$((width - filled))

    printf "\r${CYAN}Progress: [${NC}"
    printf "%${filled}s" | tr ' ' '▰'
    printf "%${empty}s" | tr ' ' '▱'
    printf "${CYAN}] %3d%%${NC}" $percentage

    if [[ $current -eq $total ]]; then
        echo ""
    fi
}

# Duration formatting
format_duration() {
    local seconds=$1
    local minutes=$((seconds / 60))
    local remaining_seconds=$((seconds % 60))

    if [[ $minutes -gt 0 ]]; then
        echo "${minutes}m ${remaining_seconds}s"
    else
        echo "${seconds}s"
    fi
}

# HTTP status code with color
format_http_status() {
    local status=$1
    case $status in
        200|201|204)
            echo -e "${GREEN}${status}${NC}"
            ;;
        400|401|403|404)
            echo -e "${RED}${status}${NC}"
            ;;
        500|502|503)
            echo -e "${RED}${BOLD}${status}${NC}"
            ;;
        *)
            echo -e "${YELLOW}${status}${NC}"
            ;;
    esac
}

# Summary box
summary_box() {
    local title="$1"
    echo ""
    echo -e "${GREEN}${BOLD}╔════════════════════════════════════════════════════════════╗${NC}"
    printf "${GREEN}${BOLD}║${NC}%s${GREEN}${BOLD}║${NC}\n" "$(center_text "$title" 60)"
    echo -e "${GREEN}${BOLD}╚════════════════════════════════════════════════════════════╝${NC}"
}

# Pause for demo
pause_demo() {
    local message="${1:-Press ENTER to continue...}"
    local mode="${DEMO_MODE:-interactive}"

    if [[ "$mode" == "interactive" ]]; then
        echo ""
        echo -e "${CYAN}${message}${NC}"
        read -r -p ""
    else
        sleep 1
    fi
}
