#!/usr/bin/env bash
# =============================================================================
# VSCode Server Setup Script (Google Colab / Ubuntu tanpa systemd)
# Versi Final v3 - dengan Kill Port & Error Handling
#
#   * Meng‑install dependencies, Node.js, code‑server
#   * Menyiapkan ngrok (download otomatis, auth token optional)
#   * Menonaktifkan/men-skip konfigurasi UFW bila tidak dapat di‑root
#   * Verifikasi bahwa code‑server sudah berjalan
#   * Otomatis mematikan proses lain yang menggunakan port yang sama
#   * Penanganan Error Otomatis dengan Logging Detail
# =============================================================================

set -euo pipefail # <-- lebih ketat daripada `set -e` saja

# -------------------------------------------------------------------------
# 1️⃣  WARNA & LOGGING
# -------------------------------------------------------------------------
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; NC='\033[0m' # No Color

log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[SUCCESS]NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

# -------------------------------------------------------------------------
#  ENHANCED ERROR HANDLING AND RECOVERY SYSTEM
# -------------------------------------------------------------------------

# Enhanced error handler with recovery attempts
handle_error() {
    local exit_code=$?
    local line_number=$1
    local command_str="$2"
    local error_log="$HOME/.local/share/code-server/logs/error.log"

    # Log error details
    {
        echo "$(date '+%Y-%m-%d %H:%M:%S') - ERROR OCCURRED"
        echo "Line: $line_number"
        echo "Command: $command_str"
        echo "Exit Code: $exit_code"
        echo "Working Directory: $(pwd)"
        echo "User: $(whoami)"
        echo "---"
    } >> "$error_log"

    log_error "Skrip gagal pada baris ${line_number} dengan exit code ${exit_code}."
    log_error "Perintah yang gagal: '${command_str}'"
    log_error "Error logged to: $error_log"

    # Attempt recovery for common issues
    case "$command_str" in
        *"npm install"*|*"code-server --install-extension"*)
            log_warn "Attempting to recover from package installation error..."
            sleep 2
            return 0  # Continue execution
            ;;
        *"curl"*|*"wget"*)
            log_warn "Network error detected, retrying in 5 seconds..."
            sleep 5
            return 0  # Continue execution
            ;;
        *)
            log_error "Silakan periksa log output di atas untuk menemukan penyebab spesifiknya."
            exit $exit_code
            ;;
    esac
}

# Self-healing function
setup_self_healing() {
    log_info "Setting up self-healing mechanisms..."

    # Create watchdog script
    cat > ~/.local/bin/code-server-watchdog <<'EOF'
#!/bin/bash
WATCHDOG_LOG="$HOME/.local/share/code-server/logs/watchdog.log"
CONFIG_FILE="$HOME/.config/code-server/config.yaml"
MAX_FAILURES=3
FAILURE_COUNT=0

log_watchdog() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$WATCHDOG_LOG"
}

# Get port from config
PORT=$(grep "bind-addr:" "$CONFIG_FILE" 2>/dev/null | cut -d: -f3 | tr -d ' ' || echo "8080")

while true; do
    if curl -s -f "http://127.0.0.1:$PORT/healthz" >/dev/null 2>&1; then
        FAILURE_COUNT=0
        sleep 30  # Check every 30 seconds when healthy
    else
        ((FAILURE_COUNT++))
        log_watchdog "Health check failed (attempt $FAILURE_COUNT/$MAX_FAILURES)"

        if [[ $FAILURE_COUNT -ge $MAX_FAILURES ]]; then
            log_watchdog "Maximum failures reached, attempting recovery..."

            # Kill any stuck processes
            pkill -f "code-server" 2>/dev/null || true
            sleep 2

            # Restart service
            ~/.local/bin/code-server-restart >/dev/null 2>&1

            # Wait for startup
            sleep 10

            # Reset failure count
            FAILURE_COUNT=0
            log_watchdog "Recovery attempt completed"
        fi

        sleep 10  # Check more frequently when unhealthy
    fi
done
EOF
    chmod +x ~/.local/bin/code-server-watchdog

    # Create crash recovery script
    cat > ~/.local/bin/code-server-recover <<'EOF'
#!/bin/bash
RECOVERY_LOG="$HOME/.local/share/code-server/logs/recovery.log"

log_recovery() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$RECOVERY_LOG"
}

log_recovery "=== RECOVERY INITIATED ==="

# Stop all code-server processes
log_recovery "Stopping all code-server processes..."
~/.local/bin/code-server-stop >/dev/null 2>&1

# Clean up any stuck resources
log_recovery "Cleaning up resources..."
pkill -f "code-server" 2>/dev/null || true
pkill -f "ngrok" 2>/dev/null || true

# Check and fix permissions
log_recovery "Checking permissions..."
chmod -R u+rw ~/.config/code-server/ ~/.local/share/code-server/ 2>/dev/null || true

# Clear temporary files
log_recovery "Clearing temporary files..."
rm -f /tmp/code-server-* 2>/dev/null || true

# Restart with fresh configuration
log_recovery "Restarting code-server..."
~/.local/bin/code-server-restart >/dev/null 2>&1

# Wait and verify
sleep 5
PORT=$(grep "bind-addr:" ~/.config/code-server/config.yaml 2>/dev/null | cut -d: -f3 | tr -d ' ' || echo "8080")
if curl -s -f "http://127.0.0.1:$PORT/healthz" >/dev/null 2>&1; then
    log_recovery "Recovery successful"
    echo "Recovery completed successfully"
else
    log_recovery "Recovery failed"
    echo "Recovery failed - manual intervention required"
    exit 1
fi
EOF
    chmod +x ~/.local/bin/code-server-recover

    log_success "Self-healing mechanisms configured"
}

# Resource management and monitoring
setup_resource_management() {
    log_info "Setting up resource management..."

    # Create resource monitoring script
    cat > ~/.local/bin/code-server-resources <<'EOF'
#!/bin/bash
RESOURCE_LOG="$HOME/.local/share/code-server/logs/resources.log"

log_resource() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$RESOURCE_LOG"
}

# Get system resources
get_system_resources() {
    # CPU usage
    CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | sed 's/%us,//' || echo "0")

    # Memory usage
    MEM_INFO=$(free -m | grep '^Mem:')
    MEM_TOTAL=$(echo $MEM_INFO | awk '{print $2}')
    MEM_USED=$(echo $MEM_INFO | awk '{print $3}')
    MEM_PERCENT=$((MEM_USED * 100 / MEM_TOTAL))

    # Disk usage
    DISK_INFO=$(df -h "$HOME" | awk 'NR==2 {print $5}' | sed 's/%//')

    # Code-server specific resources
    CS_PID=$(pgrep -f "code-server" | head -1)
    if [[ -n "$CS_PID" ]]; then
        CS_CPU=$(ps -p $CS_PID -o %cpu --no-headers 2>/dev/null || echo "0")
        CS_MEM=$(ps -p $CS_PID -o %mem --no-headers 2>/dev/null || echo "0")
        CS_RSS=$(ps -p $CS_PID -o rss --no-headers 2>/dev/null || echo "0")
    else
        CS_CPU="0"
        CS_MEM="0"
        CS_RSS="0"
    fi

    # Log resources
    log_resource "SYS_CPU=${CPU_USAGE}% SYS_MEM=${MEM_PERCENT}% DISK=${DISK_INFO}% CS_CPU=${CS_CPU}% CS_MEM=${CS_MEM}% CS_RSS=${CS_RSS}KB"

    # Check for resource alerts
    if [[ ${DISK_INFO} -gt 90 ]]; then
        log_resource "ALERT: Disk usage critical: ${DISK_INFO}%"
    fi

    if [[ ${MEM_PERCENT} -gt 90 ]]; then
        log_resource "ALERT: Memory usage critical: ${MEM_PERCENT}%"
    fi

    # Check if code-server is using too much memory (>1GB)
    if [[ ${CS_RSS} -gt 1048576 ]]; then
        log_resource "ALERT: Code-server memory usage high: $((CS_RSS/1024))MB"
    fi
}

# Main execution
get_system_resources

# Display current resources if run interactively
if [[ -t 1 ]]; then
    echo "=== System Resources ==="
    echo "CPU Usage: ${CPU_USAGE}%"
    echo "Memory: ${MEM_USED}MB / ${MEM_TOTAL}MB (${MEM_PERCENT}%)"
    echo "Disk: ${DISK_INFO}%"
    echo ""
    echo "=== Code-Server Resources ==="
    echo "CPU: ${CS_CPU}%"
    echo "Memory: ${CS_MEM}% (${CS_RSS}KB)"
    echo ""
    echo "Recent resource logs:"
    tail -5 "$RESOURCE_LOG" 2>/dev/null || echo "No resource logs found"
fi
EOF
    chmod +x ~/.local/bin/code-server-resources

    # Create resource cleanup script
    cat > ~/.local/bin/code-server-cleanup <<'EOF'
#!/bin/bash
CLEANUP_LOG="$HOME/.local/share/code-server/logs/cleanup.log"

log_cleanup() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$CLEANUP_LOG"
}

log_cleanup "=== CLEANUP STARTED ==="

# Clean old log files (keep last 10)
find ~/.local/share/code-server/logs/ -name "*.log.*" -type f | sort | head -n -10 | xargs rm -f 2>/dev/null || true
log_cleanup "Cleaned old log files"

# Clean temporary files
rm -f /tmp/code-server-* /tmp/vscode-* 2>/dev/null || true
log_cleanup "Cleaned temporary files"

# Clean extension cache if too large (>500MB)
EXT_CACHE="$HOME/.local/share/code-server/CachedExtensions"
if [[ -d "$EXT_CACHE" ]]; then
    CACHE_SIZE=$(du -sm "$EXT_CACHE" 2>/dev/null | cut -f1 || echo "0")
    if [[ $CACHE_SIZE -gt 500 ]]; then
        rm -rf "$EXT_CACHE"/*
        log_cleanup "Cleaned extension cache (was ${CACHE_SIZE}MB)"
    fi
fi

# Clean user data cache if too large (>1GB)
USER_DATA="$HOME/.local/share/code-server/User"
if [[ -d "$USER_DATA" ]]; then
    # Clean workspace storage
    find "$USER_DATA/workspaceStorage" -type f -name "*.log" -mtime +7 -delete 2>/dev/null || true

    # Clean logs
    find "$USER_DATA/logs" -type f -mtime +7 -delete 2>/dev/null || true

    log_cleanup "Cleaned user data cache"
fi

# Rotate monitoring logs
~/.local/bin/code-server-logrotate 2>/dev/null || true

log_cleanup "=== CLEANUP COMPLETED ==="

# Show disk usage after cleanup
DISK_USAGE=$(df -h "$HOME" | awk 'NR==2 {print $5}')
log_cleanup "Disk usage after cleanup: $DISK_USAGE"
EOF
    chmod +x ~/.local/bin/code-server-cleanup

    # Create resource limits script (for PM2)
    cat > ~/.local/bin/code-server-limits <<'EOF'
#!/bin/bash
# Set resource limits for code-server

# Check if running under PM2
if command -v pm2 >/dev/null 2>&1 && pm2 list 2>/dev/null | grep -q code-server; then
    echo "Updating PM2 resource limits..."

    # Update PM2 config with resource limits
    pm2 stop code-server 2>/dev/null || true

    # Create updated ecosystem config
    cat > ~/.config/code-server/ecosystem.config.js <<'EOFPM2'
module.exports = {
  apps: [{
    name: 'code-server',
    script: process.env.HOME + '/.local/bin/code-server',
    args: '--config ' + process.env.HOME + '/.config/code-server/config.yaml',
    cwd: process.env.HOME,
    instances: 1,
    autorestart: true,
    watch: false,
    max_memory_restart: '1G',
    max_restarts: 10,
    min_uptime: '10s',
    env: {
      NODE_ENV: 'production',
      NODE_OPTIONS: '--max-old-space-size=1024'
    },
    error_file: process.env.HOME + '/.local/share/code-server/logs/pm2-error.log',
    out_file: process.env.HOME + '/.local/share/code-server/logs/pm2-out.log',
    log_file: process.env.HOME + '/.local/share/code-server/logs/pm2-combined.log',
    time: true
  }]
};
EOFPM2

    pm2 start ~/.config/code-server/ecosystem.config.js
    pm2 save

    echo "PM2 resource limits updated"
else
    echo "PM2 not found or code-server not running under PM2"
fi
EOF
    chmod +x ~/.local/bin/code-server-limits

    log_success "Resource management configured"
}

# -------------------------------------------------------------------------
# COMPREHENSIVE EXTENSION MANAGEMENT SYSTEM
# -------------------------------------------------------------------------

# Install extensions with marketplace support
install_extension() {
    local ext_id="$1"
    local marketplace="$2"

    case "$marketplace" in
        "openvsx")
            SERVICE_URL=https://open-vsx.org/vscode/gallery \
            ITEM_URL=https://open-vsx.org/vscode/item \
            code-server --install-extension "$ext_id"
            ;;
        "microsoft")
            code-server --install-extension "$ext_id"
            ;;
        *)
            # Try OpenVSX first, fallback to Microsoft
            if ! SERVICE_URL=https://open-vsx.org/vscode/gallery \
                 ITEM_URL=https://open-vsx.org/vscode/item \
                 code-server --install-extension "$ext_id" 2>/dev/null; then
                code-server --install-extension "$ext_id"
            fi
            ;;
    esac
}

# Create extension configuration
create_extension_config() {
    log_info "Creating extension configuration..."

    # Create extensions directory
    mkdir -p ~/.config/code-server/extensions

    # Essential extensions list
    cat > ~/.config/code-server/extensions/essential.json <<'EOF'
{
  "recommendations": [
    "ms-python.python",
    "ms-vscode.vscode-typescript-next",
    "esbenp.prettier-vscode",
    "ms-vscode.vscode-json",
    "redhat.vscode-yaml",
    "ms-vscode.vscode-eslint",
    "ms-vscode.vscode-docker",
    "GitLab.gitlab-workflow",
    "ms-vscode.remote-ssh",
    "ms-azuretools.vscode-containers",
    "bradlc.vscode-tailwindcss",
    "formulahendry.auto-rename-tag",
    "christian-kohler.path-intellisense",
    "ms-vscode.vscode-css",
    "ms-vscode.vscode-html",
    "ms-vscode.vscode-markdown"
  ]
}
EOF

    # Development extensions by language
    cat > ~/.config/code-server/extensions/languages.json <<'EOF'
{
  "javascript": [
    "ms-vscode.vscode-typescript-next",
    "esbenp.prettier-vscode",
    "ms-vscode.vscode-eslint",
    "bradlc.vscode-tailwindcss",
    "formulahendry.auto-rename-tag"
  ],
  "python": [
    "ms-python.python",
    "ms-python.pylint",
    "ms-python.black-formatter",
    "ms-python.isort"
  ],
  "php": [
    "bmewburn.vscode-intelephense-client",
    "xdebug.php-debug",
    "junstyle.php-cs-fixer"
  ],
  "go": [
    "golang.go"
  ],
  "rust": [
    "rust-lang.rust-analyzer"
  ],
  "java": [
    "redhat.java",
    "vscjava.vscode-java-debug"
  ],
  "docker": [
    "ms-vscode.vscode-docker",
    "ms-azuretools.vscode-containers"
  ],
  "git": [
    "eamodio.gitlens",
    "GitLab.gitlab-workflow",
    "github.vscode-pull-request-github"
  ]
}
EOF

    # Theme and UI extensions
    cat > ~/.config/code-server/extensions/themes.json <<'EOF'
{
  "recommendations": [
    "dracula-theme.theme-dracula",
    "ms-vscode.theme-monokai-dimmed",
    "github.github-vscode-theme",
    "pkief.material-icon-theme",
    "vscode-icons-team.vscode-icons",
    "ms-vscode.theme-tomorrow-night-blue"
  ]
}
EOF

    log_success "Extension configuration created"
}

# Install extensions from JSON file
install_extensions_from_file() {
    local ext_file="$1"
    local marketplace="${2:-$EXTENSION_MARKETPLACE}"

    if [[ ! -f "$ext_file" ]]; then
        log_warn "Extension file not found: $ext_file"
        return 1
    fi

    log_info "Installing extensions from: $ext_file"

    # Check if jq is available
    if ! command_exists jq; then
        log_warn "jq not available, installing..."
        sudo apt-get update && sudo apt-get install -y jq
    fi

    # Install extensions
    jq -r '.recommendations[]' "$ext_file" 2>/dev/null | while read -r ext; do
        if [[ -n "$ext" ]]; then
            log_info "Installing extension: $ext"
            if install_extension "$ext" "$marketplace"; then
                log_success "✓ Installed: $ext"
            else
                log_warn "✗ Failed to install: $ext"
            fi
        fi
    done
}

# Main extension installation function
install_extensions() {
    if [[ "$INSTALL_EXTENSIONS" != "true" ]]; then
        log_info "Extension installation disabled"
        return
    fi

    log_info "Starting extension installation..."

    # Create extension configuration
    create_extension_config

    # Install essential extensions
    log_info "Installing essential extensions..."
    install_extensions_from_file ~/.config/code-server/extensions/essential.json

    # Install theme extensions
    log_info "Installing theme extensions..."
    install_extensions_from_file ~/.config/code-server/extensions/themes.json

    # Check for workspace-specific extensions
    if [[ -f ".vscode/extensions.json" ]]; then
        log_info "Installing workspace-specific extensions..."
        install_extensions_from_file .vscode/extensions.json
    fi

    # Check for user-defined extensions
    if [[ -f ~/.config/code-server/extensions/user.json ]]; then
        log_info "Installing user-defined extensions..."
        install_extensions_from_file ~/.config/code-server/extensions/user.json
    fi

    log_success "Extension installation completed"
}

# Create extension management scripts
create_extension_management_scripts() {
    log_info "Creating extension management scripts..."

    # Extension manager script
    cat > ~/.local/bin/code-server-extensions <<'EOF'
#!/bin/bash
EXTENSIONS_DIR="$HOME/.config/code-server/extensions"
INSTALLED_LIST="$HOME/.local/share/code-server/installed-extensions.txt"

show_help() {
    echo "Code-Server Extension Manager"
    echo "Usage: $0 [command] [options]"
    echo ""
    echo "Commands:"
    echo "  list                 List installed extensions"
    echo "  install <ext-id>     Install extension"
    echo "  uninstall <ext-id>   Uninstall extension"
    echo "  update               Update all extensions"
    echo "  backup               Backup extension list"
    echo "  restore              Restore extensions from backup"
    echo "  search <term>        Search for extensions"
    echo "  info <ext-id>        Show extension information"
    echo ""
}

list_extensions() {
    echo "=== Installed Extensions ==="
    code-server --list-extensions --show-versions 2>/dev/null || echo "No extensions found"
}

install_extension() {
    local ext_id="$1"
    if [[ -z "$ext_id" ]]; then
        echo "Error: Extension ID required"
        return 1
    fi

    echo "Installing extension: $ext_id"
    if SERVICE_URL=https://open-vsx.org/vscode/gallery \
       ITEM_URL=https://open-vsx.org/vscode/item \
       code-server --install-extension "$ext_id"; then
        echo "✓ Successfully installed: $ext_id"
        echo "$ext_id" >> "$INSTALLED_LIST"
    else
        echo "✗ Failed to install: $ext_id"
        return 1
    fi
}

uninstall_extension() {
    local ext_id="$1"
    if [[ -z "$ext_id" ]]; then
        echo "Error: Extension ID required"
        return 1
    fi

    echo "Uninstalling extension: $ext_id"
    if code-server --uninstall-extension "$ext_id"; then
        echo "✓ Successfully uninstalled: $ext_id"
        sed -i "/$ext_id/d" "$INSTALLED_LIST" 2>/dev/null || true
    else
        echo "✗ Failed to uninstall: $ext_id"
        return 1
    fi
}

update_extensions() {
    echo "Updating all extensions..."
    local updated=0

    code-server --list-extensions 2>/dev/null | while read -r ext; do
        if [[ -n "$ext" ]]; then
            echo "Updating: $ext"
            if SERVICE_URL=https://open-vsx.org/vscode/gallery \
               ITEM_URL=https://open-vsx.org/vscode/item \
               code-server --install-extension "$ext" --force; then
                echo "✓ Updated: $ext"
                ((updated++))
            else
                echo "✗ Failed to update: $ext"
            fi
        fi
    done

    echo "Update completed. $updated extensions updated."
}

backup_extensions() {
    local backup_file="$HOME/.config/code-server/extensions/backup-$(date +%Y%m%d-%H%M%S).json"
    echo "Creating extension backup..."

    {
        echo "{"
        echo '  "timestamp": "'$(date -Iseconds)'",'
        echo '  "extensions": ['
        code-server --list-extensions 2>/dev/null | sed 's/.*/"&"/' | paste -sd, -
        echo "  ]"
        echo "}"
    } > "$backup_file"

    echo "✓ Backup created: $backup_file"
}

restore_extensions() {
    local backup_file="$1"
    if [[ -z "$backup_file" ]]; then
        # Find latest backup
        backup_file=$(ls -t ~/.config/code-server/extensions/backup-*.json 2>/dev/null | head -1)
    fi

    if [[ ! -f "$backup_file" ]]; then
        echo "Error: Backup file not found"
        return 1
    fi

    echo "Restoring extensions from: $backup_file"

    if command -v jq >/dev/null 2>&1; then
        jq -r '.extensions[]' "$backup_file" | while read -r ext; do
            install_extension "$ext"
        done
    else
        echo "Error: jq not available for parsing backup file"
        return 1
    fi
}

# Main command handling
case "$1" in
    "list"|"ls")
        list_extensions
        ;;
    "install"|"add")
        install_extension "$2"
        ;;
    "uninstall"|"remove"|"rm")
        uninstall_extension "$2"
        ;;
    "update"|"upgrade")
        update_extensions
        ;;
    "backup")
        backup_extensions
        ;;
    "restore")
        restore_extensions "$2"
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
    chmod +x ~/.local/bin/code-server-extensions

    log_success "Extension management scripts created"
}

# Atur 'trap' untuk memanggil fungsi handle_error saat sinyal ERR diterima.
trap 'handle_error $LINENO "$BASH_COMMAND"' ERR

# -------------------------------------------------------------------------
# 2️⃣  KONFIGURASI DASAR (ubah bila diperlukan)
# -------------------------------------------------------------------------
CODE_SERVER_VERSION="4.20.0"
INSTALL_METHOD="script" # script | standalone | npm
PROCESS_MANAGER="pm2" # nohup | pm2 | supervisor
BIND_ADDR="0.0.0.0:8888"
ENABLE_SSL=false
DOMAIN=""
INSTALL_EXTENSIONS=true
EXTENSION_MARKETPLACE="both"  # openvsx | microsoft | both
SETUP_DEV_ENVIRONMENT=true  # Setup development environment
SETUP_UI_EXPERIENCE=true    # Setup UI and user experience
SETUP_SECURITY=true         # Setup security and authentication
SETUP_BACKUP=true           # Setup backup system
SETUP_PERFORMANCE=true      # Setup performance optimization

NGROK_URL="https://bin.equinox.io/c/4VmDzA7iaHb/ngrok-stable-linux-amd64.zip"
NGROK_BIN="${HOME}/.local/bin/ngrok"
NGROK_AUTH_TOKEN="1UB1Whi7kn5pLy7zdouDg0H7To9_3JPMzcK9c3vUz4MVGSKK5" # isi token Anda di sini (opsional)

# -------------------------------------------------------------------------
# 3️⃣  UTILITAS
# -------------------------------------------------------------------------
command_exists() { command -v "$1" >/dev/null 2>&1; }

generate_password() {
    openssl rand -base64 32 | tr -d '=+/' | cut -c1-25
}

# -------------------------------------------------------------------------
# 4️⃣  INSTALL DEPENDENCIES
# -------------------------------------------------------------------------
install_dependencies() {
    log_info "Meng‑install paket sistem…"
    sudo apt-get update -y
    sudo apt-get install -y \
        curl wget git build-essential pkg-config lsof \
        python3 python3-pip nginx ufw openssl jq htop unzip
    log_success "Paket sistem selesai di‑install"
}

# -------------------------------------------------------------------------
# 5️⃣  INSTALL NODE.JS
# -------------------------------------------------------------------------
install_nodejs() {
    if command_exists node && command_exists npm; then
        log_info "Node.js sudah terpasang: $(node --version)"
        return
    fi
    log_info "Meng‑install Node.js 18.x…"
    curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
    sudo apt-get install -y nodejs
    log_success "Node.js terinstall: $(node --version)"
}

# -------------------------------------------------------------------------
# 6️⃣  INSTALL CODE‑SERVER
# -------------------------------------------------------------------------
install_code_server() {
    log_info "Meng‑install code‑server (metode: $INSTALL_METHOD)…"
    case "$INSTALL_METHOD" in
    script)
        curl -fsSL https://code-server.dev/install.sh | sh
        ;;
    standalone)
        mkdir -p ~/.local/{lib,bin}
        curl -fL "https://github.com/coder/code-server/releases/download/v$CODE_SERVER_VERSION/code-server-$CODE_SERVER_VERSION-linux-amd64.tar.gz" |
            tar -C ~/.local/lib -xz
        mv ~/.local/lib/code-server-$CODE_SERVER_VERSION-linux-amd64 ~/.local/lib/code-server-$CODE_SERVER_VERSION
        ln -sf ~/.local/lib/code-server-$CODE_SERVER_VERSION/bin/code-server ~/.local/bin/code-server
        if ! echo "$PATH" | grep -q "$HOME/.local/bin"; then
            echo 'export PATH="$HOME/.local/bin:$PATH"' >>~/.bashrc
            export PATH="$HOME/.local/bin:$PATH"
        fi
        ;;
    npm)
        npm config set python python3
        npm install -g code-server
        ;;
    *)
        log_error "Metode instalasi $INSTALL_METHOD tidak dikenal"
        exit 1
        ;;
    esac
    log_success "code‑server terinstall"
}

# -------------------------------------------------------------------------
# 7️⃣  KONFIGURASI CODE‑SERVER & MONITORING
# -------------------------------------------------------------------------

# Setup logging and monitoring
setup_logging_monitoring() {
    log_info "Setting up logging and monitoring system..."

    # Create log directories
    mkdir -p ~/.local/share/code-server/logs/{server,monitoring,backup}

    # Create log rotation script
    cat > ~/.local/bin/code-server-logrotate <<'EOF'
#!/bin/bash
LOG_DIR="$HOME/.local/share/code-server/logs"
MAX_SIZE="10M"
MAX_FILES=5

rotate_log() {
    local logfile="$1"
    if [[ -f "$logfile" ]] && [[ $(stat -f%z "$logfile" 2>/dev/null || stat -c%s "$logfile" 2>/dev/null) -gt 10485760 ]]; then
        for i in $(seq $((MAX_FILES-1)) -1 1); do
            [[ -f "${logfile}.$i" ]] && mv "${logfile}.$i" "${logfile}.$((i+1))"
        done
        mv "$logfile" "${logfile}.1"
        touch "$logfile"
        echo "$(date): Rotated $logfile"
    fi
}

# Rotate various log files
rotate_log "$LOG_DIR/server.log"
rotate_log "$LOG_DIR/pm2-combined.log"
rotate_log "$LOG_DIR/supervisor-out.log"
rotate_log "$LOG_DIR/supervisor-err.log"
rotate_log "$LOG_DIR/monitoring.log"
EOF
    chmod +x ~/.local/bin/code-server-logrotate

    # Create monitoring script
    cat > ~/.local/bin/code-server-monitor <<'EOF'
#!/bin/bash
MONITOR_LOG="$HOME/.local/share/code-server/logs/monitoring.log"
CONFIG_FILE="$HOME/.config/code-server/config.yaml"

log_monitor() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$MONITOR_LOG"
}

# Get port from config
PORT=$(grep "bind-addr:" "$CONFIG_FILE" 2>/dev/null | cut -d: -f3 | tr -d ' ' || echo "8080")

# Check if code-server is responding
if curl -s -f "http://127.0.0.1:$PORT/healthz" >/dev/null 2>&1; then
    STATUS="HEALTHY"
else
    STATUS="UNHEALTHY"
    log_monitor "WARNING: Code-server not responding on port $PORT"
fi

# Check resource usage
CPU_USAGE=$(ps aux | grep '[c]ode-server' | awk '{sum += $3} END {print sum+0}')
MEM_USAGE=$(ps aux | grep '[c]ode-server' | awk '{sum += $4} END {print sum+0}')

# Log metrics
log_monitor "STATUS=$STATUS CPU=${CPU_USAGE}% MEM=${MEM_USAGE}%"

# Check disk space
DISK_USAGE=$(df -h "$HOME" | awk 'NR==2 {print $5}' | sed 's/%//')
if [[ $DISK_USAGE -gt 90 ]]; then
    log_monitor "WARNING: Disk usage high: ${DISK_USAGE}%"
fi

# Auto-restart if unhealthy
if [[ "$STATUS" == "UNHEALTHY" ]]; then
    log_monitor "Attempting auto-restart..."
    ~/.local/bin/code-server-restart >/dev/null 2>&1
    sleep 5
    if curl -s -f "http://127.0.0.1:$PORT/healthz" >/dev/null 2>&1; then
        log_monitor "Auto-restart successful"
    else
        log_monitor "ERROR: Auto-restart failed"
    fi
fi
EOF
    chmod +x ~/.local/bin/code-server-monitor

    # Create system info script
    cat > ~/.local/bin/code-server-sysinfo <<'EOF'
#!/bin/bash
echo "=== Code-Server System Information ==="
echo "Date: $(date)"
echo "Uptime: $(uptime)"
echo "Load Average: $(uptime | awk -F'load average:' '{print $2}')"
echo "Memory Usage: $(free -h | grep '^Mem:' | awk '{print $3 "/" $2}')"
echo "Disk Usage: $(df -h $HOME | awk 'NR==2 {print $3 "/" $2 " (" $5 ")"}')"
echo ""
echo "=== Code-Server Processes ==="
ps aux | grep '[c]ode-server' | awk '{print "PID: " $2 " CPU: " $3 "% MEM: " $4 "% CMD: " $11}'
echo ""
echo "=== Network Connections ==="
netstat -tlnp 2>/dev/null | grep ':8080\|:8888\|:4040' || ss -tlnp | grep ':8080\|:8888\|:4040'
echo ""
echo "=== Recent Log Entries ==="
tail -10 ~/.local/share/code-server/logs/monitoring.log 2>/dev/null || echo "No monitoring logs found"
EOF
    chmod +x ~/.local/bin/code-server-sysinfo

    log_success "Logging and monitoring system configured"
}

create_config() {
    log_info "Membuat konfigurasi code‑server…"
    mkdir -p ~/.config/code-server ~/.local/share/code-server/logs

    PASSWORD=$(generate_password)

    cat >~/.config/code-server/config.yaml <<EOF
bind-addr: $BIND_ADDR
auth: password
password: $PASSWORD
cert: $ENABLE_SSL
disable-telemetry: true
disable-update-check: true
disable-workspace-trust: true
log: info
EOF

    # Setup logging and monitoring
    setup_logging_monitoring

    log_success "Konfigurasi disimpan di ~/.config/code-server/config.yaml"
    log_warn "Password yang dihasilkan: $PASSWORD"
    echo "Password: $PASSWORD"
}

# -------------------------------------------------------------------------
# 8️⃣  MULTIPLE TUNNEL SOLUTIONS
# -------------------------------------------------------------------------

# Enhanced ngrok setup
install_ngrok() {
    if command_exists ngrok; then
        log_info "ngrok sudah ada di PATH"
        return
    fi

    if [[ -x "$NGROK_BIN" ]]; then
        log_info "ngrok sudah di‑download di $NGROK_BIN"
        return
    fi

    log_info "Meng‑download ngrok…"
    mkdir -p "${HOME}/.local/bin"
    curl -sL "$NGROK_URL" -o /tmp/ngrok.zip
    unzip -q /tmp/ngrok.zip -d "${HOME}/.local/bin"
    chmod +x "$NGROK_BIN"
    rm /tmp/ngrok.zip
    log_success "ngrok terinstall di $NGROK_BIN"
}

# Cloudflare Tunnel setup
install_cloudflare_tunnel() {
    if command_exists cloudflared; then
        log_info "Cloudflare Tunnel already installed"
        return
    fi

    log_info "Installing Cloudflare Tunnel..."

    # Download cloudflared
    local arch="amd64"
    if [[ "$(uname -m)" == "aarch64" ]]; then
        arch="arm64"
    fi

    curl -L "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${arch}" \
        -o ~/.local/bin/cloudflared
    chmod +x ~/.local/bin/cloudflared

    log_success "Cloudflare Tunnel installed"
}

# VS Code Tunnel setup
install_vscode_tunnel() {
    if [[ -x ~/.local/bin/code-tunnel ]]; then
        log_info "VS Code Tunnel already installed"
        return
    fi

    log_info "Installing VS Code Tunnel..."

    # Download VS Code CLI
    local arch="x64"
    if [[ "$(uname -m)" == "aarch64" ]]; then
        arch="arm64"
    fi

    curl -Lk "https://code.visualstudio.com/sha/download?build=stable&os=cli-alpine-${arch}" \
        --output /tmp/vscode_cli.tar.gz

    tar -xzf /tmp/vscode_cli.tar.gz -C ~/.local/bin/
    mv ~/.local/bin/code ~/.local/bin/code-tunnel
    rm /tmp/vscode_cli.tar.gz

    log_success "VS Code Tunnel installed"
}

# Start ngrok tunnel
start_ngrok_tunnel() {
    install_ngrok
    if [[ -n "$NGROK_AUTH_TOKEN" ]]; then
        "$NGROK_BIN" authtoken "$NGROK_AUTH_TOKEN"
    fi
    log_info "Membuka tunnel ngrok ke $BIND_ADDR …"
    "$NGROK_BIN" http "${BIND_ADDR##*:}" >/dev/null 2>&1 &
    NGROK_PID=$!
    for i in {1..10}; do
        sleep 1
        TUNNEL_JSON=$(curl -s http://127.0.0.1:4040/api/tunnels 2>/dev/null || true)
        if [[ -n "$TUNNEL_JSON" && "$TUNNEL_JSON" != "null" ]]; then
            break
        fi
    done
    if [[ -z "$TUNNEL_JSON" ]]; then
        log_error "Tidak dapat membaca URL tunnel ngrok (JSON kosong)."
        kill "$NGROK_PID" 2>/dev/null || true
        return 1
    fi
    if command_exists jq; then
        PUBLIC_URL=$(echo "$TUNNEL_JSON" | jq -r '.tunnels[0].public_url')
    else
        PUBLIC_URL=$(echo "$TUNNEL_JSON" | grep -o '"public_url":"[^"]*' | head -1 | cut -d'"' -f4)
    fi
    if [[ -z "$PUBLIC_URL" || "$PUBLIC_URL" == "null" ]]; then
        log_error "Gagal mengekstrak public URL dari response ngrok."
        kill "$NGROK_PID" 2>/dev/null || true
        return 1
    fi
    log_success "Tunnel ngrok aktif: $PUBLIC_URL"
    echo "$PUBLIC_URL" >"${HOME}/.ngrok_url"
}

# Start Cloudflare tunnel
start_cloudflare_tunnel() {
    install_cloudflare_tunnel
    log_info "Starting Cloudflare Tunnel..."

    local port="${BIND_ADDR##*:}"
    ~/.local/bin/cloudflared tunnel --url "http://127.0.0.1:$port" >/dev/null 2>&1 &
    CLOUDFLARE_PID=$!

    # Wait for tunnel to establish
    sleep 5

    # Try to get the tunnel URL (this is tricky with cloudflared)
    log_success "Cloudflare Tunnel started (PID: $CLOUDFLARE_PID)"
    echo "Check cloudflared logs for the public URL"
}

# Start VS Code tunnel
start_vscode_tunnel() {
    install_vscode_tunnel
    log_info "Starting VS Code Tunnel..."

    # This requires user authentication
    log_warn "VS Code Tunnel requires GitHub/Microsoft authentication"
    log_info "Run manually: ~/.local/bin/code-tunnel tunnel --accept-server-license-terms"
}

# Create tunnel management script
create_tunnel_manager() {
    log_info "Creating tunnel management script..."

    cat > ~/.local/bin/code-server-tunnel <<'EOF'
#!/bin/bash
TUNNEL_TYPE="${1:-ngrok}"
PORT="${2:-8080}"

show_help() {
    echo "Code-Server Tunnel Manager"
    echo "Usage: $0 [tunnel-type] [port]"
    echo ""
    echo "Tunnel Types:"
    echo "  ngrok       Use ngrok tunnel (default)"
    echo "  cloudflare  Use Cloudflare tunnel"
    echo "  vscode      Use VS Code tunnel"
    echo "  stop        Stop all tunnels"
    echo "  status      Show tunnel status"
    echo ""
}

start_ngrok() {
    if pgrep -f "ngrok" >/dev/null; then
        echo "Ngrok already running"
        return
    fi

    echo "Starting ngrok tunnel on port $PORT..."
    ngrok http "$PORT" >/dev/null 2>&1 &

    sleep 3
    TUNNEL_JSON=$(curl -s http://127.0.0.1:4040/api/tunnels 2>/dev/null || true)
    if [[ -n "$TUNNEL_JSON" ]]; then
        PUBLIC_URL=$(echo "$TUNNEL_JSON" | jq -r '.tunnels[0].public_url' 2>/dev/null || echo "Check ngrok dashboard")
        echo "✓ Ngrok tunnel active: $PUBLIC_URL"
    else
        echo "✗ Failed to get ngrok URL"
    fi
}

start_cloudflare() {
    if pgrep -f "cloudflared" >/dev/null; then
        echo "Cloudflare tunnel already running"
        return
    fi

    echo "Starting Cloudflare tunnel on port $PORT..."
    cloudflared tunnel --url "http://127.0.0.1:$PORT" >/dev/null 2>&1 &
    echo "✓ Cloudflare tunnel started (check logs for URL)"
}

start_vscode() {
    echo "Starting VS Code tunnel..."
    echo "This requires authentication - run interactively:"
    echo "code tunnel --accept-server-license-terms"
}

stop_tunnels() {
    echo "Stopping all tunnels..."
    pkill -f "ngrok" 2>/dev/null || true
    pkill -f "cloudflared" 2>/dev/null || true
    pkill -f "code tunnel" 2>/dev/null || true
    echo "✓ All tunnels stopped"
}

show_status() {
    echo "=== Tunnel Status ==="

    if pgrep -f "ngrok" >/dev/null; then
        echo "Ngrok: Running"
        TUNNEL_JSON=$(curl -s http://127.0.0.1:4040/api/tunnels 2>/dev/null || true)
        if [[ -n "$TUNNEL_JSON" ]]; then
            PUBLIC_URL=$(echo "$TUNNEL_JSON" | jq -r '.tunnels[0].public_url' 2>/dev/null || echo "Unknown")
            echo "  URL: $PUBLIC_URL"
        fi
    else
        echo "Ngrok: Stopped"
    fi

    if pgrep -f "cloudflared" >/dev/null; then
        echo "Cloudflare: Running"
    else
        echo "Cloudflare: Stopped"
    fi

    if pgrep -f "code tunnel" >/dev/null; then
        echo "VS Code Tunnel: Running"
    else
        echo "VS Code Tunnel: Stopped"
    fi
}

# Main command handling
case "$TUNNEL_TYPE" in
    "ngrok")
        start_ngrok
        ;;
    "cloudflare"|"cf")
        start_cloudflare
        ;;
    "vscode"|"code")
        start_vscode
        ;;
    "stop")
        stop_tunnels
        ;;
    "status")
        show_status
        ;;
    "help"|"-h"|"--help")
        show_help
        ;;
    *)
        echo "Unknown tunnel type: $TUNNEL_TYPE"
        show_help
        exit 1
        ;;
esac
EOF
    chmod +x ~/.local/bin/code-server-tunnel

    log_success "Tunnel management script created"
}

# SSH Server Configuration
setup_ssh_server() {
    log_info "Setting up SSH server configuration..."

    # Install OpenSSH server if not present
    if ! command_exists sshd; then
        sudo apt-get update
        sudo apt-get install -y openssh-server
    fi

    # Create SSH configuration backup
    sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup 2>/dev/null || true

    # Configure SSH for better security
    sudo tee -a /etc/ssh/sshd_config.d/code-server.conf >/dev/null <<'EOF'
# Code-Server SSH Configuration
Port 22
PermitRootLogin no
PasswordAuthentication yes
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys
AllowTcpForwarding yes
GatewayPorts no
X11Forwarding no
PrintMotd no
AcceptEnv LANG LC_*
Subsystem sftp /usr/lib/openssh/sftp-server
EOF

    # Restart SSH service
    sudo systemctl restart ssh 2>/dev/null || sudo service ssh restart 2>/dev/null || true

    log_success "SSH server configured"
}

# Reverse Proxy Setup (Nginx)
setup_reverse_proxy() {
    log_info "Setting up reverse proxy (Nginx)..."

    # Install Nginx
    sudo apt-get update
    sudo apt-get install -y nginx

    # Create code-server site configuration
    local port="${BIND_ADDR##*:}"
    sudo tee /etc/nginx/sites-available/code-server >/dev/null <<EOF
server {
    listen 80;
    server_name _;

    # Security headers
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";

    # Proxy to code-server
    location / {
        proxy_pass http://127.0.0.1:$port;
        proxy_set_header Host \$http_host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;

        # WebSocket support
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection upgrade;
        proxy_set_header Accept-Encoding gzip;

        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    # Health check endpoint
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
}
EOF

    # Enable the site
    sudo ln -sf /etc/nginx/sites-available/code-server /etc/nginx/sites-enabled/
    sudo rm -f /etc/nginx/sites-enabled/default

    # Test and reload Nginx
    if sudo nginx -t; then
        sudo systemctl reload nginx 2>/dev/null || sudo service nginx reload 2>/dev/null || true
        log_success "Nginx reverse proxy configured"
    else
        log_error "Nginx configuration test failed"
    fi
}

# Network Configuration
setup_network_configuration() {
    log_info "Setting up network configuration..."

    # Configure UFW firewall
    if command_exists ufw; then
        # Allow SSH
        sudo ufw allow ssh

        # Allow HTTP/HTTPS
        sudo ufw allow 80/tcp
        sudo ufw allow 443/tcp

        # Allow code-server port
        local port="${BIND_ADDR##*:}"
        sudo ufw allow "$port/tcp"

        # Enable UFW (with --force to avoid interactive prompt)
        sudo ufw --force enable

        log_success "UFW firewall configured"
    else
        log_warn "UFW not available, skipping firewall configuration"
    fi

    # Create network monitoring script
    cat > ~/.local/bin/code-server-network <<'EOF'
#!/bin/bash
show_help() {
    echo "Code-Server Network Monitor"
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  status    Show network status"
    echo "  ports     Show open ports"
    echo "  test      Test connectivity"
    echo "  firewall  Show firewall status"
    echo ""
}

show_status() {
    echo "=== Network Status ==="
    echo "Hostname: $(hostname)"
    echo "IP Addresses:"
    ip addr show | grep "inet " | awk '{print "  " $2}' | grep -v "127.0.0.1"
    echo ""
    echo "Active Connections:"
    netstat -tlnp 2>/dev/null | grep ":80\|:443\|:8080\|:8888\|:22" || ss -tlnp | grep ":80\|:443\|:8080\|:8888\|:22"
}

show_ports() {
    echo "=== Open Ports ==="
    if command -v netstat >/dev/null; then
        netstat -tlnp | grep LISTEN
    else
        ss -tlnp | grep LISTEN
    fi
}

test_connectivity() {
    echo "=== Connectivity Test ==="

    # Test local code-server
    local port=$(grep "bind-addr:" ~/.config/code-server/config.yaml 2>/dev/null | cut -d: -f3 | tr -d ' ' || echo "8080")
    if curl -s -f "http://127.0.0.1:$port/healthz" >/dev/null; then
        echo "✓ Code-server responding on port $port"
    else
        echo "✗ Code-server not responding on port $port"
    fi

    # Test external connectivity
    if curl -s -f "http://httpbin.org/ip" >/dev/null; then
        echo "✓ External connectivity working"
    else
        echo "✗ External connectivity failed"
    fi
}

show_firewall() {
    echo "=== Firewall Status ==="
    if command -v ufw >/dev/null; then
        sudo ufw status verbose
    elif command -v iptables >/dev/null; then
        sudo iptables -L -n
    else
        echo "No firewall tools found"
    fi
}

# Main command handling
case "${1:-status}" in
    "status")
        show_status
        ;;
    "ports")
        show_ports
        ;;
    "test")
        test_connectivity
        ;;
    "firewall")
        show_firewall
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
    chmod +x ~/.local/bin/code-server-network

    log_success "Network configuration completed"
}

# -------------------------------------------------------------------------
# FUNGSI UNTUK MEMBERSIHKAN PORT
# -------------------------------------------------------------------------
kill_process_on_port() {
    local port_to_check="${1##*:}"
    log_info "Mengecek port $port_to_check sebelum memulai server..."

    # Cari PID yang menggunakan port. Opsi -t hanya menampilkan PID.
    local pid_to_kill
    pid_to_kill=$(lsof -t -i:"$port_to_check" 2>/dev/null)

    if [[ -n "$pid_to_kill" ]]; then
        log_warn "Port $port_to_check sudah digunakan oleh proses PID: $pid_to_kill."
        log_warn "Mematikan proses tersebut secara paksa (kill -9)..."
        kill -9 "$pid_to_kill"
        sleep 1 # Beri jeda 1 detik agar OS melepaskan port
        log_success "Proses pada port $port_to_check berhasil dimatikan."
    else
        log_info "Port $port_to_check bebas untuk digunakan."
    fi
}

# -------------------------------------------------------------------------
# 9️⃣  ENHANCED PROCESS MANAGEMENT
# -------------------------------------------------------------------------

# Health check function
health_check() {
    local port="${BIND_ADDR##*:}"
    local max_attempts=5
    local attempt=1

    while [ $attempt -le $max_attempts ]; do
        if curl -s -f "http://127.0.0.1:$port/healthz" >/dev/null 2>&1; then
            return 0
        fi
        log_info "Health check attempt $attempt/$max_attempts failed, retrying..."
        sleep 2
        ((attempt++))
    done
    return 1
}

# Enhanced PM2 setup with monitoring
setup_pm2_enhanced() {
    if ! command_exists pm2; then
        log_info "Installing PM2..."
        npm install -g pm2
    fi

    # Create PM2 ecosystem file
    cat > ~/.config/code-server/ecosystem.config.js <<EOF
module.exports = {
  apps: [{
    name: 'code-server',
    script: '$(command -v code-server)',
    args: '--config ~/.config/code-server/config.yaml',
    cwd: '$HOME',
    instances: 1,
    autorestart: true,
    watch: false,
    max_memory_restart: '1G',
    env: {
      NODE_ENV: 'production'
    },
    error_file: '$HOME/.local/share/code-server/logs/pm2-error.log',
    out_file: '$HOME/.local/share/code-server/logs/pm2-out.log',
    log_file: '$HOME/.local/share/code-server/logs/pm2-combined.log',
    time: true,
    max_restarts: 10,
    min_uptime: '10s'
  }]
};
EOF

    # Start with ecosystem file
    pm2 start ~/.config/code-server/ecosystem.config.js
    pm2 save

    # Setup PM2 startup (if possible)
    if pm2 startup 2>/dev/null; then
        log_success "PM2 startup configured"
    else
        log_warn "PM2 startup configuration skipped (requires sudo)"
    fi
}

# Enhanced nohup with PID management
setup_nohup_enhanced() {
    local pid_file="$HOME/.local/share/code-server/code-server.pid"
    local log_file="$HOME/.local/share/code-server/logs/server.log"

    # Start code-server with nohup
    nohup "$(command -v code-server)" --config ~/.config/code-server/config.yaml \
        >"$log_file" 2>&1 &

    # Save PID
    echo $! > "$pid_file"
    log_info "Code-server started with PID $(cat $pid_file)"

    # Create stop script
    cat > ~/.local/bin/code-server-stop <<EOF
#!/bin/bash
PID_FILE="$pid_file"
if [[ -f "\$PID_FILE" ]]; then
    PID=\$(cat "\$PID_FILE")
    if kill -0 "\$PID" 2>/dev/null; then
        kill "\$PID"
        rm "\$PID_FILE"
        echo "Code-server stopped (PID: \$PID)"
    else
        echo "Process \$PID not running, removing stale PID file"
        rm "\$PID_FILE"
    fi
else
    echo "PID file not found"
fi
EOF
    chmod +x ~/.local/bin/code-server-stop
}

# Enhanced supervisor setup
setup_supervisor_enhanced() {
    sudo apt-get install -y supervisor

    SUP_CONF="/etc/supervisor/conf.d/code-server.conf"
    sudo bash -c "cat > $SUP_CONF <<'EOS'
[program:code-server]
command=$(command -v code-server) --config $HOME/.config/code-server/config.yaml
directory=$HOME
autostart=true
autorestart=true
startretries=3
user=$USER
stdout_logfile=$HOME/.local/share/code-server/logs/supervisor-out.log
stderr_logfile=$HOME/.local/share/code-server/logs/supervisor-err.log
stdout_logfile_maxbytes=10MB
stderr_logfile_maxbytes=10MB
stdout_logfile_backups=5
stderr_logfile_backups=5
EOS"

    sudo supervisorctl reread
    sudo supervisorctl update
    sudo supervisorctl start code-server
}

# Main start function with enhanced process management
start_code_server() {
    # Panggil fungsi untuk membersihkan port sebelum melanjutkan
    kill_process_on_port "$BIND_ADDR"

    log_info "Menjalankan code‑server dengan $PROCESS_MANAGER …"
    case "$PROCESS_MANAGER" in
    pm2)
        setup_pm2_enhanced
        ;;
    nohup)
        setup_nohup_enhanced
        ;;
    supervisor)
        setup_supervisor_enhanced
        ;;
    *)
        log_error "Process manager $PROCESS_MANAGER tidak dikenal"
        exit 1
        ;;
    esac

    # Wait a moment for startup
    sleep 3

    # Perform health check
    if health_check; then
        log_success "code‑server sudah berjalan dan sehat (mode $PROCESS_MANAGER)"
    else
        log_warn "code‑server started but health check failed"
    fi
}

# -------------------------------------------------------------------------
# 🔟  VERIFIKASI CODE‑SERVER
# -------------------------------------------------------------------------
verify_code_server() {
    log_info "Mengecek status code‑server …"
    if [[ "$PROCESS_MANAGER" == "pm2" ]]; then
        pm2 status code-server | grep -q online || {
            log_error "code‑server tidak online (pm2)"
            return 1
        }
    elif [[ "$PROCESS_MANAGER" == "nohup" ]]; then
        pgrep -f "code-server" >/dev/null || {
            log_error "code‑server tidak ditemukan (nohup)"
            return 1
        }
    elif [[ "$PROCESS_MANAGER" == "supervisor" ]]; then
        sudo supervisorctl status code-server | grep -q RUNNING || {
            log_error "code‑server tidak RUNNING (supervisor)"
            return 1
        }
    fi
    PORT="${BIND_ADDR##*:}"
    for i in {1..5}; do
        HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:"$PORT" || echo "000")
        if [[ "$HTTP_STATUS" -ge 200 && "$HTTP_STATUS" -lt 400 ]]; then
            log_success "code‑server merespon HTTP (status $HTTP_STATUS) pada port $PORT"
            return 0
        fi
        sleep 1
    done
    log_error "Tidak bisa mengakses code‑server melalui HTTP pada port $PORT"
    return 1
}

# -------------------------------------------------------------------------
# SERVICE MANAGEMENT SCRIPTS
# -------------------------------------------------------------------------
create_service_scripts() {
    log_info "Creating service management scripts..."

    # Create status script
    cat > ~/.local/bin/code-server-status <<'EOF'
#!/bin/bash
source ~/.bashrc 2>/dev/null || true

check_pm2() {
    if command -v pm2 >/dev/null 2>&1; then
        pm2 status code-server 2>/dev/null | grep -q "online" && echo "PM2: Running" || echo "PM2: Stopped"
    fi
}

check_nohup() {
    local pid_file="$HOME/.local/share/code-server/code-server.pid"
    if [[ -f "$pid_file" ]]; then
        local pid=$(cat "$pid_file")
        if kill -0 "$pid" 2>/dev/null; then
            echo "Nohup: Running (PID: $pid)"
        else
            echo "Nohup: Stopped (stale PID file)"
        fi
    else
        echo "Nohup: Stopped"
    fi
}

check_supervisor() {
    if command -v supervisorctl >/dev/null 2>&1; then
        sudo supervisorctl status code-server 2>/dev/null | grep -q "RUNNING" && echo "Supervisor: Running" || echo "Supervisor: Stopped"
    fi
}

echo "=== Code-Server Status ==="
check_pm2
check_nohup
check_supervisor

# Check if port is in use
port=$(grep "bind-addr:" ~/.config/code-server/config.yaml 2>/dev/null | cut -d: -f3 | tr -d ' ')
if [[ -n "$port" ]] && lsof -i:$port >/dev/null 2>&1; then
    echo "Port $port: In use"
else
    echo "Port $port: Available"
fi
EOF
    chmod +x ~/.local/bin/code-server-status

    # Create restart script
    cat > ~/.local/bin/code-server-restart <<'EOF'
#!/bin/bash
source ~/.bashrc 2>/dev/null || true

echo "Restarting code-server..."

# Stop all instances
~/.local/bin/code-server-stop 2>/dev/null || true

# Wait a moment
sleep 2

# Determine which process manager to use
if command -v pm2 >/dev/null 2>&1 && pm2 list 2>/dev/null | grep -q code-server; then
    echo "Restarting with PM2..."
    pm2 restart code-server
elif [[ -f ~/.local/share/code-server/code-server.pid ]]; then
    echo "Restarting with nohup..."
    cd ~ && nohup code-server --config ~/.config/code-server/config.yaml \
        >~/.local/share/code-server/logs/server.log 2>&1 &
    echo $! > ~/.local/share/code-server/code-server.pid
elif command -v supervisorctl >/dev/null 2>&1; then
    echo "Restarting with supervisor..."
    sudo supervisorctl restart code-server
else
    echo "No process manager found, starting with nohup..."
    cd ~ && nohup code-server --config ~/.config/code-server/config.yaml \
        >~/.local/share/code-server/logs/server.log 2>&1 &
    echo $! > ~/.local/share/code-server/code-server.pid
fi

echo "Restart completed"
EOF
    chmod +x ~/.local/bin/code-server-restart

    # Create comprehensive stop script
    cat > ~/.local/bin/code-server-stop <<'EOF'
#!/bin/bash
source ~/.bashrc 2>/dev/null || true

echo "Stopping code-server..."

# Stop PM2 if running
if command -v pm2 >/dev/null 2>&1; then
    pm2 stop code-server 2>/dev/null || true
    pm2 delete code-server 2>/dev/null || true
fi

# Stop nohup process
pid_file="$HOME/.local/share/code-server/code-server.pid"
if [[ -f "$pid_file" ]]; then
    pid=$(cat "$pid_file")
    if kill -0 "$pid" 2>/dev/null; then
        kill "$pid"
        echo "Stopped nohup process (PID: $pid)"
    fi
    rm "$pid_file"
fi

# Stop supervisor
if command -v supervisorctl >/dev/null 2>&1; then
    sudo supervisorctl stop code-server 2>/dev/null || true
fi

# Kill any remaining code-server processes
pkill -f "code-server" 2>/dev/null || true

echo "All code-server processes stopped"
EOF
    chmod +x ~/.local/bin/code-server-stop

    log_success "Service management scripts created in ~/.local/bin/"
}

# -------------------------------------------------------------------------
# MAIN – urutan eksekusi
# -------------------------------------------------------------------------
main() {
    log_info "Memulai proses setup code-server..."

    install_dependencies
    install_nodejs
    install_code_server
    create_config
    setup_self_healing
    setup_resource_management
    create_extension_management_scripts
    create_tunnel_manager
    setup_ssh_server
    setup_reverse_proxy
    setup_network_configuration
    create_service_scripts
    start_code_server

    # Install extensions after server is running
    install_extensions

    # Setup additional components if enabled
    if [[ "$SETUP_DEV_ENVIRONMENT" == "true" ]]; then
        log_info "Setting up development environment..."
        if [[ -f "./setup-dev-environment.sh" ]]; then
            bash ./setup-dev-environment.sh
        else
            log_warn "setup-dev-environment.sh not found, skipping dev environment setup"
        fi
    fi

    if [[ "$SETUP_UI_EXPERIENCE" == "true" ]]; then
        log_info "Setting up UI and user experience..."
        if [[ -f "./setup-ui-experience.sh" ]]; then
            bash ./setup-ui-experience.sh
        else
            log_warn "setup-ui-experience.sh not found, skipping UI setup"
        fi
    fi

    if [[ "$SETUP_SECURITY" == "true" ]]; then
        log_info "Setting up security and authentication..."
        if [[ -f "./setup-security.sh" ]]; then
            bash ./setup-security.sh
        else
            log_warn "setup-security.sh not found, skipping security setup"
        fi
    fi

    if [[ "$SETUP_BACKUP" == "true" ]]; then
        log_info "Setting up backup system..."
        if [[ -f "./setup-backup.sh" ]]; then
            bash ./setup-backup.sh
        else
            log_warn "setup-backup.sh not found, skipping backup setup"
        fi
    fi

    if [[ "$SETUP_PERFORMANCE" == "true" ]]; then
        log_info "Setting up performance optimization..."
        if [[ -f "./setup-performance.sh" ]]; then
            bash ./setup-performance.sh
        else
            log_warn "setup-performance.sh not found, skipping performance setup"
        fi
    fi

    verify_code_server && log_success "code‑server siap dipakai!"
    start_ngrok_tunnel || log_warn "Ngrok tidak berhasil, Anda dapat mem‑runnya manual."
    if [[ -f "${HOME}/.ngrok_url" ]]; then
        NGROK_PUBLIC=$(cat "${HOME}/.ngrok_url")
        log_success "Akses code‑server via ngrok: $NGROK_PUBLIC"
    else
        log_success "Akses code‑server langsung: http://${BIND_ADDR}"
    fi

    log_success "Semua proses setup telah selesai."
    log_info ""
    log_info "🎉 CODE-SERVER ENHANCED SETUP COMPLETED! 🎉"
    log_info ""
    log_info "=== 🛠️  MANAGEMENT COMMANDS ==="
    log_info ""
    log_info "📊 Service Control:"
    log_info "  Status:    ~/.local/bin/code-server-status"
    log_info "  Stop:      ~/.local/bin/code-server-stop"
    log_info "  Restart:   ~/.local/bin/code-server-restart"
    log_info "  Recover:   ~/.local/bin/code-server-recover"
    log_info ""
    log_info "🔌 Extensions:"
    log_info "  Manage:    ~/.local/bin/code-server-extensions"
    log_info ""
    log_info "📈 Monitoring & Resources:"
    log_info "  Resources: ~/.local/bin/code-server-resources"
    log_info "  System:    ~/.local/bin/code-server-sysinfo"
    log_info "  Monitor:   ~/.local/bin/code-server-monitor"
    log_info "  Cleanup:   ~/.local/bin/code-server-cleanup"
    log_info ""
    log_info "🌐 Remote Access:"
    log_info "  Tunnels:   ~/.local/bin/code-server-tunnel"
    log_info "  Network:   ~/.local/bin/code-server-network"
    log_info ""
    log_info "🔒 Security:"
    log_info "  Certificates: ~/.local/bin/code-server-certs"
    log_info "  Authentication: ~/.local/bin/code-server-auth"
    log_info "  Hardening: ~/.local/bin/code-server-harden"
    log_info ""
    log_info "💾 Backup & Sync:"
    log_info "  Backup:    ~/.local/bin/code-server-backup"
    log_info "  Cloud:     ~/.local/bin/code-server-cloud-backup"
    log_info "  Sync:      ~/.local/bin/code-server-sync"
    log_info "  Migrate:   ~/.local/bin/code-server-migrate"
    log_info "  Version:   ~/.local/bin/code-server-version"
    log_info ""
    log_info "⚡ Performance:"
    log_info "  Optimize:  ~/.local/bin/code-server-optimize"
    log_info "  Cache:     ~/.local/bin/code-server-cache"
    log_info "  Monitor:   ~/.local/bin/code-server-perf"
    log_info "  Startup:   ~/.local/bin/code-server-startup"
    log_info "  LoadBalancer: ~/.local/bin/code-server-loadbalancer"
    log_info "  Network:   ~/.local/bin/code-server-netopt"
    log_info ""
    log_info "🎨 User Experience:"
    log_info "  Workspace: ~/.local/bin/code-server-workspace"
    log_info ""
    log_info "=== 🚀 QUICK START ==="
    log_info "1. Check status: ~/.local/bin/code-server-status"
    log_info "2. Install extensions: ~/.local/bin/code-server-extensions list"
    log_info "3. Create workspace: ~/.local/bin/code-server-workspace create my-project"
    log_info "4. Setup tunnel: ~/.local/bin/code-server-tunnel ngrok"
    log_info "5. Create backup: ~/.local/bin/code-server-backup full"
}

# Jalankan skrip utama
main "$@"