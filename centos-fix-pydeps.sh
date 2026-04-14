#!/bin/bash
# CentOS 7.9 Python依赖修复脚本
# 专门解决proxy-manager在CentOS上的Python依赖安装问题

set -e

echo "========================================="
echo "  CentOS 7.9 Python依赖修复"
echo "========================================="
echo ""

# 检查root权限
if [[ $EUID -ne 0 ]]; then
   echo "❌ 错误: 必须使用root用户运行此脚本"
   echo "请使用: sudo bash $0"
   exit 1
fi

echo "📦 [1/4] 安装EPEL仓库..."
yum install -y epel-release

echo "📦 [2/4] 安装Python和pip..."
yum install -y python3 python3-pip python3-devel

echo "📦 [3/4] 安装Python依赖包..."
# 方法1: 尝试系统包
if yum install -y python3-flask python3-qrcode python3-pillow python3-pyyaml python3-cryptography 2>/dev/null; then
    echo "✓ 系统包安装成功"
else
    echo "⚠ 系统包不可用，使用pip安装..."
    # 方法2: 使用pip --user（更兼容）
    python3 -m pip install --user flask flask-qrcode qrcode pillow pyyaml cryptography
fi

echo "🔍 [4/4] 验证安装..."
python3 -c "import flask; import qrcode; from PIL import Image; import yaml; import cryptography" && echo "✅ 所有依赖安装成功" || echo "❌ 部分依赖安装失败"

echo ""
echo "🔄 重启proxy-web服务..."
systemctl restart proxy-web 2>/dev/null || echo "⚠ proxy-web服务未找到，请先运行主安装脚本"

echo ""
echo "========================================="
echo "  修复完成！"
echo "========================================="
echo ""

# 显示服务状态
if systemctl is-active --quiet proxy-web; then
    echo "✅ proxy-web服务运行正常"
    echo ""
    echo "🌐 访问地址:"
    echo "   http://$(hostname -I | awk '{print $1}'):5080"
else
    echo "⚠ proxy-web服务状态异常，请检查:"
    echo "   systemctl status proxy-web"
    echo "   journalctl -u proxy-web -n 50"
fi