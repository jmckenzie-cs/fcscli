#!/usr/bin/env bash

# Policy Enforcement Script
# Enforces security policies based on FCS scan results

set -euo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
SEVERITY_THRESHOLD="${SEVERITY_THRESHOLD:-high}"
MAX_CRITICAL="${MAX_CRITICAL:-0}"
MAX_HIGH="${MAX_HIGH:-5}"
MAX_MEDIUM="${MAX_MEDIUM:-20}"
FAIL_ON_THRESHOLD="${FAIL_ON_THRESHOLD:-true}"
OUTPUT_FORMAT="${OUTPUT_FORMAT:-json}"

# Logging
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }

# Usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS] scan <type> <target>

Enforce security policies on FCS CLI scan results

SCAN TYPES:
    image <image-name>      Scan a Docker image
    iac <path>              Scan Infrastructure as Code

OPTIONS:
    --severity LEVEL        Minimum severity to fail on: critical, high, medium, low
                            (default: high)
    --max-critical N        Maximum critical issues allowed (default: 0)
    --max-high N            Maximum high severity issues allowed (default: 5)
    --max-medium N          Maximum medium severity issues allowed (default: 20)
    --no-fail               Don't fail build, only warn
    -h, --help              Show this help

EXAMPLES:
    # Fail on any critical vulnerabilities
    $0 scan image nginx:latest --severity critical

    # Allow up to 3 high severity issues
    $0 scan image myapp:latest --max-high 3

    # Scan IaC with strict policy
    $0 scan iac ./terraform/ --max-critical 0 --max-high 0

    # Warn only, don't fail
    $0 scan image myapp:latest --no-fail

ENVIRONMENT VARIABLES:
    SEVERITY_THRESHOLD      Minimum severity level (default: high)
    MAX_CRITICAL            Max critical issues (default: 0)
    MAX_HIGH                Max high issues (default: 5)
    MAX_MEDIUM              Max medium issues (default: 20)
    FAIL_ON_THRESHOLD       Fail on policy violation (default: true)

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

# Check if jq is installed
check_jq() {
    if ! command -v jq &> /dev/null; then
        log_error "jq not found (required for JSON parsing)"
        log_error "Install: brew install jq  (macOS) or  apt-get install jq  (Linux)"
        exit 1
    fi
}

# Run FCS scan
run_scan() {
    local scan_type="$1"
    local target="$2"
    local output_file
    output_file=$(mktemp)

    log_info "Running FCS scan: $scan_type on $target"

    if fcs scan "$scan_type" "$target" --output json > "$output_file" 2>&1; then
        log_success "Scan completed successfully"
    else
        local exit_code=$?
        log_error "Scan failed with exit code: $exit_code"
        cat "$output_file" >&2
        rm -f "$output_file"
        exit $exit_code
    fi

    echo "$output_file"
}

# Parse scan results
parse_results() {
    local results_file="$1"
    local scan_type="$2"

    log_info "Parsing scan results..."

    # Different JSON structure for image vs IaC scans
    if [[ "$scan_type" == "image" ]]; then
        local critical high medium low total

        # Check if vulnerabilities field exists
        if jq -e '.vulnerabilities' "$results_file" &>/dev/null; then
            total=$(jq '.vulnerabilities | length' "$results_file")
            critical=$(jq '[.vulnerabilities[] | select(.severity=="CRITICAL" or .severity=="Critical")] | length' "$results_file")
            high=$(jq '[.vulnerabilities[] | select(.severity=="HIGH" or .severity=="High")] | length' "$results_file")
            medium=$(jq '[.vulnerabilities[] | select(.severity=="MEDIUM" or .severity=="Medium")] | length' "$results_file")
            low=$(jq '[.vulnerabilities[] | select(.severity=="LOW" or .severity=="Low")] | length' "$results_file")
        else
            # Alternative structure
            total=0
            critical=0
            high=0
            medium=0
            low=0
        fi

        echo "$total|$critical|$high|$medium|$low"

    elif [[ "$scan_type" == "iac" ]]; then
        local critical high medium low total

        # Check if issues field exists
        if jq -e '.issues' "$results_file" &>/dev/null; then
            total=$(jq '.issues | length' "$results_file")
            critical=$(jq '[.issues[] | select(.severity=="CRITICAL" or .severity=="Critical")] | length' "$results_file")
            high=$(jq '[.issues[] | select(.severity=="HIGH" or .severity=="High")] | length' "$results_file")
            medium=$(jq '[.issues[] | select(.severity=="MEDIUM" or .severity=="Medium")] | length' "$results_file")
            low=$(jq '[.issues[] | select(.severity=="LOW" or .severity=="Low")] | length' "$results_file")
        else
            total=0
            critical=0
            high=0
            medium=0
            low=0
        fi

        echo "$total|$critical|$high|$medium|$low"
    fi
}

# Enforce policy
enforce_policy() {
    local total="$1"
    local critical="$2"
    local high="$3"
    local medium="$4"
    local low="$5"
    local target="$6"

    log_info "Policy Enforcement Results for: $target"
    echo
    echo "Total Issues: $total"
    echo "  Critical: $critical (max allowed: $MAX_CRITICAL)"
    echo "  High:     $high (max allowed: $MAX_HIGH)"
    echo "  Medium:   $medium (max allowed: $MAX_MEDIUM)"
    echo "  Low:      $low"
    echo

    local violations=()

    # Check thresholds
    if [[ $critical -gt $MAX_CRITICAL ]]; then
        violations+=("CRITICAL: $critical found (max: $MAX_CRITICAL)")
    fi

    if [[ $high -gt $MAX_HIGH ]]; then
        violations+=("HIGH: $high found (max: $MAX_HIGH)")
    fi

    if [[ $medium -gt $MAX_MEDIUM ]]; then
        violations+=("MEDIUM: $medium found (max: $MAX_MEDIUM)")
    fi

    # Report violations
    if [[ ${#violations[@]} -gt 0 ]]; then
        log_error "Policy violations detected:"
        for violation in "${violations[@]}"; do
            echo "  ✗ $violation" >&2
        done
        echo

        if [[ "$FAIL_ON_THRESHOLD" == "true" ]]; then
            log_error "Policy enforcement FAILED"
            return 1
        else
            log_warn "Policy violations found, but --no-fail is set"
            return 0
        fi
    else
        log_success "Policy enforcement PASSED"
        log_success "All thresholds met ✓"
        return 0
    fi
}

# Main execution
main() {
    local scan_type=""
    local target=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --severity)
                SEVERITY_THRESHOLD="$2"
                shift 2
                ;;
            --max-critical)
                MAX_CRITICAL="$2"
                shift 2
                ;;
            --max-high)
                MAX_HIGH="$2"
                shift 2
                ;;
            --max-medium)
                MAX_MEDIUM="$2"
                shift 2
                ;;
            --no-fail)
                FAIL_ON_THRESHOLD=false
                shift
                ;;
            -h|--help)
                usage
                ;;
            scan)
                shift
                if [[ $# -lt 2 ]]; then
                    log_error "scan requires <type> <target>"
                    usage
                fi
                scan_type="$1"
                target="$2"
                shift 2
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                ;;
        esac
    done

    if [[ -z "$scan_type" ]] || [[ -z "$target" ]]; then
        log_error "Missing scan type or target"
        usage
    fi

    check_fcs_cli
    check_jq

    log_info "Policy Enforcement Mode"
    log_info "Target: $target"
    log_info "Severity threshold: $SEVERITY_THRESHOLD"
    log_info "Max critical: $MAX_CRITICAL"
    log_info "Max high: $MAX_HIGH"
    log_info "Max medium: $MAX_MEDIUM"
    log_info "Fail on threshold: $FAIL_ON_THRESHOLD"
    echo

    # Run scan
    local results_file
    results_file=$(run_scan "$scan_type" "$target")

    # Parse results
    local results
    results=$(parse_results "$results_file" "$scan_type")

    IFS='|' read -r total critical high medium low <<< "$results"

    # Cleanup
    rm -f "$results_file"

    # Enforce policy
    if enforce_policy "$total" "$critical" "$high" "$medium" "$low" "$target"; then
        exit 0
    else
        exit 1
    fi
}

main "$@"
