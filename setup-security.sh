#!/usr/bin/env bash
# =============================================================================
# Security & Authentication Setup for Code-Server
# SSL/TLS certificates, authentication, access control, and security hardening
# =============================================================================

set -euo pipefail

# Container-optimized environment settings
export DEBIAN_FRONTEND=noninteractive
export APT_LISTCHANGES_FRONTEND=none
export NEEDRESTART_MODE=a

# Colors and logging
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

# Container detection
detect_container() {
    if [[ -f /.dockerenv ]] || [[ -n "${CONTAINER:-}" ]] || [[ "$(hostname)" =~ ^[0-9a-f]{12}$ ]]; then
        return 0  # is container
    else
        return 1  # not container
    fi
}

# -------------------------------------------------------------------------
# SSL/TLS CERTIFICATE MANAGEMENT
# -------------------------------------------------------------------------
setup_ssl_certificates() {
    log_info "Setting up SSL/TLS certificates..."
    
    # Create certificates directory
    mkdir -p ~/.config/code-server/certs
    
    # Install certbot for Let's Encrypt
    log_info "Installing SSL certificate tools..."
    if detect_container; then
        log_info "Container environment detected, using quiet installation"
        sudo apt-get update -qq >/dev/null 2>&1 || {
            log_warn "Package update failed, continuing anyway"
        }
        sudo apt-get install -y -qq certbot python3-certbot-nginx >/dev/null 2>&1 || {
            log_warn "Certbot installation failed, SSL features may be limited"
        }
    else
        sudo apt-get update
        sudo apt-get install -y certbot python3-certbot-nginx
    fi
    
    # Create self-signed certificate for local development
    create_self_signed_cert() {
        local cert_dir="$HOME/.config/code-server/certs"
        local domain="${1:-localhost}"
        
        log_info "Creating self-signed certificate for $domain..."
        
        openssl req -x509 -newkey rsa:4096 -keyout "$cert_dir/key.pem" \
            -out "$cert_dir/cert.pem" -days 365 -nodes \
            -subj "/C=US/ST=State/L=City/O=Organization/CN=$domain"
        
        chmod 600 "$cert_dir/key.pem"
        chmod 644 "$cert_dir/cert.pem"
        
        log_success "Self-signed certificate created"
    }
    
    # Create certificate management script
    cat > ~/.local/bin/code-server-certs <<'EOF'
#!/bin/bash
CERT_DIR="$HOME/.config/code-server/certs"

show_help() {
    echo "Code-Server Certificate Manager"
    echo "Usage: $0 [command] [options]"
    echo ""
    echo "Commands:"
    echo "  create-self <domain>     Create self-signed certificate"
    echo "  letsencrypt <domain>     Get Let's Encrypt certificate"
    echo "  renew                    Renew certificates"
    echo "  status                   Show certificate status"
    echo "  install                  Install certificates to code-server"
    echo ""
}

create_self_signed() {
    local domain="${1:-localhost}"
    mkdir -p "$CERT_DIR"
    
    echo "Creating self-signed certificate for $domain..."
    openssl req -x509 -newkey rsa:4096 -keyout "$CERT_DIR/key.pem" \
        -out "$CERT_DIR/cert.pem" -days 365 -nodes \
        -subj "/C=US/ST=State/L=City/O=CodeServer/CN=$domain"
    
    chmod 600 "$CERT_DIR/key.pem"
    chmod 644 "$CERT_DIR/cert.pem"
    
    echo "✓ Self-signed certificate created"
}

get_letsencrypt() {
    local domain="$1"
    if [[ -z "$domain" ]]; then
        echo "Error: Domain required for Let's Encrypt"
        return 1
    fi
    
    echo "Getting Let's Encrypt certificate for $domain..."
    
    # Stop nginx temporarily
    sudo systemctl stop nginx 2>/dev/null || true
    
    # Get certificate
    sudo certbot certonly --standalone -d "$domain" --non-interactive --agree-tos \
        --email "admin@$domain" || {
        echo "Failed to get Let's Encrypt certificate"
        sudo systemctl start nginx 2>/dev/null || true
        return 1
    }
    
    # Copy certificates to code-server directory
    sudo cp "/etc/letsencrypt/live/$domain/fullchain.pem" "$CERT_DIR/cert.pem"
    sudo cp "/etc/letsencrypt/live/$domain/privkey.pem" "$CERT_DIR/key.pem"
    sudo chown $USER:$USER "$CERT_DIR"/*.pem
    chmod 600 "$CERT_DIR/key.pem"
    chmod 644 "$CERT_DIR/cert.pem"
    
    # Restart nginx
    sudo systemctl start nginx 2>/dev/null || true
    
    echo "✓ Let's Encrypt certificate obtained"
}

renew_certificates() {
    echo "Renewing certificates..."
    sudo certbot renew --quiet
    
    # Update code-server certificates if they exist
    for domain_dir in /etc/letsencrypt/live/*/; do
        if [[ -d "$domain_dir" ]]; then
            domain=$(basename "$domain_dir")
            if [[ -f "$domain_dir/fullchain.pem" ]]; then
                sudo cp "$domain_dir/fullchain.pem" "$CERT_DIR/cert.pem"
                sudo cp "$domain_dir/privkey.pem" "$CERT_DIR/key.pem"
                sudo chown $USER:$USER "$CERT_DIR"/*.pem
                echo "✓ Updated certificates for $domain"
            fi
        fi
    done
}

show_status() {
    echo "=== Certificate Status ==="
    
    if [[ -f "$CERT_DIR/cert.pem" ]]; then
        echo "Certificate: Found"
        echo "Expires: $(openssl x509 -enddate -noout -in "$CERT_DIR/cert.pem" | cut -d= -f2)"
        echo "Subject: $(openssl x509 -subject -noout -in "$CERT_DIR/cert.pem" | cut -d= -f2-)"
    else
        echo "Certificate: Not found"
    fi
    
    if [[ -f "$CERT_DIR/key.pem" ]]; then
        echo "Private Key: Found"
    else
        echo "Private Key: Not found"
    fi
}

install_to_codeserver() {
    if [[ ! -f "$CERT_DIR/cert.pem" || ! -f "$CERT_DIR/key.pem" ]]; then
        echo "Error: Certificates not found"
        return 1
    fi
    
    # Update code-server config
    local config_file="$HOME/.config/code-server/config.yaml"
    if [[ -f "$config_file" ]]; then
        # Enable SSL and set certificate paths
        sed -i 's/cert: false/cert: true/' "$config_file"
        
        # Add certificate paths if not present
        if ! grep -q "cert-file:" "$config_file"; then
            echo "cert-file: $CERT_DIR/cert.pem" >> "$config_file"
        fi
        if ! grep -q "cert-key:" "$config_file"; then
            echo "cert-key: $CERT_DIR/key.pem" >> "$config_file"
        fi
        
        echo "✓ Certificates installed to code-server config"
        echo "Restart code-server to apply changes"
    else
        echo "Error: code-server config not found"
        return 1
    fi
}

# Main command handling
case "${1:-}" in
    "create-self")
        create_self_signed "$2"
        ;;
    "letsencrypt")
        get_letsencrypt "$2"
        ;;
    "renew")
        renew_certificates
        ;;
    "status")
        show_status
        ;;
    "install")
        install_to_codeserver
        ;;
    "help"|"-h"|"--help"|"")
        show_help
        ;;
    *)
        echo "Unknown command: $1"
        show_help
        exit 1
        ;;
esac
EOF
    chmod +x ~/.local/bin/code-server-certs

    # Create initial self-signed certificate using the generated script
    log_info "Creating initial self-signed certificate..."
    if ~/.local/bin/code-server-certs create-self localhost; then
        log_success "Initial self-signed certificate created"
    else
        log_warn "Failed to create initial certificate, you can create it manually later"
    fi

    log_success "SSL/TLS certificate management configured"
}

# -------------------------------------------------------------------------
# AUTHENTICATION SYSTEM
# -------------------------------------------------------------------------
setup_authentication() {
    log_info "Setting up authentication system..."
    
    # Create authentication script
    cat > ~/.local/bin/code-server-auth <<'EOF'
#!/bin/bash
CONFIG_FILE="$HOME/.config/code-server/config.yaml"

show_help() {
    echo "Code-Server Authentication Manager"
    echo "Usage: $0 [command] [options]"
    echo ""
    echo "Commands:"
    echo "  password <new-password>  Set new password"
    echo "  generate                 Generate random password"
    echo "  disable                  Disable authentication"
    echo "  enable                   Enable password authentication"
    echo "  status                   Show authentication status"
    echo ""
}

set_password() {
    local password="$1"
    if [[ -z "$password" ]]; then
        echo "Error: Password required"
        return 1
    fi
    
    # Update config file
    if [[ -f "$CONFIG_FILE" ]]; then
        sed -i "s/^password:.*/password: $password/" "$CONFIG_FILE"
        sed -i "s/^auth:.*/auth: password/" "$CONFIG_FILE"
        echo "✓ Password updated"
        echo "Restart code-server to apply changes"
    else
        echo "Error: Config file not found"
        return 1
    fi
}

generate_password() {
    local password=$(openssl rand -base64 32 | tr -d '=+/' | cut -c1-25)
    echo "Generated password: $password"
    set_password "$password"
}

disable_auth() {
    if [[ -f "$CONFIG_FILE" ]]; then
        sed -i "s/^auth:.*/auth: none/" "$CONFIG_FILE"
        echo "✓ Authentication disabled"
        echo "⚠️  WARNING: Code-server will be accessible without password!"
        echo "Restart code-server to apply changes"
    else
        echo "Error: Config file not found"
        return 1
    fi
}

enable_auth() {
    if [[ -f "$CONFIG_FILE" ]]; then
        sed -i "s/^auth:.*/auth: password/" "$CONFIG_FILE"
        echo "✓ Password authentication enabled"
        echo "Restart code-server to apply changes"
    else
        echo "Error: Config file not found"
        return 1
    fi
}

show_status() {
    echo "=== Authentication Status ==="
    if [[ -f "$CONFIG_FILE" ]]; then
        local auth_method=$(grep "^auth:" "$CONFIG_FILE" | cut -d: -f2 | tr -d ' ')
        echo "Method: $auth_method"
        
        if [[ "$auth_method" == "password" ]]; then
            local password=$(grep "^password:" "$CONFIG_FILE" | cut -d: -f2 | tr -d ' ')
            echo "Password: ${password:0:3}***${password: -3}"
        fi
    else
        echo "Config file not found"
    fi
}

# Main command handling
case "${1:-}" in
    "password")
        set_password "$2"
        ;;
    "generate")
        generate_password
        ;;
    "disable")
        disable_auth
        ;;
    "enable")
        enable_auth
        ;;
    "status")
        show_status
        ;;
    "help"|"-h"|"--help"|"")
        show_help
        ;;
    *)
        echo "Unknown command: $1"
        show_help
        exit 1
        ;;
esac
EOF
    chmod +x ~/.local/bin/code-server-auth
    
    log_success "Authentication system configured"
}

# -------------------------------------------------------------------------
# SECURITY HARDENING
# -------------------------------------------------------------------------
setup_security_hardening() {
    log_info "Applying security hardening..."
    
    # Create security hardening script
    cat > ~/.local/bin/code-server-harden <<'EOF'
#!/bin/bash
show_help() {
    echo "Code-Server Security Hardening"
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  apply     Apply security hardening"
    echo "  check     Check security status"
    echo "  restore   Restore original settings"
    echo ""
}

apply_hardening() {
    echo "Applying security hardening..."
    
    # File permissions
    chmod 700 ~/.config/code-server
    chmod 600 ~/.config/code-server/config.yaml 2>/dev/null || true
    chmod 700 ~/.local/share/code-server
    
    # Remove world-readable permissions from logs
    find ~/.local/share/code-server/logs -type f -exec chmod 640 {} \; 2>/dev/null || true
    
    # Secure SSH if present
    if [[ -d ~/.ssh ]]; then
        chmod 700 ~/.ssh
        chmod 600 ~/.ssh/* 2>/dev/null || true
        chmod 644 ~/.ssh/*.pub 2>/dev/null || true
    fi
    
    echo "✓ File permissions hardened"
    
    # System hardening (if possible)
    # Check if we're in a container environment
    local is_container=false
    if [[ -f /.dockerenv ]] || [[ -n "${CONTAINER:-}" ]] || [[ "$(hostname)" =~ ^[0-9a-f]{12}$ ]]; then
        is_container=true
    fi

    if [[ $EUID -eq 0 ]] && [[ "$is_container" == "false" ]]; then
        # Test if sysctl can write (not read-only filesystem)
        if echo "# Test write" >> /etc/sysctl.conf 2>/dev/null; then
            # Remove test line
            sed -i '/# Test write/d' /etc/sysctl.conf 2>/dev/null

            # Disable unused network protocols
            echo "net.ipv4.conf.all.send_redirects = 0" >> /etc/sysctl.conf
            echo "net.ipv4.conf.default.send_redirects = 0" >> /etc/sysctl.conf
            echo "net.ipv4.conf.all.accept_redirects = 0" >> /etc/sysctl.conf
            echo "net.ipv4.conf.default.accept_redirects = 0" >> /etc/sysctl.conf

            # Apply settings if possible
            if sysctl -p >/dev/null 2>&1; then
                echo "✓ System hardening applied"
            else
                echo "⚠️  System hardening configured but may require reboot"
            fi
        else
            echo "⚠️  Cannot modify sysctl.conf (read-only filesystem)"
        fi
    elif [[ "$is_container" == "true" ]]; then
        echo "⚠️  Skipping system hardening in container environment"
    else
        echo "⚠️  Run as root for system-level hardening"
    fi
}

check_security() {
    echo "=== Security Status ==="
    
    # Check file permissions
    echo "File Permissions:"
    ls -la ~/.config/code-server/ 2>/dev/null | head -5
    
    # Check for weak passwords
    if [[ -f ~/.config/code-server/config.yaml ]]; then
        local password=$(grep "^password:" ~/.config/code-server/config.yaml | cut -d: -f2 | tr -d ' ')
        if [[ ${#password} -lt 12 ]]; then
            echo "⚠️  Password is shorter than 12 characters"
        else
            echo "✓ Password length is adequate"
        fi
    fi
    
    # Check SSL status
    if grep -q "cert: true" ~/.config/code-server/config.yaml 2>/dev/null; then
        echo "✓ SSL/TLS enabled"
    else
        echo "⚠️  SSL/TLS disabled"
    fi
    
    # Check authentication
    local auth_method=$(grep "^auth:" ~/.config/code-server/config.yaml 2>/dev/null | cut -d: -f2 | tr -d ' ')
    if [[ "$auth_method" == "none" ]]; then
        echo "⚠️  Authentication disabled"
    else
        echo "✓ Authentication enabled"
    fi
}

# Main command handling
case "${1:-check}" in
    "apply")
        apply_hardening
        ;;
    "check")
        check_security
        ;;
    "help"|"-h"|"--help")
        show_help
        ;;
    *)
        echo "Unknown command: $1"
        show_help
        exit 1
        ;;
esac
EOF
    chmod +x ~/.local/bin/code-server-harden
    
    # Apply initial hardening
    ~/.local/bin/code-server-harden apply
    
    log_success "Security hardening configured"
}

# -------------------------------------------------------------------------
# MAIN EXECUTION
# -------------------------------------------------------------------------
main() {
    log_info "Setting up Security & Authentication..."
    
    setup_ssl_certificates
    setup_authentication
    setup_security_hardening
    
    log_success "Security & Authentication setup completed!"
    log_info ""
    log_info "Security Commands:"
    log_info "  Certificates: ~/.local/bin/code-server-certs"
    log_info "  Authentication: ~/.local/bin/code-server-auth"
    log_info "  Hardening: ~/.local/bin/code-server-harden"
}

# Run main function
main "$@"
