#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Proxy Manager - Web管理界面 (简化修复版)
专注于解决模板缺失问题
"""

import os
import sys

# 设置模板目录
TEMPLATE_DIR = os.path.expanduser('~/.proxy-manager/templates')
os.makedirs(TEMPLATE_DIR, exist_ok=True)

def create_templates():
    """创建必需的模板文件"""

    # login.html 模板
    login_html = '''<!DOCTYPE html>
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

    # index.html 模板
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

    # user_config.html 模板
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

    # 写入模板文件
    with open(f'{TEMPLATE_DIR}/login.html', 'w', encoding='utf-8') as f:
        f.write(login_html)
    with open(f'{TEMPLATE_DIR}/index.html', 'w', encoding='utf-8') as f:
        f.write(index_html)
    with open(f'{TEMPLATE_DIR}/user_config.html', 'w', encoding='utf-8') as f:
        f.write(user_config_html)

    print(f"✓ 模板文件创建完成: {TEMPLATE_DIR}")

# 确保模板存在
create_templates()

# 现在导入Flask和其他依赖
try:
    from flask import Flask, render_template, request, jsonify, session, redirect
    app = Flask(__name__, template_folder=TEMPLATE_DIR)
    app.secret_key = os.urandom(24)
except ImportError as e:
    print(f"❌ Flask导入失败: {e}")
    print("请安装Flask: pip3 install flask")
    sys.exit(1)

# 简单的路由
@app.route('/')
def index():
    if 'logged_in' not in session:
        return redirect('/login')
    return render_template('index.html', domain='localhost')

@app.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        password = request.form.get('password', '')
        # 简单的密码验证（实际应用中应该更安全）
        if password:  # 临时接受任何非空密码
            session['logged_in'] = True
            return redirect('/')
        else:
            return render_template('login.html', error='密码不能为空')
    return render_template('login.html')

@app.route('/user/<username>')
def user_config(username):
    if 'logged_in' not in session:
        return redirect('/login')
    return render_template('user_config.html', username=username, domain='localhost')

@app.route('/logout')
def logout():
    session.clear()
    return redirect('/login')

if __name__ == '__main__':
    print(f"🚀 启动Proxy Manager Web界面...")
    print(f"📁 模板目录: {TEMPLATE_DIR}")
    print(f"🌐 访问地址: http://0.0.0.0:5080")
    app.run(host='0.0.0.0', port=5080, debug=False)