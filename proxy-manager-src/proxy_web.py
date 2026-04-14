#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Proxy Manager - Web管理界面
提供扫码、复制链接、配置管理功能
"""

import os
import sys
import subprocess

def install_missing_modules(modules):
    """自动安装缺失的 Python 模块，兼容 CentOS 和 Ubuntu"""
    print("🔧 检测到缺失模块，尝试自动安装...", file=sys.stderr)

    # 尝试使用 pip3 安装
    try:
        cmd = [sys.executable, '-m', 'pip', 'install', '-q'] + modules
        result = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=300)
        if result.returncode == 0:
            print("✅ 模块安装成功", file=sys.stderr)
            return True
        else:
            print(f"⚠️  pip安装失败: {result.stderr.decode()}", file=sys.stderr)
    except Exception as e:
        print(f"⚠️  pip安装异常: {e}", file=sys.stderr)

    # 尝试使用系统包管理器
    try:
        # 检测系统类型
        if os.path.exists('/etc/debian_version'):
            # Debian/Ubuntu 系统
            print("尝试使用 apt 安装...", file=sys.stderr)
            packages = []
            for module in modules:
                if module == 'flask':
                    packages.append('python3-flask')
                elif module == 'pillow':
                    packages.append('python3-pil')
                elif module == 'qrcode':
                    packages.append('python3-qrcode')
                elif module == 'pyyaml':
                    packages.append('python3-yaml')
                elif module == 'flask-qrcode':
                    # flask-qrcode 通常不在系统仓库中，跳过
                    pass

            if packages:
                cmd = ['apt-get', 'install', '-y'] + packages
                result = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=300)
                if result.returncode == 0:
                    print("✅ 系统包安装成功", file=sys.stderr)
                    return True
        elif os.path.exists('/etc/redhat-release'):
            # RedHat/CentOS 系统
            print("尝试使用 yum 安装...", file=sys.stderr)
            packages = []
            for module in modules:
                if module == 'flask':
                    packages.append('python3-flask')
                elif module == 'pillow':
                    packages.append('python3-pillow')
                elif module == 'qrcode':
                    packages.append('python3-qrcode')
                elif module == 'flask-qrcode':
                    # flask-qrcode 通常不在系统仓库中，跳过
                    pass

            if packages:
                cmd = ['yum', 'install', '-y'] + packages
                result = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=300)
                if result.returncode == 0:
                    print("✅ 系统包安装成功", file=sys.stderr)
                    return True
    except Exception as e:
        print(f"⚠️  系统包安装异常: {e}", file=sys.stderr)

    return False

def check_and_import_modules():
    """检查并导入必需的模块，如果缺失则尝试安装"""
    missing_modules = []

    # 第一轮检查：找出缺失的模块
    try:
        from flask import Flask, render_template, request, jsonify, session, redirect, send_file
    except ImportError:
        missing_modules.append('flask')

    try:
        from flask_qrcode import QRcode
    except ImportError:
        missing_modules.append('flask-qrcode')

    try:
        from PIL import Image
    except ImportError:
        missing_modules.append('pillow')

    try:
        import qrcode
    except ImportError:
        missing_modules.append('qrcode')

    try:
        import yaml
    except ImportError:
        missing_modules.append('pyyaml')

    # 如果有缺失模块，尝试安装
    if missing_modules:
        print(f"缺失模块: {', '.join(missing_modules)}", file=sys.stderr)
        if install_missing_modules(missing_modules):
            # 安装成功，重新导入
            import importlib
            for module in missing_modules:
                try:
                    importlib.import_module(module.replace('-', '_'))
                except ImportError:
                    pass

        # 第二轮检查：验证是否都可用
        still_missing = []
        try:
            from flask import Flask, render_template, request, jsonify, session, redirect, send_file
            from flask_qrcode import QRcode
            from PIL import Image
            import qrcode
            import yaml
        except ImportError as e:
            still_missing.append(str(e))

        if still_missing:
            print("=" * 60, file=sys.stderr)
            print("❌ 错误: 无法自动安装所有必需的 Python 模块", file=sys.stderr)
            print("=" * 60, file=sys.stderr)
            print("请手动安装以下模块:", file=sys.stderr)
            for module in missing_modules:
                print(f"  - {module}", file=sys.stderr)
            print("", file=sys.stderr)
            print("安装命令:", file=sys.stderr)
            print(f"  pip3 install " + " ".join(missing_modules), file=sys.stderr)
            print("", file=sys.stderr)
            print("或者使用系统包管理器:", file=sys.stderr)
            print("  Ubuntu/Debian: sudo apt-get update && sudo apt-get install -y python3-flask python3-qrcode python3-pil python3-yaml", file=sys.stderr)
            print("  CentOS/RHEL:   sudo yum install -y python3-flask python3-qrcode python3-pillow", file=sys.stderr)
            print("", file=sys.stderr)
            print("注意: flask-qrcode 需要通过 pip 安装:", file=sys.stderr)
            print("  pip3 install flask-qrcode", file=sys.stderr)
            print("=" * 60, file=sys.stderr)
            sys.exit(1)

    # 成功导入所有模块
    from flask import Flask, render_template, request, jsonify, session, redirect, send_file
    from flask_qrcode import QRcode
    from PIL import Image
    import qrcode
    import yaml
    import json
    import io
    import base64

    return Flask, render_template, request, jsonify, session, redirect, send_file, QRcode, qrcode

# 导入所有必需模块
Flask, render_template, request, jsonify, session, redirect, send_file, QRcode, qrcode = check_and_import_modules()
import json
import io
import base64

# 添加配置管理器路径
CONFIG_PATH = os.path.expanduser('~/.proxy-manager')
if os.path.exists('/etc/proxy-manager'):
    CONFIG_PATH = '/etc/proxy-manager'
sys.path.insert(0, CONFIG_PATH)
from proxy_manager import ProxyManager

# 设置模板目录并确保模板文件存在
template_dir = os.path.expanduser('~/.proxy-manager/templates')
os.makedirs(template_dir, exist_ok=True)

def ensure_templates_exist():
    """确保所有必需的模板文件存在"""
    template_files = ['login.html', 'index.html', 'user_config.html']
    for template_file in template_files:
        template_path = os.path.join(template_dir, template_file)
        if not os.path.exists(template_path):
            return False
    return True

# 如果模板文件不存在，创建它们
if not ensure_templates_exist():
    # 简化的login.html模板
    login_html = '''<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>代理管理 - 登录</title>
    <style>
        body { font-family: Arial, sans-serif; background: #f5f5f5; display: flex; justify-content: center; align-items: center; min-height: 100vh; margin: 0; }
        .login-container { background: white; padding: 40px; border-radius: 10px; box-shadow: 0 4px 6px rgba(0,0,0,0.1); width: 100%; max-width: 400px; }
        h1 { text-align: center; color: #333; margin-bottom: 30px; }
        .form-group { margin-bottom: 20px; }
        label { display: block; margin-bottom: 5px; color: #666; }
        input[type="password"] { width: 100%; padding: 12px; border: 1px solid #ddd; border-radius: 5px; box-sizing: border-box; }
        button { width: 100%; padding: 12px; background: #007bff; color: white; border: none; border-radius: 5px; cursor: pointer; font-size: 16px; }
        button:hover { background: #0056b3; }
        .error { color: #dc3545; text-align: center; margin-top: 10px; }
    </style>
</head>
<body>
    <div class="login-container">
        <h1>代理管理面板</h1>
        <form method="post">
            <div class="form-group">
                <label>管理员密码:</label>
                <input type="password" name="password" required autofocus>
            </div>
            <button type="submit">登录</button>
            {% if error %}
            <div class="error">{{ error }}</div>
            {% endif %}
        </form>
    </div>
</body>
</html>'''

    # 简化的index.html模板
    index_html = '''<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>代理管理面板</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 0; padding: 20px; background: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background: white; padding: 20px; border-radius: 10px; }
        h1 { color: #333; }
        .info { background: #e7f3ff; padding: 15px; border-radius: 5px; margin: 20px 0; }
        .user-list { margin-top: 20px; }
        table { width: 100%; border-collapse: collapse; }
        th, td { padding: 12px; text-align: left; border-bottom: 1px solid #ddd; }
        th { background: #f8f9fa; }
    </style>
</head>
<body>
    <div class="container">
        <h1>代理管理面板</h1>
        <div class="info">
            <p><strong>服务器:</strong> {{ domain }}</p>
            <p><strong>状态:</strong> 运行中</p>
        </div>
        <div class="user-list">
            <h2>用户列表</h2>
            <p>用户管理功能正在开发中...</p>
        </div>
    </div>
</body>
</html>'''

    # 简化的user_config.html模板
    user_config_html = '''<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>用户配置 - 代理管理</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 0; padding: 20px; background: #f5f5f5; }
        .container { max-width: 800px; margin: 0 auto; background: white; padding: 20px; border-radius: 10px; }
        h1 { color: #333; }
        .config-info { background: #e7f3ff; padding: 15px; border-radius: 5px; margin: 20px 0; }
        pre { background: #f8f9fa; padding: 15px; border-radius: 5px; overflow-x: auto; }
    </style>
</head>
<body>
    <div class="container">
        <h1>用户配置: {{ username }}</h1>
        <div class="config-info">
            <p><strong>服务器:</strong> {{ domain }}</p>
            <p>配置信息正在加载中...</p>
        </div>
    </div>
</body>
</html>'''

    # 保存模板文件
    with open(f'{template_dir}/login.html', 'w', encoding='utf-8') as f:
        f.write(login_html)
    with open(f'{template_dir}/index.html', 'w', encoding='utf-8') as f:
        f.write(index_html)
    with open(f'{template_dir}/user_config.html', 'w', encoding='utf-8') as f:
        f.write(user_config_html)

app = Flask(__name__, template_folder=template_dir)
app.secret_key = os.urandom(24)
QRcode(app)

manager = ProxyManager()


@app.route('/')
def index():
    """主页"""
    if 'logged_in' not in session:
        return render_template('login.html')
    return render_template('index.html', domain=manager.domain)


@app.route('/login', methods=['POST'])
def login():
    """登录验证"""
    data = request.get_json()
    password = data.get('password')

    if manager.verify_admin(password):
        session['logged_in'] = True
        return jsonify({'success': True, 'message': '登录成功'})
    else:
        return jsonify({'success': False, 'message': '密码错误'})


@app.route('/logout')
def logout():
    """退出登录"""
    session.pop('logged_in', None)
    return redirect('/')


@app.route('/api/users')
def get_users():
    """获取用户列表"""
    if 'logged_in' not in session:
        return jsonify({'error': '未登录'}), 401

    users = manager.list_users()
    return jsonify({'users': users})


@app.route('/api/user/<username>/config')
def get_user_config(username):
    """获取用户配置（无需登录，通过密码验证）"""
    try:
        password = request.args.get('password')
        print(f"[API] 获取用户配置请求: username={username}, password={'*' * len(password) if password else 'None'}")

        if not password:
            print("[API] 密码为空")
            return jsonify({'error': '请提供密码'}), 400

        user = manager.get_user(username)
        if not user:
            print(f"[API] 用户不存在: {username}")
            return jsonify({'error': '用户不存在'}), 404

        print(f"[API] 找到用户: {user['username']}")

        if password != user['password']:
            print("[API] 密码错误")
            return jsonify({'error': '密码错误'}), 401

        print("[API] 密码验证通过，正在生成配置...")

        # 生成各种配置链接
        config = {
            'username': user['username'],
            'vless': manager.generate_vless_url(user),
            'vmess': manager.generate_vmess_url(user),
            'trojan': manager.generate_trojan_url(user),
            'ss': manager.generate_ss_url(user),
            'clash': manager.generate_clash_config(user),
            'shadowrocket': manager.generate_shadowrocket_config(user)
        }

        print(f"[API] 配置生成成功，协议数量: {len([k for k, v in config.items() if v and k != 'username'])}")

        return jsonify(config)

    except Exception as e:
        print(f"[API] 错误: {str(e)}")
        import traceback
        traceback.print_exc()
        return jsonify({'error': f'服务器错误: {str(e)}'}), 500


@app.route('/api/user/<username>/qrcode')
def get_qrcode(username):
    """获取用户配置二维码"""
    password = request.args.get('password')
    protocol = request.args.get('protocol', 'vless')  # 支持协议: vless, vmess, trojan, ss
    user = manager.get_user(username)

    if not user:
        return "用户不存在", 404

    if password != user['password']:
        return "密码错误", 401

    # 根据协议类型生成对应的URL
    if protocol == 'vless':
        url = manager.generate_vless_url(user)
    elif protocol == 'vmess':
        url = manager.generate_vmess_url(user)
    elif protocol == 'trojan':
        url = manager.generate_trojan_url(user)
    elif protocol == 'ss':
        url = manager.generate_ss_url(user)
    else:
        return "不支持的协议", 400

    img = qrcode.make(url)
    img_io = io.BytesIO()
    img.save(img_io, 'PNG')
    img_io.seek(0)

    return send_file(img_io, mimetype='image/png')


@app.route('/api/user/add', methods=['POST'])
def add_user():
    """添加用户"""
    if 'logged_in' not in session:
        return jsonify({'error': '未登录'}), 401

    import uuid
    data = request.get_json()

    username = data.get('username')
    traffic_limit = data.get('traffic_limit', 0)

    # 检查用户名是否已存在
    if manager.get_user(username):
        return jsonify({'success': False, 'message': '用户名已存在'})

    # 生成UUID和密码
    user_uuid = str(uuid.uuid4())
    password = base64.b64encode(os.urandom(12)).decode('utf-8')[:16]

    success, message = manager.add_user(username, user_uuid, password, traffic_limit)

    if success:
        return jsonify({
            'success': True,
            'message': message,
            'user': {
                'username': username,
                'uuid': user_uuid,
                'password': password
            }
        })
    else:
        return jsonify({'success': False, 'message': message})


@app.route('/api/user/<username>/delete', methods=['POST'])
def delete_user(username):
    """删除用户"""
    if 'logged_in' not in session:
        return jsonify({'error': '未登录'}), 401

    success, message = manager.delete_user(username)
    return jsonify({'success': success, 'message': message})


@app.route('/api/user/<username>/toggle', methods=['POST'])
def toggle_user(username):
    """切换用户状态"""
    if 'logged_in' not in session:
        return jsonify({'error': '未登录'}), 401

    user = manager.get_user(username)
    if user['enabled']:
        manager.disable_user(username)
        status = 'disabled'
    else:
        manager.enable_user(username)
        status = 'enabled'

    return jsonify({'success': True, 'status': status})


@app.route('/user/<username>')
def user_page(username):
    """用户配置页面"""
    user = manager.get_user(username)
    if not user:
        return "用户不存在", 404

    return render_template('user_config.html',
                         username=username,
                         domain=manager.domain)


@app.route('/config/<username>.yaml')
def clash_config(username):
    """下载Clash配置文件"""
    user = manager.get_user(username)
    if not user:
        return "用户不存在", 404

    config = manager.generate_clash_config(user)
    return send_file(
        io.BytesIO(config.encode()),
        mimetype='text/yaml',
        as_attachment=True,
        download_name=f'clash_{username}.yaml'
    )


if __name__ == '__main__':
    # 模板已在模块导入时创建，这里只需确保目录存在
    template_dir = os.path.expanduser('~/.proxy-manager/templates')
    os.makedirs(template_dir, exist_ok=True)

    # 从配置文件读取Web端口
    web_port = 5080  # 默认端口
    try:
        config_file = os.path.join(CONFIG_PATH, 'install_info.txt')
        if os.path.exists(config_file):
            with open(config_file, 'r') as f:
                for line in f:
                    if 'Web:' in line:
                        web_port = int(line.split(':')[1].strip())
    except:
        pass

    # 启动服务器
    print("🚀 Proxy Manager Web界面启动中...")
    print(f"📋 管理面板: http://0.0.0.0:{web_port}")
    print(f"🔐 用户配置: http://your-ip:{web_port}/user/username")
    app.run(host='0.0.0.0', port=web_port, debug=False)
