#!/bin/bash

#############################################
# Proxy Manager - 卸载脚本
# 完全移除代理管理系统
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

echo -e "${MAGENTA}"
cat << 'EOF'
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║                   ███████╗██╗   ██╗██████╗                   ║
║                   ██╔════╝██║   ██║██╔══██╗                   ║
║                   ███████╗██║   ██║██████╔╝                   ║
║                   ╚════██║██║   ██║██╔══██╗                   ║
║                   ███████║╚██████╔╝██████╔╝                   ║
║                   ╚══════╝ ╚═════╝ ╚═════╝                    ║
║                                                               ║
║                   ╔═╗╔═╗ ╦ ╦╔═╗╦ ╦                          ║
║                   ║ ║║ ╦ ╠═╣╠═╣╚╦╝                          ║
║                   ╚═╝╚═╝ ╩ ╩╩ ╩ ╩                          ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
EOF
echo -e "${PLAIN}"
echo -e "${CYAN}Proxy Manager 卸载脚本${PLAIN}"
echo ""

# 检查root权限
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}✗ 错误: 必须使用root用户运行此脚本${PLAIN}"
    echo "请使用: sudo bash $0"
    exit 1
fi

# 警告
echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${PLAIN}"
echo -e "${RED}${BOLD}警告: 此操作将完全卸载 Proxy Manager！${PLAIN}"
echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${PLAIN}"
echo ""
echo -e "${YELLOW}将执行以下操作:${PLAIN}"
echo -e "   • 停止并禁用 xray 和 proxy-web 服务"
echo -e "   • 删除 systemd 服务文件"
echo -e "   • 删除配置目录: ${CONFIG_DIR}"
echo -e "   • 删除Web目录: ${WEB_DIR}"
echo -e "   • 删除 XRay-core 二进制文件"
echo -e "   • 关闭防火墙端口"
echo ""

read -p "$(echo -e ${YELLOW}确定要卸载吗? 输入 'yes' 继续: ${PLAIN})" confirm
if [[ "$confirm" != "yes" ]]; then
    echo -e "${GREEN}卸载已取消${PLAIN}"
    exit 0
fi

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${PLAIN}"
echo -e "${BOLD}${CYAN}开始卸载...${PLAIN}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${PLAIN}"
echo ""

# 步骤1: 停止服务
echo -e "${YELLOW}[1/6]${PLAIN} 停止服务..."

# 强制停止服务，避免卡住
systemctl stop xray 2>/dev/null || true
systemctl stop proxy-web 2>/dev/null || true
systemctl disable xray 2>/dev/null || true
systemctl disable proxy-web 2>/dev/null || true

# 等待最多5秒，如果服务还在运行则强制杀死
for i in {1..5}; do
    if ! systemctl is-active --quiet xray 2>/dev/null && ! systemctl is-active --quiet proxy-web 2>/dev/null; then
        break
    fi
    if [ $i -eq 5 ]; then
        echo -e "${YELLOW}⚠${PLAIN} 服务未正常停止，强制终止..."
        pkill -9 -f "python.*proxy_web" 2>/dev/null || true
        pkill -9 -f "xray" 2>/dev/null || true
    fi
    sleep 1
done

echo -e "${GREEN}✓${PLAIN} 服务已停止"

# 步骤2: 删除systemd服务
echo -e "${YELLOW}[2/6]${PLAIN} 删除systemd服务..."
rm -f /etc/systemd/system/xray.service
rm -f /etc/systemd/system/proxy-web.service
systemctl daemon-reload
echo -e "${GREEN}✓${PLAIN} systemd服务已删除"

# 步骤3: 删除配置文件
echo -e "${YELLOW}[3/6]${PLAIN} 删除配置文件..."
rm -rf ${CONFIG_DIR}
echo -e "${GREEN}✓${PLAIN} 配置目录已删除"

# 步骤4: 删除Web文件
echo -e "${YELLOW}[4/6]${PLAIN} 删除Web文件..."
rm -rf ${WEB_DIR}
echo -e "${GREEN}✓${PLAIN} Web目录已删除"

# 步骤5: 删除XRay-core
echo -e "${YELLOW}[5/6]${PLAIN} 删除XRay-core..."
rm -f /usr/local/bin/xray
rm -f /usr/local/bin/geosite.dat
rm -f /usr/local/bin/geoip.dat
echo -e "${GREEN}✓${PLAIN} XRay-core已删除"

# 步骤6: 关闭防火墙端口
echo -e "${YELLOW}[6/6]${PLAIN} 配置防火墙..."

# 设置超时避免防火墙命令卡住
timeout 10 firewall-cmd --state &>/dev/null
if [ $? -eq 0 ]; then
    # 使用防火墙命令，设置超时避免卡住
    timeout 5 firewall-cmd --permanent --remove-port=500/tcp &>/dev/null || true
    timeout 5 firewall-cmd --permanent --remove-port=501/tcp &>/dev/null || true
    timeout 5 firewall-cmd --permanent --remove-port=502/tcp &>/dev/null || true
    timeout 5 firewall-cmd --permanent --remove-port=503/tcp &>/dev/null || true
    timeout 5 firewall-cmd --permanent --remove-port=5080/tcp &>/dev/null || true
    timeout 10 firewall-cmd --reload &>/dev/null || true
    echo -e "${GREEN}✓${PLAIN} 防火墙规则已移除"
elif command -v ufw &>/dev/null; then
    ufw delete allow 500/tcp &>/dev/null || true
    ufw delete allow 501/tcp &>/dev/null || true
    ufw delete allow 502/tcp &>/dev/null || true
    ufw delete allow 503/tcp &>/dev/null || true
    ufw delete allow 5080/tcp &>/dev/null || true
    echo -e "${GREEN}✓${PLAIN} 防火墙规则已移除"
else
    echo -e "${YELLOW}⚠${PLAIN} 未检测到防火墙"
fi

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${PLAIN}"
echo -e "${BOLD}${GREEN}卸载完成！${PLAIN}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${PLAIN}"
echo ""
echo -e "${CYAN}注意:${PLAIN}"
echo -e "   • Python依赖包未删除 (可能被其他程序使用)"
echo -e "   • 日志文件保留在: /var/log/xray/"
echo -e "   • 如需完全清理，请手动删除上述目录"
echo ""
