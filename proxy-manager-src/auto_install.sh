#!/bin/bash

#############################################
# Proxy Manager 自动安装脚本
#############################################

RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[36m"
PLAIN="\033[0m"

# 配置路径
CONFIG_DIR="/etc/proxy-manager"
WEB_DIR="/var/www/proxy-manager"

echo -e "${BLUE}========================================${PLAIN}"
echo -e "${BLUE}  Proxy Manager 自动安装${PLAIN}"
echo -e "${BLUE}========================================${PLAIN}"
echo ""

# 检查root权限
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}错误: 必须使用root用户运行${PLAIN}"
    echo "请使用: sudo bash $0"
    exit 1
fi

# 步骤1: 安装依赖
echo -e "${BLUE}[1/6] 安装依赖包...${PLAIN}"
if command -v dnf &> /dev/null; then
    dnf install -y curl wget unzip python3 python3-pip nginx qrencode openssl 2>/dev/null || \
    yum install -y curl wget unzip python3 python3-pip nginx qrencode openssl
elif command -v apt-get &> /dev/null; then
    apt-get update
    apt-get install -y curl wget unzip python3 python3-pip nginx qrencode openssl
else
    echo -e "${RED}不支持的系统${PLAIN}"
    exit 1
fi
echo -e "${GREEN}✓ 依赖安装完成${PLAIN}"

# 步骤2: 安装Python包
echo -e "${BLUE}[2/6] 安装Python依赖...${PLAIN}"
pip3 install flask qrcode pillow pyyaml cryptography 2>/dev/null || \
pip3 install flask qrcode pillow pyyaml cryptography --break-system-packages 2>/dev/null
echo -e "${GREEN}✓ Python依赖安装完成${PLAIN}"

# 步骤3: 安装XRay-core
echo -e "${BLUE}[3/6] 安装 XRay-core...${PLAIN}"
XRAY_VERSION=$(curl -s https://api.github.com/repos/XTLS/Xray-core/releases/latest | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')

if [[ -z "$XRAY_VERSION" ]]; then
    XRAY_VERSION="v1.8.24"
fi

echo -e "${YELLOW}下载 XRay-core ${XRAY_VERSION}${PLAIN}"
wget -N --no-check-certificate "https://github.com/XTLS/Xray-core/releases/download/${XRAY_VERSION}/Xray-linux-64.zip" -O /tmp/xray.zip

unzip -o /tmp/xray.zip -d /tmp/xray_temp
cp /tmp/xray_temp/xray /usr/local/bin/
cp /tmp/xray_temp/geosite.dat /usr/local/bin/
cp /tmp/xray_temp/geoip.dat /usr/local/bin/
chmod +x /usr/local/bin/xray
rm -rf /tmp/xray.zip /tmp/xray_temp
echo -e "${GREEN}✓ XRay-core 安装完成${PLAIN}"

# 步骤4: 创建配置目录和文件
echo -e "${BLUE}[4/6] 初始化配置...${PLAIN}"
mkdir -p ${CONFIG_DIR}
mkdir -p ${WEB_DIR}/templates
mkdir -p /var/log/xray

# 生成管理员密码
ADMIN_PASS=$(openssl rand -base64 16 | tr -d '=+/' | cut -c1-16)
MAIN_UUID=$(cat /proc/sys/kernel/random/uuid)

# 获取服务器IP
SERVER_IP=$(curl -s4 ip.sb 2>/dev/null || curl -s4 ifconfig.me 2>/dev/null || echo "your-server-ip")

# 创建用户数据库
cat > ${CONFIG_DIR}/users.json << EOF
{
    "users": [],
    "admin_password": "${ADMIN_PASS}",
    "port": 500,
    "domain": "${SERVER_IP}"
}
EOF

# 创建XRay配置
cat > ${CONFIG_DIR}/config.json << EOF
{
    "log": {
        "access": "/var/log/xray/access.log",
        "error": "/var/log/xray/error.log",
        "loglevel": "warning"
    },
    "inbounds": [
        {
            "port": 500,
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

# 生成自签名证书
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout ${CONFIG_DIR}/server.key \
    -out ${CONFIG_DIR}/server.crt \
    -subj "/CN=${SERVER_IP}" 2>/dev/null

chmod 600 ${CONFIG_DIR}/server.key

echo -e "${GREEN}✓ 配置初始化完成${PLAIN}"

# 步骤5: 部署程序文件
echo -e "${BLUE}[5/6] 部署程序文件...${PLAIN}"

# 生成proxy_manager.py
if [[ -f "${SCRIPT_DIR}/proxy_manager.py" ]]; then
    cp ${SCRIPT_DIR}/proxy_manager.py ${CONFIG_DIR}/
else
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

        if not enabled_users:
            config = {
                "log": {"access": "/var/log/xray/access.log", "error": "/var/log/xray/error.log", "loglevel": "warning"},
                "inbounds": [],
                "outbounds": [{"protocol": "freedom", "settings": {}}]
            }
            with open(CONFIG_FILE, 'w') as f:
                json.dump(config, f, indent=2)
            return

        vless_clients = [{'id': u['uuid'], 'flow': '', 'email': f"{u['username']}@proxy-manager"} for u in enabled_users]

        config = {
            "log": {"access": "/var/log/xray/access.log", "error": "/var/log/xray/error.log", "loglevel": "info"},
            "inbounds": [
                {
                    "port": 443,
                    "protocol": "vless",
                    "settings": {
                        "clients": vless_clients,
                        "decryption": "none"
                    },
                    "streamSettings": {
                        "network": "tcp",
                        "security": "tls",
                        "tlsSettings": {
                            "certificates": [{"certificateFile": f"{self.config_dir}/server.crt", "keyFile": f"{self.config_dir}/server.key"}],
                            "serverName": self.domain,
                            "allowInsecure": False
                        }
                    }
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
        vmess_config = {"v": "2", "ps": f"ProxyManager_{user['username']}", "add": self.domain, "port": "443", "id": user['uuid'], "net": "tcp", "type": "none", "tls": "tls"}
        b64 = base64.b64encode(json.dumps(vmess_config, separators=(',', ':')).encode()).decode()
        return f"vmess://{b64}"

    def generate_trojan_url(self, user):
        return f"trojan://{user['password']}@{self.domain}:443?security=tls&type=tcp#ProxyManager_{user['username']}"

    def list_users(self):
        result = []
        for user in self.users:
            status = "启用" if user['enabled'] else "禁用"
            traffic_info = f"{user['traffic_used']:.2f}GB"
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

# 复制并修复Web脚本
cat > ${WEB_DIR}/proxy_web.py << 'WEBSCRIPT'
#!/usr/bin/env python3
import sys
import os
import json
import io
import base64

sys.path.insert(0, '/etc/proxy-manager')
sys.path.insert(0, '/home/hnbwww/proxy-manager')

from flask import Flask, render_template_string, request, jsonify, session, redirect, send_file
import qrcode

app = Flask(__name__)
app.secret_key = os.urandom(24)

exec(open('/etc/proxy-manager/proxy_manager.py', encoding='utf-8').read())

manager = ProxyManager()

LOGIN_HTML = '''<!DOCTYPE html>
<html>
<head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1.0">
<title>代理管理 - 登录</title>
<style>
*{margin:0;padding:0;box-sizing:border-box}body{font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,sans-serif;background:linear-gradient(135deg,#667eea 0%,#764ba2 100%);min-height:100vh;display:flex;align-items:center;justify-content:center;padding:20px}.login-box{background:white;border-radius:20px;padding:40px;box-shadow:0 20px 60px rgba(0,0,0,0.3);max-width:400px;width:100%}h1{text-align:center;color:#333;margin-bottom:30px}.form-group{margin-bottom:20px}label{display:block;color:#666;margin-bottom:8px;font-weight:500}input{width:100%;padding:12px 15px;border:2px solid #e0e0e0;border-radius:10px;font-size:16px}input:focus{outline:none;border-color:#667eea}button{width:100%;padding:14px;background:linear-gradient(135deg,#667eea 0%,#764ba2 100%);color:white;border:none;border-radius:10px;font-size:16px;font-weight:600;cursor:pointer}.message{padding:12px;border-radius:8px;margin-bottom:20px;text-align:center}.error{background:#fee;color:#c33}.success{background:#efe;color:#3c3}
</style></head>
<body>
<div class="login-box"><h1>🔐 代理管理登录</h1>
<div id="message"></div>
<form id="loginForm">
<div class="form-group"><label>管理员密码</label><input type="password" id="password" required autofocus></div>
<button type="submit">登录</button>
</form></div>
<script>
document.getElementById('loginForm').addEventListener('submit',async(e)=>{
e.preventDefault();const p=document.getElementById('password').value;
const res=await fetch('/login',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({password:p})});
const d=await res.json();
const m=document.getElementById('message');
if(d.success){m.className='message success';m.textContent=d.message;setTimeout(()=>window.location.href='/',1000)}else{m.className='message error';m.textContent=d.message}
});
</script></body></html>'''

INDEX_HTML = '''<!DOCTYPE html>
<html>
<head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1.0">
<title>代理管理面板</title>
<style>
*{margin:0;padding:0;box-sizing:border-box}body{font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,sans-serif;background:#f5f7fa;padding:20px}.header{background:white;padding:20px 30px;border-radius:15px;margin-bottom:20px;display:flex;justify-content:space-between;align-items:center;box-shadow:0 2px 10px rgba(0,0,0,0.05)}.header h1{color:#333;font-size:24px}.btn{padding:10px 20px;border:none;border-radius:8px;cursor:pointer;font-weight:500}.btn-primary{background:#667eea;color:white}.btn-danger{background:#f56565;color:white}.container{max-width:1200px;margin:0 auto}.card{background:white;border-radius:15px;padding:25px;margin-bottom:20px;box-shadow:0 2px 10px rgba(0,0,0,0.05)}.card h2{color:#333;margin-bottom:20px;font-size:18px}.add-user-form{display:grid;grid-template-columns:2fr 1fr 1fr auto;gap:15px;align-items:end}.form-group label{display:block;color:#666;margin-bottom:5px;font-size:14px}.form-group input{width:100%;padding:10px 15px;border:1px solid #e0e0e0;border-radius:8px}table{width:100%;border-collapse:collapse}th,td{padding:15px;text-align:left;border-bottom:1px solid #f0f0f0}th{background:#f8f9fa;color:#666;font-weight:600}.status-badge{display:inline-block;padding:5px 12px;border-radius:20px;font-size:12px;font-weight:600}.status-enabled{background:#c6f6d5;color:#22543d}.status-disabled{background:#fed7d7;color:#742a2a}.config-modal{display:none;position:fixed;top:0;left:0;right:0;bottom:0;background:rgba(0,0,0,0.5);z-index:1000;align-items:center;justify-content:center}.config-modal.active{display:flex}.modal-content{background:white;border-radius:20px;padding:30px;max-width:600px;width:90%;max-height:90vh;overflow-y:auto}.config-tabs{display:flex;gap:10px;margin-bottom:20px;border-bottom:2px solid #f0f0f0}.config-tab{padding:10px 20px;background:none;border:none;cursor:pointer;color:#666;font-weight:500}.config-tab.active{color:#667eea;border-bottom:2px solid #667eea}.config-url{background:#f8f9fa;padding:15px;border-radius:8px;word-break:break-all;font-family:monospace;font-size:12px;margin-bottom:10px}.qrcode-container{text-align:center;padding:20px;background:#f8f9fa;border-radius:15px;margin:20px 0}.copy-btn{background:#667eea;color:white;border:none;padding:8px 15px;border-radius:6px;cursor:pointer;font-size:14px}
</style></head>
<body>
<div class="container">
<div class="header"><h1>🚀 代理管理面板</h1><button class="btn btn-danger" onclick="logout()">退出</button></div>
<div class="card">
<h2>添加用户</h2>
<form class="add-user-form" id="addUserForm">
<div class="form-group"><label>用户名</label><input type="text" id="username" required></div>
<div class="form-group"><label>流量限制(GB)</label><input type="number" id="trafficLimit" value="0" min="0"></div>
<div></div><button type="submit" class="btn btn-primary">添加</button>
</form></div>
<div class="card">
<h2>用户列表</h2>
<table><thead><tr><th>用户名</th><th>UUID</th><th>流量</th><th>状态</th><th>操作</th></tr></thead>
<tbody id="userTable"></tbody></table></div></div>
<div class="config-modal" id="configModal">
<div class="modal-content">
<h2 id="modalTitle">用户配置</h2>
<div class="config-tabs"><button class="config-tab active" data-tab="vless">VLESS</button><button class="config-tab" data-tab="vmess">VMESS</button><button class="config-tab" data-tab="trojan">Trojan</button></div>
<div class="config-url" id="configUrl"></div><button class="copy-btn" onclick="copyConfig()">复制链接</button>
<div class="qrcode-container"><h3>扫描二维码</h3><div id="qrcode"></div></div>
<div style="text-align:center;margin-top:20px"><button class="btn" onclick="closeModal()">关闭</button></div></div></div>
<script src="https://cdn.jsdelivr.net/npm/qrcode@1.5.3/build/qrcode.min.js"></script>
<script>
let cu=[];async function lu(){const r=await fetch('/api/users');const d=await r.json();cu=d.users;ru()}
function ru(){document.getElementById('userTable').innerHTML=cu.map(u=>`<tr><td><strong>${u.username}</strong></td><td style="font-family:monospace;font-size:12px">${u.uuid.substring(0,8)}...</td><td>${u.traffic}</td><td><span class="status-badge ${u.status==='启用'?'status-enabled':'status-disabled'}">${u.status}</span></td><td><button class="btn btn-primary" onclick="sc('${u.username}')">配置</button><button class="btn" onclick="tu('${u.username}')">切换</button><button class="btn btn-danger" onclick="du('${u.username}')">删除</button></td></tr>`).join('')}
document.getElementById('addUserForm').addEventListener('submit',async(e)=>{
e.preventDefault();const u=document.getElementById('username').value;const t=document.getElementById('trafficLimit').value;
const r=await fetch('/api/user/add',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({username:u,traffic_limit:parseInt(t)})});
const d=await r.json();
if(d.success){alert('用户添加成功!\\n\\n用户名: '+d.user.username+'\\n密码: '+d.user.password+'\\n\\n请保存此密码!');document.getElementById('addUserForm').reset();lu()}else{alert(d.message)}});
let cc={};async function sc(un){const p=prompt('请输入用户密码:');if(!p)return;const r=await fetch(`/api/user/${un}/config?password=${p}`);const d=await r.json();if(d.error){alert(d.error);return}cc=d;document.getElementById('modalTitle').textContent=`配置 - ${un}`;st('vless');document.getElementById('configModal').classList.add('active')}
function st(t){document.querySelectorAll('.config-tab').forEach(x=>x.classList.remove('active'));document.querySelector(`[data-tab="${t}"]`).classList.add('active');const urls={vless:cc.vless,vmess:cc.vmess,trojan:cc.trojan};document.getElementById('configUrl').textContent=urls[t];QRCode.toCanvas(document.createElement('canvas'),urls[t],{width:200},(e,c)=>{document.getElementById('qrcode').innerHTML='';if(!e)document.getElementById('qrcode').appendChild(c)})}
document.querySelectorAll('.config-tab').forEach(t=>t.addEventListener('click',()=>st(t.dataset.tab)));
function copyConfig(){navigator.clipboard.writeText(document.getElementById('configUrl').textContent);alert('已复制')}
function closeModal(){document.getElementById('configModal').classList.remove('active')}
async function tu(un){await fetch(`/api/user/${un}/toggle`,{method:'POST'});lu()}
async function du(un){if(!confirm('确定删除?'))return;await fetch(`/api/user/${un}/delete`,{method:'POST'});lu()}
function logout(){if(confirm('确定退出?'))window.location.href='/logout'}lu();
</script></body></html>'''

@app.route('/')
def index():
    if 'logged_in' not in session:
        return render_template_string(LOGIN_HTML)
    return render_template_string(INDEX_HTML, domain=manager.domain)

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
    return jsonify({'username':username,'vless':manager.generate_vless_url(user),'vmess':manager.generate_vmess_url(user),'trojan':manager.generate_trojan_url(user)})

@app.route('/api/user/add', methods=['POST'])
def add_user():
    if 'logged_in' not in session: return jsonify({'error':'未登录'}), 401
    import uuid
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
    print("🚀 Web界面启动: http://0.0.0.0:8080")
    app.run(host='0.0.0.0', port=8080, debug=False)
WEBSCRIPT

chmod +x ${WEB_DIR}/proxy_web.py
echo -e "${GREEN}✓ 程序文件部署完成${PLAIN}"

# 步骤6: 创建systemd服务
echo -e "${BLUE}[6/6] 创建系统服务...${PLAIN}"

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
echo -e "${GREEN}✓ 系统服务创建完成${PLAIN}"

# 启动服务
echo ""
echo -e "${BLUE}========================================${PLAIN}"
echo -e "${BLUE}  启动服务${PLAIN}"
echo -e "${BLUE}========================================${PLAIN}"

systemctl enable xray 2>/dev/null
systemctl enable proxy-web 2>/dev/null
systemctl start xray
sleep 2
systemctl start proxy-web

# 等待服务启动
sleep 3

# 检查服务状态
echo ""
echo -e "${BLUE}========================================${PLAIN}"
echo -e "${BLUE}  安装完成！${PLAIN}"
echo -e "${BLUE}========================================${PLAIN}"
echo ""
echo -e "${GREEN}✓ 服务状态:${PLAIN}"
if systemctl is-active --quiet xray; then
    echo -e "   XRay:       ${GREEN}运行中${PLAIN}"
else
    echo -e "   XRay:       ${RED}未运行${PLAIN}"
fi

if systemctl is-active --quiet proxy-web; then
    echo -e "   Web界面:    ${GREEN}运行中${PLAIN}"
else
    echo -e "   Web界面:    ${RED}未运行${PLAIN}"
fi

echo ""
echo -e "${YELLOW}========================================${PLAIN}"
echo -e "${YELLOW}  重要信息${PLAIN}"
echo -e "${YELLOW}========================================${PLAIN}"
echo ""
echo -e "${RED}★★★ 管理员密码: ${ADMIN_PASS} ★★★${PLAIN}"
echo -e "${RED}请立即保存此密码！${PLAIN}"
echo ""
echo -e "${GREEN}服务器IP: ${SERVER_IP}${PLAIN}"
echo -e "${GREEN}代理端口: 443${PLAIN}"
echo -e "${GREEN}管理面板: http://${SERVER_IP}:8080${PLAIN}"
echo ""
echo -e "${BLUE}使用说明:${PLAIN}"
echo -e "1. 访问管理面板并使用管理员密码登录"
echo -e "2. 添加用户（每个用户会自动生成密码）"
echo -e "3. 用户可通过以下方式获取配置:"
echo -e "   - 扫描二维码（支持V2Ray/Shadowrocket等）"
echo -e "   - 复制配置链接"
echo -e ""
echo -e "${BLUE}常用命令:${PLAIN}"
echo -e "添加用户:    ${YELLOW}cd /home/hnbwww/proxy-manager && ./install.sh${PLAIN} (选择2)"
echo -e "查看用户:    ${YELLOW}PYTHONIOENCODING=utf-8 python3 /etc/proxy-manager/proxy_manager.py list${PLAIN}"
echo -e "重启服务:    ${YELLOW}systemctl restart xray proxy-web${PLAIN}"
echo -e "查看日志:    ${YELLOW}tail -f /var/log/xray/access.log${PLAIN}"
echo ""
echo -e "${YELLOW}========================================${PLAIN}"
echo ""

# 开放防火墙端口
if command -v firewall-cmd &> /dev/null; then
    firewall-cmd --permanent --add-port=443/tcp 2>/dev/null
    firewall-cmd --permanent --add-port=8080/tcp 2>/dev/null
    firewall-cmd --reload 2>/dev/null
    echo -e "${GREEN}✓ 防火墙规则已添加${PLAIN}"
fi
