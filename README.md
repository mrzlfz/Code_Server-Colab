# 🚀 Enhanced VS Code Server Setup

A comprehensive, production-ready VS Code Server installation that provides a **GitHub Codespaces-like experience** on Ubuntu without systemd, using nohup and other process management alternatives.

## 🌟 Features Overview

This enhanced setup transforms a basic code-server installation into a **professional development environment** with enterprise-grade features:

### 🏗️ **Core Infrastructure**
- **Enhanced Process Management**: PM2, nohup, supervisor support with health checks and auto-restart
- **Comprehensive Logging**: Structured logging with rotation and monitoring systems
- **Self-Healing**: Automatic error recovery, crash detection, and service restoration
- **Resource Management**: CPU, memory, and disk usage monitoring with configurable limits

### 🔌 **Extension Management**
- **Automatic Installation**: Essential extensions with marketplace integration (OpenVSX + Microsoft)
- **Workspace-Specific**: Per-workspace extension recommendations and auto-installation
- **Update System**: Automatic extension updates and version management
- **Custom Repository**: Support for private and custom extensions
- **Backup & Restore**: Complete extension backup and restoration capabilities

### 💻 **Development Environment**
- **Enhanced Terminal**: Multiple shells (bash, zsh, fish), customization, and management
- **Multi-Language Debugging**: Full debugging support for Node.js, Python, PHP, Go, and more
- **Git Integration**: Advanced Git tools, GUI integration, and workflow automation
- **Language Servers**: IntelliSense and autocomplete for all major programming languages
- **Development Tools**: Docker, databases, API testing tools, and build system integration
- **Code Quality**: Automatic formatting, linting, and code quality tools

### 🎨 **User Experience**
- **Theme System**: Multiple themes, appearance customization, and visual enhancements
- **Settings Sync**: Cross-instance configuration synchronization and backup
- **Keyboard Shortcuts**: Desktop VS Code-like keybindings and custom shortcuts
- **Workspace Management**: Project templates, workspace switching, and organization
- **Enhanced Interface**: Improved file explorer, search, and command palette

### 🌐 **Remote Access**
- **Multiple Tunnels**: ngrok, Cloudflare Tunnel, VS Code Tunnels support
- **SSH Server**: Secure remote access with key-based authentication
- **Reverse Proxy**: nginx/caddy integration for load balancing and SSL termination
- **Mobile Support**: Optimized interface for mobile and tablet access
- **Network Security**: Firewall configuration and network monitoring

### 🔒 **Security**
- **SSL/TLS Management**: Automatic certificate generation, renewal (Let's Encrypt + self-signed)
- **Authentication**: Password, token, and multi-factor authentication support
- **Access Control**: User permissions, file access control, and workspace isolation
- **Security Hardening**: System-level security optimizations and configurations
- **Audit Logging**: Comprehensive security monitoring and compliance logging
- **Intrusion Detection**: Firewall rules and security monitoring

### 💾 **Backup & Configuration**
- **Automated Backups**: Scheduled daily, weekly, and monthly backup systems
- **Cloud Integration**: S3, Google Drive, Dropbox backup support
- **Migration Tools**: Server-to-server configuration transfer and cloning
- **Version Control**: Git-based configuration versioning with rollback capabilities
- **Disaster Recovery**: Complete system restoration and recovery procedures

### ⚡ **Performance**
- **Resource Optimization**: CPU, memory, and disk usage optimization
- **Caching System**: Intelligent caching for faster file access and responsiveness
- **Load Balancing**: Multiple instance support for high availability
- **Performance Monitoring**: Real-time performance analytics and reporting
- **Startup Optimization**: Fast boot times and lazy loading mechanisms
- **Network Optimization**: Bandwidth optimization and connection management

## 📦 Installation

### Quick Start
```bash
# Clone or download the scripts
git clone <repository-url>
cd vscode-server

# Make all scripts executable
chmod +x *.sh

# Run the enhanced setup (installs everything)
./setup-code-server.sh
```

### Custom Installation
You can customize the installation by editing the configuration variables in `setup-code-server.sh`:

```bash
# Core settings
PROCESS_MANAGER="pm2"              # pm2, nohup, supervisor
BIND_ADDR="127.0.0.1:8080"        # Server bind address
ENABLE_SSL=false                   # Enable SSL/TLS

# Feature toggles
INSTALL_EXTENSIONS=true            # Install essential extensions
SETUP_DEV_ENVIRONMENT=true        # Setup development tools
SETUP_UI_EXPERIENCE=true          # Setup UI enhancements
SETUP_SECURITY=true               # Setup security features
SETUP_BACKUP=true                 # Setup backup system
SETUP_PERFORMANCE=true            # Setup performance optimization

# Extension settings
EXTENSION_MARKETPLACE="openvsx"    # openvsx, microsoft, both

# Remote access
NGROK_AUTH_TOKEN=""               # Your ngrok auth token (optional)
```

Then run the setup:
```bash
./setup-code-server.sh
```

## 🛠️ Management Commands

After installation, you'll have access to **25+ management commands** for complete control:

### 📊 **Service Control**
```bash
~/.local/bin/code-server-status     # Check service status and health
~/.local/bin/code-server-stop       # Stop code-server service
~/.local/bin/code-server-restart    # Restart code-server service
~/.local/bin/code-server-recover    # Recover from crashes and issues
```

### 🔌 **Extension Management**
```bash
~/.local/bin/code-server-extensions list                    # List installed extensions
~/.local/bin/code-server-extensions install <ext-id>        # Install extension
~/.local/bin/code-server-extensions uninstall <ext-id>      # Uninstall extension
~/.local/bin/code-server-extensions update                  # Update all extensions
~/.local/bin/code-server-extensions backup                  # Backup extension list
~/.local/bin/code-server-extensions restore                 # Restore extensions
```

### 📈 **Monitoring & Resources**
```bash
~/.local/bin/code-server-resources  # Monitor CPU, memory, disk usage
~/.local/bin/code-server-sysinfo    # Show comprehensive system information
~/.local/bin/code-server-monitor    # Real-time health monitoring
~/.local/bin/code-server-cleanup    # Clean logs and temporary files
```

### 🌐 **Remote Access**
```bash
~/.local/bin/code-server-tunnel ngrok        # Start ngrok tunnel
~/.local/bin/code-server-tunnel cloudflare   # Start Cloudflare tunnel
~/.local/bin/code-server-tunnel vscode       # Start VS Code tunnel
~/.local/bin/code-server-tunnel stop         # Stop all tunnels
~/.local/bin/code-server-tunnel status       # Show tunnel status

~/.local/bin/code-server-network status      # Show network status
~/.local/bin/code-server-network test        # Test connectivity
~/.local/bin/code-server-network firewall    # Show firewall status
```

### 🔒 **Security Management**
```bash
# SSL Certificates
~/.local/bin/code-server-certs create-self localhost    # Create self-signed cert
~/.local/bin/code-server-certs letsencrypt example.com  # Get Let's Encrypt cert
~/.local/bin/code-server-certs renew                    # Renew certificates
~/.local/bin/code-server-certs status                   # Show cert status

# Authentication
~/.local/bin/code-server-auth password newpassword      # Set new password
~/.local/bin/code-server-auth generate                  # Generate random password
~/.local/bin/code-server-auth status                    # Show auth status

# Security Hardening
~/.local/bin/code-server-harden apply                   # Apply security hardening
~/.local/bin/code-server-harden check                   # Check security status
```

### 💾 **Backup & Migration**
```bash
# Local Backups
~/.local/bin/code-server-backup full                    # Create full backup
~/.local/bin/code-server-backup config                  # Backup configuration only
~/.local/bin/code-server-backup extensions              # Backup extensions only
~/.local/bin/code-server-backup list                    # List available backups
~/.local/bin/code-server-backup restore backup.tar.gz  # Restore from backup
~/.local/bin/code-server-backup schedule                # Setup automated backups

# Cloud Backups
~/.local/bin/code-server-cloud-backup setup s3         # Setup S3 backup
~/.local/bin/code-server-cloud-backup upload s3 file   # Upload to S3
~/.local/bin/code-server-cloud-backup sync s3          # Sync to S3

# Migration Tools
~/.local/bin/code-server-migrate export user@server     # Export to remote server
~/.local/bin/code-server-migrate import backup.tar.gz  # Import from backup
~/.local/bin/code-server-migrate clone src dest        # Clone entire setup

# Version Control
~/.local/bin/code-server-version init                   # Initialize version control
~/.local/bin/code-server-version commit "message"      # Commit configuration
~/.local/bin/code-server-version log                    # Show history
~/.local/bin/code-server-version revert <commit>       # Revert to commit
```

### ⚡ **Performance & Optimization**
```bash
# Performance Optimization
~/.local/bin/code-server-optimize apply                 # Apply optimizations
~/.local/bin/code-server-optimize status                # Show optimization status
~/.local/bin/code-server-optimize tune                  # Interactive tuning

# Cache Management
~/.local/bin/code-server-cache clear                    # Clear all caches
~/.local/bin/code-server-cache status                   # Show cache status
~/.local/bin/code-server-cache optimize                 # Optimize cache settings

# Performance Monitoring
~/.local/bin/code-server-perf monitor                   # Start monitoring
~/.local/bin/code-server-perf report                    # Generate report
~/.local/bin/code-server-perf benchmark                 # Run benchmark

# Load Balancing
~/.local/bin/code-server-loadbalancer setup             # Setup load balancer
~/.local/bin/code-server-loadbalancer add 8081          # Add instance on port 8081
~/.local/bin/code-server-loadbalancer status            # Show LB status

# Network Optimization
~/.local/bin/code-server-netopt apply                   # Apply network optimizations
~/.local/bin/code-server-netopt test                    # Test network performance
```

### 🎨 **User Experience**
```bash
# Settings Synchronization
~/.local/bin/code-server-sync backup                    # Backup current settings
~/.local/bin/code-server-sync restore                   # Restore settings
~/.local/bin/code-server-sync export settings.tar.gz   # Export settings
~/.local/bin/code-server-sync import settings.tar.gz   # Import settings

# Workspace Management
~/.local/bin/code-server-workspace create my-project    # Create new workspace
~/.local/bin/code-server-workspace list                 # List workspaces
~/.local/bin/code-server-workspace open my-project      # Open workspace
```

## 📚 **Complete Command Reference**

For a complete list of all commands with detailed usage:

```bash
./code-server-help.sh              # Show all commands
./code-server-help.sh service      # Show service commands only
./code-server-help.sh security     # Show security commands only
./code-server-help.sh performance  # Show performance commands only
./code-server-help.sh quickstart   # Show quick start guide
```

## 🚀 **Quick Start Guide**

1. **Install and Start**
   ```bash
   ./setup-code-server.sh
   ```

2. **Check Status**
   ```bash
   ~/.local/bin/code-server-status
   ```

3. **Create Your First Workspace**
   ```bash
   ~/.local/bin/code-server-workspace create my-first-project
   ```

4. **Setup Remote Access**
   ```bash
   ~/.local/bin/code-server-tunnel ngrok
   ```

5. **Install Essential Extensions**
   ```bash
   ~/.local/bin/code-server-extensions install ms-python.python
   ~/.local/bin/code-server-extensions install ms-vscode.vscode-typescript-next
   ```

6. **Create Your First Backup**
   ```bash
   ~/.local/bin/code-server-backup full
   ```

7. **Optimize Performance**
   ```bash
   ~/.local/bin/code-server-optimize apply
   ```

## 📁 **File Structure**

```
vscode-server/
├── setup-code-server.sh          # Main enhanced setup script (1,900+ lines)
├── setup-dev-environment.sh      # Development environment setup
├── setup-ui-experience.sh        # UI and user experience setup
├── setup-security.sh             # Security and authentication setup
├── setup-backup.sh               # Backup system setup (1,067+ lines)
├── setup-performance.sh          # Performance optimization (1,027+ lines)
├── code-server-help.sh           # Complete command reference guide
├── README.md                     # This comprehensive documentation
└── ~/.local/bin/                 # Management scripts (25+ commands)
    ├── code-server-*             # Various management commands
    └── ...
```

## 🔧 **Configuration Files**

- `~/.config/code-server/config.yaml` - Main code-server configuration
- `~/.local/share/code-server/User/settings.json` - VS Code settings
- `~/.local/share/code-server/User/keybindings.json` - Keyboard shortcuts
- `~/.config/code-server/extensions/` - Extension configurations
- `~/.config/code-server/backups/` - Local backup storage
- `~/.config/code-server/git-repo/` - Configuration version control

## 🔍 **Troubleshooting**

### Common Issues

**Code-server won't start:**
```bash
~/.local/bin/code-server-sysinfo    # Check system information
~/.local/bin/code-server-recover    # Attempt automatic recovery
```

**Performance issues:**
```bash
~/.local/bin/code-server-resources  # Check resource usage
~/.local/bin/code-server-optimize apply  # Apply optimizations
~/.local/bin/code-server-cache clear     # Clear caches
```

**Extension problems:**
```bash
~/.local/bin/code-server-extensions list     # List current extensions
~/.local/bin/code-server-cache clear         # Clear extension cache
~/.local/bin/code-server-extensions restore  # Restore from backup
```

**Network/Remote access issues:**
```bash
~/.local/bin/code-server-network test        # Test connectivity
~/.local/bin/code-server-tunnel status       # Check tunnel status
~/.local/bin/code-server-network firewall    # Check firewall
```

## 📊 **System Requirements**

- **OS**: Ubuntu 18.04+ (may work on other Debian-based systems)
- **Memory**: Minimum 2GB RAM (4GB+ recommended for optimal performance)
- **Storage**: At least 5GB free space (more for workspaces and backups)
- **Network**: Internet access for downloads, updates, and remote access
- **Permissions**: Sudo access for system-level optimizations (optional)

## 🎯 **Production Deployment**

This setup is **production-ready** and includes:

✅ **High Availability**: Load balancing and automatic failover  
✅ **Security**: SSL/TLS, authentication, and security hardening  
✅ **Monitoring**: Comprehensive logging and performance monitoring  
✅ **Backup**: Automated backups with cloud integration  
✅ **Scalability**: Multi-instance support and resource optimization  
✅ **Maintenance**: Automated cleanup and self-healing capabilities  

## 🤝 **Contributing**

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes and test thoroughly
4. Commit your changes (`git commit -m 'Add amazing feature'`)
5. Push to the branch (`git push origin feature/amazing-feature`)
6. Open a Pull Request

## 📄 **License**

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 **Acknowledgments**

- [code-server](https://github.com/coder/code-server) - The core VS Code server by Coder
- [Visual Studio Code](https://code.visualstudio.com/) - Microsoft's Visual Studio Code
- [OpenVSX Registry](https://open-vsx.org/) - Open source extension marketplace
- [PM2](https://pm2.keymetrics.io/) - Advanced process manager for Node.js
- [nginx](https://nginx.org/) - High-performance web server and reverse proxy

---

**🚀 Made with ❤️ for developers who want a powerful, self-hosted development environment that rivals GitHub Codespaces!**

**⭐ If this project helps you, please consider giving it a star!**
