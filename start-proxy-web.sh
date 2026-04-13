#!/bin/bash
# Proxy Manager Web 快速启动脚本

# 颜色定义
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[36m"
PLAIN="\033[0m"
BOLD="\033[1m"

# 检测OS和设置路径
if [[ "$OSTYPE" == "darwin"* ]]; then
    WEB_DIR="$HOME/.proxy-manager"
    CONFIG_DIR="$HOME/.proxy-manager"
else
    WEB_DIR="/var/www/proxy-manager"
    CONFIG_DIR="/etc/proxy-manager"
fi

echo -e "${BLUE}═══════════════════════════════════════════════════════════${PLAIN}"
echo -e "${BOLD}${CYAN}Proxy Manager Web 服务${PLAIN}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${PLAIN}"
echo ""

# 检查文件是否存在
if [[ ! -f "${WEB_DIR}/proxy_web.py" ]]; then
    echo -e "${RED}✗ proxy_web.py 不存在于 ${WEB_DIR}${PLAIN}"
    echo ""
    echo -e "${YELLOW}请先运行安装脚本:${PLAIN}"
    echo "  bash /path/to/one_click_install.sh"
    exit 1
fi

# 停止已存在的服务
if [[ -f "${WEB_DIR}/web.pid" ]]; then
    OLD_PID=$(cat ${WEB_DIR}/web.pid 2>/dev/null)
    if [[ -n "$OLD_PID" ]] && ps -p $OLD_PID > /dev/null 2>&1; then
        echo -e "${YELLOW}⚠ 停止旧服务 (PID: $OLD_PID)${PLAIN}"
        kill $OLD_PID 2>/dev/null
        sleep 1
    fi
fi

# 清理可能残留的进程
pkill -f "proxy_web.py" 2>/dev/null

# 创建日志目录
mkdir -p ${WEB_DIR}/logs

# 启动服务
echo -e "${YELLOW}🚀 启动 Web 服务...${PLAIN}"
cd ${WEB_DIR}
nohup python3 ${WEB_DIR}/proxy_web.py > ${WEB_DIR}/logs/web.log 2>&1 &
WEB_PID=$!
echo $WEB_PID > ${WEB_DIR}/web.pid

# 等待服务启动
sleep 2

# 检查服务状态
if ps -p $WEB_PID > /dev/null 2>&1; then
    echo -e "${GREEN}✓${PLAIN} Web服务已启动"
    echo ""
    echo -e "${BOLD}${CYAN}服务信息:${PLAIN}"
    echo -e "   PID:        ${GREEN}${WEB_PID}${PLAIN}"
    echo -e "   日志:       ${YELLOW}${WEB_DIR}/logs/web.log${PLAIN}"
    echo ""
    echo -e "${BOLD}${CYAN}访问地址:${PLAIN}"
    echo -e "   本地:       ${GREEN}http://127.0.0.1:5080${PLAIN}"

    # 获取本机IP
    if [[ "$OSTYPE" == "darwin"* ]]; then
        LOCAL_IP=$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null)
    else
        LOCAL_IP=$(hostname -I | awk '{print $1}')
    fi

    if [[ -n "$LOCAL_IP" ]]; then
        echo -e "   局域网:     ${GREEN}http://${LOCAL_IP}:5080${PLAIN}"
    fi
    echo ""

    # 检查管理员密码
    if [[ -f "${CONFIG_DIR}/install_info.txt" ]]; then
        ADMIN_PASS=$(grep "管理员密码" ${CONFIG_DIR}/install_info.txt | tail -1 | sed 's/.*: //')
        if [[ -n "$ADMIN_PASS" ]]; then
            echo -e "${BOLD}${YELLOW}管理员密码: ${ADMIN_PASS}${PLAIN}"
            echo ""
        fi
    fi

    echo -e "${BOLD}${CYAN}常用命令:${PLAIN}"
    echo -e "   查看日志:   ${YELLOW}tail -f ${WEB_DIR}/logs/web.log${PLAIN}"
    echo -e "   停止服务:   ${YELLOW}kill ${WEB_PID}${PLAIN}"
    echo -e "   重启服务:   ${YELLOW}bash $0${PLAIN}"
    echo ""

else
    echo -e "${RED}✗${PLAIN} Web服务启动失败"
    echo ""
    echo -e "${YELLOW}查看错误日志:${PLAIN}"
    echo "  tail -n 20 ${WEB_DIR}/logs/web.log"
    echo ""
    exit 1
fi

echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${PLAIN}"
echo -e "${GREEN}${BOLD}          Web 管理界面已启动成功！${PLAIN}"
echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${PLAIN}"
echo ""
