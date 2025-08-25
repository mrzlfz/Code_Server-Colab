# 🚀 VS Code Server untuk Google Colab

Panduan lengkap untuk menjalankan VS Code Server di Google Colab tanpa konfigurasi firewall atau sudo.

## 📋 Ringkasan Masalah

Script asli memiliki beberapa masalah untuk Google Colab:

### ❌ Masalah Utama:
1. **Firewall Configuration**: Script menggunakan `sudo ufw` commands
2. **System Dependencies**: Memerlukan `sudo apt-get install`
3. **Service Management**: Menggunakan `systemctl` dan `supervisor`
4. **SSH Configuration**: Modifikasi `/etc/ssh/sshd_config`
5. **System Hardening**: Modifikasi `/etc/sysctl.conf`

### ✅ Solusi yang Diterapkan:
1. **Environment Detection**: Deteksi otomatis Google Colab
2. **Conditional Sudo**: Skip operasi yang memerlukan sudo
3. **User-space Installation**: Install tools ke `~/.local/bin`
4. **Nohup Process Manager**: Gunakan nohup instead of PM2/supervisor
5. **OpenVSX Marketplace**: Gunakan marketplace yang Colab-friendly

## 🛠️ File yang Dibuat

### 1. `setup-code-server-colab.sh`
Script setup yang dioptimalkan untuk Google Colab:
- ✅ Deteksi environment otomatis
- ✅ Instalasi dependencies tanpa sudo (fallback ke user-space)
- ✅ Process management dengan nohup
- ✅ Konfigurasi yang aman untuk Colab

### 2. `colab-code-server-manager.sh`
Script management untuk kontrol server:
- ✅ Start/stop/restart server
- ✅ Check status dan health
- ✅ View logs
- ✅ Setup ngrok tunnel
- ✅ Show access information

### 3. `Google_Colab_VSCode_Server.ipynb`
Jupyter notebook untuk Google Colab:
- ✅ Setup otomatis dengan satu klik
- ✅ Management commands yang mudah
- ✅ Troubleshooting guide
- ✅ Tips dan best practices

## 🚀 Cara Penggunaan

### Metode 1: Langsung di Terminal Colab
```bash
# Download dan jalankan setup
!curl -fsSL https://raw.githubusercontent.com/your-repo/vscode-server/main/setup-code-server-colab.sh -o setup.sh
!chmod +x setup.sh
!./setup.sh
```

### Metode 2: Menggunakan Jupyter Notebook
1. Upload `Google_Colab_VSCode_Server.ipynb` ke Google Colab
2. Jalankan cell setup
3. Gunakan management commands

### Metode 3: Manual Setup
```bash
# Clone repository
!git clone https://github.com/your-repo/vscode-server.git
!cd vscode-server

# Jalankan Colab-optimized setup
!./setup-code-server-colab.sh

# Download manager
!curl -fsSL https://raw.githubusercontent.com/your-repo/vscode-server/main/colab-code-server-manager.sh -o manager.sh
!chmod +x manager.sh
```

## 🎛️ Management Commands

```bash
# Check status
!./manager.sh status

# Start server
!./manager.sh start

# Stop server
!./manager.sh stop

# Restart server
!./manager.sh restart

# View logs
!./manager.sh logs

# Get access URL and password
!./manager.sh url

# Setup ngrok tunnel
!./manager.sh tunnel
```

## 🔧 Konfigurasi

### Environment Variables
```bash
# Dalam setup-code-server-colab.sh
CODE_SERVER_VERSION="4.20.0"
PROCESS_MANAGER="nohup"          # Colab-friendly
BIND_ADDR="0.0.0.0:8888"        # Default port
EXTENSION_MARKETPLACE="openvsx"   # Colab-compatible
```

### Custom Configuration
Edit file sebelum menjalankan:
```bash
# Ubah port jika diperlukan
BIND_ADDR="0.0.0.0:9999"

# Disable extensions jika tidak diperlukan
INSTALL_EXTENSIONS=false

# Gunakan Microsoft marketplace (jika diperlukan)
EXTENSION_MARKETPLACE="microsoft"
```

## 🌐 Remote Access

### Ngrok Tunnel
```bash
# Setup tunnel otomatis
!./manager.sh tunnel

# Manual ngrok setup
!ngrok http 8888
```

### Cloudflare Tunnel (Alternative)
```bash
# Install cloudflared
!curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -o cloudflared
!chmod +x cloudflared

# Create tunnel
!./cloudflared tunnel --url http://localhost:8888
```

## 🐛 Troubleshooting

### Server Tidak Start
```bash
# Check logs
!./manager.sh logs

# Check processes
!ps aux | grep code-server

# Manual start
!nohup code-server --config ~/.config/code-server/config.yaml > ~/code-server.log 2>&1 &
```

### Port Sudah Digunakan
```bash
# Kill processes on port
!lsof -ti:8888 | xargs kill -9

# Atau gunakan port lain
# Edit BIND_ADDR di script setup
```

### Extensions Tidak Install
```bash
# Manual install dengan OpenVSX
!SERVICE_URL=https://open-vsx.org/vscode/gallery ITEM_URL=https://open-vsx.org/vscode/item code-server --install-extension ms-python.python

# Atau gunakan Microsoft marketplace
!code-server --install-extension ms-python.python
```

### Permission Denied
```bash
# Pastikan file executable
!chmod +x setup-code-server-colab.sh
!chmod +x colab-code-server-manager.sh

# Check PATH
!echo $PATH
!export PATH="$HOME/.local/bin:$PATH"
```

## 📊 Monitoring

### Health Check
```bash
# Check if server responding
!curl -s -f http://127.0.0.1:8888/healthz && echo "OK" || echo "FAIL"

# Check process
!pgrep -f code-server && echo "Running" || echo "Stopped"
```

### Resource Usage
```bash
# Memory usage
!ps aux | grep code-server | awk '{print $4}' | head -1

# CPU usage
!top -bn1 | grep code-server
```

## 🔒 Security Notes

### Google Colab Environment
- ✅ Isolated environment per session
- ✅ Automatic cleanup saat session berakhir
- ✅ No persistent network exposure
- ⚠️ Files hilang saat session berakhir (backup ke Drive)

### Best Practices
1. **Gunakan strong password** (auto-generated sudah aman)
2. **Jangan share ngrok URL** secara publik
3. **Backup important files** ke Google Drive
4. **Monitor resource usage** untuk avoid timeout

## 📁 File Structure

```
/content/
├── setup-code-server-colab.sh      # Main setup script
├── colab-code-server-manager.sh    # Management script
├── Google_Colab_VSCode_Server.ipynb # Jupyter notebook
└── ~/.config/code-server/
    ├── config.yaml                  # Server configuration
    └── ~/.local/share/code-server/
        ├── logs/server.log          # Server logs
        └── code-server.pid          # Process ID file
```

## 🎯 Next Steps

1. **Test the scripts** di Google Colab environment
2. **Add error handling** untuk edge cases
3. **Create automated tests** untuk verify functionality
4. **Add more extensions** sesuai kebutuhan
5. **Optimize performance** untuk Colab resources

## 📞 Support

Jika mengalami masalah:
1. Check logs: `!./manager.sh logs`
2. Verify status: `!./manager.sh status`
3. Restart server: `!./manager.sh restart`
4. Check troubleshooting section di atas
