# Proxy Manager 完整部署指南

> 📦 **版本**: v1.0
> 📅 **更新日期**: 2026-03-20
> 🔐 **安全等级**: 企业级

---

## 📋 目录

1. [系统要求](#系统要求)
2. [快速部署](#快速部署)
3. [详细安装步骤](#详细安装步骤)
4. [配置说明](#配置说明)
5. [安全加固](#安全加固)
6. [日常维护](#日常维护)
7. [故障排查](#故障排查)
8. [升级卸载](#升级卸载)

---

## 系统要求

### 最低配置

| 项目 | 要求 |
|------|------|
| **操作系统** | CentOS 7+, Ubuntu 18.04+, Debian 10+, OpenCloudOS |
| **CPU架构** | x86_64, aarch64, armv7l |
| **内存** | 最低 512MB，推荐 1GB+ |
| **磁盘** | 最低 500MB 可用空间 |
| **权限** | Root 或 sudo 权限 |
| **网络** | 公网IP，开放端口 500-503, 5080 |

### 支持的Linux发行版

```bash
# RHEL系列
CentOS 7/8/9
RHEL 7/8/9
Rocky Linux
AlmaLinux
OpenCloudOS

# Debian系列
Ubuntu 18.04/20.04/22.04
Debian 10/11/12
```

---

## 快速部署

### 方式一：一键安装（推荐）

```bash
# 下载安装包
wget https://your-domain/proxy-manager-v1.0.tar.gz

# 或使用curl
curl -O https://your-domain/proxy-manager-v1.0.tar.gz

# 解压
tar -xzf proxy-manager-v1.0.tar.gz
cd proxy-manager

# 一键安装
sudo bash quick_install.sh
```

**安装完成后会显示：**
- 🔑 管理员密码
- 👤 默认用户信息
- 🔗 所有代理连接配置
- 📱 二维码（终端支持时）

### 方式二：在线安装

```bash
# 直接下载并运行
curl -fsSL https://your-domain/install.sh | sudo bash

# 或
wget -qO- https://your-domain/install.sh | sudo bash
```

---

## 详细安装步骤

### 步骤 1: 准备工作

#### 1.1 更新系统

```bash
# CentOS/RHEL
sudo dnf update -y
# 或
sudo yum update -y

# Ubuntu/Debian
sudo apt update && sudo apt upgrade -y
```

#### 1.2 检查系统环境

```bash
# 检查系统版本
cat /etc/os-release

# 检查CPU架构
uname -m

# 检查内存
free -h

# 检查磁盘空间
df -h
```

#### 1.3 确认root权限

```bash
# 确保是root用户或有sudo权限
sudo -v

# 或切换到root
sudo su -
```

### 步骤 2: 下载和解压

```bash
# 创建工作目录
mkdir -p ~/proxy-manager
cd ~/proxy-manager

# 上传或下载安装包
# 方式A: 从本地上传
scp proxy-manager-v1.0.tar.gz user@server:~/proxy-manager/

# 方式B: 从URL下载
wget https://your-domain/proxy-manager-v1.0.tar.gz

# 解压
tar -xzf proxy-manager-v1.0.tar.gz
cd proxy-manager

# 查看文件列表
ls -lh
```

**应该看到以下文件：**
```
quick_install.sh       # 一键安装脚本
uninstall.sh           # 卸载脚本
security_check.sh      # 安全检查脚本
verify_security.sh     # 安全验证脚本
proxy_manager.py       # 核心管理器
proxy_web.py           # Web管理界面
README.md              # 项目说明
SECURITY.md            # 安全文档
PORTS.md               # 端口说明
QUICKREF.md            # 快速参考
requirements.txt       # Python依赖
```

### 步骤 3: 执行安装

```bash
# 添加执行权限（如果需要）
chmod +x *.sh

# 运行安装脚本
sudo bash quick_install.sh
```

**安装过程：**

```
╔═══════════════════════════════════════════════════════════════╗
║                   Proxy Manager 安装中                      ║
╚═══════════════════════════════════════════════════════════════╝

✓ 系统检测: centos
✓ CPU架构: x86_64

[1/8] 安装系统依赖...
✓ 系统依赖安装完成

[2/8] 安装Python依赖...
✓ Python依赖安装完成

[3/8] 安装 XRay-core...
下载 XRay-core v1.8.24
✓ XRay-core 安装完成

[4/8] 初始化配置...
✓ 配置文件创建完成

[5/8] 部署程序文件...
✓ 程序文件部署完成

[6/8] 创建系统服务...
✓ 系统服务创建完成

[7/8] 配置防火墙...
✓ firewalld 防火墙规则已添加

[8/8] 启动服务...
✓ 服务已启动

═══════════════════════════════════════════════════════════════
安装完成！
═══════════════════════════════════════════════════════════════

服务状态:
   XRay服务:      ✓ 运行中
   Web管理界面:   ✓ 运行中

═══════════════════════════════════════════════════════════════
重要信息 - 请立即保存！
═══════════════════════════════════════════════════════════════

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
管理员密码: AbCdEf1234567890
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

服务器信息:
   服务器IP:     123.45.67.89

代理端口配置:
   VLESS端口:    500 (TLS加密)
   Trojan端口:   501 (TLS加密)
   VMess端口:    502 (TLS加密)
   SS端口:       503 (无加密)

Web管理面板:
   管理地址:     http://123.45.67.89:5080

默认用户信息:
   用户名:       user
   用户密码:     xYz1234567890AbC
   流量限制:     无限

快速连接 (VLESS):
vless://uuid@123.45.67.89:500?encryption=none&security=tls&type=tcp#ProxyManager_user

快速连接 (Trojan):
trojan://xYz1234567890AbC@123.45.67.89:501?security=tls&type=tcp#ProxyManager_user

═══════════════════════════════════════════════════════════════
安装成功！请保存好上述信息！
═══════════════════════════════════════════════════════════════
```

### 步骤 4: 保存安装信息

```bash
# 安装信息已保存到
sudo cat /etc/proxy-manager/install_info.txt

# 建议备份此文件
sudo cp /etc/proxy-manager/install_info.txt ~/proxy-manager-info.txt
```

### 步骤 5: 验证安装

```bash
# 检查服务状态
sudo systemctl status xray
sudo systemctl status proxy-web

# 检查端口监听
sudo ss -tlnp | grep -E '500|501|502|503|5080'

# 运行安全检查
sudo bash security_check.sh

# 验证密码保护
sudo bash verify_security.sh
```

---

## 配置说明

### 目录结构

```
/etc/proxy-manager/              # 配置目录
├── config.json                 # XRay核心配置
├── users.json                  # 用户数据库
├── proxy_manager.py            # 核心管理器
├── server.crt                  # TLS证书
├── server.key                  # TLS私钥 (权限600)
└── install_info.txt            # 安装信息

/var/www/proxy-manager/         # Web界面
├── proxy_web.py                # Web应用
└── templates/                  # HTML模板

/var/log/xray/                  # 日志目录
├── access.log                  # 访问日志
└── error.log                   # 错误日志

/etc/systemd/system/            # 系统服务
├── xray.service                # XRay服务
└── proxy-web.service           # Web服务
```

### 端口配置

| 端口 | 协议 | 用途 | 加密 | 认证方式 |
|------|------|------|------|----------|
| 500 | VLESS | 代理服务 | TLS | UUID |
| 501 | Trojan | 代理服务 | TLS | 密码 |
| 502 | VMess | 代理服务 | TLS | UUID |
| 503 | Shadowsocks | 代理服务 | 无 | 密码 |
| 5080 | HTTP | Web管理 | 无 | 管理员密码 |

### Web管理面板

访问地址：`http://your-server-ip:5080`

**功能：**
- 用户管理（添加/删除/启用/禁用）
- 流量统计和限制
- 配置链接生成
- 二维码分享

---

## 安全加固

### 1. 修改默认密码

```bash
# 编辑用户数据库
sudo nano /etc/proxy-manager/users.json

# 修改admin_password字段
# 重新加载配置
sudo systemctl restart proxy-web
```

### 2. 配置防火墙

```bash
# CentOS/RHEL (firewalld)
sudo firewall-cmd --permanent --add-port=500/tcp
sudo firewall-cmd --permanent --add-port=501/tcp
sudo firewall-cmd --permanent --add-port=502/tcp
sudo firewall-cmd --permanent --add-port=503/tcp
sudo firewall-cmd --permanent --add-port=5080/tcp
sudo firewall-cmd --reload

# Ubuntu/Debian (ufw)
sudo ufw allow 500/tcp
sudo ufw allow 501/tcp
sudo ufw allow 502/tcp
sudo ufw allow 503/tcp
sudo ufw allow 5080/tcp
```

### 3. 使用有效证书（可选）

```bash
# 使用Let's Encrypt
sudo dnf/yum/apt install certbot

# 申请证书
sudo certbot certonly --standalone -d your-domain.com

# 复制证书
sudo cp /etc/letsencrypt/live/your-domain.com/fullchain.pem /etc/proxy-manager/server.crt
sudo cp /etc/letsencrypt/live/your-domain.com/privkey.pem /etc/proxy-manager/server.key
sudo chmod 600 /etc/proxy-manager/server.key

# 重启服务
sudo systemctl restart xray
```

### 4. 定期安全检查

```bash
# 每周运行一次
sudo bash security_check.sh

# 检查日志
sudo tail -f /var/log/xray/access.log

# 监控流量
python3 /etc/proxy-manager/proxy_manager.py list
```

---

## 日常维护

### 服务管理

```bash
# 启动服务
sudo systemctl start xray
sudo systemctl start proxy-web

# 停止服务
sudo systemctl stop xray
sudo systemctl stop proxy-web

# 重启服务
sudo systemctl restart xray
sudo systemctl restart proxy-web

# 开机自启
sudo systemctl enable xray
sudo systemctl enable proxy-web

# 查看状态
sudo systemctl status xray
sudo systemctl status proxy-web
```

### 用户管理

#### 命令行方式

```bash
# 添加用户
python3 /etc/proxy-manager/proxy_manager.py add \
  username \
  uuid \
  password \
  traffic_limit_gb

# 删除用户
python3 /etc/proxy-manager/proxy_manager.py delete username

# 列出用户
python3 /etc/proxy-manager/proxy_manager.py list

# 启用/禁用用户
python3 /etc/proxy-manager/proxy_manager.py enable username
python3 /etc/proxy-manager/proxy_manager.py disable username
```

#### Web界面方式

1. 访问 `http://your-server-ip:5080`
2. 使用管理员密码登录
3. 在用户管理界面操作

### 日志管理

```bash
# 查看实时日志
sudo tail -f /var/log/xray/access.log
sudo journalctl -u xray -f
sudo journalctl -u proxy-web -f

# 查看最近100条
sudo journalctl -u xray -n 100

# 按时间过滤
sudo journalctl -u xray --since "1 hour ago"

# 清理旧日志
sudo truncate -s 0 /var/log/xray/access.log
sudo journalctl --vacuum-time=7d
```

### 备份与恢复

#### 备份

```bash
# 创建备份目录
mkdir -p ~/proxy-backup
cd ~/proxy-backup

# 备份配置
sudo cp /etc/proxy-manager/users.json ./users.json.backup
sudo cp /etc/proxy-manager/config.json ./config.json.backup

# 备份证书
sudo cp /etc/proxy-manager/server.crt ./server.crt.backup
sudo cp /etc/proxy-manager/server.key ./server.key.backup

# 打包备份
tar -czf proxy-backup-$(date +%Y%m%d).tar.gz *.backup

# 删除临时文件
rm *.backup
```

#### 恢复

```bash
# 解压备份
tar -xzf proxy-backup-20260320.tar.gz

# 停止服务
sudo systemctl stop xray proxy-web

# 恢复配置
sudo cp users.json.backup /etc/proxy-manager/users.json
sudo cp config.json.backup /etc/proxy-manager/config.json
sudo cp server.crt.backup /etc/proxy-manager/server.crt
sudo cp server.key.backup /etc/proxy-manager/server.key
sudo chmod 600 /etc/proxy-manager/server.key

# 启动服务
sudo systemctl start xray proxy-web
```

---

## 故障排查

### 常见问题

#### 1. 服务无法启动

**症状：**
```bash
sudo systemctl status xray
# 显示: failed
```

**解决方案：**
```bash
# 检查配置文件语法
sudo /usr/local/bin/xray -test -config /etc/proxy-manager/config.json

# 查看错误日志
sudo journalctl -u xray -n 50

# 检查端口占用
sudo ss -tlnp | grep -E '500|501|502|503'

# 检查文件权限
sudo ls -la /etc/proxy-manager/
```

#### 2. Web界面无法访问

**症状：** 无法打开 http://server-ip:5080

**解决方案：**
```bash
# 检查Web服务
sudo systemctl status proxy-web

# 检查端口
sudo ss -tlnp | grep 5080

# 检查防火墙
sudo firewall-cmd --list-ports
# 或
sudo ufw status

# 查看Web日志
sudo journalctl -u proxy-web -n 50
```

#### 3. 客户端无法连接

**症状：** 客户端连接超时或认证失败

**解决方案：**
```bash
# 检查服务状态
sudo systemctl status xray

# 验证用户配置
python3 /etc/proxy-manager/proxy_manager.py list

# 检查访问日志
sudo tail -f /var/log/xray/access.log

# 验证配置
sudo bash verify_security.sh
```

#### 4. 端口被占用

**症状：** 安装时提示端口已被使用

**解决方案：**
```bash
# 查找占用进程
sudo ss -tlnp | grep :500
sudo lsof -i :500

# 停止占用进程或修改端口
# 修改 /etc/proxy-manager/users.json 中的 port 字段
```

### 诊断工具

```bash
# 完整安全检查
sudo bash security_check.sh

# 密码保护验证
sudo bash verify_security.sh

# 系统状态检查
sudo systemctl status xray proxy-web

# 网络连接测试
sudo ss -tlnp
```

---

## 升级卸载

### 升级

```bash
# 1. 备份当前配置
sudo bash /home/hnbwww/proxy-manager/security_check.sh > ~/backup-report.txt
sudo cp /etc/proxy-manager/users.json ~/users.json.backup

# 2. 下载新版本
wget https://your-domain/proxy-manager-v1.1.tar.gz
tar -xzf proxy-manager-v1.1.tar.gz
cd proxy-manager

# 3. 更新程序文件
sudo cp proxy_manager.py /etc/proxy-manager/
sudo cp proxy_web.py /var/www/proxy-manager/

# 4. 重启服务
sudo systemctl restart xray proxy-web

# 5. 验证
sudo bash security_check.sh
```

### 卸载

```bash
# 运行卸载脚本
sudo bash uninstall.sh

# 或手动卸载
# 1. 停止服务
sudo systemctl stop xray proxy-web
sudo systemctl disable xray proxy-web

# 2. 删除服务
sudo rm /etc/systemd/system/xray.service
sudo rm /etc/systemd/system/proxy-web.service
sudo systemctl daemon-reload

# 3. 删除文件
sudo rm -rf /etc/proxy-manager
sudo rm -rf /var/www/proxy-manager
sudo rm /usr/local/bin/xray

# 4. 关闭防火墙端口
sudo firewall-cmd --permanent --remove-port=500/tcp
sudo firewall-cmd --permanent --remove-port=501/tcp
sudo firewall-cmd --permanent --remove-port=502/tcp
sudo firewall-cmd --permanent --remove-port=503/tcp
sudo firewall-cmd --permanent --remove-port=5080/tcp
sudo firewall-cmd --reload
```

---

## 附录

### A. 客户端配置示例

#### VLESS (端口500)
```
vless://uuid@server:500?encryption=none&security=tls&type=tcp#ProxyManager_user
```

#### Trojan (端口501)
```
trojan://password@server:501?security=tls&type=tcp#ProxyManager_user
```

#### VMess (端口502)
```json
{
  "v": "2",
  "ps": "ProxyManager_user",
  "add": "server",
  "port": "502",
  "id": "uuid",
  "net": "tcp",
  "type": "none",
  "tls": "tls"
}
```

#### Shadowsocks (端口503)
```
ss://base64(method:password)@server:503#ProxyManager_user
```

### B. 支持的客户端

| 客户端 | 平台 | 下载地址 |
|--------|------|----------|
| Shadowrocket | iOS/macOS | App Store |
| V2RayN | Windows | GitHub |
| V2RayNG | Android | Google Play |
| Quantumult X | iOS | App Store |
| Clash | 全平台 | GitHub |

### C. 系统要求详情

```
最低配置：
- CPU: 1核心
- 内存: 512MB
- 磁盘: 500MB
- 网络: 10Mbps

推荐配置：
- CPU: 2核心+
- 内存: 1GB+
- 磁盘: 10GB+
- 网络: 100Mbps+
```

### D. 性能优化

```bash
# 1. 调整文件描述符限制
sudo bash -c 'cat > /etc/security/limits.conf << EOF
* soft nofile 51200
* hard nofile 51200
EOF'

# 2. 优化TCP参数
sudo bash -c 'cat > /etc/sysctl.d/99-proxy.conf << EOF
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
net.ipv4.tcp_fastopen=3
EOF'

sudo sysctl -p /etc/sysctl.d/99-proxy.conf

# 3. 开启BBR加速
# 检查内核版本是否支持
uname -r
```

---

## 技术支持

- 📧 邮件: support@example.com
- 💬 Issues: GitHub Issues
- 📖 文档: https://docs.example.com

---

**部署愉快！** 🚀
