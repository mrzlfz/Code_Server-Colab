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
    
    # Install essential terminal tools
    sudo apt-get update
    sudo apt-get install -y \
        zsh fish tmux screen \
        htop btop neofetch \
        tree fd-find ripgrep bat \
        git-extras tig \
        nodejs npm python3-pip \
        curl wget jq yq \
        docker.io docker-compose \
        build-essential
    
    # Setup Oh My Zsh (optional)
    if [[ ! -d ~/.oh-my-zsh ]]; then
        log_info "Installing Oh My Zsh..."
        sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended || true
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
    
    # Install debugging tools
    sudo apt-get install -y \
        gdb lldb \
        python3-debugpy \
        nodejs npm
    
    # Install Node.js debugging tools
    npm install -g node-inspect
    
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
    
    # Database clients
    sudo apt-get install -y \
        mysql-client postgresql-client \
        redis-tools mongodb-clients
    
    # API testing tools
    sudo apt-get install -y curl httpie
    
    # Container tools
    sudo apt-get install -y docker.io docker-compose
    sudo usermod -aG docker $USER || true
    
    # Build tools
    sudo apt-get install -y \
        make cmake \
        gcc g++ \
        python3-dev \
        pkg-config
    
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
