# Proxy Manager v1.0 - 下载安装指南

> 🔐 **多协议代理管理系统** | 🚀 **一键安装** | 📱 **全平台支持**

---

## 📦 下载信息

| 项目 | 信息 |
|------|------|
| **文件名** | proxy-manager-v1.0-full.tar.gz |
| **版本** | v1.0 |
| **大小** | 36KB |
| **发布日期** | 2026-03-20 |

### 🔐 校验信息

**MD5:**
```
5136f0a6cb49e5edca56631f8a4d5c7f
```

**SHA256:**
```
775ceef28dbbd74a1566e2fc5e2a355b24404ab6895a0a6cda777cf518b4cf4f
```

---

## ⚡ 快速开始

### 方式一：直接下载安装

```bash
# 下载安装包
wget https://your-domain.com/proxy-manager-v1.0-full.tar.gz

# 验证校验和（可选）
sha256sum proxy-manager-v1.0-full.tar.gz

# 解压
tar -xzf proxy-manager-v1.0-full.tar.gz
cd proxy-manager

# 一键安装
sudo bash quick_install.sh
```

### 方式二：使用curl

```bash
curl -O https://your-domain.com/proxy-manager-v1.0-full.tar.gz
tar -xzf proxy-manager-v1.0-full.tar.gz
cd proxy-manager
sudo bash quick_install.sh
```

---

## 📋 安装后操作

安装成功后，脚本会显示：

```
═══════════════════════════════════════════════════════════════
管理员密码: AbCdEf1234567890
═══════════════════════════════════════════════════════════════

服务器IP:     123.45.67.89

代理端口配置:
   VLESS端口:    500 (TLS加密)
   Trojan端口:   501 (TLS加密)
   VMess端口:    502 (TLS加密)
   SS端口:       503 (无加密)

Web管理面板:
   http://123.45.67.89:5080
```

### 重要提示

⚠️ **请立即保存以下信息：**
- 管理员密码
- 默认用户密码

💾 **安装信息保存位置：**
```
/etc/proxy-manager/install_info.txt
```

---

## 🌐 访问管理面板

安装完成后，访问Web管理面板：

```
http://your-server-ip:5080
```

使用管理员密码登录，即可：
- ✅ 添加/删除用户
- ✅ 设置流量限制
- ✅ 生成配置二维码
- ✅ 查看使用统计

---

## 📱 客户端配置

### 支持的协议

| 协议 | 端口 | 认证 | 加密 |
|------|------|------|------|
| VLESS | 500 | UUID | TLS |
| Trojan | 501 | 密码 | TLS |
| VMess | 502 | UUID | TLS |
| Shadowsocks | 503 | 密码 | 无 |

### 支持的客户端

- **iOS/macOS**: Shadowrocket, Quantumult X
- **Windows**: V2RayN, Clash
- **Android**: V2RayNG, Shadowsocks
- **Linux**: V2Ray, Clash

---

## 🛡️ 安全特性

- ✅ 所有渠道强制密码/UUID认证
- ✅ TLS加密传输（除Shadowsocks外）
- ✅ 用户隔离和流量限制
- ✅ 完整的访问日志记录
- ✅ 空用户时端口自动关闭

---

## 📚 详细文档

安装包中包含以下文档：

| 文档 | 说明 |
|------|------|
| `INSTALL.txt` | 快速安装指南 |
| `DEPLOY_GUIDE.md` | 完整部署指南 |
| `README.md` | 项目说明 |
| `SECURITY.md` | 安全配置说明 |
| `PORTS.md` | 端口配置详解 |
| `QUICKREF.md` | 快速参考手册 |

---

## 🔧 常用命令

```bash
# 查看服务状态
sudo systemctl status xray proxy-web

# 重启服务
sudo systemctl restart xray proxy-web

# 查看用户列表
python3 /etc/proxy-manager/proxy_manager.py list

# 查看访问日志
sudo tail -f /var/log/xray/access.log

# 安全检查
sudo bash security_check.sh

# 卸载
sudo bash uninstall.sh
```

---

## 📊 系统要求

| 项目 | 要求 |
|------|------|
| 操作系统 | CentOS 7+, Ubuntu 18.04+, Debian 10+, OpenCloudOS |
| CPU架构 | x86_64, aarch64, armv7l |
| 内存 | 最低 512MB，推荐 1GB |
| 权限 | Root 或 sudo |

---

## ❓ 常见问题

### 1. 无法访问Web界面？

检查防火墙：
```bash
# CentOS/RHEL
sudo firewall-cmd --add-port=5080/tcp --permanent
sudo firewall-cmd --reload

# Ubuntu/Debian
sudo ufw allow 5080/tcp
```

### 2. 服务无法启动？

查看日志：
```bash
sudo journalctl -u xray -n 50
sudo journalctl -u proxy-web -n 50
```

### 3. 如何修改端口？

编辑配置文件：
```bash
sudo nano /etc/proxy-manager/users.json
# 修改端口号
sudo systemctl restart xray
```

---

## 🆘 获取帮助

- 📖 查看详细文档: `cat DEPLOY_GUIDE.md`
- 🔍 运行诊断: `sudo bash security_check.sh`
- 📧 技术支持: support@example.com

---

## ⚖️ 免责声明

本项目仅供学习和研究使用，请遵守当地法律法规。

---

**祝使用愉快！** 🚀
