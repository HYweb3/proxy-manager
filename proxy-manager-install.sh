#!/bin/bash

# Proxy Manager 一键安装脚本
# 从原始 URL 下载并安装

echo "正在下载 Proxy Manager..."
curl -L https://ok.bi5u.com/xxx/proxy-manager-full.zip -o proxy-manager.zip

echo "正在解压..."
unzip proxy-manager.zip -d proxy-manager

echo "进入目录并执行安装..."
cd proxy-manager && sudo bash quick_install.sh

echo "安装完成！"
