#!/bin/bash

#############################################
# Proxy Manager - 多协议更新脚本
# 将现有安装更新为支持4协议
# VLESS(443), Trojan(501), VMess(502), SS(503)
#############################################

RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[36m"
PLAIN="\033[0m"

CONFIG_DIR="/etc/proxy-manager"

echo -e "${BLUE}========================================${PLAIN}"
echo -e "${BLUE}  Proxy Manager 多协议更新${PLAIN}"
echo -e "${BLUE}========================================${PLAIN}"
echo ""

# 检查root权限
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}错误: 必须使用root用户运行此脚本${PLAIN}"
    exit 1
fi

# 备份现有配置
echo -e "${YELLOW}1️⃣  备份现有配置...${PLAIN}"
if [[ -f "${CONFIG_DIR}/users.json" ]]; then
    cp ${CONFIG_DIR}/users.json ${CONFIG_DIR}/users.json.backup
    echo -e "${GREEN}✓${PLAIN} users.json 已备份"
fi
if [[ -f "${CONFIG_DIR}/config.json" ]]; then
    cp ${CONFIG_DIR}/config.json ${CONFIG_DIR}/config.json.backup
    echo -e "${GREEN}✓${PLAIN} config.json 已备份"
fi
echo ""

# 更新 proxy_manager.py
echo -e "${YELLOW}2️⃣  更新 proxy_manager.py...${PLAIN}"
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

        # VLESS clients (443端口 - TLS加密)
        vless_clients = [{'id': u['uuid'], 'flow': '', 'email': f"{u['username']}@proxy-manager"} for u in enabled_users]

        # Trojan clients (501端口 - TLS加密)
        trojan_clients = [{'password': u['password'], 'email': f"{u['username']}@proxy-manager"} for u in enabled_users]

        # VMess clients (502端口 - TLS加密)
        vmess_clients = [{'id': u['uuid'], 'email': f"{u['username']}@proxy-manager"} for u in enabled_users]

        # Shadowsocks clients (503端口 - 无加密)
        ss_clients = [{'email': f"{u['username']}@proxy-manager", 'password': u['password'], 'method': 'aes-256-gcm'} for u in enabled_users]

        config = {
            "log": {"access": "/var/log/xray/access.log", "error": "/var/log/xray/error.log", "loglevel": "info"},
            "inbounds": [
                # VLESS - 端口443 (TLS加密)
                {
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
                },
                # Trojan - 端口501 (TLS加密)
                {
                    "port": 501,
                    "protocol": "trojan",
                    "settings": {"clients": trojan_clients},
                    "streamSettings": {
                        "network": "tcp",
                        "security": "tls",
                        "tlsSettings": {
                            "certificates": [{"certificateFile": f"{self.config_dir}/server.crt", "keyFile": f"{self.config_dir}/server.key"}],
                            "serverName": self.domain,
                            "allowInsecure": False
                        }
                    }
                },
                # VMess - 端口502 (TLS加密)
                {
                    "port": 502,
                    "protocol": "vmess",
                    "settings": {"clients": vmess_clients},
                    "streamSettings": {
                        "network": "tcp",
                        "security": "tls",
                        "tlsSettings": {
                            "certificates": [{"certificateFile": f"{self.config_dir}/server.crt", "keyFile": f"{self.config_dir}/server.key"}],
                            "serverName": self.domain,
                            "allowInsecure": False
                        }
                    }
                },
                # Shadowsocks - 端口503 (无加密)
                {
                    "port": 503,
                    "protocol": "shadowsocks",
                    "settings": {"clients": ss_clients, "network": "tcp,udp"}
                }
            ],
            "outbounds": [{"protocol": "freedom", "settings": {}}]
        }
        with open(CONFIG_FILE, 'w') as f:
            json.dump(config, f, indent=2)

    def generate_vless_url(self, user):
        return f"vless://{user['uuid']}@{self.domain}:443?encryption=none&security=tls&type=tcp#ProxyManager_{user['username']}"

    def generate_vmess_url(self, user):
        import base64
        vmess_config = {"v": "2", "ps": f"ProxyManager_{user['username']}", "add": self.domain, "port": "502", "id": user['uuid'], "net": "tcp", "type": "none", "tls": "tls"}
        b64 = base64.b64encode(json.dumps(vmess_config, separators=(',', ':')).encode()).decode()
        return f"vmess://{b64}"

    def generate_trojan_url(self, user):
        return f"trojan://{user['password']}@{self.domain}:501?security=tls&type=tcp#ProxyManager_{user['username']}"

    def generate_ss_url(self, user):
        import base64
        ss_method = "aes-256-gcm"
        ss_info = f"{ss_method}:{user['password']}@{self.domain}:503"
        ss_b64 = base64.b64encode(ss_info.encode()).decode().rstrip('=')
        return f"ss://{ss_b64}#ProxyManager_{user['username']}"

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
echo -e "${GREEN}✓${PLAIN} proxy_manager.py 已更新"
echo ""

# 重新生成配置
echo -e "${YELLOW}3️⃣  生成新的 XRay 配置...${PLAIN}"
PYTHONIOENCODING=utf-8 python3 ${CONFIG_DIR}/proxy_manager.py update_config

if [[ ! -f "${CONFIG_DIR}/config.json" ]]; then
    echo -e "${RED}✗ XRay配置文件生成失败${PLAIN}"
    exit 1
fi
echo -e "${GREEN}✓${PLAIN} XRay 配置已生成"
echo ""

# 重启服务
echo -e "${YELLOW}4️⃣  重启 XRay 服务...${PLAIN}"
systemctl restart xray
sleep 2

if systemctl is-active --quiet xray; then
    echo -e "${GREEN}✓${PLAIN} XRay 服务运行正常"
else
    echo -e "${RED}✗${PLAIN} XRay 服务启动失败"
    echo -e "${YELLOW}查看错误日志:${PLAIN}"
    journalctl -u xray -n 20 --no-pager
    exit 1
fi
echo ""

# 显示监听端口
echo -e "${YELLOW}5️⃣  检查监听端口...${PLAIN}"
netstat -tuln | grep -E ':(443|501|502|503|5080)'
echo ""

# 显示配置信息
echo -e "${YELLOW}6️⃣  配置信息...${PLAIN}"
if [[ -f "${CONFIG_DIR}/users.json" ]]; then
    ADMIN_PASS=$(cat ${CONFIG_DIR}/users.json | grep -o '"admin_password":"[^"]*"' | cut -d'"' -f4)
    SERVER_IP=$(cat ${CONFIG_DIR}/users.json | grep -o '"domain":"[^"]*"' | cut -d'"' -f4)
    
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${PLAIN}"
    echo -e "${GREEN}管理员密码: ${ADMIN_PASS}${PLAIN}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${PLAIN}"
    echo ""
    echo -e "${BLUE}服务器IP: ${SERVER_IP}${PLAIN}"
    echo ""
    echo -e "${BLUE}支持的协议:${PLAIN}"
    echo -e "  • VLESS    端口 443  (TLS加密)"
    echo -e "  • Trojan   端口 501  (TLS加密)"
    echo -e "  • VMess    端口 502  (TLS加密)"
    echo -e "  • SS       端口 503  (无加密)"
fi
echo ""

echo -e "${GREEN}========================================${PLAIN}"
echo -e "${GREEN}  ✅ 更新完成！${PLAIN}"
echo -e "${GREEN}========================================${PLAIN}"
echo ""
echo -e "${YELLOW}查看完整配置:${PLAIN}"
echo -e "  cat ${CONFIG_DIR}/config.json"
echo ""
echo -e "${YELLOW}查看用户列表:${PLAIN}"
echo -e "  python3 ${CONFIG_DIR}/proxy_manager.py list"
echo ""
