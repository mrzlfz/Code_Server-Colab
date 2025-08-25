#!/usr/bin/env bash
# Debug script for Code-Server issues

set -euo pipefail

# Colors and logging
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

echo "=== Code-Server Debug Information ==="
echo "Date: $(date)"
echo "User: $(whoami)"
echo "Home: $HOME"
echo "PWD: $(pwd)"

# Container detection
echo ""
echo "=== Environment Detection ==="
if [[ -f /.dockerenv ]]; then
    echo "✓ Container: Docker (/.dockerenv exists)"
elif [[ -n "${CONTAINER:-}" ]]; then
    echo "✓ Container: Environment variable set (CONTAINER=$CONTAINER)"
elif [[ "$(hostname)" =~ ^[0-9a-f]{12}$ ]]; then
    echo "✓ Container: Container-like hostname ($(hostname))"
else
    echo "✗ Container: Not detected"
fi

echo "Hostname: $(hostname)"
echo "OS: $(uname -a)"

# System resources
echo ""
echo "=== System Resources ==="
if command -v free >/dev/null; then
    echo "Memory:"
    free -h
else
    echo "Memory: free command not available"
fi

if command -v df >/dev/null; then
    echo "Disk usage:"
    df -h "$HOME" 2>/dev/null || echo "Cannot check disk usage"
else
    echo "Disk: df command not available"
fi

# Code-server installation
echo ""
echo "=== Code-Server Installation ==="
if command -v code-server >/dev/null; then
    echo "✓ Code-server binary found"
    echo "Version: $(code-server --version | head -1)"
    echo "Location: $(which code-server)"
else
    echo "✗ Code-server binary not found"
fi

# Node.js installation
echo ""
echo "=== Node.js Installation ==="
if command -v node >/dev/null; then
    echo "✓ Node.js found: $(node --version)"
    echo "Location: $(which node)"
else
    echo "✗ Node.js not found"
fi

if command -v npm >/dev/null; then
    echo "✓ npm found: $(npm --version)"
    echo "Location: $(which npm)"
else
    echo "✗ npm not found"
fi

# PM2 status
echo ""
echo "=== PM2 Status ==="
if command -v pm2 >/dev/null; then
    echo "✓ PM2 found: $(pm2 --version)"
    echo "Location: $(which pm2)"
    echo ""
    echo "PM2 processes:"
    pm2 list 2>/dev/null || echo "PM2 list failed"
    echo ""
    echo "PM2 logs (last 20 lines):"
    pm2 logs code-server --lines 20 2>/dev/null || echo "No PM2 logs for code-server"
else
    echo "✗ PM2 not found"
fi

# Configuration files
echo ""
echo "=== Configuration Files ==="
CONFIG_FILE="$HOME/.config/code-server/config.yaml"
if [[ -f "$CONFIG_FILE" ]]; then
    echo "✓ Config file exists: $CONFIG_FILE"
    echo "Content:"
    cat "$CONFIG_FILE"
else
    echo "✗ Config file not found: $CONFIG_FILE"
fi

ECOSYSTEM_FILE="$HOME/.config/code-server/ecosystem.config.js"
if [[ -f "$ECOSYSTEM_FILE" ]]; then
    echo "✓ PM2 ecosystem file exists: $ECOSYSTEM_FILE"
    echo "Content:"
    cat "$ECOSYSTEM_FILE"
else
    echo "✗ PM2 ecosystem file not found: $ECOSYSTEM_FILE"
fi

# Process information
echo ""
echo "=== Process Information ==="
echo "Code-server processes:"
ps aux | grep '[c]ode-server' || echo "No code-server processes found"

echo ""
echo "PM2 processes:"
ps aux | grep '[P]M2' || echo "No PM2 processes found"

echo ""
echo "Node processes:"
ps aux | grep '[n]ode' || echo "No node processes found"

# Port usage
echo ""
echo "=== Port Usage ==="
PORTS="8080 8888 4040"
for port in $PORTS; do
    echo "Port $port:"
    if command -v netstat >/dev/null; then
        netstat -tlnp 2>/dev/null | grep ":$port " || echo "  Not in use"
    elif command -v ss >/dev/null; then
        ss -tlnp 2>/dev/null | grep ":$port " || echo "  Not in use"
    else
        echo "  Cannot check (no netstat/ss)"
    fi
done

# Log files
echo ""
echo "=== Log Files ==="
LOG_DIR="$HOME/.local/share/code-server/logs"
if [[ -d "$LOG_DIR" ]]; then
    echo "✓ Log directory exists: $LOG_DIR"
    echo "Log files:"
    ls -la "$LOG_DIR" 2>/dev/null || echo "Cannot list log files"
    
    # Show recent logs
    for logfile in server.log pm2-error.log pm2-out.log pm2-combined.log; do
        if [[ -f "$LOG_DIR/$logfile" ]]; then
            echo ""
            echo "=== $logfile (last 10 lines) ==="
            tail -10 "$LOG_DIR/$logfile"
        fi
    done
else
    echo "✗ Log directory not found: $LOG_DIR"
fi

# Network connectivity
echo ""
echo "=== Network Connectivity ==="
echo "Testing local connectivity:"
for port in 8080 8888; do
    if curl -s -f "http://127.0.0.1:$port/healthz" >/dev/null 2>&1; then
        echo "✓ Port $port: Responding"
    else
        echo "✗ Port $port: Not responding"
    fi
done

echo ""
echo "Testing external connectivity:"
if curl -s -f "http://httpbin.org/ip" >/dev/null 2>&1; then
    echo "✓ External connectivity: Working"
else
    echo "✗ External connectivity: Failed"
fi

# Ngrok status
echo ""
echo "=== Ngrok Status ==="
if command -v ngrok >/dev/null; then
    echo "✓ Ngrok found"
    echo "Location: $(which ngrok)"
    
    if [[ -f "$HOME/.ngrok_url" ]]; then
        echo "✓ Tunnel URL file exists"
        echo "URL: $(cat $HOME/.ngrok_url)"
    else
        echo "✗ No tunnel URL file"
    fi
    
    # Check ngrok API
    NGROK_API=$(curl -s http://127.0.0.1:4040/api/tunnels 2>/dev/null || echo "")
    if [[ -n "$NGROK_API" && "$NGROK_API" != "null" ]]; then
        echo "✓ Ngrok API responding"
        if command -v jq >/dev/null; then
            echo "Tunnels:"
            echo "$NGROK_API" | jq '.tunnels[] | {name: .name, public_url: .public_url, proto: .proto}' 2>/dev/null || echo "Cannot parse tunnel info"
        fi
    else
        echo "✗ Ngrok API not responding"
    fi
else
    echo "✗ Ngrok not found"
fi

# Permissions
echo ""
echo "=== Permissions ==="
echo "Home directory permissions:"
ls -ld "$HOME" 2>/dev/null || echo "Cannot check home permissions"

echo "Config directory permissions:"
ls -ld "$HOME/.config/code-server" 2>/dev/null || echo "Config directory not found"

echo "Local bin permissions:"
ls -ld "$HOME/.local/bin" 2>/dev/null || echo "Local bin directory not found"

# PATH
echo ""
echo "=== PATH Information ==="
echo "PATH: $PATH"
echo ""
echo "PATH directories containing code-server or node:"
for dir in $(echo $PATH | tr ':' '\n'); do
    if [[ -d "$dir" ]]; then
        if ls "$dir"/*code-server* 2>/dev/null || ls "$dir"/node* 2>/dev/null; then
            echo "  $dir:"
            ls -la "$dir"/*code-server* "$dir"/node* 2>/dev/null || true
        fi
    fi
done

echo ""
echo "=== Debug Information Complete ==="
echo "If code-server is not working, try:"
echo "1. ./start-code-server-manual.sh start"
echo "2. Check the logs above for specific errors"
echo "3. Ensure all required packages are installed"
