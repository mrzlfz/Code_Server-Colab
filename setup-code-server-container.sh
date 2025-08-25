#!/usr/bin/env bash
# =============================================================================
# VSCode Server Setup Script (Container/Colab Optimized)
# Versi Container-Safe - tanpa konfigurasi sistem yang memerlukan root
#
# Script ini dirancang khusus untuk environment container seperti:
# - Google Colab
# - Docker containers
# - Restricted environments
# =============================================================================

set -euo pipefail

# -------------------------------------------------------------------------
# CONFIGURATION
# -------------------------------------------------------------------------
CODE_SERVER_VERSION="4.20.0"
BIND_ADDR="0.0.0.0:8080"
CONFIG_DIR="$HOME/.config/code-server"
DATA_DIR="$HOME/.local/share/code-server"
LOG_DIR="$DATA_DIR/logs"

# -------------------------------------------------------------------------
# LOGGING FUNCTIONS
# -------------------------------------------------------------------------
log_info() { echo -e "\033[34m[INFO]\033[0m $1"; }
log_success() { echo -e "\033[32m[SUCCESS]\033[0m $1"; }
log_warn() { echo -e "\033[33m[WARN]\033[0m $1"; }
log_error() { echo -e "\033[31m[ERROR]\033[0m $1"; }

# -------------------------------------------------------------------------
# UTILITY FUNCTIONS
# -------------------------------------------------------------------------
command_exists() { command -v "$1" >/dev/null 2>&1; }

generate_password() {
    if command_exists openssl; then
        openssl rand -base64 32 | tr -d '=+/' | cut -c1-25
    else
        # Fallback method
        date +%s | sha256sum | base64 | head -c 25
    fi
}

detect_environment() {
    log_info "Detecting environment..."
    
    if [[ -f /.dockerenv ]]; then
        log_info "Docker container detected"
    elif [[ -n "${COLAB_GPU:-}" ]]; then
        log_info "Google Colab detected"
    elif [[ "$(hostname)" =~ ^[0-9a-f]{12}$ ]]; then
        log_info "Container environment detected"
    else
        log_info "Standard Linux environment detected"
    fi
}

# -------------------------------------------------------------------------
# INSTALLATION FUNCTIONS
# -------------------------------------------------------------------------
install_dependencies() {
    log_info "Installing basic dependencies..."
    
    # Update package list if possible
    if command_exists apt-get && [[ $EUID -eq 0 || -n "${SUDO_USER:-}" ]]; then
        sudo apt-get update -qq
        sudo apt-get install -y curl wget unzip
    elif command_exists apt-get; then
        log_warn "Cannot update packages (no sudo access)"
    fi
    
    log_success "Dependencies check completed"
}

install_nodejs() {
    log_info "Checking Node.js installation..."
    
    if command_exists node && command_exists npm; then
        local node_version=$(node --version)
        log_success "Node.js already installed: $node_version"
        return 0
    fi
    
    log_info "Installing Node.js..."
    
    # Install Node.js using NodeSource repository
    if [[ $EUID -eq 0 || -n "${SUDO_USER:-}" ]]; then
        curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
        sudo apt-get install -y nodejs
    else
        # Install Node.js locally using n-install
        log_info "Installing Node.js locally (no sudo)..."
        curl -L https://bit.ly/n-install | bash -s -- -y
        export PATH="$HOME/n/bin:$PATH"
    fi
    
    log_success "Node.js installed successfully"
}

install_code_server() {
    log_info "Installing code-server..."
    
    # Create directories
    mkdir -p "$CONFIG_DIR" "$DATA_DIR" "$LOG_DIR"
    
    # Install code-server
    curl -fsSL https://code-server.dev/install.sh | sh -s -- --method=standalone --prefix="$HOME/.local"
    
    # Add to PATH if not already there
    if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
        export PATH="$HOME/.local/bin:$PATH"
    fi
    
    log_success "Code-server installed successfully"
}

create_config() {
    log_info "Creating code-server configuration..."
    
    local password=$(generate_password)
    
    cat > "$CONFIG_DIR/config.yaml" <<EOF
bind-addr: $BIND_ADDR
auth: password
password: $password
cert: false
disable-telemetry: true
disable-update-check: true
EOF
    
    chmod 600 "$CONFIG_DIR/config.yaml"
    
    log_success "Configuration created"
    log_info "Password: $password"
    
    # Save password to file for easy access
    echo "$password" > "$CONFIG_DIR/password.txt"
    chmod 600 "$CONFIG_DIR/password.txt"
}

# -------------------------------------------------------------------------
# SERVICE MANAGEMENT (Container-Safe)
# -------------------------------------------------------------------------
create_management_scripts() {
    log_info "Creating management scripts..."
    
    mkdir -p ~/.local/bin
    
    # Start script
    cat > ~/.local/bin/code-server-start <<'EOF'
#!/bin/bash
CONFIG_FILE="$HOME/.config/code-server/config.yaml"
PID_FILE="$HOME/.local/share/code-server/code-server.pid"
LOG_FILE="$HOME/.local/share/code-server/logs/server.log"

if [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
    echo "Code-server is already running (PID: $(cat "$PID_FILE"))"
    exit 0
fi

echo "Starting code-server..."
mkdir -p "$(dirname "$LOG_FILE")"

nohup code-server --config "$CONFIG_FILE" > "$LOG_FILE" 2>&1 &
echo $! > "$PID_FILE"

sleep 2
if kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
    echo "Code-server started successfully (PID: $(cat "$PID_FILE"))"
    echo "Access URL: http://localhost:$(grep bind-addr "$CONFIG_FILE" | cut -d: -f3)"
    echo "Password: $(cat "$HOME/.config/code-server/password.txt")"
else
    echo "Failed to start code-server"
    exit 1
fi
EOF
    
    # Stop script
    cat > ~/.local/bin/code-server-stop <<'EOF'
#!/bin/bash
PID_FILE="$HOME/.local/share/code-server/code-server.pid"

if [[ -f "$PID_FILE" ]]; then
    PID=$(cat "$PID_FILE")
    if kill -0 "$PID" 2>/dev/null; then
        echo "Stopping code-server (PID: $PID)..."
        kill "$PID"
        rm -f "$PID_FILE"
        echo "Code-server stopped"
    else
        echo "Code-server was not running"
        rm -f "$PID_FILE"
    fi
else
    echo "No PID file found, trying to kill by process name..."
    pkill -f "code-server" && echo "Code-server processes killed" || echo "No code-server processes found"
fi
EOF
    
    # Status script
    cat > ~/.local/bin/code-server-status <<'EOF'
#!/bin/bash
PID_FILE="$HOME/.local/share/code-server/code-server.pid"
CONFIG_FILE="$HOME/.config/code-server/config.yaml"

echo "=== Code-Server Status ==="

if [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
    PID=$(cat "$PID_FILE")
    echo "Status: Running (PID: $PID)"
    echo "Memory: $(ps -o rss= -p "$PID" | awk '{print int($1/1024) "MB"}')"
    echo "CPU: $(ps -o %cpu= -p "$PID")%"
else
    echo "Status: Not running"
fi

if [[ -f "$CONFIG_FILE" ]]; then
    PORT=$(grep bind-addr "$CONFIG_FILE" | cut -d: -f3)
    echo "Port: $PORT"
    echo "Access URL: http://localhost:$PORT"
fi

echo ""
echo "Recent log entries:"
tail -5 "$HOME/.local/share/code-server/logs/server.log" 2>/dev/null || echo "No logs available"
EOF
    
    # Make scripts executable
    chmod +x ~/.local/bin/code-server-{start,stop,status}
    
    log_success "Management scripts created"
}

# -------------------------------------------------------------------------
# MAIN EXECUTION
# -------------------------------------------------------------------------
main() {
    log_info "Starting container-safe code-server setup..."
    
    detect_environment
    install_dependencies
    install_nodejs
    install_code_server
    create_config
    create_management_scripts
    
    log_success "Setup completed successfully!"
    log_info ""
    log_info "To start code-server: ~/.local/bin/code-server-start"
    log_info "To stop code-server:  ~/.local/bin/code-server-stop"
    log_info "To check status:      ~/.local/bin/code-server-status"
    log_info ""
    log_info "Starting code-server now..."
    
    # Start code-server
    ~/.local/bin/code-server-start
}

# Run main function
main "$@"
