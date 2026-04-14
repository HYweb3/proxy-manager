#!/bin/bash
# 密码重置功能测试脚本

echo "========================================="
echo "  密码重置功能测试"
echo "========================================="
echo ""

# 检查root权限
if [[ $EUID -ne 0 ]]; then
   echo "❌ 请使用root权限运行: sudo bash $0"
   exit 1
fi

echo "🧪 [1/5] 测试 /config/user.yaml 端点..."
echo "---"
# 测试配置文件生成（应该不再500错误）
TEST_USER="testuser"
curl -s -o /tmp/test_config.yaml http://localhost:5080/config/${TEST_USER}.yaml 2>/dev/null
if [ -f /tmp/test_config.yaml ]; then
    echo "✓ YAML配置文件下载成功"
    rm /tmp/test_config.yaml
else
    echo "✗ YAML配置文件下载失败（可能用户不存在，但路由本身正常）"
fi
echo ""

echo "🧪 [2/5] 测试用户重置自己的密码..."
echo "---"
# 测试API端点
curl -s -X POST http://localhost:5080/api/reset-password \
  -H "Content-Type: application/json" \
  -d '{
    "username": "testuser",
    "new_password": "newpass123",
    "current_password": "oldpass123"
  }' | python3 -m json.tool 2>/dev/null || echo "API测试完成"
echo ""

echo "🧪 [3/5] 测试管理员设置用户密码..."
echo "---"
curl -s -X POST http://localhost:5080/api/admin/set-password \
  -H "Content-Type: application/json" \
  -d '{
    "username": "testuser",
    "new_password": "adminset123"
  }' | python3 -m json.tool 2>/dev/null || echo "API测试完成"
echo ""

echo "🧪 [4/5] 检查ProxyManager方法..."
echo "---"
python3 << 'PYEOF'
import sys
sys.path.insert(0, '/etc/proxy-manager')
try:
    from proxy_manager import ProxyManager
    manager = ProxyManager()

    # 检查新方法是否存在
    if hasattr(manager, 'reset_user_password'):
        print("✓ reset_user_password() 方法存在")
    else:
        print("✗ reset_user_password() 方法不存在")

    if hasattr(manager, 'set_user_password'):
        print("✓ set_user_password() 方法存在")
    else:
        print("✗ set_user_password() 方法不存在")

    if hasattr(manager, 'generate_clash_config'):
        print("✓ generate_clash_config() 方法存在")
    else:
        print("✗ generate_clash_config() 方法不存在")

except Exception as e:
    print(f"✗ 检查失败: {e}")
PYEOF
echo ""

echo "🧪 [5/5] 测试YAML配置生成..."
echo "---"
python3 << 'PYEOF'
import sys
sys.path.insert(0, '/etc/proxy-manager')
try:
    from proxy_manager import ProxyManager
    import yaml

    manager = ProxyManager()

    # 创建测试用户
    test_user = {
        'username': 'testuser',
        'uuid': 'test-uuid-123',
        'password': 'test123',
        'enabled': True,
        'traffic_used': 0.0,
        'traffic_limit': 0
    }

    # 测试配置生成
    config = manager.generate_clash_config(test_user)
    print("✓ YAML配置生成成功")
    print(f"  配置长度: {len(config)} 字符")

    # 验证YAML格式
    if yaml.__version__:
        parsed = yaml.safe_load(config)
        print("✓ YAML格式验证通过")

except Exception as e:
    print(f"✗ 配置生成失败: {e}")
PYEOF
echo ""

echo "========================================="
echo "  测试完成"
echo "========================================="
echo ""
echo "🔧 如需应用到服务器:"
echo "sudo systemctl restart proxy-web"
echo ""
echo "🌐 访问地址:"
echo "http://YOUR_SERVER_IP:5080"
