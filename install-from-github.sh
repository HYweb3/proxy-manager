#!/bin/bash

# Proxy Manager GitHub 版本一键安装脚本
# 直接从 GitHub 下载并安装

set -e

GITHUB_USERNAME="HYweb3"
REPO_NAME="proxy-manager"
ZIP_FILE="proxy-manager-full.zip"
SRC_DIR="proxy-manager-src"
WEB_PORT=5080  # Web管理界面端口

echo "========================================="
echo "  Proxy Manager 一键安装"
echo "========================================="
echo ""

# 检查root权限
if [[ $EUID -ne 0 ]]; then
    echo "❌ 错误: 必须使用root用户运行此脚本"
    echo "请使用: sudo bash $0"
    exit 1
fi

# 安装必要的依赖
echo "📦 检查并安装依赖..."
if command -v apt-get &> /dev/null; then
    apt-get update -qq
    apt-get install -y curl wget unzip python3 python3-pip openssl 2>/dev/null
elif command -v dnf &> /dev/null; then
    dnf install -y curl wget unzip python3 python3-pip openssl 2>/dev/null
elif command -v yum &> /dev/null; then
    yum install -y curl wget unzip python3 python3-pip openssl 2>/dev/null
else
    echo "⚠️  未知的包管理器，跳过依赖安装"
fi

# 检查是否已安装
if [ -d "/etc/proxy-manager" ] || [ -f "/etc/systemd/system/xray.service" ] || [ -f "/etc/systemd/system/proxy-web.service" ]; then
    echo "⚠️  检测到已安装 Proxy Manager"
    read -p "是否重新安装？(y/N): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "安装已取消"
        exit 0
    fi
    echo "正在卸载旧版本..."
    [ -f "$SRC_DIR/uninstall.sh" ] && bash "$SRC_DIR/uninstall.sh" 2>/dev/null || true
    # 停止并禁用服务
    systemctl stop xray proxy-web 2>/dev/null || true
    systemctl disable xray proxy-web 2>/dev/null || true
fi

# 下载 zip 文件
echo "📥 正在从 GitHub 下载 Proxy Manager..."
DOWNLOAD_URL="https://github.com/${GITHUB_USERNAME}/${REPO_NAME}/raw/main/${ZIP_FILE}"
if ! curl -fL --connect-timeout 30 --max-time 300 "$DOWNLOAD_URL" -o "$ZIP_FILE"; then
    echo "❌ 下载失败，请检查网络连接或稍后重试"
    rm -f "$ZIP_FILE"
    exit 1
fi

# 检查下载的文件
if [ ! -s "$ZIP_FILE" ]; then
    echo "❌ 下载的文件为空或损坏"
    rm -f "$ZIP_FILE"
    exit 1
fi

# 解压
echo "📦 正在解压..."
rm -rf "$SRC_DIR"
unzip -q "$ZIP_FILE" -d "$SRC_DIR"

# 进入目录并执行安装
echo "🔧 正在安装..."
cd "$SRC_DIR"

# 优先使用 one_click_install.sh（最新版本）
if [ -f "one_click_install.sh" ]; then
    echo "✓ 找到 one_click_install.sh（推荐）"
    sudo bash one_click_install.sh
elif [ -f "quick_install.sh" ]; then
    echo "✓ 找到 quick_install.sh"
    sudo bash quick_install.sh
elif [ -f "install.sh" ]; then
    echo "✓ 找到 install.sh"
    sudo bash install.sh
else
    echo "❌ 未找到安装脚本"
    exit 1
fi

# 清理
cd ..
rm -f "$ZIP_FILE"
rm -rf "$SRC_DIR"

echo ""
echo "========================================="
echo "✅ 安装完成！"
echo "========================================="
echo ""

# 获取服务器IP
SERVER_IP=$(curl -s4 ip.sb 2>/dev/null || curl -s4 ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')

echo "📋 重要信息已保存到:"
echo "   /etc/proxy-manager/install_info.txt"
echo ""
echo "📖 查看安装信息:"
echo "   cat /etc/proxy-manager/install_info.txt"
echo ""
echo "🌐 Web管理面板:"
echo "   http://${SERVER_IP}:${WEB_PORT}"
echo "   http://localhost:${WEB_PORT}"
echo ""
echo "💡 提示: 安装信息包含连接链接、端口配置、管理命令等"
echo "         请妥善保存 install_info.txt 文件！"
echo ""
echo "🔧 常用命令:"
echo "   查看用户列表:   python3 /etc/proxy-manager/proxy_manager.py list"
echo "   重启服务:       systemctl restart xray proxy-web"
echo "   查看状态:       systemctl status xray proxy-web"
echo "   查看日志:       journalctl -u xray -f"
echo ""
