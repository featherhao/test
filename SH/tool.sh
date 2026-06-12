#!/bin/bash
# ====================================================
# 脚本路径: /usr/local/bin/tool
# 脚本功能: 小主机代理命令手册及快捷管理
# ====================================================
# 【快捷命令配置说明 (必须写入 ~/.bashrc 才能生效)】
# 请确保以下内容已加入到 /root/.bashrc 中：
#
# alias proxyon='export http_proxy="http://192.168.51.88:7890"; export https_proxy="http://192.168.51.88:7890"; export no_proxy="localhost,127.0.0.1,192.168.51.88,192.168.51.0/24,status.moontv.top"; echo "终端代理已开启 (已切换至 .88 IP 并排除局域网)"'
# alias proxyoff='unset http_proxy;unset https_proxy;echo "终端代理已关闭"'
#
# ====================================================
# 【使用方法说明】
# 1. 菜单主界面: 
#    直接输入 `tool` 即可弹出代理状态和命令手册。
#
# 2. 终端代理 (仅限当前窗口有效):
#    - 开启: proxyon  (用于 curl/wget 下载脚本、apt 系统更新)
#    - 关闭: proxyoff (恢复直连模式)
#
# 3. Docker 代理 (全局永久生效):
#    - 开启: dkproxy on  (解决 docker pull 镜像拉不动)
#    - 关闭: dkproxy off (恢复官方源拉取)
# ====================================================
# 定义颜色
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}====================================================${NC}"
echo -e "           🛠️  小主机代理命令手册 (Manual)           "
echo -e "${BLUE}====================================================${NC}"

echo -e "${YELLOW}[ 1. 终端代理 (仅限当前窗口有效) ]${NC}"
echo -e " proxyon  - 开启代理。用于 curl/wget 下载脚本、apt 系统更新。"
echo -e " proxyoff - 关闭代理。恢复直连模式。"
echo ""

echo -e "${YELLOW}[ 2. Docker 代理 (全局永久生效) ]${NC}"
echo -e " dkproxy on  - 开启代理。用于解决 docker pull 镜像拉不动。"
echo -e " dkproxy off - 关闭代理。恢复官方源拉取。"
echo ""

# --- 重点修改的第三部分 ---
echo -e "${YELLOW}[ 3. 检查状态 ]${NC}"

# 检查终端环境变量
if [ -z "$http_proxy" ]; then
    echo -e " 终端代理状态: ${RED}已关闭${NC}"
else
    echo -e " 终端代理状态: ${GREEN}已开启${NC} ($http_proxy)"
fi

# 检查 Docker 配置文件
if [ -f "/etc/systemd/system/docker.service.d/http-proxy.conf" ]; then
    echo -e " Docker 代理状态: ${GREEN}已开启${NC}"
else
    echo -e " Docker 代理状态: ${RED}已关闭${NC}"
fi

echo -e "${BLUE}====================================================${NC}"
