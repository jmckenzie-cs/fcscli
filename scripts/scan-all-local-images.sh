#!/usr/bin/env bash

# Scan All Local Docker Images
# Automatically scans all images in the local Docker registry

set -euo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
OUTPUT_FORMAT="${OUTPUT_FORMAT:-json}"
OUTPUT_DIR="${OUTPUT_DIR:-./scan-results}"
SKIP_TAGS="${SKIP_TAGS:-none|<none>}"
TIMEOUT="${TIMEOUT:-300}"

# Logging
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }

# Usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Scan all Docker images in the local registry using FCS CLI

OPTIONS:
    -f, --format FORMAT     Output format: json, sarif (default: json)
    -o, --output-dir DIR    Output directory (default: ./scan-results)
    -t, --timeout SECONDS   Timeout per scan (default: 300)
    -s, --skip-pattern      Skip images matching pattern (default: none|<none>)
    -h, --help              Show this help

EXAMPLES:
    # Scan all local images
    $0

    # Custom output directory
    $0 --output-dir results

    # Skip untagged images
    $0 --skip-pattern '<none>'

EOF
    exit 1
}

# Check if Docker is running
check_docker() {
    if ! command -v docker &> /dev/null; then
        log_error "Docker not found"
        exit 1
    fi

    if ! docker ps &> /dev/null; then
        log_error "Docker daemon not running or no permission"
        exit 1
    fi
}

# Check if FCS CLI is installed
check_fcs_cli() {
    if ! command -v fcs &> /dev/null; then
        log_error "FCS CLI not found"
        log_error "Please install FCS CLI first: ./scripts/install-fcs-cli.sh"
        exit 1
    fi
}

# Get all local images
get_local_images() {
    log_info "Fetching local Docker images..."

    # Get all images, format as REPOSITORY:TAG
    local images
    images=$(docker images --format "{{.Repository}}:{{.Tag}}" | grep -v "$SKIP_TAGS")

    echo "$images"
}

# Scan single image
scan_image() {
    local image="$1"
    local output_file="$2"

    log_info "Scanning: $image"

    local scan_start
    scan_start=$(date +%s)

    if fcs --timeout "$TIMEOUT" scan image "$image" --output "$OUTPUT_FORMAT" > "$output_file" 2>&1; then
        local scan_end
        scan_end=$(date +%s)
        local duration=$((scan_end - scan_start))

        log_success "Completed: $image (${duration}s)"
        echo "success|$image|$output_file|$duration"
        return 0
    else
        local exit_code=$?
        log_error "Failed: $image (exit code: $exit_code)"
        echo "failed|$image|$output_file|$exit_code"
        return $exit_code
    fi
}

# Generate summary report
generate_summary() {
    local results_file="$1"
    local summary_file="${OUTPUT_DIR}/summary.txt"

    log_info "Generating summary report..."

    local total=0
    local success=0
    local failed=0
    local total_duration=0

    while IFS='|' read -r status image output duration; do
        total=$((total + 1))
        if [[ "$status" == "success" ]]; then
            success=$((success + 1))
            total_duration=$((total_duration + duration))
        else
            failed=$((failed + 1))
        fi
    done < "$results_file"

    cat > "$summary_file" << EOF
========================================
FCS CLI - All Local Images Scan Summary
========================================
Scan Date: $(date)
Total Images: $total
Successful: $success
Failed: $failed
Success Rate: $(awk "BEGIN {printf \"%.2f%%\", ($success/$total)*100}")
Total Duration: ${total_duration}s
Average Duration: $(if [[ $success -gt 0 ]]; then awk "BEGIN {printf \"%.2f\", $total_duration/$success}"; else echo "N/A"; fi)s
========================================

Detailed Results:
EOF

    while IFS='|' read -r status image output duration; do
        if [[ "$status" == "success" ]]; then
            echo "✓ $image - ${duration}s - $output" >> "$summary_file"
        else
            echo "✗ $image - Exit code: $duration - $output" >> "$summary_file"
        fi
    done < "$results_file"

    cat "$summary_file"
    log_success "Summary saved to: $summary_file"
}

# Main execution
main() {
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -f|--format)
                OUTPUT_FORMAT="$2"
                shift 2
                ;;
            -o|--output-dir)
                OUTPUT_DIR="$2"
                shift 2
                ;;
            -t|--timeout)
                TIMEOUT="$2"
                shift 2
                ;;
            -s|--skip-pattern)
                SKIP_TAGS="$2"
                shift 2
                ;;
            -h|--help)
                usage
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                ;;
        esac
    done

    check_docker
    check_fcs_cli

    # Create output directory
    mkdir -p "$OUTPUT_DIR"

    log_info "Scanning All Local Docker Images"
    log_info "Output directory: $OUTPUT_DIR"
    log_info "Output format: $OUTPUT_FORMAT"
    log_info "Timeout per scan: ${TIMEOUT}s"
    echo

    # Get all local images
    local images
    images=$(get_local_images)

    if [[ -z "$images" ]]; then
        log_warn "No Docker images found locally"
        exit 0
    fi

    local total_images
    total_images=$(echo "$images" | wc -l | tr -d ' ')
    log_info "Found $total_images images to scan"
    echo

    # Results tracking
    local results_file="${OUTPUT_DIR}/results.tmp"
    > "$results_file"

    # Scan images
    local current=0
    while IFS= read -r image; do
        current=$((current + 1))

        # Create safe filename
        local safe_name
        safe_name=$(echo "$image" | tr '/:' '_')
        local output_file="${OUTPUT_DIR}/${safe_name}.${OUTPUT_FORMAT}"

        echo "[$current/$total_images]"

        # Scan image
        if scan_result=$(scan_image "$image" "$output_file"); then
            echo "$scan_result" >> "$results_file"
        else
            echo "$scan_result" >> "$results_file"
        fi

        echo
    done <<< "$images"

    # Generate summary
    echo
    generate_summary "$results_file"

    # Check if any scans failed
    local failed_count
    failed_count=$(grep -c "^failed|" "$results_file" 2>/dev/null || echo 0)

    # Cleanup temp file
    rm -f "$results_file"

    if [[ $failed_count -gt 0 ]]; then
        log_warn "$failed_count scan(s) failed"
        exit 1
    else
        log_success "All scans completed successfully!"
        exit 0
    fi
}

main "$@"
