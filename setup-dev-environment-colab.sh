#!/usr/bin/env bash
# =============================================================================
# Development Environment Setup for Code-Server (Google Colab Optimized)
# Container-friendly version with minimal package conflicts
# =============================================================================

set -euo pipefail

# Colors and logging (container-optimized)
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

# Container detection
detect_container() {
    if [[ -f /.dockerenv ]] || [[ -n "${CONTAINER:-}" ]] || [[ "$(hostname)" =~ ^[0-9a-f]{12}$ ]]; then
        return 0  # is container
    else
        return 1  # not container
    fi
}

# Setup container-optimized environment
setup_container_environment() {
    log_info "Setting up container-optimized environment..."
    
    # Disable interactive prompts and progress bars
    export DEBIAN_FRONTEND=noninteractive
    export APT_LISTCHANGES_FRONTEND=none
    export NEEDRESTART_MODE=a
    
    # Ensure ~/.local/bin exists and is in PATH
    mkdir -p ~/.local/bin
    if ! echo "$PATH" | grep -q "$HOME/.local/bin"; then
        export PATH="$HOME/.local/bin:$PATH"
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
    fi
    
    log_success "Container environment configured"
}

# Install essential tools (container-safe)
install_essential_tools() {
    log_info "Installing essential development tools..."
    
    # Update package lists quietly
    sudo apt-get update -qq >/dev/null 2>&1 || {
        log_warn "Package update failed, continuing anyway..."
    }
    
    # Essential tools that usually work in containers
    local essential_packages=(
        "curl" "wget" "git" "jq"
        "python3-pip" "python3-dev"
        "build-essential" "pkg-config"
        "htop" "tree" "unzip"
    )
    
    log_info "Installing packages individually to avoid conflicts..."
    for pkg in "${essential_packages[@]}"; do
        if sudo apt-get install -y -qq "$pkg" >/dev/null 2>&1; then
            log_info "✓ $pkg"
        else
            log_warn "✗ $pkg (failed)"
        fi
    done
    
    # Optional tools (don't fail if they don't install)
    local optional_packages=(
        "tmux" "screen" "neofetch"
        "ripgrep" "fd-find" "bat"
    )
    
    log_info "Installing optional packages..."
    for pkg in "${optional_packages[@]}"; do
        if sudo apt-get install -y -qq "$pkg" >/dev/null 2>&1; then
            log_info "✓ $pkg"
        else
            log_warn "✗ $pkg (optional, skipped)"
        fi
    done
}

# Install Python development tools
setup_python_development() {
    log_info "Setting up Python development environment..."
    
    # Install Python debugging and development tools via pip
    local python_packages=(
        "debugpy"
        "ipython"
        "jupyter"
        "black"
        "flake8"
        "pylint"
    )
    
    for pkg in "${python_packages[@]}"; do
        if pip3 install --user "$pkg" >/dev/null 2>&1; then
            log_info "✓ $pkg (pip)"
        else
            log_warn "✗ $pkg (pip failed)"
        fi
    done
    
    log_success "Python development environment configured"
}

# Setup Node.js development (if available)
setup_nodejs_development() {
    log_info "Setting up Node.js development environment..."
    
    if command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1; then
        log_success "Node.js already available: $(node --version)"
        log_success "npm available: $(npm --version)"
        
        # Install global development tools
        local npm_packages=(
            "node-inspect"
            "nodemon"
            "typescript"
            "@types/node"
        )
        
        for pkg in "${npm_packages[@]}"; do
            if npm install -g "$pkg" >/dev/null 2>&1; then
                log_info "✓ $pkg (npm global)"
            else
                log_warn "✗ $pkg (npm failed)"
            fi
        done
    else
        log_warn "Node.js/npm not available, skipping Node.js development setup"
    fi
}

# Create development configuration
create_development_config() {
    log_info "Creating development configuration..."
    
    # Create code-server user settings
    mkdir -p ~/.local/share/code-server/User
    cat > ~/.local/share/code-server/User/settings.json <<'EOF'
{
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
    "terminal.integrated.fontSize": 14,
    "terminal.integrated.fontFamily": "monospace",
    "terminal.integrated.cursorBlinking": true,
    "terminal.integrated.scrollback": 10000,
    "git.enableSmartCommit": true,
    "git.confirmSync": false,
    "extensions.autoUpdate": false,
    "python.defaultInterpreterPath": "/usr/bin/python3",
    "python.linting.enabled": true,
    "python.linting.pylintEnabled": true,
    "python.formatting.provider": "black"
}
EOF
    
    log_success "Development configuration created"
}

# Main execution
main() {
    log_info "Setting up development environment for Google Colab..."
    
    if detect_container; then
        log_info "Container environment detected - using optimized settings"
        setup_container_environment
    else
        log_info "Non-container environment detected"
    fi
    
    install_essential_tools
    setup_python_development
    setup_nodejs_development
    create_development_config
    
    log_success "Development environment setup completed!"
    log_info "Restart your terminal or run 'source ~/.bashrc' to apply PATH changes"
}

# Run main function
main "$@"
