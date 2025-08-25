#!/usr/bin/env bash
# =============================================================================
# Development Environment Setup for Code-Server
# Enhanced terminal, debugging, Git integration, and development tools
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
# INTEGRATED TERMINAL ENHANCEMENT
# -------------------------------------------------------------------------
setup_terminal_enhancement() {
    log_info "Setting up enhanced terminal environment..."

    # Check if we're in a container environment
    local is_container=false
    if [[ -f /.dockerenv ]] || [[ -n "${CONTAINER:-}" ]] || [[ "$(hostname)" =~ ^[0-9a-f]{12}$ ]]; then
        is_container=true
        log_warn "Container environment detected, using container-optimized settings"
    fi

    # Ensure ~/.local/bin exists and is in PATH
    mkdir -p ~/.local/bin
    if ! echo "$PATH" | grep -q "$HOME/.local/bin"; then
        export PATH="$HOME/.local/bin:$PATH"
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
    fi

    # Install essential terminal tools
    log_info "Updating package lists..."

    # Use container-optimized apt settings
    export DEBIAN_FRONTEND=noninteractive
    export APT_LISTCHANGES_FRONTEND=none

    sudo apt-get update -qq 2>/dev/null || sudo apt-get update

    # Install packages in groups to avoid conflicts
    log_info "Installing terminal tools..."
    sudo apt-get install -y -qq \
        zsh fish tmux screen \
        htop neofetch \
        tree fd-find ripgrep bat \
        git-extras tig \
        python3-pip \
        curl wget jq \
        build-essential 2>/dev/null || {
        log_warn "Some terminal packages failed to install, trying individual installation..."

        # Try installing packages individually
        for pkg in zsh fish tmux screen htop neofetch tree fd-find ripgrep bat git-extras tig python3-pip curl wget jq build-essential; do
            if sudo apt-get install -y -qq "$pkg" 2>/dev/null; then
                log_info "✓ Installed: $pkg"
            else
                log_warn "✗ Failed to install: $pkg"
            fi
        done
    }

    # Handle Node.js separately to avoid conflicts
    log_info "Checking Node.js installation..."
    if command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1; then
        log_success "Node.js and npm already available"
        log_info "Node.js version: $(node --version)"
        log_info "npm version: $(npm --version)"
    else
        log_warn "Node.js/npm not found, but skipping installation to avoid conflicts"
        log_info "Node.js should be installed by the main setup script"
    fi

    # Handle Docker installation separately for containers
    if [[ "$is_container" == "false" ]]; then
        log_info "Installing Docker tools..."
        sudo apt-get install -y -qq docker.io docker-compose 2>/dev/null || {
            log_warn "Docker installation failed, continuing without Docker"
        }
    else
        log_info "Skipping Docker installation in container environment"
    fi

    # Install yq separately (not available in standard Ubuntu repos)
    if ! command -v yq >/dev/null 2>&1; then
        log_info "Installing yq from GitHub releases..."
        YQ_VERSION="v4.35.2"
        curl -L "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_amd64" -o ~/.local/bin/yq
        chmod +x ~/.local/bin/yq
        export PATH="$HOME/.local/bin:$PATH"
    fi

    # Install btop separately (might not be available in older Ubuntu versions)
    if ! command -v btop >/dev/null 2>&1; then
        log_info "btop not available in repositories, using htop instead"
    fi
    
    # Setup Oh My Zsh (optional, skip in containers)
    if [[ "$is_container" == "false" && ! -d ~/.oh-my-zsh ]]; then
        log_info "Installing Oh My Zsh..."
        if sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended 2>/dev/null; then
            log_success "Oh My Zsh installed successfully"
        else
            log_warn "Oh My Zsh installation failed, continuing without it"
        fi
    elif [[ "$is_container" == "true" ]]; then
        log_info "Skipping Oh My Zsh installation in container environment"
    else
        log_info "Oh My Zsh already installed"
    fi
    
    # Create enhanced shell configuration
    cat >> ~/.bashrc <<'EOF'

# Code-Server Development Environment
export EDITOR="code-server --wait"
export VISUAL="code-server --wait"

# Enhanced aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'

# Development aliases
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git log --oneline'
alias gd='git diff'

# Docker aliases
alias dps='docker ps'
alias dimg='docker images'
alias dlog='docker logs'
alias dexec='docker exec -it'

# Node.js aliases
alias ni='npm install'
alias ns='npm start'
alias nt='npm test'
alias nb='npm run build'

# Python aliases
alias py='python3'
alias pip='pip3'
alias venv='python3 -m venv'

# Enhanced prompt
PS1='\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
EOF
    
    # Create terminal configuration for code-server
    mkdir -p ~/.local/share/code-server/User
    cat > ~/.local/share/code-server/User/settings.json <<'EOF'
{
    "terminal.integrated.shell.linux": "/bin/bash",
    "terminal.integrated.fontSize": 14,
    "terminal.integrated.fontFamily": "monospace",
    "terminal.integrated.cursorBlinking": true,
    "terminal.integrated.cursorStyle": "line",
    "terminal.integrated.scrollback": 10000,
    "terminal.integrated.enableBell": false,
    "terminal.integrated.copyOnSelection": true,
    "terminal.integrated.rightClickBehavior": "copyPaste",
    "terminal.integrated.confirmOnExit": "hasChildProcesses",
    "terminal.integrated.enableMultiLinePasteWarning": false,
    "workbench.colorTheme": "Default Dark+",
    "editor.fontSize": 14,
    "editor.fontFamily": "monospace",
    "editor.tabSize": 2,
    "editor.insertSpaces": true,
    "editor.detectIndentation": true,
    "editor.renderWhitespace": "boundary",
    "editor.minimap.enabled": true,
    "editor.wordWrap": "on",
    "files.autoSave": "afterDelay",
    "files.autoSaveDelay": 1000,
    "git.enableSmartCommit": true,
    "git.confirmSync": false,
    "extensions.autoUpdate": true
}
EOF
    
    log_success "Terminal enhancement completed"
}

# -------------------------------------------------------------------------
# DEBUGGING SUPPORT SETUP
# -------------------------------------------------------------------------
setup_debugging_support() {
    log_info "Setting up debugging support..."

    # Check if we're in a container environment
    local is_container=false
    if [[ -f /.dockerenv ]] || [[ -n "${CONTAINER:-}" ]] || [[ "$(hostname)" =~ ^[0-9a-f]{12}$ ]]; then
        is_container=true
    fi

    # Install basic debugging tools
    log_info "Installing debugging tools..."
    sudo apt-get install -y -qq gdb lldb 2>/dev/null || {
        log_warn "Some debugging tools failed to install"
        # Try individual installation
        sudo apt-get install -y -qq gdb 2>/dev/null || log_warn "gdb installation failed"
        sudo apt-get install -y -qq lldb 2>/dev/null || log_warn "lldb installation failed"
    }

    # Install Python debugging support via pip (not apt)
    log_info "Installing Python debugging support..."
    if command -v pip3 >/dev/null 2>&1; then
        pip3 install --user debugpy 2>/dev/null || {
            log_warn "Failed to install debugpy via pip3"
        }
    else
        log_warn "pip3 not available, skipping Python debugging support"
    fi

    # Install Node.js debugging tools (if Node.js is available)
    if command -v npm >/dev/null 2>&1; then
        log_info "Installing Node.js debugging tools..."
        npm install -g node-inspect 2>/dev/null || {
            log_warn "Failed to install node-inspect, trying without -g flag"
            npm install node-inspect 2>/dev/null || log_warn "node-inspect installation failed"
        }
    else
        log_warn "npm not available, skipping Node.js debugging tools"
    fi
    
    # Create debug configurations directory
    mkdir -p ~/.local/share/code-server/User/globalStorage
    
    # Create launch.json template
    mkdir -p .vscode
    cat > .vscode/launch.json <<'EOF'
{
    "version": "0.2.0",
    "configurations": [
        {
            "name": "Node.js Debug",
            "type": "node",
            "request": "launch",
            "program": "${workspaceFolder}/index.js",
            "console": "integratedTerminal",
            "internalConsoleOptions": "neverOpen"
        },
        {
            "name": "Python Debug",
            "type": "python",
            "request": "launch",
            "program": "${file}",
            "console": "integratedTerminal"
        },
        {
            "name": "PHP Debug",
            "type": "php",
            "request": "launch",
            "program": "${file}",
            "cwd": "${workspaceFolder}",
            "port": 9000
        }
    ]
}
EOF
    
    log_success "Debugging support configured"
}

# -------------------------------------------------------------------------
# GIT INTEGRATION
# -------------------------------------------------------------------------
setup_git_integration() {
    log_info "Setting up Git integration..."
    
    # Install Git and related tools
    sudo apt-get install -y git git-extras tig gh
    
    # Configure Git (if not already configured)
    if [[ -z "$(git config --global user.name 2>/dev/null || true)" ]]; then
        log_info "Git not configured. Please run:"
        log_info "  git config --global user.name 'Your Name'"
        log_info "  git config --global user.email 'your.email@example.com'"
    fi
    
    # Create Git configuration for better integration
    git config --global core.editor "code-server --wait"
    git config --global merge.tool "code-server"
    git config --global diff.tool "code-server"
    
    # Create .gitconfig additions
    cat >> ~/.gitconfig <<'EOF'

[alias]
    st = status
    co = checkout
    br = branch
    ci = commit
    ca = commit -a
    ps = push
    pl = pull
    lg = log --oneline --graph --decorate --all
    unstage = reset HEAD --
    last = log -1 HEAD
    visual = !gitk

[color]
    ui = auto

[push]
    default = simple

[pull]
    rebase = false
EOF
    
    log_success "Git integration configured"
}

# -------------------------------------------------------------------------
# LANGUAGE SERVER PROTOCOL SETUP
# -------------------------------------------------------------------------
setup_language_servers() {
    log_info "Setting up Language Server Protocol support..."
    
    # Install language servers
    # TypeScript/JavaScript
    npm install -g typescript @typescript-eslint/parser @typescript-eslint/eslint-plugin
    
    # Python
    pip3 install pylsp-mypy python-lsp-server[all] black isort
    
    # PHP (requires Composer)
    if command -v composer >/dev/null 2>&1; then
        composer global require intelephense/intelephense
    fi
    
    # Go
    if command -v go >/dev/null 2>&1; then
        go install golang.org/x/tools/gopls@latest
    fi
    
    log_success "Language servers configured"
}

# -------------------------------------------------------------------------
# DEVELOPMENT TOOLS INTEGRATION
# -------------------------------------------------------------------------
setup_development_tools() {
    log_info "Setting up development tools..."

    # Check if we're in a container environment
    local is_container=false
    if [[ -f /.dockerenv ]] || [[ -n "${CONTAINER:-}" ]] || [[ "$(hostname)" =~ ^[0-9a-f]{12}$ ]]; then
        is_container=true
    fi

    # Database clients (install individually to avoid conflicts)
    log_info "Installing database clients..."
    for pkg in mysql-client postgresql-client redis-tools; do
        if sudo apt-get install -y -qq "$pkg" 2>/dev/null; then
            log_info "✓ Installed: $pkg"
        else
            log_warn "✗ Failed to install: $pkg"
        fi
    done

    # MongoDB clients (might not be available in all repositories)
    if sudo apt-get install -y -qq mongodb-clients 2>/dev/null; then
        log_info "✓ Installed: mongodb-clients"
    else
        log_warn "✗ mongodb-clients not available in repositories"
    fi

    # API testing tools
    log_info "Installing API testing tools..."
    sudo apt-get install -y -qq curl httpie 2>/dev/null || {
        log_warn "Some API testing tools failed to install"
        sudo apt-get install -y -qq curl 2>/dev/null || log_warn "curl installation failed"
        sudo apt-get install -y -qq httpie 2>/dev/null || log_warn "httpie installation failed"
    }
    
    # Container tools (skip in container environments)
    if [[ "$is_container" == "false" ]]; then
        log_info "Installing Docker tools..."
        sudo apt-get install -y docker.io docker-compose || {
            log_warn "Docker installation failed, continuing without Docker"
        }
        sudo usermod -aG docker $USER 2>/dev/null || {
            log_warn "Could not add user to docker group"
        }
    else
        log_info "Skipping Docker installation in container environment"
    fi
    
    # Build tools
    log_info "Installing build tools..."
    for pkg in make cmake gcc g++ python3-dev pkg-config; do
        if sudo apt-get install -y -qq "$pkg" 2>/dev/null; then
            log_info "✓ Installed: $pkg"
        else
            log_warn "✗ Failed to install: $pkg"
        fi
    done
    
    log_success "Development tools configured"
}

# -------------------------------------------------------------------------
# MAIN EXECUTION
# -------------------------------------------------------------------------
main() {
    log_info "Setting up development environment for Code-Server..."
    
    setup_terminal_enhancement
    setup_debugging_support
    setup_git_integration
    setup_language_servers
    setup_development_tools
    
    log_success "Development environment setup completed!"
    log_info "Please restart your terminal or run 'source ~/.bashrc' to apply changes"
}

# Run main function
main "$@"
