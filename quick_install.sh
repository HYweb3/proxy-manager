#!/bin/bash

#############################################
# Proxy Manager - 完整版一键安装脚本
# 支持所有功能：VLESS/VMESS/Trojan/SS 多协议
# Web管理界面 | 用户管理 | 流量统计
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
# 端口配置 - 从500开始，避免常见端口冲突
WEB_PORT=5080      # Web管理界面
PROXY_PORT=500     # VLESS 主端口
TROJAN_PORT=501    # Trojan
VMESS_PORT=502     # VMess
SS_PORT=503        # Shadowsocks

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
echo -e "${CYAN}完整功能一键安装脚本${PLAIN}"
echo -e "${YELLOW}支持: VLESS | VMESS | Trojan | Shadowsocks${PLAIN}"
echo ""

# 检查root权限
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}✗ 错误: 必须使用root用户运行此脚本${PLAIN}"
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
    echo -e "${RED}✗ 不支持的系统${PLAIN}"
    exit 1
fi

echo -e "${GREEN}✓${PLAIN} 系统检测: ${BOLD}${release}${PLAIN}"

# 检测架构
ARCH=$(uname -m)
case ${ARCH} in
    x86_64) XRAY_ARCH="64" ;;
    aarch64) XRAY_ARCH="arm64" ;;
    armv7l) XRAY_ARCH="arm32-v7a" ;;
    *)
        echo -e "${RED}✗ 不支持的CPU架构: ${ARCH}${PLAIN}"
        exit 1
        ;;
esac
echo -e "${GREEN}✓${PLAIN} CPU架构: ${BOLD}${ARCH}${PLAIN}"

# 询问是否继续
echo ""
read -p "$(echo -e ${YELLOW}是否继续安装? [Y/n]: ${PLAIN})" confirm
if [[ ! "$confirm" =~ ^[Yy]$|^$ ]]; then
    echo -e "${RED}安装已取消${PLAIN}"
    exit 0
fi

# 步骤1: 安装系统依赖
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${PLAIN}"
echo -e "${BOLD}${CYAN}[1/8] 安装系统依赖${PLAIN}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${PLAIN}"

if [[ "${release}" == "centos" ]]; then
    ${systemPackage} install -y curl wget unzip qrencode python3 python3-pip openssl 2>/dev/null
else
    apt-get update -qq
    apt-get install -y curl wget unzip qrencode python3 python3-pip openssl 2>/dev/null
fi
echo -e "${GREEN}✓${PLAIN} 系统依赖安装完成"

# 步骤2: 安装Python依赖
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${PLAIN}"
echo -e "${BOLD}${CYAN}[2/8] 安装Python依赖${PLAIN}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${PLAIN}"

pip3 install -q flask flask-qrcode qrcode pillow pyyaml cryptography 2>/dev/null || \
pip3 install -q flask flask-qrcode qrcode pillow pyyaml cryptography --break-system-packages 2>/dev/null
echo -e "${GREEN}✓${PLAIN} Python依赖安装完成"

# 步骤3: 安装XRay-core
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${PLAIN}"
echo -e "${BOLD}${CYAN}[3/8] 安装 XRay-core${PLAIN}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${PLAIN}"

XRAY_VERSION=$(curl -s https://api.github.com/repos/XTLS/Xray-core/releases/latest | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')
if [[ -z "$XRAY_VERSION" ]]; then
    XRAY_VERSION="v1.8.24"
fi

echo -e "${YELLOW}正在下载 XRay-core ${XRAY_VERSION} (linux-${XRAY_ARCH})${PLAIN}"
wget --no-check-certificate \
    "https://github.com/XTLS/Xray-core/releases/download/${XRAY_VERSION}/Xray-linux-${XRAY_ARCH}.zip" \
    -O /tmp/xray.zip

unzip -o /tmp/xray.zip -d /usr/local/bin/ xray geosite.dat geoip.dat 2>/dev/null
chmod +x /usr/local/bin/xray
rm -f /tmp/xray.zip
echo -e "${GREEN}✓${PLAIN} XRay-core 安装完成"

# 步骤4: 初始化配置
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${PLAIN}"
echo -e "${BOLD}${CYAN}[4/8] 初始化配置${PLAIN}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${PLAIN}"

mkdir -p ${CONFIG_DIR}
mkdir -p ${WEB_DIR}/templates
mkdir -p /var/log/xray

# 生成管理员密码
ADMIN_PASS=$(openssl rand -base64 16 | tr -d '=+/' | cut -c1-16)
SERVER_IP=$(curl -s4 ip.sb 2>/dev/null || curl -s4 ifconfig.me 2>/dev/null || curl -s4 icanhazip.com 2>/dev/null || echo "your-server-ip")

# 创建默认用户
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
echo -e "${BLUE}═══════════════════════════════════════════════════════════${PLAIN}"
echo -e "${BOLD}${CYAN}[5/8] 部署程序文件${PLAIN}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${PLAIN}"

# 获取脚本目录
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# 复制核心管理器
if [[ -f "${SCRIPT_DIR}/proxy_manager.py" ]]; then
    cp ${SCRIPT_DIR}/proxy_manager.py ${CONFIG_DIR}/
else
    echo -e "${YELLOW}⚠ 警告: proxy_manager.py 不存在，将创建基础版本${PLAIN}"
    # 创建基础版本的proxy_manager.py
    cat > ${CONFIG_DIR}/proxy_manager.py << 'PYEOF'
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import json, os, hashlib, base64, uuid
from datetime import datetime

CONFIG_FILE = "/etc/proxy-manager/config.json"
USERS_FILE = "/etc/proxy-manager/users.json"
STATS_FILE = "/etc/proxy-manager/stats.json"

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
                self.port = data.get('port', 500)
                self.domain = data.get('domain', 'localhost')
        else:
            self.users = []
            self.admin_password = ''
            self.port = 500
            self.domain = 'localhost'

    def save_data(self):
        data = {'users': self.users, 'admin_password': self.admin_password, 'port': self.port, 'domain': self.domain}
        with open(USERS_FILE, 'w') as f:
            json.dump(data, f, indent=2)

    def add_user(self, username, user_uuid, password, traffic_limit=0):
        if any(u['username'] == username for u in self.users):
            return False, "用户已存在"
        user = {'username': username, 'uuid': user_uuid, 'password': password, 'traffic_limit': traffic_limit, 'traffic_used': 0, 'enabled': True, 'created_at': datetime.now().isoformat(), 'last_active': None}
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

        # 安全检查：如果没有启用用户，不开放任何端口
        if not enabled_users:
            config = {
                "log": {"access": "/var/log/xray/access.log", "error": "/var/log/xray/error.log", "loglevel": "warning"},
                "inbounds": [],
                "outbounds": [{"protocol": "freedom", "settings": {}}]
            }
            with open(CONFIG_FILE, 'w') as f:
                json.dump(config, f, indent=2)
            return

        # VLESS clients - UUID认证
        vless_clients = [{'id': u['uuid'], 'flow': '', 'email': f"{u['username']}@proxy-manager"} for u in enabled_users]

        # Trojan clients - 密码认证
        trojan_clients = [{'password': u['password'], 'email': f"{u['username']}@proxy-manager"} for u in enabled_users]

        # VMess clients - UUID认证
        vmess_clients = [{'id': u['uuid'], 'email': f"{u['username']}@proxy-manager"} for u in enabled_users]

        # Shadowsocks clients - 密码认证
        ss_clients = [{'email': f"{u['username']}@proxy-manager", 'method': 'aes-256-gcm', 'password': u['password']} for u in enabled_users]

        config = {
            "log": {"access": "/var/log/xray/access.log", "error": "/var/log/xray/error.log", "loglevel": "info"},
            "inbounds": [
                {
                    "port": 500,
                    "protocol": "vless",
                    "settings": {
                        "clients": vless_clients,
                        "decryption": "none",
                        "fallbacks": []
                    },
                    "streamSettings": {
                        "network": "tcp",
                        "security": "tls",
                        "tlsSettings": {
                            "certificates": [{"certificateFile": f"{self.config_dir}/server.crt", "keyFile": f"{self.config_dir}/server.key"}],
                            "serverName": self.domain,
                            "allowInsecure": false
                        }
                    }
                },
                {
                    "port": 501,
                    "protocol": "trojan",
                    "settings": {
                        "clients": trojan_clients,
                        "fallbacks": []
                    },
                    "streamSettings": {
                        "network": "tcp",
                        "security": "tls",
                        "tlsSettings": {
                            "certificates": [{"certificateFile": f"{self.config_dir}/server.crt", "keyFile": f"{self.config_dir}/server.key"}],
                            "serverName": self.domain,
                            "allowInsecure": false
                        }
                    }
                },
                {
                    "port": 502,
                    "protocol": "vmess",
                    "settings": {
                        "clients": vmess_clients,
                        "disableInsecureEncryption": true
                    },
                    "streamSettings": {
                        "network": "tcp",
                        "security": "tls",
                        "tlsSettings": {
                            "certificates": [{"certificateFile": f"{self.config_dir}/server.crt", "keyFile": f"{self.config_dir}/server.key"}],
                            "serverName": self.domain,
                            "allowInsecure": false
                        }
                    }
                },
                {
                    "port": 503,
                    "protocol": "shadowsocks",
                    "settings": {
                        "clients": ss_clients,
                        "network": "tcp,udp"
                    }
                }
            ],
            "outbounds": [{"protocol": "freedom", "settings": {}}]
        }
        with open(CONFIG_FILE, 'w') as f:
            json.dump(config, f, indent=2)
        os.system("systemctl reload xray 2>/dev/null")

    def generate_vless_url(self, user):
        return f"vless://{user['uuid']}@{self.domain}:500?encryption=none&security=tls&type=tcp#ProxyManager_{user['username']}"

    def generate_vmess_url(self, user):
        import base64
        vmess_config = {"v": "2", "ps": f"ProxyManager_{user['username']}", "add": self.domain, "port": "502", "id": user['uuid'], "net": "tcp", "type": "none", "tls": "tls"}
        b64 = base64.b64encode(json.dumps(vmess_config, separators=(',', ':')).encode()).decode()
        return f"vmess://{b64}"

    def generate_trojan_url(self, user):
        return f"trojan://{user['password']}@{self.domain}:501?security=tls&type=tcp#ProxyManager_{user['username']}"

    def generate_ss_url(self, user):
        import base64
        method = "aes-256-gcm"
        user_info = f"{method}:{user['password']}"
        b64_info = base64.b64encode(user_info.encode()).decode()
        return f"ss://{b64_info}@{self.domain}:503#ProxyManager_{user['username']}"

    def list_users(self):
        result = []
        for user in self.users:
            status = "启用" if user['enabled'] else "禁用"
            traffic_info = f"{user['traffic_used']:.2f}/{user['traffic_limit']}GB" if user['traffic_limit'] > 0 else f"{user['traffic_used']:.2f}GB"
            result.append({'username': user['username'], 'uuid': user['uuid'], 'traffic': traffic_info, 'status': status})
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
        users = manager.list_users()
        for user in users:
            print(f"{user['username']:<15} {user['uuid']:<20} {user['traffic']:<15} {user['status']:<15}")
    elif command == 'update_config':
        manager.update_xray_config()
        print("XRay configuration updated successfully")
PYEOF
fi

chmod +x ${CONFIG_DIR}/proxy_manager.py

# 创建Web管理界面
cat > ${WEB_DIR}/proxy_web.py << 'WEBEOF'
#!/usr/bin/env python3
import sys, os, json, io, base64, uuid
sys.path.insert(0, '/etc/proxy-manager')
from flask import Flask, render_template_string, request, jsonify, session, redirect, send_file
import qrcode

app = Flask(__name__)
app.secret_key = os.urandom(24)

exec(open('/etc/proxy-manager/proxy_manager.py', encoding='utf-8').read())
manager = ProxyManager()

LOGIN_HTML = '''<!DOCTYPE html>
<html><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1.0">
<title>代理管理 - 登录</title>
<style>*{margin:0;padding:0;box-sizing:border-box}body{font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,sans-serif;background:linear-gradient(135deg,#667eea 0%,#764ba2 100%);min-height:100vh;display:flex;align-items:center;justify-content:center;padding:20px}.login-box{background:white;border-radius:20px;padding:40px;box-shadow:0 20px 60px rgba(0,0,0,0.3);max-width:400px;width:100%}h1{text-align:center;color:#333;margin-bottom:30px}.form-group{margin-bottom:20px}label{display:block;color:#666;margin-bottom:8px;font-weight:500}input{width:100%;padding:12px 15px;border:2px solid #e0e0e0;border-radius:10px;font-size:16px}input:focus{outline:none;border-color:#667eea}button{width:100%;padding:14px;background:linear-gradient(135deg,#667eea 0%,#764ba2 100%);color:white;border:none;border-radius:10px;font-size:16px;font-weight:600;cursor:pointer}.message{padding:12px;border-radius:8px;margin-bottom:20px;text-align:center}.error{background:#fee;color:#c33}.success{background:#efe;color:#3c3}</style></head>
<body><div class="login-box"><h1>🔐 代理管理登录</h1><div id="message"></div><form id="loginForm"><div class="form-group"><label>管理员密码</label><input type="password" id="password" required autofocus></div><button type="submit">登录</button></form></div>
<script>document.getElementById('loginForm').addEventListener('submit',async(e)=>{e.preventDefault();const p=document.getElementById('password').value;const res=await fetch('/login',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({password:p})});const d=await res.json();const m=document.getElementById('message');if(d.success){m.className='message success';m.textContent=d.message;setTimeout(()=>window.location.href='/',1000)}else{m.className='message error';m.textContent=d.message}});</script></body></html>'''

INDEX_HTML = '''<!DOCTYPE html>
<html><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1.0">
<title>代理管理面板</title>
<style>*{margin:0;padding:0;box-sizing:border-box}body{font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,sans-serif;background:#f5f7fa;padding:20px}.header{background:white;padding:20px 30px;border-radius:15px;margin-bottom:20px;display:flex;justify-content:space-between;align-items:center;box-shadow:0 2px 10px rgba(0,0,0,0.05)}.header h1{color:#333;font-size:24px}.btn{padding:10px 20px;border:none;border-radius:8px;cursor:pointer;font-weight:500;transition:all 0.2s}.btn-primary{background:#667eea;color:white}.btn-danger{background:#f56565;color:white}.btn:hover{transform:translateY(-2px);box-shadow:0 5px 15px rgba(0,0,0,0.2)}.container{max-width:1200px;margin:0 auto}.card{background:white;border-radius:15px;padding:25px;margin-bottom:20px;box-shadow:0 2px 10px rgba(0,0,0,0.05)}.card h2{color:#333;margin-bottom:20px;font-size:18px}.add-user-form{display:grid;grid-template-columns:2fr 1fr 1fr auto;gap:15px;align-items:end}.form-group label{display:block;color:#666;margin-bottom:5px;font-size:14px}.form-group input{width:100%;padding:10px 15px;border:1px solid #e0e0e0;border-radius:8px}table{width:100%;border-collapse:collapse}th,td{padding:15px;text-align:left;border-bottom:1px solid #f0f0f0}th{background:#f8f9fa;color:#666;font-weight:600}.status-badge{display:inline-block;padding:5px 12px;border-radius:20px;font-size:12px;font-weight:600}.status-enabled{background:#c6f6d5;color:#22543d}.status-disabled{background:#fed7d7;color:#742a2a}.config-modal{display:none;position:fixed;top:0;left:0;right:0;bottom:0;background:rgba(0,0,0,0.5);z-index:1000;align-items:center;justify-content:center}.config-modal.active{display:flex}.modal-content{background:white;border-radius:20px;padding:30px;max-width:600px;width:90%;max-height:90vh;overflow-y:auto}.config-tabs{display:flex;gap:10px;margin-bottom:20px;border-bottom:2px solid #f0f0f0}.config-tab{padding:10px 20px;background:none;border:none;cursor:pointer;color:#666;font-weight:500}.config-tab.active{color:#667eea;border-bottom:2px solid #667eea}.config-url{background:#f8f9fa;padding:15px;border-radius:8px;word-break:break-all;font-family:monospace;font-size:12px;margin-bottom:10px}.qrcode-container{text-align:center;padding:20px;background:#f8f9fa;border-radius:15px;margin:20px 0}.copy-btn{background:#667eea;color:white;border:none;padding:8px 15px;border-radius:6px;cursor:pointer;font-size:14px}</style></head>
<body><div class="container"><div class="header"><h1>🚀 代理管理面板</h1><button class="btn btn-danger" onclick="logout()">退出</button></div>
<div class="card"><h2>添加用户</h2><form class="add-user-form" id="addUserForm"><div class="form-group"><label>用户名</label><input type="text" id="username" required></div><div class="form-group"><label>流量限制(GB)</label><input type="number" id="trafficLimit" value="0" min="0"></div><div></div><button type="submit" class="btn btn-primary">添加</button></form></div>
<div class="card"><h2>用户列表</h2><table><thead><tr><th>用户名</th><th>UUID</th><th>流量</th><th>状态</th><th>操作</th></tr></thead><tbody id="userTable"></tbody></table></div></div>
<div class="config-modal" id="configModal"><div class="modal-content"><h2 id="modalTitle">用户配置</h2><div class="config-tabs"><button class="config-tab active" data-tab="vless">VLESS</button><button class="config-tab" data-tab="vmess">VMESS</button><button class="config-tab" data-tab="trojan">Trojan</button><button class="config-tab" data-tab="ss">Shadowsocks</button></div><div class="config-url" id="configUrl"></div><button class="copy-btn" onclick="copyConfig()">复制链接</button><div class="qrcode-container"><h3>扫描二维码</h3><div id="qrcode"></div></div><div style="text-align:center;margin-top:20px"><button class="btn" onclick="closeModal()">关闭</button></div></div></div>
<script src="https://cdn.jsdelivr.net/npm/qrcode@1.5.3/build/qrcode.min.js"></script>
<script>let cu=[];async function lu(){const r=await fetch('/api/users');const d=await r.json();cu=d.users;ru()}
function ru(){document.getElementById('userTable').innerHTML=cu.map(u=>`<tr><td><strong>${u.username}</strong></td><td style="font-family:monospace;font-size:12px">${u.uuid.substring(0,8)}...</td><td>${u.traffic}</td><td><span class="status-badge ${u.status==='启用'?'status-enabled':'status-disabled'}">${u.status}</span></td><td><button class="btn btn-primary" onclick="sc('${u.username}')">配置</button><button class="btn" onclick="tu('${u.username}')">切换</button><button class="btn btn-danger" onclick="du('${u.username}')">删除</button></td></tr>`).join('')}
document.getElementById('addUserForm').addEventListener('submit',async(e)=>{e.preventDefault();const u=document.getElementById('username').value;const t=document.getElementById('trafficLimit').value;const r=await fetch('/api/user/add',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({username:u,traffic_limit:parseInt(t)})});const d=await r.json();if(d.success){alert('✓ 用户添加成功!\\n\\n用户名: '+d.user.username+'\\n密码: '+d.user.password+'\\n\\n请保存此密码!');document.getElementById('addUserForm').reset();lu()}else{alert(d.message)}});
let cc={};async function sc(un){const p=prompt('请输入用户密码:');if(!p)return;const r=await fetch(`/api/user/${un}/config?password=${p}`);const d=await r.json();if(d.error){alert(d.error);return}cc=d;document.getElementById('modalTitle').textContent=`配置 - ${un}`;st('vless');document.getElementById('configModal').classList.add('active')}
function st(t){document.querySelectorAll('.config-tab').forEach(x=>x.classList.remove('active'));document.querySelector(`[data-tab="${t}"]`).classList.add('active');const urls={vless:cc.vless,vmess:cc.vmess,trojan:cc.trojan,ss:cc.ss};document.getElementById('configUrl').textContent=urls[t];QRCode.toCanvas(document.createElement('canvas'),urls[t],{width:200},(e,c)=>{document.getElementById('qrcode').innerHTML='';if(!e)document.getElementById('qrcode').appendChild(c)})}
document.querySelectorAll('.config-tab').forEach(t=>t.addEventListener('click',()=>st(t.dataset.tab)));
function copyConfig(){if(navigator.clipboard){navigator.clipboard.writeText(document.getElementById('configUrl').textContent).then(()=>alert('✓ 已复制到剪贴板')).catch(()=>fallbackCopy())}else{fallbackCopy()}}
function fallbackCopy(){const ta=document.createElement('textarea');ta.value=document.getElementById('configUrl').textContent;ta.style.position='fixed';ta.style.opacity='0';document.body.appendChild(ta);ta.select();try{document.execCommand('copy');alert('✓ 已复制到剪贴板')}catch(e){alert('✗ 复制失败')}document.body.removeChild(ta)}
function closeModal(){document.getElementById('configModal').classList.remove('active')}
async function tu(un){await fetch(`/api/user/${un}/toggle`,{method:'POST'});lu()}
async function du(un){if(!confirm('确定删除用户 '+un+' ?'))return;await fetch(`/api/user/${un}/delete`,{method:'POST'});lu()}
function logout(){if(confirm('确定退出登录?'))window.location.href='/logout'}lu();
</script></body></html>'''

@app.route('/')
def index():
    if 'logged_in' not in session: return render_template_string(LOGIN_HTML)
    return render_template_string(INDEX_HTML)

@app.route('/login', methods=['POST'])
def login():
    data = request.get_json()
    if manager.verify_admin(data.get('password')):
        session['logged_in'] = True
        return jsonify({'success': True, 'message': '登录成功'})
    return jsonify({'success': False, 'message': '密码错误'})

@app.route('/logout')
def logout():
    session.pop('logged_in', None)
    return redirect('/')

@app.route('/api/users')
def get_users():
    if 'logged_in' not in session: return jsonify({'error':'未登录'}), 401
    return jsonify({'users': manager.list_users()})

@app.route('/api/user/<username>/config')
def get_user_config(username):
    pwd = request.args.get('password')
    user = manager.get_user(username)
    if not user: return jsonify({'error':'用户不存在'}), 404
    if pwd != user['password']: return jsonify({'error':'密码错误'}), 401
    return jsonify({'username':username,'vless':manager.generate_vless_url(user),'vmess':manager.generate_vmess_url(user),'trojan':manager.generate_trojan_url(user),'ss':manager.generate_ss_url(user)})

@app.route('/api/user/add', methods=['POST'])
def add_user():
    if 'logged_in' not in session: return jsonify({'error':'未登录'}), 401
    d=request.get_json()
    u=d.get('username')
    if manager.get_user(u): return jsonify({'success':False,'message':'用户已存在'})
    uid=str(uuid.uuid4())
    pwd=base64.b64encode(os.urandom(12)).decode()[:16]
    tl=d.get('traffic_limit',0)
    s,m=manager.add_user(u,uid,pwd,tl)
    if s:return jsonify({'success':True,'message':m,'user':{'username':u,'uuid':uid,'password':pwd}})
    return jsonify({'success':False,'message':m})

@app.route('/api/user/<username>/delete', methods=['POST'])
def delete_user(username):
    if 'logged_in' not in session: return jsonify({'error':'未登录'}), 401
    s,m=manager.delete_user(username)
    return jsonify({'success':s,'message':m})

@app.route('/api/user/<username>/toggle', methods=['POST'])
def toggle_user(username):
    if 'logged_in' not in session: return jsonify({'error':'未登录'}), 401
    u=manager.get_user(username)
    if u['enabled']:manager.disable_user(username);st='disabled'
    else:manager.enable_user(username);st='enabled'
    return jsonify({'success':True,'status':st})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=${WEB_PORT}, debug=False)
WEBEOF

chmod +x ${WEB_DIR}/proxy_web.py
echo -e "${GREEN}✓${PLAIN} 程序文件部署完成"

# 步骤5.5: 生成XRay配置文件
echo ""
echo -e "${YELLOW}正在生成 XRay 配置文件...${PLAIN}"
PYTHONIOENCODING=utf-8 python3 ${CONFIG_DIR}/proxy_manager.py update_config 2>/dev/null

if [[ -f "${CONFIG_DIR}/config.json" ]]; then
    echo -e "${GREEN}✓${PLAIN} XRay配置文件生成完成"
else
    echo -e "${RED}✗${PLAIN} XRay配置文件生成失败"
    exit 1
fi

# 步骤6: 创建systemd服务
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${PLAIN}"
echo -e "${BOLD}${CYAN}[6/8] 创建系统服务${PLAIN}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${PLAIN}"

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

# Web服务
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

systemctl daemon-reload
echo -e "${GREEN}✓${PLAIN} 系统服务创建完成"

# 步骤7: 配置防火墙
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${PLAIN}"
echo -e "${BOLD}${CYAN}[7/8] 配置防火墙${PLAIN}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${PLAIN}"

if command -v firewall-cmd &>/dev/null; then
    firewall-cmd --permanent --add-port=${PROXY_PORT}/tcp 2>/dev/null
    firewall-cmd --permanent --add-port=${TROJAN_PORT}/tcp 2>/dev/null
    firewall-cmd --permanent --add-port=${VMESS_PORT}/tcp 2>/dev/null
    firewall-cmd --permanent --add-port=${SS_PORT}/tcp 2>/dev/null
    firewall-cmd --permanent --add-port=${WEB_PORT}/tcp 2>/dev/null
    firewall-cmd --reload 2>/dev/null
    echo -e "${GREEN}✓${PLAIN} firewalld 防火墙规则已添加"
elif command -v ufw &>/dev/null; then
    ufw allow ${PROXY_PORT}/tcp 2>/dev/null
    ufw allow ${TROJAN_PORT}/tcp 2>/dev/null
    ufw allow ${VMESS_PORT}/tcp 2>/dev/null
    ufw allow ${SS_PORT}/tcp 2>/dev/null
    ufw allow ${WEB_PORT}/tcp 2>/dev/null
    echo -e "${GREEN}✓${PLAIN} ufw 防火墙规则已添加"
else
    echo -e "${YELLOW}⚠${PLAIN} 未检测到防火墙，跳过配置"
fi

# 步骤8: 启动服务
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${PLAIN}"
echo -e "${BOLD}${CYAN}[8/8] 启动服务${PLAIN}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${PLAIN}"

systemctl enable xray proxy-web 2>/dev/null
systemctl restart xray
sleep 2
systemctl restart proxy-web
sleep 3

# 生成代理连接配置
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${PLAIN}"
echo -e "${BOLD}${GREEN}安装完成！${PLAIN}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${PLAIN}"
echo ""

# 检查服务状态
echo -e "${BOLD}${CYAN}服务状态:${PLAIN}"
if systemctl is-active --quiet xray; then
    echo -e "   XRay服务:      ${GREEN}✓ 运行中${PLAIN}"
else
    echo -e "   XRay服务:      ${RED}✗ 未运行${PLAIN}"
fi

if systemctl is-active --quiet proxy-web; then
    echo -e "   Web管理界面:   ${GREEN}✓ 运行中${PLAIN}"
else
    echo -e "   Web管理界面:   ${RED}✗ 未运行${PLAIN}"
fi

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
echo -e ""
echo -e "${CYAN}代理端口配置:${PLAIN}"
echo -e "   VLESS端口:    ${GREEN}${PROXY_PORT}${PLAIN} (TLS加密)"
echo -e "   Trojan端口:   ${GREEN}${TROJAN_PORT}${PLAIN} (TLS加密)"
echo -e "   VMess端口:    ${GREEN}${VMESS_PORT}${PLAIN} (TLS加密)"
echo -e "   SS端口:       ${GREEN}${SS_PORT}${PLAIN} (无加密)"
echo ""
echo -e "${CYAN}Web管理面板:${PLAIN}"
echo -e "   管理地址:     ${GREEN}http://${SERVER_IP}:${WEB_PORT}${PLAIN}"
echo ""
echo -e "${CYAN}默认用户信息:${PLAIN}"
echo -e "   用户名:       ${GREEN}${USER_NAME}${PLAIN}"
echo -e "   用户密码:     ${GREEN}${USER_PASS}${PLAIN}"
echo -e "   流量限制:     ${GREEN}无限${PLAIN}"
echo ""

# 生成代理连接URL
VLESS_URL="vless://${USER_UUID}@${SERVER_IP}:${PROXY_PORT}?encryption=none&security=tls&type=tcp#ProxyManager_${USER_NAME}"
TROJAN_URL="trojan://${USER_PASS}@${SERVER_IP}:${TROJAN_PORT}?security=tls&type=tcp#ProxyManager_${USER_NAME}"

# 生成VMess URL (需要base64编码)
VMESS_CONFIG="{\"v\":\"2\",\"ps\":\"ProxyManager_${USER_NAME}\",\"add\":\"${SERVER_IP}\",\"port\":\"${VMESS_PORT}\",\"id\":\"${USER_UUID}\",\"net\":\"tcp\",\"type\":\"none\",\"tls\":\"tls\"}"
VMESS_URL="vmess://$(echo -n "${VMESS_CONFIG}" | base64 -w 0)"

# 生成Shadowsocks URL
SS_METHOD="aes-256-gcm"
SS_INFO="${SS_METHOD}:${USER_PASS}"
SS_URL="ss://$(echo -n "${SS_INFO}" | base64 -w 0)@${SERVER_IP}:${SS_PORT}#ProxyManager_${USER_NAME}"

# 步骤4.5: 保存安装信息到文件 (在配置生成之前保存，确保不会丢失)
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${PLAIN}"
echo -e "${BOLD}${CYAN}[4.5/8] 保存安装信息${PLAIN}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${PLAIN}"

cat > ${CONFIG_DIR}/install_info.txt << INFOEOF
╔═══════════════════════════════════════════════════════════════╗
║              Proxy Manager 安装信息 - 请妥善保存               ║
╚═══════════════════════════════════════════════════════════════╝

安装日期: $(date)
服务器IP: ${SERVER_IP}

【🔐 管理员密码】
${ADMIN_PASS}

【👤 默认用户信息】
用户名: ${USER_NAME}
UUID: ${USER_UUID}
密码: ${USER_PASS}

【🔌 端口配置】
VLESS:  ${PROXY_PORT}  (TLS加密)
Trojan: ${TROJAN_PORT}  (TLS加密)
VMess:  ${VMESS_PORT}  (TLS加密)
SS:     ${SS_PORT}  (无加密)
Web:    ${WEB_PORT}

【📱 快速连接链接】
VLESS: ${VLESS_URL}
Trojan: ${TROJAN_URL}
VMess: ${VMESS_URL}
SS: ${SS_URL}

【🌐 管理面板】
http://${SERVER_IP}:${WEB_PORT}

【📝 查看用户】
PYTHONIOENCODING=utf-8 python3 ${CONFIG_DIR}/proxy_manager.py list
INFOEOF

chmod 644 ${CONFIG_DIR}/install_info.txt
echo -e "${GREEN}✓${PLAIN} 安装信息已保存到: ${YELLOW}${CONFIG_DIR}/install_info.txt${PLAIN}"

echo ""
echo -e "${YELLOW}═══════════════════════════════════════════════════════════${PLAIN}"
echo -e "${YELLOW}  正在生成连接二维码...${PLAIN}"
echo -e "${YELLOW}═══════════════════════════════════════════════════════════${PLAIN}"
echo ""

# 显示VLESS二维码
if command -v qrencode &>/dev/null; then
    echo -e "${CYAN}VLESS 二维码:${PLAIN}"
    qrencode -t ANSIUTF8 "${VLESS_URL}"
    echo ""
fi

# 显示Trojan二维码
if command -v qrencode &>/dev/null; then
    echo -e "${CYAN}Trojan 二维码:${PLAIN}"
    qrencode -t ANSIUTF8 "${TROJAN_URL}"
    echo ""
fi

# 显示Shadowsocks二维码
if command -v qrencode &>/dev/null; then
    echo -e "${CYAN}Shadowsocks 二维码:${PLAIN}"
    qrencode -t ANSIUTF8 "${SS_URL}"
    echo ""
fi

echo -e "${CYAN}快速连接 (VLESS):${PLAIN}"
echo -e "${VLESS_URL}"
echo ""
echo -e "${CYAN}快速连接 (Trojan):${PLAIN}"
echo -e "${TROJAN_URL}"
echo ""
echo -e "${CYAN}快速连接 (VMess):${PLAIN}"
echo -e "${VMESS_URL}"
echo ""
echo -e "${CYAN}快速连接 (Shadowsocks):${PLAIN}"
echo -e "${SS_URL}"
echo ""

# 生成二维码
echo -e "${CYAN}生成二维码...${PLAIN}"
if command -v qrencode &>/dev/null; then
    echo ""
    echo -e "${YELLOW}VLESS 二维码 (端口 ${PROXY_PORT}):${PLAIN}"
    qrencode -t ANSIUTF8 "${VLESS_URL}"
    echo ""
    echo -e "${YELLOW}Trojan 二维码 (端口 ${TROJAN_PORT}):${PLAIN}"
    qrencode -t ANSIUTF8 "${TROJAN_URL}"
    echo ""
    echo -e "${YELLOW}Shadowsocks 二维码 (端口 ${SS_PORT}):${PLAIN}"
    qrencode -t ANSIUTF8 "${SS_URL}"
    echo ""
    echo -e "${YELLOW}注意: VMess链接过长，无法显示二维码${PLAIN}"
    echo -e "${YELLOW}请复制上方VMess链接到客户端导入${PLAIN}"
    echo ""
fi

echo -e "${MAGENTA}╔═══════════════════════════════════════════════════════════════╗${PLAIN}"
echo -e "${MAGENTA}║${PLAIN}                    ${BOLD}使用说明${PLAIN}                    ${MAGENTA}║${PLAIN}"
echo -e "${MAGENTA}╚═══════════════════════════════════════════════════════════════╝${PLAIN}"
echo ""
echo -e "${CYAN}1. Web管理:${PLAIN}"
echo -e "   访问管理面板: ${GREEN}http://${SERVER_IP}:${WEB_PORT}${PLAIN}"
echo -e "   使用管理员密码登录"
echo -e "   可以添加/删除用户，查看流量统计"
echo ""
echo -e "${CYAN}2. 客户端配置:${PLAIN}"
echo -e "   支持的客户端:"
echo -e "   - Shadowrocket (iOS/macOS)"
echo -e "   - V2RayN/V2RayNG (Windows/Android)"
echo -e "   - Quantumult X (iOS)"
echo -e "   - Clash (全平台)"
echo -e "   - 其他支持VLESS/VMESS/Trojan/SS的客户端"
echo ""
echo -e "${CYAN}3. 常用命令:${PLAIN}"
echo -e "   查看用户列表:   ${YELLOW}PYTHONIOENCODING=utf-8 python3 ${CONFIG_DIR}/proxy_manager.py list${PLAIN}"
echo -e "   重启服务:       ${YELLOW}systemctl restart xray proxy-web${PLAIN}"
echo -e "   查看XRay日志:   ${YELLOW}tail -f /var/log/xray/access.log${PLAIN}"
echo -e "   查看Web日志:    ${YELLOW}journalctl -u proxy-web -f${PLAIN}"
echo ""
echo -e "${CYAN}4. 卸载脚本:${PLAIN}"
echo -e "   ${YELLOW}bash ${SCRIPT_DIR}/uninstall.sh${PLAIN}"
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
VLESS:  ${PROXY_PORT}  (TLS加密)
Trojan: ${TROJAN_PORT}  (TLS加密)
VMess:  ${VMESS_PORT}  (TLS加密)
SS:     ${SS_PORT}  (无加密)
Web:    ${WEB_PORT}  (管理界面)

========================================
【📱 快速连接链接】
========================================

1️⃣ VLESS (推荐):
${VLESS_URL}

2️⃣ Trojan:
${TROJAN_URL}

3️⃣ VMess:
${VMESS_URL}

4️⃣ Shadowsocks:
${SS_URL}

========================================
【🌐 访问地址】
========================================
Web管理面板: http://${SERVER_IP}:${WEB_PORT}

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

或查看安装时的终端输出

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

开机自启:
  systemctl enable xray proxy-web

========================================
【📊 用户管理】
========================================
查看用户列表:
  PYTHONIOENCODING=utf-8 python3 ${CONFIG_DIR}/proxy_manager.py list

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

Web服务日志:
  journalctl -u proxy-web -f

========================================
【🔧 配置文件位置】
========================================
配置目录: ${CONFIG_DIR}
  - config.json      XRay配置
  - users.json       用户数据库
  - stats.json       流量统计
  - server.crt       TLS证书
  - server.key       TLS私钥

Web目录: ${WEB_DIR}
  - proxy_web.py     Web服务

========================================
【🗑️ 卸载】
========================================
如需卸载，请运行:
  bash ${SCRIPT_DIR}/uninstall.sh

========================================
【📱 客户端支持】
========================================
支持的客户端:
  - Shadowrocket (iOS/macOS)
  - V2RayN/V2RayNG (Windows/Android)
  - Quantumult X (iOS)
  - Clash (全平台)
  - 其他支持VLESS/VMESS/Trojan/SS的客户端

========================================
安装完成！请妥善保存此文件！
========================================
INFOEOF

echo -e "${GREEN}✓${PLAIN} 安装信息已保存到: ${YELLOW}${CONFIG_DIR}/install_info.txt${PLAIN}"
echo ""
echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${PLAIN}"
echo -e "${GREEN}${BOLD}              安装成功！请保存好上述信息！${PLAIN}"
echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${PLAIN}"
echo ""
