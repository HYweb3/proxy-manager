# Proxy Manager

<div align="center">

**一个功能完整的代理服务管理系统**

支持多用户、流量统计、Web管理界面、二维码分享

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Python](https://img.shields.io/badge/python-3.6+-green.svg)](https://www.python.org/)
[![Xray](https://img.shields.io/badge/xray-core-latest-orange.svg)](https://github.com/XTLS/Xray-core)

</div>

## ✨ 功能特性

- ✅ **多协议支持**: VLESS, VMESS, Trojan, Shadowsocks, Shadowrocket
- ✅ **多用户管理**: 独立账号、独立流量统计
- ✅ **Web管理界面**: 简洁美观的操作面板
- ✅ **二维码分享**: 扫码即用，支持多种客户端
- ✅ **流量控制**: 支持流量限制和实时统计
- ✅ **安全可靠**: 密码保护、TLS加密
- ✅ **一键部署**: 自动化安装脚本
- ✅ **跨平台**: 支持 CentOS, Ubuntu, Debian, OpenCloudOS

## 📦 支持的客户端

| 客户端 | 支持协议 | 导入方式 |
|--------|----------|----------|
| Shadowrocket | VLESS, VMESS, Trojan, Shadowrocket | 扫码/链接 |
| Quantumult X | VLESS, VMESS, Trojan | 扫码/链接 |
| Clash | VLESS | 配置文件 |
| V2RayN | VLESS, VMESS | 链接 |
| V2RayNG | VLESS, VMESS | 链接 |
| Shadowsocks | SS | 链接 |

## 🚀 快速开始

### ⭐ GitHub 一键安装（最简单）

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/HYweb3/proxy-manager/main/install-from-github.sh)
```

**一行命令搞定！自动下载并安装所有依赖。**

---

### 方法一：完整版一键安装（推荐）⭐

```bash
sudo bash quick_install.sh
```

**完整功能包括：**
- ✅ 自动创建不限流量默认用户
- ✅ 安装后直接显示所有代理连接配置
- ✅ 自动生成二维码（终端支持时）
- ✅ 完整的卸载脚本

### 方法二：简化自动安装

```bash
wget -N --no-check-certificate https://raw.githubusercontent.com/HYweb3/proxy-manager/master/auto_install.sh
chmod +x auto_install.sh
sudo bash auto_install.sh
```

### 方法二：手动安装

详细的安装步骤请参考 [部署文档](DEPLOY.md)

```bash
# 1. 安装系统依赖
sudo dnf/yum/apt-get install -y curl wget unzip qrencode python3 python3-pip

# 2. 安装Python依赖
pip3 install -r requirements.txt

# 3. 安装XRay-core
wget https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip
unzip Xray-linux-64.zip -d /usr/local/bin/

# 4. 运行安装脚本
chmod +x install.sh
sudo ./install.sh
```

## 📖 使用说明

### Web管理面板

安装完成后访问：`http://你的服务器IP:8081`

```
管理员密码: 在安装时生成，保存在 /etc/proxy-manager/users.json
查看密码: sudo cat /etc/proxy-manager/users.json | grep admin_password
```

### 命令行管理

```bash
# 运行管理脚本
sudo ./install.sh

# 菜单选项：
# 1. 安装代理服务
# 2. 添加用户
# 3. 列出所有用户
# 4. 删除用户
# 5. 启动服务
# 6. 停止服务
# 7. 重启服务
# 8. 查看服务状态
# 9. 查看日志
# 10. 卸载服务
```

### 用户配置获取

用户可以通过以下方式获取配置：

**方式一：管理员分享**
```
Web面板 → 查看用户配置 → 显示二维码/复制链接
```

**方式二：用户自助获取**
```
访问: http://你的服务器IP:8081/user/用户名
输入用户密码 → 选择协议 → 扫码或复制链接
```

## 📁 目录结构

```
/etc/proxy-manager/              # 配置目录
├── config.json                 # Xray配置
├── users.json                  # 用户数据库
├── stats.json                  # 流量统计
├── server.crt                  # TLS证书
├── server.key                  # TLS私钥
└── proxy_manager.py            # 配置管理器

/var/www/proxy-manager/         # Web界面
└── proxy_web.py                # Web服务

/var/log/xray/                  # 日志目录
```

## 🔧 常用命令

```bash
# 服务管理
sudo systemctl start xray          # 启动代理服务
sudo systemctl start proxy-web     # 启动Web服务
sudo systemctl restart xray         # 重启代理服务
sudo systemctl status proxy-web     # 查看Web服务状态

# 用户管理
python3 /etc/proxy-manager/proxy_manager.py list              # 列出用户
python3 /etc/proxy-manager/proxy_manager.py add 用户名 UUID 密码  # 添加用户
python3 /etc/proxy-manager/proxy_manager.py delete 用户名       # 删除用户

# 日志查看
sudo tail -f /var/log/xray/access.log    # 访问日志
sudo journalctl -u xray -f                # 系统日志
```

## 🛡️ 安全建议

1. **修改默认端口**: 建议修改代理端口（默认500）
2. **使用域名**: 配置自己的域名和有效SSL证书
3. **防火墙配置**: 只开放必要的端口（500-503, 5080）
4. **定期更新**: 定期更新系统和依赖包
5. **密码管理**: 定期更换管理员密码
6. **流量限制**: 为用户设置合理的流量限制
7. **运行安全检查**: 使用 `sudo bash security_check.sh` 检查系统安全状态

## 🔐 安全特性

- ✅ **所有渠道强制密码/UUID认证** - 防止被滥用
- ✅ **TLS加密传输** - VLESS/Trojan/VMess使用TLS
- ✅ **用户隔离** - 每个用户独立凭证
- ✅ **流量限制** - 超限自动禁用
- ✅ **访问日志** - 完整的连接记录
- ✅ **空用户保护** - 无用户时端口自动关闭

详细安全说明请查看 [SECURITY.md](SECURITY.md)

## 🔍 故障排查

### 服务无法启动

```bash
# 检查端口占用
sudo ss -tlnp | grep 500
sudo ss -tlnp | grep 5080

# 检查配置文件
/usr/local/bin/xray -test -config /etc/proxy-manager/config.json

# 查看错误日志
sudo journalctl -u xray -n 50
sudo journalctl -u proxy-web -n 50
```

### Python模块缺失

```bash
pip3 install flask flask-qrcode qrcode pillow pyyaml
```

更多故障排查方法请参考 [部署文档](DEPLOY.md)

## 📋 系统要求

- **操作系统**: Linux (CentOS 7+, Ubuntu 18.04+, Debian 10+, OpenCloudOS)
- **Python版本**: Python 3.6+
- **权限**: Root权限
- **内存**: 最低512MB，推荐1GB+
- **网络**: 开放端口 500-503 (代理), 5080 (Web管理)

## 📚 文档

- [部署文档](DEPLOY.md) - 详细的安装和配置指南
- [依赖列表](requirements.txt) - Python依赖包

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

## 📄 开源协议

MIT License

## ⚠️ 免责声明

本项目仅供学习交流使用，请遵守当地法律法规。使用本软件所产生的一切后果由使用者自行承担。

---

<div align="center">

Made with ❤️ by [Proxy Manager](https://github.com/HYweb3/proxy-manager)

</div>
