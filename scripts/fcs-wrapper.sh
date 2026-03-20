#!/usr/bin/env bash

# FCS CLI Wrapper Script
# Enhanced wrapper with logging, error handling, and notifications

set -euo pipefail

# Configuration
LOG_DIR="${LOG_DIR:-./logs}"
LOG_FILE="${LOG_DIR}/fcs-cli-$(date +%Y%m%d-%H%M%S).log"
ENABLE_SLACK_NOTIFICATIONS="${ENABLE_SLACK_NOTIFICATIONS:-false}"
SLACK_WEBHOOK_URL="${SLACK_WEBHOOK_URL:-}"
MAX_RETRIES="${MAX_RETRIES:-3}"
RETRY_DELAY="${RETRY_DELAY:-5}"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging functions
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp
    timestamp=$(date +"%Y-%m-%d %H:%M:%S")

    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE" >&2
}

# Setup logging
setup_logging() {
    mkdir -p "$LOG_DIR"
    log_info "Log file: $LOG_FILE"
}

# Send Slack notification
send_slack_notification() {
    local status="$1"
    local message="$2"

    if [[ "$ENABLE_SLACK_NOTIFICATIONS" != "true" ]] || [[ -z "$SLACK_WEBHOOK_URL" ]]; then
        return 0
    fi

    local color
    case "$status" in
        success) color="good" ;;
        warning) color="warning" ;;
        error) color="danger" ;;
        *) color="#439FE0" ;;
    esac

    local payload
    payload=$(cat <<EOF
{
    "attachments": [{
        "color": "$color",
        "title": "FCS CLI Scan $status",
        "text": "$message",
        "footer": "FCS CLI Wrapper",
        "ts": $(date +%s)
    }]
}
EOF
)

    curl -X POST -H 'Content-type: application/json' \
        --data "$payload" \
        "$SLACK_WEBHOOK_URL" &>/dev/null || true
}

# Detect the container daemon socket and set FCS_SOCKET_ARG
# fcs ignores DOCKER_HOST — use --socket flag instead
detect_socket() {
    if [[ -n "${FCS_SOCKET:-}" ]]; then
        FCS_SOCKET_ARG="--socket ${FCS_SOCKET}"
        log_info "Using FCS_SOCKET=${FCS_SOCKET}"
        return
    fi

    local sockets=(
        "/Users/$(whoami)/.rd/docker.sock"
        "/var/run/docker.sock"
        "/run/docker.sock"
        "/run/user/1000/podman/podman.sock"
        "/run/containerd/containerd.sock"
    )
    for sock in "${sockets[@]}"; do
        if [[ -S "$sock" ]]; then
            FCS_SOCKET_ARG="--socket unix://${sock}"
            log_info "Auto-detected socket: unix://${sock}"
            return
        fi
    done

    FCS_SOCKET_ARG=""
    log_warn "No container daemon socket found; fcs will use its own discovery"
}

# Check prerequisites
check_prerequisites() {
    if ! command -v fcs &> /dev/null; then
        log_error "FCS CLI not found in PATH"
        exit 1
    fi

    local fcs_version
    fcs_version=$(fcs --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "unknown")
    log_info "FCS CLI version: $fcs_version"
}

# Execute FCS CLI with retry logic
execute_fcs_with_retry() {
    local attempt=1
    local exit_code=0

    while [[ $attempt -le $MAX_RETRIES ]]; do
        log_info "Attempt $attempt of $MAX_RETRIES"

        if fcs "$@" $FCS_SOCKET_ARG; then
            log_success "Command succeeded"
            return 0
        else
            exit_code=$?
            log_warn "Command failed with exit code: $exit_code"

            if [[ $attempt -lt $MAX_RETRIES ]]; then
                log_info "Retrying in ${RETRY_DELAY} seconds..."
                sleep "$RETRY_DELAY"
                attempt=$((attempt + 1))
            else
                log_error "All retry attempts exhausted"
                return $exit_code
            fi
        fi
    done

    return $exit_code
}

# Parse scan results
parse_scan_results() {
    local output_file="$1"

    if [[ ! -f "$output_file" ]]; then
        log_warn "Output file not found: $output_file"
        return
    fi

    if command -v jq &> /dev/null && [[ "$output_file" == *.json ]]; then
        log_info "Parsing scan results..."

        # Extract key metrics (adjust based on actual FCS CLI output format)
        local vulnerabilities
        vulnerabilities=$(jq -r '.vulnerabilities | length' "$output_file" 2>/dev/null || echo "N/A")

        log_info "Total vulnerabilities found: $vulnerabilities"

        # Count by severity
        local critical high medium low
        critical=$(jq -r '[.vulnerabilities[] | select(.severity=="CRITICAL")] | length' "$output_file" 2>/dev/null || echo "0")
        high=$(jq -r '[.vulnerabilities[] | select(.severity=="HIGH")] | length' "$output_file" 2>/dev/null || echo "0")
        medium=$(jq -r '[.vulnerabilities[] | select(.severity=="MEDIUM")] | length' "$output_file" 2>/dev/null || echo "0")
        low=$(jq -r '[.vulnerabilities[] | select(.severity=="LOW")] | length' "$output_file" 2>/dev/null || echo "0")

        log_info "  Critical: $critical"
        log_info "  High: $high"
        log_info "  Medium: $medium"
        log_info "  Low: $low"

        echo "$critical|$high|$medium|$low"
    fi
}

# Main wrapper function
fcs_wrapper() {
    local start_time
    start_time=$(date +%s)

    log_info "Starting FCS CLI operation"
    log_info "Command: fcs $*"
    log_info "Working directory: $(pwd)"
    log_info "User: $(whoami)"
    echo

    # Execute command
    local exit_code=0
    if execute_fcs_with_retry "$@"; then
        local end_time
        end_time=$(date +%s)
        local duration=$((end_time - start_time))

        log_success "Operation completed successfully in ${duration}s"

        # Send success notification
        send_slack_notification "success" "FCS CLI scan completed successfully (${duration}s)"

        exit_code=0
    else
        exit_code=$?
        local end_time
        end_time=$(date +%s)
        local duration=$((end_time - start_time))

        log_error "Operation failed after ${duration}s (exit code: $exit_code)"

        # Send failure notification
        send_slack_notification "error" "FCS CLI scan failed (exit code: $exit_code, ${duration}s)"

        exit_code=1
    fi

    log_info "Log file: $LOG_FILE"
    return $exit_code
}

# Usage information
usage() {
    cat << EOF
Usage: $0 [FCS CLI ARGUMENTS]

Enhanced FCS CLI wrapper with logging, retry, and notifications

FEATURES:
    - Automatic logging to files
    - Retry logic on failures
    - Slack notifications (optional)
    - Result parsing and metrics

ENVIRONMENT VARIABLES:
    LOG_DIR                     Log directory (default: ./logs)
    MAX_RETRIES                 Number of retry attempts (default: 3)
    RETRY_DELAY                 Delay between retries in seconds (default: 5)
    ENABLE_SLACK_NOTIFICATIONS  Enable Slack notifications (default: false)
    SLACK_WEBHOOK_URL           Slack webhook URL for notifications

EXAMPLES:
    # Basic scan
    $0 scan image nginx:latest

    # Scan with output file
    $0 scan image nginx:latest --output json > results.json

    # IaC scan
    $0 scan iac ./terraform/

    # With Slack notifications
    export ENABLE_SLACK_NOTIFICATIONS=true
    export SLACK_WEBHOOK_URL="https://hooks.slack.com/services/YOUR/WEBHOOK/URL"
    $0 scan image myapp:latest

EOF
    exit 0
}

# Main execution
main() {
    if [[ $# -eq 0 ]] || [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
        usage
    fi

    setup_logging
    detect_socket
    check_prerequisites

    fcs_wrapper "$@"
}

main "$@"
