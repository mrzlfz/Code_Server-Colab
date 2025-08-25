#!/usr/bin/env bash
# =============================================================================
# VSCode Server Setup Script (Simple Windows/Linux Compatible)
# Menggunakan instalasi script resmi dari code-server
# =============================================================================

set -euo pipefail

# -------------------------------------------------------------------------
# CONFIGURATION
# -------------------------------------------------------------------------
BIND_ADDR="127.0.0.1:8080"
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
        echo "$(date +%s)$(whoami)" | sha256sum | cut -c1-25 2>/dev/null || echo "codeserver$(date +%s)"
    fi
}

detect_environment() {
    log_info "Detecting environment..."
    
    if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]]; then
        log_info "Windows Git Bash/MSYS2 detected"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        log_info "Linux environment detected"
    else
        log_info "Environment: $OSTYPE"
    fi
}

# -------------------------------------------------------------------------
# INSTALLATION FUNCTIONS
# -------------------------------------------------------------------------
install_code_server() {
    log_info "Installing code-server using official installer..."
    
    # Create directories
    mkdir -p "$CONFIG_DIR" "$DATA_DIR" "$LOG_DIR"
    
    # Check if already installed
    if command_exists code-server; then
        log_success "Code-server already installed"
        return 0
    fi
    
    # Use official install script
    log_info "Downloading and running official installer..."
    
    # Download and run the install script
    if command_exists curl; then
        curl -fsSL https://code-server.dev/install.sh | sh
    elif command_exists wget; then
        wget -qO- https://code-server.dev/install.sh | sh
    else
        log_error "Neither curl nor wget found. Please install one of them."
        exit 1
    fi
    
    # Check if installation was successful
    if command_exists code-server; then
        log_success "Code-server installed successfully"
    else
        log_error "Code-server installation failed"
        exit 1
    fi
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
    
    log_success "Configuration created"
    log_info "Password: $password"
    
    # Save password to file for easy access
    echo "$password" > "$CONFIG_DIR/password.txt"
    
    # Save access info
    cat > "$CONFIG_DIR/access-info.txt" <<EOF
Code-Server Access Information
=============================
URL: http://localhost:8080
Password: $password
Config: $CONFIG_DIR/config.yaml
Logs: $LOG_DIR
EOF
}

# -------------------------------------------------------------------------
# SERVICE MANAGEMENT
# -------------------------------------------------------------------------
create_management_scripts() {
    log_info "Creating management scripts..."
    
    mkdir -p "$HOME/bin"
    
    # Start script
    cat > "$HOME/bin/code-server-start.sh" <<'EOF'
#!/bin/bash
CONFIG_FILE="$HOME/.config/code-server/config.yaml"
LOG_FILE="$HOME/.local/share/code-server/logs/server.log"
PID_FILE="$HOME/.local/share/code-server/code-server.pid"

echo "Starting code-server..."

# Kill any existing processes
pkill -f "code-server" 2>/dev/null || true

# Create log directory
mkdir -p "$(dirname "$LOG_FILE")"

# Start code-server in background
nohup code-server --config "$CONFIG_FILE" > "$LOG_FILE" 2>&1 &
CODE_SERVER_PID=$!

echo $CODE_SERVER_PID > "$PID_FILE"

sleep 3

# Check if process is still running
if kill -0 $CODE_SERVER_PID 2>/dev/null; then
    echo "Code-server started successfully (PID: $CODE_SERVER_PID)"
    echo "Access URL: http://localhost:8080"
    if [[ -f "$HOME/.config/code-server/password.txt" ]]; then
        echo "Password: $(cat "$HOME/.config/code-server/password.txt")"
    fi
    echo "Logs: $LOG_FILE"
else
    echo "Failed to start code-server"
    echo "Check logs: $LOG_FILE"
    exit 1
fi
EOF
    
    # Stop script
    cat > "$HOME/bin/code-server-stop.sh" <<'EOF'
#!/bin/bash
PID_FILE="$HOME/.local/share/code-server/code-server.pid"

echo "Stopping code-server..."

if [[ -f "$PID_FILE" ]]; then
    PID=$(cat "$PID_FILE")
    if kill -0 "$PID" 2>/dev/null; then
        kill "$PID"
        rm -f "$PID_FILE"
        echo "Code-server stopped (PID: $PID)"
    else
        echo "Code-server was not running"
        rm -f "$PID_FILE"
    fi
else
    echo "No PID file found, trying to kill by process name..."
    if pkill -f "code-server"; then
        echo "Code-server processes killed"
    else
        echo "No code-server processes found"
    fi
fi
EOF
    
    # Status script
    cat > "$HOME/bin/code-server-status.sh" <<'EOF'
#!/bin/bash
PID_FILE="$HOME/.local/share/code-server/code-server.pid"

echo "=== Code-Server Status ==="

if [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
    PID=$(cat "$PID_FILE")
    echo "Status: Running (PID: $PID)"
    echo "Access URL: http://localhost:8080"
    
    if [[ -f "$HOME/.config/code-server/password.txt" ]]; then
        echo "Password: $(cat "$HOME/.config/code-server/password.txt")"
    fi
else
    echo "Status: Not running"
fi

echo ""
echo "Recent log entries:"
tail -5 "$HOME/.local/share/code-server/logs/server.log" 2>/dev/null || echo "No logs available"
EOF
    
    # Make scripts executable
    chmod +x "$HOME/bin/code-server-"*.sh
    
    log_success "Management scripts created"
}

start_code_server() {
    log_info "Starting code-server..."
    
    # Use the script we just created
    "$HOME/bin/code-server-start.sh"
}

# -------------------------------------------------------------------------
# MAIN EXECUTION
# -------------------------------------------------------------------------
main() {
    log_info "Starting simple code-server setup..."
    
    detect_environment
    install_code_server
    create_config
    create_management_scripts
    
    log_success "Setup completed successfully!"
    log_info ""
    log_info "Management commands:"
    log_info "  Start:  ~/bin/code-server-start.sh"
    log_info "  Stop:   ~/bin/code-server-stop.sh"
    log_info "  Status: ~/bin/code-server-status.sh"
    log_info ""
    
    # Try to start code-server
    start_code_server
}

# Run main function
main "$@"
