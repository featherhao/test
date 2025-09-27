#!/bin/bash
###
# @Author: YourName
# @Date: 2025-09-27
# @Description: VPS 容器及残留清理脚本
###

set -Eeuo pipefail

# ================== 彩色定义 ==================
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

info()  { echo -e "${green}[INFO]${plain} $*"; }
warn()  { echo -e "${yellow}[WARN]${plain} $*"; }
error() { echo -e "${red}[ERROR]${plain} $*" >&2; }

# ================== 主功能 ==================
echo "🚀 VPS 容器与残留清理工具"
echo "===================================="

# 列出所有容器
docker ps -a --format "table {{.ID}}\t{{.Names}}\t{{.Status}}\t{{.Image}}\t{{.Ports}}"

read -rp "是否停止所有正在运行的容器？ [y/N]: " stop_choice
if [[ "$stop_choice" =~ ^[Yy]$ ]]; then
    running_containers=$(docker ps -q)
    if [[ -n "$running_containers" ]]; then
        docker stop $running_containers
        info "已停止所有容器"
    else
        warn "没有正在运行的容器"
    fi
fi

echo ""
docker ps -a --format "table {{.ID}}\t{{.Names}}\t{{.Status}}"
read -rp "请输入要删除的容器名称或ID，用空格分隔（直接回车删除所有已停止容器）: " containers_to_remove
if [[ -z "$containers_to_remove" ]]; then
    containers_to_remove=$(docker ps -a -q --filter "status=exited")
fi
if [[ -n "$containers_to_remove" ]]; then
    docker rm $containers_to_remove
    info "容器删除完成"
else
    warn "没有需要删除的容器"
fi

echo ""
docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.Size}}"
read -rp "是否删除未使用的镜像？ [y/N]: " prune_img
[[ "$prune_img" =~ ^[Yy]$ ]] && docker image prune -a -f && info "未使用镜像已清理"

echo ""
docker volume ls
read -rp "是否删除未使用的卷？ [y/N]: " prune_vol
[[ "$prune_vol" =~ ^[Yy]$ ]] && docker volume prune -f && info "未使用卷已清理"

echo ""
docker network ls
read -rp "是否删除未使用的 Docker 网络？ [y/N]: " prune_net
[[ "$prune_net" =~ ^[Yy]$ ]] && docker network prune -f && info "未使用网络已清理"

# 清理残留 systemd 服务
echo ""
echo "检查常见残留 systemd 服务..."
services=(/etc/systemd/system/mtg.service /etc/systemd/system/subconverter.service /etc/systemd/system/shlink.service)
for svc in "${services[@]}"; do
    if [[ -f "$svc" ]]; then
        read -rp "检测到残留服务 $svc，是否删除？ [y/N]: " del_svc
        if [[ "$del_svc" =~ ^[Yy]$ ]]; then
            systemctl stop $(basename $svc .service) || true
            systemctl disable $(basename $svc .service) || true
            rm -f "$svc"
            info "已删除 $svc"
        fi
    fi
done

echo ""
info "VPS 清理完成！"
docker ps -a
read -rp "按任意键返回主菜单..."
