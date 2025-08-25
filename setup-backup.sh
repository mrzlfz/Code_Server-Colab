#!/usr/bin/env bash
# =============================================================================
# Backup & Configuration Management for Code-Server
# Automated backup, restore, and configuration management system
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
# CONFIGURATION BACKUP SYSTEM
# -------------------------------------------------------------------------
setup_backup_system() {
    log_info "Setting up backup system..."
    
    # Create backup directories
    mkdir -p ~/.config/code-server/backups/{daily,weekly,monthly}
    mkdir -p ~/.local/share/code-server/backups
    
    # Create comprehensive backup script
    cat > ~/.local/bin/code-server-backup <<'EOF'
#!/bin/bash
BACKUP_BASE="$HOME/.config/code-server/backups"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

show_help() {
    echo "Code-Server Backup Manager"
    echo "Usage: $0 [command] [options]"
    echo ""
    echo "Commands:"
    echo "  full                     Create full backup"
    echo "  config                   Backup configuration only"
    echo "  extensions               Backup extensions only"
    echo "  workspace <path>         Backup specific workspace"
    echo "  list                     List available backups"
    echo "  restore <backup-file>    Restore from backup"
    echo "  cleanup                  Clean old backups"
    echo "  schedule                 Setup automated backups"
    echo ""
}

create_full_backup() {
    local backup_dir="$BACKUP_BASE/full-$TIMESTAMP"
    mkdir -p "$backup_dir"
    
    echo "Creating full backup..."
    
    # Backup configuration
    if [[ -d ~/.config/code-server ]]; then
        cp -r ~/.config/code-server "$backup_dir/config"
        echo "✓ Configuration backed up"
    fi
    
    # Backup user data
    if [[ -d ~/.local/share/code-server/User ]]; then
        cp -r ~/.local/share/code-server/User "$backup_dir/user-data"
        echo "✓ User data backed up"
    fi
    
    # Backup extensions
    if [[ -d ~/.local/share/code-server/extensions ]]; then
        cp -r ~/.local/share/code-server/extensions "$backup_dir/extensions"
        echo "✓ Extensions backed up"
    fi
    
    # Create extensions list
    code-server --list-extensions > "$backup_dir/extensions-list.txt" 2>/dev/null || true
    
    # Create backup manifest
    cat > "$backup_dir/manifest.json" <<EOFMANIFEST
{
    "timestamp": "$TIMESTAMP",
    "type": "full",
    "hostname": "$(hostname)",
    "user": "$(whoami)",
    "code_server_version": "$(code-server --version 2>/dev/null | head -1 || echo 'unknown')",
    "includes": [
        "config",
        "user-data", 
        "extensions",
        "extensions-list"
    ]
}
EOFMANIFEST
    
    # Create archive
    tar -czf "$backup_dir.tar.gz" -C "$BACKUP_BASE" "$(basename "$backup_dir")"
    rm -rf "$backup_dir"
    
    echo "✓ Full backup created: $backup_dir.tar.gz"
}

backup_config_only() {
    local backup_dir="$BACKUP_BASE/config-$TIMESTAMP"
    mkdir -p "$backup_dir"
    
    echo "Creating configuration backup..."
    
    # Backup configuration files
    [[ -f ~/.config/code-server/config.yaml ]] && cp ~/.config/code-server/config.yaml "$backup_dir/"
    [[ -f ~/.local/share/code-server/User/settings.json ]] && cp ~/.local/share/code-server/User/settings.json "$backup_dir/"
    [[ -f ~/.local/share/code-server/User/keybindings.json ]] && cp ~/.local/share/code-server/User/keybindings.json "$backup_dir/"
    
    # Create manifest
    cat > "$backup_dir/manifest.json" <<EOFMANIFEST
{
    "timestamp": "$TIMESTAMP",
    "type": "config",
    "hostname": "$(hostname)",
    "user": "$(whoami)"
}
EOFMANIFEST
    
    tar -czf "$backup_dir.tar.gz" -C "$BACKUP_BASE" "$(basename "$backup_dir")"
    rm -rf "$backup_dir"
    
    echo "✓ Configuration backup created: $backup_dir.tar.gz"
}

backup_extensions() {
    local backup_dir="$BACKUP_BASE/extensions-$TIMESTAMP"
    mkdir -p "$backup_dir"
    
    echo "Creating extensions backup..."
    
    # Backup extensions directory
    if [[ -d ~/.local/share/code-server/extensions ]]; then
        cp -r ~/.local/share/code-server/extensions "$backup_dir/"
    fi
    
    # Create extensions list
    code-server --list-extensions > "$backup_dir/extensions-list.txt" 2>/dev/null || true
    
    # Create manifest
    cat > "$backup_dir/manifest.json" <<EOFMANIFEST
{
    "timestamp": "$TIMESTAMP",
    "type": "extensions",
    "hostname": "$(hostname)",
    "user": "$(whoami)",
    "extension_count": $(code-server --list-extensions 2>/dev/null | wc -l || echo 0)
}
EOFMANIFEST
    
    tar -czf "$backup_dir.tar.gz" -C "$BACKUP_BASE" "$(basename "$backup_dir")"
    rm -rf "$backup_dir"
    
    echo "✓ Extensions backup created: $backup_dir.tar.gz"
}

backup_workspace() {
    local workspace_path="$1"
    if [[ -z "$workspace_path" || ! -d "$workspace_path" ]]; then
        echo "Error: Valid workspace path required"
        return 1
    fi
    
    local workspace_name=$(basename "$workspace_path")
    local backup_dir="$BACKUP_BASE/workspace-${workspace_name}-$TIMESTAMP"
    mkdir -p "$backup_dir"
    
    echo "Creating workspace backup for: $workspace_path"
    
    # Backup workspace (excluding common ignore patterns)
    rsync -av --exclude='.git' --exclude='node_modules' --exclude='*.log' \
          --exclude='.DS_Store' --exclude='Thumbs.db' \
          "$workspace_path/" "$backup_dir/workspace/"
    
    # Create manifest
    cat > "$backup_dir/manifest.json" <<EOFMANIFEST
{
    "timestamp": "$TIMESTAMP",
    "type": "workspace",
    "workspace_name": "$workspace_name",
    "workspace_path": "$workspace_path",
    "hostname": "$(hostname)",
    "user": "$(whoami)"
}
EOFMANIFEST
    
    tar -czf "$backup_dir.tar.gz" -C "$BACKUP_BASE" "$(basename "$backup_dir")"
    rm -rf "$backup_dir"
    
    echo "✓ Workspace backup created: $backup_dir.tar.gz"
}

list_backups() {
    echo "=== Available Backups ==="
    
    if [[ -d "$BACKUP_BASE" ]]; then
        find "$BACKUP_BASE" -name "*.tar.gz" -type f | sort -r | while read -r backup; do
            local basename=$(basename "$backup" .tar.gz)
            local size=$(du -h "$backup" | cut -f1)
            local date=$(stat -c %y "$backup" 2>/dev/null | cut -d' ' -f1 || echo "unknown")
            echo "$basename ($size, $date)"
        done
    else
        echo "No backups found"
    fi
}

restore_backup() {
    local backup_file="$1"
    if [[ -z "$backup_file" ]]; then
        echo "Error: Backup file required"
        return 1
    fi
    
    if [[ ! -f "$backup_file" ]]; then
        # Try to find in backup directory
        backup_file="$BACKUP_BASE/$backup_file"
        if [[ ! -f "$backup_file" ]]; then
            echo "Error: Backup file not found: $backup_file"
            return 1
        fi
    fi
    
    echo "Restoring from backup: $backup_file"
    
    # Create temporary directory
    local temp_dir="/tmp/code-server-restore-$$"
    mkdir -p "$temp_dir"
    
    # Extract backup
    tar -xzf "$backup_file" -C "$temp_dir"
    
    # Find the extracted directory
    local extracted_dir=$(find "$temp_dir" -maxdepth 1 -type d | grep -v "^$temp_dir$" | head -1)
    
    if [[ -z "$extracted_dir" ]]; then
        echo "Error: Could not find extracted backup directory"
        rm -rf "$temp_dir"
        return 1
    fi
    
    # Restore based on backup type
    if [[ -f "$extracted_dir/manifest.json" ]]; then
        local backup_type=$(jq -r '.type' "$extracted_dir/manifest.json" 2>/dev/null || echo "unknown")
        echo "Backup type: $backup_type"
    fi
    
    # Stop code-server before restore
    ~/.local/bin/code-server-stop 2>/dev/null || true
    
    # Restore configuration
    if [[ -d "$extracted_dir/config" ]]; then
        cp -r "$extracted_dir/config"/* ~/.config/code-server/ 2>/dev/null || true
        echo "✓ Configuration restored"
    fi
    
    # Restore user data
    if [[ -d "$extracted_dir/user-data" ]]; then
        mkdir -p ~/.local/share/code-server/User
        cp -r "$extracted_dir/user-data"/* ~/.local/share/code-server/User/ 2>/dev/null || true
        echo "✓ User data restored"
    fi
    
    # Restore extensions
    if [[ -d "$extracted_dir/extensions" ]]; then
        mkdir -p ~/.local/share/code-server
        cp -r "$extracted_dir/extensions" ~/.local/share/code-server/ 2>/dev/null || true
        echo "✓ Extensions restored"
    fi
    
    # Restore extensions from list
    if [[ -f "$extracted_dir/extensions-list.txt" ]]; then
        echo "Reinstalling extensions..."
        while read -r ext; do
            [[ -n "$ext" ]] && code-server --install-extension "$ext" 2>/dev/null || true
        done < "$extracted_dir/extensions-list.txt"
        echo "✓ Extensions reinstalled"
    fi
    
    # Cleanup
    rm -rf "$temp_dir"
    
    echo "✓ Restore completed"
    echo "Restart code-server to apply changes"
}

cleanup_old_backups() {
    echo "Cleaning up old backups..."
    
    # Keep last 7 daily backups
    find "$BACKUP_BASE" -name "full-*.tar.gz" -type f -mtime +7 -delete 2>/dev/null || true
    find "$BACKUP_BASE" -name "config-*.tar.gz" -type f -mtime +7 -delete 2>/dev/null || true
    
    # Keep last 4 weekly backups (older than 28 days)
    find "$BACKUP_BASE" -name "extensions-*.tar.gz" -type f -mtime +28 -delete 2>/dev/null || true
    
    # Keep last 12 monthly backups (older than 365 days)
    find "$BACKUP_BASE" -name "workspace-*.tar.gz" -type f -mtime +365 -delete 2>/dev/null || true
    
    echo "✓ Cleanup completed"
}

setup_scheduled_backups() {
    echo "Setting up scheduled backups..."
    
    # Create cron job for daily config backup
    (crontab -l 2>/dev/null || true; echo "0 2 * * * $HOME/.local/bin/code-server-backup config >/dev/null 2>&1") | crontab -
    
    # Create cron job for weekly full backup
    (crontab -l 2>/dev/null || true; echo "0 3 * * 0 $HOME/.local/bin/code-server-backup full >/dev/null 2>&1") | crontab -
    
    # Create cron job for monthly cleanup
    (crontab -l 2>/dev/null || true; echo "0 4 1 * * $HOME/.local/bin/code-server-backup cleanup >/dev/null 2>&1") | crontab -
    
    echo "✓ Scheduled backups configured:"
    echo "  - Daily config backup at 2:00 AM"
    echo "  - Weekly full backup at 3:00 AM on Sunday"
    echo "  - Monthly cleanup at 4:00 AM on 1st day"
}

# Main command handling
case "${1:-}" in
    "full")
        create_full_backup
        ;;
    "config")
        backup_config_only
        ;;
    "extensions")
        backup_extensions
        ;;
    "workspace")
        backup_workspace "$2"
        ;;
    "list")
        list_backups
        ;;
    "restore")
        restore_backup "$2"
        ;;
    "cleanup")
        cleanup_old_backups
        ;;
    "schedule")
        setup_scheduled_backups
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
    chmod +x ~/.local/bin/code-server-backup
    
    log_success "Backup system configured"
}

# -------------------------------------------------------------------------
# CLOUD BACKUP INTEGRATION
# -------------------------------------------------------------------------
setup_cloud_backup() {
    log_info "Setting up cloud backup integration..."
    
    # Create cloud backup script
    cat > ~/.local/bin/code-server-cloud-backup <<'EOF'
#!/bin/bash
BACKUP_DIR="$HOME/.config/code-server/backups"
CLOUD_PROVIDERS=("s3" "gdrive" "dropbox" "onedrive")

show_help() {
    echo "Code-Server Cloud Backup"
    echo "Usage: $0 [command] [provider] [options]"
    echo ""
    echo "Providers: s3, gdrive, dropbox, onedrive"
    echo ""
    echo "Commands:"
    echo "  setup <provider>         Setup cloud provider"
    echo "  upload <provider> <file> Upload backup to cloud"
    echo "  download <provider>      Download latest backup"
    echo "  list <provider>          List cloud backups"
    echo "  sync <provider>          Sync local backups to cloud"
    echo ""
}

setup_s3() {
    echo "Setting up AWS S3 backup..."
    
    if ! command -v aws >/dev/null; then
        echo "Installing AWS CLI..."
        curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
        unzip awscliv2.zip
        sudo ./aws/install
        rm -rf aws awscliv2.zip
    fi
    
    echo "Configure AWS credentials:"
    aws configure
    
    echo "✓ AWS S3 setup completed"
}

setup_gdrive() {
    echo "Setting up Google Drive backup..."
    
    if ! command -v gdrive >/dev/null; then
        echo "Installing gdrive..."
        wget -O ~/.local/bin/gdrive "https://github.com/prasmussen/gdrive/releases/download/2.1.1/gdrive_2.1.1_linux_386.tar.gz"
        tar -xzf ~/.local/bin/gdrive -C ~/.local/bin/
        chmod +x ~/.local/bin/gdrive
    fi
    
    echo "Authenticate with Google Drive:"
    gdrive about
    
    echo "✓ Google Drive setup completed"
}

upload_to_s3() {
    local file="$1"
    local bucket="${S3_BUCKET:-code-server-backups}"
    
    if [[ ! -f "$file" ]]; then
        echo "Error: File not found: $file"
        return 1
    fi
    
    aws s3 cp "$file" "s3://$bucket/$(basename "$file")"
    echo "✓ Uploaded to S3: $file"
}

upload_to_gdrive() {
    local file="$1"
    
    if [[ ! -f "$file" ]]; then
        echo "Error: File not found: $file"
        return 1
    fi
    
    gdrive upload "$file"
    echo "✓ Uploaded to Google Drive: $file"
}

sync_backups() {
    local provider="$1"
    
    echo "Syncing backups to $provider..."
    
    find "$BACKUP_DIR" -name "*.tar.gz" -type f -mtime -7 | while read -r backup; do
        case "$provider" in
            "s3")
                upload_to_s3 "$backup"
                ;;
            "gdrive")
                upload_to_gdrive "$backup"
                ;;
            *)
                echo "Provider $provider not supported for sync"
                ;;
        esac
    done
    
    echo "✓ Sync completed"
}

# Main command handling
case "${1:-}" in
    "setup")
        case "$2" in
            "s3")
                setup_s3
                ;;
            "gdrive")
                setup_gdrive
                ;;
            *)
                echo "Provider not supported: $2"
                ;;
        esac
        ;;
    "upload")
        case "$2" in
            "s3")
                upload_to_s3 "$3"
                ;;
            "gdrive")
                upload_to_gdrive "$3"
                ;;
            *)
                echo "Provider not supported: $2"
                ;;
        esac
        ;;
    "sync")
        sync_backups "$2"
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
    chmod +x ~/.local/bin/code-server-cloud-backup
    
    log_success "Cloud backup integration configured"
}

# -------------------------------------------------------------------------
# MIGRATION TOOLS
# -------------------------------------------------------------------------
setup_migration_tools() {
    log_info "Setting up migration tools..."

    # Create migration script
    cat > ~/.local/bin/code-server-migrate <<'EOF'
#!/bin/bash
show_help() {
    echo "Code-Server Migration Tools"
    echo "Usage: $0 [command] [options]"
    echo ""
    echo "Commands:"
    echo "  export <target>          Export configuration to target server"
    echo "  import <source>          Import configuration from source"
    echo "  sync <remote-host>       Sync with remote code-server instance"
    echo "  clone <source> <target>  Clone entire setup to new location"
    echo "  compare <host1> <host2>  Compare configurations between hosts"
    echo ""
}

export_to_remote() {
    local target="$1"
    if [[ -z "$target" ]]; then
        echo "Error: Target host required"
        return 1
    fi

    echo "Exporting configuration to $target..."

    # Create export package
    local export_file="/tmp/code-server-export-$(date +%Y%m%d-%H%M%S).tar.gz"
    ~/.local/bin/code-server-backup full

    # Find latest backup
    local latest_backup=$(ls -t ~/.config/code-server/backups/full-*.tar.gz | head -1)

    if [[ -n "$latest_backup" ]]; then
        cp "$latest_backup" "$export_file"

        # Transfer to remote host
        scp "$export_file" "$target:/tmp/"

        # Execute remote import
        ssh "$target" "
            if [[ -f ~/.local/bin/code-server-migrate ]]; then
                ~/.local/bin/code-server-migrate import /tmp/$(basename $export_file)
            else
                echo 'Migration tools not found on remote host'
            fi
        "

        # Cleanup
        rm "$export_file"

        echo "✓ Export completed to $target"
    else
        echo "✗ No backup found to export"
        return 1
    fi
}

import_from_backup() {
    local source="$1"
    if [[ -z "$source" || ! -f "$source" ]]; then
        echo "Error: Valid source backup file required"
        return 1
    fi

    echo "Importing configuration from $source..."

    # Use existing backup restore functionality
    ~/.local/bin/code-server-backup restore "$source"

    echo "✓ Import completed"
}

sync_with_remote() {
    local remote_host="$1"
    if [[ -z "$remote_host" ]]; then
        echo "Error: Remote host required"
        return 1
    fi

    echo "Syncing with remote host: $remote_host"

    # Create local backup
    ~/.local/bin/code-server-backup config
    local local_backup=$(ls -t ~/.config/code-server/backups/config-*.tar.gz | head -1)

    # Get remote backup
    ssh "$remote_host" "~/.local/bin/code-server-backup config" 2>/dev/null || true
    local remote_backup="/tmp/remote-config-$(date +%Y%m%d-%H%M%S).tar.gz"
    scp "$remote_host:$(ssh $remote_host 'ls -t ~/.config/code-server/backups/config-*.tar.gz | head -1')" "$remote_backup" 2>/dev/null || true

    if [[ -f "$remote_backup" ]]; then
        echo "Comparing configurations..."

        # Extract and compare
        local temp_local="/tmp/local-config-$$"
        local temp_remote="/tmp/remote-config-$$"

        mkdir -p "$temp_local" "$temp_remote"
        tar -xzf "$local_backup" -C "$temp_local" 2>/dev/null || true
        tar -xzf "$remote_backup" -C "$temp_remote" 2>/dev/null || true

        # Compare settings
        if [[ -f "$temp_local"/*/settings.json && -f "$temp_remote"/*/settings.json ]]; then
            echo "Settings differences:"
            diff "$temp_local"/*/settings.json "$temp_remote"/*/settings.json || echo "No differences in settings"
        fi

        # Cleanup
        rm -rf "$temp_local" "$temp_remote" "$remote_backup"
    else
        echo "Could not retrieve remote configuration"
    fi

    echo "✓ Sync analysis completed"
}

clone_setup() {
    local source="$1"
    local target="$2"

    if [[ -z "$source" || -z "$target" ]]; then
        echo "Error: Source and target required"
        return 1
    fi

    echo "Cloning setup from $source to $target..."

    # Create full backup on source
    ssh "$source" "~/.local/bin/code-server-backup full" 2>/dev/null || {
        echo "Error: Could not create backup on source"
        return 1
    }

    # Get the backup file
    local remote_backup=$(ssh "$source" "ls -t ~/.config/code-server/backups/full-*.tar.gz | head -1")
    local local_backup="/tmp/clone-backup-$(date +%Y%m%d-%H%M%S).tar.gz"

    scp "$source:$remote_backup" "$local_backup"

    # Transfer to target and restore
    scp "$local_backup" "$target:/tmp/"

    ssh "$target" "
        # Install code-server if not present
        if ! command -v code-server >/dev/null 2>&1; then
            echo 'Installing code-server on target...'
            curl -fsSL https://code-server.dev/install.sh | sh
        fi

        # Restore backup
        if [[ -f ~/.local/bin/code-server-backup ]]; then
            ~/.local/bin/code-server-backup restore /tmp/$(basename $local_backup)
        else
            echo 'Backup tools not found on target'
        fi
    "

    # Cleanup
    rm "$local_backup"

    echo "✓ Clone completed from $source to $target"
}

compare_hosts() {
    local host1="$1"
    local host2="$2"

    if [[ -z "$host1" || -z "$host2" ]]; then
        echo "Error: Two hosts required for comparison"
        return 1
    fi

    echo "Comparing configurations between $host1 and $host2..."

    # Get configurations from both hosts
    local config1="/tmp/config1-$(date +%Y%m%d-%H%M%S).tar.gz"
    local config2="/tmp/config2-$(date +%Y%m%d-%H%M%S).tar.gz"

    # Create backups on both hosts
    ssh "$host1" "~/.local/bin/code-server-backup config" 2>/dev/null || true
    ssh "$host2" "~/.local/bin/code-server-backup config" 2>/dev/null || true

    # Download configurations
    scp "$host1:$(ssh $host1 'ls -t ~/.config/code-server/backups/config-*.tar.gz | head -1')" "$config1" 2>/dev/null || true
    scp "$host2:$(ssh $host2 'ls -t ~/.config/code-server/backups/config-*.tar.gz | head -1')" "$config2" 2>/dev/null || true

    if [[ -f "$config1" && -f "$config2" ]]; then
        # Extract and compare
        local temp1="/tmp/compare1-$$"
        local temp2="/tmp/compare2-$$"

        mkdir -p "$temp1" "$temp2"
        tar -xzf "$config1" -C "$temp1" 2>/dev/null || true
        tar -xzf "$config2" -C "$temp2" 2>/dev/null || true

        echo "=== Configuration Comparison ==="
        echo "Host 1: $host1"
        echo "Host 2: $host2"
        echo ""

        # Compare main config
        if [[ -f "$temp1"/*/config.yaml && -f "$temp2"/*/config.yaml ]]; then
            echo "Main Configuration Differences:"
            diff "$temp1"/*/config.yaml "$temp2"/*/config.yaml || echo "No differences in main config"
            echo ""
        fi

        # Compare settings
        if [[ -f "$temp1"/*/settings.json && -f "$temp2"/*/settings.json ]]; then
            echo "Settings Differences:"
            diff "$temp1"/*/settings.json "$temp2"/*/settings.json || echo "No differences in settings"
            echo ""
        fi

        # Compare extensions
        if [[ -f "$temp1"/*/extensions-list.txt && -f "$temp2"/*/extensions-list.txt ]]; then
            echo "Extension Differences:"
            diff "$temp1"/*/extensions-list.txt "$temp2"/*/extensions-list.txt || echo "No differences in extensions"
        fi

        # Cleanup
        rm -rf "$temp1" "$temp2" "$config1" "$config2"
    else
        echo "Could not retrieve configurations from both hosts"
    fi

    echo "✓ Comparison completed"
}

# Main command handling
case "${1:-}" in
    "export")
        export_to_remote "$2"
        ;;
    "import")
        import_from_backup "$2"
        ;;
    "sync")
        sync_with_remote "$2"
        ;;
    "clone")
        clone_setup "$2" "$3"
        ;;
    "compare")
        compare_hosts "$2" "$3"
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
    chmod +x ~/.local/bin/code-server-migrate

    log_success "Migration tools configured"
}

# -------------------------------------------------------------------------
# VERSION CONTROL FOR CONFIGURATIONS
# -------------------------------------------------------------------------
setup_config_version_control() {
    log_info "Setting up configuration version control..."

    # Create version control script
    cat > ~/.local/bin/code-server-version <<'EOF'
#!/bin/bash
CONFIG_REPO="$HOME/.config/code-server/git-repo"
CONFIG_DIR="$HOME/.config/code-server"
USER_DIR="$HOME/.local/share/code-server/User"

show_help() {
    echo "Code-Server Configuration Version Control"
    echo "Usage: $0 [command] [options]"
    echo ""
    echo "Commands:"
    echo "  init              Initialize version control"
    echo "  commit [message]  Commit current configuration"
    echo "  log               Show configuration history"
    echo "  diff              Show current changes"
    echo "  revert <commit>   Revert to specific commit"
    echo "  branch <name>     Create configuration branch"
    echo "  status            Show repository status"
    echo ""
}

init_version_control() {
    echo "Initializing configuration version control..."

    # Create git repository for configurations
    if [[ ! -d "$CONFIG_REPO" ]]; then
        mkdir -p "$CONFIG_REPO"
        cd "$CONFIG_REPO"
        git init

        # Create .gitignore
        cat > .gitignore <<'EOFGIT'
# Ignore sensitive files
*.log
*.pid
logs/
backups/
certs/key.pem
# Keep structure
!.gitkeep
EOFGIT

        # Initial commit
        git add .gitignore
        git commit -m "Initial configuration repository setup"

        echo "✓ Version control initialized"
    else
        echo "Version control already initialized"
    fi

    # Setup hooks for automatic commits
    cat > "$CONFIG_REPO/.git/hooks/post-commit" <<'EOFHOOK'
#!/bin/bash
echo "Configuration committed: $(date)"
EOFHOOK
    chmod +x "$CONFIG_REPO/.git/hooks/post-commit"
}

commit_config() {
    local message="${1:-Automatic configuration update}"

    if [[ ! -d "$CONFIG_REPO/.git" ]]; then
        echo "Version control not initialized. Run: $0 init"
        return 1
    fi

    echo "Committing configuration changes..."

    cd "$CONFIG_REPO"

    # Copy current configurations
    mkdir -p config user-data

    # Copy main config files
    [[ -f "$CONFIG_DIR/config.yaml" ]] && cp "$CONFIG_DIR/config.yaml" config/
    [[ -d "$CONFIG_DIR/extensions" ]] && cp -r "$CONFIG_DIR/extensions" config/ 2>/dev/null || true

    # Copy user data
    [[ -f "$USER_DIR/settings.json" ]] && cp "$USER_DIR/settings.json" user-data/
    [[ -f "$USER_DIR/keybindings.json" ]] && cp "$USER_DIR/keybindings.json" user-data/

    # Create extensions snapshot
    code-server --list-extensions > extensions-list.txt 2>/dev/null || true

    # Create system info
    cat > system-info.txt <<EOFINFO
Timestamp: $(date -Iseconds)
Hostname: $(hostname)
User: $(whoami)
Code-Server Version: $(code-server --version 2>/dev/null | head -1 || echo 'unknown')
Node Version: $(node --version 2>/dev/null || echo 'unknown')
OS: $(uname -a)
EOFINFO

    # Add and commit changes
    git add .

    if git diff --staged --quiet; then
        echo "No configuration changes to commit"
    else
        git commit -m "$message"
        echo "✓ Configuration committed: $message"
    fi
}

show_log() {
    if [[ ! -d "$CONFIG_REPO/.git" ]]; then
        echo "Version control not initialized"
        return 1
    fi

    cd "$CONFIG_REPO"
    echo "=== Configuration History ==="
    git log --oneline --graph --decorate -10
}

show_diff() {
    if [[ ! -d "$CONFIG_REPO/.git" ]]; then
        echo "Version control not initialized"
        return 1
    fi

    # Update current state
    commit_config "Temporary commit for diff" >/dev/null 2>&1

    cd "$CONFIG_REPO"
    echo "=== Configuration Changes ==="
    git diff HEAD~1 HEAD
}

revert_to_commit() {
    local commit="$1"
    if [[ -z "$commit" ]]; then
        echo "Error: Commit hash required"
        return 1
    fi

    if [[ ! -d "$CONFIG_REPO/.git" ]]; then
        echo "Version control not initialized"
        return 1
    fi

    echo "Reverting configuration to commit: $commit"

    cd "$CONFIG_REPO"

    # Create backup of current state
    commit_config "Backup before revert to $commit"

    # Checkout specific commit
    git checkout "$commit" -- .

    # Restore configurations
    [[ -f config/config.yaml ]] && cp config/config.yaml "$CONFIG_DIR/"
    [[ -f user-data/settings.json ]] && cp user-data/settings.json "$USER_DIR/"
    [[ -f user-data/keybindings.json ]] && cp user-data/keybindings.json "$USER_DIR/"

    # Restore extensions
    if [[ -f extensions-list.txt ]]; then
        echo "Restoring extensions..."
        while read -r ext; do
            [[ -n "$ext" ]] && code-server --install-extension "$ext" 2>/dev/null || true
        done < extensions-list.txt
    fi

    # Commit the revert
    git add .
    git commit -m "Reverted configuration to $commit"

    echo "✓ Configuration reverted to $commit"
    echo "Restart code-server to apply changes"
}

create_branch() {
    local branch_name="$1"
    if [[ -z "$branch_name" ]]; then
        echo "Error: Branch name required"
        return 1
    fi

    if [[ ! -d "$CONFIG_REPO/.git" ]]; then
        echo "Version control not initialized"
        return 1
    fi

    cd "$CONFIG_REPO"

    # Commit current state
    commit_config "Pre-branch commit"

    # Create and switch to new branch
    git checkout -b "$branch_name"

    echo "✓ Created and switched to branch: $branch_name"
}

show_status() {
    if [[ ! -d "$CONFIG_REPO/.git" ]]; then
        echo "Version control not initialized"
        return 1
    fi

    cd "$CONFIG_REPO"
    echo "=== Repository Status ==="
    echo "Current branch: $(git branch --show-current)"
    echo "Last commit: $(git log -1 --format='%h - %s (%cr)')"
    echo ""
    git status --short
}

# Main command handling
case "${1:-}" in
    "init")
        init_version_control
        ;;
    "commit")
        commit_config "$2"
        ;;
    "log")
        show_log
        ;;
    "diff")
        show_diff
        ;;
    "revert")
        revert_to_commit "$2"
        ;;
    "branch")
        create_branch "$2"
        ;;
    "status")
        show_status
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
    chmod +x ~/.local/bin/code-server-version

    # Initialize version control
    ~/.local/bin/code-server-version init

    log_success "Configuration version control configured"
}

# -------------------------------------------------------------------------
# MAIN EXECUTION
# -------------------------------------------------------------------------
main() {
    log_info "Setting up Backup & Configuration Management..."

    setup_backup_system
    setup_cloud_backup
    setup_migration_tools
    setup_config_version_control

    # Create initial backup
    ~/.local/bin/code-server-backup config

    # Create initial version control commit
    ~/.local/bin/code-server-version commit "Initial configuration setup"

    log_success "Backup & Configuration Management setup completed!"
    log_info ""
    log_info "Backup & Migration Commands:"
    log_info "  Local Backup: ~/.local/bin/code-server-backup"
    log_info "  Cloud Backup: ~/.local/bin/code-server-cloud-backup"
    log_info "  Migration: ~/.local/bin/code-server-migrate"
    log_info "  Version Control: ~/.local/bin/code-server-version"
}

# Run main function
main "$@"
