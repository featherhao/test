#!/bin/bash
###
# @Author: YourName
# @Date: 2025-09-27
# @Description: VPS 容器及残留清理脚本（优化逻辑：优先删除已停止容器）
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

# ------------------ 显示容器 ------------------
echo ""
info "当前正在运行的容器："
docker ps --format "table {{.ID}}\t{{.Names}}\t{{.Status}}\t{{.Image}}\t{{.Ports}}"

echo ""
info "当前已停止的容器："
docker ps -a --filter "status=exited" --format "table {{.ID}}\t{{.Names}}\t{{.Status}}\t{{.Image}}"

# ------------------ 删除已停止容器 ------------------
stopped_containers=$(docker ps -a -q --filter "status=exited")
if [[ -n "$stopped_containers" ]]; then
    read -rp "是否删除所有已停止的容器？ [y/N]: " del_stopped
    if [[ "$del_stopped" =~ ^[Yy]$ ]]; then
        docker rm $stopped_containers
        info "已删除所有已停止容器"
    fi
else
    warn "没有已停止的容器"
fi

# ------------------ 停止并删除运行中的容器 ------------------
running_containers=$(docker ps -q)
if [[ -n "$running_containers" ]]; then
    read -rp "是否停止并删除正在运行的容器？ [y/N]: " stop_del_running
    if [[ "$stop_del_running" =~ ^[Yy]$ ]]; then
        docker stop $running_containers
        docker rm $running_containers
        info "已停止并删除所有运行容器"
    fi
else
    warn "没有正在运行的容器"
fi

# ------------------ 清理镜像 ------------------
echo ""
docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.Size}}"
read -rp "是否删除未使用的镜像？ [y/N]: " prune_img
[[ "$prune_img" =~ ^[Yy]$ ]] && docker image prune -a -f && info "未使用镜像已清理"

# ------------------ 清理卷 ------------------
echo ""
docker volume ls
read -rp "是否删除未使用的卷？ [y/N]: " prune_vol
[[ "$prune_vol" =~ ^[Yy]$ ]] && docker volume prune -f && info "未使用卷已清理"

# ------------------ 清理网络 ------------------
echo ""
docker network ls
read -rp "是否删除未使用的 Docker 网络？ [y/N]: " prune_net
[[ "$prune_net" =~ ^[Yy]$ ]] && docker network prune -f && info "未使用网络已清理"

# ------------------ 清理残留 systemd 服务 ------------------
echo ""
info "检查常见残留 systemd 服务..."
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
