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

# 设置模板目录
template_dir = os.path.expanduser('~/.proxy-manager/templates')
os.makedirs(template_dir, exist_ok=True)

# 确保模板文件存在
def ensure_templates_exist():
    """检查并创建必需的模板文件"""
    template_files = ['login.html', 'index.html', 'user_config.html']
    missing_templates = [f for f in template_files if not os.path.exists(os.path.join(template_dir, f))]

    if missing_templates:
        # 如果模板缺失，暂时返回False，稍后在__main__中创建
        return False
    return True

# 先尝试创建模板（如果__main__部分没有运行的话）
if not os.path.exists(os.path.join(template_dir, 'login.html')):
    # 创建基础的login.html模板
    basic_login_html = '''<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>代理管理 - 登录</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: Arial, sans-serif; background: #f5f5f5; display: flex; justify-content: center; align-items: center; min-height: 100vh; }
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

    # 创建基础的index.html模板
    basic_index_html = '''<!DOCTYPE html>
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
    </style>
</head>
<body>
    <div class="container">
        <h1>代理管理面板</h1>
        <div class="info">
            <p><strong>服务器:</strong> {{ domain }}</p>
            <p><strong>状态:</strong> 运行中</p>
        </div>
        <p>用户管理功能正在开发中...</p>
    </div>
</body>
</html>'''

    # 创建基础的user_config.html模板
    basic_user_config_html = '''<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>用户配置 - 代理管理</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 0; padding: 20px; background: #f5f5f5; }
        .container { max-width: 800px; margin: 0 auto; background: white; padding: 20px; border-radius: 10px; }
        h1 { color: #333; }
    </style>
</head>
<body>
    <div class="container">
        <h1>用户配置: {{ username }}</h1>
        <p><strong>服务器:</strong> {{ domain }}</p>
        <p>配置信息正在加载中...</p>
    </div>
</body>
</html>'''

    # 保存基础模板
    with open(os.path.join(template_dir, 'login.html'), 'w', encoding='utf-8') as f:
        f.write(basic_login_html)
    with open(os.path.join(template_dir, 'index.html'), 'w', encoding='utf-8') as f:
        f.write(basic_index_html)
    with open(os.path.join(template_dir, 'user_config.html'), 'w', encoding='utf-8') as f:
        f.write(basic_user_config_html)

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


@app.route('/api/reset-password', methods=['POST'])
def reset_password():
    """重置用户密码API"""
    data = request.get_json()
    username = data.get('username')
    new_password = data.get('new_password')
    current_password = data.get('current_password')

    if not all([username, new_password, current_password]):
        return jsonify({'success': False, 'message': '参数不完整'})

    # 重置密码
    success, message = manager.reset_user_password(username, new_password, current_password)
    return jsonify({'success': success, 'message': message})


@app.route('/api/admin/set-password', methods=['POST'])
def admin_set_password():
    """管理员设置用户密码API"""
    if 'logged_in' not in session:
        return jsonify({'success': False, 'message': '未登录'})

    data = request.get_json()
    username = data.get('username')
    new_password = data.get('new_password')

    if not all([username, new_password]):
        return jsonify({'success': False, 'message': '参数不完整'})

    # 管理员直接设置密码
    success, message = manager.set_user_password(username, new_password)
    return jsonify({'success': success, 'message': message})


@app.route('/config/<username>.yaml')
def clash_config(username):
    """下载Clash配置文件"""
    try:
        user = manager.get_user(username)
        if not user:
            return "用户不存在", 404

        config = manager.generate_clash_config(user)
        # 兼容不同版本的Flask
        try:
            return send_file(
                io.BytesIO(config.encode()),
                mimetype='text/yaml',
                as_attachment=True,
                download_name=f'{username}.yaml'
            )
        except TypeError:
            # 旧版本Flask使用attachment_filename
            return send_file(
                io.BytesIO(config.encode()),
                mimetype='text/yaml',
                as_attachment=True,
                attachment_filename=f'{username}.yaml'
            )
    except Exception as e:
        return f"配置生成失败: {str(e)}", 500


if __name__ == '__main__':
    # 模板目录已在模块导入时创建，这里直接使用
    # template_dir 已在文件开头定义

    # 创建完整的HTML模板（功能更丰富）
    login_html = '''<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>代理管理 - 登录</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }

        @keyframes gradientBG {
            0% { background-position: 0% 50%; }
            50% { background-position: 100% 50%; }
            100% { background-position: 0% 50%; }
        }

        @keyframes fadeInUp {
            from {
                opacity: 0;
                transform: translateY(30px);
            }
            to {
                opacity: 1;
                transform: translateY(0);
            }
        }

        @keyframes shake {
            0%, 100% { transform: translateX(0); }
            10%, 30%, 50%, 70%, 90% { transform: translateX(-5px); }
            20%, 40%, 60%, 80% { transform: translateX(5px); }
        }

        body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
            background: linear-gradient(-45deg, #ee7752, #e73c7e, #23a6d5, #23d5ab);
            background-size: 400% 400%;
            animation: gradientBG 15s ease infinite;
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 20px;
            position: relative;
            overflow: hidden;
        }

        body::before {
            content: '';
            position: absolute;
            top: 0;
            left: 0;
            right: 0;
            bottom: 0;
            background: radial-gradient(circle at 20% 50%, rgba(255, 255, 255, 0.1) 0%, transparent 50%),
                        radial-gradient(circle at 80% 80%, rgba(255, 255, 255, 0.1) 0%, transparent 50%);
            pointer-events: none;
        }

        .login-box {
            background: rgba(255, 255, 255, 0.95);
            backdrop-filter: blur(10px);
            border-radius: 24px;
            padding: 48px;
            box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.25);
            max-width: 420px;
            width: 100%;
            position: relative;
            animation: fadeInUp 0.6s ease-out;
            border: 1px solid rgba(255, 255, 255, 0.2);
        }

        .login-box::before {
            content: '';
            position: absolute;
            top: -2px;
            left: -2px;
            right: -2px;
            bottom: -2px;
            background: linear-gradient(45deg, #ee7752, #e73c7e, #23a6d5, #23d5ab);
            border-radius: 24px;
            z-index: -1;
            opacity: 0.1;
        }

        h1 {
            text-align: center;
            color: #1f2937;
            margin-bottom: 32px;
            font-size: 28px;
            font-weight: 700;
            letter-spacing: -0.025em;
        }

        .form-group {
            margin-bottom: 24px;
        }

        label {
            display: block;
            color: #4b5563;
            margin-bottom: 8px;
            font-weight: 600;
            font-size: 14px;
            letter-spacing: 0.025em;
            text-transform: uppercase;
        }

        input {
            width: 100%;
            padding: 16px 20px;
            border: 2px solid #e5e7eb;
            border-radius: 12px;
            font-size: 16px;
            transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
            background: #f9fafb;
            color: #1f2937;
        }

        input:focus {
            outline: none;
            border-color: #23a6d5;
            background: white;
            box-shadow: 0 0 0 4px rgba(35, 166, 213, 0.1);
            transform: translateY(-1px);
        }

        input::placeholder {
            color: #9ca3af;
        }

        button {
            width: 100%;
            padding: 16px;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            background-size: 200% 200%;
            color: white;
            border: none;
            border-radius: 12px;
            font-size: 16px;
            font-weight: 600;
            cursor: pointer;
            transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
            letter-spacing: 0.025em;
            box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1), 0 2px 4px -1px rgba(0, 0, 0, 0.06);
        }

        button:hover {
            transform: translateY(-2px);
            box-shadow: 0 10px 15px -3px rgba(0, 0, 0, 0.1), 0 4px 6px -2px rgba(0, 0, 0, 0.05);
            background-position: right center;
        }

        button:active {
            transform: translateY(0);
        }

        .message {
            padding: 16px;
            border-radius: 12px;
            margin-bottom: 24px;
            text-align: center;
            font-weight: 500;
            animation: fadeInUp 0.3s ease-out;
        }

        .error {
            background: linear-gradient(135deg, #fee 0%, #fcc 100%);
            color: #991b1b;
            border: 1px solid #fecaca;
            animation: shake 0.5s ease-in-out;
        }

        .success {
            background: linear-gradient(135deg, #d1fae5 0%, #a7f3d0 100%);
            color: #065f46;
            border: 1px solid #a7f3d0;
        }

        @media (max-width: 480px) {
            .login-box {
                padding: 32px 24px;
            }

            h1 {
                font-size: 24px;
            }
        }
    </style>
</head>
<body>
    <div class="login-box">
        <h1>🔐 代理管理登录</h1>
        <div id="message"></div>
        <form id="loginForm">
            <div class="form-group">
                <label>管理员密码</label>
                <input type="password" id="password" placeholder="请输入管理员密码" required autofocus>
            </div>
            <button type="submit">登录</button>
        </form>
    </div>
    <script>
        document.getElementById('loginForm').addEventListener('submit', async (e) => {
            e.preventDefault();
            const password = document.getElementById('password').value;
            const messageDiv = document.getElementById('message');

            try {
                const res = await fetch('/login', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ password })
                });
                const data = await res.json();

                if (data.success) {
                    messageDiv.className = 'message success';
                    messageDiv.textContent = data.message;
                    setTimeout(() => window.location.href = '/', 1000);
                } else {
                    messageDiv.className = 'message error';
                    messageDiv.textContent = data.message;
                }
            } catch (err) {
                messageDiv.className = 'message error';
                messageDiv.textContent = '登录失败，请重试';
            }
        });
    </script>
</body>
</html>'''

    index_html = '''<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>代理管理面板</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            background-size: 400% 400%;
            animation: gradientBG 15s ease infinite;
            padding: 20px;
            min-height: 100vh;
            position: relative;
        }
        body::before {
            content: '';
            position: absolute;
            top: 0;
            left: 0;
            right: 0;
            bottom: 0;
            background: radial-gradient(circle at 20% 50%, rgba(255, 255, 255, 0.1) 0%, transparent 50%),
                        radial-gradient(circle at 80% 80%, rgba(255, 255, 255, 0.1) 0%, transparent 50%);
            pointer-events: none;
        }
        @keyframes gradientBG {
            0% { background-position: 0% 50%; }
            50% { background-position: 100% 50%; }
            100% { background-position: 0% 50%; }
        }
        .header {
            background: rgba(255, 255, 255, 0.95);
            backdrop-filter: blur(10px);
            padding: 24px 32px;
            border-radius: 20px;
            margin-bottom: 24px;
            display: flex;
            justify-content: space-between;
            align-items: center;
            box-shadow: 0 8px 32px rgba(0, 0, 0, 0.1);
            border: 1px solid rgba(255, 255, 255, 0.2);
        }
        .header h1 {
            color: #333;
            font-size: 24px;
        }
        .btn {
            padding: 10px 20px;
            border: none;
            border-radius: 10px;
            cursor: pointer;
            font-weight: 600;
            font-size: 14px;
            transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
            box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
            letter-spacing: 0.025em;
        }
        .btn-primary {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            background-size: 200% 200%;
            color: white;
        }
        .btn-primary:hover {
            background-position: right center;
            transform: translateY(-2px);
            box-shadow: 0 8px 16px rgba(102, 126, 234, 0.3);
        }
        .btn-danger {
            background: linear-gradient(135deg, #f56565 0%, #ed5a5a 100%);
            background-size: 200% 200%;
            color: white;
        }
        .btn-danger:hover {
            background-position: right center;
            transform: translateY(-2px);
            box-shadow: 0 8px 16px rgba(245, 101, 101, 0.3);
        }
        .btn:not(.btn-primary):not(.btn-danger) {
            background: #e2e8f0;
            color: #4a5568;
        }
        .btn:not(.btn-primary):not(.btn-danger):hover {
            background: #cbd5e0;
            transform: translateY(-2px);
            box-shadow: 0 4px 8px rgba(0, 0, 0, 0.1);
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
            position: relative;
        }
        .card {
            background: rgba(255, 255, 255, 0.95);
            backdrop-filter: blur(10px);
            border-radius: 20px;
            padding: 32px;
            margin-bottom: 24px;
            box-shadow: 0 8px 32px rgba(0, 0, 0, 0.1);
            border: 1px solid rgba(255, 255, 255, 0.2);
            transition: transform 0.3s cubic-bezier(0.4, 0, 0.2, 1);
        }
        .card:hover {
            transform: translateY(-4px);
            box-shadow: 0 12px 40px rgba(0, 0, 0, 0.15);
        }
        .card h2 {
            color: #1f2937;
            margin-bottom: 24px;
            font-size: 20px;
            font-weight: 700;
            letter-spacing: -0.025em;
        }
        .add-user-form {
            display: grid;
            grid-template-columns: 2fr 1fr 1fr auto;
            gap: 15px;
            align-items: end;
        }
        .form-group label {
            display: block;
            color: #4a5568;
            margin-bottom: 8px;
            font-size: 14px;
            font-weight: 600;
            letter-spacing: 0.025em;
        }
        .form-group input {
            width: 100%;
            padding: 12px 16px;
            border: 2px solid #e2e8f0;
            border-radius: 10px;
            font-size: 15px;
            transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
            background: #f7fafc;
            color: #1f2937;
        }
        .form-group input:focus {
            outline: none;
            border-color: #667eea;
            background: white;
            box-shadow: 0 0 0 4px rgba(102, 126, 234, 0.1);
            transform: translateY(-1px);
        }
        .form-group input::placeholder {
            color: #a0aec0;
        }
        table {
            width: 100%;
            border-collapse: separate;
            border-spacing: 0;
            overflow: hidden;
            border-radius: 12px;
        }
        th, td {
            padding: 16px;
            text-align: left;
            border-bottom: 1px solid #f0f0f0;
        }
        th {
            background: linear-gradient(135deg, #f8f9fa 0%, #e9ecef 100%);
            color: #495057;
            font-weight: 700;
            font-size: 13px;
            text-transform: uppercase;
            letter-spacing: 0.05em;
        }
        tr:hover td {
            background: rgba(102, 126, 234, 0.05);
        }
        tr:last-child td {
            border-bottom: none;
        }
        .status-badge {
            display: inline-block;
            padding: 6px 16px;
            border-radius: 20px;
            font-size: 12px;
            font-weight: 700;
            letter-spacing: 0.025em;
            text-transform: uppercase;
            box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
        }
        .status-enabled {
            background: linear-gradient(135deg, #48bb78 0%, #38a169 100%);
            color: white;
            box-shadow: 0 2px 8px rgba(72, 187, 120, 0.3);
        }
        .status-disabled {
            background: linear-gradient(135deg, #fc8181 0%, #f56565 100%);
            color: white;
            box-shadow: 0 2px 8px rgba(245, 101, 101, 0.3);
        }
        .config-modal {
            display: none;
            position: fixed;
            top: 0;
            left: 0;
            right: 0;
            bottom: 0;
            background: rgba(0,0,0,0.5);
            z-index: 1000;
            align-items: center;
            justify-content: center;
        }
        .config-modal.active {
            display: flex;
        }
        .modal-content {
            background: white;
            border-radius: 20px;
            padding: 30px;
            max-width: 600px;
            width: 90%;
            max-height: 90vh;
            overflow-y: auto;
        }
        .config-tabs {
            display: flex;
            gap: 10px;
            margin-bottom: 20px;
            border-bottom: 2px solid #f0f0f0;
        }
        .config-tab {
            padding: 10px 20px;
            background: none;
            border: none;
            cursor: pointer;
            color: #666;
            font-weight: 500;
        }
        .config-tab.active {
            color: #667eea;
            border-bottom: 2px solid #667eea;
        }
        .config-url {
            background: #f8f9fa;
            padding: 15px;
            border-radius: 8px;
            word-break: break-all;
            font-family: monospace;
            font-size: 12px;
            margin-bottom: 10px;
        }
        .qrcode-container {
            text-align: center;
            padding: 20px;
            background: #f8f9fa;
            border-radius: 15px;
            margin: 20px 0;
        }
        .copy-btn {
            background: #667eea;
            color: white;
            border: none;
            padding: 8px 15px;
            border-radius: 6px;
            cursor: pointer;
            font-size: 14px;
        }

        /* 消息模态框样式 */
        .message-modal {
            display: none;
            position: fixed;
            top: 0;
            left: 0;
            right: 0;
            bottom: 0;
            background: rgba(0,0,0,0.5);
            z-index: 2000;
            align-items: center;
            justify-content: center;
        }
        .message-modal.active {
            display: flex;
        }
        .message-modal-content {
            background: white;
            border-radius: 20px;
            padding: 30px;
            max-width: 500px;
            width: 90%;
            box-shadow: 0 20px 60px rgba(0,0,0,0.3);
            animation: slideIn 0.3s ease-out;
        }
        @keyframes slideIn {
            from {
                transform: translateY(-50px);
                opacity: 0;
            }
            to {
                transform: translateY(0);
                opacity: 1;
            }
        }
        .message-modal-header {
            display: flex;
            align-items: center;
            margin-bottom: 20px;
            padding-bottom: 15px;
            border-bottom: 2px solid #f0f0f0;
        }
        .message-modal-icon {
            font-size: 32px;
            margin-right: 15px;
        }
        .message-modal-title {
            font-size: 20px;
            font-weight: 600;
            color: #333;
            flex: 1;
        }
        .message-modal-body {
            background: #f8f9fa;
            padding: 20px;
            border-radius: 12px;
            margin-bottom: 20px;
            max-height: 300px;
            overflow-y: auto;
            white-space: pre-wrap;
            word-break: break-word;
            font-family: 'Courier New', monospace;
            font-size: 14px;
            line-height: 1.6;
            color: #333;
            user-select: text;
            -webkit-user-select: text;
            -moz-user-select: text;
            -ms-user-select: text;
        }
        .message-modal-body.success {
            background: #d4edda;
            color: #155724;
            border: 1px solid #c3e6cb;
        }
        .message-modal-body.error {
            background: #f8d7da;
            color: #721c24;
            border: 1px solid #f5c6cb;
        }
        .message-modal-body.info {
            background: #d1ecf1;
            color: #0c5460;
            border: 1px solid #bee5eb;
        }
        .message-modal-footer {
            display: flex;
            gap: 10px;
            justify-content: flex-end;
        }
        .message-modal-btn {
            padding: 12px 24px;
            border: none;
            border-radius: 10px;
            cursor: pointer;
            font-size: 16px;
            font-weight: 500;
            transition: all 0.2s;
        }
        .message-modal-btn.primary {
            background: #667eea;
            color: white;
        }
        .message-modal-btn.primary:hover {
            background: #5568d3;
            transform: translateY(-2px);
        }
        .message-modal-btn.secondary {
            background: #e0e0e0;
            color: #333;
        }
        .message-modal-btn.secondary:hover {
            background: #d0d0d0;
        }
        .message-modal-copy-btn {
            background: #28a745;
            color: white;
            font-size: 14px;
            padding: 8px 16px;
        }
        .message-modal-copy-btn:hover {
            background: #218838;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🚀 代理管理面板</h1>
            <button class="btn btn-danger" onclick="logout()">退出登录</button>
        </div>

        <div class="card">
            <h2>添加用户</h2>
            <form class="add-user-form" id="addUserForm">
                <div class="form-group">
                    <label>用户名</label>
                    <input type="text" id="username" placeholder="输入用户名" required>
                </div>
                <div class="form-group">
                    <label>流量限制(GB)</label>
                    <input type="number" id="trafficLimit" placeholder="0为无限" value="0" min="0">
                </div>
                <div></div>
                <button type="submit" class="btn btn-primary">添加用户</button>
            </form>
        </div>

        <div class="card">
            <h2>用户列表</h2>
            <table>
                <thead>
                    <tr>
                        <th>用户名</th>
                        <th>UUID</th>
                        <th>流量使用</th>
                        <th>状态</th>
                        <th>操作</th>
                    </tr>
                </thead>
                <tbody id="userTable">
                    <tr><td colspan="5" style="text-align:center;">加载中...</td></tr>
                </tbody>
            </table>
        </div>
    </div>

    <!-- 消息模态框 -->
    <div class="message-modal" id="messageModal">
        <div class="message-modal-content">
            <div class="message-modal-header">
                <span class="message-modal-icon" id="messageIcon">ℹ️</span>
                <h3 class="message-modal-title" id="messageTitle">提示</h3>
            </div>
            <div class="message-modal-body" id="messageBody"></div>
            <div class="message-modal-footer">
                <button class="message-modal-btn message-modal-copy-btn" id="messageCopyBtn" onclick="copyMessage()" style="display: none;">📋 复制内容</button>
                <button class="message-modal-btn primary" onclick="closeMessageModal()">确定</button>
            </div>
        </div>
    </div>

    <div class="config-modal" id="configModal">
        <div class="modal-content">
            <h2 id="modalTitle">用户配置</h2>
            <div class="config-tabs">
                <button class="config-tab active" data-tab="vless">VLESS</button>
                <button class="config-tab" data-tab="vmess">VMESS</button>
                <button class="config-tab" data-tab="trojan">Trojan</button>
                <button class="config-tab" data-tab="ss">Shadowsocks</button>
                <button class="config-tab" data-tab="clash">Clash</button>
            </div>

            <div id="tabContent">
                <div class="config-url" id="configUrl"></div>
                <button class="copy-btn" onclick="copyConfig()">复制链接</button>

                <div class="qrcode-container">
                    <h3>扫描二维码</h3>
                    <div id="qrcode"></div>
                </div>
            </div>

            <div style="text-align: center; margin-top: 20px;">
                <button class="btn" onclick="closeModal()">关闭</button>
            </div>
        </div>
    </div>

    <!-- QRCode 库 - 国内高速CDN源 (按速度排序) -->
    <script src="https://lib.baomitu.com/qrcodejs/1.0.0/qrcode.min.js"></script>
    <script>
        // 如果主CDN加载失败，自动尝试备用源
        if (typeof QRCode === 'undefined') {
            console.log('主CDN加载失败，尝试备用源...');
            var script = document.createElement('script');
            script.src = 'https://cdn.bootcdn.net/ajax/libs/qrcodejs/1.0.0/qrcode.min.js';
            script.onerror = function() {
                console.log('备用源1加载失败，尝试备用源2...');
                var script2 = document.createElement('script');
                script2.src = 'https://unpkg.com/qrcode@1.5.3/build/qrcode.min.js';
                document.head.appendChild(script2);
            };
            document.head.appendChild(script);
        } else {
            console.log('✅ QRCode库加载成功');
        }
    </script>
    <script>
        // 消息模态框函数
        function showMessage(title, message, type = 'info', showCopy = false) {
            const modal = document.getElementById('messageModal');
            const icon = document.getElementById('messageIcon');
            const titleEl = document.getElementById('messageTitle');
            const body = document.getElementById('messageBody');
            const copyBtn = document.getElementById('messageCopyBtn');

            // 设置图标
            const icons = {
                'success': '✅',
                'error': '❌',
                'info': 'ℹ️',
                'warning': '⚠️'
            };
            icon.textContent = icons[type] || 'ℹ️';

            // 设置标题和内容
            titleEl.textContent = title;
            body.textContent = message;

            // 设置样式类
            body.className = 'message-modal-body ' + type;

            // 显示/隐藏复制按钮
            copyBtn.style.display = showCopy ? 'block' : 'none';

            // 显示模态框
            modal.classList.add('active');
        }

        function closeMessageModal() {
            const modal = document.getElementById('messageModal');
            modal.classList.remove('active');
        }

        function copyMessage() {
            const body = document.getElementById('messageBody');
            const text = body.textContent;

            // 尝试使用现代 clipboard API
            if (navigator.clipboard && navigator.clipboard.writeText) {
                navigator.clipboard.writeText(text).then(() => {
                    showMessage('复制成功', '内容已复制到剪贴板', 'success');
                }).catch(err => {
                    console.error('复制失败:', err);
                    fallbackCopy(text);
                });
            } else {
                fallbackCopy(text);
            }
        }

        function fallbackCopy(text) {
            const textarea = document.createElement('textarea');
            textarea.value = text;
            textarea.style.position = 'fixed';
            textarea.style.opacity = '0';
            document.body.appendChild(textarea);
            textarea.select();
            try {
                document.execCommand('copy');
                showMessage('复制成功', '内容已复制到剪贴板', 'success');
            } catch (err) {
                console.error('复制失败:', err);
                showMessage('复制失败', '无法自动复制，请手动选择内容复制', 'error');
            }
            document.body.removeChild(textarea);
        }

        // 键盘事件：ESC键关闭模态框
        document.addEventListener('keydown', function(e) {
            if (e.key === 'Escape') {
                closeMessageModal();
            }
        });

        let currentUsers = [];

        async function loadUsers() {
            const res = await fetch('/api/users');
            const data = await res.json();
            currentUsers = data.users;
            renderUsers();
        }

        function renderUsers() {
            const tbody = document.getElementById('userTable');
            tbody.innerHTML = currentUsers.map(user => `
                <tr>
                    <td><strong>${user.username}</strong></td>
                    <td style="font-family: monospace; font-size: 12px;">${user.uuid.substring(0, 8)}...</td>
                    <td>${user.traffic}</td>
                    <td><span class="status-badge ${user.status === '启用' ? 'status-enabled' : 'status-disabled'}">${user.status}</span></td>
                    <td>
                        <button class="btn btn-primary" onclick="showConfig('${user.username}')">配置</button>
                        <button class="btn" onclick="resetUserPassword('${user.username}')">重置密码</button>
                        <button class="btn" onclick="toggleUser('${user.username}')">切换</button>
                        <button class="btn btn-danger" onclick="deleteUser('${user.username}')">删除</button>
                    </td>
                </tr>
            `).join('');
        }

        document.getElementById('addUserForm').addEventListener('submit', async (e) => {
            e.preventDefault();
            const username = document.getElementById('username').value;
            const trafficLimit = document.getElementById('trafficLimit').value;

            const res = await fetch('/api/user/add', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ username, traffic_limit: parseInt(trafficLimit) })
            });
            const data = await res.json();

            if (data.success) {
                const message = `用户添加成功！\n\n用户名: ${data.user.username}\n密码: ${data.user.password}\n\n请保存此密码！`;
                showMessage('添加成功', message, 'success', true);
                document.getElementById('addUserForm').reset();
                loadUsers();
            } else {
                showMessage('添加失败', data.message, 'error');
            }
        });

        let currentConfig = {};

        async function showConfig(username) {
            const user = currentUsers.find(u => u.username === username);
            if (!user) {
                showMessage('错误', '用户不存在', 'error');
                return;
            }

            const password = prompt('请输入用户密码:');
            if (!password) return;

            try {
                console.log(`正在获取用户 ${username} 的配置...`);

                const res = await fetch(`/api/user/${username}/config?password=${password}`);

                console.log(`API响应状态: ${res.status}`);

                if (!res.ok) {
                    throw new Error(`HTTP ${res.status}: ${res.statusText}`);
                }

                const data = await res.json();

                console.log('配置数据:', data);

                if (data.error) {
                    showMessage('错误', data.error, 'error');
                    return;
                }

                if (!data.vless && !data.vmess && !data.trojan && !data.ss) {
                    showMessage('警告', '配置数据为空，请联系管理员', 'warning');
                    return;
                }

                currentConfig = data;
                document.getElementById('modalTitle').textContent = `配置 - ${username}`;
                showTab('vless');
                document.getElementById('configModal').classList.add('active');

                console.log('配置模态框已显示');

            } catch (error) {
                console.error('获取配置失败:', error);
                const errorMsg = `获取配置失败: ${error.message}\n\n请检查:\n1. 网络连接\n2. 服务器状态\n3. 用户密码是否正确`;
                showMessage('获取配置失败', errorMsg, 'error');
            }
        }

        function showTab(tab) {
            document.querySelectorAll('.config-tab').forEach(t => t.classList.remove('active'));
            document.querySelector(`[data-tab="${tab}"]`).classList.add('active');

            const urls = {
                vless: currentConfig.vless,
                vmess: currentConfig.vmess,
                trojan: currentConfig.trojan,
                ss: currentConfig.ss,
                clash: '配置文件格式，请使用下方链接'
            };

            document.getElementById('configUrl').textContent = urls[tab] || '暂不支持';

            // 生成二维码
            if (tab !== 'clash') {
                const qrcodeContainer = document.getElementById('qrcode');
                qrcodeContainer.innerHTML = ''; // 清空容器

                // 创建新的容器元素
                const qrElement = document.createElement('div');
                qrcodeContainer.appendChild(qrElement);

                // 使用qrcodejs库的正确API
                try {
                    new QRCode(qrElement, {
                        text: urls[tab],
                        width: 200,
                        height: 200,
                        colorDark: '#000000',
                        colorLight: '#ffffff',
                        correctLevel: QRCode.CorrectLevel.L
                    });
                } catch (error) {
                    console.error('二维码生成失败:', error);
                    qrcodeContainer.innerHTML = '<p style="color: #f56565;">二维码生成失败，请使用复制链接功能</p>';
                }
            } else {
                document.getElementById('qrcode').innerHTML = '<a href="/config/' + currentConfig.username + '.yaml" class="btn btn-primary">下载Clash配置</a>';
            }
        }

        document.querySelectorAll('.config-tab').forEach(tab => {
            tab.addEventListener('click', () => showTab(tab.dataset.tab));
        });

        function copyConfig() {
            const text = document.getElementById('configUrl').textContent;
            
            // 尝试使用现代 clipboard API
            if (navigator.clipboard && navigator.clipboard.writeText) {
                navigator.clipboard.writeText(text).then(() => {
                    showMessage('复制成功', '配置链接已复制到剪贴板', 'success');
                }).catch(err => {
                    console.error('复制失败:', err);
                    fallbackCopy(text);
                });
            } else {
                // 降级到传统方法
                fallbackCopy(text);
            }
        }

        function fallbackCopy(text) {
            const textarea = document.createElement('textarea');
            textarea.value = text;
            textarea.style.position = 'fixed';
            textarea.style.opacity = '0';
            document.body.appendChild(textarea);
            textarea.select();
            try {
                document.execCommand('copy');
                showMessage('复制成功', '配置链接已复制到剪贴板', 'success');
            } catch (err) {
                console.error('复制失败:', err);
                showMessage('复制失败', '无法自动复制，请手动选择内容复制', 'error');
            }
            document.body.removeChild(textarea);
        }

        function closeModal() {
            document.getElementById('configModal').classList.remove('active');
        }

        async function toggleUser(username) {
            await fetch(`/api/user/${username}/toggle`, { method: 'POST' });
            loadUsers();
        }

        async function deleteUser(username) {
            if (!confirm('确定要删除用户 ' + username + ' 吗？')) return;
            await fetch(`/api/user/${username}/delete`, { method: 'POST' });
            loadUsers();
        }

        async function resetUserPassword(username) {
            const newPassword = prompt('请输入用户 ' + username + ' 的新密码:');
            if (!newPassword) return;

            if (newPassword.length < 6) {
                showMessage('密码错误', '密码长度至少为6位', 'error');
                return;
            }

            try {
                const res = await fetch('/api/admin/set-password', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ username, new_password: newPassword })
                });

                const data = await res.json();

                if (data.success) {
                    showMessage('密码设置成功', '用户 ' + username + ' 的密码已成功修改', 'success');
                } else {
                    showMessage('密码设置失败', data.message, 'error');
                }
            } catch (error) {
                console.error('密码设置错误:', error);
                showMessage('密码设置失败', '网络错误，请稍后重试', 'error');
            }
        }

        function logout() {
            if (confirm('确定要退出登录吗？')) {
                window.location.href = '/logout';
            }
        }

        loadUsers();
    </script>
</body>
</html>'''

    user_config_html = '''<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>代理配置 - {{ username }}</title>
    <style>
        @keyframes gradientBG {
            0% { background-position: 0% 50%; }
            50% { background-position: 100% 50%; }
            100% { background-position: 0% 50%; }
        }

        @keyframes fadeInUp {
            from {
                opacity: 0;
                transform: translateY(30px);
            }
            to {
                opacity: 1;
                transform: translateY(0);
            }
        }

        @keyframes pulse {
            0%, 100% { transform: scale(1); }
            50% { transform: scale(1.05); }
        }

        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
            background: linear-gradient(-45deg, #ee7752, #e73c7e, #23a6d5, #23d5ab);
            background-size: 400% 400%;
            animation: gradientBG 15s ease infinite;
            min-height: 100vh;
            padding: 20px;
            position: relative;
        }
        body::before {
            content: '';
            position: absolute;
            top: 0;
            left: 0;
            right: 0;
            bottom: 0;
            background: radial-gradient(circle at 20% 50%, rgba(255, 255, 255, 0.1) 0%, transparent 50%),
                        radial-gradient(circle at 80% 80%, rgba(255, 255, 255, 0.1) 0%, transparent 50%);
            pointer-events: none;
        }
        .container {
            max-width: 700px;
            margin: 0 auto;
            background: rgba(255, 255, 255, 0.95);
            backdrop-filter: blur(10px);
            border-radius: 24px;
            padding: 48px;
            box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.25);
            position: relative;
            animation: fadeInUp 0.6s ease-out;
            border: 1px solid rgba(255, 255, 255, 0.2);
        }
        .container::before {
            content: '';
            position: absolute;
            top: -2px;
            left: -2px;
            right: -2px;
            bottom: -2px;
            background: linear-gradient(45deg, #ee7752, #e73c7e, #23a6d5, #23d5ab);
            border-radius: 24px;
            z-index: -1;
            opacity: 0.1;
        }
        h1 {
            text-align: center;
            color: #1f2937;
            margin-bottom: 32px;
            font-size: 28px;
            font-weight: 700;
            letter-spacing: -0.025em;
        }
        .password-form {
            margin-bottom: 32px;
        }
        .password-form input {
            width: 100%;
            padding: 16px 20px;
            border: 2px solid #e5e7eb;
            border-radius: 12px;
            font-size: 16px;
            margin-bottom: 16px;
            transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
            background: #f9fafb;
            color: #1f2937;
        }
        .password-form input:focus {
            outline: none;
            border-color: #23a6d5;
            background: white;
            box-shadow: 0 0 0 4px rgba(35, 166, 213, 0.1);
            transform: translateY(-1px);
        }
        .btn {
            width: 100%;
            padding: 16px;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            background-size: 200% 200%;
            color: white;
            border: none;
            border-radius: 12px;
            font-size: 16px;
            font-weight: 600;
            cursor: pointer;
            transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
            box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1), 0 2px 4px -1px rgba(0, 0, 0, 0.06);
        }
        .btn:hover {
            transform: translateY(-2px);
            box-shadow: 0 10px 15px -3px rgba(0, 0, 0, 0.1), 0 4px 6px -2px rgba(0, 0, 0, 0.05);
            background-position: right center;
        }
        .config-content {
            display: none;
        }
        .config-content.active {
            display: block;
            animation: fadeInUp 0.4s ease-out;
        }
        .tabs {
            display: flex;
            gap: 8px;
            margin-bottom: 24px;
            border-bottom: 2px solid #f0f0f0;
            overflow-x: auto;
        }
        .tab {
            flex: 1;
            padding: 12px 16px;
            background: none;
            border: none;
            cursor: pointer;
            color: #6b7280;
            font-weight: 600;
            font-size: 14px;
            transition: all 0.3s;
            border-bottom: 2px solid transparent;
            margin-bottom: -2px;
            white-space: nowrap;
        }
        .tab:hover {
            color: #23a6d5;
        }
        .tab.active {
            color: #23a6d5;
            border-bottom-color: #23a6d5;
        }
        .config-box {
            background: #f8f9fa;
            padding: 20px;
            border-radius: 12px;
            word-break: break-all;
            font-family: 'Courier New', monospace;
            font-size: 13px;
            margin-bottom: 16px;
            border: 1px solid #e5e7eb;
            color: #374151;
            max-height: 200px;
            overflow-y: auto;
        }
        .qrcode-box {
            text-align: center;
            padding: 32px 24px;
            background: linear-gradient(135deg, #f8f9fa 0%, #e9ecef 100%);
            border-radius: 16px;
            margin: 24px 0;
            min-height: 350px;
            display: flex;
            flex-direction: column;
            align-items: center;
            justify-content: center;
            border: 1px solid #dee2e6;
        }
        .qrcode-box canvas {
            max-width: 100%;
            height: auto;
            border: 8px solid white;
            border-radius: 12px;
            box-shadow: 0 10px 25px rgba(0,0,0,0.1);
            transition: transform 0.3s cubic-bezier(0.4, 0, 0.2, 1);
        }
        .qrcode-box canvas:hover {
            transform: scale(1.02);
        }
        .qrcode-box h3 {
            margin-bottom: 24px;
            color: #1f2937;
            font-size: 18px;
            font-weight: 700;
        }
        .copy-btn {
            background: #23a6d5;
            color: white;
            border: none;
            padding: 12px 24px;
            border-radius: 10px;
            cursor: pointer;
            width: 100%;
            font-size: 15px;
            font-weight: 600;
            transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
            box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
        }
        .copy-btn:hover {
            background: #1e9bbb;
            transform: translateY(-1px);
            box-shadow: 0 4px 8px rgba(0, 0, 0, 0.15);
        }
        .message-modal {
            display: none;
            position: fixed;
            top: 0;
            left: 0;
            right: 0;
            bottom: 0;
            background: rgba(0,0,0,0.6);
            backdrop-filter: blur(4px);
            z-index: 2000;
            align-items: center;
            justify-content: center;
        }
        .message-modal.active {
            display: flex;
        }
        .message-modal-content {
            background: white;
            border-radius: 24px;
            padding: 32px;
            max-width: 500px;
            width: 90%;
            box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.25);
            animation: fadeInUp 0.3s ease-out;
            border: 1px solid rgba(255, 255, 255, 0.2);
        }
        .message-modal-header {
            display: flex;
            align-items: center;
            margin-bottom: 24px;
            padding-bottom: 16px;
            border-bottom: 2px solid #f0f0f0;
        }
        .message-modal-icon {
            font-size: 32px;
            margin-right: 16px;
        }
        .message-modal-title {
            font-size: 20px;
            font-weight: 700;
            color: #1f2937;
            flex: 1;
        }
        .message-modal-body {
            background: #f8f9fa;
            padding: 20px;
            border-radius: 12px;
            margin-bottom: 24px;
            max-height: 300px;
            overflow-y: auto;
            white-space: pre-wrap;
            word-break: break-word;
            font-family: 'Courier New', monospace;
            font-size: 14px;
            line-height: 1.6;
            color: #374151;
            user-select: text;
        }
        .message-modal-body.success {
            background: #d1fae5;
            color: #065f46;
            border: 1px solid #a7f3d0;
        }
        .message-modal-body.error {
            background: #fee2e2;
            color: #991b1b;
            border: 1px solid #fecaca;
        }
        .message-modal-body.info {
            background: #dbeafe;
            color: #1e40af;
            border: 1px solid #bfdbfe;
        }
        .message-modal-footer {
            display: flex;
            gap: 12px;
            justify-content: flex-end;
        }
        .message-modal-btn {
            padding: 12px 24px;
            border: none;
            border-radius: 10px;
            cursor: pointer;
            font-size: 16px;
            font-weight: 600;
            transition: all 0.3s;
        }
        .message-modal-btn.primary {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
        }
        .message-modal-btn.primary:hover {
            transform: translateY(-2px);
            box-shadow: 0 4px 12px rgba(102, 126, 234, 0.4);
        }
        .message-modal-copy-btn {
            background: #10b981;
            color: white;
            font-size: 14px;
            padding: 12px 20px;
        }
        .message-modal-copy-btn:hover {
            background: #059669;
        }
        @media (max-width: 640px) {
            .container {
                padding: 32px 24px;
            }
            .tabs {
                flex-wrap: wrap;
            }
            .tab {
                flex: 1 1 calc(50% - 4px);
            }
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 代理配置下载</h1>
        <p style="text-align: center; color: #6b7280; margin-bottom: 32px; font-size: 14px;">请输入您的用户密码以获取配置</p>

        <div class="password-form" id="passwordForm">
            <input type="password" id="password" placeholder="请输入用户密码" autofocus>
            <button class="btn" onclick="loadConfig()">查看配置</button>
            <div id="message" style="margin-top: 16px; text-align: center;"></div>
        </div>

        <div class="config-content" id="configContent">
            <div class="tabs">
                <button class="tab active">VLESS</button>
                <button class="tab">VMESS</button>
                <button class="tab">Trojan</button>
                <button class="tab">Shadowsocks</button>
                <button class="tab">Shadowrocket</button>
                <button class="tab">Clash</button>
            </div>

            <div id="tabContent">
                <div class="config-box" id="configUrl"></div>
                <button class="copy-btn" onclick="copyConfig()">📋 复制链接</button>

                <div class="qrcode-box">
                    <h3>📱 扫描二维码导入</h3>
                    <div id="qrcode"></div>
                </div>

                <div style="margin-top: 32px; padding-top: 24px; border-top: 2px solid #f0f0f0;">
                    <h3 style="text-align: center; color: #1f2937; margin-bottom: 16px; font-size: 18px;">🔐 密码管理</h3>
                    <div style="max-width: 400px; margin: 0 auto;">
                        <div style="margin-bottom: 12px;">
                            <label style="display: block; color: #6b7280; margin-bottom: 8px; font-size: 14px; font-weight: 600;">当前密码</label>
                            <input type="password" id="currentPassword" placeholder="输入当前密码" style="width: 100%; padding: 12px; border: 2px solid #e5e7eb; border-radius: 8px; font-size: 14px;">
                        </div>
                        <div style="margin-bottom: 12px;">
                            <label style="display: block; color: #6b7280; margin-bottom: 8px; font-size: 14px; font-weight: 600;">新密码</label>
                            <input type="password" id="newPassword" placeholder="输入新密码" style="width: 100%; padding: 12px; border: 2px solid #e5e7eb; border-radius: 8px; font-size: 14px;">
                        </div>
                        <div style="margin-bottom: 16px;">
                            <label style="display: block; color: #6b7280; margin-bottom: 8px; font-size: 14px; font-weight: 600;">确认新密码</label>
                            <input type="password" id="confirmPassword" placeholder="再次输入新密码" style="width: 100%; padding: 12px; border: 2px solid #e5e7eb; border-radius: 8px; font-size: 14px;">
                        </div>
                        <button onclick="resetPassword()" style="width: 100%; padding: 12px; background: linear-gradient(135deg, #f59e0b 0%, #d97706 100%); color: white; border: none; border-radius: 8px; font-size: 15px; font-weight: 600; cursor: pointer; transition: all 0.3s;">
                            🔄 重置密码
                        </button>
                    </div>
                </div>
            </div>
        </div>
    </div>

    <!-- 消息模态框 -->
    <div class="message-modal" id="messageModal">
        <div class="message-modal-content">
            <div class="message-modal-header">
                <span class="message-modal-icon" id="messageIcon">ℹ️</span>
                <h3 class="message-modal-title" id="messageTitle">提示</h3>
            </div>
            <div class="message-modal-body" id="messageBody"></div>
            <div class="message-modal-footer">
                <button class="message-modal-btn message-modal-copy-btn" id="messageCopyBtn" onclick="copyMessage()" style="display: none;">📋 复制内容</button>
                <button class="message-modal-btn primary" onclick="closeMessageModal()">确定</button>
            </div>
        </div>
    </div>

    <!-- QRCode 库 -->
    <script src="https://lib.baomitu.com/qrcodejs/1.0.0/qrcode.min.js"></script>
    <script>
        // 消息模态框函数
        function showMessage(title, message, type = 'info', showCopy = false) {
            const modal = document.getElementById('messageModal');
            const icon = document.getElementById('messageIcon');
            const titleEl = document.getElementById('messageTitle');
            const body = document.getElementById('messageBody');
            const copyBtn = document.getElementById('messageCopyBtn');

            // 设置图标
            const icons = {
                'success': '✅',
                'error': '❌',
                'info': 'ℹ️',
                'warning': '⚠️'
            };
            icon.textContent = icons[type] || 'ℹ️';

            // 设置标题和内容
            titleEl.textContent = title;
            body.textContent = message;

            // 设置样式类
            body.className = 'message-modal-body ' + type;

            // 显示/隐藏复制按钮
            copyBtn.style.display = showCopy ? 'block' : 'none';

            // 显示模态框
            modal.classList.add('active');
        }

        function closeMessageModal() {
            const modal = document.getElementById('messageModal');
            modal.classList.remove('active');
        }

        function copyMessage() {
            const body = document.getElementById('messageBody');
            const text = body.textContent;

            // 尝试使用现代 clipboard API
            if (navigator.clipboard && navigator.clipboard.writeText) {
                navigator.clipboard.writeText(text).then(() => {
                    showMessage('复制成功', '内容已复制到剪贴板', 'success');
                }).catch(err => {
                    console.error('复制失败:', err);
                    fallbackCopy(text);
                });
            } else {
                fallbackCopy(text);
            }
        }

        function fallbackCopy(text) {
            const textarea = document.createElement('textarea');
            textarea.value = text;
            textarea.style.position = 'fixed';
            textarea.style.opacity = '0';
            document.body.appendChild(textarea);
            textarea.select();
            try {
                document.execCommand('copy');
                showMessage('复制成功', '内容已复制到剪贴板', 'success');
            } catch (err) {
                console.error('复制失败:', err);
                showMessage('复制失败', '无法自动复制，请手动选择内容复制', 'error');
            }
            document.body.removeChild(textarea);
        }

        // 键盘事件：ESC键关闭模态框
        document.addEventListener('keydown', function(e) {
            if (e.key === 'Escape') {
                closeMessageModal();
            }
        });

        // 如果主CDN加载失败，自动尝试备用源
        if (typeof QRCode === 'undefined') {
            console.log('主CDN加载失败，尝试备用源...');
            var script = document.createElement('script');
            script.src = 'https://cdn.bootcdn.net/ajax/libs/qrcodejs/1.0.0/qrcode.min.js';
            script.onerror = function() {
                console.log('备用源1加载失败，尝试备用源2...');
                var script2 = document.createElement('script');
                script2.src = 'https://unpkg.com/qrcode@1.5.3/build/qrcode.min.js';
                document.head.appendChild(script2);
            };
            document.head.appendChild(script);
        } else {
            console.log('✅ QRCode库加载成功');
        }
    </script>
    <script>
        let currentConfig = {};
        let qrcodeLoaded = false;

        // 检查QRCode库是否加载
        function checkQRCode() {
            if (typeof QRCode !== 'undefined') {
                qrcodeLoaded = true;
                console.log('✅ QRCode库已加载');
            } else {
                console.error('❌ QRCode库未加载');
            }
            return qrcodeLoaded;
        }

        // 等待QRCode库加载完成
        function waitForQRCode(callback, maxAttempts = 50) {
            let attempts = 0;
            const interval = setInterval(() => {
                attempts++;
                if (typeof QRCode !== 'undefined' || attempts >= maxAttempts) {
                    clearInterval(interval);
                    if (typeof QRCode !== 'undefined') {
                        qrcodeLoaded = true;
                        callback();
                    } else {
                        console.error('QRCode库加载超时');
                    }
                }
            }, 100);
        }

        async function loadConfig() {
            const password = document.getElementById('password').value;
            const messageDiv = document.getElementById('message');

            try {
                const res = await fetch('/api/user/{{ username }}/config?password=' + password);
                const data = await res.json();

                if (data.error) {
                    messageDiv.innerHTML = '<span style="color: #f56565;">' + data.error + '</span>';
                    return;
                }

                currentConfig = data;
                document.getElementById('passwordForm').style.display = 'none';
                document.getElementById('configContent').classList.add('active');
                
                // 等待QRCode库加载完成后再显示配置
                waitForQRCode(() => {
                    showTab('vless');
                });
            } catch (err) {
                messageDiv.innerHTML = '<span style="color: #f56565;">加载失败，请重试</span>';
            }
        }

        function showTab(tab, clickedTab = null) {
            // 移除所有active状态
            document.querySelectorAll('.tab').forEach(t => t.classList.remove('active'));

            // 添加active状态
            if (clickedTab) {
                clickedTab.classList.add('active');
            } else {
                // 根据tab名称找到对应的按钮
                const tabIndex = {'vless': 0, 'vmess': 1, 'trojan': 2, 'ss': 3, 'shadowrocket': 4, 'clash': 5}[tab] ?? 0;
                document.querySelectorAll('.tab')[tabIndex]?.classList.add('active');
            }

            const urls = {
                vless: currentConfig.vless,
                vmess: currentConfig.vmess,
                trojan: currentConfig.trojan,
                ss: currentConfig.ss,
                shadowrocket: currentConfig.shadowrocket || currentConfig.vless,
                clash: '配置文件，请下载使用'
            };

            // 显示配置链接
            const configUrlDiv = document.getElementById('configUrl');
            if (configUrlDiv) {
                configUrlDiv.textContent = urls[tab] || '暂不支持';
            }

            // 生成二维码
            const qrcodeDiv = document.getElementById('qrcode');
            if (qrcodeDiv) {
                if (tab === 'clash') {
                    // Clash配置显示下载链接
                    qrcodeDiv.innerHTML = '<a href="/config/{{ username }}.yaml" style="display: block; padding: 15px; background: #667eea; color: white; text-decoration: none; border-radius: 10px; margin-top: 10px;">下载 Clash 配置文件</a>';
                } else if (urls[tab]) {
                    // 生成二维码
                    qrcodeDiv.innerHTML = '<p style="color: #666; margin-bottom: 10px;">正在生成二维码...</p>';

                    // 检查链接长度，VMESS等长链接不适合生成二维码
                    const urlLength = urls[tab].length;
                    const isVmess = tab === 'vmess';

                    if (isVmess || urlLength > 800) {
                        // VMESS链接或过长链接，不生成二维码
                        qrcodeDiv.innerHTML = '<div style="text-align: center; padding: 20px;"><p style="color: #666; margin-bottom: 10px;">⚠️ ' + (isVmess ? 'VMESS' : '链接') + '过长，不适合生成二维码</p><p style="color: #999; font-size: 14px;">请使用下方按钮复制链接</p></div>';
                    } else if (typeof QRCode === 'undefined') {
                        qrcodeDiv.innerHTML = '<p style="color: #f56565;">二维码库未加载，请刷新页面重试</p>';
                        return;
                    }
                    if (typeof QRCode === 'undefined') {
                        qrcodeDiv.innerHTML = '<p style="color: #f56565;">二维码库加载中，请稍后刷新页面重试</p>';
                        console.error('QRCode库未加载');
                        return;
                    }

                    try {
                        // 清空二维码容器
                        qrcodeDiv.innerHTML = '';

                        // 创建一个新的容器元素
                        const qrContainer = document.createElement('div');
                        qrcodeDiv.appendChild(qrContainer);

                        // 使用 qrcodejs 库的 API
                        if (typeof QRCode !== 'undefined') {
                            new QRCode(qrContainer, {
                                text: urls[tab],
                                width: 250,
                                height: 250,
                                colorDark: '#000000',
                                colorLight: '#ffffff',
                                correctLevel: QRCode.CorrectLevel.L
                            });
                            console.log('二维码生成成功');
                        } else {
                            qrcodeDiv.innerHTML = '<p style="color: #f56565;">二维码库未加载，请刷新页面重试</p>';
                        }
                    } catch (e) {
                        console.error('二维码生成异常:', e);
qrcodeDiv.innerHTML = '<div style="text-align: center; padding: 20px;"><p style="color: #f56565;">❌ 二维码生成失败</p><p style="color: #999; font-size: 14px; margin-top: 10px;">链接过长或不支持<br>请使用下方按钮复制链接</p></div>';
                    }
                } else {
                    qrcodeDiv.innerHTML = '<p style="color: #999;">暂无二维码</p>';
                }
            }
        }

        function copyConfig() {
            const text = document.getElementById('configUrl').textContent;
            
            // 尝试使用现代 clipboard API
            if (navigator.clipboard && navigator.clipboard.writeText) {
                navigator.clipboard.writeText(text).then(() => {
                    showMessage('复制成功', '配置链接已复制到剪贴板', 'success');
                }).catch(err => {
                    console.error('复制失败:', err);
                    fallbackCopy(text);
                });
            } else {
                // 降级到传统方法
                fallbackCopy(text);
            }
        }

        function fallbackCopy(text) {
            const textarea = document.createElement('textarea');
            textarea.value = text;
            textarea.style.position = 'fixed';
            textarea.style.opacity = '0';
            document.body.appendChild(textarea);
            textarea.select();
            try {
                document.execCommand('copy');
                showMessage('复制成功', '配置链接已复制到剪贴板', 'success');
            } catch (err) {
                console.error('复制失败:', err);
                showMessage('复制失败', '无法自动复制，请手动选择内容复制', 'error');
            }
            document.body.removeChild(textarea);
        }

        async function resetPassword() {
            const currentPassword = document.getElementById('currentPassword').value;
            const newPassword = document.getElementById('newPassword').value;
            const confirmPassword = document.getElementById('confirmPassword').value;

            if (!currentPassword || !newPassword || !confirmPassword) {
                showMessage('输入错误', '请填写所有密码字段', 'error');
                return;
            }

            if (newPassword !== confirmPassword) {
                showMessage('密码不匹配', '新密码和确认密码不一致', 'error');
                return;
            }

            if (newPassword.length < 6) {
                showMessage('密码太短', '新密码长度至少为6位', 'error');
                return;
            }

            try {
                const res = await fetch('/api/reset-password', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({
                        username: '{{ username }}',
                        current_password: currentPassword,
                        new_password: newPassword
                    })
                });

                const data = await res.json();

                if (data.success) {
                    showMessage('密码重置成功', '您的密码已成功修改，请记住新密码', 'success');
                    // 清空密码输入框
                    document.getElementById('currentPassword').value = '';
                    document.getElementById('newPassword').value = '';
                    document.getElementById('confirmPassword').value = '';
                } else {
                    showMessage('密码重置失败', data.message, 'error');
                }
            } catch (error) {
                console.error('密码重置错误:', error);
                showMessage('密码重置失败', '网络错误，请稍后重试', 'error');
            }
        }

        // 页面加载完成后初始化
        document.addEventListener('DOMContentLoaded', function() {
            // 检查QRCode库
            checkQRCode();

            // 为所有tab按钮添加点击事件
            document.querySelectorAll('.tab').forEach((tabBtn, index) => {
                tabBtn.addEventListener('click', function() {
                    const tabTypes = ['vless', 'vmess', 'trojan', 'ss', 'shadowrocket', 'clash'];
                    showTab(tabTypes[index], this);
                });
            });

            // 密码输入框回车事件
            document.getElementById('password').addEventListener('keypress', function(e) {
                if (e.key === 'Enter') loadConfig();
            });
        });
    </script>
</body>
</html>'''

    # 保存模板
    with open(f'{template_dir}/login.html', 'w', encoding='utf-8') as f:
        f.write(login_html)
    with open(f'{template_dir}/index.html', 'w', encoding='utf-8') as f:
        f.write(index_html)
    with open(f'{template_dir}/user_config.html', 'w', encoding='utf-8') as f:
        f.write(user_config_html)

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
