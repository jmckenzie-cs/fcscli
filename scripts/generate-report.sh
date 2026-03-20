#!/usr/bin/env bash

# Generate HTML Report from FCS Scan Results
# Converts JSON scan results to formatted HTML report

set -euo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
REPORT_TITLE="${REPORT_TITLE:-FCS Security Scan Report}"
INCLUDE_DETAILS="${INCLUDE_DETAILS:-true}"

# Logging
log_info() { echo -e "${BLUE}[INFO]${NC} $1" >&2; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1" >&2; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1" >&2; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }

# Usage
usage() {
    cat << EOF >&2
Usage: $0 <scan-results.json> [OPTIONS]

Generate an HTML report from FCS CLI scan results

OPTIONS:
    --title TITLE           Report title (default: FCS Security Scan Report)
    --no-details            Exclude vulnerability details
    -h, --help              Show this help

EXAMPLES:
    # Generate HTML report
    $0 scan-results.json > report.html

    # Custom title
    $0 scan-results.json --title "Production Image Scan" > report.html

    # Summary only (no details)
    $0 scan-results.json --no-details > summary.html

EOF
    exit 1
}

# Check if jq is installed
check_jq() {
    if ! command -v jq &> /dev/null; then
        log_error "jq not found (required for JSON parsing)"
        log_error "Install: brew install jq  (macOS) or  apt-get install jq  (Linux)"
        exit 1
    fi
}

# Detect scan type and parse results
parse_scan_results() {
    local json_file="$1"

    # Detect if it's an image or IaC scan
    if jq -e '.vulnerabilities' "$json_file" &>/dev/null; then
        echo "image"
    elif jq -e '.issues' "$json_file" &>/dev/null; then
        echo "iac"
    else
        log_error "Unable to detect scan type (expected .vulnerabilities or .issues)"
        exit 1
    fi
}

# Get severity counts
get_severity_counts() {
    local json_file="$1"
    local scan_type="$2"
    local field

    if [[ "$scan_type" == "image" ]]; then
        field="vulnerabilities"
    else
        field="issues"
    fi

    local total critical high medium low

    total=$(jq ".$field | length" "$json_file")
    critical=$(jq "[.$field[] | select(.severity==\"CRITICAL\" or .severity==\"Critical\")] | length" "$json_file")
    high=$(jq "[.$field[] | select(.severity==\"HIGH\" or .severity==\"High\")] | length" "$json_file")
    medium=$(jq "[.$field[] | select(.severity==\"MEDIUM\" or .severity==\"Medium\")] | length" "$json_file")
    low=$(jq "[.$field[] | select(.severity==\"LOW\" or .severity==\"Low\")] | length" "$json_file")

    echo "$total|$critical|$high|$medium|$low"
}

# Get target info
get_target_info() {
    local json_file="$1"
    local scan_type="$2"

    if [[ "$scan_type" == "image" ]]; then
        jq -r '.image // "Unknown Image"' "$json_file"
    else
        jq -r '.path // "Unknown Path"' "$json_file"
    fi
}

# Generate HTML header
generate_html_header() {
    cat << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>FCS Security Scan Report</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
            line-height: 1.6;
            color: #333;
            background: #f5f5f5;
            padding: 20px;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
            background: white;
            padding: 30px;
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        h1 {
            color: #2c3e50;
            margin-bottom: 10px;
            font-size: 2em;
        }
        .header {
            border-bottom: 3px solid #e74c3c;
            padding-bottom: 20px;
            margin-bottom: 30px;
        }
        .metadata {
            color: #7f8c8d;
            font-size: 0.9em;
            margin-top: 10px;
        }
        .summary {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 20px;
            margin-bottom: 30px;
        }
        .card {
            background: #f8f9fa;
            padding: 20px;
            border-radius: 6px;
            border-left: 4px solid #3498db;
        }
        .card.critical { border-left-color: #e74c3c; background: #fee; }
        .card.high { border-left-color: #e67e22; background: #ffeee5; }
        .card.medium { border-left-color: #f39c12; background: #fff9e6; }
        .card.low { border-left-color: #95a5a6; background: #f8f9fa; }
        .card h3 {
            font-size: 0.9em;
            color: #7f8c8d;
            text-transform: uppercase;
            margin-bottom: 10px;
        }
        .card .count {
            font-size: 2.5em;
            font-weight: bold;
            color: #2c3e50;
        }
        .details {
            margin-top: 30px;
        }
        .details h2 {
            color: #2c3e50;
            margin-bottom: 20px;
            padding-bottom: 10px;
            border-bottom: 2px solid #ecf0f1;
        }
        .vulnerability {
            background: #f8f9fa;
            padding: 15px;
            margin-bottom: 15px;
            border-radius: 6px;
            border-left: 4px solid #3498db;
        }
        .vulnerability.critical { border-left-color: #e74c3c; }
        .vulnerability.high { border-left-color: #e67e22; }
        .vulnerability.medium { border-left-color: #f39c12; }
        .vulnerability.low { border-left-color: #95a5a6; }
        .vulnerability h4 {
            color: #2c3e50;
            margin-bottom: 8px;
            font-size: 1.1em;
        }
        .vulnerability .meta {
            display: flex;
            gap: 15px;
            font-size: 0.85em;
            color: #7f8c8d;
            margin-bottom: 10px;
        }
        .badge {
            display: inline-block;
            padding: 3px 8px;
            border-radius: 3px;
            font-size: 0.75em;
            font-weight: bold;
            text-transform: uppercase;
        }
        .badge.critical { background: #e74c3c; color: white; }
        .badge.high { background: #e67e22; color: white; }
        .badge.medium { background: #f39c12; color: white; }
        .badge.low { background: #95a5a6; color: white; }
        .description {
            color: #555;
            margin-top: 10px;
            line-height: 1.5;
        }
        .footer {
            margin-top: 40px;
            padding-top: 20px;
            border-top: 1px solid #ecf0f1;
            text-align: center;
            color: #95a5a6;
            font-size: 0.85em;
        }
        @media print {
            body { background: white; }
            .container { box-shadow: none; }
        }
    </style>
</head>
<body>
    <div class="container">
EOF
}

# Generate HTML footer
generate_html_footer() {
    cat << 'EOF'
        <div class="footer">
            <p>Generated by CrowdStrike FCS CLI | Report Date: <span id="date"></span></p>
            <script>document.getElementById('date').textContent = new Date().toLocaleString();</script>
        </div>
    </div>
</body>
</html>
EOF
}

# Generate summary section
generate_summary() {
    local target="$1"
    local scan_type="$2"
    local total="$3"
    local critical="$4"
    local high="$5"
    local medium="$6"
    local low="$7"

    cat << EOF
        <div class="header">
            <h1>$REPORT_TITLE</h1>
            <div class="metadata">
                <strong>Target:</strong> $target<br>
                <strong>Scan Type:</strong> $(echo "$scan_type" | tr '[:lower:]' '[:upper:]')<br>
                <strong>Generated:</strong> $(date)
            </div>
        </div>

        <div class="summary">
            <div class="card">
                <h3>Total Issues</h3>
                <div class="count">$total</div>
            </div>
            <div class="card critical">
                <h3>Critical</h3>
                <div class="count">$critical</div>
            </div>
            <div class="card high">
                <h3>High</h3>
                <div class="count">$high</div>
            </div>
            <div class="card medium">
                <h3>Medium</h3>
                <div class="count">$medium</div>
            </div>
            <div class="card low">
                <h3>Low</h3>
                <div class="count">$low</div>
            </div>
        </div>
EOF
}

# Generate details section for image scans
generate_image_details() {
    local json_file="$1"

    cat << 'EOF'
        <div class="details">
            <h2>Vulnerability Details</h2>
EOF

    # Extract vulnerabilities with jq and format as HTML
    jq -r '.vulnerabilities[] |
        "<div class=\"vulnerability " + (.severity | ascii_downcase) + "\">" +
        "<h4>" + (.cve // .name // "Unknown") + "</h4>" +
        "<div class=\"meta\">" +
        "<span class=\"badge " + (.severity | ascii_downcase) + "\">" + .severity + "</span>" +
        "<span><strong>Package:</strong> " + (.package // "N/A") + "</span>" +
        "<span><strong>Version:</strong> " + (.version // "N/A") + "</span>" +
        "</div>" +
        "<div class=\"description\">" + (.description // "No description available") + "</div>" +
        "</div>"
    ' "$json_file"

    echo "        </div>"
}

# Generate details section for IaC scans
generate_iac_details() {
    local json_file="$1"

    cat << 'EOF'
        <div class="details">
            <h2>Issue Details</h2>
EOF

    # Extract issues with jq and format as HTML
    jq -r '.issues[] |
        "<div class=\"vulnerability " + (.severity | ascii_downcase) + "\">" +
        "<h4>" + (.title // .id // "Unknown Issue") + "</h4>" +
        "<div class=\"meta\">" +
        "<span class=\"badge " + (.severity | ascii_downcase) + "\">" + .severity + "</span>" +
        "<span><strong>File:</strong> " + (.file // "N/A") + "</span>" +
        "<span><strong>Line:</strong> " + (.line // "N/A" | tostring) + "</span>" +
        "</div>" +
        "<div class=\"description\">" + (.description // "No description available") + "</div>" +
        "</div>"
    ' "$json_file"

    echo "        </div>"
}

# Main execution
main() {
    local json_file=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --title)
                REPORT_TITLE="$2"
                shift 2
                ;;
            --no-details)
                INCLUDE_DETAILS=false
                shift
                ;;
            -h|--help)
                usage
                ;;
            *)
                if [[ -z "$json_file" ]]; then
                    json_file="$1"
                    shift
                else
                    log_error "Unknown option: $1"
                    usage
                fi
                ;;
        esac
    done

    if [[ -z "$json_file" ]]; then
        log_error "No JSON file specified"
        usage
    fi

    if [[ ! -f "$json_file" ]]; then
        log_error "File not found: $json_file"
        exit 1
    fi

    check_jq

    log_info "Generating HTML report from: $json_file"

    # Parse scan results
    local scan_type
    scan_type=$(parse_scan_results "$json_file")

    log_info "Detected scan type: $scan_type"

    # Get counts
    local counts
    counts=$(get_severity_counts "$json_file" "$scan_type")
    IFS='|' read -r total critical high medium low <<< "$counts"

    # Get target
    local target
    target=$(get_target_info "$json_file" "$scan_type")

    # Generate HTML
    generate_html_header
    generate_summary "$target" "$scan_type" "$total" "$critical" "$high" "$medium" "$low"

    if [[ "$INCLUDE_DETAILS" == "true" ]]; then
        if [[ "$scan_type" == "image" ]]; then
            generate_image_details "$json_file"
        else
            generate_iac_details "$json_file"
        fi
    fi

    generate_html_footer

    log_success "HTML report generated successfully" >&2
}

main "$@"
