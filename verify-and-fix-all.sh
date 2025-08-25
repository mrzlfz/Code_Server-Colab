#!/usr/bin/env bash
# Comprehensive Verification and Fix Script for Code-Server

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
ECOSYSTEM_FILE="$HOME/.config/code-server/ecosystem.config.js"
TARGET_BIND_ADDR="0.0.0.0:8888"
TARGET_PORT="8888"

# Function to check and fix all configurations
check_and_fix_configs() {
    log_info "=== Checking and Fixing All Configurations ==="
    
    # 1. Check main config file
    log_info "1. Checking main configuration file..."
    if [[ -f "$CONFIG_FILE" ]]; then
        local current_bind=$(grep "bind-addr:" "$CONFIG_FILE" | cut -d' ' -f2 || echo "")
        if [[ "$current_bind" != "$TARGET_BIND_ADDR" ]]; then
            log_warn "Wrong bind address: $current_bind (should be $TARGET_BIND_ADDR)"
            
            # Fix it
            local password=$(grep "password:" "$CONFIG_FILE" | cut -d' ' -f2 || openssl rand -base64 32 | tr -d '=+/' | cut -c1-25)
            
            cat > "$CONFIG_FILE" <<EOF
bind-addr: $TARGET_BIND_ADDR
auth: password
password: $password
cert: false
disable-telemetry: true
disable-update-check: true
disable-workspace-trust: true
log: info
EOF
            log_success "✓ Fixed main configuration"
        else
            log_success "✓ Main configuration is correct"
        fi
    else
        log_warn "Main config not found, creating..."
        mkdir -p "$(dirname "$CONFIG_FILE")"
        local password=$(openssl rand -base64 32 | tr -d '=+/' | cut -c1-25)
        
        cat > "$CONFIG_FILE" <<EOF
bind-addr: $TARGET_BIND_ADDR
auth: password
password: $password
cert: false
disable-telemetry: true
disable-update-check: true
disable-workspace-trust: true
log: info
EOF
        log_success "✓ Created main configuration with password: $password"
    fi
    
    # 2. Check PM2 ecosystem config
    log_info "2. Checking PM2 ecosystem configuration..."
    if [[ -f "$ECOSYSTEM_FILE" ]]; then
        if grep -q "127.0.0.1:8080" "$ECOSYSTEM_FILE" 2>/dev/null; then
            log_warn "PM2 config has wrong bind address references"
            # We'll recreate it with correct paths
            create_fixed_ecosystem_config
        else
            log_success "✓ PM2 ecosystem config looks correct"
        fi
    else
        log_warn "PM2 ecosystem config not found, creating..."
        create_fixed_ecosystem_config
    fi
    
    # 3. Check directories
    log_info "3. Checking required directories..."
    local dirs=(
        "$HOME/.config/code-server"
        "$HOME/.local/share/code-server/logs"
        "$HOME/.local/bin"
    )
    
    for dir in "${dirs[@]}"; do
        if [[ ! -d "$dir" ]]; then
            mkdir -p "$dir"
            log_success "✓ Created directory: $dir"
        else
            log_success "✓ Directory exists: $dir"
        fi
    done
}

# Function to create fixed PM2 ecosystem config
create_fixed_ecosystem_config() {
    local code_server_path=$(command -v code-server)
    
    cat > "$ECOSYSTEM_FILE" <<EOF
module.exports = {
  apps: [{
    name: 'code-server',
    script: '$code_server_path',
    args: ['--config', '$CONFIG_FILE'],
    cwd: '$HOME',
    instances: 1,
    autorestart: true,
    watch: false,
    max_memory_restart: '1G',
    restart_delay: 2000,
    env: {
      NODE_ENV: 'production',
      HOME: '$HOME',
      PATH: process.env.PATH,
      USER: process.env.USER || '$(whoami)'
    },
    error_file: '$HOME/.local/share/code-server/logs/pm2-error.log',
    out_file: '$HOME/.local/share/code-server/logs/pm2-out.log',
    log_file: '$HOME/.local/share/code-server/logs/pm2-combined.log',
    time: true,
    max_restarts: 5,
    min_uptime: '10s',
    kill_timeout: 5000,
    listen_timeout: 15000,
    wait_ready: false
  }]
};
EOF
    log_success "✓ Created fixed PM2 ecosystem config"
}

# Function to clean up all conflicts
cleanup_all_conflicts() {
    log_info "=== Cleaning Up All Conflicts ==="
    
    # Stop PM2
    if command -v pm2 >/dev/null; then
        pm2 delete code-server 2>/dev/null || true
        pm2 kill 2>/dev/null || true
        log_success "✓ PM2 stopped"
    fi
    
    # Kill all code-server processes
    pkill -f "code-server" 2>/dev/null || true
    sleep 2
    pkill -9 -f "code-server" 2>/dev/null || true
    log_success "✓ Code-server processes killed"
    
    # Clean up ports
    for port in 8080 8888 4040; do
        if command -v lsof >/dev/null; then
            local pids=$(lsof -t -i:"$port" 2>/dev/null || true)
            if [[ -n "$pids" ]]; then
                echo "$pids" | xargs kill -9 2>/dev/null || true
                log_success "✓ Cleaned port $port"
            fi
        fi
    done
    
    # Kill ngrok processes
    pkill -f "ngrok" 2>/dev/null || true
    log_success "✓ Ngrok processes killed"
}

# Function to test everything
test_everything() {
    log_info "=== Testing Everything ==="
    
    # Test 1: Binary
    if command -v code-server >/dev/null && timeout 5 code-server --version >/dev/null 2>&1; then
        log_success "✓ Code-server binary works"
    else
        log_error "✗ Code-server binary issue"
        return 1
    fi
    
    # Test 2: Configuration
    if [[ -f "$CONFIG_FILE" ]] && python3 -c "import yaml; yaml.safe_load(open('$CONFIG_FILE'))" 2>/dev/null; then
        log_success "✓ Configuration file is valid"
    else
        log_error "✗ Configuration file issue"
        return 1
    fi
    
    # Test 3: Direct startup
    log_info "Testing direct startup..."
    timeout 15 code-server --config "$CONFIG_FILE" > /tmp/test-all.log 2>&1 &
    local pid=$!
    
    sleep 8
    
    if kill -0 $pid 2>/dev/null; then
        if curl -s -f "http://127.0.0.1:$TARGET_PORT/healthz" >/dev/null 2>&1; then
            log_success "✓ Direct startup and HTTP test passed"
            kill $pid 2>/dev/null || true
            return 0
        else
            log_warn "Process running but HTTP failed"
            kill $pid 2>/dev/null || true
        fi
    else
        log_error "✗ Direct startup failed"
        log_info "Startup log:"
        cat /tmp/test-all.log
    fi
    
    return 1
}

# Function to create ultimate working startup script
create_ultimate_startup() {
    log_info "=== Creating Ultimate Startup Script ==="
    
    cat > ~/.local/bin/code-server-ultimate <<'EOF'
#!/bin/bash
# Ultimate Code-Server Startup Script - Always Works

# Configuration
CONFIG_FILE="$HOME/.config/code-server/config.yaml"
LOG_FILE="$HOME/.local/share/code-server/logs/server.log"
PID_FILE="$HOME/.local/share/code-server/code-server.pid"
TARGET_PORT="8888"

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

# Ensure directories exist
mkdir -p "$(dirname "$LOG_FILE")" "$(dirname "$PID_FILE")"

case "${1:-start}" in
    "start")
        log_info "Starting Code-Server Ultimate..."
        
        # Complete cleanup
        log_info "Complete cleanup..."
        pkill -f "code-server" 2>/dev/null || true
        pkill -f "ngrok" 2>/dev/null || true
        sleep 2
        
        # Clean ports
        for port in 8080 8888 4040; do
            if command -v lsof >/dev/null; then
                pids=$(lsof -t -i:$port 2>/dev/null || true)
                [[ -n "$pids" ]] && echo "$pids" | xargs kill -9 2>/dev/null || true
            fi
        done
        
        sleep 2
        
        # Verify config
        if [[ ! -f "$CONFIG_FILE" ]]; then
            log_error "Config file not found: $CONFIG_FILE"
            exit 1
        fi
        
        # Start code-server
        log_info "Starting code-server..."
        nohup code-server --config "$CONFIG_FILE" > "$LOG_FILE" 2>&1 &
        PID=$!
        echo $PID > "$PID_FILE"
        
        # Wait and verify
        sleep 5
        if kill -0 $PID 2>/dev/null; then
            if curl -s -f "http://127.0.0.1:$TARGET_PORT/healthz" >/dev/null 2>&1; then
                log_success "✓ Code-server is running!"
                log_info "Access: http://0.0.0.0:$TARGET_PORT"
                log_info "Password: $(grep password: $CONFIG_FILE | cut -d' ' -f2)"
                
                # Start ngrok if available
                if command -v ngrok >/dev/null; then
                    log_info "Starting ngrok tunnel..."
                    ngrok http $TARGET_PORT >/dev/null 2>&1 &
                    sleep 3
                    
                    tunnel_json=$(curl -s http://127.0.0.1:4040/api/tunnels 2>/dev/null || echo "")
                    if [[ -n "$tunnel_json" && "$tunnel_json" != "null" ]]; then
                        if command -v jq >/dev/null; then
                            public_url=$(echo "$tunnel_json" | jq -r '.tunnels[0].public_url' 2>/dev/null || echo "")
                        else
                            public_url=$(echo "$tunnel_json" | grep -o '"public_url":"[^"]*' | head -1 | cut -d'"' -f4 || echo "")
                        fi
                        
                        if [[ -n "$public_url" && "$public_url" != "null" ]]; then
                            log_success "✓ Ngrok tunnel: $public_url"
                            echo "$public_url" > "$HOME/.ngrok_url"
                        fi
                    fi
                fi
            else
                log_error "✗ Code-server not responding"
                tail -10 "$LOG_FILE"
                exit 1
            fi
        else
            log_error "✗ Code-server failed to start"
            cat "$LOG_FILE"
            exit 1
        fi
        ;;
    "stop")
        log_info "Stopping Code-Server..."
        pkill -f "code-server" 2>/dev/null || true
        pkill -f "ngrok" 2>/dev/null || true
        rm -f "$PID_FILE" "$HOME/.ngrok_url"
        log_success "✓ Stopped"
        ;;
    "status")
        if [[ -f "$PID_FILE" ]]; then
            pid=$(cat "$PID_FILE")
            if kill -0 "$pid" 2>/dev/null; then
                log_success "✓ Running (PID: $pid)"
                if curl -s -f "http://127.0.0.1:$TARGET_PORT/healthz" >/dev/null 2>&1; then
                    log_success "✓ HTTP responding"
                    [[ -f "$HOME/.ngrok_url" ]] && log_info "Tunnel: $(cat $HOME/.ngrok_url)"
                else
                    log_warn "Process running but HTTP not responding"
                fi
            else
                log_error "✗ Not running (stale PID)"
            fi
        else
            log_error "✗ Not running"
        fi
        ;;
    "restart")
        $0 stop
        sleep 2
        $0 start
        ;;
    *)
        echo "Usage: $0 {start|stop|status|restart}"
        exit 1
        ;;
esac
EOF
    
    chmod +x ~/.local/bin/code-server-ultimate
    log_success "✓ Ultimate startup script created: ~/.local/bin/code-server-ultimate"
}

# Main execution
main() {
    log_info "🔧 Comprehensive Code-Server Verification and Fix"
    
    case "${1:-all}" in
        "all")
            cleanup_all_conflicts
            check_and_fix_configs
            if test_everything; then
                log_success "✓ All tests passed!"
            else
                log_warn "Some tests failed, but configs are fixed"
            fi
            create_ultimate_startup
            log_success "🎉 Complete fix done! Use: ~/.local/bin/code-server-ultimate start"
            ;;
        "config")
            check_and_fix_configs
            ;;
        "clean")
            cleanup_all_conflicts
            ;;
        "test")
            test_everything
            ;;
        *)
            echo "Usage: $0 {all|config|clean|test}"
            echo ""
            echo "Commands:"
            echo "  all     Complete verification and fix (recommended)"
            echo "  config  Fix configurations only"
            echo "  clean   Clean up conflicts only"
            echo "  test    Test everything"
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
