#!/usr/bin/env bash
# Comprehensive Code-Server Diagnostic and Fix Script

set -euo pipefail

# Colors and logging
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

# Configuration
CONFIG_FILE="$HOME/.config/code-server/config.yaml"
LOG_DIR="$HOME/.local/share/code-server/logs"

# Step 1: Test code-server binary directly
test_binary() {
    log_info "=== Testing Code-Server Binary ==="
    
    # Check if binary exists
    if ! command -v code-server >/dev/null; then
        log_error "Code-server binary not found in PATH"
        log_info "PATH: $PATH"
        return 1
    fi
    
    local binary_path=$(command -v code-server)
    log_success "Binary found: $binary_path"
    
    # Check if executable
    if [[ ! -x "$binary_path" ]]; then
        log_error "Binary not executable"
        return 1
    fi
    
    # Test version command
    log_info "Testing version command..."
    if timeout 10 code-server --version >/dev/null 2>&1; then
        log_success "Version command works"
        log_info "Version: $(code-server --version | head -1)"
    else
        log_error "Version command failed or timed out"
        return 1
    fi
    
    # Test help command
    log_info "Testing help command..."
    if timeout 10 code-server --help >/dev/null 2>&1; then
        log_success "Help command works"
    else
        log_error "Help command failed"
        return 1
    fi
    
    return 0
}

# Step 2: Check and fix configuration
check_config() {
    log_info "=== Checking Configuration ==="
    
    # Create config directory
    mkdir -p "$(dirname "$CONFIG_FILE")"
    mkdir -p "$LOG_DIR"
    
    # Check if config exists
    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_warn "Config file not found, creating basic config..."
        create_basic_config
    fi
    
    log_info "Config file: $CONFIG_FILE"
    log_info "Config content:"
    cat "$CONFIG_FILE"
    
    # Validate YAML syntax
    if command -v python3 >/dev/null; then
        if python3 -c "import yaml; yaml.safe_load(open('$CONFIG_FILE'))" 2>/dev/null; then
            log_success "Config file YAML syntax is valid"
        else
            log_error "Config file has YAML syntax errors"
            log_info "Recreating config file..."
            create_basic_config
        fi
    else
        log_warn "Cannot validate YAML syntax (python3 not available)"
    fi
    
    return 0
}

# Create basic working configuration
create_basic_config() {
    local password=$(openssl rand -base64 32 | tr -d '=+/' | cut -c1-25)
    
    cat > "$CONFIG_FILE" <<EOF
bind-addr: 0.0.0.0:8888
auth: password
password: $password
cert: false
disable-telemetry: true
disable-update-check: true
disable-workspace-trust: true
log: info
EOF
    
    log_success "Basic config created with password: $password"
}

# Step 3: Test direct startup
test_direct_startup() {
    log_info "=== Testing Direct Startup ==="
    
    # Kill any existing processes
    pkill -f "code-server" 2>/dev/null || true
    sleep 2
    
    # Test with minimal config and verbose output
    log_info "Testing direct startup with verbose output..."
    
    # Create a test log file
    local test_log="$LOG_DIR/direct-test.log"
    
    # Try to start code-server directly
    log_info "Starting code-server directly..."
    timeout 30 code-server --config "$CONFIG_FILE" --verbose > "$test_log" 2>&1 &
    local pid=$!
    
    log_info "Started with PID: $pid"
    
    # Wait a bit for startup
    sleep 10
    
    # Check if process is still running
    if kill -0 $pid 2>/dev/null; then
        log_success "Process is still running"
        
        # Test HTTP connectivity
        if curl -s -f "http://127.0.0.1:8888/healthz" >/dev/null 2>&1; then
            log_success "HTTP connectivity works!"
            log_info "Code-server is working correctly"
            
            # Kill the test process
            kill $pid 2>/dev/null || true
            
            return 0
        else
            log_warn "Process running but HTTP not responding"
            log_info "Checking what's in the log..."
            tail -20 "$test_log"
        fi
    else
        log_error "Process died during startup"
        log_info "Checking startup log..."
        cat "$test_log"
    fi
    
    return 1
}

# Step 4: Handle root user issues
handle_root_issues() {
    log_info "=== Handling Root User Issues ==="
    
    if [[ $EUID -eq 0 ]]; then
        log_warn "Running as root - this may cause issues with code-server"
        
        # Try with --allow-http and --disable-workspace-trust
        log_info "Testing with root-friendly options..."
        
        local test_log="$LOG_DIR/root-test.log"
        
        timeout 30 code-server \
            --bind-addr 0.0.0.0:8888 \
            --auth password \
            --password test123 \
            --disable-workspace-trust \
            --disable-telemetry \
            --allow-http \
            --verbose > "$test_log" 2>&1 &
        local pid=$!
        
        sleep 10
        
        if kill -0 $pid 2>/dev/null; then
            if curl -s -f "http://127.0.0.1:8888/healthz" >/dev/null 2>&1; then
                log_success "Root-friendly startup works!"
                kill $pid 2>/dev/null || true
                
                # Update config with root-friendly settings
                cat > "$CONFIG_FILE" <<EOF
bind-addr: 0.0.0.0:8888
auth: password
password: test123
cert: false
disable-telemetry: true
disable-update-check: true
disable-workspace-trust: true
log: info
EOF
                log_success "Updated config with root-friendly settings"
                return 0
            fi
        fi
        
        log_error "Root-friendly startup failed"
        log_info "Startup log:"
        cat "$test_log"
    else
        log_info "Not running as root"
    fi
    
    return 1
}

# Step 5: Create working startup script
create_working_startup() {
    log_info "=== Creating Working Startup Script ==="
    
    cat > "$HOME/.local/bin/start-code-server-working" <<'EOF'
#!/bin/bash
# Working Code-Server Startup Script

CONFIG_FILE="$HOME/.config/code-server/config.yaml"
LOG_FILE="$HOME/.local/share/code-server/logs/server.log"
PID_FILE="$HOME/.local/share/code-server/code-server.pid"

# Ensure directories exist
mkdir -p "$(dirname "$LOG_FILE")" "$(dirname "$PID_FILE")"

# Kill existing processes
pkill -f "code-server" 2>/dev/null || true
sleep 2

# Start code-server
echo "Starting code-server..."
echo "Config: $CONFIG_FILE"
echo "Log: $LOG_FILE"

if [[ $EUID -eq 0 ]]; then
    # Root-friendly startup
    nohup code-server \
        --bind-addr 0.0.0.0:8888 \
        --auth password \
        --password test123 \
        --disable-workspace-trust \
        --disable-telemetry \
        --allow-http \
        > "$LOG_FILE" 2>&1 &
else
    # Regular startup
    nohup code-server --config "$CONFIG_FILE" > "$LOG_FILE" 2>&1 &
fi

PID=$!
echo $PID > "$PID_FILE"
echo "Started with PID: $PID"

# Wait and test
sleep 5
if kill -0 $PID 2>/dev/null; then
    echo "Process is running"
    if curl -s -f "http://127.0.0.1:8888/healthz" >/dev/null 2>&1; then
        echo "✓ Code-server is working!"
        echo "Access: http://127.0.0.1:8888"
        if [[ $EUID -eq 0 ]]; then
            echo "Password: test123"
        else
            echo "Password: $(grep password: $CONFIG_FILE | cut -d' ' -f2)"
        fi
    else
        echo "✗ Process running but not responding"
        tail -10 "$LOG_FILE"
    fi
else
    echo "✗ Process failed to start"
    cat "$LOG_FILE"
fi
EOF
    
    chmod +x "$HOME/.local/bin/start-code-server-working"
    log_success "Working startup script created: ~/.local/bin/start-code-server-working"
}

# Main diagnostic and fix process
main() {
    log_info "🔍 Code-Server Comprehensive Diagnostic and Fix"
    log_info "User: $(whoami)"
    log_info "Home: $HOME"
    log_info "Container: $(if [[ -f /.dockerenv ]]; then echo "Yes"; else echo "No"; fi)"
    
    # Stop PM2 first
    log_info "Stopping PM2..."
    pm2 delete code-server 2>/dev/null || true
    pm2 kill 2>/dev/null || true
    
    # Run diagnostics
    if test_binary; then
        log_success "✓ Binary test passed"
    else
        log_error "✗ Binary test failed - code-server installation issue"
        exit 1
    fi
    
    if check_config; then
        log_success "✓ Configuration check passed"
    else
        log_error "✗ Configuration check failed"
        exit 1
    fi
    
    if test_direct_startup; then
        log_success "✓ Direct startup test passed"
        log_info "Code-server can run normally"
    elif handle_root_issues; then
        log_success "✓ Root-friendly startup works"
        log_info "Code-server works with root-friendly settings"
    else
        log_error "✗ All startup tests failed"
        log_info "Creating working startup script anyway..."
    fi
    
    create_working_startup
    
    log_success "🎉 Diagnostic complete!"
    log_info "To start code-server: ~/.local/bin/start-code-server-working"
    log_info "Or use: ./start-code-server-manual.sh start"
}

# Run main function
main "$@"
