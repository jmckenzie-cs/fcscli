#!/usr/bin/env bash

# Batch Image Scanner
# Scans multiple Docker images from a file or list

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
PARALLEL_SCANS="${PARALLEL_SCANS:-1}"
FAIL_ON_ERROR="${FAIL_ON_ERROR:-false}"
TIMEOUT="${TIMEOUT:-300}"

# Logging
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }

# Usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS] <image-list-file>

Scan multiple Docker images using FCS CLI

OPTIONS:
    -f, --format FORMAT     Output format: json, sarif (default: json)
    -o, --output-dir DIR    Output directory (default: ./scan-results)
    -p, --parallel N        Number of parallel scans (default: 1)
    -t, --timeout SECONDS   Timeout per scan (default: 300)
    --fail-on-error         Exit on first scan failure
    -h, --help              Show this help

INPUT FILE FORMAT:
    One image per line, e.g.:
        nginx:latest
        alpine:3.14
        myregistry.io/myapp:v1.0.0

EXAMPLES:
    # Scan images from file
    $0 images.txt

    # Parallel scanning with custom output
    $0 --parallel 4 --output-dir results images.txt

    # SARIF format for security tools
    $0 --format sarif images.txt

EOF
    exit 1
}

# Check if FCS CLI is installed
check_fcs_cli() {
    if ! command -v fcs &> /dev/null; then
        log_error "FCS CLI not found"
        log_error "Please install FCS CLI first: ./scripts/install-fcs-cli.sh"
        exit 1
    fi
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
FCS CLI Batch Scan Summary
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
    local image_list_file=""

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
            -p|--parallel)
                PARALLEL_SCANS="$2"
                shift 2
                ;;
            -t|--timeout)
                TIMEOUT="$2"
                shift 2
                ;;
            --fail-on-error)
                FAIL_ON_ERROR=true
                shift
                ;;
            -h|--help)
                usage
                ;;
            *)
                if [[ -z "$image_list_file" ]]; then
                    image_list_file="$1"
                    shift
                else
                    log_error "Unknown option: $1"
                    usage
                fi
                ;;
        esac
    done

    # Validate input
    if [[ -z "$image_list_file" ]]; then
        log_error "No image list file provided"
        usage
    fi

    if [[ ! -f "$image_list_file" ]]; then
        log_error "File not found: $image_list_file"
        exit 1
    fi

    check_fcs_cli

    # Create output directory
    mkdir -p "$OUTPUT_DIR"

    log_info "Batch Image Scanning"
    log_info "Input file: $image_list_file"
    log_info "Output directory: $OUTPUT_DIR"
    log_info "Output format: $OUTPUT_FORMAT"
    log_info "Parallel scans: $PARALLEL_SCANS"
    log_info "Timeout per scan: ${TIMEOUT}s"
    echo

    # Read images
    local images=()
    while IFS= read -r line; do
        # Skip empty lines and comments
        [[ -z "$line" ]] && continue
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        images+=("$line")
    done < "$image_list_file"

    local total_images=${#images[@]}
    log_info "Found $total_images images to scan"
    echo

    # Results tracking
    local results_file="${OUTPUT_DIR}/results.tmp"
    > "$results_file"

    # Scan images
    local current=0
    for image in "${images[@]}"; do
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
            if [[ "$FAIL_ON_ERROR" == "true" ]]; then
                log_error "Scan failed and --fail-on-error is set. Aborting."
                exit 1
            fi
        fi

        echo
    done

    # Generate summary
    echo
    generate_summary "$results_file"

    # Check if any scans failed (before removing results file)
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
