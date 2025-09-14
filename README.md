🚀 服务管理中心
一个功能强大的 Bash 脚本，用于快速安装和管理各种服务器应用程序和服务。

📋 功能概述

工具名称	  功能描述	    状态检测
MoonTV	  媒体服务器和流媒体平台	  目录存在检测
RustDesk	开源远程桌面软件	目录存在检测
LibreTV	电视流媒体解决方案	目录存在检测
Sing-box-yg	甬哥开发的代理工具	二进制文件检测
ArgoSB	勇哥开发的 Argo 隧道工具	二进制文件或配置检测
Kejilion.sh	一键脚本工具箱	远程调用
zjsync	GitHub 文件自动同步工具	配置文件检测
Pansou	网盘搜索引擎	Docker 容器检测
Nginx	域名绑定管理	远程调用
Subconverter	订阅转换后端API	Docker 容器检测
Poste.io	邮件服务器	Docker 容器检测
Shlink	短链接生成服务	Docker 容器检测
🛠️ 安装方法
一键安装并运行
bash
```
bash <(curl -fsSL https://raw.githubusercontent.com/featherhao/test/main/menu.sh)
````
脚本会自动保存到 ~/menu.sh，下次可直接运行：

···
bash ~/menu.sh 
```
设置快捷命令
在菜单中选择选项 13 或直接运行：

bash
···
echo "alias Q='bash ~/menu.sh'" >> ~/.bashrc
···
echo "alias q='bash ~/menu.sh'" >> ~/.bashrc
source ~/.bashrc···
···
之后只需输入 Q 或 q 即可打开菜单。

📖 详细功能说明
1. MoonTV 安装
媒体服务器和流媒体平台。

单独安装命令：

bash```
bash <(curl -fsSL https://raw.githubusercontent.com/featherhao/test/main/SH/mootvinstall.sh)```
安装位置： /opt/moontv

功能特点：

媒体内容管理和流媒体服务

支持多种视频格式

用户友好的界面

2. RustDesk 安装
开源远程桌面软件，替代 TeamViewer 和 AnyDesk。

单独安装命令：

bash```
bash <(curl -fsSL https://raw.githubusercontent.com/featherhao/test/main/SH/install_rustdesk.sh)```
安装位置： /opt/rustdesk

功能特点：

完全开源

自托管中继服务器

跨平台支持

端到端加密

3. LibreTV 安装
电视流媒体解决方案。

单独安装命令：

bash```
bash <(curl -fsSL https://raw.githubusercontent.com/featherhao/test/main/SH/install_libretv.sh)```
安装位置： /opt/libretv

功能特点：

电视直播流媒体

节目指南

录制功能

4. 甬哥 Sing-box-yg 安装
代理工具，支持多种协议。

单独安装命令：

bash
bash <(curl -fsSL https://raw.githubusercontent.com/yonggekkk/sing-box-yg/main/sb.sh)
功能特点：

支持 VMess、VLESS、Trojan 等协议

路由规则自定义

流量统计

5. 勇哥 ArgoSB 脚本
Argo 隧道管理工具。

单独安装命令：

bash
bash <(curl -fsSL https://raw.githubusercontent.com/featherhao/test/main/SH/argosb.sh)
配置文件位置： /etc/opt/ArgoSB/config.json

功能特点：

Cloudflare Argo 隧道管理

自动更新证书

多域名支持

6. Kejilion.sh 一键脚本工具箱
多功能服务器管理工具箱。

直接运行：

bash
bash <(curl -fsSL https://raw.githubusercontent.com/kejilion/sh/main/kejilion.sh)
功能特点：

系统监控

服务管理

网络工具

安全加固

7. zjsync (GitHub 文件自动同步)
自动同步 GitHub 文件到本地。

单独安装命令：

bash
bash <(curl -fsSL https://raw.githubusercontent.com/featherhao/test/main/SH/zjsync.sh)
配置文件位置： /etc/zjsync.conf

功能特点：

定时同步 GitHub 文件

支持多个仓库

冲突处理

8. Pansou 网盘搜索
网盘资源搜索引擎。

单独安装命令：

bash
bash <(curl -fsSL https://raw.githubusercontent.com/featherhao/test/main/SH/pansou.sh)
Docker 容器名称： pansou-web

功能特点：

多网盘资源搜索

磁力链接生成

资源分享

9. 域名绑定管理
Nginx 域名管理工具。

单独运行：

bash
bash <(curl -fsSL https://raw.githubusercontent.com/featherhao/test/main/SH/nginx)
功能特点：

域名添加/删除

SSL 证书管理

反向代理配置

10. Subconverter - 订阅转换后端API
订阅转换服务。

单独安装命令：

bash
bash <(curl -fsSL https://raw.githubusercontent.com/featherhao/test/main/SH/subconverter-api.sh)
Docker 容器名称： subconverter

功能特点：

多种订阅格式转换

规则自定义

API 接口

11. Poste.io 邮件服务器
全功能邮件服务器。

单独安装命令：

bash
bash <(curl -fsSL https://raw.githubusercontent.com/featherhao/test/main/SH/Poste.io.sh)
Docker 容器名称： posteio

功能特点：

Webmail 界面

反垃圾邮件

DKIM/DMARC 支持

多域名管理

12. Shlink 短链接生成
URL 短链接服务。

单独安装命令：

bash
bash <(curl -fsSL https://raw.githubusercontent.com/featherhao/test/main/SH/install_shlink.sh)
Docker 容器名称： shlink-web

功能特点：

URL 缩短

点击统计

QR 码生成

API 支持

🔄 更新菜单脚本
菜单本身可以通过选项 U 更新，或直接运行：

bash
bash ~/menu.sh U
或手动更新：

bash
curl -fsSL https://raw.githubusercontent.com/featherhao/test/main/menu.sh -o ~/menu.sh
chmod +x ~/menu.sh
🗑️ 卸载方法
卸载特定服务
每个服务的卸载方法不同，请参考各自服务的文档或脚本。

完全卸载菜单
bash
rm -f ~/menu.sh
# 从 shell 配置文件中删除别名
sed -i '/alias Q=/d' ~/.bashrc
sed -i '/alias q=/d' ~/.bashrc
❓ 常见问题
1. 脚本执行权限问题
如果遇到权限错误，请运行：

bash
chmod +x ~/menu.sh
2. Docker 容器无法启动
确保 Docker 已安装并运行：

bash
# 检查 Docker 状态
systemctl status docker

# 启动 Docker
systemctl start docker
3. 网络连接问题
如果 curl 下载失败，请检查网络连接或尝试使用代理。

4. 脚本更新后问题
如果更新后出现问题，可以删除并重新下载：

''''
rm -f ~/menu.sh
bash <(curl -fsSL https://raw.githubusercontent.com/featherhao/test/main/menu.sh)
'''