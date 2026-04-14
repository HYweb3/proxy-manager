#!/bin/bash
# Web服务错误诊断脚本

echo "========================================="
echo "  Proxy Manager Web错误诊断"
echo "========================================="
echo ""

# 检查root权限
if [[ $EUID -ne 0 ]]; then
   echo "❌ 请使用root权限运行: sudo bash $0"
   exit 1
fi

echo "🔍 [1/8] 检查服务状态..."
echo "---"
systemctl status proxy-web --no-pager | head -10
echo ""

echo "📋 [2/8] 查看详细错误日志..."
echo "---"
journalctl -u proxy-web -n 30 --no-pager
echo ""

echo "🐍 [3/8] 检查Python环境..."
echo "---"
python3 --version
which python3
echo ""

echo "📦 [4/8] 验证Python依赖..."
echo "---"
python3 << 'PYEOF'
import sys
print(f"Python版本: {sys.version}")

modules = {
    'flask': 'Flask',
    'qrcode': 'QRCode',
    'PIL': 'Pillow',
    'yaml': 'PyYAML',
    'cryptography': 'Cryptography',
    'flask_qrcode': 'Flask-QRCode'
}

missing = []
for module, name in modules.items():
    try:
        __import__(module)
        print(f"✓ {name}")
    except ImportError as e:
        print(f"✗ {name} - {e}")
        missing.append(name)

if missing:
    print(f"\n缺失模块: {missing}")
    sys.exit(1)
else:
    print("\n✅ 所有依赖正常")
PYEOF

if [ $? -ne 0 ]; then
    echo ""
    echo "🔧 正在安装缺失的模块..."
    python3 -m pip install --user flask flask-qrcode qrcode pillow pyyaml cryptography
fi
echo ""

echo "📁 [5/8] 检查文件和权限..."
echo "---"
ls -la /var/www/proxy-manager/proxy_web.py
if [ -f "/var/www/proxy-manager/proxy_web.py" ]; then
    python3 -m py_compile /var/www/proxy-manager/proxy_web.py && echo "✓ 文件语法正确" || echo "✗ 文件语法错误"
else
    echo "✗ proxy_web.py 文件不存在"
fi
echo ""

echo "⚙️  [6/8] 检查配置文件..."
echo "---"
if [ -f "/etc/proxy-manager/config.json" ]; then
    echo "✓ 配置文件存在"
    python3 -c "import json; json.load(open('/etc/proxy-manager/config.json'))" 2>/dev/null && echo "✓ 配置文件格式正确" || echo "✗ 配置文件格式错误"
else
    echo "✗ 配置文件不存在"
fi
echo ""

echo "🌐 [7/8] 检查端口监听..."
echo "---"
netstat -tlnp | grep 5080 || echo "端口5080未监听"
echo ""

echo "🧪 [8/8] 手动测试Web应用..."
echo "---"
cd /var/www/proxy-manager
echo "尝试手动启动..."
timeout 5 python3 proxy_web.py 2>&1 || true
echo ""

echo "========================================="
echo "  诊断完成"
echo "========================================="
echo ""

# 提供修复建议
echo "🔧 常见问题修复建议:"
echo ""
echo "1. 如果是模块缺失:"
echo "   python3 -m pip install --user flask flask-qrcode qrcode pillow pyyaml cryptography"
echo ""
echo "2. 如果是权限问题:"
echo "   sudo chown -R root:root /var/www/proxy-manager"
echo "   sudo chmod +x /var/www/proxy-manager/proxy_web.py"
echo ""
echo "3. 如果是配置文件问题:"
echo "   sudo cat /etc/proxy-manager/config.json | python3 -m json.tool"
echo ""
echo "4. 重启服务:"
echo "   sudo systemctl restart proxy-web"
echo "   sudo systemctl status proxy-web"
echo ""