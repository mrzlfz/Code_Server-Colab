#!/usr/bin/env bash
# Fix PM2 Configuration for Code-Server

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
LOG_DIR="$HOME/.local/share/code-server/logs"

fix_pm2_config() {
    log_info "Fixing PM2 configuration..."
    
    # Stop existing PM2 processes
    log_info "Stopping existing PM2 processes..."
    pm2 delete code-server 2>/dev/null || true
    pm2 kill 2>/dev/null || true
    
    # Verify code-server binary
    local code_server_path=$(command -v code-server 2>/dev/null || echo "")
    if [[ -z "$code_server_path" || ! -x "$code_server_path" ]]; then
        log_error "Code-server binary not found or not executable"
        log_info "Please install code-server first"
        return 1
    fi
    
    log_success "Code-server binary found: $code_server_path"
    log_info "Version: $(code-server --version | head -1)"
    
    # Verify config file
    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_error "Config file not found: $CONFIG_FILE"
        log_info "Creating basic config file..."
        
        mkdir -p "$(dirname "$CONFIG_FILE")"
        cat > "$CONFIG_FILE" <<EOF
bind-addr: 0.0.0.0:8888
auth: password
password: $(openssl rand -base64 32 | tr -d '=+/' | cut -c1-25)
cert: false
disable-telemetry: true
disable-update-check: true
disable-workspace-trust: true
log: info
EOF
        log_success "Basic config file created"
    fi
    
    # Create log directory
    mkdir -p "$LOG_DIR"
    
    # Test code-server directly first
    log_info "Testing code-server binary..."
    if timeout 5 code-server --help >/dev/null 2>&1; then
        log_success "Code-server binary is working"
    else
        log_error "Code-server binary test failed"
        return 1
    fi
    
    # Create fixed ecosystem configuration
    log_info "Creating fixed PM2 ecosystem configuration..."
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
      USER: process.env.USER || 'root'
    },
    error_file: '$LOG_DIR/pm2-error.log',
    out_file: '$LOG_DIR/pm2-out.log',
    log_file: '$LOG_DIR/pm2-combined.log',
    time: true,
    max_restarts: 5,
    min_uptime: '10s',
    kill_timeout: 5000,
    listen_timeout: 15000,
    wait_ready: true,
    ready_timeout: 20000
  }]
};
EOF
    
    log_success "PM2 ecosystem configuration created"
    
    # Start PM2 with new configuration
    log_info "Starting code-server with PM2..."
    if pm2 start "$ECOSYSTEM_FILE"; then
        log_success "PM2 started successfully"
        
        # Wait for startup
        log_info "Waiting for code-server to start..."
        sleep 5
        
        # Check PM2 status
        log_info "PM2 status:"
        pm2 status code-server
        
        # Test connectivity
        log_info "Testing HTTP connectivity..."
        local port="8888"
        local success=false
        
        for i in {1..10}; do
            if curl -s -f "http://127.0.0.1:$port/healthz" >/dev/null 2>&1; then
                log_success "Code-server is responding on port $port"
                success=true
                break
            fi
            log_info "Attempt $i/10: Waiting for response..."
            sleep 2
        done
        
        if [[ "$success" == "true" ]]; then
            log_success "PM2 configuration fixed successfully!"
            
            # Save PM2 configuration
            pm2 save
            
            # Show access information
            log_info "Code-server is now accessible at:"
            log_info "  Local: http://127.0.0.1:$port"
            
            # Show password
            local password=$(grep "password:" "$CONFIG_FILE" | cut -d' ' -f2)
            log_info "  Password: $password"
            
            return 0
        else
            log_error "Code-server is not responding"
            log_info "Checking PM2 logs..."
            pm2 logs code-server --lines 20
            return 1
        fi
    else
        log_error "Failed to start PM2"
        return 1
    fi
}

# Test code-server directly (fallback method)
test_direct_startup() {
    log_info "Testing direct code-server startup..."
    
    # Kill any existing processes
    pkill -f "code-server" 2>/dev/null || true
    sleep 2
    
    # Start code-server directly in background
    log_info "Starting code-server directly..."
    nohup code-server --config "$CONFIG_FILE" > "$LOG_DIR/direct-startup.log" 2>&1 &
    local pid=$!
    
    log_info "Code-server started with PID: $pid"
    
    # Wait and test
    sleep 5
    
    if kill -0 $pid 2>/dev/null; then
        log_success "Direct startup successful"
        
        # Test connectivity
        if curl -s -f "http://127.0.0.1:8888/healthz" >/dev/null 2>&1; then
            log_success "Code-server is responding"
            log_info "Use './start-code-server-manual.sh' for better process management"
            return 0
        else
            log_warn "Process running but not responding to HTTP"
            return 1
        fi
    else
        log_error "Direct startup failed"
        log_info "Check log: $LOG_DIR/direct-startup.log"
        return 1
    fi
}

# Main execution
main() {
    log_info "PM2 Configuration Fix for Code-Server"
    
    # Check if PM2 is available
    if ! command -v pm2 >/dev/null; then
        log_error "PM2 not found"
        log_info "Installing PM2..."
        npm install -g pm2 || {
            log_error "Failed to install PM2"
            exit 1
        }
    fi
    
    case "${1:-fix}" in
        "fix")
            if fix_pm2_config; then
                log_success "PM2 configuration fixed successfully!"
            else
                log_warn "PM2 fix failed, trying direct startup..."
                test_direct_startup
            fi
            ;;
        "test")
            test_direct_startup
            ;;
        "logs")
            log_info "PM2 logs:"
            pm2 logs code-server --lines 50
            ;;
        "status")
            log_info "PM2 status:"
            pm2 status
            log_info "Process list:"
            ps aux | grep '[c]ode-server' || echo "No code-server processes found"
            ;;
        *)
            echo "Usage: $0 {fix|test|logs|status}"
            echo ""
            echo "Commands:"
            echo "  fix     Fix PM2 configuration and restart"
            echo "  test    Test direct startup (bypass PM2)"
            echo "  logs    Show PM2 logs"
            echo "  status  Show PM2 and process status"
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
