#!/usr/bin/env bash
# Test script for development environment setup

set -euo pipefail

# Colors and logging
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

# Test function
test_yq_installation() {
    log_info "Testing yq installation..."
    
    # Check if we're in a container environment
    local is_container=false
    if [[ -f /.dockerenv ]] || [[ -n "${CONTAINER:-}" ]] || [[ "$(hostname)" =~ ^[0-9a-f]{12}$ ]]; then
        is_container=true
        log_warn "Container environment detected"
    fi
    
    # Ensure ~/.local/bin exists and is in PATH
    mkdir -p ~/.local/bin
    if ! echo "$PATH" | grep -q "$HOME/.local/bin"; then
        export PATH="$HOME/.local/bin:$PATH"
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
    fi
    
    # Install yq separately (not available in standard Ubuntu repos)
    if ! command -v yq >/dev/null 2>&1; then
        log_info "Installing yq from GitHub releases..."
        YQ_VERSION="v4.35.2"
        if curl -L "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_amd64" -o ~/.local/bin/yq; then
            chmod +x ~/.local/bin/yq
            log_success "yq installed successfully"
        else
            log_error "Failed to install yq"
            return 1
        fi
    else
        log_success "yq already installed"
    fi
    
    # Test yq
    if yq --version; then
        log_success "yq is working correctly"
    else
        log_error "yq installation failed"
        return 1
    fi
}

# Run test
log_info "Starting yq installation test..."
if test_yq_installation; then
    log_success "All tests passed!"
else
    log_error "Tests failed!"
    exit 1
fi
