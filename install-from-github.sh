#!/bin/bash

# Proxy Manager GitHub 版本一键安装脚本
# 请将下面的 GITHUB_USERNAME 和 REPO_NAME 替换为你的实际值

GITHUB_USERNAME="hnbwww"
REPO_NAME="proxy-manager"
SCRIPT_FILE="proxy-manager-install.sh"

echo "正在从 GitHub 下载 Proxy Manager 安装脚本..."
curl -LO "https://raw.githubusercontent.com/${GITHUB_USERNAME}/${REPO_NAME}/main/${SCRIPT_FILE}"

echo "正在执行安装..."
chmod +x ${SCRIPT_FILE}
bash ${SCRIPT_FILE}

echo "安装完成！"
