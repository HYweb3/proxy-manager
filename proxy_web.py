#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Proxy Manager - Web管理界面
提供扫码、复制链接、配置管理功能
"""

import sys
import os

# 检查必需的 Python 模块
missing_modules = []

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

import json
import io
import base64

# 如果缺少必需模块，输出错误信息并退出
if missing_modules:
    print("=" * 60, file=sys.stderr)
    print("错误: 缺少必需的 Python 模块", file=sys.stderr)
    print("=" * 60, file=sys.stderr)
    print("请安装以下模块:", file=sys.stderr)
    for module in missing_modules:
        print(f"  - {module}", file=sys.stderr)
    print("", file=sys.stderr)
    print("安装命令:", file=sys.stderr)
    print("  pip3 install " + " ".join(missing_modules), file=sys.stderr)
    print("", file=sys.stderr)
    print("或者使用系统包管理器:", file=sys.stderr)
    print("  Ubuntu/Debian: sudo apt-get install python3-flask python3-qrcode python3-pil", file=sys.stderr)
    print("  CentOS/RHEL:   sudo yum install python3-flask python3-qrcode python3-pillow", file=sys.stderr)
    print("=" * 60, file=sys.stderr)
    sys.exit(1)

# 添加配置管理器路径
sys.path.insert(0, '/etc/proxy-manager')
try:
    from proxy_manager import ProxyManager
except ImportError:
    print("错误: 找不到 proxy_manager 模块", file=sys.stderr)
    print("请确保 /etc/proxy-manager/proxy_manager.py 文件存在", file=sys.stderr)
    sys.exit(1)

app = Flask(__name__)
app.secret_key = os.urandom(24)
QRcode(app)

try:
    manager = ProxyManager()
except Exception as e:
    print(f"错误: 无法初始化 ProxyManager: {e}", file=sys.stderr)
    sys.exit(1)


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
    password = request.args.get('password')
    user = manager.get_user(username)

    if not user:
        return jsonify({'error': '用户不存在'}), 404

    if password != user['password']:
        return jsonify({'error': '密码错误'}), 401

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

    return jsonify(config)


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
    # 创建模板目录
    template_dir = '/var/www/proxy-manager/templates'
    os.makedirs(template_dir, exist_ok=True)

    # 创建HTML模板
    login_html = '''<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>代理管理 - 登录</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 20px;
        }
        .login-box {
            background: white;
            border-radius: 20px;
            padding: 40px;
            box-shadow: 0 20px 60px rgba(0,0,0,0.3);
            max-width: 400px;
            width: 100%;
        }
        h1 {
            text-align: center;
            color: #333;
            margin-bottom: 30px;
        }
        .form-group {
            margin-bottom: 20px;
        }
        label {
            display: block;
            color: #666;
            margin-bottom: 8px;
            font-weight: 500;
        }
        input {
            width: 100%;
            padding: 12px 15px;
            border: 2px solid #e0e0e0;
            border-radius: 10px;
            font-size: 16px;
            transition: all 0.3s;
        }
        input:focus {
            outline: none;
            border-color: #667eea;
        }
        button {
            width: 100%;
            padding: 14px;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            border: none;
            border-radius: 10px;
            font-size: 16px;
            font-weight: 600;
            cursor: pointer;
            transition: transform 0.2s;
        }
        button:hover {
            transform: translateY(-2px);
        }
        .message {
            padding: 12px;
            border-radius: 8px;
            margin-bottom: 20px;
            text-align: center;
        }
        .error {
            background: #fee;
            color: #c33;
        }
        .success {
            background: #efe;
            color: #3c3;
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
            background: #f5f7fa;
            padding: 20px;
        }
        .header {
            background: white;
            padding: 20px 30px;
            border-radius: 15px;
            margin-bottom: 20px;
            display: flex;
            justify-content: space-between;
            align-items: center;
            box-shadow: 0 2px 10px rgba(0,0,0,0.05);
        }
        .header h1 {
            color: #333;
            font-size: 24px;
        }
        .btn {
            padding: 10px 20px;
            border: none;
            border-radius: 8px;
            cursor: pointer;
            font-weight: 500;
            transition: all 0.2s;
        }
        .btn-primary {
            background: #667eea;
            color: white;
        }
        .btn-danger {
            background: #f56565;
            color: white;
        }
        .btn:hover {
            transform: translateY(-2px);
            box-shadow: 0 5px 15px rgba(0,0,0,0.2);
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
        }
        .card {
            background: white;
            border-radius: 15px;
            padding: 25px;
            margin-bottom: 20px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.05);
        }
        .card h2 {
            color: #333;
            margin-bottom: 20px;
            font-size: 18px;
        }
        .add-user-form {
            display: grid;
            grid-template-columns: 2fr 1fr 1fr auto;
            gap: 15px;
            align-items: end;
        }
        .form-group label {
            display: block;
            color: #666;
            margin-bottom: 5px;
            font-size: 14px;
        }
        .form-group input {
            width: 100%;
            padding: 10px 15px;
            border: 1px solid #e0e0e0;
            border-radius: 8px;
        }
        table {
            width: 100%;
            border-collapse: collapse;
        }
        th, td {
            padding: 15px;
            text-align: left;
            border-bottom: 1px solid #f0f0f0;
        }
        th {
            background: #f8f9fa;
            color: #666;
            font-weight: 600;
        }
        .status-badge {
            display: inline-block;
            padding: 5px 12px;
            border-radius: 20px;
            font-size: 12px;
            font-weight: 600;
        }
        .status-enabled {
            background: #c6f6d5;
            color: #22543d;
        }
        .status-disabled {
            background: #fed7d7;
            color: #742a2a;
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
                alert('用户添加成功！\\n\\n用户名: ' + data.user.username + '\\n密码: ' + data.user.password + '\\n\\n请保存此密码！');
                document.getElementById('addUserForm').reset();
                loadUsers();
            } else {
                alert(data.message);
            }
        });

        let currentConfig = {};

        async function showConfig(username) {
            const user = currentUsers.find(u => u.username === username);
            if (!user) return;

            const password = prompt('请输入用户密码:');
            if (!password) return;

            const res = await fetch(`/api/user/${username}/config?password=${password}`);
            const data = await res.json();

            if (data.error) {
                alert(data.error);
                return;
            }

            currentConfig = data;
            document.getElementById('modalTitle').textContent = `配置 - ${username}`;
            showTab('vless');
            document.getElementById('configModal').classList.add('active');
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
                QRCode.toCanvas(document.createElement('canvas'), urls[tab], { width: 200 }, (error, canvas) => {
                    document.getElementById('qrcode').innerHTML = '';
                    if (!error) document.getElementById('qrcode').appendChild(canvas);
                });
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
                    alert('✅ 已复制到剪贴板');
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
                alert('✅ 已复制到剪贴板');
            } catch (err) {
                console.error('复制失败:', err);
                alert('❌ 复制失败，请手动复制');
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
    <title>配置 - {{ username }}</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            padding: 20px;
        }
        .container {
            max-width: 600px;
            margin: 0 auto;
            background: white;
            border-radius: 20px;
            padding: 30px;
            box-shadow: 0 20px 60px rgba(0,0,0,0.3);
        }
        h1 {
            text-align: center;
            color: #333;
            margin-bottom: 30px;
        }
        .password-form {
            margin-bottom: 30px;
        }
        .password-form input {
            width: 100%;
            padding: 15px;
            border: 2px solid #e0e0e0;
            border-radius: 10px;
            font-size: 16px;
            margin-bottom: 15px;
        }
        .btn {
            width: 100%;
            padding: 15px;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            border: none;
            border-radius: 10px;
            font-size: 16px;
            font-weight: 600;
            cursor: pointer;
        }
        .config-content {
            display: none;
        }
        .config-content.active {
            display: block;
        }
        .tabs {
            display: flex;
            gap: 10px;
            margin-bottom: 20px;
            border-bottom: 2px solid #f0f0f0;
        }
        .tab {
            flex: 1;
            padding: 12px;
            background: none;
            border: none;
            cursor: pointer;
            color: #666;
            font-weight: 500;
        }
        .tab.active {
            color: #667eea;
            border-bottom: 2px solid #667eea;
        }
        .config-box {
            background: #f8f9fa;
            padding: 15px;
            border-radius: 10px;
            word-break: break-all;
            font-family: monospace;
            font-size: 12px;
            margin-bottom: 15px;
        }
        .qrcode-box {
            text-align: center;
            padding: 30px 20px;
            background: #f8f9fa;
            border-radius: 15px;
            margin: 20px 0;
            min-height: 300px;
            display: flex;
            flex-direction: column;
            align-items: center;
            justify-content: center;
        }
        .qrcode-box canvas {
            max-width: 100%;
            height: auto;
            border: 5px solid white;
            border-radius: 10px;
            box-shadow: 0 4px 15px rgba(0,0,0,0.1);
        }
        .qrcode-box h3 {
            margin-bottom: 20px;
            color: #333;
        }
        .copy-btn {
            background: #667eea;
            color: white;
            border: none;
            padding: 10px 20px;
            border-radius: 8px;
            cursor: pointer;
            width: 100%;
            font-size: 14px;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>📱 代理配置</h1>

        <div class="password-form" id="passwordForm">
            <input type="password" id="password" placeholder="请输入用户密码" autofocus>
            <button class="btn" onclick="loadConfig()">查看配置</button>
            <div id="message" style="margin-top: 15px; text-align: center;"></div>
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
                <button class="copy-btn" onclick="copyConfig()">复制链接</button>

                <div class="qrcode-box">
                    <h3>扫描二维码导入</h3>
                    <div id="qrcode"></div>
                </div>
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
                    alert('✅ 已复制到剪贴板');
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
                alert('✅ 已复制到剪贴板');
            } catch (err) {
                console.error('复制失败:', err);
                alert('❌ 复制失败，请手动复制');
            }
            document.body.removeChild(textarea);
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

    # 安装 Flask-QRCode
    os.system('pip3 install flask flask-qrcode pyyaml 2>/dev/null')

    # 从配置文件读取Web端口
    web_port = 5080  # 默认端口
    try:
        if os.path.exists('/etc/proxy-manager/install_info.txt'):
            with open('/etc/proxy-manager/install_info.txt', 'r') as f:
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
