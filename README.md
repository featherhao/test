#!/bin/bash

# 此脚本用于在终端中显示完整的 README.md 文件内容。
# 您可以直接复制并执行。

cat << 'EOF'
# 🚀 服务管理中心 (menu.sh)

`menu.sh` 是一个基于 Bash 的自动化脚本，旨在简化服务器上常用服务的安装和管理。它提供了一个交互式菜单，让您无需记住复杂的命令，即可轻松部署各种服务。

## ✨ 主要功能

* **交互式菜单:** 友好的命令行界面，引导您完成各项操作。
* **状态动态检测:** 实时显示每个服务的安装或运行状态。
* **一键式操作:** 自动从远程仓库拉取并执行最新的安装脚本。
* **自更新机制:** 支持一键更新 `menu.sh` 脚本本身。
* **快捷键:** 支持设置 `Q` 或 `q` 为快捷键，随时调出菜单。

## 📥 安装与使用

您可以通过以下两种方式运行和安装 `menu.sh`。

### 方式一：临时运行 (推荐)

如果您只是想快速使用，而不想永久安装脚本，可以使用此方法。

```bash
bash <(curl -fsSL [https://raw.githubusercontent.com/featherhao/test/refs/heads/main/menu.sh](https://raw.githubusercontent.com/featherhao/test/refs/heads/main/menu.sh))