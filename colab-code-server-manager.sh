#!/usr/bin/env bash
# =============================================================================
# Google Colab Code-Server Manager
# Management script for code-server in Google Colab environment
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
# CONFIGURATION
# -------------------------------------------------------------------------
PID_FILE="$HOME/.local/share/code-server/code-server.pid"
LOG_FILE="$HOME/.local/share/code-server/logs/server.log"
CONFIG_FILE="$HOME/.config/code-server/config.yaml"

# -------------------------------------------------------------------------
# UTILITY FUNCTIONS
# -------------------------------------------------------------------------
show_help() {
    echo "Google Colab Code-Server Manager"
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  start     Start code-server"
    echo "  stop      Stop code-server"
    echo "  restart   Restart code-server"
    echo "  status    Show status"
    echo "  logs      Show logs"
    echo "  url       Show access URL and password"
    echo "  tunnel    Setup ngrok tunnel"
    echo "  help      Show this help"
    echo ""
}

# -------------------------------------------------------------------------
# STATUS FUNCTIONS
# -------------------------------------------------------------------------
check_status() {
    if [[ -f "$PID_FILE" ]]; then
        local pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            echo "✅ Code-server is running (PID: $pid)"
            
            # Check if responding
            local port=$(grep "bind-addr:" "$CONFIG_FILE" 2>/dev/null | cut -d: -f3 | tr -d ' ' || echo "8888")
            if curl -s -f "http://127.0.0.1:$port/healthz" >/dev/null 2>&1; then
                echo "✅ Server is responding on port $port"
            else
                echo "⚠️  Server not responding on port $port"
            fi
            return 0
        else
            echo "❌ Code-server is not running (stale PID file)"
            rm -f "$PID_FILE"
            return 1
        fi
    else
        echo "❌ Code-server is not running"
        return 1
    fi
}

# -------------------------------------------------------------------------
# CONTROL FUNCTIONS
# -------------------------------------------------------------------------
start_server() {
    if check_status >/dev/null 2>&1; then
        log_warn "Code-server is already running"
        return 0
    fi

    log_info "Starting code-server..."
    
    # Ensure directories exist
    mkdir -p ~/.local/share/code-server/logs
    
    # Start code-server
    nohup "$(command -v code-server)" --config "$CONFIG_FILE" \
        >"$LOG_FILE" 2>&1 &
    
    echo $! > "$PID_FILE"
    
    # Wait for startup
    sleep 3
    
    if check_status >/dev/null 2>&1; then
        log_success "Code-server started successfully"
        show_access_info
    else
        log_error "Failed to start code-server"
        return 1
    fi
}

stop_server() {
    if [[ -f "$PID_FILE" ]]; then
        local pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            log_info "Stopping code-server (PID: $pid)..."
            kill "$pid"
            rm -f "$PID_FILE"
            log_success "Code-server stopped"
        else
            log_warn "Code-server was not running"
            rm -f "$PID_FILE"
        fi
    else
        # Fallback: kill by process name
        if pkill -f "code-server" 2>/dev/null; then
            log_success "Code-server processes killed"
        else
            log_warn "No code-server processes found"
        fi
    fi
}

restart_server() {
    log_info "Restarting code-server..."
    stop_server
    sleep 2
    start_server
}

# -------------------------------------------------------------------------
# INFO FUNCTIONS
# -------------------------------------------------------------------------
show_access_info() {
    if [[ -f "$CONFIG_FILE" ]]; then
        local bind_addr=$(grep "bind-addr:" "$CONFIG_FILE" | cut -d: -f2- | tr -d ' ')
        local password=$(grep "password:" "$CONFIG_FILE" | cut -d: -f2 | tr -d ' ')
        
        echo ""
        echo "=== ACCESS INFORMATION ==="
        echo "URL: http://$bind_addr"
        echo "Password: $password"
        echo ""
        
        # Show tunnel info if available
        if pgrep -f "ngrok" >/dev/null 2>&1; then
            echo "=== NGROK TUNNEL ==="
            curl -s http://localhost:4040/api/tunnels | jq -r '.tunnels[0].public_url' 2>/dev/null || echo "Ngrok tunnel active (check http://localhost:4040)"
            echo ""
        fi
    else
        log_error "Configuration file not found"
    fi
}

show_logs() {
    if [[ -f "$LOG_FILE" ]]; then
        echo "=== CODE-SERVER LOGS ==="
        tail -n 50 "$LOG_FILE"
    else
        log_error "Log file not found"
    fi
}

# -------------------------------------------------------------------------
# TUNNEL FUNCTIONS
# -------------------------------------------------------------------------
setup_tunnel() {
    log_info "Setting up ngrok tunnel..."
    
    # Check if ngrok is installed
    if ! command -v ngrok >/dev/null; then
        log_info "Installing ngrok..."
        curl -s https://ngrok-agent.s3.amazonaws.com/ngrok.asc | sudo tee /etc/apt/trusted.gpg.d/ngrok.asc >/dev/null
        echo "deb https://ngrok-agent.s3.amazonaws.com buster main" | sudo tee /etc/apt/sources.list.d/ngrok.list
        sudo apt update && sudo apt install ngrok
    fi
    
    # Get port from config
    local port=$(grep "bind-addr:" "$CONFIG_FILE" 2>/dev/null | cut -d: -f3 | tr -d ' ' || echo "8888")
    
    # Start ngrok tunnel
    log_info "Starting ngrok tunnel on port $port..."
    nohup ngrok http "$port" >/dev/null 2>&1 &
    
    sleep 3
    
    # Show tunnel URL
    local tunnel_url=$(curl -s http://localhost:4040/api/tunnels | jq -r '.tunnels[0].public_url' 2>/dev/null)
    if [[ -n "$tunnel_url" && "$tunnel_url" != "null" ]]; then
        log_success "Ngrok tunnel created: $tunnel_url"
        echo ""
        echo "=== REMOTE ACCESS ==="
        echo "URL: $tunnel_url"
        echo "Password: $(grep "password:" "$CONFIG_FILE" | cut -d: -f2 | tr -d ' ')"
        echo ""
    else
        log_error "Failed to create ngrok tunnel"
    fi
}

# -------------------------------------------------------------------------
# MAIN COMMAND HANDLING
# -------------------------------------------------------------------------
case "${1:-help}" in
    "start")
        start_server
        ;;
    "stop")
        stop_server
        ;;
    "restart")
        restart_server
        ;;
    "status")
        check_status
        ;;
    "logs")
        show_logs
        ;;
    "url"|"info")
        show_access_info
        ;;
    "tunnel")
        setup_tunnel
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
