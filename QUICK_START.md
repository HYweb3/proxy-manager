# Proxy Manager - 快速开始指南

## 🚀 一键安装（推荐）

### 方式一：增强版一键安装（自动创建不限量用户）

```bash
wget -N --no-check-certificate https://raw.githubusercontent.com/hnbwww/proxy-manager/master/one_click_install.sh
chmod +x one_click_install.sh
sudo bash one_click_install.sh
```

**特点：**
- ✅ 全自动安装所有依赖
- ✅ 自动创建不限流量用户
- ✅ 安装完成自动显示所有协议链接
- ✅ 终端直接显示二维码
- ✅ 无需任何手动配置

**安装完成自动显示：**
- 📱 VLESS 链接 + 二维码
- 📱 VMESS 链接
- 📱 Trojan 链接 + 二维码
- 📱 Shadowrocket 链接 + 二维码
- 📱 Clash 配置

---

## 📋 系统要求

- **操作系统**: Linux (CentOS 7+, Ubuntu 18.04+, Debian 10+, OpenCloudOS)
- **Python版本**: Python 3.6+
- **权限**: Root权限
- **内存**: 最低512MB，推荐1GB+
- **网络**: 开放端口 443 (代理), 8081 (Web管理)

---

## 🔧 手动安装

如果一键安装失败，可以尝试手动安装：

### 1. 安装依赖

**CentOS/RHEL/OpenCloudOS:**
```bash
sudo dnf/yum install -y curl wget unzip qrencode python3 python3-pip openssl
```

**Ubuntu/Debian:**
```bash
sudo apt-get update
sudo apt-get install -y curl wget unzip qrencode python3 python3-pip openssl
```

### 2. 安装Python依赖

```bash
pip3 install flask flask-qrcode qrcode pillow pyyaml cryptography
```

### 3. 安装XRay-core

```bash
wget https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip
unzip Xray-linux-64.zip -d /usr/local/bin/
chmod +x /usr/local/bin/xray
```

### 4. 运行安装脚本

```bash
chmod +x auto_install.sh
sudo bash auto_install.sh
```

---

## 🌐 访问地址

安装完成后，可以通过以下地址访问：

| 服务 | 地址 | 说明 |
|------|------|------|
| **管理面板** | `http://服务器IP:8081` | 管理所有用户 |
| **用户配置** | `http://服务器IP:8081/user/用户名` | 查看个人配置 |

---

## 📱 客户端配置

### Shadowrocket / Quantumult X

1. 复制 VLESS 链接
2. 在客户端添加配置
3. 或扫描二维码导入

### Clash

1. 下载 Clash 配置文件
2. 导入到 Clash

### V2Ray / V2RayN

1. 复制 VMESS 链接
2. 在客户端导入

---

## 🔧 常用命令

```bash
# 服务管理
sudo systemctl start xray          # 启动代理
sudo systemctl start proxy-web     # 启动Web管理
sudo systemctl restart xray        # 重启代理
sudo systemctl restart proxy-web   # 重启Web管理

# 查看状态
sudo systemctl status xray
sudo systemctl status proxy-web

# 查看日志
sudo tail -f /var/log/xray/access.log
sudo journalctl -u xray -f
sudo journalctl -u proxy-web -f
```

---

## 🛡️ 防火墙配置

**firewalld (CentOS/RHEL):**
```bash
sudo firewall-cmd --permanent --add-port=443/tcp
sudo firewall-cmd --permanent --add-port=8081/tcp
sudo firewall-cmd --reload
```

**ufw (Ubuntu/Debian):**
```bash
sudo ufw allow 443/tcp
sudo ufw allow 8081/tcp
```

---

## ❓ 常见问题

### 端口被占用

如果8081端口被占用，可以修改端口：
```bash
# 修改 proxy_web.py 中的端口
# 将 app.run(host='0.0.0.0', port=8081) 改为其他端口
```

### 二维码无法显示

1. 检查 qrcode 库是否安装
2. VMESS 链接过长不支持二维码，请复制链接使用
3. VLESS、Trojan、Shadowrocket 支持二维码

### 服务无法启动

1. 检查端口占用: `netstat -tlnp | grep 443`
2. 查看错误日志: `journalctl -u xray -n 50`
3. 检查配置文件: `/usr/local/bin/xray -test -config /etc/proxy-manager/config.json`

---

## 📞 技术支持

如有问题，请检查：
- 系统要求和依赖是否满足
- 防火墙端口是否开放
- 服务是否正常运行
- 配置文件是否正确

---

## 🔄 更新

要更新到最新版本：
```bash
cd /home/hnbwww/proxy-manager
git pull
sudo systemctl restart xray proxy-web
```

---

## 🗑️ 卸载

```bash
sudo systemctl stop xray proxy-web
sudo systemctl disable xray proxy-web
sudo rm -f /etc/systemd/system/xray.service
sudo rm -f /etc/systemd/system/proxy-web.service
sudo rm -rf /etc/proxy-manager
sudo rm -rf /var/www/proxy-manager
sudo systemctl daemon-reload
```

---

**Proxy Manager** - 一个功能完整的代理服务管理系统

MIT License
