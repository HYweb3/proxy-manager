# Proxy Manager 部署清单

## 📦 打包文件清单

文件名: `proxy-manager.zip` (26KB)

### 包含文件:

| 文件名 | 说明 |
|--------|------|
| `proxy_manager.py` | 核心配置管理器 |
| `proxy_web.py` | Web管理界面 |
| `install.sh` | 交互式安装脚本 |
| `auto_install.sh` | 一键自动安装脚本 |
| `README.md` | 项目说明文档 |
| `DEPLOY.md` | 详细部署文档 |
| `requirements.txt` | Python依赖列表 |
| `INSTALL_CHECKLIST.md` | 本部署清单 |

---

## 🚀 新设备部署步骤

### 1. 上传文件到新服务器

```bash
# 方式1: 使用scp上传
scp proxy-manager.zip root@新服务器IP:/root/

# 方式2: 使用wget下载（如果已托管）
wget https://你的下载地址/proxy-manager.zip
```

### 2. 解压文件

```bash
cd /root
unzip proxy-manager.zip
cd proxy-manager
```

### 3. 确认文件完整性

```bash
ls -la
# 应该看到以下文件:
# - proxy_manager.py
# - proxy_web.py
# - install.sh
# - auto_install.sh
# - README.md
# - DEPLOY.md
# - requirements.txt
```

### 4. 运行安装

```bash
# 给予执行权限
chmod +x install.sh auto_install.sh

# 运行自动安装（推荐）
sudo bash auto_install.sh

# 或运行交互式安装
sudo ./install.sh
```

### 5. 记录重要信息

安装完成后会显示：

```
★★★ 管理员密码: xxxxxxxxxxxxxxxx ★★★
请立即保存此密码！

服务器IP: xxx.xxx.xxx.xxx
代理端口: 443
管理面板: http://xxx.xxx.xxx.xxx:8081
```

### 6. 验证安装

```bash
# 检查服务状态
sudo systemctl status xray
sudo systemctl status proxy-web

# 检查端口监听
sudo ss -tlnp | grep -E "443|8081"

# 测试Web访问
curl -I http://localhost:8081
```

### 7. 配置防火墙

```bash
# firewalld (CentOS/RHEL)
sudo firewall-cmd --permanent --add-port=443/tcp
sudo firewall-cmd --permanent --add-port=8081/tcp
sudo firewall-cmd --reload

# ufw (Ubuntu/Debian)
sudo ufw allow 443/tcp
sudo ufw allow 8081/tcp
```

### 8. 访问管理面板

打开浏览器访问: `http://服务器IP:8081`

使用管理员密码登录

---

## ✅ 安装检查清单

部署完成后，请逐项检查：

- [ ] Xray服务运行正常
  ```bash
  sudo systemctl is-active xray
  # 应显示: active
  ```

- [ ] Web服务运行正常
  ```bash
  sudo systemctl is-active proxy-web
  # 应显示: active
  ```

- [ ] 443端口正在监听
  ```bash
  sudo ss -tlnp | grep 443
  # 应显示: LISTEN ... xray
  ```

- [ ] 8081端口正在监听
  ```bash
  sudo ss -tlnp | grep 8081
  # 应显示: LISTEN ... python3
  ```

- [ ] 可以访问Web管理面板
  ```bash
  curl http://localhost:8081
  # 应返回HTML内容
  ```

- [ ] 管理员密码已保存
  ```bash
  sudo cat /etc/proxy-manager/users.json | grep admin_password
  # 记录此密码！
  ```

- [ ] 防火墙规则已配置
  ```bash
  # CentOS
  sudo firewall-cmd --list-ports
  # 应显示: 443/tcp 8081/tcp

  # Ubuntu
  sudo ufw status
  # 应显示端口已开放
  ```

- [ ] 服务已设置开机自启
  ```bash
  sudo systemctl is-enabled xray
  sudo systemctl is-enabled proxy-web
  # 都应显示: enabled
  ```

---

## 🔑 重要信息记录

**部署后请立即记录以下信息:**

```
服务器IP: ___________________
管理员密码: ___________________
代理端口: 443
Web端口: 8081
管理面板: http://__________________:8081
安装日期: ___________________
```

---

## 📞 故障排查

如果安装过程中遇到问题：

1. **查看服务日志**
   ```bash
   sudo journalctl -u xray -n 50
   sudo journalctl -u proxy-web -n 50
   ```

2. **检查端口占用**
   ```bash
   sudo ss -tlnp | grep -E "443|8081"
   ```

3. **测试配置文件**
   ```bash
   /usr/local/bin/xray -test -config /etc/proxy-manager/config.json
   ```

4. **查看Python依赖**
   ```bash
   pip3 list | grep -E "flask|qrcode|pyyaml"
   ```

详细故障排查请参考 [DEPLOY.md](DEPLOY.md)

---

## 📝 版本信息

- 打包日期: 2026-03-20
- 版本: 1.0.0
- Xray版本: latest
- Python要求: 3.6+

---

**部署完成后建议:**

1. 修改默认端口
2. 配置自己的域名和SSL证书
3. 定期备份配置文件
4. 设置流量限制防止滥用
