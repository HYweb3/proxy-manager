#!/bin/bash

# Proxy Manager GitHub 版本一键安装脚本
# 直接从 GitHub 下载并安装

set -e

GITHUB_USERNAME="HYweb3"
REPO_NAME="proxy-manager"
ZIP_FILE="proxy-manager-full.zip"
SRC_DIR="proxy-manager-src"

echo "========================================="
echo "  Proxy Manager 一键安装"
echo "========================================="
echo ""

# 检查是否已安装
if [ -d "/opt/proxy-manager" ] || [ -f "/etc/systemd/system/proxy-manager.service" ]; then
    echo "⚠️  检测到已安装 Proxy Manager"
    read -p "是否重新安装？(y/N): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "安装已取消"
        exit 0
    fi
    echo "正在卸载旧版本..."
    [ -f "$SRC_DIR/uninstall.sh" ] && bash "$SRC_DIR/uninstall.sh" 2>/dev/null || true
fi

# 下载 zip 文件
echo "📥 正在从 GitHub 下载 Proxy Manager..."
DOWNLOAD_URL="https://github.com/${GITHUB_USERNAME}/${REPO_NAME}/raw/main/${ZIP_FILE}"
if ! curl -fL "$DOWNLOAD_URL" -o "$ZIP_FILE"; then
    echo "❌ 下载失败，请检查网络连接"
    exit 1
fi

# 解压
echo "📦 正在解压..."
rm -rf "$SRC_DIR"
unzip -q "$ZIP_FILE" -d "$SRC_DIR"

# 进入目录并执行安装
echo "🔧 正在安装..."
cd "$SRC_DIR"

if [ -f "quick_install.sh" ]; then
    sudo bash quick_install.sh
elif [ -f "install.sh" ]; then
    sudo bash install.sh
elif [ -f "one_click_install.sh" ]; then
    sudo bash one_click_install.sh
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
echo "📋 重要信息已保存到:"
echo "   /etc/proxy-manager/install_info.txt"
echo ""
echo "📖 查看安装信息:"
echo "   cat /etc/proxy-manager/install_info.txt"
echo ""
echo "🌐 Web管理面板:"
echo "   http://$(hostname -I | awk '{print $1}'):8080"
echo "   http://localhost:8080"
echo ""
echo "💡 提示: 安装信息包含连接链接、端口配置、管理命令等"
echo "         请妥善保存 install_info.txt 文件！"
echo ""
