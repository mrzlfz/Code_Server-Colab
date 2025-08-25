#!/usr/bin/env bash
# =============================================================================
# Code-Server Help and Command Reference
# Complete guide to all available management commands
# =============================================================================

# Colors for output
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; PURPLE='\033[0;35m'; CYAN='\033[0;36m'; NC='\033[0m'

show_banner() {
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════════════════════════════════╗"
    echo "║                    🚀 Enhanced VS Code Server Help                          ║"
    echo "║                     Complete Command Reference                              ║"
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

show_service_commands() {
    echo -e "${GREEN}📊 SERVICE CONTROL COMMANDS${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${YELLOW}~/.local/bin/code-server-status${NC}     - Check service status and health"
    echo -e "${YELLOW}~/.local/bin/code-server-stop${NC}       - Stop code-server service"
    echo -e "${YELLOW}~/.local/bin/code-server-restart${NC}    - Restart code-server service"
    echo -e "${YELLOW}~/.local/bin/code-server-recover${NC}    - Recover from crashes and issues"
    echo ""
}

show_extension_commands() {
    echo -e "${GREEN}🔌 EXTENSION MANAGEMENT COMMANDS${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${YELLOW}~/.local/bin/code-server-extensions${NC} - Manage extensions"
    echo "  • list                    - List installed extensions"
    echo "  • install <ext-id>        - Install extension"
    echo "  • uninstall <ext-id>      - Uninstall extension"
    echo "  • update                  - Update all extensions"
    echo "  • backup                  - Backup extension list"
    echo "  • restore                 - Restore extensions from backup"
    echo ""
}

show_monitoring_commands() {
    echo -e "${GREEN}📈 MONITORING & RESOURCES COMMANDS${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${YELLOW}~/.local/bin/code-server-resources${NC}  - Monitor CPU, memory, disk usage"
    echo -e "${YELLOW}~/.local/bin/code-server-sysinfo${NC}    - Show comprehensive system information"
    echo -e "${YELLOW}~/.local/bin/code-server-monitor${NC}    - Real-time health monitoring"
    echo -e "${YELLOW}~/.local/bin/code-server-cleanup${NC}    - Clean logs and temporary files"
    echo ""
}

show_remote_access_commands() {
    echo -e "${GREEN}🌐 REMOTE ACCESS COMMANDS${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${YELLOW}~/.local/bin/code-server-tunnel${NC}     - Manage tunneling solutions"
    echo "  • ngrok                   - Start ngrok tunnel"
    echo "  • cloudflare              - Start Cloudflare tunnel"
    echo "  • vscode                  - Start VS Code tunnel"
    echo "  • stop                    - Stop all tunnels"
    echo "  • status                  - Show tunnel status"
    echo ""
    echo -e "${YELLOW}~/.local/bin/code-server-network${NC}    - Network monitoring and testing"
    echo "  • status                  - Show network status"
    echo "  • ports                   - Show open ports"
    echo "  • test                    - Test connectivity"
    echo "  • firewall                - Show firewall status"
    echo ""
}

show_security_commands() {
    echo -e "${GREEN}🔒 SECURITY COMMANDS${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${YELLOW}~/.local/bin/code-server-certs${NC}      - SSL certificate management"
    echo "  • create-self <domain>    - Create self-signed certificate"
    echo "  • letsencrypt <domain>    - Get Let's Encrypt certificate"
    echo "  • renew                   - Renew certificates"
    echo "  • status                  - Show certificate status"
    echo "  • install                 - Install certificates to code-server"
    echo ""
    echo -e "${YELLOW}~/.local/bin/code-server-auth${NC}       - Authentication management"
    echo "  • password <new-password> - Set new password"
    echo "  • generate                - Generate random password"
    echo "  • disable                 - Disable authentication"
    echo "  • enable                  - Enable password authentication"
    echo "  • status                  - Show authentication status"
    echo ""
    echo -e "${YELLOW}~/.local/bin/code-server-harden${NC}     - Security hardening"
    echo "  • apply                   - Apply security hardening"
    echo "  • check                   - Check security status"
    echo ""
}

show_backup_commands() {
    echo -e "${GREEN}💾 BACKUP & CONFIGURATION COMMANDS${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${YELLOW}~/.local/bin/code-server-backup${NC}     - Local backup management"
    echo "  • full                    - Create full backup"
    echo "  • config                  - Backup configuration only"
    echo "  • extensions              - Backup extensions only"
    echo "  • workspace <path>        - Backup specific workspace"
    echo "  • list                    - List available backups"
    echo "  • restore <backup-file>   - Restore from backup"
    echo "  • cleanup                 - Clean old backups"
    echo "  • schedule                - Setup automated backups"
    echo ""
    echo -e "${YELLOW}~/.local/bin/code-server-cloud-backup${NC} - Cloud backup integration"
    echo "  • setup <provider>        - Setup cloud provider (s3, gdrive)"
    echo "  • upload <provider> <file> - Upload backup to cloud"
    echo "  • sync <provider>         - Sync local backups to cloud"
    echo ""
    echo -e "${YELLOW}~/.local/bin/code-server-migrate${NC}    - Migration tools"
    echo "  • export <target>         - Export configuration to target server"
    echo "  • import <source>         - Import configuration from source"
    echo "  • sync <remote-host>      - Sync with remote code-server instance"
    echo "  • clone <source> <target> - Clone entire setup to new location"
    echo "  • compare <host1> <host2> - Compare configurations between hosts"
    echo ""
    echo -e "${YELLOW}~/.local/bin/code-server-version${NC}    - Configuration version control"
    echo "  • init                    - Initialize version control"
    echo "  • commit [message]        - Commit current configuration"
    echo "  • log                     - Show configuration history"
    echo "  • diff                    - Show current changes"
    echo "  • revert <commit>         - Revert to specific commit"
    echo "  • branch <name>           - Create configuration branch"
    echo "  • status                  - Show repository status"
    echo ""
}

show_performance_commands() {
    echo -e "${GREEN}⚡ PERFORMANCE & OPTIMIZATION COMMANDS${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${YELLOW}~/.local/bin/code-server-optimize${NC}   - Performance optimization"
    echo "  • apply                   - Apply performance optimizations"
    echo "  • status                  - Show current optimization status"
    echo "  • tune                    - Interactive performance tuning"
    echo ""
    echo -e "${YELLOW}~/.local/bin/code-server-cache${NC}      - Cache management"
    echo "  • setup                   - Setup caching system"
    echo "  • clear                   - Clear all caches"
    echo "  • status                  - Show cache status"
    echo "  • optimize                - Optimize cache settings"
    echo ""
    echo -e "${YELLOW}~/.local/bin/code-server-perf${NC}       - Performance monitoring"
    echo "  • monitor                 - Start performance monitoring"
    echo "  • report                  - Generate performance report"
    echo "  • benchmark               - Run performance benchmark"
    echo "  • analyze                 - Analyze performance logs"
    echo ""
    echo -e "${YELLOW}~/.local/bin/code-server-startup${NC}    - Startup optimization"
    echo "  • optimize                - Optimize startup performance"
    echo "  • test                    - Test startup time"
    echo ""
    echo -e "${YELLOW}~/.local/bin/code-server-loadbalancer${NC} - Load balancing"
    echo "  • setup                   - Setup load balancer"
    echo "  • add <port>              - Add instance on port"
    echo "  • remove <port>           - Remove instance"
    echo "  • list                    - List instances"
    echo "  • status                  - Show load balancer status"
    echo "  • reload                  - Reload configuration"
    echo ""
    echo -e "${YELLOW}~/.local/bin/code-server-netopt${NC}     - Network optimization"
    echo "  • apply                   - Apply network optimizations"
    echo "  • test                    - Test network performance"
    echo "  • status                  - Show network status"
    echo ""
}

show_ui_commands() {
    echo -e "${GREEN}🎨 USER EXPERIENCE COMMANDS${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${YELLOW}~/.local/bin/code-server-sync${NC}       - Settings synchronization"
    echo "  • backup                  - Create backup of current settings"
    echo "  • restore                 - Restore settings from backup"
    echo "  • export                  - Export settings to file"
    echo "  • import                  - Import settings from file"
    echo "  • status                  - Show sync status"
    echo ""
    echo -e "${YELLOW}~/.local/bin/code-server-workspace${NC}  - Workspace management"
    echo "  • create <name> [template] - Create new workspace"
    echo "  • list                    - List workspaces"
    echo "  • open <name>             - Open workspace"
    echo "  • delete <name>           - Delete workspace"
    echo "  • template <name>         - Create template from workspace"
    echo ""
}

show_quick_start() {
    echo -e "${GREEN}🚀 QUICK START GUIDE${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${PURPLE}1. Check Status:${NC}        ~/.local/bin/code-server-status"
    echo -e "${PURPLE}2. Install Extensions:${NC}  ~/.local/bin/code-server-extensions install ms-python.python"
    echo -e "${PURPLE}3. Create Workspace:${NC}    ~/.local/bin/code-server-workspace create my-project"
    echo -e "${PURPLE}4. Setup Tunnel:${NC}        ~/.local/bin/code-server-tunnel ngrok"
    echo -e "${PURPLE}5. Create Backup:${NC}       ~/.local/bin/code-server-backup full"
    echo -e "${PURPLE}6. Optimize Performance:${NC} ~/.local/bin/code-server-optimize apply"
    echo ""
}

show_help() {
    echo "Usage: $0 [category]"
    echo ""
    echo "Categories:"
    echo "  service     - Service control commands"
    echo "  extensions  - Extension management commands"
    echo "  monitoring  - Monitoring and resource commands"
    echo "  remote      - Remote access commands"
    echo "  security    - Security commands"
    echo "  backup      - Backup and configuration commands"
    echo "  performance - Performance and optimization commands"
    echo "  ui          - User experience commands"
    echo "  quickstart  - Quick start guide"
    echo "  all         - Show all commands (default)"
    echo ""
}

# Main execution
case "${1:-all}" in
    "service")
        show_banner
        show_service_commands
        ;;
    "extensions")
        show_banner
        show_extension_commands
        ;;
    "monitoring")
        show_banner
        show_monitoring_commands
        ;;
    "remote")
        show_banner
        show_remote_access_commands
        ;;
    "security")
        show_banner
        show_security_commands
        ;;
    "backup")
        show_banner
        show_backup_commands
        ;;
    "performance")
        show_banner
        show_performance_commands
        ;;
    "ui")
        show_banner
        show_ui_commands
        ;;
    "quickstart")
        show_banner
        show_quick_start
        ;;
    "all")
        show_banner
        show_service_commands
        show_extension_commands
        show_monitoring_commands
        show_remote_access_commands
        show_security_commands
        show_backup_commands
        show_performance_commands
        show_ui_commands
        show_quick_start
        ;;
    "help"|"-h"|"--help")
        show_help
        ;;
    *)
        echo "Unknown category: $1"
        show_help
        exit 1
        ;;
esac
