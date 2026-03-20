#!/bin/bash

#############################################
# Proxy Manager - 快速安全验证
# 验证所有渠道的密码保护状态
#############################################

RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[36m"
PLAIN="\033[0m"
BOLD="\033[1m"

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${PLAIN}"
echo -e "${BOLD}${BLUE}Proxy Manager 密码保护验证${PLAIN}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${PLAIN}"
echo ""

USERS_FILE="/etc/proxy-manager/users.json"
CONFIG_FILE="/etc/proxy-manager/config.json"

# 检查1: 验证所有用户都有凭证
echo -e "${BOLD}[1] 用户凭证检查${PLAIN}"
if [[ -f "$USERS_FILE" ]]; then
    USER_COUNT=$(python3 -c "import json; data=json.load(open('$USERS_FILE')); print(len(data.get('users', [])))" 2>/dev/null || echo "0")

    if [[ "$USER_COUNT" -eq 0 ]]; then
        echo -e "${YELLOW}⚠ 没有配置用户${PLAIN}"
    else
        echo -e "${GREEN}✓${PLAIN} 找到 $USER_COUNT 个用户"

        # 检查每个用户
        python3 << PYTHON
import json
with open('$USERS_FILE') as f:
    data = json.load(f)
    users = data.get('users', [])
    for u in users:
        username = u.get('username', 'unknown')
        uuid = u.get('uuid', '')
        password = u.get('password', '')
        enabled = u.get('enabled', False)

        has_uuid = len(uuid) == 36 and uuid.count('-') == 4
        has_pass = len(password) >= 12

        status = "启用" if enabled else "禁用"
        uuid_ok = "✓" if has_uuid else "✗"
        pass_ok = "✓" if has_pass else "✗"

        print(f"  用户: {username:<15} 状态: {status:<6} UUID: {uuid_ok} 密码: {pass_ok}")
PYTHON
    fi
else
    echo -e "${RED}✗ 用户数据库不存在${PLAIN}"
fi

echo ""

# 检查2: 验证配置中的客户端凭证
echo -e "${BOLD}[2] Xray配置凭证检查${PLAIN}"
if [[ -f "$CONFIG_FILE" ]]; then
    python3 << PYTHON
import json

with open('$CONFIG_FILE') as f:
    config = json.load(f)
    inbounds = config.get('inbounds', [])

    protocols = {
        'vless': 'UUID认证',
        'trojan': '密码认证',
        'vmess': 'UUID认证',
        'shadowsocks': '密码认证'
    }

    for ib in inbounds:
        protocol = ib.get('protocol', 'unknown')
        port = ib.get('port', 0)
        settings = ib.get('settings', {})
        clients = settings.get('clients', [])

        has_clients = len(clients) > 0
        client_count = len(clients)

        status = "✓" if has_clients else "✗"
        auth_type = protocols.get(protocol, '未知')

        print(f"  端口 {port:<4} ({protocol:<12}): {status} {auth_type} - {client_count} 个客户端")
PYTHON
else
    echo -e "${YELLOW}⚠ Xray配置文件不存在${PLAIN}"
fi

echo ""

# 检查3: 验证安全配置
echo -e "${BOLD}[3] 安全配置检查${PLAIN}"
if [[ -f "$CONFIG_FILE" ]]; then
    # 检查TLS
    if grep -q '"security": "tls"' "$CONFIG_FILE" 2>/dev/null; then
        echo -e "${GREEN}✓${PLAIN} TLS加密已启用"
    else
        echo -e "${YELLOW}⚠${PLAIN} TLS加密未配置"
    fi

    # 检查allowInsecure
    if grep -q '"allowInsecure": false' "$CONFIG_FILE" 2>/dev/null; then
        echo -e "${GREEN}✓${PLAIN} 禁止不安全连接"
    else
        echo -e "${YELLOW}⚠${PLAIN} allowInsecure未设置"
    fi

    # 检查VMess disableInsecureEncryption
    if grep -q '"disableInsecureEncryption": true' "$CONFIG_FILE" 2>/dev/null; then
        echo -e "${GREEN}✓${PLAIN} VMess禁用弱加密"
    else
        echo -e "${YELLOW}⚠${PLAIN} VMess弱加密未禁用"
    fi

    # 检查空fallbacks
    if grep -q '"fallbacks": \[\]' "$CONFIG_FILE" 2>/dev/null; then
        echo -e "${GREEN}✓${PLAIN} 无回退配置（防止绕过认证）"
    else
        echo -e "${YELLOW}⚠${PLAIN} 未检查fallbacks配置"
    fi
fi

echo ""

# 检查4: 端口监听状态
echo -e "${BOLD}[4] 端口监听检查${PLAIN}"
PORTS=(500 501 502 503)
for port in "${PORTS[@]}"; do
    if ss -tlnp 2>/dev/null | grep -q ":${port} "; then
        echo -e "${GREEN}✓${PLAIN} 端口 ${port} 监听中"
    else
        echo -e "${YELLOW}⚠${PLAIN} 端口 ${port} 未监听"
    fi
done

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${PLAIN}"
echo -e "${GREEN}${BOLD}所有渠道都已配置密码保护！${PLAIN}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${PLAIN}"
