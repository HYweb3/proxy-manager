#!/bin/bash

#############################################
# Proxy Manager - 安全检查脚本
# 检查系统的安全配置状态
#############################################

RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[36m"
CYAN="\033[36m"
PLAIN="\033[0m"
BOLD="\033[1m"

CONFIG_DIR="/etc/proxy-manager"
USERS_FILE="${CONFIG_DIR}/users.json"
CONFIG_FILE="${CONFIG_DIR}/config.json"

echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${PLAIN}"
echo -e "${CYAN}║${PLAIN}           ${BOLD}Proxy Manager 安全检查${PLAIN}            ${CYAN}║${PLAIN}"
echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${PLAIN}"
echo ""

# 检查root权限
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}✗ 错误: 需要root权限运行此脚本${PLAIN}"
    exit 1
fi

# 检查项目计数
PASS_COUNT=0
WARN_COUNT=0
FAIL_COUNT=0

# 检查函数
check_pass() {
    echo -e "${GREEN}✓${PLAIN} $1"
    ((PASS_COUNT++))
}

check_warn() {
    echo -e "${YELLOW}⚠${PLAIN} $1"
    ((WARN_COUNT++))
}

check_fail() {
    echo -e "${RED}✗${PLAIN} $1"
    ((FAIL_COUNT++))
}

echo -e "${BOLD}${CYAN}[1] 配置文件检查${PLAIN}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [[ -f "$USERS_FILE" ]]; then
    check_pass "用户数据库存在"

    # 检查文件权限
    PERMISSIONS=$(stat -c %a "$USERS_FILE" 2>/dev/null || stat -f %A "$USERS_FILE" 2>/dev/null)
    if [[ "$PERMISSIONS" == "600" ]] || [[ "$PERMISSIONS" == "640" ]]; then
        check_pass "用户数据库权限正确 ($PERMISSIONS)"
    else
        check_warn "用户数据库权限过于宽松: $PERMISSIONS (建议600或640)"
    fi

    # 检查是否有管理员密码
    if grep -q '"admin_password"' "$USERS_FILE" 2>/dev/null; then
        ADMIN_PASS=$(grep '"admin_password"' "$USERS_FILE" | grep -o '"[^"]*"' | tail -1 | tr -d '"')
        if [[ -n "$ADMIN_PASS" ]] && [[ "$ADMIN_PASS" != "" ]]; then
            check_pass "管理员密码已设置"
        else
            check_fail "管理员密码未设置"
        fi
    fi

    # 检查用户数量
    USER_COUNT=$(python3 -c "import json; data=json.load(open('$USERS_FILE')); print(len(data.get('users', [])))" 2>/dev/null || echo "0")
    if [[ "$USER_COUNT" -gt 0 ]]; then
        check_pass "存在 $USER_COUNT 个用户"

        # 检查启用用户数量
        ENABLED_COUNT=$(python3 -c "import json; data=json.load(open('$USERS_FILE')); users=[u for u in data.get('users', []) if u.get('enabled', False)]; print(len(users))" 2>/dev/null || echo "0")
        if [[ "$ENABLED_COUNT" -gt 0 ]]; then
            check_pass "有 $ENABLED_COUNT 个启用用户"
        else
            check_warn "没有启用的用户（所有代理端口已关闭）"
        fi
    else
        check_warn "没有配置用户"
    fi
else
    check_fail "用户数据库不存在: $USERS_FILE"
fi

if [[ -f "$CONFIG_FILE" ]]; then
    check_pass "Xray配置文件存在"

    # 检查是否有inbounds配置
    INBOUND_COUNT=$(python3 -c "import json; data=json.load(open('$CONFIG_FILE')); print(len(data.get('inbounds', [])))" 2>/dev/null || echo "0")
    if [[ "$INBOUND_COUNT" -eq 0 ]]; then
        check_warn "没有配置入站规则（代理端口已关闭）"
    else
        check_pass "配置了 $INBOUND_COUNT 个入站规则"

        # 检查是否所有入站都有clients
        ALL_HAVE_CLIENTS=true
        for i in $(seq 0 $((INBOUND_COUNT-1))); do
            CLIENT_COUNT=$(python3 -c "import json; data=json.load(open('$CONFIG_FILE')); ib=data.get('inbounds', [])[$i]; clients=ib.get('settings', {}).get('clients', []); print(len(clients))" 2>/dev/null || echo "0")
            if [[ "$CLIENT_COUNT" -eq 0 ]]; then
                ALL_HAVE_CLIENTS=false
            fi
        done

        if [[ "$ALL_HAVE_CLIENTS" == "true" ]]; then
            check_pass "所有入站规则都有客户端配置"
        else
            check_fail "存在没有客户端配置的入站规则（可能导致开放代理）"
        fi
    fi

    # 检查TLS配置
    if grep -q '"security": "tls"' "$CONFIG_FILE" 2>/dev/null; then
        check_pass "TLS加密已配置"
    else
        check_warn "TLS加密未配置（Shadowsocks除外）"
    fi

    # 检查allowInsecure
    if grep -q '"allowInsecure": false' "$CONFIG_FILE" 2>/dev/null; then
        check_pass "不允许不安全连接"
    else
        check_warn "未设置allowInsecure（建议设置为false）"
    fi
else
    check_fail "Xray配置文件不存在: $CONFIG_FILE"
fi

# 检查证书文件
if [[ -f "${CONFIG_DIR}/server.crt" ]] && [[ -f "${CONFIG_DIR}/server.key" ]]; then
    check_pass "TLS证书文件存在"

    KEY_PERM=$(stat -c %a "${CONFIG_DIR}/server.key" 2>/dev/null || stat -f %A "${CONFIG_DIR}/server.key" 2>/dev/null)
    if [[ "$KEY_PERM" == "600" ]] || [[ "$KEY_PERM" == "400" ]]; then
        check_pass "私钥文件权限正确 ($KEY_PERM)"
    else
        check_fail "私钥文件权限不安全: $KEY_PERM (必须600或400)"
    fi
else
    check_fail "TLS证书文件缺失"
fi

echo ""
echo -e "${BOLD}${CYAN}[2] 服务状态检查${PLAIN}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if systemctl is-active --quiet xray; then
    check_pass "Xray服务运行中"

    # 检查端口监听
    if ss -tlnp 2>/dev/null | grep -q ":500 "; then
        check_pass "VLESS端口(500)监听中"
    else
        check_warn "VLESS端口(500)未监听"
    fi

    if ss -tlnp 2>/dev/null | grep -q ":501 "; then
        check_pass "Trojan端口(501)监听中"
    else
        check_warn "Trojan端口(501)未监听"
    fi

    if ss -tlnp 2>/dev/null | grep -q ":502 "; then
        check_pass "VMess端口(502)监听中"
    else
        check_warn "VMess端口(502)未监听"
    fi

    if ss -tlnp 2>/dev/null | grep -q ":503 "; then
        check_pass "Shadowsocks端口(503)监听中"
    else
        check_warn "Shadowsocks端口(503)未监听"
    fi
else
    check_warn "Xray服务未运行"
fi

if systemctl is-active --quiet proxy-web; then
    check_pass "Web管理服务运行中"

    if ss -tlnp 2>/dev/null | grep -q ":5080 "; then
        check_pass "Web管理端口(5080)监听中"
    else
        check_warn "Web管理端口(5080)未监听"
    fi
else
    check_warn "Web管理服务未运行"
fi

echo ""
echo -e "${BOLD}${CYAN}[3] 防火墙检查${PLAIN}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if command -v firewall-cmd &>/dev/null; then
    if firewall-cmd --state &>/dev/null; then
        check_pass "firewalld防火墙运行中"

        # 检查端口
        for port in 500 501 502 503 5080; do
            if firewall-cmd --list-ports | grep -q "${port}/tcp"; then
                check_pass "端口 ${port} 已开放"
            else
                check_warn "端口 ${port} 未在防火墙开放"
            fi
        done
    else
        check_warn "firewalld防火墙未运行"
    fi
elif command -v ufw &>/dev/null; then
    if ufw status | grep -q "Status: active"; then
        check_pass "ufw防火墙运行中"

        for port in 500 501 502 503 5080; do
            if ufw status | grep -q "${port}/tcp.*ALLOW"; then
                check_pass "端口 ${port} 已开放"
            else
                check_warn "端口 ${port} 未在防火墙开放"
            fi
        done
    else
        check_warn "ufw防火墙未激活"
    fi
else
    check_warn "未检测到防火墙"
fi

echo ""
echo -e "${BOLD}${CYAN}[4] 日志检查${PLAIN}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [[ -f "/var/log/xray/access.log" ]]; then
    check_pass "访问日志文件存在"

    # 检查最近的日志
    if [[ -s "/var/log/xray/access.log" ]]; then
        check_pass "访问日志有记录"

        # 显示最近的几条
        RECENT_LOGS=$(tail -3 /var/log/xray/access.log 2>/dev/null | wc -l)
        if [[ "$RECENT_LOGS" -gt 0 ]]; then
            echo -e "${CYAN}最近的活动:${PLAIN}"
            tail -3 /var/log/xray/access.log | sed 's/^/  /'
        fi
    else
        check_warn "访问日志为空"
    fi
else
    check_fail "访问日志文件不存在"
fi

echo ""
echo -e "${BOLD}${CYAN}[5] 安全建议${PLAIN}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 检查管理员密码强度
if [[ -n "$ADMIN_PASS" ]]; then
    if [[ ${#ADMIN_PASS} -lt 12 ]]; then
        check_warn "管理员密码长度不足12位，建议使用更强的密码"
    else
        check_pass "管理员密码长度符合要求"
    fi
fi

# 检查是否有弱密码用户
WEAK_PASS_COUNT=$(python3 -c "
import json
try:
    with open('$USERS_FILE') as f:
        data = json.load(f)
        weak = [u for u in data.get('users', []) if len(u.get('password', '')) < 12]
        print(len(weak))
except:
    print(0)
" 2>/dev/null || echo "0")

if [[ "$WEAK_PASS_COUNT" -gt 0 ]]; then
    check_warn "发现 $WEAK_PASS_COUNT 个用户密码长度不足12位"
else
    check_pass "所有用户密码长度符合要求"
fi

echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${PLAIN}"
echo -e "${BOLD}检查结果汇总${PLAIN}"
echo -e "${GREEN}通过: ${PASS_COUNT}${PLAIN} | ${YELLOW}警告: ${WARN_COUNT}${PLAIN} | ${RED}失败: ${FAIL_COUNT}${PLAIN}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${PLAIN}"

if [[ "$FAIL_COUNT" -gt 0 ]]; then
    echo ""
    echo -e "${RED}⚠ 发现 ${FAIL_COUNT} 个安全问题，请立即处理！${PLAIN}"
    exit 1
elif [[ "$WARN_COUNT" -gt 0 ]]; then
    echo ""
    echo -e "${YELLOW}⚠ 发现 ${WARN_COUNT} 个警告，建议检查并优化。${PLAIN}"
    exit 0
else
    echo ""
    echo -e "${GREEN}✓ 所有安全检查通过！${PLAIN}"
    exit 0
fi
