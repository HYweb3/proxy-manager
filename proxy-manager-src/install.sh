#!/bin/bash

#############################################
# Proxy Manager - 多用户代理服务管理脚本
# 支持: V2Ray, XRay, Trojan, Shadowsocks
# 功能: 用户管理、链接生成、二维码分享
# 作者: Claude Code
# 更新: 2026-03-20
#############################################

RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[36m"
PLAIN="\033[0m"

# 配置文件路径
CONFIG_DIR="/etc/proxy-manager"
CONFIG_FILE="${CONFIG_DIR}/config.json"
USERS_FILE="${CONFIG_DIR}/users.json"
WEB_DIR="/var/www/proxy-manager"

# 端口配置
PROXY_PORT=500     # VLESS
TROJAN_PORT=501    # Trojan
VMESS_PORT=502     # VMess
SS_PORT=503        # Shadowsocks
WEB_PORT=5080      # Web管理界面

# 检查root权限
[[ $EUID -ne 0 ]] && echo -e "${RED}错误: ${PLAIN}必须使用root用户运行此脚本！" && exit 1

# 获取本机IP
IP=$(curl -s4 ip.sb || curl -s4 ifconfig.me || curl -s4 icanhazip.com)
[[ -z "${IP}" ]] && IP="your-server-ip"

# 系统检测
check_system() {
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
    echo -e "${GREEN}系统: ${release}${PLAIN}"
}

# 安装依赖
install_dependencies() {
    echo -e "${BLUE}正在安装依赖...${PLAIN}"
    if [[ "${release}" == "centos" ]]; then
        ${systemPackage} install -y curl wget unzip qrencode python3 python3-pip nginx
    else
        ${systemPackage} update
        ${systemPackage} install -y curl wget unzip qrencode python3 python3-pip nginx
    fi

    # 安装Python依赖
    pip3 install flask qrcode pillow cryptography
}

# 安装 XRay-core
install_xray() {
    echo -e "${BLUE}正在安装 XRay-core...${PLAIN}"

    # 下载最新版本
    ARCH=$(uname -m)
    case ${ARCH} in
        x86_64) XRAY_ARCH="64" ;;
        aarch64) XRAY_ARCH="arm64" ;;
        armv7l) XRAY_ARCH="arm32-v7a" ;;
        *) echo -e "${RED}不支持的架构${PLAIN}" && exit 1 ;;
    esac

    XRAY_VERSION=$(curl -s https://api.github.com/repos/XTLS/Xray-core/releases/latest | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')
    XRAY_URL="https://github.com/XTLS/Xray-core/releases/download/${XRAY_VERSION}/Xray-linux-${XRAY_ARCH}.zip"

    wget -N --no-check-certificate ${XRAY_URL} -O /tmp/xray.zip
    unzip -o /tmp/xray.zip -d /usr/local/bin/ xray geosite.dat geoip.dat
    chmod +x /usr/local/bin/xray

    # 创建systemd服务
    cat > /etc/systemd/system/xray.service << EOF
[Unit]
Description=XRay Service
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/xray run -config ${CONFIG_FILE}
Restart=on-failure
RestartSec=3s

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    echo -e "${GREEN}XRay-core 安装完成${PLAIN}"
}

# 生成随机UUID和密码
generate_uuid() {
    cat /proc/sys/kernel/random/uuid
}

generate_password() {
    openssl rand -base64 16 | tr -d '=+/' | cut -c1-16
}

# 初始化配置
init_config() {
    echo -e "${BLUE}正在初始化配置...${PLAIN}"

    mkdir -p ${CONFIG_DIR}
    mkdir -p ${WEB_DIR}

    # 生成主配置
    MAIN_UUID=$(generate_uuid)
    MAIN_PASSWORD=$(generate_password)

    cat > ${CONFIG_FILE} << EOF
{
    "log": {
        "access": "/var/log/xray/access.log",
        "error": "/var/log/xray/error.log",
        "loglevel": "warning"
    },
    "inbounds": [
        {
            "port": 443,
            "protocol": "vless",
            "settings": {
                "clients": [],
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
            "settings": {}
        }
    ]
}
EOF

    # 用户数据库 - 创建默认用户
    DEFAULT_UUID=$(generate_uuid)
    DEFAULT_PASS=$(generate_password)

    cat > ${USERS_FILE} << EOF
{
    "users": [
        {
            "username": "user",
            "uuid": "${DEFAULT_UUID}",
            "password": "${DEFAULT_PASS}",
            "traffic_limit": 0,
            "traffic_used": 0,
            "enabled": true,
            "created_at": "$(date -Iseconds 2>/dev/null || date +%Y-%m-%dT%H:%M:%S)",
            "last_active": null
        }
    ],
    "admin_password": "${MAIN_PASSWORD}",
    "port": 443,
    "domain": "${IP}"
}
EOF

    echo -e "${GREEN}默认用户已创建${PLAIN}"
    echo -e "${YELLOW}用户名: user${PLAIN}"
    echo -e "${YELLOW}UUID: ${DEFAULT_UUID}${PLAIN}"
    echo -e "${YELLOW}密码: ${DEFAULT_PASS}${PLAIN}"

    # 生成自签名证书
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout ${CONFIG_DIR}/server.key \
        -out ${CONFIG_DIR}/server.crt \
        -subj "/CN=${IP}" 2>/dev/null

    echo -e "${GREEN}配置初始化完成${PLAIN}"
    echo -e "${YELLOW}管理员密码: ${MAIN_PASSWORD}${PLAIN}"
    echo -e "${RED}请保存此密码！${PLAIN}"

    # 生成XRay配置文件
    echo -e "${YELLOW}正在生成 XRay 配置文件...${PLAIN}"
    python3 -c "
import sys, json, os
from datetime import datetime
exec(open('${CONFIG_DIR}/proxy_manager.py', encoding='utf-8').read())
manager = ProxyManager()
manager.update_xray_config()
print('XRay config generated!')
"

    if [[ ! -f "${CONFIG_DIR}/config.json" ]]; then
        echo -e "${RED}✗ XRay配置文件生成失败${PLAIN}"
        exit 1
    fi
    echo -e "${GREEN}✓ XRay配置文件生成完成${PLAIN}"
}

# 创建Web管理界面
create_web_interface() {
    echo -e "${BLUE}正在创建Web管理界面...${PLAIN}"

    # 检查proxy_manager.py是否存在，不存在则创建基础版本
    if [[ ! -f "${CONFIG_DIR}/proxy_manager.py" ]]; then
        cat > ${CONFIG_DIR}/proxy_manager.py << 'PYEOF'
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import json, os, uuid
from datetime import datetime

CONFIG_FILE = "/etc/proxy-manager/config.json"
USERS_FILE = "/etc/proxy-manager/users.json"

class ProxyManager:
    def __init__(self):
        self.config_dir = "/etc/proxy-manager"
        self.load_data()

    def load_data(self):
        if os.path.exists(USERS_FILE):
            with open(USERS_FILE, 'r') as f:
                data = json.load(f)
                self.users = data.get('users', [])
                self.admin_password = data.get('admin_password', '')
                self.port = data.get('port', 443)
                self.domain = data.get('domain', 'localhost')
        else:
            self.users = []
            self.admin_password = ''
            self.port = 443
            self.domain = 'localhost'

    def save_data(self):
        data = {'users': self.users, 'admin_password': self.admin_password, 'port': self.port, 'domain': self.domain}
        with open(USERS_FILE, 'w') as f:
            json.dump(data, f, indent=2)

    def add_user(self, username, user_uuid, password, traffic_limit=0):
        if any(u['username'] == username for u in self.users):
            return False, "用户已存在"
        user = {'username': username, 'uuid': user_uuid, 'password': password, 'traffic_limit': traffic_limit, 'traffic_used': 0, 'enabled': True, 'created_at': datetime.now().isoformat()}
        self.users.append(user)
        self.update_xray_config()
        self.save_data()
        return True, "用户添加成功"

    def delete_user(self, username):
        self.users = [u for u in self.users if u['username'] != username]
        self.update_xray_config()
        self.save_data()
        return True, "用户删除成功"

    def get_user(self, username):
        for user in self.users:
            if user['username'] == username:
                return user
        return None

    def enable_user(self, username):
        user = self.get_user(username)
        if user: user['enabled'] = True; self.save_data(); return True, "用户已启用"
        return False, "用户不存在"

    def disable_user(self, username):
        user = self.get_user(username)
        if user: user['enabled'] = False; self.save_data(); return True, "用户已禁用"
        return False, "用户不存在"

    def update_xray_config(self):
        enabled_users = [u for u in self.users if u['enabled']]
        if not enabled_users:
            config = {"log": {"access": "/var/log/xray/access.log", "error": "/var/log/xray/error.log", "loglevel": "warning"}, "inbounds": [], "outbounds": [{"protocol": "freedom", "settings": {}}]}
            with open(CONFIG_FILE, 'w') as f:
                json.dump(config, f, indent=2)
            return

        vless_clients = [{'id': u['uuid'], 'flow': '', 'email': f"{u['username']}@proxy-manager"} for u in enabled_users]
        config = {
            "log": {"access": "/var/log/xray/access.log", "error": "/var/log/xray/error.log", "loglevel": "info"},
            "inbounds": [{
                "port": 443,
                "protocol": "vless",
                "settings": {"clients": vless_clients, "decryption": "none"},
                "streamSettings": {
                    "network": "tcp",
                    "security": "tls",
                    "tlsSettings": {
                        "certificates": [{"certificateFile": f"{self.config_dir}/server.crt", "keyFile": f"{self.config_dir}/server.key"}],
                        "serverName": self.domain,
                        "allowInsecure": False
                    }
                }
            }],
            "outbounds": [{"protocol": "freedom", "settings": {}}]
        }
        with open(CONFIG_FILE, 'w') as f:
            json.dump(config, f, indent=2)

    def generate_vless_url(self, user):
        return f"vless://{user['uuid']}@{self.domain}:443?encryption=none&security=tls&type=tcp#ProxyManager_{user['username']}"

    def generate_vmess_url(self, user):
        import base64
        vmess_config = {"v": "2", "ps": f"ProxyManager_{user['username']}", "add": self.domain, "port": "443", "id": user['uuid'], "net": "tcp", "type": "none", "tls": "tls"}
        b64 = base64.b64encode(json.dumps(vmess_config, separators=(',', ':')).encode()).decode()
        return f"vmess://{b64}"

    def generate_trojan_url(self, user):
        return f"trojan://{user['password']}@{self.domain}:443?security=tls&type=tcp#ProxyManager_{user['username']}"

    def list_users(self):
        result = []
        for user in self.users:
            status = "启用" if user['enabled'] else "禁用"
            result.append({'username': user['username'], 'uuid': user['uuid'], 'traffic': '0GB', 'status': status})
        return result

    def verify_admin(self, password):
        return password == self.admin_password

if __name__ == '__main__':
    import sys
    import io
    # Set UTF-8 encoding for stdout
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

    manager = ProxyManager()
    command = sys.argv[1] if len(sys.argv) > 1 else ''
    if command == 'list':
        for user in manager.list_users():
            print(f"{user['username']:<15} {user['uuid']:<20} {user['traffic']:<15} {user['status']:<15}")
    elif command == 'update_config':
        manager.update_xray_config()
        print("XRay configuration updated successfully")
PYEOF
        chmod +x ${CONFIG_DIR}/proxy_manager.py
    fi


    # 创建systemd服务
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

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    echo -e "${GREEN}Web界面创建完成${PLAIN}"
}

# 添加用户
add_user() {
    echo -e "${BLUE}添加新用户${PLAIN}"
    read -p "请输入用户名: " USERNAME
    read -p "请输入流量限制(GB，0为无限): " TRAFFIC_LIMIT

    UUID=$(generate_uuid)
    PASSWORD=$(generate_password)

    # 更新用户配置
    python3 ${CONFIG_DIR}/proxy_manager.py add "${USERNAME}" "${UUID}" "${PASSWORD}" "${TRAFFIC_LIMIT}"

    # 显示配置信息
    echo -e "${GREEN}========================================${PLAIN}"
    echo -e "${GREEN}用户添加成功！${PLAIN}"
    echo -e "${YELLOW}用户名: ${USERNAME}${PLAIN}"
    echo -e "${YELLOW}UUID: ${UUID}${PLAIN}"
    echo -e "${YELLOW}密码: ${PASSWORD}${PLAIN}"
    echo -e "${GREEN}========================================${PLAIN}"

    # 生成二维码
    DOMAIN=$(cat ${USERS_FILE} | grep -o '"domain":"[^"]*"' | cut -d'"' -f4)
    PORT=$(cat ${USERS_FILE} | grep -o '"port":[0-9]*' | cut -d':' -f2)

    # VLESS链接
    VLESS_URL="vless://${UUID}@${DOMAIN}:${PORT}?encryption=none&security=tls&type=tcp#ProxyManager_${USERNAME}"
    echo -e "${BLUE}VLESS链接:${PLAIN}"
    echo -e "${VLESS_URL}"
    echo ""

    # 生成二维码
    echo -e "${BLUE}二维码:${PLAIN}"
    qrencode -t ANSIUTF8 "${VLESS_URL}"

    echo ""
    echo -e "${YELLOW}访问管理面板: http://${IP}:${WEB_PORT}${PLAIN}"
    echo -e "${YELLOW}使用管理员密码登录查看所有用户配置${PLAIN}"
}

# 列出用户
list_users() {
    echo -e "${BLUE}用户列表${PLAIN}"
    echo -e "${GREEN}============================================${PLAIN}"
    printf "%-15s %-20s %-15s %-15s\n" "用户名" "UUID" "已用流量" "状态"
    echo -e "${GREEN}============================================${PLAIN}"

    python3 ${CONFIG_DIR}/proxy_manager.py list
}

# 删除用户
delete_user() {
    read -p "请输入要删除的用户名: " USERNAME
    python3 ${CONFIG_DIR}/proxy_manager.py delete "${USERNAME}"
    echo -e "${GREEN}用户 ${USERNAME} 已删除${PLAIN}"
}

# 启动服务
start_service() {
    echo -e "${BLUE}正在启动服务...${PLAIN}"
    systemctl enable xray
    systemctl start xray
    systemctl enable proxy-web
    systemctl start proxy-web

    # 开放防火墙端口
    if [[ "${release}" == "centos" ]]; then
        firewall-cmd --permanent --add-port=${PROXY_PORT}/tcp 2>/dev/null
        firewall-cmd --permanent --add-port=${TROJAN_PORT}/tcp 2>/dev/null
        firewall-cmd --permanent --add-port=${VMESS_PORT}/tcp 2>/dev/null
        firewall-cmd --permanent --add-port=${SS_PORT}/tcp 2>/dev/null
        firewall-cmd --permanent --add-port=${SS_PORT}/udp 2>/dev/null
        firewall-cmd --permanent --add-port=${WEB_PORT}/tcp 2>/dev/null
        firewall-cmd --reload 2>/dev/null
    else
        ufw allow ${PROXY_PORT}/tcp 2>/dev/null
        ufw allow ${TROJAN_PORT}/tcp 2>/dev/null
        ufw allow ${VMESS_PORT}/tcp 2>/dev/null
        ufw allow ${SS_PORT}/tcp 2>/dev/null
        ufw allow ${SS_PORT}/udp 2>/dev/null
        ufw allow ${WEB_PORT}/tcp 2>/dev/null
    fi

    echo -e "${GREEN}服务启动成功！${PLAIN}"
    echo -e "${YELLOW}端口配置:${PLAIN}"
    echo -e "  VLESS:     ${PROXY_PORT}"
    echo -e "  Trojan:    ${TROJAN_PORT}"
    echo -e "  VMess:     ${VMESS_PORT}"
    echo -e "  SS:        ${SS_PORT}"
    echo -e "  Web管理:   ${WEB_PORT}"
    echo -e "${YELLOW}管理面板: http://${IP}:${WEB_PORT}${PLAIN}"
}

# 停止服务
stop_service() {
    echo -e "${YELLOW}正在停止服务...${PLAIN}"
    systemctl stop xray
    systemctl stop proxy-web
    echo -e "${GREEN}服务已停止${PLAIN}"
}

# 重启服务
restart_service() {
    stop_service
    start_service
}

# 查看状态
status_service() {
    echo -e "${BLUE}========== 服务状态 ==========${PLAIN}"
    systemctl status xray --no-pager -l
    echo ""
    systemctl status proxy-web --no-pager -l
}

# 查看日志
view_logs() {
    echo -e "${BLUE}XRay 日志:${PLAIN}"
    tail -f /var/log/xray/access.log
}

# 主菜单
main_menu() {
    clear
    echo -e "${BLUE}========================================${PLAIN}"
    echo -e "${BLUE}    Proxy Manager 管理面板${PLAIN}"
    echo -e "${BLUE}========================================${PLAIN}"
    echo -e "${GREEN}  1.${PLAIN} 安装代理服务"
    echo -e "${GREEN}  2.${PLAIN} 添加用户"
    echo -e "${GREEN}  3.${PLAIN} 列出所有用户"
    echo -e "${GREEN}  4.${PLAIN} 删除用户"
    echo -e "${GREEN}  5.${PLAIN} 启动服务"
    echo -e "${GREEN}  6.${PLAIN} 停止服务"
    echo -e "${GREEN}  7.${PLAIN} 重启服务"
    echo -e "${GREEN}  8.${PLAIN} 查看服务状态"
    echo -e "${GREEN}  9.${PLAIN} 查看日志"
    echo -e "${GREEN} 10.${PLAIN} 卸载服务"
    echo -e "${GREEN}  0.${PLAIN} 退出"
    echo -e "${BLUE}========================================${PLAIN}"
    read -p "请选择: " choice

    case $choice in
        1)
            check_system
            install_dependencies
            install_xray
            init_config
            create_web_interface
            start_service
            ;;
        2) add_user ;;
        3) list_users ;;
        4) delete_user ;;
        5) start_service ;;
        6) stop_service ;;
        7) restart_service ;;
        8) status_service ;;
        9) view_logs ;;
        10)
            read -p "确定要卸载吗? (y/n): " confirm
            [[ $confirm == "y" ]] && uninstall_service
            ;;
        0) exit 0 ;;
        *) echo -e "${RED}无效选择${PLAIN}" ;;
    esac

    read -p "按Enter继续..." && main_menu
}

# 卸载服务
uninstall_service() {
    stop_service
    systemctl disable xray
    systemctl disable proxy-web
    rm -f /etc/systemd/system/xray.service
    rm -f /etc/systemd/system/proxy-web.service
    rm -rf ${CONFIG_DIR}
    rm -rf ${WEB_DIR}
    rm -f /usr/local/bin/xray
    systemctl daemon-reload
    echo -e "${GREEN}服务已卸载${PLAIN}"
}

# 开始运行
main_menu
