# 新设备一键自动安装说明 v2.0

## 问题已修复 ✅

之前新设备安装时，XRay服务无法启动的原因是：
1. 安装脚本创建了 `users.json` 但没有生成 XRay 需要的 `config.json`
2. 导致服务启动失败：`no such file or directory: /etc/proxy-manager/config.json`

## 一键自动安装（推荐）

```bash
cd /home/hnbwww/proxy-manager
sudo bash one_click_install.sh
```

**此脚本将自动完成：**
- ✅ 安装所有依赖
- ✅ 安装 XRay-core
- ✅ 创建默认用户（user/随机密码）
- ✅ 生成自签名证书
- ✅ **自动生成 XRay 配置文件**
- ✅ 启动所有服务
- ✅ 显示连接信息和二维码

## 安装完成后的输出

```
╔═══════════════════════════════════════════════════════════════╗
║           重要信息 - 请立即保存！                            ║
╚═══════════════════════════════════════════════════════════════╝

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
管理员密码: xxxxxxxxxxxxxxxx
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

服务器信息:
   服务器IP:     xxx.xxx.xxx.xxx

代理端口配置:
   VLESS端口:    500 (TLS加密)
   Trojan端口:   502 (TLS加密)
   VMess端口:    503 (TLS加密)
   SS端口:       504 (无加密)

默认用户信息:
   用户名:       user
   用户密码:     xxxxxxxxxxxxxxxx
   流量限制:     无限

服务状态:
   XRay服务:      ✓ 运行中
   Web管理界面:   ✓ 运行中
```

## 其他安装脚本

### 1. 快速安装（交互式菜单）
```bash
sudo bash quick_install.sh
```
- 选择选项1进行完整安装
- 安装后选择选项2添加用户

### 2. 基础安装（交互式菜单）
```bash
sudo bash install.sh
```
- 选择选项1进行安装
- 安装后选择选项2添加用户

## 常用命令

```bash
# 查看服务状态
systemctl status xray

# 重启服务
systemctl restart xray

# 查看用户列表
python3 /etc/proxy-manager/proxy_manager.py list

# 手动更新XRay配置（如果修改了users.json）
python3 /etc/proxy-manager/proxy_manager.py update_config

# 查看XRay日志
tail -f /var/log/xray/access.log

# 查看服务错误日志
journalctl -u xray -n 50
```

## 配置文件位置

| 文件 | 路径 |
|------|------|
| XRay配置 | `/etc/proxy-manager/config.json` |
| 用户数据 | `/etc/proxy-manager/users.json` |
| TLS证书 | `/etc/proxy-manager/server.crt` |
| TLS私钥 | `/etc/proxy-manager/server.key` |
| 管理器脚本 | `/etc/proxy-manager/proxy_manager.py` |

## 端口说明

| 端口 | 协议 | 说明 |
|------|------|------|
| 500 | VLESS | 主要协议，TLS加密 |
| 502 | Trojan | 备用协议，TLS加密 |
| 503 | VMess | 备用协议，TLS加密 |
| 504 | Shadowsocks | 无加密 |
| 5080 | Web管理 | HTTP管理面板 |

## 问题排查

如果 XRay 服务未运行：

```bash
# 1. 检查配置文件是否存在
ls -la /etc/proxy-manager/config.json

# 2. 查看服务状态
systemctl status xray

# 3. 查看详细错误
journalctl -u xray -n 30

# 4. 手动生成配置文件
python3 /etc/proxy-manager/proxy_manager.py update_config

# 5. 重启服务
systemctl restart xray
```

## 卸载

```bash
sudo bash /home/hnbwww/proxy-manager/uninstall.sh
```
