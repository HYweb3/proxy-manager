# Proxy Manager 一键安装脚本

## 原始版本安装

\`\`\`bash
curl -L https://ok.bi5u.com/xxx/proxy-manager-full.zip -o proxy-manager.zip && \
unzip proxy-manager.zip -d proxy-manager && \
cd proxy-manager && \
sudo bash quick_install.sh
\`\`\`

## GitHub 版本一键安装

将以下命令中的 `YOUR_USERNAME` 和 `YOUR_REPO` 替换为你的 GitHub 用户名和仓库名：

\`\`\`bash
curl -fsSL https://raw.githubusercontent.com/HYweb3/proxy-manager/main/install-from-github.sh | bash
\`\`\`

或者直接运行：

\`\`\`bash
bash <(curl -fsSL https://raw.githubusercontent.com/HYweb3/proxy-manager/main/install-from-github.sh)
\`\`\`

## 使用说明

1. 将此项目上传到你的 GitHub 仓库
2. 替换 `install-from-github.sh` 中的 `GITHUB_USERNAME` 和 `REPO_NAME`
3. 使用上面的命令进行一键安装

## 文件说明

- `proxy-manager-install.sh` - 原始安装脚本
- `install-from-github.sh` - GitHub 版本一键安装脚本
