#!/bin/bash

#############################################
# Proxy Manager GitHub 一键安装脚本
# 自动下载并安装最新版本
#############################################

RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[36m"
CYAN="\033[36b"
MAGENTA="\033[35m"
PLAIN="\033[0m"
BOLD="\033[1m"

clear
echo -e "${MAGENTA}"
cat << 'EOF'
=========================================
  Proxy Manager 一键安装
=========================================
EOF
echo -e "${PLAIN}"

# 检测系统
if [[ "$OSTYPE" == "darwin"* ]]; then
    OS="macos"
else
    OS="linux"
fi

echo -e "${CYAN}检测到的系统: ${BOLD}${OS}${PLAIN}"
echo ""

# 创建临时目录
TEMP_DIR=$(mktemp -d)
cd ${TEMP_DIR}

echo -e "${YELLOW}📦 正在下载最新版本...${PLAIN}"

# 下载最新版本
DOWNLOAD_URL="https://ok.bi5u.com/xxx/proxy-manager-full.zip"
if curl -L -o proxy-manager.zip "${DOWNLOAD_URL}"; then
    echo -e "${GREEN}✓ 下载完成${PLAIN}"
else
    # 尝试备用URL
    echo -e "${YELLOW}⚠ 主下载失败，尝试备用源...${PLAIN}"
    DOWNLOAD_URL="https://github.com/HYweb3/proxy-manager/archive/refs/heads/main.zip"
    if curl -L -o proxy-manager.zip "${DOWNLOAD_URL}"; then
        echo -e "${GREEN}✓ 下载完成（备用源）${PLAIN}"
    else
        echo -e "${RED}✗ 下载失败${PLAIN}"
        rm -rf ${TEMP_DIR}
        exit 1
    fi
fi

echo -e "${YELLOW}📦 正在解压...${PLAIN}"
if unzip -q proxy-manager.zip; then
    echo -e "${GREEN}✓ 解压完成${PLAIN}"
else
    echo -e "${RED}✗ 解压失败${PLAIN}"
    rm -rf ${TEMP_DIR}
    exit 1
fi

# 找到解压后的目录
EXTRACTED_DIR=$(find . -maxdepth 1 -type d -name "*proxy-manager*" | head -1)
if [[ -z "$EXTRACTED_DIR" ]]; then
    EXTRACTED_DIR="."
fi

cd ${EXTRACTED_DIR}

echo -e "${YELLOW}🔧 正在安装...${PLAIN}"

# 检查是否有one_click_install.sh
if [[ -f "one_click_install.sh" ]]; then
    echo -e "${GREEN}✓${PLAIN} 找到 one_click_install.sh（推荐）"
    chmod +x one_click_install.sh
    bash one_click_install.sh
elif [[ -f "quick_install.sh" ]]; then
    echo -e "${GREEN}✓${PLAIN} 找到 quick_install.sh"
    chmod +x quick_install.sh
    if [[ "$OS" == "linux" ]] && [[ $EUID -ne 0 ]]; then
        echo -e "${YELLOW}⚠ Linux需要root权限，使用sudo${PLAIN}"
        sudo bash quick_install.sh
    else
        bash quick_install.sh
    fi
else
    echo -e "${RED}✗${PLAIN} 未找到安装脚本"
    echo -e "${YELLOW}手动安装:${PLAIN}"
    echo "1. 安装依赖: pip3 install flask flask-qrcode qrcode"
    echo "2. 运行Web: python3 proxy_web.py"
fi

# 清理临时文件
cd /
rm -rf ${TEMP_DIR}

echo ""
echo -e "${GREEN}安装脚本执行完成！${PLAIN}"
