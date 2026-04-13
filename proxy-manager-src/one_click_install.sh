#!/bin/bash

#############################################
# Proxy Manager - 通用一键安装脚本
# 支持 Linux 和 macOS
# Web管理界面 | 用户管理 | 流量统计
#############################################

set -e  # 遇到错误立即退出

RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[36m"
CYAN="\033[36m"
MAGENTA="\033[35m"
PLAIN="\033[0m"
BOLD="\033[1m"

# 检测操作系统
if [[ "$OSTYPE" == "darwin"* ]]; then
    OS="macos"
    CONFIG_DIR="$HOME/.proxy-manager"
    WEB_DIR="$HOME/.proxy-manager"
    PYTHON_CMD="python3"
else
    OS="linux"
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}✗ Linux 需要root权限${PLAIN}"
        echo "请使用: sudo bash $0"
        exit 1
    fi
    CONFIG_DIR="/etc/proxy-manager"
    WEB_DIR="/var/www/proxy-manager"
    PYTHON_CMD="python3"
fi

# 端口配置
WEB_PORT=5080
PROXY_PORT=500

# 显示欢迎信息
clear
echo -e "${MAGENTA}"
cat << 'EOF'
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║        ███████╗██╗   ██╗██████╗ ███████╗██████╗               ║
║        ██╔════╝██║   ██║██╔══██╗██╔════╝██╔══██╗              ║
║        ███████╗██║   ██║██████╔╝█████╗  ██████╔╝              ║
║        ╚════██║██║   ██║██╔══██╗██╔══╝  ██╔══██╗              ║
║        ███████║╚██████╔╝██████╔╝███████╗██║  ██║              ║
║        ╚══════╝ ╚═════╝ ╚═════╝ ╚══════╝╚═╝  ╚═╝              ║
║                                                               ║
║                   ╔═╗╔═╗ ╦ ╦╔═╗╦ ╦                          ║
║                   ║ ║║ ╦ ╠═╣╠═╣╚╦╝                          ║
║                   ╚═╝╚═╝ ╩ ╩╩ ╩ ╩                          ║
║                                                               ║
║           ███████╗ ██████╗ ███████╗██╗     ██╗               ║
║           ██╔════╝██╔═══██╗██╔════╝██║     ██║               ║
║           █████╗  ██║   ██║█████╗  ██║     ██║               ║
║           ██╔══╝  ██║   ██║██╔══╝  ██║     ██║               ║
║           ██║     ╚██████╔╝███████╗███████╗███████╗          ║
║           ╚═╝      ╚═════╝ ╚══════╝╚══════╝╚══════╝          ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
EOF
echo -e "${PLAIN}"
echo -e "${CYAN}Proxy Manager 一键安装脚本${PLAIN}"
echo -e "${YELLOW}检测到的系统: ${BOLD}${OS}${PLAIN}"
echo ""

# 获取脚本目录
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# 询问是否继续
read -p "$(echo -e ${YELLOW}是否继续安装? [Y/n]: ${PLAIN})" confirm
if [[ ! "$confirm" =~ ^[Yy]$|^$ ]]; then
    echo -e "${RED}安装已取消${PLAIN}"
    exit 0
fi

# 步骤1: 检查Python
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${PLAIN}"
echo -e "${BOLD}${CYAN}[1/6] 检查 Python 环境${PLAIN}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${PLAIN}"

if ! command -v python3 &>/dev/null; then
    echo -e "${RED}✗ Python3 未安装${PLAIN}"
    exit 1
fi

PYTHON_VERSION=$(python3 --version 2>&1 | awk '{print $2}')
echo -e "${GREEN}✓${PLAIN} Python版本: ${PYTHON_VERSION}"

# 步骤2: 安装Python依赖
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${PLAIN}"
echo -e "${BOLD}${CYAN}[2/6] 安装 Python 依赖${PLAIN}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${PLAIN}"

echo "安装 Flask 和相关依赖..."

if [[ "$OS" == "macos" ]]; then
    pip3 install --break-system-packages flask flask-qrcode qrcode pillow pyyaml 2>/dev/null || \
    pip3 install flask flask-qrcode qrcode pillow pyyaml 2>/dev/null
else
    pip3 install -q flask flask-qrcode qrcode pillow pyyaml 2>/dev/null || \
    pip3 install -q flask flask-qrcode qrcode pillow pyyaml --break-system-packages 2>/dev/null
fi

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓${PLAIN} Python依赖安装完成"
else
    echo -e "${YELLOW}⚠ 部分依赖安装失败，尝试继续...${PLAIN}"
fi

# 步骤3: 创建配置目录
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${PLAIN}"
echo -e "${BOLD}${CYAN}[3/6] 创建配置目录${PLAIN}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${PLAIN}"

mkdir -p ${CONFIG_DIR}
mkdir -p ${WEB_DIR}/templates
mkdir -p ${WEB_DIR}/logs

echo -e "${GREEN}✓${PLAIN} 配置目录: ${CONFIG_DIR}"
echo -e "${GREEN}✓${PLAIN} Web目录: ${WEB_DIR}"

# 步骤4: 部署程序文件
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${PLAIN}"
echo -e "${BOLD}${CYAN}[4/6] 部署程序文件${PLAIN}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${PLAIN}"

# 部署proxy_manager.py
if [[ -f "${SCRIPT_DIR}/proxy_manager.py" ]]; then
    cp ${SCRIPT_DIR}/proxy_manager.py ${CONFIG_DIR}/
    chmod +x ${CONFIG_DIR}/proxy_manager.py
    echo -e "${GREEN}✓${PLAIN} proxy_manager.py 已部署"
else
    echo -e "${RED}✗ proxy_manager.py 不存在${PLAIN}"
    exit 1
fi

# 部署proxy_web.py
if [[ -f "${SCRIPT_DIR}/proxy_web.py" ]]; then
    # 使用源文件而不是复制，确保路径正确
    WEB_PY_PATH="${SCRIPT_DIR}/proxy_web.py"
    echo -e "${GREEN}✓${PLAIN} proxy_web.py 位置: ${WEB_PY_PATH}"
else
    echo -e "${RED}✗ proxy_web.py 不存在${PLAIN}"
    exit 1
fi

# 步骤5: 生成配置
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${PLAIN}"
echo -e "${BOLD}${CYAN}[5/6] 生成配置${PLAIN}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${PLAIN}"

# 生成管理员密码
if [[ "$OS" == "macos" ]]; then
    ADMIN_PASS=$(LC_ALL=C tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 16)
    USER_UUID=$(uuidgen)
    USER_PASS=$(LC_ALL=C tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 16)
    SERVER_IP=$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || echo "127.0.0.1")
else
    ADMIN_PASS=$(openssl rand -base64 16 | tr -d '=+/' | cut -c1-16)
    USER_UUID=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || ${PYTHON_CMD} -c "import uuid; print(uuid.uuid4())")
    USER_PASS=$(openssl rand -base64 16 | tr -d '=+/' | cut -c1-16)
    SERVER_IP=$(curl -s4 ip.sb 2>/dev/null || curl -s4 ifconfig.me 2>/dev/null || echo "your-server-ip")
fi

# 创建用户数据库
cat > ${CONFIG_DIR}/users.json << EOF
{
    "users": [
        {
            "username": "user",
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

echo -e "${GREEN}✓${PLAIN} 用户数据库已生成"

# 步骤6: 启动Web服务
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${PLAIN}"
echo -e "${BOLD}${CYAN}[6/6] 启动 Web 服务${PLAIN}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${PLAIN}"

# 停止已存在的服务
pkill -f "proxy_web.py" 2>/dev/null || true
sleep 1

# 启动Web服务
cd ${SCRIPT_DIR}
echo "启动目录: $(pwd)"
echo "Python文件: ${WEB_PY_PATH}"

nohup ${PYTHON_CMD} ${WEB_PY_PATH} > ${WEB_DIR}/logs/web.log 2>&1 &
WEB_PID=$!
echo $WEB_PID > ${WEB_DIR}/web.pid

echo -e "${YELLOW}等待服务启动...${PLAIN}"
sleep 3

# 检查服务状态
if ps -p $WEB_PID > /dev/null 2>&1; then
    echo -e "${GREEN}✓${PLAIN} Web服务已启动 (PID: $WEB_PID)"
else
    echo -e "${RED}✗${PLAIN} Web服务启动失败"
    echo ""
    echo -e "${YELLOW}查看日志:${PLAIN}"
    tail -n 20 ${WEB_DIR}/logs/web.log
    exit 1
fi

# 创建启动脚本
cat > ${HOME}/start-proxy-web.sh << STARTEOF
#!/bin/bash
# Proxy Manager Web 快速启动脚本

SCRIPT_DIR="\$( cd "\$( dirname "\${BASH_SOURCE[0]}" )" && pwd )"

# 检测OS
if [[ "\$OSTYPE" == "darwin"* ]]; then
    CONFIG_DIR="\$HOME/.proxy-manager"
    WEB_DIR="\$HOME/.proxy-manager"
else
    CONFIG_DIR="/etc/proxy-manager"
    WEB_DIR="/var/www/proxy-manager"
fi

# 停止旧服务
if [[ -f "\${WEB_DIR}/web.pid" ]]; then
    OLD_PID=\$(cat \${WEB_DIR}/web.pid 2>/dev/null)
    if [[ -n "\$OLD_PID" ]] && ps -p \$OLD_PID > /dev/null 2>&1; then
        echo "停止旧服务 (PID: \$OLD_PID)"
        kill \$OLD_PID 2>/dev/null
    fi
fi

# 清理残留进程
pkill -f "proxy_web.py" 2>/dev/null || true
sleep 1

# 找到proxy_web.py
if [[ -f "\${SCRIPT_DIR}/proxy-manager-src/proxy_web.py" ]]; then
    WEB_PY="\${SCRIPT_DIR}/proxy-manager-src/proxy_web.py"
elif [[ -f "\${WEB_DIR}/proxy_web.py" ]]; then
    WEB_PY="\${WEB_DIR}/proxy_web.py"
else
    echo "错误: 找不到 proxy_web.py"
    exit 1
fi

# 创建日志目录
mkdir -p \${WEB_DIR}/logs

# 启动服务
cd \$(dirname \$WEB_PY)
nohup python3 \$WEB_PY > \${WEB_DIR}/logs/web.log 2>&1 &
WEB_PID=\$!
echo \$WEB_PID > \${WEB_DIR}/web.pid

sleep 2

if ps -p \$WEB_PID > /dev/null 2>&1; then
    echo "Proxy Manager Web 已启动 (PID: \$WEB_PID)"
    echo "管理地址: http://127.0.0.1:5080"
else
    echo "启动失败，查看日志: \${WEB_DIR}/logs/web.log"
    exit 1
fi
STARTEOF

chmod +x ${HOME}/start-proxy-web.sh

# 保存安装信息
cat > ${CONFIG_DIR}/install_info.txt << INFOEOF
╔═══════════════════════════════════════════════════════════════╗
║              Proxy Manager 安装信息 - 请妥善保存               ║
╚═══════════════════════════════════════════════════════════════╝

系统: ${OS}
安装日期: $(date)
服务器IP: ${SERVER_IP}

【🔐 管理员密码】
${ADMIN_PASS}

【👤 默认用户信息】
用户名: user
UUID: ${USER_UUID}
密码: ${USER_PASS}
流量限制: 无限

【🌐 管理面板】
http://127.0.0.1:${WEB_PORT}
http://${SERVER_IP}:${WEB_PORT}

【🚀 快速启动】
bash ${HOME}/start-proxy-web.sh

【📊 用户管理】
python3 ${CONFIG_DIR}/proxy_manager.py list

【📝 查看日志】
tail -f ${WEB_DIR}/logs/web.log

【🛑 停止服务】
kill $(cat ${WEB_DIR}/web.pid)
INFOEOF

echo -e "${GREEN}✓${PLAIN} 安装信息已保存"

# 显示完成信息
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${PLAIN}"
echo -e "${BOLD}${GREEN}安装完成！${PLAIN}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${PLAIN}"
echo ""

echo -e "${MAGENTA}╔═══════════════════════════════════════════════════════════════╗${PLAIN}"
echo -e "${MAGENTA}║${PLAIN}           ${BOLD}${YELLOW}重要信息 - 请立即保存！${PLAIN}            ${MAGENTA}║${PLAIN}"
echo -e "${MAGENTA}╚═══════════════════════════════════════════════════════════════╝${PLAIN}"
echo ""
echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${PLAIN}"
echo -e "${RED}${BOLD}管理员密码: ${ADMIN_PASS}${PLAIN}"
echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${PLAIN}"
echo ""
echo -e "${CYAN}📱 访问地址:${PLAIN}"
echo -e "   本地:     ${GREEN}http://127.0.0.1:${WEB_PORT}${PLAIN}"
echo -e "   网络:     ${GREEN}http://${SERVER_IP}:${WEB_PORT}${PLAIN}"
echo ""
echo -e "${CYAN}👤 默认用户:${PLAIN}"
echo -e "   用户名:   ${GREEN}user${PLAIN}"
echo -e "   密码:     ${GREEN}${USER_PASS}${PLAIN}"
echo ""
echo -e "${CYAN}🚀 快速命令:${PLAIN}"
echo -e "   启动服务: ${YELLOW}bash ${HOME}/start-proxy-web.sh${PLAIN}"
echo -e "   查看日志: ${YELLOW}tail -f ${WEB_DIR}/logs/web.log${PLAIN}"
echo -e "   停止服务: ${YELLOW}kill \$(cat ${WEB_DIR}/web.pid)${PLAIN}"
echo ""
echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${PLAIN}"
echo -e "${GREEN}${BOLD}          安装成功！Web 管理界面已启动！${PLAIN}"
echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${PLAIN}"
echo ""
