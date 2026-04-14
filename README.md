# Proxy Manager v2.1-FINAL

🚀 **一键安装代理管理系统** - 支持 XRay 多协议 + Web 管理界面

## ⚡ 一句话一键安装指令

```bash
bash <(curl -Ls https://raw.githubusercontent.com/HYweb3/proxy-manager/main/install-from-github.sh)
```

**就这么简单！** 一行命令即可完成所有安装配置。

## 🌟 主要特性

### 🔧 代理协议支持
- ✅ **VLESS** (端口 443, TLS加密)
- ✅ **Trojan** (端口 501, TLS加密)
- ✅ **VMess** (端口 502, TLS加密)
- ✅ **Shadowsocks** (端口 503, 无加密)

### 🖥️ Web 管理界面
- ✅ 用户管理（添加/删除/启用/禁用）
- ✅ 流量统计和限制
- ✅ 配置链接生成
- ✅ 二维码快速导入
- ✅ 现代化模态框界面
- ✅ 内容可复制

### 🤖 智能功能
- ✅ 自动依赖安装（pip3 + 系统包管理器）
- ✅ 跨平台支持（Linux + macOS）
- ✅ 多架构支持（x64, arm64, arm32）
- ✅ 防火墙自动配置
- ✅ TLS 证书自动生成

## 💻 系统要求

### Linux 系统
- **CentOS**: 7/8/Stream
- **Ubuntu**: 18.04/20.04/22.04
- **Debian**: 10/11
- **RHEL**: 7/8/9
- **架构**: x86_64, aarch64, armv7l

### macOS 系统
- **版本**: 10.15+ (Big Sur/Monterey/Ventura)
- **模式**: Web 管理界面（用于测试开发）

## 📦 其他安装方式

### 本地安装
```bash
# 下载ZIP文件
wget https://github.com/HYweb3/proxy-manager/raw/main/proxy-manager-full.zip

# 解压并安装
unzip proxy-manager-full.zip
cd proxy-manager-src
sudo bash one_click_install.sh
```

### 手动安装
```bash
# 1. 安装依赖
pip3 install flask flask-qrcode qrcode pillow pyyaml

# 2. 配置系统
sudo mkdir -p /etc/proxy-manager /var/www/proxy-manager

# 3. 部署文件
sudo cp proxy_manager.py /etc/proxy-manager/
sudo cp proxy_web.py /var/www/proxy-manager/

# 4. 启动服务
sudo systemctl start proxy-web
```

## 🔧 配置说明

### 默认端口
| 协议 | 端口 | 加密 |
|------|------|------|
| VLESS | 443 | TLS |
| Trojan | 501 | TLS |
| VMess | 502 | TLS |
| Shadowsocks | 503 | 无 |
| Web管理 | 5080 | - |

### 默认用户
- **用户名**: `user`
- **密码**: 自动生成（安装后显示）
- **流量限制**: 无限

### 管理员密码
- 安装时自动生成
- 用于登录 Web 管理界面
- 保存在 `/etc/proxy-manager/install_info.txt`

## 🌐 访问地址

### Web 管理界面
- **本地**: http://127.0.0.1:5080
- **远程**: http://YOUR_SERVER_IP:5080

### 查看安装信息
```bash
cat /etc/proxy-manager/install_info.txt
```

## 📊 功能特性

### 🔒 安全特性
- TLS 加密传输
- 自签名证书生成
- 用户认证系统
- 流量限制控制

### 📱 客户端支持
- **VLESS**: V2RayN / Qv2ray / Shadowrocket
- **Trojan**: Qv2ray / Shadowrocket
- **VMess**: V2RayN / Qv2ray
- **Shadowsocks**: Shadowsocks / Clash

### 🎨 Web 界面
- 🎯 现代化设计
- 📋 用户管理面板
- 📊 流量统计显示
- 🔗 配置链接生成
- 📱 二维码快速导入
- 🔄 实时状态更新

## 🛠️ 服务管理

### 启动服务
```bash
sudo systemctl start xray proxy-web
```

### 停止服务
```bash
sudo systemctl stop xray proxy-web
```

### 重启服务
```bash
sudo systemctl restart xray proxy-web
```

### 查看状态
```bash
sudo systemctl status xray proxy-web
```

### 查看日志
```bash
# XRay 日志
sudo journalctl -u xray -f

# Web 日志
sudo journalctl -u proxy-web -f
```

## 🗑️ 卸载说明

### 完全卸载
```bash
sudo bash uninstall.sh
```

### 手动卸载
```bash
# 1. 停止服务
sudo systemctl stop xray proxy-web
sudo systemctl disable xray proxy-web

# 2. 删除文件
sudo rm -rf /etc/proxy-manager
sudo rm -rf /var/www/proxy-manager
sudo rm -f /etc/systemd/system/xray.service
sudo rm -f /etc/systemd/system/proxy-web.service

# 3. 重载系统服务
sudo systemctl daemon-reload
```

## 🔍 故障排除

### 常见问题

**1. 服务无法启动**
```bash
# 查看详细错误
sudo journalctl -u proxy-web -n 50

# 检查端口占用
sudo netstat -tlnp | grep 5080
```

**2. 模块缺失**
```bash
# 手动安装依赖
pip3 install flask flask-qrcode qrcode pillow pyyaml
```

**3. 防火墙问题**
```bash
# 开放端口
sudo ufw allow 5080/tcp
sudo ufw allow 443/tcp
sudo ufw reload
```

**4. 浏览器问题**
```bash
# 强制刷新缓存
Ctrl+Shift+R (Windows/Linux)
Cmd+Shift+R (Mac)
```

### 日志位置
- **系统日志**: `sudo journalctl -u proxy-web`
- **安装信息**: `/etc/proxy-manager/install_info.txt`
- **配置文件**: `/etc/proxy-manager/`

## 📖 版本信息

### v2.1-FINAL (当前版本)
- ✅ 修复 QRCode API 错误
- ✅ 实现现代化模态框界面
- ✅ 添加内容复制功能
- ✅ 增强自动依赖安装
- ✅ 跨平台支持（Linux + macOS）
- ✅ 改进错误处理和调试

### 主要更新
- 自动依赖安装（兼容 CentOS/Ubuntu）
- 现代化 UI 界面
- 二维码生成修复
- 系统兼容性改进

## 🔗 相关链接

- **GitHub**: https://github.com/HYweb3/proxy-manager
- **文档**: proxy-manager-src/ 目录
- **问题反馈**: GitHub Issues

## 📞 技术支持

### 快速命令
```bash
# 查看用户列表
python3 /etc/proxy-manager/proxy_manager.py list

# 检查服务状态
sudo systemctl status proxy-web

# 查看安装信息
cat /etc/proxy-manager/install_info.txt
```

### 获取帮助
- 📖 查看详细文档: `proxy-manager-src/README.md`
- 🐛 报告问题: https://github.com/HYweb3/proxy-manager/issues
- 📧 查看安装日志: `sudo journalctl -u proxy-web -n 50`

---

**Proxy Manager v2.1-FINAL** - 让代理管理更简单 🚀