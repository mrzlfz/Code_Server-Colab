#!/usr/bin/env bash
# =============================================================================
# VSCode Server Setup Script - Google Colab Optimized
# Versi khusus untuk Google Colab tanpa sudo/firewall requirements
# =============================================================================

set -euo pipefail

# -------------------------------------------------------------------------
# LOGGING FUNCTIONS
# -------------------------------------------------------------------------
log_info() { echo -e "\033[34m[INFO]\033[0m $1"; }
log_success() { echo -e "\033[32m[SUCCESS]\033[0m $1"; }
log_warn() { echo -e "\033[33m[WARN]\033[0m $1"; }
log_error() { echo -e "\033[31m[ERROR]\033[0m $1"; }

# -------------------------------------------------------------------------
# ENVIRONMENT DETECTION
# -------------------------------------------------------------------------
detect_environment() {
    if [[ -n "${COLAB_GPU:-}" ]] || [[ -n "${COLAB_TPU_ADDR:-}" ]] || [[ -d "/content" ]]; then
        ENVIRONMENT="colab"
        log_info "Google Colab environment detected"
    else
        ENVIRONMENT="standard"
        log_info "Standard Linux environment detected"
    fi
}

# -------------------------------------------------------------------------
# CONFIGURATION
# -------------------------------------------------------------------------
CODE_SERVER_VERSION="4.20.0"
INSTALL_METHOD="script"
PROCESS_MANAGER="nohup"  # Colab-friendly process manager
BIND_ADDR="0.0.0.0:8888"
ENABLE_SSL=false
INSTALL_EXTENSIONS=true
EXTENSION_MARKETPLACE="openvsx"  # Colab-friendly marketplace

# -------------------------------------------------------------------------
# UTILITIES
# -------------------------------------------------------------------------
command_exists() { command -v "$1" >/dev/null 2>&1; }

generate_password() {
    openssl rand -base64 32 | tr -d '=+/' | cut -c1-25
}

# -------------------------------------------------------------------------
# COLAB-SAFE DEPENDENCY INSTALLATION
# -------------------------------------------------------------------------
install_dependencies_colab() {
    log_info "Installing dependencies (Colab-safe mode)..."
    
    # Check if we can use sudo
    if sudo -n true 2>/dev/null; then
        log_info "Sudo available, installing system packages..."
        sudo apt-get update -y
        sudo apt-get install -y curl wget git build-essential pkg-config lsof openssl jq htop unzip
    else
        log_warn "Sudo not available, using user-space alternatives..."
        # Install user-space alternatives
        mkdir -p ~/.local/bin
        
        # Install essential tools to user space if not available
        if ! command_exists jq; then
            log_info "Installing jq to user space..."
            curl -L "https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64" -o ~/.local/bin/jq
            chmod +x ~/.local/bin/jq
        fi
    fi
    
    log_success "Dependencies installed"
}

# -------------------------------------------------------------------------
# NODE.JS INSTALLATION
# -------------------------------------------------------------------------
install_nodejs() {
    if command_exists node && command_exists npm; then
        log_info "Node.js already installed: $(node --version)"
        return
    fi

    log_info "Installing Node.js..."
    curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
    if sudo -n true 2>/dev/null; then
        sudo apt-get install -y nodejs
    else
        # Install Node.js to user space
        log_info "Installing Node.js to user space..."
        curl -L "https://nodejs.org/dist/v18.17.0/node-v18.17.0-linux-x64.tar.xz" | tar -xJ -C ~/.local/
        ln -sf ~/.local/node-v18.17.0-linux-x64/bin/node ~/.local/bin/node
        ln -sf ~/.local/node-v18.17.0-linux-x64/bin/npm ~/.local/bin/npm
    fi
    
    log_success "Node.js installed"
}

# -------------------------------------------------------------------------
# CODE-SERVER INSTALLATION
# -------------------------------------------------------------------------
install_code_server() {
    log_info "Installing code-server..."
    
    case "$INSTALL_METHOD" in
    script)
        curl -fsSL https://code-server.dev/install.sh | sh
        ;;
    standalone)
        mkdir -p ~/.local/{lib,bin}
        curl -fL "https://github.com/coder/code-server/releases/download/v$CODE_SERVER_VERSION/code-server-$CODE_SERVER_VERSION-linux-amd64.tar.gz" |
            tar -C ~/.local/lib -xz
        mv ~/.local/lib/code-server-$CODE_SERVER_VERSION-linux-amd64 ~/.local/lib/code-server-$CODE_SERVER_VERSION
        ln -sf ~/.local/lib/code-server-$CODE_SERVER_VERSION/bin/code-server ~/.local/bin/code-server
        ;;
    esac
    
    # Ensure ~/.local/bin is in PATH
    if ! echo "$PATH" | grep -q "$HOME/.local/bin"; then
        echo 'export PATH="$HOME/.local/bin:$PATH"' >>~/.bashrc
        export PATH="$HOME/.local/bin:$PATH"
    fi
    
    log_success "code-server installed"
}

# -------------------------------------------------------------------------
# CONFIGURATION
# -------------------------------------------------------------------------
create_config() {
    log_info "Creating code-server configuration..."
    mkdir -p ~/.config/code-server ~/.local/share/code-server/logs

    PASSWORD=$(generate_password)

    cat >~/.config/code-server/config.yaml <<EOF
bind-addr: $BIND_ADDR
auth: password
password: $PASSWORD
cert: $ENABLE_SSL
disable-telemetry: true
disable-update-check: true
disable-workspace-trust: true
log: info
EOF

    log_success "Configuration saved to ~/.config/code-server/config.yaml"
    log_warn "Generated password: $PASSWORD"
    echo "Password: $PASSWORD"
}

# -------------------------------------------------------------------------
# COLAB-SAFE PROCESS MANAGEMENT
# -------------------------------------------------------------------------
start_code_server_colab() {
    log_info "Starting code-server (Colab mode)..."
    
    # Kill any existing code-server processes
    pkill -f "code-server" 2>/dev/null || true
    
    # Start with nohup (Colab-friendly)
    local pid_file="$HOME/.local/share/code-server/code-server.pid"
    local log_file="$HOME/.local/share/code-server/logs/server.log"
    
    nohup "$(command -v code-server)" --config ~/.config/code-server/config.yaml \
        >"$log_file" 2>&1 &
    
    echo $! > "$pid_file"
    
    # Wait for startup
    sleep 3
    
    # Verify it's running
    if kill -0 "$(cat "$pid_file")" 2>/dev/null; then
        log_success "code-server started successfully"
        log_info "Access URL: http://localhost:8888"
        log_info "Log file: $log_file"
    else
        log_error "Failed to start code-server"
        return 1
    fi
}

# -------------------------------------------------------------------------
# EXTENSION INSTALLATION
# -------------------------------------------------------------------------
install_extensions() {
    if [[ "$INSTALL_EXTENSIONS" != "true" ]]; then
        return
    fi

    log_info "Installing essential extensions..."
    
    # Essential extensions for Colab
    local extensions=(
        "ms-python.python"
        "ms-toolsai.jupyter"
        "ms-vscode.vscode-json"
        "redhat.vscode-yaml"
        "ms-vscode.vscode-typescript-next"
    )

    for ext in "${extensions[@]}"; do
        log_info "Installing extension: $ext"
        if [[ "$EXTENSION_MARKETPLACE" == "openvsx" ]]; then
            SERVICE_URL=https://open-vsx.org/vscode/gallery \
            ITEM_URL=https://open-vsx.org/vscode/item \
            code-server --install-extension "$ext" || log_warn "Failed to install $ext"
        else
            code-server --install-extension "$ext" || log_warn "Failed to install $ext"
        fi
    done
    
    log_success "Extensions installed"
}

# -------------------------------------------------------------------------
# MAIN EXECUTION
# -------------------------------------------------------------------------
main() {
    log_info "Starting Google Colab optimized code-server setup..."
    
    detect_environment
    install_dependencies_colab
    install_nodejs
    install_code_server
    create_config
    start_code_server_colab
    install_extensions
    
    log_success "Setup completed!"
    log_info "=== ACCESS INFORMATION ==="
    log_info "URL: http://localhost:8888"
    log_info "Password: $(grep "^password:" ~/.config/code-server/config.yaml | cut -d: -f2 | tr -d ' ')"
    log_info ""
    log_info "=== MANAGEMENT COMMANDS ==="
    log_info "Check status: ps aux | grep code-server"
    log_info "View logs: tail -f ~/.local/share/code-server/logs/server.log"
    log_info "Stop server: pkill -f code-server"
}

# Run main function
main "$@"
