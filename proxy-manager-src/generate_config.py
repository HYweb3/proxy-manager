#!/usr/bin/env python3
import json

# 读取现有用户配置
with open('/etc/proxy-manager/users.json', 'r') as f:
    users_data = json.load(f)

# 端口配置 - 与quick_install.sh保持一致
PROXY_PORT = 500     # VLESS
TROJAN_PORT = 501    # Trojan
VMESS_PORT = 502     # VMess
SS_PORT = 503        # Shadowsocks

enabled_users = [u for u in users_data.get('users', []) if u.get('enabled', True)]

# 构建客户端配置
vless_clients = []
trojan_clients = []
vmess_clients = []
ss_clients = []

for user in enabled_users:
    vless_clients.append({
        'id': user['uuid'],
        'flow': '',
        'email': f"{user['username']}@proxy-manager"
    })
    trojan_clients.append({
        'password': user['password'],
        'email': f"{user['username']}@proxy-manager"
    })
    vmess_clients.append({
        'id': user['uuid'],
        'email': f"{user['username']}@proxy-manager"
    })
    ss_clients.append({
        'email': f"{user['username']}@proxy-manager",
        'method': 'aes-256-gcm',
        'password': user['password']
    })

# 构建XRay配置
config = {
    "log": {
        "access": "/var/log/xray/access.log",
        "error": "/var/log/xray/error.log",
        "loglevel": "warning"
    },
    "inbounds": [
        # VLESS on port 500
        {
            "port": PROXY_PORT,
            "protocol": "vless",
            "settings": {
                "clients": vless_clients,
                "decryption": "none"
            },
            "streamSettings": {
                "network": "tcp",
                "security": "tls",
                "tlsSettings": {
                    "certificates": [
                        {
                            "certificateFile": "/etc/proxy-manager/server.crt",
                            "keyFile": "/etc/proxy-manager/server.key"
                        }
                    ]
                }
            }
        },
        # Trojan on port 501
        {
            "port": TROJAN_PORT,
            "protocol": "trojan",
            "settings": {
                "clients": trojan_clients
            },
            "streamSettings": {
                "network": "tcp",
                "security": "tls",
                "tlsSettings": {
                    "certificates": [
                        {
                            "certificateFile": "/etc/proxy-manager/server.crt",
                            "keyFile": "/etc/proxy-manager/server.key"
                        }
                    ]
                }
            }
        },
        # VMess on port 502
        {
            "port": VMESS_PORT,
            "protocol": "vmess",
            "settings": {
                "clients": vmess_clients
            },
            "streamSettings": {
                "network": "tcp",
                "security": "tls",
                "tlsSettings": {
                    "certificates": [
                        {
                            "certificateFile": "/etc/proxy-manager/server.crt",
                            "keyFile": "/etc/proxy-manager/server.key"
                        }
                    ]
                }
            }
        },
        # Shadowsocks on port 503
        {
            "port": SS_PORT,
            "protocol": "shadowsocks",
            "settings": {
                "clients": ss_clients,
                "network": "tcp,udp"
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

# 写入配置文件
with open('/etc/proxy-manager/config.json', 'w') as f:
    json.dump(config, f, indent=2)

print(f"XRay config generated successfully!")
print(f"VLESS Port: {PROXY_PORT}")
print(f"Trojan Port: {TROJAN_PORT}")
print(f"VMess Port: {VMESS_PORT}")
print(f"Shadowsocks Port: {SS_PORT}")
print(f"Users: {len(enabled_users)}")
