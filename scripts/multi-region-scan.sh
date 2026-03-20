#!/usr/bin/env bash

# Multi-Region Scan Script
# Scans images across multiple CrowdStrike regions for comparison

set -euo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }

# Region configurations
declare -A REGION_URLS=(
    ["us-1"]="https://api.crowdstrike.com"
    ["us-2"]="https://api.us-2.crowdstrike.com"
    ["eu-1"]="https://api.eu-1.crowdstrike.com"
    ["us-gov-1"]="https://api.laggar.gcw.crowdstrike.com"
    ["us-gov-2"]="https://api.us-gov-2.crowdstrike.com"
)

# Configuration
REGIONS="${REGIONS:-us-1,us-2}"
TARGET=""
OUTPUT_DIR="${OUTPUT_DIR:-./multi-region-results}"
COMPARE_RESULTS="${COMPARE_RESULTS:-true}"

# Usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS] <image-name>

Scan a Docker image across multiple CrowdStrike regions

OPTIONS:
    -r, --regions REGIONS   Comma-separated regions (default: us-1,us-2)
                            Available: us-1, us-2, eu-1, us-gov-1, us-gov-2
    -o, --output-dir DIR    Output directory (default: ./multi-region-results)
    --no-compare            Skip comparison report
    -h, --help              Show this help

REQUIRED ENVIRONMENT VARIABLES:
    FALCON_CLIENT_ID        Your Falcon Client ID
    FALCON_CLIENT_SECRET    Your Falcon Client Secret

OPTIONAL ENVIRONMENT VARIABLES:
    You can set region-specific credentials:
    FALCON_CLIENT_ID_US1, FALCON_CLIENT_SECRET_US1
    FALCON_CLIENT_ID_US2, FALCON_CLIENT_SECRET_US2
    FALCON_CLIENT_ID_EU1, FALCON_CLIENT_SECRET_EU1
    etc.

EXAMPLES:
    # Scan across US regions
    $0 nginx:latest

    # Scan across specific regions
    $0 --regions us-1,eu-1 myapp:latest

    # Custom output directory
    $0 --output-dir results nginx:latest

EOF
    exit 1
}

# Check prerequisites
check_prerequisites() {
    if ! command -v fcs &> /dev/null; then
        log_error "FCS CLI not found"
        log_error "Please install FCS CLI first: ./scripts/install-fcs-cli.sh"
        exit 1
    fi

    if ! command -v jq &> /dev/null; then
        log_error "jq not found (required for JSON parsing)"
        log_error "Install: brew install jq  (macOS) or  apt-get install jq  (Linux)"
        exit 1
    fi

    if [[ -z "${FALCON_CLIENT_ID:-}" ]] || [[ -z "${FALCON_CLIENT_SECRET:-}" ]]; then
        log_error "FALCON_CLIENT_ID and FALCON_CLIENT_SECRET must be set"
        log_error "Or set region-specific credentials (e.g., FALCON_CLIENT_ID_US1)"
        exit 1
    fi
}

# Get credentials for region
get_region_credentials() {
    local region="$1"
    local region_upper
    region_upper=$(echo "$region" | tr '[:lower:]-' '[:upper:]_')

    # Try region-specific credentials first
    local client_id_var="FALCON_CLIENT_ID_${region_upper}"
    local client_secret_var="FALCON_CLIENT_SECRET_${region_upper}"

    local client_id="${!client_id_var:-${FALCON_CLIENT_ID}}"
    local client_secret="${!client_secret_var:-${FALCON_CLIENT_SECRET}}"

    echo "${client_id}|${client_secret}"
}

# Configure FCS for region
configure_region() {
    local region="$1"
    local credentials
    credentials=$(get_region_credentials "$region")

    IFS='|' read -r client_id client_secret <<< "$credentials"

    log_info "Configuring FCS CLI for region: $region"

    fcs configure \
        --client-id "$client_id" \
        --client-secret "$client_secret" \
        --falcon-cloud "$region" \
        --profile "$region" &> /dev/null

    if [[ $? -eq 0 ]]; then
        log_success "Region $region configured"
        return 0
    else
        log_error "Failed to configure region: $region"
        return 1
    fi
}

# Scan with specific region
scan_with_region() {
    local region="$1"
    local target="$2"
    local output_file="$3"

    log_info "Scanning with region: $region"
    log_info "Target: $target"

    local scan_start
    scan_start=$(date +%s)

    if fcs --profile "$region" scan image "$target" --output json > "$output_file" 2>&1; then
        local scan_end
        scan_end=$(date +%s)
        local duration=$((scan_end - scan_start))

        # Parse results
        local total critical high medium low

        if jq -e '.vulnerabilities' "$output_file" &>/dev/null; then
            total=$(jq '.vulnerabilities | length' "$output_file")
            critical=$(jq '[.vulnerabilities[] | select(.severity=="CRITICAL" or .severity=="Critical")] | length' "$output_file")
            high=$(jq '[.vulnerabilities[] | select(.severity=="HIGH" or .severity=="High")] | length' "$output_file")
            medium=$(jq '[.vulnerabilities[] | select(.severity=="MEDIUM" or .severity=="Medium")] | length' "$output_file")
            low=$(jq '[.vulnerabilities[] | select(.severity=="LOW" or .severity=="Low")] | length' "$output_file")
        else
            total=0
            critical=0
            high=0
            medium=0
            low=0
        fi

        log_success "Region $region completed (${duration}s)"
        log_info "  Total: $total | Critical: $critical | High: $high | Medium: $medium | Low: $low"

        echo "success|$region|$total|$critical|$high|$medium|$low|$duration"
        return 0
    else
        local exit_code=$?
        log_error "Region $region failed (exit code: $exit_code)"
        echo "failed|$region|0|0|0|0|0|0"
        return $exit_code
    fi
}

# Generate comparison report
generate_comparison() {
    local results_file="$1"
    local report_file="${OUTPUT_DIR}/comparison-report.txt"

    log_info "Generating comparison report..."

    cat > "$report_file" << EOF
========================================
Multi-Region Scan Comparison Report
========================================
Scan Date: $(date)
Target: $TARGET

Region-by-Region Results:
EOF

    while IFS='|' read -r status region total critical high medium low duration; do
        if [[ "$status" == "success" ]]; then
            cat >> "$report_file" << EOF

Region: $region
  Status: ✓ Success
  Duration: ${duration}s
  Total Vulnerabilities: $total
    - Critical: $critical
    - High: $high
    - Medium: $medium
    - Low: $low
EOF
        else
            cat >> "$report_file" << EOF

Region: $region
  Status: ✗ Failed
EOF
        fi
    done < "$results_file"

    # Add summary statistics
    local successful_regions
    successful_regions=$(grep -c "^success|" "$results_file" 2>/dev/null || echo 0)

    if [[ $successful_regions -gt 0 ]]; then
        cat >> "$report_file" << EOF

========================================
Summary Statistics:
========================================
Successful Regions: $successful_regions

EOF

        # Calculate averages
        local total_sum=0 crit_sum=0 high_sum=0 med_sum=0 low_sum=0

        while IFS='|' read -r status region total critical high medium low duration; do
            if [[ "$status" == "success" ]]; then
                total_sum=$((total_sum + total))
                crit_sum=$((crit_sum + critical))
                high_sum=$((high_sum + high))
                med_sum=$((med_sum + medium))
                low_sum=$((low_sum + low))
            fi
        done < "$results_file"

        cat >> "$report_file" << EOF
Average Vulnerabilities per Region:
  Total: $(awk "BEGIN {printf \"%.1f\", $total_sum/$successful_regions}")
  Critical: $(awk "BEGIN {printf \"%.1f\", $crit_sum/$successful_regions}")
  High: $(awk "BEGIN {printf \"%.1f\", $high_sum/$successful_regions}")
  Medium: $(awk "BEGIN {printf \"%.1f\", $med_sum/$successful_regions}")
  Low: $(awk "BEGIN {printf \"%.1f\", $low_sum/$successful_regions}")

Note: Results should be identical across regions.
Differences may indicate region-specific issues or timing.
========================================
EOF
    fi

    cat "$report_file"
    log_success "Comparison report saved to: $report_file"
}

# Main execution
main() {
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -r|--regions)
                REGIONS="$2"
                shift 2
                ;;
            -o|--output-dir)
                OUTPUT_DIR="$2"
                shift 2
                ;;
            --no-compare)
                COMPARE_RESULTS=false
                shift
                ;;
            -h|--help)
                usage
                ;;
            *)
                if [[ -z "$TARGET" ]]; then
                    TARGET="$1"
                    shift
                else
                    log_error "Unknown option: $1"
                    usage
                fi
                ;;
        esac
    done

    if [[ -z "$TARGET" ]]; then
        log_error "No target image specified"
        usage
    fi

    check_prerequisites

    # Create output directory
    mkdir -p "$OUTPUT_DIR"

    log_info "Multi-Region Scan"
    log_info "Target: $TARGET"
    log_info "Regions: $REGIONS"
    log_info "Output directory: $OUTPUT_DIR"
    echo

    # Parse regions
    IFS=',' read -ra REGION_LIST <<< "$REGIONS"

    # Results tracking
    local results_file="${OUTPUT_DIR}/results.tmp"
    > "$results_file"

    # Scan each region
    for region in "${REGION_LIST[@]}"; do
        region=$(echo "$region" | xargs)  # Trim whitespace

        if [[ -z "${REGION_URLS[$region]:-}" ]]; then
            log_warn "Unknown region: $region (skipping)"
            continue
        fi

        echo "Region: $region"
        echo "----------------------------------------"

        # Configure region
        if ! configure_region "$region"; then
            echo "failed|$region|0|0|0|0|0|0" >> "$results_file"
            echo
            continue
        fi

        # Scan
        local output_file="${OUTPUT_DIR}/${region}.json"
        if scan_result=$(scan_with_region "$region" "$TARGET" "$output_file"); then
            echo "$scan_result" >> "$results_file"
        else
            echo "$scan_result" >> "$results_file"
        fi

        echo
    done

    # Generate comparison
    if [[ "$COMPARE_RESULTS" == "true" ]]; then
        echo
        generate_comparison "$results_file"
    fi

    # Cleanup
    rm -f "$results_file"

    log_success "Multi-region scan complete!"
    log_info "Results saved in: $OUTPUT_DIR"
}

main "$@"
