# Proxy Manager 快速参考

## 一键安装

```bash
sudo bash quick_install.sh
```

## 默认端口 (从500开始，避免冲突)

| 用途 | 端口 | 协议 |
|------|------|------|
| VLESS | 500 | TLS加密 |
| Trojan | 501 | TLS加密 |
| VMess | 502 | TLS加密 |
| Shadowsocks | 503 | 无加密 |
| Web管理 | 5080 | HTTP |

## 安装后首次使用

1. **获取管理员密码**
   ```bash
   sudo cat /etc/proxy-manager/install_info.txt
   ```

2. **访问管理面板**
   ```
   http://your-server-ip:5080
   ```

3. **使用管理员密码登录**

4. **添加新用户**（可选）
   - 点击"添加用户"
   - 输入用户名和流量限制
   - 保存显示的密码

5. **获取用户配置**
   - 点击用户右侧的"配置"按钮
   - 输入用户密码
   - 选择协议类型
   - 扫描二维码或复制链接

## 常用命令

```bash
# 服务管理
sudo systemctl start xray          # 启动代理
sudo systemctl start proxy-web     # 启动Web管理
sudo systemctl restart xray        # 重启代理
sudo systemctl status proxy-web    # 查看状态

# 用户管理
python3 /etc/proxy-manager/proxy_manager.py list    # 列出用户

# 日志查看
sudo tail -f /var/log/xray/access.log    # 代理日志
sudo journalctl -u proxy-web -f          # Web日志

# 配置查看
sudo cat /etc/proxy-manager/install_info.txt  # 安装信息
sudo cat /etc/proxy-manager/users.json        # 用户数据库
```

## 客户端配置链接格式

```
VLESS:    vless://uuid@server:500?encryption=none&security=tls&type=tcp#name
Trojan:   trojan://password@server:501?security=tls&type=tcp#name
VMess:    vmess://base64(config)
SS:       ss://base64(method:password)@server:503#name
```

## 卸载

```bash
sudo bash uninstall.sh
```

## 支持的客户端

| 客户端 | 平台 | 支持协议 |
|--------|------|----------|
| Shadowrocket | iOS/macOS | ✓ |
| V2RayN | Windows | ✓ |
| V2RayNG | Android | ✓ |
| Quantumult X | iOS | ✓ |
| Clash | 全平台 | VLESS |

## 故障排查

### 无法连接代理

1. 检查服务状态
   ```bash
   sudo systemctl status xray
   ```

2. 检查端口是否开放
   ```bash
   sudo ss -tlnp | grep 500
   ```

3. 查看日志
   ```bash
   sudo tail -f /var/log/xray/access.log
   ```

### 无法访问Web界面

1. 检查Web服务
   ```bash
   sudo systemctl status proxy-web
   ```

2. 检查防火墙
   ```bash
   sudo firewall-cmd --list-ports
   # 或
   sudo ufw status
   ```

3. 查看Web日志
   ```bash
   sudo journalctl -u proxy-web -n 50
   ```

## 安全建议

- ✓ 安装后立即修改管理员密码
- ✓ 为用户设置复杂密码
- ✓ 定期检查流量使用情况
- ✓ 保持系统更新
- ✓ 使用强密码策略

## 文件位置

```
/etc/proxy-manager/         配置目录
├── config.json            Xray配置
├── users.json             用户数据库
├── install_info.txt       安装信息
├── server.crt             TLS证书
└── server.key             TLS私钥

/var/www/proxy-manager/    Web界面
└── proxy_web.py           Web应用

/var/log/xray/             日志目录
├── access.log             访问日志
└── error.log              错误日志
```

## 需要帮助？

- 查看详细文档: `cat README.md`
- 查看端口说明: `cat PORTS.md`
- 查看安装日志: `sudo journalctl -u xray`
