#!/bin/bash

#############################################
# Proxy Manager - 端口配置修复脚本
# 统一所有端口配置并确保服务正确启动
#############################################

RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[36m"
PLAIN="\033[0m"

# 检查root权限
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}错误: 必须使用root用户运行此脚本！${PLAIN}"
    echo "请使用: sudo bash $0"
    exit 1
fi

echo -e "${BLUE}========================================${PLAIN}"
echo -e "${BLUE}Proxy Manager 端口配置修复${PLAIN}"
echo -e "${BLUE}========================================${PLAIN}"
echo ""

# 配置路径
CONFIG_DIR="/etc/proxy-manager"
WEB_DIR="/var/www/proxy-manager"
SCRIPT_DIR="/home/hnbwww/proxy-manager"

# 端口配置
PROXY_PORT=500     # VLESS
TROJAN_PORT=501    # Trojan
VMESS_PORT=502     # VMess
SS_PORT=503        # Shadowsocks
WEB_PORT=5080      # Web管理界面

echo -e "${YELLOW}正在更新配置文件...${PLAIN}"

# 1. 复制更新的文件
cp ${SCRIPT_DIR}/proxy_manager.py ${CONFIG_DIR}/
cp ${SCRIPT_DIR}/proxy_web.py ${WEB_DIR}/
cp ${SCRIPT_DIR}/config.json ${CONFIG_DIR}/
cp ${SCRIPT_DIR}/generate_config.py ${CONFIG_DIR}/

echo -e "${GREEN}✓${PLAIN} 配置文件已更新"

# 2. 更新 install_info.txt
IP=$(curl -s4 ip.sb || curl -s4 ifconfig.me || curl -s4 icanhazip.com)
ADMIN_PASS=$(cat ${CONFIG_DIR}/users.json 2>/dev/null | grep -o '"admin_password":"[^"]*"' | cut -d'"' -f4)
DEFAULT_UUID=$(cat ${CONFIG_DIR}/users.json 2>/dev/null | grep -o '"uuid":"[^"]*"' | head -1 | cut -d'"' -f4)
DEFAULT_PASS=$(cat ${CONFIG_DIR}/users.json 2>/dev/null | grep -o '"password":"[^"]*"' | head -1 | cut -d'"' -f4)

cat > ${CONFIG_DIR}/install_info.txt << EOF
===========================================
Proxy Manager 安装信息
===========================================
更新日期: $(date '+%Y-%m-%d %H:%M:%S')
服务器IP: ${IP}

管理员密码: ${ADMIN_PASS}

默认用户:
  用户名: user
  UUID: ${DEFAULT_UUID}
  密码: ${DEFAULT_PASS}

端口配置:
  VLESS:  ${PROXY_PORT}
  Trojan: ${TROJAN_PORT}
  VMess:  ${VMESS_PORT}
  SS:     ${SS_PORT}
  Web:    ${WEB_PORT}

代理连接:
  VLESS:  vless://${DEFAULT_UUID}@${IP}:${PROXY_PORT}?encryption=none&security=tls&type=tcp#ProxyManager_user
  Trojan: trojan://${DEFAULT_PASS}@${IP}:${TROJAN_PORT}?security=tls&type=tcp#ProxyManager_user
  VMess:  vmess://eyJhZGUiOiIxeC1zZXJ2ZXIiLCJhaWQiOiIwIiwiYWxwbiI6IiIsImZwIjoiIiwiaG9zdCI6IiR7SVB9IiwiaWQiOiIke0RFRkFVTFRfVVVJRH0iLCJuZXQiOiJ3cyIsInBhdGgiOiIvIiwicG9ydCI6IiR7Vk1FU1NfUE9S VH0iLCJwcyI6IlByb3h5TWFuYWdlciIsInNjeSI6ImF1dG8iLCJzbmkiOiIiLCJ0bHMiOiIxIiwidHlwZSI6IiIsInYiOiIyIn0=
  SS:     ss://YWVzLTI1Ni1nY206JHtERUZBVUxUX1BBU1N9QCR7SVB9OiR7U1NfUE9S VH0jUHJveHlNYW5hZ2VyX3VzZXI=

管理面板: http://${IP}:${WEB_PORT}
===========================================
EOF

echo -e "${GREEN}✓${PLAIN} 安装信息已更新"

# 3. 重启服务
echo ""
echo -e "${YELLOW}正在重启服务...${PLAIN}"

systemctl daemon-reload
systemctl restart xray
systemctl restart proxy-web

# 等待服务启动
sleep 2

# 检查服务状态
if systemctl is-active --quiet xray; then
    echo -e "${GREEN}✓${PLAIN} Xray 服务运行中"
else
    echo -e "${RED}✗${PLAIN} Xray 服务启动失败"
fi

if systemctl is-active --quiet proxy-web; then
    echo -e "${GREEN}✓${PLAIN} Web 管理界面运行中"
else
    echo -e "${RED}✗${PLAIN} Web 管理界面启动失败"
    echo -e "${YELLOW}尝试手动启动: python3 ${WEB_DIR}/proxy_web.py${PLAIN}"
fi

# 4. 更新防火墙规则
echo ""
echo -e "${YELLOW}正在配置防火墙...${PLAIN}"

if command -v firewall-cmd &>/dev/null; then
    firewall-cmd --permanent --add-port=${PROXY_PORT}/tcp 2>/dev/null
    firewall-cmd --permanent --add-port=${TROJAN_PORT}/tcp 2>/dev/null
    firewall-cmd --permanent --add-port=${VMESS_PORT}/tcp 2>/dev/null
    firewall-cmd --permanent --add-port=${SS_PORT}/tcp 2>/dev/null
    firewall-cmd --permanent --add-port=${SS_PORT}/udp 2>/dev/null
    firewall-cmd --permanent --add-port=${WEB_PORT}/tcp 2>/dev/null
    firewall-cmd --reload 2>/dev/null
    echo -e "${GREEN}✓${PLAIN} firewalld 防火墙规则已更新"
elif command -v ufw &>/dev/null; then
    ufw allow ${PROXY_PORT}/tcp 2>/dev/null
    ufw allow ${TROJAN_PORT}/tcp 2>/dev/null
    ufw allow ${VMESS_PORT}/tcp 2>/dev/null
    ufw allow ${SS_PORT}/tcp 2>/dev/null
    ufw allow ${SS_PORT}/udp 2>/dev/null
    ufw allow ${WEB_PORT}/tcp 2>/dev/null
    echo -e "${GREEN}✓${PLAIN} ufw 防火墙规则已更新"
else
    echo -e "${YELLOW}!${PLAIN} 未检测到防火墙，跳过"
fi

# 5. 显示状态
echo ""
echo -e "${BLUE}========================================${PLAIN}"
echo -e "${BLUE}服务状态${PLAIN}"
echo -e "${BLUE}========================================${PLAIN}"

echo -e "${YELLOW}端口监听状态:${PLAIN}"
ss -tlnp | grep -E "xray|proxy_web" | grep -E "500|501|502|503|5080" || echo -e "${RED}未检测到监听端口${PLAIN}"

echo ""
echo -e "${YELLOW}端口配置:${PLAIN}"
echo -e "  VLESS:     ${PROXY_PORT}"
echo -e "  Trojan:    ${TROJAN_PORT}"
echo -e "  VMess:     ${VMESS_PORT}"
echo -e "  SS:        ${SS_PORT}"
echo -e "  Web管理:   ${WEB_PORT}"

echo ""
echo -e "${GREEN}访问管理面板: http://${IP}:${WEB_PORT}${PLAIN}"
echo -e "${GREEN}用户配置页面: http://${IP}:${WEB_PORT}/user/username${PLAIN}"

echo ""
echo -e "${BLUE}========================================${PLAIN}"
echo -e "${GREEN}端口配置修复完成！${PLAIN}"
echo -e "${BLUE}========================================${PLAIN}"
