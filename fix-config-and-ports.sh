#!/usr/bin/env bash
# Fix Configuration and Port Conflicts for Code-Server

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
TARGET_BIND_ADDR="0.0.0.0:8888"
TARGET_PORT="8888"

# Function to kill processes using specific ports
kill_port_processes() {
    local port=$1
    log_info "Checking port $port for conflicts..."
    
    if command -v lsof >/dev/null; then
        local pids=$(lsof -t -i:"$port" 2>/dev/null || true)
        if [[ -n "$pids" ]]; then
            log_warn "Found processes using port $port: $pids"
            echo "$pids" | xargs kill -9 2>/dev/null || true
            sleep 1
            log_success "Killed processes on port $port"
        else
            log_info "Port $port is free"
        fi
    elif command -v netstat >/dev/null; then
        local pid=$(netstat -tlnp 2>/dev/null | grep ":$port " | awk '{print $7}' | cut -d'/' -f1 | head -1 || true)
        if [[ -n "$pid" && "$pid" != "0" ]]; then
            log_warn "Found process using port $port: $pid"
            kill -9 "$pid" 2>/dev/null || true
            sleep 1
            log_success "Killed process $pid on port $port"
        else
            log_info "Port $port is free"
        fi
    else
        log_warn "Cannot check port usage (no lsof or netstat)"
    fi
}

# Function to fix configuration file
fix_configuration() {
    log_info "Fixing code-server configuration..."
    
    # Create config directory if it doesn't exist
    mkdir -p "$(dirname "$CONFIG_FILE")"
    
    # Check current configuration
    if [[ -f "$CONFIG_FILE" ]]; then
        log_info "Current configuration:"
        cat "$CONFIG_FILE"
        echo ""
        
        # Check if bind-addr is wrong
        local current_bind=$(grep "bind-addr:" "$CONFIG_FILE" | cut -d' ' -f2 || echo "")
        if [[ "$current_bind" != "$TARGET_BIND_ADDR" ]]; then
            log_warn "Wrong bind address detected: $current_bind"
            log_info "Should be: $TARGET_BIND_ADDR"
            
            # Extract current password
            local current_password=$(grep "password:" "$CONFIG_FILE" | cut -d' ' -f2 || echo "")
            if [[ -z "$current_password" ]]; then
                current_password=$(openssl rand -base64 32 | tr -d '=+/' | cut -c1-25)
                log_info "Generated new password: $current_password"
            else
                log_info "Keeping existing password: $current_password"
            fi
            
            # Create corrected configuration
            cat > "$CONFIG_FILE" <<EOF
bind-addr: $TARGET_BIND_ADDR
auth: password
password: $current_password
cert: false
disable-telemetry: true
disable-update-check: true
disable-workspace-trust: true
log: info
EOF
            log_success "Configuration fixed!"
        else
            log_success "Configuration bind address is correct"
        fi
    else
        log_warn "Configuration file not found, creating new one..."
        local new_password=$(openssl rand -base64 32 | tr -d '=+/' | cut -c1-25)
        
        cat > "$CONFIG_FILE" <<EOF
bind-addr: $TARGET_BIND_ADDR
auth: password
password: $new_password
cert: false
disable-telemetry: true
disable-update-check: true
disable-workspace-trust: true
log: info
EOF
        log_success "New configuration created with password: $new_password"
    fi
    
    log_info "Final configuration:"
    cat "$CONFIG_FILE"
}

# Function to clean up all conflicting processes and ports
cleanup_processes_and_ports() {
    log_info "Cleaning up processes and ports..."
    
    # Kill all code-server processes
    log_info "Killing code-server processes..."
    pkill -f "code-server" 2>/dev/null || true
    sleep 2
    
    # Force kill if still running
    if pgrep -f "code-server" >/dev/null; then
        log_warn "Force killing remaining code-server processes..."
        pkill -9 -f "code-server" 2>/dev/null || true
        sleep 1
    fi
    
    # Clean up common ports
    for port in 8080 8888 4040; do
        kill_port_processes "$port"
    done
    
    # Stop PM2 if running
    if command -v pm2 >/dev/null; then
        log_info "Stopping PM2..."
        pm2 delete code-server 2>/dev/null || true
        pm2 kill 2>/dev/null || true
    fi
    
    log_success "Cleanup completed"
}

# Function to test code-server startup
test_startup() {
    log_info "Testing code-server startup..."
    
    # Test direct startup
    log_info "Starting code-server for testing..."
    timeout 15 code-server --config "$CONFIG_FILE" --verbose > /tmp/test-startup.log 2>&1 &
    local pid=$!
    
    sleep 5
    
    if kill -0 $pid 2>/dev/null; then
        # Test HTTP connectivity
        if curl -s -f "http://127.0.0.1:$TARGET_PORT/healthz" >/dev/null 2>&1; then
            log_success "✓ Code-server startup test successful!"
            kill $pid 2>/dev/null || true
            return 0
        else
            log_warn "Process running but HTTP not responding"
            log_info "Startup log:"
            tail -10 /tmp/test-startup.log
            kill $pid 2>/dev/null || true
        fi
    else
        log_error "Process failed to start"
        log_info "Startup log:"
        cat /tmp/test-startup.log
    fi
    
    return 1
}

# Function to create fixed startup script
create_fixed_startup() {
    log_info "Creating fixed startup script..."
    
    mkdir -p ~/.local/bin
    
    cat > ~/.local/bin/code-server-fixed-start <<EOF
#!/bin/bash
# Fixed Code-Server Startup Script

CONFIG_FILE="$CONFIG_FILE"
LOG_FILE="\$HOME/.local/share/code-server/logs/server.log"
PID_FILE="\$HOME/.local/share/code-server/code-server.pid"

# Ensure directories exist
mkdir -p "\$(dirname "\$LOG_FILE")" "\$(dirname "\$PID_FILE")"

# Kill existing processes and clean ports
echo "Cleaning up existing processes..."
pkill -f "code-server" 2>/dev/null || true
sleep 2

# Clean up ports
for port in 8080 8888; do
    if command -v lsof >/dev/null; then
        pids=\$(lsof -t -i:\$port 2>/dev/null || true)
        if [[ -n "\$pids" ]]; then
            echo "Killing processes on port \$port: \$pids"
            echo "\$pids" | xargs kill -9 2>/dev/null || true
        fi
    fi
done

sleep 2

# Start code-server
echo "Starting code-server..."
echo "Config: \$CONFIG_FILE"
echo "Log: \$LOG_FILE"

nohup code-server --config "\$CONFIG_FILE" > "\$LOG_FILE" 2>&1 &
PID=\$!
echo \$PID > "\$PID_FILE"
echo "Started with PID: \$PID"

# Wait and test
sleep 5
if kill -0 \$PID 2>/dev/null; then
    echo "Process is running"
    if curl -s -f "http://127.0.0.1:$TARGET_PORT/healthz" >/dev/null 2>&1; then
        echo "✓ Code-server is working!"
        echo "Access: http://$TARGET_BIND_ADDR"
        echo "Password: \$(grep password: \$CONFIG_FILE | cut -d' ' -f2)"
        
        # Start ngrok tunnel if available
        if command -v ngrok >/dev/null; then
            echo "Starting ngrok tunnel..."
            pkill -f "ngrok" 2>/dev/null || true
            sleep 1
            ngrok http $TARGET_PORT >/dev/null 2>&1 &
            sleep 3
            
            # Get tunnel URL
            tunnel_json=\$(curl -s http://127.0.0.1:4040/api/tunnels 2>/dev/null || echo "")
            if [[ -n "\$tunnel_json" && "\$tunnel_json" != "null" ]]; then
                if command -v jq >/dev/null; then
                    public_url=\$(echo "\$tunnel_json" | jq -r '.tunnels[0].public_url' 2>/dev/null || echo "")
                else
                    public_url=\$(echo "\$tunnel_json" | grep -o '"public_url":"[^"]*' | head -1 | cut -d'"' -f4 || echo "")
                fi
                
                if [[ -n "\$public_url" && "\$public_url" != "null" ]]; then
                    echo "✓ Ngrok tunnel: \$public_url"
                    echo "\$public_url" > "\$HOME/.ngrok_url"
                fi
            fi
        fi
    else
        echo "✗ Process running but not responding"
        tail -10 "\$LOG_FILE"
    fi
else
    echo "✗ Process failed to start"
    cat "\$LOG_FILE"
fi
EOF
    
    chmod +x ~/.local/bin/code-server-fixed-start
    log_success "Fixed startup script created: ~/.local/bin/code-server-fixed-start"
}

# Main execution
main() {
    log_info "🔧 Code-Server Configuration and Port Fix"
    
    case "${1:-fix}" in
        "fix")
            cleanup_processes_and_ports
            fix_configuration
            if test_startup; then
                log_success "✓ Configuration and startup test successful!"
            else
                log_warn "Startup test failed, but configuration is fixed"
            fi
            create_fixed_startup
            log_success "🎉 Fix completed! Use: ~/.local/bin/code-server-fixed-start"
            ;;
        "test")
            test_startup
            ;;
        "clean")
            cleanup_processes_and_ports
            ;;
        "config")
            fix_configuration
            ;;
        *)
            echo "Usage: $0 {fix|test|clean|config}"
            echo ""
            echo "Commands:"
            echo "  fix     Complete fix (cleanup + config + test + create startup script)"
            echo "  test    Test code-server startup"
            echo "  clean   Clean up processes and ports"
            echo "  config  Fix configuration file only"
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
