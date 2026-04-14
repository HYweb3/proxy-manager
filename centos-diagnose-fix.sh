#!/bin/bash
# CentOS 7.9 服务诊断和修复脚本
# 专门解决XRay和Web服务启动失败问题

set -e

echo "========================================="
echo "  Proxy Manager 服务诊断修复"
echo "========================================="
echo ""

# 检查root权限
if [[ $EUID -ne 0 ]]; then
   echo "❌ 错误: 必须使用root用户运行此脚本"
   echo "请使用: sudo bash $0"
   exit 1
fi

echo "🔍 [1/6] 检查服务状态..."
echo "---"
systemctl status xray 2>/dev/null | head -3 || echo "XRay服务未找到"
systemctl status proxy-web 2>/dev/null | head -3 || echo "proxy-web服务未找到"
echo ""

echo "📋 [2/6] 查看服务日志..."
echo "---"
echo "=== XRay 日志 ==="
journalctl -u xray -n 10 --no-pager 2>/dev/null || echo "无XRay日志"
echo ""
echo "=== proxy-web 日志 ==="
journalctl -u proxy-web -n 10 --no-pager 2>/dev/null || echo "无proxy-web日志"
echo ""

echo "🔧 [3/6] 检查配置文件..."
echo "---"
# 检查XRay配置
if [ -f "/etc/xray/config.json" ]; then
    echo "✓ XRay配置文件存在"
    python3 -c "import json; json.load(open('/etc/xray/config.json'))" 2>/dev/null && echo "✓ XRay配置JSON格式正确" || echo "✗ XRay配置JSON格式错误"
else
    echo "✗ XRay配置文件不存在"
fi

# 检查proxy-web配置
if [ -f "/etc/proxy-manager/config.json" ]; then
    echo "✓ proxy-manager配置文件存在"
else
    echo "✗ proxy-manager配置文件不存在"
fi

# 检查程序文件
if [ -f "/var/www/proxy-manager/proxy_web.py" ]; then
    echo "✓ proxy_web.py文件存在"
    # 检查Python语法
    python3 -m py_compile /var/www/proxy-manager/proxy_web.py 2>/dev/null && echo "✓ proxy_web.py语法正确" || echo "✗ proxy_web.py语法错误"
else
    echo "✗ proxy_web.py文件不存在"
fi
echo ""

echo "🌐 [4/6] 检查端口占用..."
echo "---"
for port in 443 501 502 503 5080; do
    if netstat -tlnp 2>/dev/null | grep ":$port " > /dev/null; then
        echo "端口 $port: 已占用"
        netstat -tlnp 2>/dev/null | grep ":$port "
    else
        echo "端口 $port: 空闲 ✓"
    fi
done
echo ""

echo "👥 [5/6] 检查文件权限..."
echo "---"
# 检查关键目录权限
for dir in /etc/proxy-manager /var/www/proxy-manager /var/log/proxy-manager; do
    if [ -d "$dir" ]; then
        perms=$(stat -c "%a" "$dir" 2>/dev/null || stat -f "%A" "$dir" 2>/dev/null)
        echo "$dir: $perms"
    else
        echo "✗ $dir 不存在"
    fi
done

# 检查执行权限
if [ -f "/var/www/proxy-manager/proxy_web.py" ]; then
    if [ -x "/var/www/proxy-manager/proxy_web.py" ]; then
        echo "✓ proxy_web.py 有执行权限"
    else
        echo "✗ proxy_web.py 无执行权限，正在修复..."
        chmod +x /var/www/proxy-manager/proxy_web.py
    fi
fi
echo ""

echo "🐍 [6/6] 检查Python依赖..."
echo "---"
python3 -c "
import sys
modules = ['flask', 'qrcode', 'PIL', 'yaml', 'cryptography']
missing = []
for module in modules:
    try:
        __import__(module)
        print(f'✓ {module}')
    except ImportError:
        print(f'✗ {module} 缺失')
        missing.append(module)

if missing:
    print(f'\\n缺失模块: {missing}')
    sys.exit(1)
"

if [ $? -ne 0 ]; then
    echo ""
    echo "🔧 正在安装缺失的Python依赖..."
    python3 -m pip install --user -q flask flask-qrcode qrcode pillow pyyaml cryptography || echo "⚠ Python依赖安装失败"
fi

echo ""
echo "========================================="
echo "  诊断完成"
echo "========================================="
echo ""

# 开始修复
echo "🔧 开始修复..."
echo ""

# 修复XRay服务
if ! systemctl is-active --quiet xray 2>/dev/null; then
    echo "📡 修复XRay服务..."

    # 检查xray二进制文件
    if [ ! -f "/usr/local/bin/xray" ]; then
        echo "✗ XRay二进制文件不存在"
        echo "📥 正在下载XRay..."
        ARCH=$(uname -m)
        if [ "$ARCH" == "x86_64" ]; then
            XRAY_ARCH="linux-64"
        elif [ "$ARCH" == "aarch64" ]; then
            XRAY_ARCH="linux-64"  # XRay uses same binary for both
        else
            XRAY_ARCH="linux-64"
        fi

        XRAY_VERSION="v26.3.27"
        wget -q --show-progress "https://github.com/XTLS/Xray-core/releases/download/${XRAY_VERSION}/Xray-${XRAY_ARCH}.zip" -O /tmp/xray-install.zip
        unzip -o /tmp/xray-install.zip -d /usr/local/bin/
        chmod +x /usr/local/bin/xray
        rm /tmp/xray-install.zip
        echo "✓ XRay安装完成"
    fi

    # 生成基础XRay配置
    if [ ! -f "/etc/xray/config.json" ]; then
        echo "📝 生成XRay配置文件..."
        mkdir -p /etc/xray
        cat > /etc/xray/config.json << 'EOF'
{
  "log": {
    "loglevel": "warning"
  },
  "inbounds": [],
  "outbounds": [
    {
      "protocol": "freedom",
      "tag": "direct"
    }
  ]
}
EOF
        echo "✓ XRay配置文件创建完成"
    fi

    # 重启XRay
    systemctl restart xray 2>/dev/null && echo "✓ XRay服务启动成功" || echo "✗ XRay服务启动失败"
else
    echo "✓ XRay服务运行正常"
fi

echo ""

# 修复proxy-web服务
if ! systemctl is-active --quiet proxy-web 2>/dev/null; then
    echo "🌐 修复proxy-web服务..."

    # 检查必要文件
    mkdir -p /var/www/proxy-manager
    mkdir -p /etc/proxy-manager
    mkdir -p /var/log/proxy-manager

    # 如果proxy_web.py不存在，从安装目录复制
    if [ ! -f "/var/www/proxy-manager/proxy_web.py" ]; then
        if [ -f "/root/proxy-manager-src/proxy_web.py" ]; then
            cp /root/proxy-manager-src/proxy_web.py /var/www/proxy-manager/
            echo "✓ proxy_web.py复制完成"
        elif [ -f "/home/www1/proxy-manager-src/proxy_web.py" ]; then
            cp /home/www1/proxy-manager-src/proxy_web.py /var/www/proxy-manager/
            echo "✓ proxy_web.py复制完成"
        else
            echo "✗ 找不到proxy_web.py文件"
        fi
    fi

    # 设置权限
    chmod +x /var/www/proxy-manager/proxy_web.py 2>/dev/null
    chown -R $(whoami):$(whoami) /var/www/proxy-manager 2>/dev/null
    chown -R $(whoami):$(whoami) /etc/proxy-manager 2>/dev/null

    # 修复systemd服务文件
    cat > /etc/systemd/system/proxy-web.service << 'EOF'
[Unit]
Description=Proxy Manager Web Interface
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/var/www/proxy-manager
ExecStart=/usr/bin/python3 /var/www/proxy-manager/proxy_web.py
Restart=on-failure
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl restart proxy-web 2>/dev/null && echo "✓ proxy-web服务启动成功" || echo "✗ proxy-web服务启动失败"
else
    echo "✓ proxy-web服务运行正常"
fi

echo ""
echo "========================================="
echo "  最终状态检查"
echo "========================================="
echo ""

# 显示服务状态
if systemctl is-active --quiet xray 2>/dev/null; then
    echo "✅ XRay服务: 运行中"
else
    echo "❌ XRay服务: 未运行"
fi

if systemctl is-active --quiet proxy-web 2>/dev/null; then
    echo "✅ Web管理界面: 运行中"
    # 获取服务器IP
    SERVER_IP=$(curl -s4 ip.sb 2>/dev/null || curl -s4 ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')
    echo ""
    echo "🌐 访问地址:"
    echo "   http://$SERVER_IP:5080"
    echo "   http://localhost:5080"
else
    echo "❌ Web管理界面: 未运行"
    echo ""
    echo "🔍 查看详细日志:"
    echo "   journalctl -u proxy-web -n 50"
    echo "   systemctl status proxy-web"
fi

echo ""
echo "📋 常用命令:"
echo "   重启服务: systemctl restart xray proxy-web"
echo "   查看状态: systemctl status xray proxy-web"
echo "   查看日志: journalctl -u xray -f 或 journalctl -u proxy-web -f"