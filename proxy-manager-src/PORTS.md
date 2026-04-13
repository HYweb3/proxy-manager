# Proxy Manager 端口配置说明

## 端口分配 (从500开始)

为了避免与常见服务端口冲突，本系统使用从500开始的端口：

| 端口 | 协议 | 用途 | 加密 |
|------|------|------|------|
| **500** | VLESS | 代理服务 | TLS |
| **501** | Trojan | 代理服务 | TLS |
| **502** | VMess | 代理服务 | TLS |
| **503** | Shadowsocks | 代理服务 | 无 |
| **5080** | HTTP | Web管理界面 | 无 |

## 端口使用说明

### 代理端口 (500-503)

- **500 (VLESS)**: 最推荐的协议，性能优秀，兼容性好
- **501 (Trojan)**: 伪装成HTTPS流量，抗封锁能力强
- **502 (VMess)**: 老牌协议，兼容性极佳
- **503 (Shadowsocks)**: 轻量级协议，速度快

### 管理端口 (5080)

- **5080**: Web管理界面，用于用户管理和配置获取

## 客户端配置示例

### VLESS (端口500)
```
vless://uuid@server:500?encryption=none&security=tls&type=tcp#ProxyManager_user
```

### Trojan (端口501)
```
trojan://password@server:501?security=tls&type=tcp#ProxyManager_user
```

### VMess (端口502)
```
vmess://base64(config)
```
配置JSON:
```json
{
  "v": "2",
  "ps": "ProxyManager_user",
  "add": "server",
  "port": "502",
  "id": "uuid",
  "net": "tcp",
  "type": "none",
  "tls": "tls"
}
```

### Shadowsocks (端口503)
```
ss://base64(method:password)@server:503#ProxyManager_user
```

## 修改端口

如需自定义端口，编辑以下文件：

```bash
# 修改安装脚本中的端口变量
nano /home/hnbwww/proxy-manager/quick_install.sh

# 修改现有配置
nano /etc/proxy-manager/users.json  # 修改port字段
nano /etc/proxy-manager/config.json  # 修改inbounds中的端口

# 重启服务
systemctl restart xray
```

## 防火墙配置

### CentOS/RHEL (firewalld)
```bash
sudo firewall-cmd --permanent --add-port=500/tcp
sudo firewall-cmd --permanent --add-port=501/tcp
sudo firewall-cmd --permanent --add-port=502/tcp
sudo firewall-cmd --permanent --add-port=503/tcp
sudo firewall-cmd --permanent --add-port=5080/tcp
sudo firewall-cmd --reload
```

### Ubuntu/Debian (ufw)
```bash
sudo ufw allow 500/tcp
sudo ufw allow 501/tcp
sudo ufw allow 502/tcp
sudo ufw allow 503/tcp
sudo ufw allow 5080/tcp
```

## 常见服务端口对照表

为了避免冲突，以下是一些常见服务端口：

| 服务 | 端口 | 说明 |
|------|------|------|
| HTTPS | 443 | 加密网页浏览 |
| HTTP | 80 | 网页浏览 |
| SSH | 22 | 远程登录 |
| FTP | 21/20 | 文件传输 |
| SMTP | 25 | 邮件发送 |
| DNS | 53 | 域名解析 |
| MySQL | 3306 | 数据库 |
| PostgreSQL | 5432 | 数据库 |
| Redis | 6379 | 缓存 |
| MongoDB | 27017 | 数据库 |
| Tomcat | 8080 | Java应用服务器 |

本系统使用的500-503和5080端口均避开了上述常见端口。
