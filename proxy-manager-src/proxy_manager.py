#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Proxy Manager - 配置管理器
管理用户、流量统计、配置生成
"""

import json
import os
import hashlib
from datetime import datetime
import yaml
from pathlib import Path

CONFIG_FILE = "/etc/proxy-manager/config.json"
USERS_FILE = "/etc/proxy-manager/users.json"
STATS_FILE = "/etc/proxy-manager/stats.json"


class ProxyManager:
    def __init__(self):
        self.config_dir = Path("/etc/proxy-manager")
        self.load_data()

    def load_data(self):
        """加载配置数据"""
        if os.path.exists(USERS_FILE):
            with open(USERS_FILE, 'r', encoding='utf-8') as f:
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

        if os.path.exists(STATS_FILE):
            with open(STATS_FILE, 'r', encoding='utf-8') as f:
                self.stats = json.load(f)
        else:
            self.stats = {}

    def save_data(self):
        """保存配置数据"""
        data = {
            'users': self.users,
            'admin_password': self.admin_password,
            'port': self.port,
            'domain': self.domain
        }
        with open(USERS_FILE, 'w', encoding='utf-8') as f:
            json.dump(data, f, indent=2, ensure_ascii=False)

        with open(STATS_FILE, 'w', encoding='utf-8') as f:
            json.dump(self.stats, f, indent=2)

    def add_user(self, username, uuid, password, traffic_limit=0):
        """添加用户"""
        # 检查用户是否已存在
        if any(u['username'] == username for u in self.users):
            return False, "用户名已存在"

        user = {
            'username': username,
            'uuid': uuid,
            'password': password,
            'traffic_limit': traffic_limit,  # GB
            'traffic_used': 0,  # GB
            'enabled': True,
            'created_at': datetime.now().isoformat(),
            'last_active': None
        }

        self.users.append(user)
        self.update_xray_config()
        self.save_data()
        return True, "用户添加成功"

    def delete_user(self, username):
        """删除用户"""
        self.users = [u for u in self.users if u['username'] != username]
        self.update_xray_config()
        self.save_data()
        return True, "用户删除成功"

    def get_user(self, username):
        """获取用户信息"""
        for user in self.users:
            if user['username'] == username:
                return user
        return None

    def get_user_by_uuid(self, uuid):
        """通过UUID获取用户"""
        for user in self.users:
            if user['uuid'] == uuid:
                return user
        return None

    def enable_user(self, username):
        """启用用户"""
        user = self.get_user(username)
        if user:
            user['enabled'] = True
            self.save_data()
            return True, "用户已启用"
        return False, "用户不存在"

    def disable_user(self, username):
        """禁用用户"""
        user = self.get_user(username)
        if user:
            user['enabled'] = False
            self.save_data()
            return True, "用户已禁用"
        return False, "用户不存在"

    def update_traffic(self, username, used_gb):
        """更新用户流量"""
        user = self.get_user(username)
        if user:
            user['traffic_used'] += used_gb
            user['last_active'] = datetime.now().isoformat()
            self.save_data()

            # 检查是否超限
            if user['traffic_limit'] > 0 and user['traffic_used'] > user['traffic_limit']:
                user['enabled'] = False
                self.save_data()
                return False, "流量超限，用户已禁用"
            return True, "流量更新成功"
        return False, "用户不存在"

    def update_xray_config(self):
        """更新Xray配置文件 - 支持多协议"""
        # 端口配置 - 使用标准HTTPS端口
        VLESS_PORT = 443     # VLESS (TLS加密)
        TROJAN_PORT = 501    # Trojan (TLS加密)
        VMESS_PORT = 502     # VMess (TLS加密)
        SS_PORT = 503        # Shadowsocks (无加密)

        # 获取启用的用户
        enabled_users = [u for u in self.users if u['enabled']]

        # 构建VLESS clients配置
        vless_clients = []
        for user in enabled_users:
            vless_clients.append({
                'id': user['uuid'],
                'flow': '',
                'email': f"{user['username']}@proxy-manager"
            })

        # 构建Trojan clients配置
        trojan_clients = []
        for user in enabled_users:
            trojan_clients.append({
                'password': user['password'],
                'email': f"{user['username']}@proxy-manager"
            })

        # 构建VMess clients配置
        vmess_clients = []
        for user in enabled_users:
            vmess_clients.append({
                'id': user['uuid'],
                'email': f"{user['username']}@proxy-manager"
            })

        # 构建Shadowsocks clients配置
        ss_clients = []
        for user in enabled_users:
            ss_clients.append({
                'email': f"{user['username']}@proxy-manager",
                'method': 'aes-256-gcm',
                'password': user['password'],
                'network': 'tcp,udp'
            })

        # 更新Xray配置 - 多协议支持
        config = {
            "log": {
                "access": "/var/log/xray/access.log",
                "error": "/var/log/xray/error.log",
                "loglevel": "warning"
            },
            "inbounds": [
                # VLESS on 443 (标准HTTPS端口)
                {
                    "port": VLESS_PORT,
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
                                    "certificateFile": f"{self.config_dir}/server.crt",
                                    "keyFile": f"{self.config_dir}/server.key"
                                }
                            ]
                        }
                    }
                },
                # Trojan on 501
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
                                    "certificateFile": f"{self.config_dir}/server.crt",
                                    "keyFile": f"{self.config_dir}/server.key"
                                }
                            ]
                        }
                    }
                },
                # VMess on 502
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
                                    "certificateFile": f"{self.config_dir}/server.crt",
                                    "keyFile": f"{self.config_dir}/server.key"
                                }
                            ]
                        }
                    }
                },
                # Shadowsocks on 503
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

        with open(CONFIG_FILE, 'w', encoding='utf-8') as f:
            json.dump(config, f, indent=2)

        # 重启Xray服务
        os.system("systemctl reload xray 2>/dev/null")

    def generate_vless_url(self, user):
        """生成VLESS URL - 端口 443 (标准HTTPS端口)"""
        vless_port = 443  # VLESS_PORT
        return f"vless://{user['uuid']}@{self.domain}:{vless_port}?encryption=none&security=tls&type=tcp#ProxyManager_{user['username']}"

    def generate_vmess_url(self, user):
        """生成VMESS URL - 端口 502"""
        vmess_port = 502  # VMESS_PORT
        vmess_config = {
            "v": "2",
            "ps": f"ProxyManager_{user['username']}",
            "add": self.domain,
            "port": str(vmess_port),
            "id": user['uuid'],
            "net": "tcp",
            "type": "none",
            "tls": "tls"
        }
        import base64
        json_str = json.dumps(vmess_config, separators=(',', ':'))
        b64 = base64.b64encode(json_str.encode()).decode()
        return f"vmess://{b64}"

    def generate_trojan_url(self, user):
        """生成Trojan URL - 端口 501"""
        trojan_port = 501  # TROJAN_PORT
        return f"trojan://{user['password']}@{self.domain}:{trojan_port}?security=tls&type=tcp#ProxyManager_{user['username']}"

    def generate_ss_url(self, user):
        """生成Shadowsocks URL - 端口 503"""
        import base64
        ss_port = 503  # SS_PORT
        method = "aes-256-gcm"
        user_info = f"{method}:{user['password']}"
        b64_info = base64.b64encode(user_info.encode()).decode()
        return f"ss://{b64_info}@{self.domain}:{ss_port}#ProxyManager_{user['username']}"

    def generate_clash_config(self, user):
        """生成Clash配置"""
        try:
            config = {
                "proxies": [
                    {
                        "name": f"ProxyManager_{user['username']}",
                        "type": "vless",
                        "server": self.domain,
                        "port": 443,  # VLESS_PORT - 标准HTTPS端口
                        "uuid": user['uuid'],
                        "udp": True,
                        "tls": True,
                        "network": "tcp"
                    }
                ],
                "proxy-groups": [
                    {
                        "name": "Proxy",
                        "type": "select",
                        "proxies": [f"ProxyManager_{user['username']}"]
                    }
                ],
                "rules": [
                    "MATCH,Proxy"
                ]
            }
            return yaml.dump(config)
        except Exception as e:
            # 如果 YAML 生成失败，返回 JSON 格式
            return json.dumps(config, indent=2)

    def generate_shadowrocket_config(self, user):
        """生成ShadowRocket配置 - Shadowrocket支持VLESS链接"""
        # Shadowrocket可以直接使用VLESS链接格式
        return self.generate_vless_url(user)

    def list_users(self):
        """列出所有用户"""
        result = []
        for user in self.users:
            status = "启用" if user['enabled'] else "禁用"
            traffic_info = f"{user['traffic_used']:.2f}/{user['traffic_limit']}GB" if user['traffic_limit'] > 0 else f"{user['traffic_used']:.2f}GB"
            result.append({
                'username': user['username'],
                'uuid': user['uuid'],
                'traffic': traffic_info,
                'status': status
            })
        return result

    def verify_admin(self, password):
        """验证管理员密码"""
        return password == self.admin_password

    def reset_user_password(self, username, new_password, requester_password):
        """重置用户密码

        Args:
            username: 要重置密码的用户名
            new_password: 新密码
            requester_password: 请求者的密码（用于权限验证）

        Returns:
            (success, message) 元组
        """
        # 验证请求者身份（管理员或用户本人）
        is_admin = self.verify_admin(requester_password)

        user = self.get_user(username)
        if not user:
            return False, "用户不存在"

        # 如果不是管理员，检查是否为用户本人
        if not is_admin:
            if user['password'] != requester_password:
                return False, "密码错误"
            # 普通用户只能重置自己的密码
            if requester_password != user['password']:
                return False, "只能重置自己的密码"

        # 重置密码
        user['password'] = new_password
        self.save_data()
        self.update_xray_config()  # 立即更新XRay配置，使新密码生效
        return True, "密码重置成功"

    def set_user_password(self, username, new_password):
        """直接设置用户密码（管理员专用）"""
        user = self.get_user(username)
        if not user:
            return False, "用户不存在"

        user['password'] = new_password
        self.save_data()
        self.update_xray_config()  # 立即更新XRay配置，使新密码生效
        return True, "密码设置成功"


def main():
    import sys
    import io
    # 设置UTF-8编码以支持中文输出
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

    manager = ProxyManager()
    command = sys.argv[1] if len(sys.argv) > 1 else ''

    if command == 'add':
        username = sys.argv[2]
        uuid = sys.argv[3]
        password = sys.argv[4]
        traffic_limit = int(sys.argv[5]) if len(sys.argv) > 5 else 0
        success, msg = manager.add_user(username, uuid, password, traffic_limit)
        print(msg)

    elif command == 'delete':
        username = sys.argv[2]
        success, msg = manager.delete_user(username)
        print(msg)

    elif command == 'list':
        users = manager.list_users()
        for user in users:
            print(f"{user['username']:<15} {user['uuid']:<20} {user['traffic']:<15} {user['status']:<15}")

    elif command == 'enable':
        username = sys.argv[2]
        success, msg = manager.enable_user(username)
        print(msg)

    elif command == 'disable':
        username = sys.argv[2]
        success, msg = manager.disable_user(username)
        print(msg)

    elif command == 'urls':
        username = sys.argv[2]
        user = manager.get_user(username)
        if user:
            print("VLESS:")
            print(manager.generate_vless_url(user))
            print("\nVMESS:")
            print(manager.generate_vmess_url(user))
            print("\nTrojan:")
            print(manager.generate_trojan_url(user))

    elif command == 'update_config':
        manager.update_xray_config()
        print('XRay config updated successfully!')

    elif command == 'status':
        import subprocess
        result = subprocess.run(['systemctl', 'is-active', 'xray'], capture_output=True, text=True)
        xray_status = result.stdout.strip()
        print(f"XRay Service: {xray_status}")


if __name__ == '__main__':
    main()
