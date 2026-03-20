# Proxy Manager 安全配置说明

## 🔐 密码保护机制

本系统所有代理渠道都采用严格的密码/凭证保护，防止被滥用。

### 各协议认证方式

| 协议 | 端口 | 认证方式 | 凭证类型 | 安全等级 |
|------|------|----------|----------|----------|
| **VLESS** | 500 | UUID | 128位随机UUID | ⭐⭐⭐⭐⭐ |
| **Trojan** | 501 | 密码 | 16位随机密码 | ⭐⭐⭐⭐⭐ |
| **VMess** | 502 | UUID + 禁用弱加密 | 128位随机UUID | ⭐⭐⭐⭐⭐ |
| **Shadowsocks** | 503 | 密码 | 16位随机密码 + AES-256-GCM | ⭐⭐⭐⭐ |

### 安全特性

#### 1. 用户级隔离
- 每个用户拥有独立的UUID和密码
- 用户无法访问其他用户的流量
- 禁用用户立即失去所有访问权限

#### 2. 强制凭证验证
```json
// VLESS - 必须提供正确的UUID
{
  "id": "0571d0cb-8841-4ce4-af60-d445bea22bff",
  "email": "user@proxy-manager"
}

// Trojan - 必须提供正确的密码
{
  "password": "3hVYU0O79zpZMIO5",
  "email": "user@proxy-manager"
}

// VMess - UUID + 禁用不安全加密
{
  "id": "0571d0cb-8841-4ce4-af60-d445bea22bff",
  "disableInsecureEncryption": true
}

// Shadowsocks - 密码 + 强加密
{
  "password": "3hVYU0O79zpZMIO5",
  "method": "aes-256-gcm"
}
```

#### 3. 空用户保护
- 当没有启用用户时，所有代理端口自动关闭
- 不会开放无密码访问的端口
- 防止配置错误导致的开放代理

#### 4. TLS加密
- VLESS、Trojan、VMess使用TLS加密传输
- 防止流量被监听或篡改
- allowInsecure设置为false，防止中间人攻击

#### 5. 访问日志
- 记录级别设置为info
- 所有连接尝试都会被记录
- 便于审计和异常检测

## 🛡️ 防滥用措施

### 1. 流量限制
```python
# 为每个用户设置流量限制
{
  "traffic_limit": 100,  # GB
  "traffic_used": 0
}
```

### 2. 用户状态控制
- 启用/禁用用户功能
- 超限自动禁用
- 管理员可随时切断访问

### 3. 凭证复杂度
- UUID: 128位随机生成
- 密码: 16位Base64随机字符
- 无法猜测或暴力破解

## 📊 日志监控

### 查看访问日志
```bash
# 实时查看访问日志
sudo tail -f /var/log/xray/access.log

# 查看最近的连接记录
sudo journalctl -u xray -n 100

# 查看Web管理日志
sudo journalctl -u proxy-web -f
```

### 日志格式
```
2026/03/20 22:30:15 [Info] proxy/proxy_manager: accepted tcp:1.2.3.4:50000 user@example.com
```

## 🔍 安全检查清单

- [ ] 所有用户都有唯一的UUID和密码
- [ ] 没有启用的用户时端口关闭
- [ ] TLS加密已启用（VLESS/Trojan/VMess）
- [ ] 禁用不安全的加密方式（VMess）
- [ ] 访问日志已启用并正常记录
- [ ] 防火墙只开放必要端口
- [ ] 管理员密码已修改并妥善保管
- [ ] 定期检查流量使用情况

## ⚠️ 安全建议

### 1. 定期更换凭证
```bash
# 删除旧用户
python3 /etc/proxy-manager/proxy_manager.py delete old_user

# 添加新用户（自动生成新凭证）
# 通过Web界面添加
```

### 2. 监控异常流量
```bash
# 查看用户流量
python3 /etc/proxy-manager/proxy_manager.py list

# 设置合理的流量限制
# 通过Web界面设置traffic_limit
```

### 3. 保护管理面板
```bash
# Web管理面板使用强密码
# 不要在公网暴露5080端口
# 考虑使用反向代理+基本认证
```

### 4. 证书管理
```bash
# 定期更新TLS证书（当前使用自签名证书）
# 考虑使用Let's Encrypt获取有效证书
# 证书位置：/etc/proxy-manager/server.crt
```

## 🚨 异常处理

### 发现滥用行为
1. 立即禁用相关用户
   ```bash
   # 通过Web界面禁用
   # 或命令行
   python3 /etc/proxy-manager/proxy_manager.py disable username
   ```

2. 检查日志确认来源
   ```bash
   sudo grep username /var/log/xray/access.log
   ```

3. 删除滥用用户并重建
   ```bash
   python3 /etc/proxy-manager/proxy_manager.py delete username
   ```

### 疑似被扫描
如果发现大量失败连接：
```bash
# 查看错误日志
sudo tail -f /var/log/xray/error.log

# 使用fail2ban保护（需额外安装）
# 或使用防火墙封禁IP
sudo firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="1.2.3.4" reject'
```

## 📞 安全事件响应

1. **隔离** - 立即禁用所有用户
2. **评估** - 检查日志确定影响范围
3. **修复** - 更新所有凭证
4. **加固** - 实施额外的安全措施
5. **监控** - 加强日志监控

## 🔄 凭证轮换

定期轮换凭证可以提高安全性：

```bash
# 1. 备份当前配置
sudo cp /etc/proxy-manager/users.json /etc/proxy-manager/users.json.backup

# 2. 通过Web界面删除旧用户

# 3. 添加新用户（自动生成新凭证）

# 4. 通知用户更新配置

# 5. 确认后删除备份
sudo rm /etc/proxy-manager/users.json.backup
```

## ✅ 默认安全配置

安装时自动应用的安全配置：

✓ 所有协议强制密码/UUID认证
✓ TLS加密传输（除Shadowsocks外）
✓ 禁用不安全的加密方式
✓ 访问日志记录
✓ 空用户时端口关闭
✓ 流量统计和限制
✓ 用户状态管理
✓ 防火墙端口限制

**系统默认配置已经足够安全，但仍建议定期检查和更新凭证。**
