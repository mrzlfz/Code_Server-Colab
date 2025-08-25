#!/usr/bin/env bash
# =============================================================================
# Performance & Optimization Setup for Code-Server
# Resource optimization, caching, load balancing, and performance monitoring
# =============================================================================

set -euo pipefail

# Colors and logging
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

# -------------------------------------------------------------------------
# RESOURCE OPTIMIZATION
# -------------------------------------------------------------------------
setup_resource_optimization() {
    log_info "Setting up resource optimization..."
    
    # Create performance tuning script
    cat > ~/.local/bin/code-server-optimize <<'EOF'
#!/bin/bash
show_help() {
    echo "Code-Server Performance Optimizer"
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  apply     Apply performance optimizations"
    echo "  revert    Revert optimizations"
    echo "  status    Show current optimization status"
    echo "  tune      Interactive performance tuning"
    echo ""
}

apply_optimizations() {
    echo "Applying performance optimizations..."
    
    # Node.js optimizations
    export NODE_OPTIONS="--max-old-space-size=2048 --optimize-for-size"
    
    # Update code-server config for performance
    local config_file="$HOME/.config/code-server/config.yaml"
    if [[ -f "$config_file" ]]; then
        # Add performance settings if not present
        if ! grep -q "disable-telemetry" "$config_file"; then
            echo "disable-telemetry: true" >> "$config_file"
        fi
        if ! grep -q "disable-update-check" "$config_file"; then
            echo "disable-update-check: true" >> "$config_file"
        fi
        if ! grep -q "disable-workspace-trust" "$config_file"; then
            echo "disable-workspace-trust: true" >> "$config_file"
        fi
    fi
    
    # Optimize VS Code settings for performance
    local settings_file="$HOME/.local/share/code-server/User/settings.json"
    if [[ -f "$settings_file" ]]; then
        # Create optimized settings
        jq '. + {
            "files.watcherExclude": {
                "**/.git/objects/**": true,
                "**/.git/subtree-cache/**": true,
                "**/node_modules/*/**": true,
                "**/.hg/store/**": true
            },
            "search.exclude": {
                "**/node_modules": true,
                "**/bower_components": true,
                "**/*.code-search": true
            },
            "files.exclude": {
                "**/.git": true,
                "**/.svn": true,
                "**/.hg": true,
                "**/CVS": true,
                "**/.DS_Store": true,
                "**/Thumbs.db": true,
                "**/node_modules": true
            },
            "typescript.disableAutomaticTypeAcquisition": true,
            "extensions.autoUpdate": false,
            "extensions.autoCheckUpdates": false,
            "telemetry.enableTelemetry": false,
            "workbench.enableExperiments": false,
            "workbench.settings.enableNaturalLanguageSearch": false
        }' "$settings_file" > "$settings_file.tmp" && mv "$settings_file.tmp" "$settings_file"
    fi
    
    # System-level optimizations (only if not in container and running as root)
    local is_container=false
    if [[ -f /.dockerenv ]] || [[ -n "${CONTAINER:-}" ]] || [[ "$(hostname)" =~ ^[0-9a-f]{12}$ ]]; then
        is_container=true
    fi

    if [[ "$is_container" == "false" && $EUID -eq 0 ]]; then
        # Increase file descriptor limits
        echo "* soft nofile 65536" >> /etc/security/limits.conf
        echo "* hard nofile 65536" >> /etc/security/limits.conf

        # Optimize kernel parameters
        echo "vm.swappiness=10" >> /etc/sysctl.conf
        echo "net.core.rmem_max=16777216" >> /etc/sysctl.conf
        echo "net.core.wmem_max=16777216" >> /etc/sysctl.conf

        if sysctl -p >/dev/null 2>&1; then
            echo "✓ System-level optimizations applied"
        else
            echo "⚠️  Some system optimizations failed"
        fi
    elif [[ "$is_container" == "true" ]]; then
        echo "⚠️  Skipping system-level optimizations in container environment"
    else
        echo "⚠️  Run as root for system-level optimizations (non-container only)"
    fi
    
    echo "✓ Performance optimizations applied"
}

show_status() {
    echo "=== Performance Status ==="
    
    # Check Node.js memory settings
    echo "Node.js Options: ${NODE_OPTIONS:-not set}"
    
    # Check file descriptor limits
    echo "File Descriptor Limit: $(ulimit -n)"
    
    # Check system resources
    echo "Memory Usage: $(free -h | grep '^Mem:' | awk '{print $3 "/" $2}')"
    echo "CPU Load: $(uptime | awk -F'load average:' '{print $2}')"
    
    # Check code-server process
    local cs_pid=$(pgrep -f "code-server" | head -1)
    if [[ -n "$cs_pid" ]]; then
        echo "Code-Server PID: $cs_pid"
        echo "Code-Server Memory: $(ps -p $cs_pid -o rss --no-headers | awk '{print $1/1024 " MB"}')"
        echo "Code-Server CPU: $(ps -p $cs_pid -o %cpu --no-headers)%"
    else
        echo "Code-Server: Not running"
    fi
}

interactive_tuning() {
    echo "=== Interactive Performance Tuning ==="
    
    # Memory allocation
    echo "Current Node.js memory limit: ${NODE_OPTIONS:-default}"
    read -p "Set Node.js memory limit (MB) [2048]: " memory_limit
    memory_limit=${memory_limit:-2048}
    
    export NODE_OPTIONS="--max-old-space-size=$memory_limit --optimize-for-size"
    echo "export NODE_OPTIONS=\"--max-old-space-size=$memory_limit --optimize-for-size\"" >> ~/.bashrc
    
    # File watching
    read -p "Disable file watching for large directories? [y/N]: " disable_watching
    if [[ "$disable_watching" =~ ^[Yy]$ ]]; then
        echo "File watching optimizations will be applied"
    fi
    
    echo "✓ Interactive tuning completed"
}

# Main command handling
case "${1:-status}" in
    "apply")
        apply_optimizations
        ;;
    "status")
        show_status
        ;;
    "tune")
        interactive_tuning
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
EOF
    chmod +x ~/.local/bin/code-server-optimize
    
    log_success "Resource optimization configured"
}

# -------------------------------------------------------------------------
# CACHING SYSTEM
# -------------------------------------------------------------------------
setup_caching_system() {
    log_info "Setting up caching system..."
    
    # Create cache management script
    cat > ~/.local/bin/code-server-cache <<'EOF'
#!/bin/bash
CACHE_DIR="$HOME/.local/share/code-server/cache"
USER_DIR="$HOME/.local/share/code-server/User"

show_help() {
    echo "Code-Server Cache Manager"
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  setup     Setup caching system"
    echo "  clear     Clear all caches"
    echo "  status    Show cache status"
    echo "  optimize  Optimize cache settings"
    echo ""
}

setup_cache() {
    echo "Setting up caching system..."
    
    # Create cache directories
    mkdir -p "$CACHE_DIR"/{extensions,workspaces,typescript,eslint}
    
    # Configure cache settings in VS Code
    local settings_file="$USER_DIR/settings.json"
    if [[ -f "$settings_file" ]]; then
        jq '. + {
            "typescript.preferences.includePackageJsonAutoImports": "off",
            "typescript.suggest.autoImports": false,
            "typescript.preferences.includePackageJsonAutoImports": "off",
            "eslint.codeAction.disableRuleComment": {
                "enable": false
            },
            "files.hotExit": "onExitAndWindowClose",
            "editor.semanticTokenColorCustomizations": null
        }' "$settings_file" > "$settings_file.tmp" && mv "$settings_file.tmp" "$settings_file"
    fi
    
    echo "✓ Caching system setup completed"
}

clear_cache() {
    echo "Clearing caches..."
    
    # Clear extension cache
    rm -rf ~/.local/share/code-server/CachedExtensions/* 2>/dev/null || true
    
    # Clear workspace cache
    rm -rf ~/.local/share/code-server/User/workspaceStorage/* 2>/dev/null || true
    
    # Clear logs
    rm -rf ~/.local/share/code-server/logs/* 2>/dev/null || true
    
    # Clear temporary files
    rm -rf /tmp/vscode-* /tmp/code-server-* 2>/dev/null || true
    
    echo "✓ Caches cleared"
}

show_cache_status() {
    echo "=== Cache Status ==="
    
    # Extension cache
    local ext_cache_size=$(du -sh ~/.local/share/code-server/CachedExtensions 2>/dev/null | cut -f1 || echo "0")
    echo "Extension Cache: $ext_cache_size"
    
    # Workspace cache
    local ws_cache_size=$(du -sh ~/.local/share/code-server/User/workspaceStorage 2>/dev/null | cut -f1 || echo "0")
    echo "Workspace Cache: $ws_cache_size"
    
    # Log files
    local log_size=$(du -sh ~/.local/share/code-server/logs 2>/dev/null | cut -f1 || echo "0")
    echo "Log Files: $log_size"
    
    # Total cache size
    local total_size=$(du -sh ~/.local/share/code-server 2>/dev/null | cut -f1 || echo "0")
    echo "Total Size: $total_size"
}

optimize_cache() {
    echo "Optimizing cache settings..."
    
    # Set cache size limits
    local max_cache_size="500M"
    
    # Clean old workspace storage
    find ~/.local/share/code-server/User/workspaceStorage -type f -mtime +30 -delete 2>/dev/null || true
    
    # Clean old logs
    find ~/.local/share/code-server/logs -name "*.log.*" -mtime +7 -delete 2>/dev/null || true
    
    echo "✓ Cache optimization completed"
}

# Main command handling
case "${1:-status}" in
    "setup")
        setup_cache
        ;;
    "clear")
        clear_cache
        ;;
    "status")
        show_cache_status
        ;;
    "optimize")
        optimize_cache
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
EOF
    chmod +x ~/.local/bin/code-server-cache
    
    # Setup initial cache
    ~/.local/bin/code-server-cache setup
    
    log_success "Caching system configured"
}

# -------------------------------------------------------------------------
# PERFORMANCE MONITORING
# -------------------------------------------------------------------------
setup_performance_monitoring() {
    log_info "Setting up performance monitoring..."
    
    # Create performance monitoring script
    cat > ~/.local/bin/code-server-perf <<'EOF'
#!/bin/bash
PERF_LOG="$HOME/.local/share/code-server/logs/performance.log"

show_help() {
    echo "Code-Server Performance Monitor"
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  monitor   Start performance monitoring"
    echo "  report    Generate performance report"
    echo "  benchmark Run performance benchmark"
    echo "  analyze   Analyze performance logs"
    echo ""
}

start_monitoring() {
    echo "Starting performance monitoring..."
    
    # Create monitoring loop
    while true; do
        local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        local cs_pid=$(pgrep -f "code-server" | head -1)
        
        if [[ -n "$cs_pid" ]]; then
            local cpu_usage=$(ps -p $cs_pid -o %cpu --no-headers | tr -d ' ')
            local mem_usage=$(ps -p $cs_pid -o %mem --no-headers | tr -d ' ')
            local mem_rss=$(ps -p $cs_pid -o rss --no-headers | tr -d ' ')
            local load_avg=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | tr -d ',')
            
            echo "$timestamp,CPU:$cpu_usage,MEM:$mem_usage,RSS:$mem_rss,LOAD:$load_avg" >> "$PERF_LOG"
        fi
        
        sleep 60  # Monitor every minute
    done
}

generate_report() {
    echo "=== Performance Report ==="
    
    if [[ ! -f "$PERF_LOG" ]]; then
        echo "No performance data available"
        return 1
    fi
    
    # Last 24 hours stats
    local last_24h=$(date -d '24 hours ago' '+%Y-%m-%d %H:%M:%S')
    local recent_data=$(awk -v date="$last_24h" '$1 >= date' "$PERF_LOG")
    
    if [[ -n "$recent_data" ]]; then
        echo "Last 24 Hours:"
        echo "$recent_data" | awk -F',' '
        BEGIN { cpu_sum=0; mem_sum=0; count=0 }
        {
            gsub(/CPU:/, "", $2); gsub(/MEM:/, "", $3)
            cpu_sum += $2; mem_sum += $3; count++
        }
        END {
            if (count > 0) {
                printf "  Average CPU: %.2f%%\n", cpu_sum/count
                printf "  Average Memory: %.2f%%\n", mem_sum/count
                printf "  Data Points: %d\n", count
            }
        }'
    else
        echo "No recent performance data"
    fi
    
    # System info
    echo ""
    echo "System Information:"
    echo "  CPU Cores: $(nproc)"
    echo "  Total Memory: $(free -h | grep '^Mem:' | awk '{print $2}')"
    echo "  Available Memory: $(free -h | grep '^Mem:' | awk '{print $7}')"
    echo "  Disk Usage: $(df -h $HOME | awk 'NR==2 {print $5}')"
}

run_benchmark() {
    echo "Running performance benchmark..."
    
    # Test file operations
    local test_dir="/tmp/code-server-benchmark-$$"
    mkdir -p "$test_dir"
    
    echo "Testing file operations..."
    local start_time=$(date +%s.%N)
    
    # Create test files
    for i in {1..100}; do
        echo "Test file $i content" > "$test_dir/test$i.txt"
    done
    
    # Read test files
    for i in {1..100}; do
        cat "$test_dir/test$i.txt" >/dev/null
    done
    
    local end_time=$(date +%s.%N)
    local duration=$(echo "$end_time - $start_time" | bc)
    
    echo "File operations completed in: ${duration}s"
    
    # Cleanup
    rm -rf "$test_dir"
    
    # Test network
    echo "Testing network performance..."
    local network_start=$(date +%s.%N)
    curl -s "http://httpbin.org/json" >/dev/null || echo "Network test failed"
    local network_end=$(date +%s.%N)
    local network_duration=$(echo "$network_end - $network_start" | bc)
    
    echo "Network request completed in: ${network_duration}s"
    
    echo "✓ Benchmark completed"
}

analyze_logs() {
    echo "=== Performance Analysis ==="
    
    if [[ ! -f "$PERF_LOG" ]]; then
        echo "No performance logs found"
        return 1
    fi
    
    # Find peak usage
    echo "Peak Usage:"
    awk -F',' 'BEGIN{max_cpu=0; max_mem=0} {gsub(/CPU:/, "", $2); gsub(/MEM:/, "", $3); if($2>max_cpu) max_cpu=$2; if($3>max_mem) max_mem=$3} END{printf "  Peak CPU: %.2f%%\n  Peak Memory: %.2f%%\n", max_cpu, max_mem}' "$PERF_LOG"
    
    # Trend analysis
    echo ""
    echo "Recent Trend (last 10 entries):"
    tail -10 "$PERF_LOG" | awk -F',' '{gsub(/CPU:/, "", $2); gsub(/MEM:/, "", $3); printf "%s: CPU=%.1f%% MEM=%.1f%%\n", $1, $2, $3}'
}

# Main command handling
case "${1:-report}" in
    "monitor")
        start_monitoring
        ;;
    "report")
        generate_report
        ;;
    "benchmark")
        run_benchmark
        ;;
    "analyze")
        analyze_logs
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
EOF
    chmod +x ~/.local/bin/code-server-perf
    
    log_success "Performance monitoring configured"
}

# -------------------------------------------------------------------------
# STARTUP OPTIMIZATION
# -------------------------------------------------------------------------
setup_startup_optimization() {
    log_info "Setting up startup optimization..."
    
    # Create startup optimization script
    cat > ~/.local/bin/code-server-startup <<'EOF'
#!/bin/bash
show_help() {
    echo "Code-Server Startup Optimizer"
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  optimize  Optimize startup performance"
    echo "  preload   Preload common modules"
    echo "  test      Test startup time"
    echo ""
}

optimize_startup() {
    echo "Optimizing startup performance..."
    
    # Disable unnecessary extensions on startup
    local settings_file="$HOME/.local/share/code-server/User/settings.json"
    if [[ -f "$settings_file" ]]; then
        jq '. + {
            "extensions.autoUpdate": false,
            "extensions.autoCheckUpdates": false,
            "workbench.startupEditor": "none",
            "git.autoRepositoryDetection": false,
            "typescript.surveys.enabled": false,
            "workbench.tips.enabled": false,
            "workbench.welcome.enabled": false
        }' "$settings_file" > "$settings_file.tmp" && mv "$settings_file.tmp" "$settings_file"
    fi
    
    # Create fast startup script
    cat > ~/.local/bin/code-server-fast <<'EOFFAST'
#!/bin/bash
# Fast startup script for code-server
export NODE_OPTIONS="--max-old-space-size=1024"
export CODE_SERVER_DISABLE_TELEMETRY=1
export CODE_SERVER_DISABLE_UPDATE_CHECK=1

exec code-server "$@"
EOFFAST
    chmod +x ~/.local/bin/code-server-fast
    
    echo "✓ Startup optimization completed"
    echo "Use 'code-server-fast' for faster startup"
}

test_startup_time() {
    echo "Testing startup time..."
    
    # Stop current instance
    ~/.local/bin/code-server-stop 2>/dev/null || true
    sleep 2
    
    # Test normal startup
    local start_time=$(date +%s.%N)
    timeout 30 code-server --version >/dev/null 2>&1 || true
    local end_time=$(date +%s.%N)
    local startup_time=$(echo "$end_time - $start_time" | bc)
    
    echo "Startup time: ${startup_time}s"
    
    if (( $(echo "$startup_time < 5" | bc -l) )); then
        echo "✓ Startup time is good"
    elif (( $(echo "$startup_time < 10" | bc -l) )); then
        echo "⚠️  Startup time is moderate"
    else
        echo "❌ Startup time is slow"
    fi
}

# Main command handling
case "${1:-optimize}" in
    "optimize")
        optimize_startup
        ;;
    "test")
        test_startup_time
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
EOF
    chmod +x ~/.local/bin/code-server-startup
    
    # Apply startup optimizations
    ~/.local/bin/code-server-startup optimize
    
    log_success "Startup optimization configured"
}

# -------------------------------------------------------------------------
# LOAD BALANCING SETUP
# -------------------------------------------------------------------------
setup_load_balancing() {
    log_info "Setting up load balancing..."

    # Create load balancing script
    cat > ~/.local/bin/code-server-loadbalancer <<'EOF'
#!/bin/bash
NGINX_CONFIG="/etc/nginx/sites-available/code-server-lb"
INSTANCES_FILE="$HOME/.config/code-server/instances.conf"

show_help() {
    echo "Code-Server Load Balancer"
    echo "Usage: $0 [command] [options]"
    echo ""
    echo "Commands:"
    echo "  setup             Setup load balancer"
    echo "  add <port>        Add instance on port"
    echo "  remove <port>     Remove instance"
    echo "  list              List instances"
    echo "  status            Show load balancer status"
    echo "  reload            Reload configuration"
    echo ""
}

setup_loadbalancer() {
    echo "Setting up load balancer..."

    # Install nginx if not present
    if ! command -v nginx >/dev/null; then
        sudo apt-get update
        sudo apt-get install -y nginx
    fi

    # Create instances configuration
    mkdir -p "$(dirname "$INSTANCES_FILE")"
    if [[ ! -f "$INSTANCES_FILE" ]]; then
        cat > "$INSTANCES_FILE" <<'EOFCONF'
# Code-server instances configuration
# Format: server 127.0.0.1:PORT weight=1 max_fails=3 fail_timeout=30s;
server 127.0.0.1:8080 weight=1 max_fails=3 fail_timeout=30s;
EOFCONF
    fi

    # Create nginx load balancer configuration
    sudo tee "$NGINX_CONFIG" >/dev/null <<'EOFNGINX'
upstream code_server_backend {
    # Load balancing method
    least_conn;

    # Include instances from file
    include /home/*/config/code-server/instances.conf;

    # Health check
    keepalive 32;
}

server {
    listen 80;
    server_name _;

    # Security headers
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";

    # Load balancer status page
    location /lb-status {
        stub_status on;
        access_log off;
        allow 127.0.0.1;
        deny all;
    }

    # Health check endpoint
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }

    # Proxy to code-server instances
    location / {
        proxy_pass http://code_server_backend;
        proxy_set_header Host $http_host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # WebSocket support
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection upgrade;
        proxy_set_header Accept-Encoding gzip;

        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;

        # Buffering
        proxy_buffering on;
        proxy_buffer_size 4k;
        proxy_buffers 8 4k;

        # Retry logic
        proxy_next_upstream error timeout invalid_header http_500 http_502 http_503;
        proxy_next_upstream_tries 3;
        proxy_next_upstream_timeout 10s;
    }
}
EOFNGINX

    # Update instances file path in nginx config
    sudo sed -i "s|/home/\*/config/code-server/instances.conf|$INSTANCES_FILE|g" "$NGINX_CONFIG"

    # Enable the site
    sudo ln -sf "$NGINX_CONFIG" /etc/nginx/sites-enabled/code-server-lb

    # Test and reload nginx
    if sudo nginx -t; then
        sudo systemctl reload nginx 2>/dev/null || sudo service nginx reload
        echo "✓ Load balancer configured"
    else
        echo "✗ Nginx configuration error"
        return 1
    fi
}

add_instance() {
    local port="$1"
    if [[ -z "$port" ]]; then
        echo "Error: Port required"
        return 1
    fi

    echo "Adding instance on port $port..."

    # Check if instance already exists
    if grep -q ":$port" "$INSTANCES_FILE" 2>/dev/null; then
        echo "Instance on port $port already exists"
        return 1
    fi

    # Add instance to configuration
    echo "server 127.0.0.1:$port weight=1 max_fails=3 fail_timeout=30s;" >> "$INSTANCES_FILE"

    # Reload nginx
    if sudo nginx -t; then
        sudo systemctl reload nginx 2>/dev/null || sudo service nginx reload
        echo "✓ Instance added on port $port"
    else
        echo "✗ Configuration error, removing instance"
        sed -i "/:$port/d" "$INSTANCES_FILE"
        return 1
    fi
}

remove_instance() {
    local port="$1"
    if [[ -z "$port" ]]; then
        echo "Error: Port required"
        return 1
    fi

    echo "Removing instance on port $port..."

    # Remove instance from configuration
    sed -i "/:$port/d" "$INSTANCES_FILE"

    # Reload nginx
    if sudo nginx -t; then
        sudo systemctl reload nginx 2>/dev/null || sudo service nginx reload
        echo "✓ Instance removed from port $port"
    else
        echo "✗ Configuration error"
        return 1
    fi
}

list_instances() {
    echo "=== Load Balancer Instances ==="
    if [[ -f "$INSTANCES_FILE" ]]; then
        grep "^server" "$INSTANCES_FILE" | while read -r line; do
            local port=$(echo "$line" | grep -o ':[0-9]*' | tr -d ':')
            local status="Unknown"

            # Check if instance is responding
            if curl -s -f "http://127.0.0.1:$port/healthz" >/dev/null 2>&1; then
                status="Healthy"
            else
                status="Unhealthy"
            fi

            echo "Port $port: $status"
        done
    else
        echo "No instances configured"
    fi
}

show_status() {
    echo "=== Load Balancer Status ==="

    # Check nginx status
    if systemctl is-active nginx >/dev/null 2>&1; then
        echo "Nginx: Running"
    else
        echo "Nginx: Stopped"
    fi

    # Show nginx stats
    if curl -s http://127.0.0.1/lb-status >/dev/null 2>&1; then
        echo ""
        echo "Connection Statistics:"
        curl -s http://127.0.0.1/lb-status
    fi

    echo ""
    list_instances
}

reload_config() {
    echo "Reloading load balancer configuration..."

    if sudo nginx -t; then
        sudo systemctl reload nginx 2>/dev/null || sudo service nginx reload
        echo "✓ Configuration reloaded"
    else
        echo "✗ Configuration test failed"
        return 1
    fi
}

# Main command handling
case "${1:-}" in
    "setup")
        setup_loadbalancer
        ;;
    "add")
        add_instance "$2"
        ;;
    "remove")
        remove_instance "$2"
        ;;
    "list")
        list_instances
        ;;
    "status")
        show_status
        ;;
    "reload")
        reload_config
        ;;
    "help"|"-h"|"--help"|"")
        show_help
        ;;
    *)
        echo "Unknown command: $1"
        show_help
        exit 1
        ;;
esac
EOF
    chmod +x ~/.local/bin/code-server-loadbalancer

    log_success "Load balancing configured"
}

# -------------------------------------------------------------------------
# NETWORK OPTIMIZATION
# -------------------------------------------------------------------------
setup_network_optimization() {
    log_info "Setting up network optimization..."

    # Create network optimization script
    cat > ~/.local/bin/code-server-netopt <<'EOF'
#!/bin/bash
show_help() {
    echo "Code-Server Network Optimization"
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  apply     Apply network optimizations"
    echo "  test      Test network performance"
    echo "  status    Show network status"
    echo ""
}

apply_optimizations() {
    echo "Applying network optimizations..."

    # TCP optimizations (only if not in container and running as root)
    local is_container=false
    if [[ -f /.dockerenv ]] || [[ -n "${CONTAINER:-}" ]] || [[ "$(hostname)" =~ ^[0-9a-f]{12}$ ]]; then
        is_container=true
    fi

    if [[ "$is_container" == "false" && $EUID -eq 0 ]]; then
        # Increase TCP buffer sizes
        echo "net.core.rmem_max = 16777216" >> /etc/sysctl.conf
        echo "net.core.wmem_max = 16777216" >> /etc/sysctl.conf
        echo "net.ipv4.tcp_rmem = 4096 87380 16777216" >> /etc/sysctl.conf
        echo "net.ipv4.tcp_wmem = 4096 65536 16777216" >> /etc/sysctl.conf

        # Enable TCP window scaling
        echo "net.ipv4.tcp_window_scaling = 1" >> /etc/sysctl.conf

        # Reduce TIME_WAIT sockets
        echo "net.ipv4.tcp_tw_reuse = 1" >> /etc/sysctl.conf

        # Apply changes
        if sysctl -p >/dev/null 2>&1; then
            echo "✓ System-level network optimizations applied"
        else
            echo "⚠️  Some network optimizations failed"
        fi
    elif [[ "$is_container" == "true" ]]; then
        echo "⚠️  Skipping system-level network optimizations in container environment"
    else
        echo "⚠️  Run as root for system-level optimizations (non-container only)"
    fi

    # Application-level optimizations
    export NODE_OPTIONS="$NODE_OPTIONS --max-http-header-size=16384"
    echo "export NODE_OPTIONS=\"\$NODE_OPTIONS --max-http-header-size=16384\"" >> ~/.bashrc

    echo "✓ Application-level optimizations applied"
}

test_performance() {
    echo "Testing network performance..."

    # Test local connection
    local port=$(grep "bind-addr:" ~/.config/code-server/config.yaml 2>/dev/null | cut -d: -f3 | tr -d ' ' || echo "8080")

    echo "Testing local connection to port $port..."
    local start_time=$(date +%s.%N)

    if curl -s -f "http://127.0.0.1:$port/healthz" >/dev/null; then
        local end_time=$(date +%s.%N)
        local duration=$(echo "$end_time - $start_time" | bc)
        echo "✓ Local connection: ${duration}s"
    else
        echo "✗ Local connection failed"
    fi

    # Test external connectivity
    echo "Testing external connectivity..."
    local ext_start=$(date +%s.%N)

    if curl -s -f "http://httpbin.org/ip" >/dev/null; then
        local ext_end=$(date +%s.%N)
        local ext_duration=$(echo "$ext_end - $ext_start" | bc)
        echo "✓ External connectivity: ${ext_duration}s"
    else
        echo "✗ External connectivity failed"
    fi

    # Bandwidth test (simple)
    echo "Testing bandwidth..."
    local bw_start=$(date +%s.%N)
    curl -s "http://httpbin.org/bytes/1048576" >/dev/null 2>&1 || true
    local bw_end=$(date +%s.%N)
    local bw_duration=$(echo "$bw_end - $bw_start" | bc)
    local bandwidth=$(echo "scale=2; 1 / $bw_duration" | bc)
    echo "Approximate bandwidth: ${bandwidth} MB/s"
}

show_network_status() {
    echo "=== Network Status ==="

    # Show network interfaces
    echo "Network Interfaces:"
    ip addr show | grep "inet " | awk '{print "  " $2}' | head -5

    # Show active connections
    echo ""
    echo "Active Connections:"
    netstat -tlnp 2>/dev/null | grep ":80\|:443\|:8080" | head -5 || ss -tlnp | grep ":80\|:443\|:8080" | head -5

    # Show network statistics
    echo ""
    echo "Network Statistics:"
    cat /proc/net/dev | grep -E "(eth|wlan|enp)" | head -3 | while read -r line; do
        local interface=$(echo "$line" | awk '{print $1}' | tr -d ':')
        local rx_bytes=$(echo "$line" | awk '{print $2}')
        local tx_bytes=$(echo "$line" | awk '{print $10}')
        echo "  $interface: RX $(numfmt --to=iec $rx_bytes) TX $(numfmt --to=iec $tx_bytes)"
    done 2>/dev/null || echo "  Network statistics not available"
}

# Main command handling
case "${1:-status}" in
    "apply")
        apply_optimizations
        ;;
    "test")
        test_performance
        ;;
    "status")
        show_network_status
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
EOF
    chmod +x ~/.local/bin/code-server-netopt

    log_success "Network optimization configured"
}

# -------------------------------------------------------------------------
# MAIN EXECUTION
# -------------------------------------------------------------------------
main() {
    log_info "Setting up Performance & Optimization..."

    setup_resource_optimization
    setup_caching_system
    setup_performance_monitoring
    setup_startup_optimization
    setup_load_balancing
    setup_network_optimization

    # Apply initial optimizations
    ~/.local/bin/code-server-optimize apply
    ~/.local/bin/code-server-netopt apply

    log_success "Performance & Optimization setup completed!"
    log_info ""
    log_info "Performance Commands:"
    log_info "  Optimize: ~/.local/bin/code-server-optimize"
    log_info "  Cache: ~/.local/bin/code-server-cache"
    log_info "  Monitor: ~/.local/bin/code-server-perf"
    log_info "  Startup: ~/.local/bin/code-server-startup"
    log_info "  Load Balancer: ~/.local/bin/code-server-loadbalancer"
    log_info "  Network: ~/.local/bin/code-server-netopt"
}

# Run main function
main "$@"
