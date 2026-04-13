#!/bin/bash

#############################################
# Proxy Manager - 完整一键安装脚本
# 新设备安装自动启动成功
#############################################

RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[36m"
CYAN="\033[36m"
MAGENTA="\033[35m"
PLAIN="\033[0m"
BOLD="\033[1m"

# 配置路径
CONFIG_DIR="/etc/proxy-manager"
WEB_DIR="/var/www/proxy-manager"
# 端口配置
VLESS_PORT=443     # VLESS (TLS加密)
TROJAN_PORT=501    # Trojan (TLS加密)
VMESS_PORT=502     # VMess (TLS加密)
SS_PORT=503        # Shadowsocks (无加密)
WEB_PORT=5080      # Web管理界面

echo -e "${MAGENTA}"
cat << 'EOF'
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║                   Proxy Manager 一键安装                      ║
║               新设备安装自动启动成功 v2.0                      ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
EOF
echo -e "${PLAIN}"

# 检查root权限
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}错误: 必须使用root用户运行此脚本${PLAIN}"
    echo "请使用: sudo bash $0"
    exit 1
fi

# 检测系统
if [[ -f /etc/redhat-release ]] || [[ -f /etc/opencloudos-release ]] || [[ -f /etc/system-release ]]; then
    release="centos"
    if command -v dnf &>/dev/null; then
        systemPackage="dnf"
    else
        systemPackage="yum"
    fi
elif [[ -f /etc/debian_version ]]; then
    release="debian"
    systemPackage="apt-get"
else
    echo -e "${RED}不支持的系统${PLAIN}"
    exit 1
fi

echo -e "${GREEN}✓${PLAIN} 系统检测: ${BOLD}${release}${PLAIN}"

# 获取脚本目录
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# 步骤1: 安装依赖
echo ""
echo -e "${BLUE}[1/8]${PLAIN} 安装系统依赖..."
if [[ "${release}" == "centos" ]]; then
    ${systemPackage} install -y curl wget unzip qrencode python3 python3-pip openssl 2>/dev/null
else
    apt-get update -qq
    apt-get install -y curl wget unzip qrencode python3 python3-pip openssl 2>/dev/null
fi
echo -e "${GREEN}✓${PLAIN} 系统依赖安装完成"

# 步骤2: 安装Python依赖
echo ""
echo -e "${BLUE}[2/8]${PLAIN} 安装Python依赖..."
pip3 install -q flask flask-qrcode qrcode pillow pyyaml cryptography 2>/dev/null || \
pip3 install -q flask flask-qrcode qrcode pillow pyyaml cryptography --break-system-packages 2>/dev/null
echo -e "${GREEN}✓${PLAIN} Python依赖安装完成"

# 步骤3: 安装XRay-core
echo ""
echo -e "${BLUE}[3/8]${PLAIN} 安装 XRay-core..."
ARCH=$(uname -m)
case ${ARCH} in
    x86_64) XRAY_ARCH="64" ;;
    aarch64) XRAY_ARCH="arm64" ;;
    armv7l) XRAY_ARCH="arm32-v7a" ;;
    *) echo -e "${RED}不支持的架构${PLAIN}" && exit 1 ;;
esac

XRAY_VERSION=$(curl -s https://api.github.com/repos/XTLS/Xray-core/releases/latest | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')
if [[ -z "$XRAY_VERSION" ]]; then
    XRAY_VERSION="v1.8.24"
fi

wget --no-check-certificate \
    "https://github.com/XTLS/Xray-core/releases/download/${XRAY_VERSION}/Xray-linux-${XRAY_ARCH}.zip" \
    -O /tmp/xray.zip

unzip -o /tmp/xray.zip -d /usr/local/bin/ xray geosite.dat geoip.dat 2>/dev/null
chmod +x /usr/local/bin/xray
rm -f /tmp/xray.zip
echo -e "${GREEN}✓${PLAIN} XRay-core 安装完成"

# 步骤4: 初始化配置
echo ""
echo -e "${BLUE}[4/8]${PLAIN} 初始化配置..."
mkdir -p ${CONFIG_DIR}
mkdir -p ${WEB_DIR}
mkdir -p /var/log/xray

# 生成密码
ADMIN_PASS=$(openssl rand -base64 16 | tr -d '=+/' | cut -c1-16)
SERVER_IP=$(curl -s4 ip.sb 2>/dev/null || curl -s4 ifconfig.me 2>/dev/null || echo "your-server-ip")
USER_NAME="user"
USER_UUID=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || python3 -c "import uuid; print(uuid.uuid4())")
USER_PASS=$(openssl rand -base64 16 | tr -d '=+/' | cut -c1-16)

# 创建用户数据库
cat > ${CONFIG_DIR}/users.json << EOF
{
    "users": [
        {
            "username": "${USER_NAME}",
            "uuid": "${USER_UUID}",
            "password": "${USER_PASS}",
            "traffic_limit": 0,
            "traffic_used": 0,
            "enabled": true,
            "created_at": "$(date -Iseconds 2>/dev/null || date +%Y-%m-%dT%H:%M:%S)",
            "last_active": null
        }
    ],
    "admin_password": "${ADMIN_PASS}",
    "port": ${PROXY_PORT},
    "domain": "${SERVER_IP}"
}
EOF

# 生成自签名证书
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout ${CONFIG_DIR}/server.key \
    -out ${CONFIG_DIR}/server.crt \
    -subj "/CN=${SERVER_IP}" 2>/dev/null
chmod 600 ${CONFIG_DIR}/server.key

echo -e "${GREEN}✓${PLAIN} 配置文件创建完成"

# 步骤5: 部署程序文件
echo ""
echo -e "${BLUE}[5/8]${PLAIN} 部署程序文件..."

# 复制proxy_manager.py
if [[ -f "${SCRIPT_DIR}/proxy_manager.py" ]]; then
    cp ${SCRIPT_DIR}/proxy_manager.py ${CONFIG_DIR}/
else
    echo -e "${YELLOW}⚠ 警告: proxy_manager.py 不存在${PLAIN}"
    exit 1
fi

chmod +x ${CONFIG_DIR}/proxy_manager.py

# 生成XRay配置文件 (关键步骤!)
echo -e "${YELLOW}正在生成 XRay 配置文件...${PLAIN}"
PYTHONIOENCODING=utf-8 python3 ${CONFIG_DIR}/proxy_manager.py update_config

if [[ ! -f "${CONFIG_DIR}/config.json" ]]; then
    echo -e "${RED}✗ XRay配置文件生成失败${PLAIN}"
    exit 1
fi
echo -e "${GREEN}✓${PLAIN} XRay配置文件生成完成"

# 步骤6: 创建系统服务
echo ""
echo -e "${BLUE}[6/8]${PLAIN} 创建系统服务..."

# XRay服务
cat > /etc/systemd/system/xray.service << EOF
[Unit]
Description=XRay Service
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/xray run -config ${CONFIG_DIR}/config.json
Restart=on-failure
RestartSec=3s

[Install]
WantedBy=multi-user.target
EOF

# Web服务 (使用proxy_web.py)
if [[ -f "${SCRIPT_DIR}/proxy_web.py" ]]; then
    cp ${SCRIPT_DIR}/proxy_web.py ${WEB_DIR}/
    cat > /etc/systemd/system/proxy-web.service << EOF
[Unit]
Description=Proxy Manager Web Interface
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=${WEB_DIR}
ExecStart=/usr/bin/python3 ${WEB_DIR}/proxy_web.py
Restart=on-failure
RestartSec=3s

[Install]
WantedBy=multi-user.target
EOF
fi

systemctl daemon-reload
echo -e "${GREEN}✓${PLAIN} 系统服务创建完成"

# 步骤7: 配置防火墙
echo ""
echo -e "${BLUE}[7/8]${PLAIN} 配置防火墙..."
if command -v firewall-cmd &>/dev/null; then
    firewall-cmd --permanent --add-port=${VLESS_PORT}/tcp 2>/dev/null
    firewall-cmd --permanent --add-port=${TROJAN_PORT}/tcp 2>/dev/null
    firewall-cmd --permanent --add-port=${VMESS_PORT}/tcp 2>/dev/null
    firewall-cmd --permanent --add-port=${SS_PORT}/tcp 2>/dev/null
    firewall-cmd --permanent --add-port=${SS_PORT}/udp 2>/dev/null
    firewall-cmd --permanent --add-port=${WEB_PORT}/tcp 2>/dev/null
    firewall-cmd --reload 2>/dev/null
    echo -e "${GREEN}✓${PLAIN} 防火墙规则已添加"
elif command -v ufw &>/dev/null; then
    ufw allow ${VLESS_PORT}/tcp 2>/dev/null
    ufw allow ${TROJAN_PORT}/tcp 2>/dev/null
    ufw allow ${VMESS_PORT}/tcp 2>/dev/null
    ufw allow ${SS_PORT}/tcp 2>/dev/null
    ufw allow ${SS_PORT}/udp 2>/dev/null
    ufw allow ${WEB_PORT}/tcp 2>/dev/null
    echo -e "${GREEN}✓${PLAIN} 防火墙规则已添加"
else
    echo -e "${YELLOW}⚠${PLAIN} 未检测到防火墙"
fi

# 步骤8: 启动服务
echo ""
echo -e "${BLUE}[8/8]${PLAIN} 启动服务..."

systemctl enable xray proxy-web 2>/dev/null
systemctl restart xray
sleep 2
if [[ -f "${WEB_DIR}/proxy_web.py" ]]; then
    systemctl restart proxy-web
    sleep 2
fi

# 检查服务状态
echo ""
echo -e "${BOLD}${CYAN}服务状态:${PLAIN}"
if systemctl is-active --quiet xray; then
    echo -e "   XRay服务:      ${GREEN}✓ 运行中${PLAIN}"
else
    echo -e "   XRay服务:      ${RED}✗ 未运行${PLAIN}"
fi

if systemctl is-active --quiet proxy-web; then
    echo -e "   Web管理界面:   ${GREEN}✓ 运行中${PLAIN}"
else
    echo -e "   Web管理界面:   ${YELLOW}- 未安装${PLAIN}"
fi

# 显示安装信息
echo ""
echo -e "${MAGENTA}╔═══════════════════════════════════════════════════════════════╗${PLAIN}"
echo -e "${MAGENTA}║${PLAIN}           ${BOLD}${YELLOW}重要信息 - 请立即保存！${PLAIN}            ${MAGENTA}║${PLAIN}"
echo -e "${MAGENTA}╚═══════════════════════════════════════════════════════════════╝${PLAIN}"
echo ""
echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${PLAIN}"
echo -e "${RED}${BOLD}管理员密码: ${ADMIN_PASS}${PLAIN}"
echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${PLAIN}"
echo ""
echo -e "${CYAN}服务器信息:${PLAIN}"
echo -e "   服务器IP:     ${GREEN}${SERVER_IP}${PLAIN}"
echo ""
echo -e "${CYAN}代理端口配置:${PLAIN}"
echo -e "   VLESS端口:    ${GREEN}${VLESS_PORT}${PLAIN} (TLS加密)"
echo -e "   Trojan端口:   ${GREEN}${TROJAN_PORT}${PLAIN} (TLS加密)"
echo -e "   VMess端口:    ${GREEN}${VMESS_PORT}${PLAIN} (TLS加密)"
echo -e "   SS端口:       ${GREEN}${SS_PORT}${PLAIN} (无加密)"
echo ""
echo -e "${CYAN}默认用户信息:${PLAIN}"
echo -e "   用户名:       ${GREEN}${USER_NAME}${PLAIN}"
echo -e "   用户密码:     ${GREEN}${USER_PASS}${PLAIN}"
echo -e "   流量限制:     ${GREEN}无限${PLAIN}"
echo ""

# 生成代理连接URL
VLESS_URL="vless://${USER_UUID}@${SERVER_IP}:${VLESS_PORT}?encryption=none&security=tls&type=tcp#ProxyManager_${USER_NAME}"
TROJAN_URL="trojan://${USER_PASS}@${SERVER_IP}:${TROJAN_PORT}?security=tls&type=tcp#ProxyManager_${USER_NAME}"
SS_URL="ss://aes-256-gcm:${USER_PASS}@${SERVER_IP}:${SS_PORT}#ProxyManager_${USER_NAME}"

echo -e "${CYAN}快速连接 (VLESS):${PLAIN}"
echo -e "${VLESS_URL}"
echo ""

# 生成二维码
if command -v qrencode &>/dev/null; then
    echo -e "${CYAN}VLESS 二维码:${PLAIN}"
    qrencode -t ANSIUTF8 "${VLESS_URL}"
    echo ""
fi

echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${PLAIN}"
echo -e "${GREEN}${BOLD}              安装成功！服务已自动启动！${PLAIN}"
echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${PLAIN}"
echo ""

# 保存安装信息到文件
cat > ${CONFIG_DIR}/install_info.txt << INFOEOF
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║              Proxy Manager 安装信息 - 请妥善保存               ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝

========================================
【基本信息】
========================================
安装日期: $(date)
服务器IP: ${SERVER_IP}
主机名: $(hostname)

========================================
【🔐 管理员密码】
========================================
${ADMIN_PASS}

⚠️  重要：请妥善保管管理员密码！用于登录Web管理面板

========================================
【👤 默认用户信息】
========================================
用户名: ${USER_NAME}
UUID: ${USER_UUID}
密码: ${USER_PASS}
流量限制: 无限

========================================
【🔌 端口配置】
========================================
VLESS:  ${VLESS_PORT}  (TLS加密)
Trojan: ${TROJAN_PORT}  (TLS加密)
VMess:  ${VMESS_PORT}  (TLS加密)
SS:     ${SS_PORT}  (无加密)

========================================
【📱 快速连接链接】
========================================

1️⃣ VLESS (推荐):
${VLESS_URL}

2️⃣ Trojan:
${TROJAN_URL}

3️⃣ Shadowsocks:
${SS_URL}

========================================
【🖼️ 二维码】
========================================
如需查看二维码，请在终端运行以下命令：

VLESS 二维码:
  qrencode -t ANSIUTF8 '${VLESS_URL}'

Trojan 二维码:
  qrencode -t ANSIUTF8 '${TROJAN_URL}'

Shadowsocks 二维码:
  qrencode -t ANSIUTF8 '${SS_URL}'

========================================
【⚡ 服务管理】
========================================
启动服务:
  systemctl start xray proxy-web

停止服务:
  systemctl stop xray proxy-web

重启服务:
  systemctl restart xray proxy-web

查看状态:
  systemctl status xray proxy-web

========================================
【📊 用户管理】
========================================
查看用户列表:
  python3 ${CONFIG_DIR}/proxy_manager.py list

添加新用户:
  python3 ${CONFIG_DIR}/proxy_manager.py add <用户名> <UUID> <密码>

删除用户:
  python3 ${CONFIG_DIR}/proxy_manager.py delete <用户名>

========================================
【📝 日志查看】
========================================
XRay访问日志:
  tail -f /var/log/xray/access.log

XRay系统日志:
  journalctl -u xray -f

========================================
【🔧 配置文件位置】
========================================
配置目录: ${CONFIG_DIR}
  - config.json      XRay配置
  - users.json       用户数据库
  - stats.json       流量统计

========================================
【🗑️ 卸载】
========================================
如需卸载，请运行:
  bash ${SCRIPT_DIR}/uninstall.sh

========================================
安装完成！请妥善保存此文件！
========================================
INFOEOF

echo -e "${GREEN}✓${PLAIN} 安装信息已保存到: ${YELLOW}${CONFIG_DIR}/install_info.txt${PLAIN}"
echo ""
