#!/usr/bin/env bash
# =============================================================================
# VSCode Server Setup Script (Windows/Git Bash Compatible)
# Dirancang untuk Windows dengan Git Bash/MSYS2
# =============================================================================

set -euo pipefail

# -------------------------------------------------------------------------
# CONFIGURATION
# -------------------------------------------------------------------------
CODE_SERVER_VERSION="4.20.0"
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
        # Fallback method for Windows
        echo "$(date +%s)$(whoami)" | sha256sum | cut -c1-25
    fi
}

detect_environment() {
    log_info "Detecting environment..."
    
    if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]]; then
        log_info "Windows Git Bash/MSYS2 detected"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        log_info "Linux environment detected"
    else
        log_info "Unknown environment: $OSTYPE"
    fi
}

# -------------------------------------------------------------------------
# INSTALLATION FUNCTIONS
# -------------------------------------------------------------------------
install_nodejs() {
    log_info "Checking Node.js installation..."
    
    if command_exists node && command_exists npm; then
        local node_version=$(node --version)
        log_success "Node.js already installed: $node_version"
        return 0
    fi
    
    log_error "Node.js not found. Please install Node.js first:"
    log_info "1. Download from: https://nodejs.org/"
    log_info "2. Or use package manager: winget install OpenJS.NodeJS"
    log_info "3. Restart terminal after installation"
    exit 1
}

install_code_server() {
    log_info "Installing code-server..."
    
    # Create directories
    mkdir -p "$CONFIG_DIR" "$DATA_DIR" "$LOG_DIR"
    
    # Check if code-server is already installed
    if command_exists code-server; then
        log_success "Code-server already installed"
        return 0
    fi
    
    # Install code-server using npm (Windows-compatible method)
    log_info "Installing code-server via npm..."
    npm install -g code-server
    
    if command_exists code-server; then
        log_success "Code-server installed successfully"
    else
        log_error "Failed to install code-server"
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
# SERVICE MANAGEMENT (Windows-Compatible)
# -------------------------------------------------------------------------
create_management_scripts() {
    log_info "Creating management scripts..."
    
    # Create scripts directory
    mkdir -p "$HOME/bin"
    
    # Start script (Windows batch file)
    cat > "$HOME/bin/code-server-start.bat" <<'EOF'
@echo off
echo Starting code-server...

REM Kill any existing code-server processes
taskkill /F /IM node.exe /FI "WINDOWTITLE eq code-server*" >nul 2>&1

REM Start code-server
start "code-server" cmd /c "code-server --config %USERPROFILE%\.config\code-server\config.yaml"

timeout /t 3 >nul

REM Check if started successfully
tasklist /FI "WINDOWTITLE eq code-server*" | find "node.exe" >nul
if %errorlevel% == 0 (
    echo Code-server started successfully
    echo Access URL: http://localhost:8080
    type "%USERPROFILE%\.config\code-server\password.txt" 2>nul && echo Password: & type "%USERPROFILE%\.config\code-server\password.txt"
) else (
    echo Failed to start code-server
)
EOF
    
    # Start script (Bash version)
    cat > "$HOME/bin/code-server-start.sh" <<'EOF'
#!/bin/bash
CONFIG_FILE="$HOME/.config/code-server/config.yaml"
LOG_FILE="$HOME/.local/share/code-server/logs/server.log"

echo "Starting code-server..."

# Kill any existing code-server processes
pkill -f "code-server" 2>/dev/null || true

# Create log directory
mkdir -p "$(dirname "$LOG_FILE")"

# Start code-server in background
nohup code-server --config "$CONFIG_FILE" > "$LOG_FILE" 2>&1 &
CODE_SERVER_PID=$!

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
echo "Stopping code-server..."

if pkill -f "code-server"; then
    echo "Code-server stopped"
else
    echo "No code-server processes found"
fi
EOF
    
    # Status script
    cat > "$HOME/bin/code-server-status.sh" <<'EOF'
#!/bin/bash
echo "=== Code-Server Status ==="

if pgrep -f "code-server" >/dev/null; then
    echo "Status: Running"
    echo "PID: $(pgrep -f "code-server")"
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
    
    # Make bash scripts executable
    chmod +x "$HOME/bin/code-server-"*.sh
    
    log_success "Management scripts created in $HOME/bin/"
}

start_code_server() {
    log_info "Starting code-server..."
    
    # Use the bash script we just created
    "$HOME/bin/code-server-start.sh"
}

# -------------------------------------------------------------------------
# MAIN EXECUTION
# -------------------------------------------------------------------------
main() {
    log_info "Starting Windows-compatible code-server setup..."
    
    detect_environment
    install_nodejs
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
    log_info "Windows batch file: ~/bin/code-server-start.bat"
    log_info ""
    
    # Try to start code-server
    start_code_server
}

# Run main function
main "$@"
