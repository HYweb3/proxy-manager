#!/usr/bin/env python3
import sys, os, json, io, base64, uuid
sys.path.insert(0, '/etc/proxy-manager')
from flask import Flask, render_template_string, request, jsonify, session, redirect, send_file
import qrcode

app = Flask(__name__)
app.secret_key = os.urandom(24)

exec(open('/etc/proxy-manager/proxy_manager.py', encoding='utf-8').read())
manager = ProxyManager()

LOGIN_HTML = '''<!DOCTYPE html>
<html><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1.0">
<title>代理管理 - 登录</title>
<style>*{margin:0;padding:0;box-sizing:border-box}body{font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,sans-serif;background:linear-gradient(135deg,#667eea 0%,#764ba2 100%);min-height:100vh;display:flex;align-items:center;justify-content:center;padding:20px}.login-box{background:white;border-radius:20px;padding:40px;box-shadow:0 20px 60px rgba(0,0,0,0.3);max-width:400px;width:100%}h1{text-align:center;color:#333;margin-bottom:30px}.form-group{margin-bottom:20px}label{display:block;color:#666;margin-bottom:8px;font-weight:500}input{width:100%;padding:12px 15px;border:2px solid #e0e0e0;border-radius:10px;font-size:16px}input:focus{outline:none;border-color:#667eea}button{width:100%;padding:14px;background:linear-gradient(135deg,#667eea 0%,#764ba2 100%);color:white;border:none;border-radius:10px;font-size:16px;font-weight:600;cursor:pointer}.message{padding:12px;border-radius:8px;margin-bottom:20px;text-align:center}.error{background:#fee;color:#c33}.success{background:#efe;color:#3c3}</style></head>
<body><div class="login-box"><h1>🔐 代理管理登录</h1><div id="message"></div><form id="loginForm"><div class="form-group"><label>管理员密码</label><input type="password" id="password" required autofocus></div><button type="submit">登录</button></form></div>
<script>document.getElementById('loginForm').addEventListener('submit',async(e)=>{e.preventDefault();const p=document.getElementById('password').value;const res=await fetch('/login',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({password:p})});const d=await res.json();const m=document.getElementById('message');if(d.success){m.className='message success';m.textContent=d.message;setTimeout(()=>window.location.href='/',1000)}else{m.className='message error';m.textContent=d.message}});</script></body></html>'''

INDEX_HTML = '''<!DOCTYPE html>
<html><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1.0">
<title>代理管理面板</title>
<style>*{margin:0;padding:0;box-sizing:border-box}body{font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,sans-serif;background:#f5f7fa;padding:20px}.header{background:white;padding:20px 30px;border-radius:15px;margin-bottom:20px;display:flex;justify-content:space-between;align-items:center;box-shadow:0 2px 10px rgba(0,0,0,0.05)}.header h1{color:#333;font-size:24px}.btn{padding:10px 20px;border:none;border-radius:8px;cursor:pointer;font-weight:500;transition:all 0.2s}.btn-primary{background:#667eea;color:white}.btn-danger{background:#f56565;color:white}.btn:hover{transform:translateY(-2px);box-shadow:0 5px 15px rgba(0,0,0,0.2)}.container{max-width:1200px;margin:0 auto}.card{background:white;border-radius:15px;padding:25px;margin-bottom:20px;box-shadow:0 2px 10px rgba(0,0,0,0.05)}.card h2{color:#333;margin-bottom:20px;font-size:18px}.add-user-form{display:grid;grid-template-columns:2fr 1fr 1fr auto;gap:15px;align-items:end}.form-group label{display:block;color:#666;margin-bottom:5px;font-size:14px}.form-group input{width:100%;padding:10px 15px;border:1px solid #e0e0e0;border-radius:8px}table{width:100%;border-collapse:collapse}th,td{padding:15px;text-align:left;border-bottom:1px solid #f0f0f0}th{background:#f8f9fa;color:#666;font-weight:600}.status-badge{display:inline-block;padding:5px 12px;border-radius:20px;font-size:12px;font-weight:600}.status-enabled{background:#c6f6d5;color:#22543d}.status-disabled{background:#fed7d7;color:#742a2a}.config-modal{display:none;position:fixed;top:0;left:0;right:0;bottom:0;background:rgba(0,0,0,0.5);z-index:1000;align-items:center;justify-content:center}.config-modal.active{display:flex}.modal-content{background:white;border-radius:20px;padding:30px;max-width:600px;width:90%;max-height:90vh;overflow-y:auto}.config-tabs{display:flex;gap:10px;margin-bottom:20px;border-bottom:2px solid #f0f0f0}.config-tab{padding:10px 20px;background:none;border:none;cursor:pointer;color:#666;font-weight:500}.config-tab.active{color:#667eea;border-bottom:2px solid #667eea}.config-url{background:#f8f9fa;padding:15px;border-radius:8px;word-break:break-all;font-family:monospace;font-size:12px;margin-bottom:10px}.qrcode-container{text-align:center;padding:20px;background:#f8f9fa;border-radius:15px;margin:20px 0}.copy-btn{background:#667eea;color:white;border:none;padding:8px 15px;border-radius:6px;cursor:pointer;font-size:14px}</style></head>
<body><div class="container"><div class="header"><h1>🚀 代理管理面板</h1><button class="btn btn-danger" onclick="logout()">退出</button></div>
<div class="card"><h2>添加用户</h2><form class="add-user-form" id="addUserForm"><div class="form-group"><label>用户名</label><input type="text" id="username" required></div><div class="form-group"><label>流量限制(GB)</label><input type="number" id="trafficLimit" value="0" min="0"></div><div></div><button type="submit" class="btn btn-primary">添加</button></form></div>
<div class="card"><h2>用户列表</h2><table><thead><tr><th>用户名</th><th>UUID</th><th>流量</th><th>状态</th><th>操作</th></tr></thead><tbody id="userTable"></tbody></table></div></div>
<div class="config-modal" id="configModal"><div class="modal-content"><h2 id="modalTitle">用户配置</h2><div class="config-tabs"><button class="config-tab active" data-tab="vless">VLESS</button><button class="config-tab" data-tab="vmess">VMESS</button><button class="config-tab" data-tab="trojan">Trojan</button><button class="config-tab" data-tab="ss">Shadowsocks</button></div><div class="config-url" id="configUrl"></div><button class="copy-btn" onclick="copyConfig()">复制链接</button><div class="qrcode-container"><h3>扫描二维码</h3><div id="qrcode"></div></div><div style="text-align:center;margin-top:20px"><button class="btn" onclick="closeModal()">关闭</button></div></div></div>
<script src="https://cdn.jsdelivr.net/npm/qrcode@1.5.3/build/qrcode.min.js"></script>
<script>let cu=[];async function lu(){const r=await fetch('/api/users');const d=await r.json();cu=d.users;ru()}
function ru(){document.getElementById('userTable').innerHTML=cu.map(u=>`<tr><td><strong>${u.username}</strong></td><td style="font-family:monospace;font-size:12px">${u.uuid.substring(0,8)}...</td><td>${u.traffic}</td><td><span class="status-badge ${u.status==='启用'?'status-enabled':'status-disabled'}">${u.status}</span></td><td><button class="btn btn-primary" onclick="sc('${u.username}')">配置</button><button class="btn" onclick="tu('${u.username}')">切换</button><button class="btn btn-danger" onclick="du('${u.username}')">删除</button></td></tr>`).join('')}
document.getElementById('addUserForm').addEventListener('submit',async(e)=>{e.preventDefault();const u=document.getElementById('username').value;const t=document.getElementById('trafficLimit').value;const r=await fetch('/api/user/add',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({username:u,traffic_limit:parseInt(t)})});const d=await r.json();if(d.success){alert('✓ 用户添加成功!\\n\\n用户名: '+d.user.username+'\\n密码: '+d.user.password+'\\n\\n请保存此密码!');document.getElementById('addUserForm').reset();lu()}else{alert(d.message)}});
let cc={};async function sc(un){const p=prompt('请输入用户密码:');if(!p)return;const r=await fetch(`/api/user/${un}/config?password=${p}`);const d=await r.json();if(d.error){alert(d.error);return}cc=d;document.getElementById('modalTitle').textContent=`配置 - ${un}`;st('vless');document.getElementById('configModal').classList.add('active')}
function st(t){document.querySelectorAll('.config-tab').forEach(x=>x.classList.remove('active'));document.querySelector(`[data-tab="${t}"]`).classList.add('active');const urls={vless:cc.vless,vmess:cc.vmess,trojan:cc.trojan,ss:cc.ss};document.getElementById('configUrl').textContent=urls[t];QRCode.toCanvas(document.createElement('canvas'),urls[t],{width:200},(e,c)=>{document.getElementById('qrcode').innerHTML='';if(!e)document.getElementById('qrcode').appendChild(c)})}
document.querySelectorAll('.config-tab').forEach(t=>t.addEventListener('click',()=>st(t.dataset.tab)));
function copyConfig(){if(navigator.clipboard){navigator.clipboard.writeText(document.getElementById('configUrl').textContent).then(()=>alert('✓ 已复制到剪贴板')).catch(()=>fallbackCopy())}else{fallbackCopy()}}
function fallbackCopy(){const ta=document.createElement('textarea');ta.value=document.getElementById('configUrl').textContent;ta.style.position='fixed';ta.style.opacity='0';document.body.appendChild(ta);ta.select();try{document.execCommand('copy');alert('✓ 已复制到剪贴板')}catch(e){alert('✗ 复制失败')}document.body.removeChild(ta)}
function closeModal(){document.getElementById('configModal').classList.remove('active')}
async function tu(un){await fetch(`/api/user/${un}/toggle`,{method:'POST'});lu()}
async function du(un){if(!confirm('确定删除用户 '+un+' ?'))return;await fetch(`/api/user/${un}/delete`,{method:'POST'});lu()}
function logout(){if(confirm('确定退出登录?'))window.location.href='/logout'}lu();
</script></body></html>'''

@app.route('/')
def index():
    if 'logged_in' not in session: return render_template_string(LOGIN_HTML)
    return render_template_string(INDEX_HTML)

@app.route('/login', methods=['POST'])
def login():
    data = request.get_json()
    if manager.verify_admin(data.get('password')):
        session['logged_in'] = True
        return jsonify({'success': True, 'message': '登录成功'})
    return jsonify({'success': False, 'message': '密码错误'})

@app.route('/logout')
def logout():
    session.pop('logged_in', None)
    return redirect('/')

@app.route('/api/users')
def get_users():
    if 'logged_in' not in session: return jsonify({'error':'未登录'}), 401
    return jsonify({'users': manager.list_users()})

@app.route('/api/user/<username>/config')
def get_user_config(username):
    pwd = request.args.get('password')
    user = manager.get_user(username)
    if not user: return jsonify({'error':'用户不存在'}), 404
    if pwd != user['password']: return jsonify({'error':'密码错误'}), 401
    return jsonify({'username':username,'vless':manager.generate_vless_url(user),'vmess':manager.generate_vmess_url(user),'trojan':manager.generate_trojan_url(user),'ss':manager.generate_ss_url(user)})

@app.route('/api/user/add', methods=['POST'])
def add_user():
    if 'logged_in' not in session: return jsonify({'error':'未登录'}), 401
    d=request.get_json()
    u=d.get('username')
    if manager.get_user(u): return jsonify({'success':False,'message':'用户已存在'})
    uid=str(uuid.uuid4())
    pwd=base64.b64encode(os.urandom(12)).decode()[:16]
    tl=d.get('traffic_limit',0)
    s,m=manager.add_user(u,uid,pwd,tl)
    if s:return jsonify({'success':True,'message':m,'user':{'username':u,'uuid':uid,'password':pwd}})
    return jsonify({'success':False,'message':m})

@app.route('/api/user/<username>/delete', methods=['POST'])
def delete_user(username):
    if 'logged_in' not in session: return jsonify({'error':'未登录'}), 401
    s,m=manager.delete_user(username)
    return jsonify({'success':s,'message':m})

@app.route('/api/user/<username>/toggle', methods=['POST'])
def toggle_user(username):
    if 'logged_in' not in session: return jsonify({'error':'未登录'}), 401
    u=manager.get_user(username)
    if u['enabled']:manager.disable_user(username);st='disabled'
    else:manager.enable_user(username);st='enabled'
    return jsonify({'success':True,'status':st})

if __name__ == '__main__':
    web_port = 5080
    try:
        with open('/etc/proxy-manager/install_info.txt') as f:
            for line in f:
                if 'Web:' in line:
                    web_port = int(line.split(':')[1].strip())
    except: pass
    app.run(host='0.0.0.0', port=web_port, debug=False)
