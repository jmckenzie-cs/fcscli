#!/usr/bin/env bash

# FCS CLI Installation Script
# Automatically downloads and installs the CrowdStrike Falcon Cloud Security CLI

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
VERSION="2.2.0"
OS=""
ARCH=""
INSTALL_DIR="/usr/local/bin"
DOWNLOAD_URL_BASE="https://falcon.crowdstrike.com/downloads"

# Usage information
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Install CrowdStrike FCS CLI

OPTIONS:
    -v, --version VERSION    FCS CLI version to install (default: ${VERSION})
    -o, --os OS             Operating system: linux, darwin, windows
    -a, --arch ARCH         Architecture: amd64, arm64
    -d, --dir DIR           Installation directory (default: ${INSTALL_DIR})
    -h, --help              Show this help message

EXAMPLES:
    # Install latest version for macOS Apple Silicon
    $0 --os darwin --arch arm64

    # Install specific version for Linux x86_64
    $0 --version 2.1.5 --os linux --arch amd64

    # Install to custom directory
    $0 --os darwin --arch arm64 --dir ~/bin

EOF
    exit 1
}

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

# Detect OS and architecture
detect_platform() {
    if [[ -z "$OS" ]]; then
        case "$(uname -s)" in
            Linux*)     OS="linux";;
            Darwin*)    OS="darwin";;
            MINGW*|MSYS*|CYGWIN*) OS="windows";;
            *)
                log_error "Unsupported operating system: $(uname -s)"
                exit 1
                ;;
        esac
        log_info "Detected OS: $OS"
    fi

    if [[ -z "$ARCH" ]]; then
        case "$(uname -m)" in
            x86_64|amd64)   ARCH="amd64";;
            arm64|aarch64)  ARCH="arm64";;
            *)
                log_error "Unsupported architecture: $(uname -m)"
                exit 1
                ;;
        esac
        log_info "Detected architecture: $ARCH"
    fi
}

# Build filename based on OS and architecture
build_filename() {
    local os_name arch_name extension

    case "$OS" in
        darwin)
            os_name="Darwin"
            extension="tar.gz"
            ;;
        linux)
            os_name="Linux"
            extension="tar.gz"
            ;;
        windows)
            os_name="Windows"
            extension="zip"
            ;;
    esac

    case "$ARCH" in
        amd64)
            [[ "$OS" == "darwin" ]] && arch_name="x86_64" || arch_name="x86_64"
            ;;
        arm64)
            arch_name="arm64"
            ;;
    esac

    echo "fcs_${VERSION}_${os_name}_${arch_name}.${extension}"
}

# Check if FCS CLI is already installed
check_existing_installation() {
    if command -v fcs &> /dev/null; then
        local current_version
        current_version=$(fcs --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "unknown")
        log_info "FCS CLI is already installed (version: $current_version)"

        read -p "Do you want to replace it with version ${VERSION}? [y/N] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Installation cancelled"
            exit 0
        fi
    fi
}

# Download FCS CLI
download_fcs() {
    local filename="$1"
    local tmp_dir
    tmp_dir=$(mktemp -d)

    log_info "Downloading FCS CLI ${VERSION} for ${OS}/${ARCH}..."
    log_info "Filename: $filename"

    # Note: Replace with actual download URL from Falcon console
    # This is a placeholder - users need to get the actual URL
    log_warn "Please manually download ${filename} from:"
    log_warn "  Falcon Console > Support and resources > Tool downloads"
    log_warn "Then place it in: ${tmp_dir}"
    echo
    read -p "Press Enter after downloading the file to ${tmp_dir}/${filename}..."

    if [[ ! -f "${tmp_dir}/${filename}" ]]; then
        log_error "File not found: ${tmp_dir}/${filename}"
        exit 1
    fi

    echo "$tmp_dir"
}

# Extract and install
install_fcs() {
    local tmp_dir="$1"
    local filename="$2"

    log_info "Extracting FCS CLI..."

    cd "$tmp_dir"

    if [[ "$filename" == *.tar.gz ]]; then
        tar -xzf "$filename"
    elif [[ "$filename" == *.zip ]]; then
        unzip -q "$filename"
    fi

    local binary_name="fcs"
    [[ "$OS" == "windows" ]] && binary_name="fcs.exe"

    if [[ ! -f "$binary_name" ]]; then
        log_error "Binary not found after extraction: $binary_name"
        exit 1
    fi

    log_info "Installing to ${INSTALL_DIR}/${binary_name}..."

    # Make executable
    chmod +x "$binary_name"

    # Install
    if [[ -w "$INSTALL_DIR" ]]; then
        mv "$binary_name" "${INSTALL_DIR}/"
    else
        sudo mv "$binary_name" "${INSTALL_DIR}/"
    fi

    # Cleanup
    cd - > /dev/null
    rm -rf "$tmp_dir"

    log_success "FCS CLI ${VERSION} installed successfully!"
}

# Verify installation
verify_installation() {
    log_info "Verifying installation..."

    if ! command -v fcs &> /dev/null; then
        log_error "fcs command not found in PATH"
        log_error "Please add ${INSTALL_DIR} to your PATH"
        exit 1
    fi

    local installed_version
    installed_version=$(fcs --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "unknown")

    log_success "FCS CLI version: $installed_version"
    log_info "Run 'fcs configure' to set up your credentials"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--version)
            VERSION="$2"
            shift 2
            ;;
        -o|--os)
            OS="$2"
            shift 2
            ;;
        -a|--arch)
            ARCH="$2"
            shift 2
            ;;
        -d|--dir)
            INSTALL_DIR="$2"
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

# Main execution
main() {
    log_info "FCS CLI Installation Script"
    echo

    detect_platform
    check_existing_installation

    local filename
    filename=$(build_filename)

    local tmp_dir
    tmp_dir=$(download_fcs "$filename")

    install_fcs "$tmp_dir" "$filename"
    verify_installation

    echo
    log_success "Installation complete!"
    echo
    echo "Next steps:"
    echo "  1. Run: fcs configure"
    echo "  2. Enter your Falcon Client ID and Secret"
    echo "  3. Select your Falcon Region"
    echo "  4. Start scanning: fcs scan image nginx:latest"
    echo
}

main
