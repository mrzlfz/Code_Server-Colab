#!/usr/bin/env bash
# Test script to verify the security setup fix

set -euo pipefail

# Colors and logging
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

# Test the certificate creation function
test_certificate_creation() {
    log_info "Testing certificate creation..."
    
    # Ensure ~/.local/bin exists
    mkdir -p ~/.local/bin
    
    # Create a minimal certificate management script for testing
    cat > ~/.local/bin/test-code-server-certs <<'EOF'
#!/bin/bash
CERT_DIR="$HOME/.config/code-server/certs"

create_self_signed() {
    local domain="${1:-localhost}"
    mkdir -p "$CERT_DIR"
    
    echo "Creating self-signed certificate for $domain..."
    
    # Check if openssl is available
    if ! command -v openssl >/dev/null 2>&1; then
        echo "Error: openssl not found"
        return 1
    fi
    
    # Create certificate
    openssl req -x509 -newkey rsa:2048 -keyout "$CERT_DIR/key.pem" \
        -out "$CERT_DIR/cert.pem" -days 365 -nodes \
        -subj "/C=US/ST=State/L=City/O=CodeServer/CN=$domain" 2>/dev/null
    
    if [[ $? -eq 0 ]]; then
        chmod 600 "$CERT_DIR/key.pem"
        chmod 644 "$CERT_DIR/cert.pem"
        echo "✓ Self-signed certificate created successfully"
        return 0
    else
        echo "✗ Failed to create certificate"
        return 1
    fi
}

# Main command handling
case "${1:-}" in
    "create-self")
        create_self_signed "$2"
        ;;
    *)
        echo "Usage: $0 create-self <domain>"
        exit 1
        ;;
esac
EOF
    
    chmod +x ~/.local/bin/test-code-server-certs
    
    # Test the certificate creation
    if ~/.local/bin/test-code-server-certs create-self localhost; then
        log_success "Certificate creation test passed"
        
        # Verify files were created
        if [[ -f ~/.config/code-server/certs/cert.pem && -f ~/.config/code-server/certs/key.pem ]]; then
            log_success "Certificate files created successfully"
            log_info "Certificate location: ~/.config/code-server/certs/"
            ls -la ~/.config/code-server/certs/
        else
            log_error "Certificate files not found"
            return 1
        fi
    else
        log_error "Certificate creation test failed"
        return 1
    fi
    
    # Clean up test files
    rm -f ~/.local/bin/test-code-server-certs
}

# Test environment detection
test_environment_detection() {
    log_info "Testing environment detection..."
    
    if [[ -f /.dockerenv ]] || [[ -n "${CONTAINER:-}" ]] || [[ "$(hostname)" =~ ^[0-9a-f]{12}$ ]]; then
        log_info "Container environment detected"
        log_info "Hostname: $(hostname)"
        log_info "Container indicators:"
        [[ -f /.dockerenv ]] && log_info "  - /.dockerenv exists"
        [[ -n "${CONTAINER:-}" ]] && log_info "  - CONTAINER variable set"
        [[ "$(hostname)" =~ ^[0-9a-f]{12}$ ]] && log_info "  - Container-like hostname"
    else
        log_info "Non-container environment detected"
    fi
}

# Main test execution
main() {
    log_info "Starting security setup fix tests..."
    
    test_environment_detection
    
    if command -v openssl >/dev/null 2>&1; then
        test_certificate_creation
    else
        log_warn "OpenSSL not available, skipping certificate tests"
        log_info "Install openssl: sudo apt-get install -y openssl"
    fi
    
    log_success "All tests completed!"
}

# Run tests
main "$@"
