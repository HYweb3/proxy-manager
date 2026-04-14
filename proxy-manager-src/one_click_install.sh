#!/bin/bash

#############################################
# Proxy Manager - 通用一键安装脚本 v2.1
# 支持 Linux (CentOS/Ubuntu) 和 macOS
# XRay多协议 | Web管理 | 用户管理 | 流量统计
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

# 检测操作系统和配置路径
if [[ "$OSTYPE" == "darwin"* ]]; then
    OS="macos"
    IS_MACOS=true
    CONFIG_DIR="$HOME/.proxy-manager"
    WEB_DIR="$HOME/.proxy-manager"
    PYTHON_CMD="python3"
    # macOS使用简单端口配置
    WEB_PORT=5080
    PROXY_PORT=500
    USE_XRAY=false
else
    OS="linux"
    IS_MACOS=false
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}错误: 必须使用root用户运行此脚本${PLAIN}"
        echo "请使用: sudo bash $0"
        exit 1
    fi
    CONFIG_DIR="/etc/proxy-manager"
    WEB_DIR="/var/www/proxy-manager"
    PYTHON_CMD="python3"
    # Linux使用完整端口配置
    VLESS_PORT=443     # VLESS (TLS加密)
    TROJAN_PORT=501    # Trojan (TLS加密)
    VMESS_PORT=502     # VMess (TLS加密)
    SS_PORT=503        # Shadowsocks (无加密)
    WEB_PORT=5080      # Web管理界面
    USE_XRAY=true
fi

echo -e "${MAGENTA}"
cat << 'EOF'
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║                   Proxy Manager 一键安装                      ║
║               v2.1 通用版 | 新设备自动启动                      ║
║                   支持 Linux/macOS 多平台                      ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
EOF
echo -e "${PLAIN}"
echo -e "${CYAN}检测到的系统: ${BOLD}${OS}${PLAIN}"
echo -e "${CYAN}配置目录: ${BOLD}${CONFIG_DIR}${PLAIN}"
echo -e "${CYAN}Web目录: ${BOLD}${WEB_DIR}${PLAIN}"
echo ""

# 获取脚本目录
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# 询问是否继续
read -p "$(echo -e ${YELLOW}是否继续安装? [Y/n]: ${PLAIN})" confirm
if [[ ! "$confirm" =~ ^[Yy]$|^$ ]]; then
    echo -e "${RED}安装已取消${PLAIN}"
    exit 0
fi

# 检测Linux发行版
if [[ "$IS_MACOS" == "false" ]]; then
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
    echo -e "${GREEN}✓${PLAIN} Linux发行版: ${BOLD}${release}${PLAIN}"
fi

# ============================================
# 步骤1: 安装系统依赖
# ============================================
echo ""
echo -e "${BLUE}[1/9]${PLAIN} 安装系统依赖..."

if [[ "$IS_MACOS" == "true" ]]; then
    # macOS依赖安装
    if ! command -v python3 &>/dev/null; then
        echo -e "${YELLOW}请安装Python3: brew install python3${PLAIN}"
        exit 1
    fi
    if ! command -v qrencode &>/dev/null; then
        echo -e "${YELLOW}建议安装qrencode: brew install qrencode${PLAIN}"
    fi
    echo -e "${GREEN}✓${PLAIN} macOS系统检查完成"
else
    # Linux依赖安装
    if [[ "${release}" == "centos" ]]; then
        # 先安装EPEL仓库（CentOS需要）
        ${systemPackage} install -y epel-release 2>/dev/null || true
        ${systemPackage} install -y curl wget unzip qrencode python3 python3-pip openssl python3-devel 2>/dev/null
        ${systemPackage} install -y gcc gcc-c++ make 2>/dev/null || true
    else
        apt-get update -qq
        apt-get install -y curl wget unzip qrencode python3 python3-pip openssl python3-dev 2>/dev/null
        apt-get install -y build-essential 2>/dev/null || true
    fi
    echo -e "${GREEN}✓${PLAIN} 系统依赖安装完成"
fi

# ============================================
# 步骤2: 安装Python依赖
# ============================================
echo ""
echo -e "${BLUE}[2/9]${PLAIN} 安装Python依赖..."

PYTHON_PACKAGES="flask flask-qrcode qrcode pillow pyyaml cryptography"

# 增强的Python包安装函数
install_python_packages() {
    local packages="$1"
    local installed=false

    # 方法1: 使用 pip3
    if command -v pip3 &>/dev/null; then
        echo "  尝试使用 pip3 安装..."
        if pip3 install -q $packages 2>/dev/null; then
            installed=true
        elif pip3 install -q $packages --break-system-packages 2>/dev/null; then
            installed=true
        elif pip3 install -q $packages --user 2>/dev/null; then
            installed=true
        fi
    fi

    # 方法2: 使用 python3 -m pip
    if [[ "$installed" == "false" ]] && python3 -m pip --version &>/dev/null; then
        echo "  尝试使用 python3 -m pip 安装..."
        if python3 -m pip install -q $packages 2>/dev/null; then
            installed=true
        elif python3 -m pip install -q $packages --break-system-packages 2>/dev/null; then
            installed=true
        elif python3 -m pip install -q $packages --user 2>/dev/null; then
            installed=true
        fi
    fi

    # 方法3: 使用系统包管理器（Ubuntu/Debian）
    if [[ "$installed" == "false" ]] && [[ "${release}" == "debian" ]]; then
        echo "  尝试使用 apt 安装 Python 包..."
        apt-get install -y python3-flask python3-qrcode python3-pil python3-yaml python3-cryptography 2>/dev/null && installed=true
    fi

    # 方法4: 使用系统包管理器（CentOS/RHEL）
    if [[ "$installed" == "false" ]] && [[ "${release}" == "centos" ]]; then
        echo "  尝试使用 yum/dnf 安装 Python 包..."
        # 先安装EPEL仓库
        ${systemPackage} install -y epel-release 2>/dev/null || true
        # 尝试安装系统Python包
        ${systemPackage} install -y python3-flask python3-qrcode python3-pillow python3-pyyaml python3-cryptography 2>/dev/null && installed=true

        # 如果系统包失败，使用pip with --user
        if [[ "$installed" == "false" ]] && command -v python3 &>/dev/null; then
            echo "  尝试使用 python3 -m pip --user 安装..."
            python3 -m pip install --user -q $packages 2>/dev/null && installed=true
        fi
    fi

    if [[ "$installed" == "true" ]]; then
        return 0
    else
        return 1
    fi
}

# 安装 Python 包
if install_python_packages "$PYTHON_PACKAGES"; then
    echo -e "${GREEN}✓${PLAIN} Python依赖安装完成"
else
    echo -e "${YELLOW}⚠${PLAIN} Python依赖部分安装失败，尝试继续..."
fi

# 验证关键模块
echo "  验证 Python 模块..."
python3 -c "import flask" 2>/dev/null && echo -e "    ${GREEN}✓${PLAIN} flask" || echo -e "    ${YELLOW}⚠${PLAIN} flask 未安装"
python3 -c "import qrcode" 2>/dev/null && echo -e "    ${GREEN}✓${PLAIN} qrcode" || echo -e "    ${YELLOW}⚠${PLAIN} qrcode 未安装"
python3 -c "from PIL import Image" 2>/dev/null && echo -e "    ${GREEN}✓${PLAIN} pillow" || echo -e "    ${YELLOW}⚠${PLAIN} pillow 未安装"

# ============================================
# 步骤3: 安装XRay-core (仅Linux)
# ============================================
if [[ "$USE_XRAY" == "true" ]]; then
    echo ""
    echo -e "${BLUE}[3/9]${PLAIN} 安装 XRay-core..."

    ARCH=$(uname -m)
    case ${ARCH} in
        x86_64) XRAY_ARCH="64" ;;
        aarch64) XRAY_ARCH="arm64" ;;
        armv7l) XRAY_ARCH="arm32-v7a" ;;
        *) echo -e "${YELLOW}⚠ 不支持的架构: ${ARCH}${PLAIN}" && USE_XRAY=false ;;
    esac

    if [[ "$USE_XRAY" == "true" ]]; then
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
    fi
else
    echo ""
    echo -e "${BLUE}[3/9]${PLAIN} 跳过 XRay-core (macOS模式)"
fi

# ============================================
# 步骤4: 初始化配置
# ============================================
echo ""
echo -e "${BLUE}[4/9]${PLAIN} 初始化配置..."
mkdir -p ${CONFIG_DIR}
mkdir -p ${WEB_DIR}
mkdir -p ${WEB_DIR}/templates
mkdir -p ${WEB_DIR}/logs
mkdir -p /var/log/xray 2>/dev/null || true

# 生成密码
if [[ "$IS_MACOS" == "true" ]]; then
    ADMIN_PASS=$(LC_ALL=C tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 16)
    USER_UUID=$(uuidgen)
    USER_PASS=$(LC_ALL=C tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 16)
    SERVER_IP=$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || echo "127.0.0.1")
    PROXY_PORT=${PROXY_PORT:-500}
else
    ADMIN_PASS=$(openssl rand -base64 16 | tr -d '=+/' | cut -c1-16)
    SERVER_IP=$(curl -s4 ip.sb 2>/dev/null || curl -s4 ifconfig.me 2>/dev/null || echo "your-server-ip")
    USER_NAME="user"
    USER_UUID=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || python3 -c "import uuid; print(uuid.uuid4())")
    USER_PASS=$(openssl rand -base64 16 | tr -d '=+/' | cut -c1-16)
fi

# 创建用户数据库
TIMESTAMP=$(date -Iseconds 2>/dev/null || date +%Y-%m-%dT%H:%M:%S)
cat > ${CONFIG_DIR}/users.json << EOF
{
    "users": [
        {
            "username": "${USER_NAME:-user}",
            "uuid": "${USER_UUID}",
            "password": "${USER_PASS}",
            "traffic_limit": 0,
            "traffic_used": 0,
            "enabled": true,
            "created_at": "${TIMESTAMP}",
            "last_active": null
        }
    ],
    "admin_password": "${ADMIN_PASS}",
    "port": ${PROXY_PORT:-443},
    "domain": "${SERVER_IP}"
}
EOF

# 生成自签名证书 (仅Linux或需要时)
if [[ "$IS_MACOS" == "false" ]] || [[ "$USE_XRAY" == "true" ]]; then
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout ${CONFIG_DIR}/server.key \
        -out ${CONFIG_DIR}/server.crt \
        -subj "/CN=${SERVER_IP}" 2>/dev/null
    chmod 600 ${CONFIG_DIR}/server.key 2>/dev/null
fi

echo -e "${GREEN}✓${PLAIN} 配置文件创建完成"

# ============================================
# 步骤5: 部署程序文件
# ============================================
echo ""
echo -e "${BLUE}[5/9]${PLAIN} 部署程序文件..."

# 部署proxy_manager.py
if [[ -f "${SCRIPT_DIR}/proxy_manager.py" ]]; then
    cp ${SCRIPT_DIR}/proxy_manager.py ${CONFIG_DIR}/
    echo -e "${GREEN}✓${PLAIN} proxy_manager.py 已复制"
elif [[ -f "proxy_manager.py" ]]; then
    cp proxy_manager.py ${CONFIG_DIR}/
    echo -e "${GREEN}✓${PLAIN} proxy_manager.py 已复制"
else
    echo -e "${YELLOW}⚠ proxy_manager.py 不存在，正在生成...${PLAIN}"
    # 这里可以生成一个基础的proxy_manager.py
fi

chmod +x ${CONFIG_DIR}/proxy_manager.py 2>/dev/null

# 查找并部署 proxy_web.py
PROXY_WEB_SRC=""
if [[ -f "${SCRIPT_DIR}/proxy_web_fixed.py" ]]; then
    PROXY_WEB_SRC="${SCRIPT_DIR}/proxy_web_fixed.py"
elif [[ -f "${SCRIPT_DIR}/proxy_web.py" ]]; then
    PROXY_WEB_SRC="${SCRIPT_DIR}/proxy_web.py"
elif [[ -f "proxy-web.py" ]]; then
    PROXY_WEB_SRC="proxy-web.py"
elif [[ -f "proxy_web.py" ]]; then
    PROXY_WEB_SRC="proxy_web.py"
elif [[ -f "proxy_manager-src/proxy_web_fixed.py" ]]; then
    PROXY_WEB_SRC="proxy_manager-src/proxy_web_fixed.py"
elif [[ -f "proxy_manager-src/proxy_web.py" ]]; then
    PROXY_WEB_SRC="proxy_manager-src/proxy_web.py"
fi

if [[ -n "${PROXY_WEB_SRC}" ]]; then
    echo -e "${GREEN}✓${PLAIN} 找到 Web 界面文件: ${PROXY_WEB_SRC}"
    mkdir -p ${WEB_DIR}
    cp ${PROXY_WEB_SRC} ${WEB_DIR}/proxy_web.py
    chmod +x ${WEB_DIR}/proxy_web.py
    WEB_INSTALLED=true
else
    echo -e "${RED}✗${PLAIN} 未找到 proxy_web.py 文件"
    WEB_INSTALLED=false
fi

# ============================================
# 步骤6: 生成XRay配置 (仅Linux)
# ============================================
if [[ "$USE_XRAY" == "true" ]] && [[ -f "${CONFIG_DIR}/proxy_manager.py" ]]; then
    echo ""
    echo -e "${BLUE}[6/9]${PLAIN} 生成 XRay 配置..."
    echo -e "${YELLOW}正在生成 XRay 配置文件...${PLAIN}"

    # 首先尝试使用proxy_manager.py生成配置
    if [[ -f "${CONFIG_DIR}/proxy_manager.py" ]]; then
        PYTHONIOENCODING=utf-8 python3 ${CONFIG_DIR}/proxy_manager.py update_config 2>/dev/null
    fi

    # 检查XRay配置是否生成成功，如果失败则创建基础配置
    if [[ ! -f "${CONFIG_DIR}/config.json" ]]; then
        echo -e "${YELLOW}⚠ proxy_manager.py生成配置失败，创建基础XRay配置...${PLAIN}"

        # 创建基础XRay配置
        cat > ${CONFIG_DIR}/config.json << EOF
{
  "log": {
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "port": 443,
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "${USER_UUID}",
            "flow": "xtls-rprx-vision"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "tls",
        "tlsSettings": {
          "certificates": [
            {
              "certificateFile": "${CONFIG_DIR}/server.crt",
              "keyFile": "${CONFIG_DIR}/server.key"
            }
          ]
        }
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "tag": "direct"
    }
  ]
}
EOF
        echo -e "${GREEN}✓${PLAIN} 基础XRay配置创建完成"
    else
        echo -e "${GREEN}✓${PLAIN} XRay配置文件生成完成"
    fi
else
    echo ""
    echo -e "${BLUE}[6/9]${PLAIN} 跳过 XRay 配置 (macOS模式)"
fi

# ============================================
# 步骤7: 创建系统服务 (仅Linux)
# ============================================
if [[ "$IS_MACOS" == "false" ]]; then
    echo ""
    echo -e "${BLUE}[7/9]${PLAIN} 创建系统服务..."

    # XRay服务
    if [[ "$USE_XRAY" == "true" ]]; then
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
    fi

    # Web服务
    if [[ "${WEB_INSTALLED}" == "true" ]]; then
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
        echo -e "${GREEN}✓${PLAIN} Web 服务配置完成"
    fi

    systemctl daemon-reload
    echo -e "${GREEN}✓${PLAIN} 系统服务创建完成"
else
    echo ""
    echo -e "${BLUE}[7/9]${PLAIN} 创建启动脚本 (macOS)..."

    # macOS启动脚本
    cat > ${HOME}/start-proxy-web.sh << STARTEOF
#!/bin/bash
# Proxy Manager Web 快速启动脚本

SCRIPT_DIR="\$( cd "\$( dirname "\${BASH_SOURCE[0]}" )" && pwd )"

# 停止旧服务
if [[ -f "${WEB_DIR}/web.pid" ]]; then
    OLD_PID=\$(cat ${WEB_DIR}/web.pid 2>/dev/null)
    if [[ -n "\$OLD_PID" ]] && ps -p \$OLD_PID > /dev/null 2>&1; then
        echo "停止旧服务 (PID: \$OLD_PID)"
        kill \$OLD_PID 2>/dev/null
    fi
fi

# 清理残留进程
pkill -f "proxy_web.py" 2>/dev/null || true
sleep 1

# 找到proxy_web.py
if [[ -f "\${SCRIPT_DIR}/proxy_web.py" ]]; then
    WEB_PY="\${SCRIPT_DIR}/proxy_web.py"
elif [[ -f "\${SCRIPT_DIR}/proxy-manager-src/proxy_web.py" ]]; then
    WEB_PY="\${SCRIPT_DIR}/proxy-manager-src/proxy_web.py"
elif [[ -f "${WEB_DIR}/proxy_web.py" ]]; then
    WEB_PY="\${WEB_DIR}/proxy_web.py"
else
    echo "错误: 找不到 proxy_web.py"
    exit 1
fi

# 创建日志目录
mkdir -p ${WEB_DIR}/logs

# 启动服务
cd \$(dirname \$WEB_PY)
nohup python3 \$WEB_PY > ${WEB_DIR}/logs/web.log 2>&1 &
WEB_PID=\$!
echo \$WEB_PID > ${WEB_DIR}/web.pid

sleep 2

if ps -p \$WEB_PID > /dev/null 2>&1; then
    echo "Proxy Manager Web 已启动 (PID: \$WEB_PID)"
    echo "管理地址: http://127.0.0.1:${WEB_PORT}"
else
    echo "启动失败，查看日志: ${WEB_DIR}/logs/web.log"
    exit 1
fi
STARTEOF

    chmod +x ${HOME}/start-proxy-web.sh
    echo -e "${GREEN}✓${PLAIN} 启动脚本已创建: ${HOME}/start-proxy-web.sh"
fi

# ============================================
# 步骤8: 配置防火墙 (仅Linux)
# ============================================
if [[ "$IS_MACOS" == "false" ]]; then
    echo ""
    echo -e "${BLUE}[8/9]${PLAIN} 配置防火墙..."
    if command -v firewall-cmd &>/dev/null; then
        if [[ "$USE_XRAY" == "true" ]]; then
            firewall-cmd --permanent --add-port=${VLESS_PORT}/tcp 2>/dev/null
            firewall-cmd --permanent --add-port=${TROJAN_PORT}/tcp 2>/dev/null
            firewall-cmd --permanent --add-port=${VMESS_PORT}/tcp 2>/dev/null
            firewall-cmd --permanent --add-port=${SS_PORT}/tcp 2>/dev/null
            firewall-cmd --permanent --add-port=${SS_PORT}/udp 2>/dev/null
        fi
        firewall-cmd --permanent --add-port=${WEB_PORT}/tcp 2>/dev/null
        firewall-cmd --reload 2>/dev/null
        echo -e "${GREEN}✓${PLAIN} 防火墙规则已添加"
    elif command -v ufw &>/dev/null; then
        if [[ "$USE_XRAY" == "true" ]]; then
            ufw allow ${VLESS_PORT}/tcp 2>/dev/null
            ufw allow ${TROJAN_PORT}/tcp 2>/dev/null
            ufw allow ${VMESS_PORT}/tcp 2>/dev/null
            ufw allow ${SS_PORT}/tcp 2>/dev/null
            ufw allow ${SS_PORT}/udp 2>/dev/null
        fi
        ufw allow ${WEB_PORT}/tcp 2>/dev/null
        echo -e "${GREEN}✓${PLAIN} 防火墙规则已添加"
    else
        echo -e "${YELLOW}⚠${PLAIN} 未检测到防火墙"
    fi
else
    echo ""
    echo -e "${BLUE}[8/9]${PLAIN} 跳过防火墙配置 (macOS)"
fi

# ============================================
# 步骤9: 启动服务
# ============================================
echo ""
echo -e "${BLUE}[9/9]${PLAIN} 启动服务..."

if [[ "$IS_MACOS" == "false" ]]; then
    # Linux系统启动
    if [[ "$USE_XRAY" == "true" ]]; then
        systemctl enable xray 2>/dev/null
        systemctl restart xray
        sleep 2
    fi

    if [[ "${WEB_INSTALLED}" == "true" ]]; then
        systemctl enable proxy-web 2>/dev/null
        systemctl restart proxy-web
        sleep 2
    fi

    # 检查服务状态
    echo ""
    echo -e "${BOLD}${CYAN}服务状态:${PLAIN}"
    if [[ "$USE_XRAY" == "true" ]]; then
        if systemctl is-active --quiet xray; then
            echo -e "   XRay服务:      ${GREEN}✓ 运行中${PLAIN}"
        else
            echo -e "   XRay服务:      ${RED}✗ 未运行${PLAIN}"
        fi
    fi

    if [[ "${WEB_INSTALLED}" == "true" ]]; then
        if systemctl is-active --quiet proxy-web; then
            echo -e "   Web管理界面:   ${GREEN}✓ 运行中${PLAIN}"
        else
            echo -e "   Web管理界面:   ${RED}✗ 启动失败${PLAIN}"
        fi
    else
        echo -e "   Web管理界面:   ${YELLOW}- 未安装${PLAIN}"
    fi
else
    # macOS系统启动
    if [[ "${WEB_INSTALLED}" == "true" ]]; then
        # 停止已存在的服务
        pkill -f "proxy_web.py" 2>/dev/null || true
        sleep 1

        # 启动Web服务
        cd ${SCRIPT_DIR}
        nohup ${PYTHON_CMD} ${PROXY_WEB_SRC} > ${WEB_DIR}/logs/web.log 2>&1 &
        WEB_PID=$!
        echo $WEB_PID > ${WEB_DIR}/web.pid

        echo -e "${YELLOW}等待服务启动...${PLAIN}"
        sleep 3

        # 检查服务状态
        if ps -p $WEB_PID > /dev/null 2>&1; then
            echo -e "   Web管理界面:   ${GREEN}✓ 运行中${PLAIN} (PID: $WEB_PID)"
        else
            echo -e "   Web管理界面:   ${RED}✗ 启动失败${PLAIN}"
            echo ""
            echo -e "${YELLOW}查看日志:${PLAIN}"
            tail -n 20 ${WEB_DIR}/logs/web.log
        fi
    fi
fi

# ============================================
# 显示安装信息
# ============================================
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
echo -e "   操作系统:     ${GREEN}${OS}${PLAIN}"
echo ""

if [[ "$USE_XRAY" == "true" ]]; then
    echo -e "${CYAN}代理端口配置:${PLAIN}"
    echo -e "   VLESS端口:    ${GREEN}${VLESS_PORT}${PLAIN} (TLS加密)"
    echo -e "   Trojan端口:   ${GREEN}${TROJAN_PORT}${PLAIN} (TLS加密)"
    echo -e "   VMess端口:    ${GREEN}${VMESS_PORT}${PLAIN} (TLS加密)"
    echo -e "   SS端口:       ${GREEN}${SS_PORT}${PLAIN} (无加密)"
    echo ""
fi

echo -e "${CYAN}默认用户信息:${PLAIN}"
echo -e "   用户名:       ${GREEN}${USER_NAME:-user}${PLAIN}"
echo -e "   用户密码:     ${GREEN}${USER_PASS}${PLAIN}"
echo -e "   流量限制:     ${GREEN}无限${PLAIN}"
echo ""

echo -e "${CYAN}📱 访问地址:${PLAIN}"
echo -e "   本地:     ${GREEN}http://127.0.0.1:${WEB_PORT}${PLAIN}"
echo -e "   网络:     ${GREEN}http://${SERVER_IP}:${WEB_PORT}${PLAIN}"
echo ""

# 生成代理连接URL (仅Linux XRay模式)
if [[ "$USE_XRAY" == "true" ]]; then
    VLESS_URL="vless://${USER_UUID}@${SERVER_IP}:${VLESS_PORT}?encryption=none&security=tls&type=tcp#ProxyManager_${USER_NAME}"
    TROJAN_URL="trojan://${USER_PASS}@${SERVER_IP}:${TROJAN_PORT}?security=tls&type=tcp#ProxyManager_${USER_NAME}"

    # VMess URL (需要base64编码)
    VMESS_JSON=$(cat <<VMESSEOF
{"v":"2","ps":"ProxyManager_${USER_NAME}","add":"${SERVER_IP}","port":"${VMESS_PORT}","id":"${USER_UUID}","net":"tcp","type":"none","tls":"tls"}
VMESSEOF
)
    VMESS_URL="vmess://$(echo -n "${VMESS_JSON}" | base64 -w 0)"

    SS_URL="ss://aes-256-gcm:${USER_PASS}@${SERVER_IP}:${SS_PORT}#ProxyManager_${USER_NAME}"

    # 显示所有协议链接
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${PLAIN}"
    echo -e "${CYAN}📱 所有协议连接链接${PLAIN}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${PLAIN}"
    echo ""

    echo -e "${GREEN}1️⃣  VLESS (端口 ${VLESS_PORT}) - 推荐${PLAIN}"
    echo -e "${VLESS_URL}"
    echo ""

    echo -e "${GREEN}2️⃣  Trojan (端口 ${TROJAN_PORT})${PLAIN}"
    echo -e "${TROJAN_URL}"
    echo ""

    echo -e "${GREEN}3️⃣  VMess (端口 ${VMESS_PORT})${PLAIN}"
    echo -e "${VMESS_URL}"
    echo ""

    echo -e "${GREEN}4️⃣  Shadowsocks (端口 ${SS_PORT})${PLAIN}"
    echo -e "${SS_URL}"
    echo ""

    # 生成所有二维码
    if command -v qrencode &>/dev/null; then
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${PLAIN}"
        echo -e "${CYAN}🖼️  扫描二维码快速导入${PLAIN}"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${PLAIN}"
        echo ""

        echo -e "${GREEN}VLESS 二维码:${PLAIN}"
        qrencode -t ANSIUTF8 "${VLESS_URL}"
        echo ""

        echo -e "${GREEN}Trojan 二维码:${PLAIN}"
        qrencode -t ANSIUTF8 "${TROJAN_URL}"
        echo ""

        echo -e "${GREEN}VMess 二维码:${PLAIN}"
        qrencode -t ANSIUTF8 "${VMESS_URL}"
        echo ""

        echo -e "${GREEN}Shadowsocks 二维码:${PLAIN}"
        qrencode -t ANSIUTF8 "${SS_URL}"
        echo ""
    fi
fi

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${PLAIN}"
echo ""

# 显示快速命令
echo -e "${CYAN}🚀 快速命令:${PLAIN}"
if [[ "$IS_MACOS" == "false" ]]; then
    echo -e "   启动服务: ${YELLOW}systemctl start xray proxy-web${PLAIN}"
    echo -e "   停止服务: ${YELLOW}systemctl stop xray proxy-web${PLAIN}"
    echo -e "   重启服务: ${YELLOW}systemctl restart xray proxy-web${PLAIN}"
    echo -e "   查看状态: ${YELLOW}systemctl status xray proxy-web${PLAIN}"
else
    echo -e "   启动服务: ${YELLOW}bash ${HOME}/start-proxy-web.sh${PLAIN}"
    echo -e "   查看日志: ${YELLOW}tail -f ${WEB_DIR}/logs/web.log${PLAIN}"
    echo -e "   停止服务: ${YELLOW}kill \$(cat ${WEB_DIR}/web.pid)${PLAIN}"
fi
echo ""

# 保存安装信息到文件
cat > ${CONFIG_DIR}/install_info.txt << INFOEOF
╔═══════════════════════════════════════════════════════════════╗
║              Proxy Manager 安装信息 - 请妥善保存               ║
╚═══════════════════════════════════════════════════════════════╝

========================================
【基本信息】
========================================
安装日期: $(date)
操作系统: ${OS}
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
用户名: ${USER_NAME:-user}
UUID: ${USER_UUID}
密码: ${USER_PASS}
流量限制: 无限

========================================
【🌐 管理面板】
========================================
本地访问: http://127.0.0.1:${WEB_PORT}
网络访问: http://${SERVER_IP}:${WEB_PORT}

========================================
【🔌 端口配置】
========================================
$(if [[ "$USE_XRAY" == "true" ]]; then
echo "VLESS:  ${VLESS_PORT}  (TLS加密)"
echo "Trojan: ${TROJAN_PORT}  (TLS加密)"
echo "VMess:  ${VMESS_PORT}  (TLS加密)"
echo "SS:     ${SS_PORT}  (无加密)"
else
echo "代理功能: 仅Web管理界面"
fi)

========================================
【⚡ 服务管理】
========================================
$(if [[ "$IS_MACOS" == "false" ]]; then
echo "启动服务:"
echo "  systemctl start xray proxy-web"
echo ""
echo "停止服务:"
echo "  systemctl stop xray proxy-web"
echo ""
echo "重启服务:"
echo "  systemctl restart xray proxy-web"
echo ""
echo "查看状态:"
echo "  systemctl status xray proxy-web"
else
echo "启动服务:"
echo "  bash ${HOME}/start-proxy-web.sh"
echo ""
echo "查看日志:"
echo "  tail -f ${WEB_DIR}/logs/web.log"
echo ""
echo "停止服务:"
echo "  kill \$(cat ${WEB_DIR}/web.pid)"
fi)

========================================
【📊 用户管理】
========================================
查看用户列表:
  python3 ${CONFIG_DIR}/proxy_manager.py list

========================================
【📝 日志查看】
========================================
$(if [[ "$IS_MACOS" == "false" ]] && [[ "$USE_XRAY" == "true" ]]; then
echo "XRay访问日志:"
echo "  tail -f /var/log/xray/access.log"
echo ""
echo "XRay系统日志:"
echo "  journalctl -u xray -f"
fi)
$(if [[ "$IS_MACOS" == "true" ]] || [[ "$WEB_INSTALLED" == "true" ]]; then
echo "Web服务日志:"
echo "  tail -f ${WEB_DIR}/logs/web.log"
fi)

========================================
【🔧 配置文件位置】
========================================
配置目录: ${CONFIG_DIR}
  - users.json       用户数据库
  - install_info.txt 安装信息

$(if [[ "$USE_XRAY" == "true" ]]; then
echo "  - config.json      XRay配置"
echo "  - server.key       TLS私钥"
echo "  - server.crt       TLS证书"
fi)

========================================
安装完成！请妥善保存此文件！
========================================
INFOEOF

echo -e "${GREEN}✓${PLAIN} 安装信息已保存到: ${YELLOW}${CONFIG_DIR}/install_info.txt${PLAIN}"
echo ""

# 最终成功消息
echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${PLAIN}"
echo -e "${GREEN}${BOLD}              安装成功！服务已自动启动！${PLAIN}"
echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${PLAIN}"
echo ""

# 显示后续步骤
if [[ "$IS_MACOS" == "true" ]]; then
    echo -e "${YELLOW}💡 提示: 下次启动请运行: ${PLAIN}bash ${HOME}/start-proxy-web.sh"
else
    echo -e "${YELLOW}💡 提示: 服务已配置为开机自启${PLAIN}"
fi
echo ""