#!/bin/bash
# 测试端口检测功能

echo "🧪 测试端口检测和自动切换功能"
echo "======================================"
echo ""

# 检测系统类型
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "📱 系统: macOS"
    CHECK_CMD="netstat -an | grep LISTEN"
else
    echo "🖥️  系统: Linux"
    CHECK_CMD="ss -tuln | grep LISTEN"
fi

echo ""
echo "🔍 当前端口占用情况:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 检查5080-5085端口占用情况
for port in {5080..5085}; do
    if command -v netstat &>/dev/null; then
        if netstat -an | grep -q ":${port}.*LISTEN"; then
            echo "   端口 ${port}: ❌ 被占用"
            # 显示占用进程
            PID=$(lsof -ti :$port 2>/dev/null)
            if [[ -n "$PID" ]]; then
                PROCESS=$(ps -p $PID -o comm= 2>/dev/null)
                echo "              进程: $PROCESS (PID: $PID)"
            fi
        else
            echo "   端口 ${port}: ✅ 可用"
        fi
    elif command -v ss &>/dev/null; then
        if ss -tuln | grep -q ":${port} "; then
            echo "   端口 ${port}: ❌ 被占用"
            # 显示占用进程
            PID=$(lsof -ti :$port 2>/dev/null)
            if [[ -n "$PID" ]]; then
                PROCESS=$(ps -p $PID -o comm= 2>/dev/null)
                echo "              进程: $PROCESS (PID: $PID)"
            fi
        else
            echo "   端口 ${port}: ✅ 可用"
        fi
    fi
done

echo ""
echo "🎯 模拟端口检测:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 模拟检测函数
check_port() {
    local port=$1
    if command -v netstat &>/dev/null; then
        netstat -an | grep -q ":${port}.*LISTEN" && return 0 || return 1
    elif command -v ss &>/dev/null; then
        ss -tuln | grep -q ":${port} " && return 0 || return 1
    else
        # 备用方法
        timeout 1 bash -c "echo >/dev/tcp/localhost/${port}" 2>/dev/null && return 0 || return 1
    fi
}

find_available_port() {
    local start_port=$1
    local max_attempts=5
    for ((i=0; i<max_attempts; i++)); do
        local port=$((start_port + i))
        if ! check_port $port; then
            echo $port
            return 0
        fi
    done
    echo ""
    return 1
}

# 测试端口检测
RESULT=$(find_available_port 5080)
if [[ -n "$RESULT" ]]; then
    if [[ "$RESULT" -eq 5080 ]]; then
        echo "   ✅ 默认端口 5080 可用，将使用该端口"
    else
        echo "   ⚠️  默认端口 5080 被占用，将使用端口 $RESULT"
    fi
else
    echo "   ❌ 无法找到可用端口 (5080-5084)"
fi

echo ""
echo "💡 功能说明:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "   1. 启动前自动检测端口 5080 是否可用"
echo "   2. 如果被占用，依次尝试 5081, 5082, 5083..."
echo "   3. 显示实际使用的端口号"
echo "   4. 保存实际端口到配置文件供后续使用"
echo "   5. 提供端口冲突解决建议"
echo ""

echo "🚀 测试启动 (5秒后自动停止):"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 创建临时测试配置
TEMP_DIR="/tmp/port-test-$$"
mkdir -p "$TEMP_DIR"

# 创建最小化的测试文件
cat > "$TEMP_DIR/test_proxy_web.py" << 'EOF'
import sys
import os
sys.path.insert(0, '/Users/www1')
from proxy_web import app, find_available_port

print("🔍 执行端口检测...")
available_port, attempts = find_available_port(5080, 5)

if available_port:
    if attempts > 0:
        print(f"⚠️  端口 5080 被占用，使用端口 {available_port}")
    else:
        print(f"✅ 端口 {available_port} 可用")

    print(f"🚀 启动测试服务器在端口 {available_port}...")
    print(f"📋 访问地址: http://localhost:{available_port}")
    print(f"⏱️  5秒后自动停止...")

    import threading
    import time

    def stop_server():
        time.sleep(5)
        print("🛑 停止测试服务器...")
        os._exit(0)

    stop_thread = threading.Thread(target=stop_server)
    stop_thread.daemon = True
    stop_thread.start()

    try:
        app.run(host='127.0.0.1', port=available_port, debug=False)
    except:
        pass
else:
    print("❌ 无法找到可用端口")
    sys.exit(1)
EOF

cd /Users/www1
python3 "$TEMP_DIR/test_proxy_web.py" 2>/dev/null

# 清理
rm -rf "$TEMP_DIR"

echo ""
echo "✅ 测试完成！"
echo ""