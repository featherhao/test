
菜单：
bash <(curl -fsSL https://raw.githubusercontent.com/featherhao/test/refs/heads/main/menu.sh)


域名调取：bash <(curl -fsSL https://sh.qqy.pp.ua)

bash <(curl -fsSL "https://raw.githubusercontent.com/featherhao/test/refs/heads/main/menu.sh?$(date +%s)")


MOONTV安装：
bash <(curl -fsSL "https://raw.githubusercontent.com/featherhao/test/refs/heads/main/mootvinstall.sh?$(date +%s)")


subconverter -api后端安装：
bash <(curl -fsSL https://raw.githubusercontent.com/featherhao/test/refs/heads/main/subconverter-api.sh)


https://raw.githubusercontent.com/featherhao/test/refs/heads/main/menu.sh
shLINK订阅转换安装

bash <(curl -fsSL "https://raw.githubusercontent.com/featherhao/test/refs/heads/main/shlink.sh?$(date +%s)")
https://raw.githubusercontent.com/featherhao/test/refs/heads/main/shlink.sh


  更新：mtv：
  bash <(curl -fsSL https://raw.githubusercontent.com/featherhao/test/refs/heads/main/updatemtv.sh)

  
  cd /opt/moontv
  curl -fsSL https://raw.githubusercontent.com/featherhao/test/refs/heads/main/install.sh
  bash install.sh
  docker compose pull
  docker compose up -d


  
2： _rustdesk
  bash <(curl -fsSL https://raw.githubusercontent.com/featherhao/test/refs/heads/main/install_rustdesk.sh)

   bash <(curl -fsSL https://raw.githubusercontent.com/featherhao/test/refs/heads/main/install_rustdesk.sh?$(date +%s)")

  https://raw.githubusercontent.com/featherhao/test/refs/heads/main/install_rustdesk.sh



# 🚀 menu.sh 使用说明

## 概述
`menu.sh` 是一个集中管理 VPS 服务的脚本，支持：
- MoonTV 容器管理
- RustDesk 服务端安装
- LibreTV 安装
- Sing-box 协议管理
- ArgoSB 协议管理
- zjsync GitHub 文件自动同步
- Kejilion 一键脚本工具箱
- 快捷键 Q/q 调用

脚本支持多 VPS 环境，SSH 与 cron 环境均可使用。  

---

## 快速运行

### 临时运行
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/featherhao/test/refs/heads/main/menu.sh)
```

# 🚀 menu.sh 使用说明

## 概述
`menu.sh` 是一个集中管理 VPS 服务的脚本，支持：
- MoonTV 容器管理
- RustDesk 服务端安装
- LibreTV 安装
- Sing-box 协议管理
- ArgoSB 协议管理
- zjsync GitHub 文件自动同步
- Kejilion 一键脚本工具箱
- 快捷键 Q/q 调用

脚本支持多 VPS 环境，SSH 与 cron 环境均可使用。  

---

## 快速运行

### 临时运行
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/featherhao/test/refs/heads/main/menu.sh)

````
脚本会自动检测并保存到 $HOME/menu.sh，以后可以直接运行：


````
bash ~/menu.sh
````
或者通过快捷键：
`````

````
Q 或 q
`````
主菜单功能说明
1) MoonTV 管理
管理 MoonTV 容器环境

安装/升级/卸载/查看状态

2) RustDesk 管理
安装 RustDesk 服务端

卸载/升级/查看运行状态

3) LibreTV 安装
安装 LibreTV 服务

检查运行状态

4) 甬哥 Sing-box 管理
管理 Sing-box 协议节点

支持动态增删节点

显示节点信息

5) 勇哥 ArgoSB 脚本
增量添加协议节点

查看节点信息

自定义协议变量更新

更新/重启/卸载 ArgoSB

切换 IPv4/IPv6 节点显示

6) Kejilion.sh 一键脚本工具箱
远程调用 Kejilion 工具箱脚本

7) zjsync（GitHub 文件自动同步）
支持 Token/SSH 模式

自动生成文件并显示前几行

任务列表显示完整 URL 和序号

删除任务时同步移除 crontab

防止重复任务

适用多 VPS、SSH 与 cron 环境

9) 设置快捷键 Q / q
设置后可以直接使用 Q 或 q 快捷启动 menu.sh

U) 更新菜单脚本
自动更新 menu.sh 到最新版本

0) 退出
退出菜单

使用示例

添加 zjsync 同步任务
选择 7) zjsync

添加任务编号

输入 GitHub 文件 URL（私人库请使用 Token）

指定保存目录和文件名

设置同步间隔

选择访问方式（Token / SSH）

验证 Token（如选择 Token）

文件生成后立即显示路径和前几行内容

删除 zjsync 任务
显示任务列表及序号

输入序号删除任务，同时移除 crontab

查看 zjsync 任务
显示任务编号、名称和完整 GitHub URL

快捷键说明
Q / q：快速启动 menu.sh

可在不同 VPS 或不同用户环境下使用

注意事项
脚本依赖 bash、curl 或 wget

Token 仅用于私人 GitHub 仓库访问

确保保存目录有写权限

任务添加后会自动加入 cron 定时同步

脚本运行后会在 $HOME/zjsync_logs 生成日志文件

文件结构示例
bash
复制
编辑
$HOME/menu.sh
/opt/moontv/
    docker-compose.yml
/opt/rustdesk/
/opt/libretv/
/usr/local/bin/zjsync-<文件名>.sh
/etc/zjsync.conf
$HOME/zjsync_logs/






  🌀 zjsync（GitHub 文件自动同步）

功能：将 GitHub 仓库文件定时同步到 VPS 网站目录

用法：

zjsync.sh


按提示输入：

GitHub 文件地址（如 https://github.com/xxx/xxx/blob/main/file）

保存目录（默认 /var/www/zj）

保存文件名（默认自动加 .txt）

同步间隔分钟数（默认 5 分钟）

结果：文件会自动定时更新，可通过网站直接访问。
