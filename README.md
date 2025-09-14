
🚀 服务管理中心 (menu.sh)
menu.sh 是一个基于 Bash 的自动化脚本，旨在简化服务器上常用服务的安装和管理。它提供了一个交互式菜单，让您无需记住复杂的命令，即可轻松部署各种服务。

✨ 主要功能
交互式菜单: 友好的命令行界面，引导您完成各项操作。

状态动态检测: 实时显示每个服务的安装或运行状态。

一键式操作: 自动从远程仓库拉取并执行最新的安装脚本。

自更新机制: 支持一键更新 menu.sh 脚本本身。

快捷键: 支持设置 Q 或 q 为快捷键，随时调出菜单。

📥 安装与使用
您可以通过以下两种方式运行和安装 menu.sh。

方式一：临时运行 (推荐)
如果您只是想快速使用，而不想永久安装脚本，可以使用此方法。

Bash

bash <(curl -fsSL https://raw.githubusercontent.com/featherhao/test/refs/heads/main/menu.sh)
方式二：永久安装
此方法会将脚本下载到您的家目录，方便您随时调用。

Bash

curl -fsSL https://raw.githubusercontent.com/featherhao/test/refs/heads/main/menu.sh -o ~/menu.sh
chmod +x ~/menu.sh
bash ~/menu.sh
提示: 运行脚本后，您可以选择菜单中的 设置快捷键 Q / q 选项，以后只需在终端输入 q 即可快速启动菜单。

📜 脚本功能列表
以下是 menu.sh 菜单中包含的各项服务及其功能的详细说明。

菜单选项	功能描述	完整调用命令 (直接运行)
1) MoonTV	一个基于 Docker 的电视直播源分享和管理平台。	bash <(curl -fsSL https://raw.githubusercontent.com/featherhao/test/refs/heads/main/SH/mootvinstall.sh)
2) RustDesk	开源的远程桌面软件，类似 TeamViewer。	bash <(curl -fsSL https://raw.githubusercontent.com/featherhao/test/refs/heads/main/SH/install_rustdesk.sh)
3) LibreTV	另一个开源的电视直播源管理平台。	bash <(curl -fsSL https://raw.githubusercontent.com/featherhao/test/refs/heads/main/SH/install_libretv.sh)
4) 甬哥Sing-box-yg	自动化安装 Sing-box 的脚本。	bash <(curl -fsSL https://raw.githubusercontent.com/yonggekkk/sing-box-yg/main/sb.sh)
5) 勇哥ArgoSB脚本	快速安装基于 Sing-box 和 Cloudflare Argo Tunnel 的脚本。	bash <(curl -fsSL https://raw.githubusercontent.com/featherhao/test/refs/heads/main/SH/argosb.sh)
6) Kejilion.sh	一个功能丰富的 Linux 工具箱，包含多种常用脚本。	bash <(curl -fsSL https://raw.githubusercontent.com/kejilion/sh/main/kejilion.sh)
7) zjsync	GitHub 文件自动同步工具，用于同步仓库文件到指定目录。	bash <(curl -fsSL https://raw.githubusercontent.com/featherhao/test/refs/heads/main/SH/zjsync.sh)
8) Pansou	基于 Docker 的网盘搜索工具。	bash <(curl -fsSL https://raw.githubusercontent.com/featherhao/test/refs/heads/main/SH/pansou.sh)
9) 域名绑定管理	用于配置 Nginx 域名绑定和 SSL 证书的工具。	bash <(curl -fsSL https://raw.githubusercontent.com/featherhao/test/refs/heads/main/SH/nginx)
10) Subconverter	一键部署订阅转换后端 API 服务。	bash <(curl -fsSL https://raw.githubusercontent.com/featherhao/test/refs/heads/main/SH/subconverter-api.sh)
11) Poste.io	基于 Docker 的邮件服务器一键安装。	bash <(curl -fsSL https://raw.githubusercontent.com/featherhao/test/refs/heads/main/SH/Poste.io.sh)
12) Shlink	开源的短链接生成工具。	bash <(curl -fsSL https://raw.githubusercontent.com/featherhao/test/refs/heads/main/SH/install_shlink.sh)
