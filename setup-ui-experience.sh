#!/usr/bin/env bash
# =============================================================================
# User Experience & Interface Setup for Code-Server
# Themes, settings sync, keybindings, and desktop-like interface features
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
# THEME AND APPEARANCE SYSTEM
# -------------------------------------------------------------------------
setup_themes_and_appearance() {
    log_info "Setting up themes and appearance..."
    
    # Create themes directory
    mkdir -p ~/.local/share/code-server/User/themes
    
    # Enhanced settings.json with appearance configurations
    cat > ~/.local/share/code-server/User/settings.json <<'EOF'
{
    "workbench.colorTheme": "Default Dark+",
    "workbench.iconTheme": "vs-seti",
    "workbench.productIconTheme": "Default",
    "workbench.startupEditor": "welcomePage",
    "workbench.sideBar.location": "left",
    "workbench.panel.defaultLocation": "bottom",
    "workbench.activityBar.visible": true,
    "workbench.statusBar.visible": true,
    "workbench.menuBar.visibility": "toggle",
    "workbench.editor.showTabs": true,
    "workbench.editor.tabCloseButton": "right",
    "workbench.editor.tabSizing": "fit",
    "workbench.editor.wrapTabs": false,
    "workbench.tree.indent": 8,
    "workbench.tree.renderIndentGuides": "always",
    
    "editor.fontSize": 14,
    "editor.fontFamily": "'Fira Code', 'Cascadia Code', 'JetBrains Mono', monospace",
    "editor.fontLigatures": true,
    "editor.lineHeight": 1.5,
    "editor.tabSize": 2,
    "editor.insertSpaces": true,
    "editor.detectIndentation": true,
    "editor.renderWhitespace": "boundary",
    "editor.renderControlCharacters": false,
    "editor.minimap.enabled": true,
    "editor.minimap.side": "right",
    "editor.wordWrap": "on",
    "editor.lineNumbers": "on",
    "editor.cursorStyle": "line",
    "editor.cursorBlinking": "blink",
    "editor.bracketPairColorization.enabled": true,
    "editor.guides.bracketPairs": true,
    "editor.smoothScrolling": true,
    "editor.mouseWheelZoom": true,
    
    "terminal.integrated.fontSize": 14,
    "terminal.integrated.fontFamily": "'Fira Code', 'Cascadia Code', monospace",
    "terminal.integrated.cursorBlinking": true,
    "terminal.integrated.cursorStyle": "line",
    "terminal.integrated.scrollback": 10000,
    "terminal.integrated.enableBell": false,
    "terminal.integrated.copyOnSelection": true,
    "terminal.integrated.rightClickBehavior": "copyPaste",
    
    "files.autoSave": "afterDelay",
    "files.autoSaveDelay": 1000,
    "files.trimTrailingWhitespace": true,
    "files.insertFinalNewline": true,
    "files.trimFinalNewlines": true,
    
    "git.enableSmartCommit": true,
    "git.confirmSync": false,
    "git.autofetch": true,
    
    "extensions.autoUpdate": true,
    "extensions.autoCheckUpdates": true,
    
    "breadcrumbs.enabled": true,
    "outline.showVariables": true,
    "problems.decorations.enabled": true,
    
    "search.showLineNumbers": true,
    "search.smartCase": true,
    
    "window.zoomLevel": 0,
    "window.menuBarVisibility": "toggle",
    "window.title": "${dirty}${activeEditorShort}${separator}${rootName}${separator}${appName}",
    
    "zenMode.centerLayout": true,
    "zenMode.hideLineNumbers": false,
    "zenMode.hideStatusBar": false
}
EOF
    
    # Create keybindings.json for desktop-like experience
    cat > ~/.local/share/code-server/User/keybindings.json <<'EOF'
[
    {
        "key": "ctrl+shift+`",
        "command": "workbench.action.terminal.new"
    },
    {
        "key": "ctrl+shift+c",
        "command": "workbench.action.terminal.openNativeConsole",
        "when": "!terminalFocus"
    },
    {
        "key": "ctrl+shift+v",
        "command": "workbench.action.terminal.paste",
        "when": "terminalFocus"
    },
    {
        "key": "ctrl+k ctrl+t",
        "command": "workbench.action.selectTheme"
    },
    {
        "key": "ctrl+k ctrl+i",
        "command": "workbench.action.selectIconTheme"
    },
    {
        "key": "ctrl+shift+p",
        "command": "workbench.action.showCommands"
    },
    {
        "key": "ctrl+shift+e",
        "command": "workbench.view.explorer"
    },
    {
        "key": "ctrl+shift+f",
        "command": "workbench.view.search"
    },
    {
        "key": "ctrl+shift+g",
        "command": "workbench.view.scm"
    },
    {
        "key": "ctrl+shift+d",
        "command": "workbench.view.debug"
    },
    {
        "key": "ctrl+shift+x",
        "command": "workbench.view.extensions"
    },
    {
        "key": "ctrl+b",
        "command": "workbench.action.toggleSidebarVisibility"
    },
    {
        "key": "ctrl+j",
        "command": "workbench.action.togglePanel"
    },
    {
        "key": "ctrl+shift+m",
        "command": "workbench.actions.view.problems"
    },
    {
        "key": "ctrl+shift+u",
        "command": "workbench.action.output.toggleOutput"
    },
    {
        "key": "ctrl+shift+y",
        "command": "workbench.debug.action.toggleRepl"
    },
    {
        "key": "f11",
        "command": "workbench.action.toggleZenMode"
    }
]
EOF
    
    log_success "Themes and appearance configured"
}

# -------------------------------------------------------------------------
# SETTINGS SYNCHRONIZATION
# -------------------------------------------------------------------------
setup_settings_sync() {
    log_info "Setting up settings synchronization..."
    
    # Create sync script
    cat > ~/.local/bin/code-server-sync <<'EOF'
#!/bin/bash
SYNC_DIR="$HOME/.config/code-server/sync"
USER_DIR="$HOME/.local/share/code-server/User"

show_help() {
    echo "Code-Server Settings Sync"
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  backup    Create backup of current settings"
    echo "  restore   Restore settings from backup"
    echo "  export    Export settings to file"
    echo "  import    Import settings from file"
    echo "  status    Show sync status"
    echo ""
}

backup_settings() {
    local backup_dir="$SYNC_DIR/backup-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$backup_dir"
    
    # Backup settings
    [[ -f "$USER_DIR/settings.json" ]] && cp "$USER_DIR/settings.json" "$backup_dir/"
    [[ -f "$USER_DIR/keybindings.json" ]] && cp "$USER_DIR/keybindings.json" "$backup_dir/"
    
    # Backup extensions list
    code-server --list-extensions > "$backup_dir/extensions.txt" 2>/dev/null || true
    
    echo "✓ Settings backed up to: $backup_dir"
}

restore_settings() {
    local backup_dir="$1"
    if [[ -z "$backup_dir" ]]; then
        backup_dir=$(ls -td "$SYNC_DIR"/backup-* 2>/dev/null | head -1)
    fi
    
    if [[ ! -d "$backup_dir" ]]; then
        echo "Error: Backup directory not found"
        return 1
    fi
    
    echo "Restoring settings from: $backup_dir"
    
    # Restore settings
    [[ -f "$backup_dir/settings.json" ]] && cp "$backup_dir/settings.json" "$USER_DIR/"
    [[ -f "$backup_dir/keybindings.json" ]] && cp "$backup_dir/keybindings.json" "$USER_DIR/"
    
    # Restore extensions
    if [[ -f "$backup_dir/extensions.txt" ]]; then
        while read -r ext; do
            [[ -n "$ext" ]] && code-server --install-extension "$ext" 2>/dev/null || true
        done < "$backup_dir/extensions.txt"
    fi
    
    echo "✓ Settings restored"
}

export_settings() {
    local export_file="${1:-code-server-settings-$(date +%Y%m%d).tar.gz}"
    local temp_dir="/tmp/code-server-export-$$"
    
    mkdir -p "$temp_dir"
    
    # Copy settings
    [[ -f "$USER_DIR/settings.json" ]] && cp "$USER_DIR/settings.json" "$temp_dir/"
    [[ -f "$USER_DIR/keybindings.json" ]] && cp "$USER_DIR/keybindings.json" "$temp_dir/"
    
    # Export extensions
    code-server --list-extensions > "$temp_dir/extensions.txt" 2>/dev/null || true
    
    # Create archive
    tar -czf "$export_file" -C "$temp_dir" .
    rm -rf "$temp_dir"
    
    echo "✓ Settings exported to: $export_file"
}

import_settings() {
    local import_file="$1"
    if [[ ! -f "$import_file" ]]; then
        echo "Error: Import file not found: $import_file"
        return 1
    fi
    
    local temp_dir="/tmp/code-server-import-$$"
    mkdir -p "$temp_dir"
    
    # Extract archive
    tar -xzf "$import_file" -C "$temp_dir"
    
    # Import settings
    [[ -f "$temp_dir/settings.json" ]] && cp "$temp_dir/settings.json" "$USER_DIR/"
    [[ -f "$temp_dir/keybindings.json" ]] && cp "$temp_dir/keybindings.json" "$USER_DIR/"
    
    # Import extensions
    if [[ -f "$temp_dir/extensions.txt" ]]; then
        while read -r ext; do
            [[ -n "$ext" ]] && code-server --install-extension "$ext" 2>/dev/null || true
        done < "$temp_dir/extensions.txt"
    fi
    
    rm -rf "$temp_dir"
    echo "✓ Settings imported from: $import_file"
}

show_status() {
    echo "=== Code-Server Settings Status ==="
    echo "User Directory: $USER_DIR"
    echo "Sync Directory: $SYNC_DIR"
    echo ""
    echo "Settings File: $([[ -f "$USER_DIR/settings.json" ]] && echo "✓ Found" || echo "✗ Missing")"
    echo "Keybindings File: $([[ -f "$USER_DIR/keybindings.json" ]] && echo "✓ Found" || echo "✗ Missing")"
    echo ""
    echo "Available Backups:"
    ls -la "$SYNC_DIR"/backup-* 2>/dev/null | tail -5 || echo "No backups found"
}

# Main command handling
case "${1:-}" in
    "backup")
        backup_settings
        ;;
    "restore")
        restore_settings "$2"
        ;;
    "export")
        export_settings "$2"
        ;;
    "import")
        import_settings "$2"
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
    chmod +x ~/.local/bin/code-server-sync
    
    # Create initial backup
    mkdir -p ~/.config/code-server/sync
    ~/.local/bin/code-server-sync backup
    
    log_success "Settings synchronization configured"
}

# -------------------------------------------------------------------------
# WORKSPACE MANAGEMENT
# -------------------------------------------------------------------------
setup_workspace_management() {
    log_info "Setting up workspace management..."
    
    # Create workspace templates directory
    mkdir -p ~/.config/code-server/workspace-templates
    
    # Create workspace manager script
    cat > ~/.local/bin/code-server-workspace <<'EOF'
#!/bin/bash
TEMPLATES_DIR="$HOME/.config/code-server/workspace-templates"
WORKSPACES_DIR="$HOME/workspaces"

show_help() {
    echo "Code-Server Workspace Manager"
    echo "Usage: $0 [command] [options]"
    echo ""
    echo "Commands:"
    echo "  create <name> [template]  Create new workspace"
    echo "  list                      List workspaces"
    echo "  open <name>              Open workspace"
    echo "  delete <name>            Delete workspace"
    echo "  template <name>          Create template from workspace"
    echo ""
}

create_workspace() {
    local name="$1"
    local template="$2"
    local workspace_dir="$WORKSPACES_DIR/$name"
    
    if [[ -z "$name" ]]; then
        echo "Error: Workspace name required"
        return 1
    fi
    
    if [[ -d "$workspace_dir" ]]; then
        echo "Error: Workspace '$name' already exists"
        return 1
    fi
    
    mkdir -p "$workspace_dir"
    
    # Apply template if specified
    if [[ -n "$template" && -d "$TEMPLATES_DIR/$template" ]]; then
        cp -r "$TEMPLATES_DIR/$template"/* "$workspace_dir/"
        echo "✓ Applied template: $template"
    else
        # Create basic workspace structure
        mkdir -p "$workspace_dir/.vscode"
        cat > "$workspace_dir/.vscode/settings.json" <<'EOFWS'
{
    "files.exclude": {
        "**/.git": true,
        "**/.DS_Store": true,
        "**/node_modules": true
    }
}
EOFWS
    fi
    
    echo "✓ Workspace '$name' created at: $workspace_dir"
}

list_workspaces() {
    echo "=== Available Workspaces ==="
    if [[ -d "$WORKSPACES_DIR" ]]; then
        ls -la "$WORKSPACES_DIR" | grep "^d" | awk '{print $9}' | grep -v "^\.$\|^\.\.$" || echo "No workspaces found"
    else
        echo "No workspaces directory found"
    fi
}

open_workspace() {
    local name="$1"
    local workspace_dir="$WORKSPACES_DIR/$name"
    
    if [[ -z "$name" ]]; then
        echo "Error: Workspace name required"
        return 1
    fi
    
    if [[ ! -d "$workspace_dir" ]]; then
        echo "Error: Workspace '$name' not found"
        return 1
    fi
    
    echo "Opening workspace: $name"
    echo "Directory: $workspace_dir"
    echo "Run: code-server '$workspace_dir'"
}

# Main command handling
case "${1:-}" in
    "create")
        create_workspace "$2" "$3"
        ;;
    "list"|"ls")
        list_workspaces
        ;;
    "open")
        open_workspace "$2"
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
    chmod +x ~/.local/bin/code-server-workspace
    
    # Create default workspace directory
    mkdir -p ~/workspaces
    
    log_success "Workspace management configured"
}

# -------------------------------------------------------------------------
# MAIN EXECUTION
# -------------------------------------------------------------------------
main() {
    log_info "Setting up User Experience & Interface..."
    
    setup_themes_and_appearance
    setup_settings_sync
    setup_workspace_management
    
    log_success "User Experience & Interface setup completed!"
}

# Run main function
main "$@"
