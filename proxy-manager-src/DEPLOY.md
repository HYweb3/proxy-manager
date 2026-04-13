# Proxy Manager 部署文档

## 系统要求

- **操作系统**: Linux (CentOS 7+, Ubuntu 18.04+, Debian 10+, OpenCloudOS)
- **Python版本**: Python 3.6+
- **权限**: Root权限
- **内存**: 最低512MB
- **网络**: 开放端口 443 (代理), 8081 (Web管理)

## 快速部署

### 方法一：一键自动安装

```bash
# 下载并运行自动安装脚本
wget -N --no-check-certificate https://raw.githubusercontent.com/hnbwww/proxy-manager/master/auto_install.sh
chmod +x auto_install.sh
sudo bash auto_install.sh
```

### 方法二：手动安装

#### 1. 安装系统依赖

**CentOS/RHEL/OpenCloudOS:**
```bash
sudo dnf install -y curl wget unzip qrencode python3 python3-pip openssl nginx
# 或使用 yum
sudo yum install -y curl wget unzip qrencode python3 python3-pip openssl nginx
```

**Ubuntu/Debian:**
```bash
sudo apt-get update
sudo apt-get install -y curl wget unzip qrencode python3 python3-pip openssl nginx
```

#### 2. 安装Python依赖

```bash
# 方式1: 使用requirements.txt
pip3 install -r requirements.txt

# 方式2: 手动安装
pip3 install flask flask-qrcode qrcode pillow pyyaml cryptography
```

#### 3. 安装XRay-core

```bash
# 下载最新版XRay
XRAY_VERSION=$(curl -s https://api.github.com/repos/XTLS/Xray-core/releases/latest | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')
wget -N --no-check-certificate "https://github.com/XTLS/Xray-core/releases/download/${XRAY_VERSION}/Xray-linux-64.zip" -O /tmp/xray.zip

# 解压并安装
sudo unzip -o /tmp/xray.zip -d /tmp/xray_temp
sudo cp /tmp/xray_temp/xray /usr/local/bin/
sudo cp /tmp/xray_temp/geosite.dat /usr/local/bin/
sudo cp /tmp/xray_temp/geoip.dat /usr/local/bin/
sudo chmod +x /usr/local/bin/xray
rm -rf /tmp/xray.zip /tmp/xray_temp
```

#### 4. 配置服务

```bash
# 创建配置目录
sudo mkdir -p /etc/proxy-manager
sudo mkdir -p /var/www/proxy-manager
sudo mkdir -p /var/log/xray

# 复制程序文件
sudo cp proxy_manager.py /etc/proxy-manager/
sudo cp proxy_web.py /var/www/proxy-manager/

# 生成管理员密码
ADMIN_PASS=$(openssl rand -base64 16 | tr -d '=+/' | cut -c1-16)
SERVER_IP=$(curl -s4 ip.sb 2>/dev/null || echo "your-server-ip")

# 创建用户数据库
sudo tee /etc/proxy-manager/users.json > /dev/null <<EOF
{
    "users": [],
    "admin_password": "${ADMIN_PASS}",
    "port": 443,
    "domain": "${SERVER_IP}"
}
EOF

# 生成TLS证书
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/proxy-manager/server.key \
    -out /etc/proxy-manager/server.crt \
    -subj "/CN=${SERVER_IP}"

sudo chmod 600 /etc/proxy-manager/server.key
```

#### 5. 创建systemd服务

**XRay服务:**
```bash
sudo tee /etc/systemd/system/xray.service > /dev/null <<EOF
[Unit]
Description=XRay Service
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/xray run -config /etc/proxy-manager/config.json
Restart=on-failure
RestartSec=3s

[Install]
WantedBy=multi-user.target
EOF
```

**Web服务:**
```bash
sudo tee /etc/systemd/system/proxy-web.service > /dev/null <<EOF
[Unit]
Description=Proxy Manager Web Interface
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/var/www/proxy-manager
ExecStart=/usr/bin/python3 /var/www/proxy-manager/proxy_web.py
Restart=on-failure
RestartSec=3s

[Install]
WantedBy=multi-user.target
EOF
```

#### 6. 启动服务

```bash
# 重载systemd配置
sudo systemctl daemon-reload

# 启动并设置开机自启
sudo systemctl enable xray
sudo systemctl enable proxy-web
sudo systemctl start xray
sudo systemctl start proxy-web

# 查看服务状态
sudo systemctl status xray
sudo systemctl status proxy-web
```

#### 7. 配置防火墙

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

## 访问服务

安装完成后，您可以通过以下地址访问：

- **Web管理面板**: `http://你的服务器IP:8081`
- **用户配置页面**: `http://你的服务器IP:8081/user/用户名`

管理员密码在安装过程中生成，请妥善保存。

如需查看管理员密码：
```bash
sudo cat /etc/proxy-manager/users.json | grep admin_password
```

## 目录结构

```
/etc/proxy-manager/           # 配置目录
├── config.json              # Xray配置文件
├── users.json               # 用户数据库
├── stats.json               # 流量统计
├── server.crt               # TLS证书
├── server.key               # TLS私钥
└── proxy_manager.py         # 配置管理器

/var/www/proxy-manager/      # Web界面目录
└── proxy_web.py             # Web服务程序

/var/log/xray/               # 日志目录
├── access.log               # 访问日志
└── error.log                # 错误日志

/usr/local/bin/
├── xray                     # Xray核心程序
├── geoip.dat                # IP地理位置数据
└── geosite.dat              # 域名分类数据
```

## 常用命令

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

# 查看服务状态
sudo systemctl status xray
sudo systemctl status proxy-web

# 查看日志
sudo tail -f /var/log/xray/access.log
sudo journalctl -u xray -f
sudo journalctl -u proxy-web -f
```

### 用户管理
```bash
# 列出所有用户
python3 /etc/proxy-manager/proxy_manager.py list

# 添加用户
python3 /etc/proxy-manager/proxy_manager.py add 用户名 UUID 密码 流量限制

# 删除用户
python3 /etc/proxy-manager/proxy_manager.py delete 用户名

# 启用用户
python3 /etc/proxy-manager/proxy_manager.py enable 用户名

# 禁用用户
python3 /etc/proxy-manager/proxy_manager.py disable 用户名

# 生成用户配置链接
python3 /etc/proxy-manager/proxy_manager.py urls 用户名
```

## 故障排查

### 服务无法启动

1. 检查端口是否被占用：
```bash
sudo ss -tlnp | grep 443
sudo ss -tlnp | grep 8081
```

2. 检查配置文件语法：
```bash
/usr/local/bin/xray -test -config /etc/proxy-manager/config.json
```

3. 查看详细错误日志：
```bash
sudo journalctl -u xray -n 50
sudo journalctl -u proxy-web -n 50
```

### Python模块缺失

如果出现模块导入错误：
```bash
pip3 install flask flask-qrcode qrcode pillow pyyaml
```

### 防火墙问题

检查防火墙状态：
```bash
# firewalld
sudo firewall-cmd --list-ports

# ufw
sudo ufw status
```

### 证书问题

如果证书过期，重新生成：
```bash
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/proxy-manager/server.key \
    -out /etc/proxy-manager/server.crt \
    -subj "/CN=你的域名或IP"
sudo chmod 600 /etc/proxy-manager/server.key
sudo systemctl restart xray
```

## 卸载

```bash
# 停止服务
sudo systemctl stop xray proxy-web

# 禁用服务
sudo systemctl disable xray proxy-web

# 删除服务文件
sudo rm -f /etc/systemd/system/xray.service
sudo rm -f /etc/systemd/system/proxy-web.service

# 删除程序文件
sudo rm -rf /etc/proxy-manager
sudo rm -rf /var/www/proxy-manager
sudo rm -f /usr/local/bin/xray
sudo rm -f /usr/local/bin/geoip.dat
sudo rm -f /usr/local/bin/geosite.dat

# 重载systemd
sudo systemctl daemon-reload
```

## 安全建议

1. **修改默认端口**: 考虑将代理端口从443改为其他端口
2. **使用域名**: 使用自己的域名并配置有效的SSL证书
3. **防火墙配置**: 只开放必要的端口
4. **定期更新**: 定期更新Xray核心和Python依赖
5. **密码管理**: 定期更换管理员密码和用户密码
6. **流量监控**: 设置合理的流量限制防止滥用

## 技术支持

如遇问题，请检查：
- [ ] 系统要求和依赖是否满足
- [ ] 防火墙端口是否开放
- [ ] 服务是否正常运行
- [ ] 配置文件是否正确
- [ ] 日志中的错误信息

## 更新日志

- **2026-03-20**: 修复Web端口冲突，默认使用8081端口
- **2026-03-20**: 添加Python依赖管理
- **2026-03-20**: 完善部署文档
