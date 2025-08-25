#!/usr/bin/env bash
# =============================================================================
# VSCode Server Setup Script (Windows Binary Download)
# Menggunakan binary download untuk menghindari masalah npm di Windows
# =============================================================================

set -euo pipefail

# -------------------------------------------------------------------------
# CONFIGURATION
# -------------------------------------------------------------------------
CODE_SERVER_VERSION="4.103.1"
BIND_ADDR="127.0.0.1:8080"
CONFIG_DIR="$HOME/.config/code-server"
DATA_DIR="$HOME/.local/share/code-server"
LOG_DIR="$DATA_DIR/logs"
INSTALL_DIR="$HOME/.local/bin"

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

download_code_server() {
    log_info "Downloading code-server binary..."
    
    # Create directories
    mkdir -p "$CONFIG_DIR" "$DATA_DIR" "$LOG_DIR" "$INSTALL_DIR"
    
    # Check if already installed
    if [[ -f "$INSTALL_DIR/code-server.exe" ]]; then
        log_success "Code-server binary already exists"
        return 0
    fi
    
    # Determine architecture
    local arch="amd64"
    if [[ "$(uname -m)" == "arm64" ]] || [[ "$(uname -m)" == "aarch64" ]]; then
        arch="arm64"
    fi
    
    # Download URL
    local download_url="https://github.com/coder/code-server/releases/download/v${CODE_SERVER_VERSION}/code-server-${CODE_SERVER_VERSION}-windows-${arch}.zip"
    local zip_file="$INSTALL_DIR/code-server.zip"
    
    log_info "Downloading from: $download_url"
    
    if command_exists curl; then
        curl -L -o "$zip_file" "$download_url"
    elif command_exists wget; then
        wget -O "$zip_file" "$download_url"
    else
        log_error "Neither curl nor wget found. Please install one of them."
        exit 1
    fi
    
    if [[ ! -f "$zip_file" ]]; then
        log_error "Failed to download code-server"
        exit 1
    fi
    
    log_success "Downloaded code-server"
}

extract_code_server() {
    log_info "Extracting code-server..."
    
    local zip_file="$INSTALL_DIR/code-server.zip"
    local extract_dir="$INSTALL_DIR/code-server-temp"
    
    # Create temporary extraction directory
    mkdir -p "$extract_dir"
    
    # Extract using unzip (should be available in Git Bash)
    if command_exists unzip; then
        unzip -q "$zip_file" -d "$extract_dir"
    else
        log_error "unzip command not found. Please install unzip."
        exit 1
    fi
    
    # Find the extracted directory
    local extracted_dir=$(find "$extract_dir" -name "code-server-*" -type d | head -1)
    
    if [[ -z "$extracted_dir" ]]; then
        log_error "Could not find extracted code-server directory"
        exit 1
    fi
    
    # Copy binary to install directory
    cp "$extracted_dir/bin/code-server.exe" "$INSTALL_DIR/"
    
    # Clean up
    rm -rf "$extract_dir" "$zip_file"
    
    # Make executable (though .exe should already be)
    chmod +x "$INSTALL_DIR/code-server.exe"
    
    log_success "Code-server extracted successfully"
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
Binary: $INSTALL_DIR/code-server.exe
EOF
}

# -------------------------------------------------------------------------
# SERVICE MANAGEMENT
# -------------------------------------------------------------------------
create_management_scripts() {
    log_info "Creating management scripts..."
    
    # Start script
    cat > "$INSTALL_DIR/code-server-start.sh" <<EOF
#!/bin/bash
CONFIG_FILE="$CONFIG_DIR/config.yaml"
LOG_FILE="$LOG_DIR/server.log"
PID_FILE="$DATA_DIR/code-server.pid"
BINARY="$INSTALL_DIR/code-server.exe"

echo "Starting code-server..."

# Kill any existing processes
pkill -f "code-server" 2>/dev/null || true

# Create log directory
mkdir -p "\$(dirname "\$LOG_FILE")"

# Start code-server in background
nohup "\$BINARY" --config "\$CONFIG_FILE" > "\$LOG_FILE" 2>&1 &
CODE_SERVER_PID=\$!

echo \$CODE_SERVER_PID > "\$PID_FILE"

sleep 3

# Check if process is still running
if kill -0 \$CODE_SERVER_PID 2>/dev/null; then
    echo "Code-server started successfully (PID: \$CODE_SERVER_PID)"
    echo "Access URL: http://localhost:8080"
    if [[ -f "$CONFIG_DIR/password.txt" ]]; then
        echo "Password: \$(cat "$CONFIG_DIR/password.txt")"
    fi
    echo "Logs: \$LOG_FILE"
else
    echo "Failed to start code-server"
    echo "Check logs: \$LOG_FILE"
    exit 1
fi
EOF
    
    # Stop script
    cat > "$INSTALL_DIR/code-server-stop.sh" <<EOF
#!/bin/bash
PID_FILE="$DATA_DIR/code-server.pid"

echo "Stopping code-server..."

if [[ -f "\$PID_FILE" ]]; then
    PID=\$(cat "\$PID_FILE")
    if kill -0 "\$PID" 2>/dev/null; then
        kill "\$PID"
        rm -f "\$PID_FILE"
        echo "Code-server stopped (PID: \$PID)"
    else
        echo "Code-server was not running"
        rm -f "\$PID_FILE"
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
    cat > "$INSTALL_DIR/code-server-status.sh" <<EOF
#!/bin/bash
PID_FILE="$DATA_DIR/code-server.pid"

echo "=== Code-Server Status ==="

if [[ -f "\$PID_FILE" ]] && kill -0 "\$(cat "\$PID_FILE")" 2>/dev/null; then
    PID=\$(cat "\$PID_FILE")
    echo "Status: Running (PID: \$PID)"
    echo "Access URL: http://localhost:8080"
    
    if [[ -f "$CONFIG_DIR/password.txt" ]]; then
        echo "Password: \$(cat "$CONFIG_DIR/password.txt")"
    fi
else
    echo "Status: Not running"
fi

echo ""
echo "Recent log entries:"
tail -5 "$LOG_DIR/server.log" 2>/dev/null || echo "No logs available"
EOF
    
    # Make scripts executable
    chmod +x "$INSTALL_DIR/code-server-"*.sh
    
    log_success "Management scripts created"
}

start_code_server() {
    log_info "Starting code-server..."
    
    # Use the script we just created
    "$INSTALL_DIR/code-server-start.sh"
}

# -------------------------------------------------------------------------
# MAIN EXECUTION
# -------------------------------------------------------------------------
main() {
    log_info "Starting Windows code-server setup (binary download)..."
    
    detect_environment
    install_nodejs
    download_code_server
    extract_code_server
    create_config
    create_management_scripts
    
    log_success "Setup completed successfully!"
    log_info ""
    log_info "Management commands:"
    log_info "  Start:  $INSTALL_DIR/code-server-start.sh"
    log_info "  Stop:   $INSTALL_DIR/code-server-stop.sh"
    log_info "  Status: $INSTALL_DIR/code-server-status.sh"
    log_info ""
    
    # Try to start code-server
    start_code_server
}

# Run main function
main "\$@"
