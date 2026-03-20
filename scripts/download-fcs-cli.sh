#!/usr/bin/env bash

# Programmatic FCS CLI Download Script
# Downloads FCS CLI using the CrowdStrike API

set -euo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
FALCON_CLIENT_ID="${FALCON_CLIENT_ID:-}"
FALCON_CLIENT_SECRET="${FALCON_CLIENT_SECRET:-}"
FALCON_API_URL="${FALCON_API_URL:-https://api.crowdstrike.com}"
FCS_TARGET_OS="${FCS_TARGET_OS:-}"
FCS_TARGET_ARCH="${FCS_TARGET_ARCH:-}"
OUTPUT_DIR="${OUTPUT_DIR:-.}"

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."

    local missing_tools=()

    command -v curl &> /dev/null || missing_tools+=("curl")
    command -v jq &> /dev/null || missing_tools+=("jq")

    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        log_error "Please install: ${missing_tools[*]}"
        exit 1
    fi

    if [[ -z "$FALCON_CLIENT_ID" ]] || [[ -z "$FALCON_CLIENT_SECRET" ]]; then
        log_error "FALCON_CLIENT_ID and FALCON_CLIENT_SECRET must be set"
        log_error "Example:"
        log_error "  export FALCON_CLIENT_ID='your-client-id'"
        log_error "  export FALCON_CLIENT_SECRET='your-client-secret'"
        exit 1
    fi

    log_success "Prerequisites check passed"
}

# Detect platform
detect_platform() {
    if [[ -z "$FCS_TARGET_OS" ]]; then
        case "$(uname -s)" in
            Linux*)  FCS_TARGET_OS="linux";;
            Darwin*) FCS_TARGET_OS="darwin";;
            *)
                log_error "Unsupported OS: $(uname -s)"
                exit 1
                ;;
        esac
    fi

    if [[ -z "$FCS_TARGET_ARCH" ]]; then
        case "$(uname -m)" in
            x86_64|amd64) FCS_TARGET_ARCH="amd64";;
            arm64|aarch64) FCS_TARGET_ARCH="arm64";;
            *)
                log_error "Unsupported architecture: $(uname -m)"
                exit 1
                ;;
        esac
    fi

    log_info "Target platform: ${FCS_TARGET_OS}/${FCS_TARGET_ARCH}"
}

# Get OAuth2 access token
get_access_token() {
    log_info "Authenticating with CrowdStrike API..."

    local response
    response=$(curl --silent --request POST \
        --header "Content-Type: application/x-www-form-urlencoded" \
        --data-urlencode "client_id=${FALCON_CLIENT_ID}" \
        --data-urlencode "client_secret=${FALCON_CLIENT_SECRET}" \
        --url "${FALCON_API_URL}/oauth2/token")

    local access_token
    access_token=$(echo "$response" | jq -r '.access_token')

    if [[ "$access_token" == "null" ]] || [[ -z "$access_token" ]]; then
        log_error "Failed to obtain access token"
        log_error "Response: $response"
        exit 1
    fi

    log_success "Authentication successful"
    echo "$access_token"
}

# Enumerate available versions
enumerate_versions() {
    local access_token="$1"

    log_info "Fetching available FCS CLI versions..."

    local filter="category:\"fcs\""
    [[ -n "$FCS_TARGET_OS" ]] && filter="${filter}+os:\"${FCS_TARGET_OS}\""
    [[ -n "$FCS_TARGET_ARCH" ]] && filter="${filter}+arch:\"${FCS_TARGET_ARCH}\""

    local response
    response=$(curl --silent --get \
        --header "Accept: application/json" \
        --header "Authorization: Bearer ${access_token}" \
        --url "${FALCON_API_URL}/csdownloads/combined/files-download/v2" \
        --data-urlencode "filter=${filter}")

    echo "$response"
}

# Download FCS CLI
download_fcs_cli() {
    local access_token="$1"
    local download_info="$2"

    local file_name
    local file_version
    local file_hash
    local download_url

    file_name=$(echo "$download_info" | jq -r '.file_name')
    file_version=$(echo "$download_info" | jq -r '.file_version')
    file_hash=$(echo "$download_info" | jq -r '.file_hash')
    download_url=$(echo "$download_info" | jq -r '.download_info.download_url')

    log_info "Downloading: $file_name"
    log_info "Version: $file_version"
    log_info "SHA256: $file_hash"

    local output_path="${OUTPUT_DIR}/${file_name}"

    curl --location --progress-bar --output "$output_path" "$download_url"

    log_success "Downloaded: $output_path"

    # Verify hash
    log_info "Verifying file integrity..."

    local computed_hash
    if command -v sha256sum &> /dev/null; then
        computed_hash=$(sha256sum "$output_path" | awk '{print $1}')
    elif command -v shasum &> /dev/null; then
        computed_hash=$(shasum -a 256 "$output_path" | awk '{print $1}')
    else
        log_warn "SHA256 verification tool not found, skipping verification"
        return
    fi

    if [[ "$computed_hash" == "$file_hash" ]]; then
        log_success "File integrity verified"
    else
        log_error "Hash mismatch!"
        log_error "Expected: $file_hash"
        log_error "Got: $computed_hash"
        exit 1
    fi

    echo "$output_path"
}

# Main execution
main() {
    log_info "FCS CLI Programmatic Download Script"
    echo

    check_prerequisites
    detect_platform

    local access_token
    access_token=$(get_access_token)

    local versions_response
    versions_response=$(enumerate_versions "$access_token")

    # Get the first (latest) version
    local download_info
    download_info=$(echo "$versions_response" | jq -r '.resources[0]')

    if [[ "$download_info" == "null" ]] || [[ -z "$download_info" ]]; then
        log_error "No FCS CLI versions found for ${FCS_TARGET_OS}/${FCS_TARGET_ARCH}"
        exit 1
    fi

    local downloaded_file
    downloaded_file=$(download_fcs_cli "$access_token" "$download_info")

    echo
    log_success "Download complete!"
    log_info "File: $downloaded_file"
    echo
    echo "Next steps:"
    echo "  1. Extract: tar -xzf $downloaded_file (or unzip for Windows)"
    echo "  2. Make executable: chmod +x fcs"
    echo "  3. Move to PATH: sudo mv fcs /usr/local/bin/"
    echo "  4. Configure: fcs configure"
    echo
}

# Run main
main
