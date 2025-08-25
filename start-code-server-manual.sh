#!/usr/bin/env bash
# Manual Code-Server Startup Script for Google Colab
# Use this when PM2 fails to start code-server properly

set -euo pipefail

# Container-optimized environment settings
export DEBIAN_FRONTEND=noninteractive
export APT_LISTCHANGES_FRONTEND=none

# Colors and logging
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

# Configuration
BIND_ADDR="0.0.0.0:8888"
CONFIG_FILE="$HOME/.config/code-server/config.yaml"
LOG_FILE="$HOME/.local/share/code-server/logs/server.log"
PID_FILE="$HOME/.local/share/code-server/code-server.pid"

# Container detection
detect_container() {
    if [[ -f /.dockerenv ]] || [[ -n "${CONTAINER:-}" ]] || [[ "$(hostname)" =~ ^[0-9a-f]{12}$ ]]; then
        return 0  # is container
    else
        return 1  # not container
    fi
}

# Kill existing code-server processes
kill_existing_processes() {
    log_info "Checking for existing code-server processes..."
    
    if pgrep -f "code-server" >/dev/null; then
        log_warn "Found existing code-server processes, terminating..."
        pkill -f "code-server" 2>/dev/null || true
        sleep 2
        
        # Force kill if still running
        if pgrep -f "code-server" >/dev/null; then
            log_warn "Force killing remaining processes..."
            pkill -9 -f "code-server" 2>/dev/null || true
            sleep 1
        fi
        
        log_success "Existing processes terminated"
    else
        log_info "No existing code-server processes found"
    fi
}

# Check port availability
check_port() {
    local port="${BIND_ADDR##*:}"
    log_info "Checking port $port availability..."
    
    if command -v netstat >/dev/null; then
        if netstat -tlnp 2>/dev/null | grep -q ":$port "; then
            log_warn "Port $port is in use"
            return 1
        fi
    elif command -v ss >/dev/null; then
        if ss -tlnp 2>/dev/null | grep -q ":$port "; then
            log_warn "Port $port is in use"
            return 1
        fi
    fi
    
    log_success "Port $port is available"
    return 0
}

# Start code-server manually
start_code_server() {
    log_info "Starting code-server manually..."
    
    # Ensure directories exist
    mkdir -p ~/.local/share/code-server/logs
    mkdir -p ~/.config/code-server
    
    # Check if config exists
    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_error "Configuration file not found: $CONFIG_FILE"
        log_info "Please run the main setup script first"
        return 1
    fi
    
    # Check if code-server binary exists
    if ! command -v code-server >/dev/null; then
        log_error "code-server binary not found in PATH"
        log_info "Please install code-server first"
        return 1
    fi
    
    log_info "Code-server version: $(code-server --version | head -1)"
    log_info "Configuration file: $CONFIG_FILE"
    log_info "Log file: $LOG_FILE"
    log_info "Bind address: $BIND_ADDR"
    
    # Start code-server in background
    log_info "Starting code-server..."
    nohup code-server --config "$CONFIG_FILE" > "$LOG_FILE" 2>&1 &
    local pid=$!
    
    # Save PID
    echo $pid > "$PID_FILE"
    log_info "Code-server started with PID: $pid"
    
    # Wait a moment for startup
    sleep 3
    
    # Check if process is still running
    if kill -0 $pid 2>/dev/null; then
        log_success "Code-server is running (PID: $pid)"
        return 0
    else
        log_error "Code-server failed to start"
        log_info "Check log file: $LOG_FILE"
        if [[ -f "$LOG_FILE" ]]; then
            log_info "Last few lines of log:"
            tail -10 "$LOG_FILE"
        fi
        return 1
    fi
}

# Test code-server connectivity
test_connectivity() {
    local port="${BIND_ADDR##*:}"
    log_info "Testing code-server connectivity..."
    
    for i in {1..10}; do
        if curl -s -f "http://127.0.0.1:$port/healthz" >/dev/null 2>&1; then
            log_success "Code-server is responding on port $port"
            return 0
        fi
        log_info "Attempt $i/10: Waiting for code-server to respond..."
        sleep 2
    done
    
    log_error "Code-server is not responding on port $port"
    return 1
}

# Start ngrok tunnel
start_tunnel() {
    log_info "Starting ngrok tunnel..."
    
    if ! command -v ngrok >/dev/null; then
        log_warn "ngrok not found, skipping tunnel setup"
        return 1
    fi
    
    local port="${BIND_ADDR##*:}"
    
    # Kill existing ngrok processes
    pkill -f "ngrok" 2>/dev/null || true
    sleep 1
    
    # Start ngrok
    ngrok http "$port" >/dev/null 2>&1 &
    sleep 3
    
    # Get tunnel URL
    local tunnel_json=$(curl -s http://127.0.0.1:4040/api/tunnels 2>/dev/null || echo "")
    if [[ -n "$tunnel_json" && "$tunnel_json" != "null" ]]; then
        if command -v jq >/dev/null; then
            local public_url=$(echo "$tunnel_json" | jq -r '.tunnels[0].public_url' 2>/dev/null || echo "")
        else
            local public_url=$(echo "$tunnel_json" | grep -o '"public_url":"[^"]*' | head -1 | cut -d'"' -f4 || echo "")
        fi
        
        if [[ -n "$public_url" && "$public_url" != "null" ]]; then
            log_success "Ngrok tunnel active: $public_url"
            echo "$public_url" > "$HOME/.ngrok_url"
            return 0
        fi
    fi
    
    log_warn "Failed to get ngrok tunnel URL"
    return 1
}

# Show status
show_status() {
    log_info "Code-server status:"
    
    # Check process
    if [[ -f "$PID_FILE" ]]; then
        local pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            log_success "Process running (PID: $pid)"
        else
            log_error "Process not running (stale PID file)"
        fi
    else
        log_warn "No PID file found"
    fi
    
    # Check port
    local port="${BIND_ADDR##*:}"
    if curl -s -f "http://127.0.0.1:$port/healthz" >/dev/null 2>&1; then
        log_success "HTTP service responding on port $port"
        log_info "Local access: http://127.0.0.1:$port"
    else
        log_error "HTTP service not responding on port $port"
    fi
    
    # Check tunnel
    if [[ -f "$HOME/.ngrok_url" ]]; then
        local tunnel_url=$(cat "$HOME/.ngrok_url")
        log_info "Tunnel URL: $tunnel_url"
    else
        log_warn "No tunnel URL found"
    fi
}

# Main execution
main() {
    log_info "Manual Code-Server Startup for Google Colab"
    
    if detect_container; then
        log_info "Container environment detected"
    fi
    
    case "${1:-start}" in
        "start")
            kill_existing_processes
            if check_port; then
                if start_code_server; then
                    if test_connectivity; then
                        start_tunnel || log_warn "Tunnel setup failed, but code-server is running"
                        show_status
                        log_success "Code-server startup completed!"
                    else
                        log_error "Code-server started but not responding"
                        exit 1
                    fi
                else
                    log_error "Failed to start code-server"
                    exit 1
                fi
            else
                log_error "Port not available"
                exit 1
            fi
            ;;
        "stop")
            log_info "Stopping code-server..."
            pkill -f "code-server" 2>/dev/null || true
            pkill -f "ngrok" 2>/dev/null || true
            rm -f "$PID_FILE" "$HOME/.ngrok_url"
            log_success "Code-server stopped"
            ;;
        "status")
            show_status
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
}

# Run main function
main "$@"
