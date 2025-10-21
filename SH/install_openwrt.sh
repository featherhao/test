#!/bin/bash
set -euo pipefail

CONTAINER_NAME="openwrt"
DEFAULT_PASSWORD="openwrt123"

# ================== 检测架构并选择镜像 ==================
ARCH=$(uname -m)
OPENWRT_IMAGE=""

case "$ARCH" in
    aarch64)
        # 适用于 64 位 ARM 架构 (如树莓派 4B, 某些 ARM 服务器)
        # 替换为更通用的 armv8 标签，通常对应 aarch64
        OPENWRT_IMAGE="sulinggg/openwrt:armv8"
        echo "ℹ️ 检测到架构: $ARCH，使用镜像: $OPENWRT_IMAGE"
        ;;
    x86_64|amd64)
        # 适用于 64 位 x86 架构
        # 替换为更通用的 x86_64 标签
        OPENWRT_IMAGE="sulinggg/openwrt:x86_64"
        echo "ℹ️ 检测到架构: $ARCH，使用镜像: $OPENWRT_IMAGE"
        ;;
    armv7l|armhf|i386|i686)
        # 32 位架构（armv7l/i386/i686）可能需要特定的 32 位镜像标签，
        # 为了兼容性，暂时标记为不支持，避免拉取错误的 arm64/x86_64 镜像。
        echo "⚠️ 不支持的 32 位架构 ($ARCH)。请手动确认 sulinggg/openwrt 仓库中是否存在兼容的 32 位标签。"
        exit 1
        ;;
    *)
        echo "⚠️ 不支持的架构: $ARCH"
        exit 1
        ;;
esac

# ================== 功能函数 ==================

install_openwrt() {
    echo "=============================="
    echo "安装 OpenWrt 容器"
    echo "=============================="

    # 安装 Docker
    if ! command -v docker >/dev/null 2>&1; then
        echo "[*] Docker 未安装。开始安装 Docker..."
        # 检查是否是 Debian/Ubuntu 系列，如果是则使用 apt
        if command -v apt >/dev/null 2>&1; then
            sudo apt update
            sudo apt install -y docker.io
            sudo systemctl enable docker --now
        else
            echo "⚠️ 无法自动安装 Docker。请先手动安装 Docker。"
            exit 1
        fi
    fi

    # 拉取镜像
    echo "[*] 拉取镜像: $OPENWRT_IMAGE"
    if ! docker pull $OPENWRT_IMAGE; then
        echo "❌ 镜像拉取失败！请检查镜像名称 ($OPENWRT_IMAGE) 是否正确或网络是否正常。"
        exit 1
    fi

    # 删除旧容器
    if docker ps -a --format '{{.Names}}' | grep -qw "$CONTAINER_NAME"; then
        echo "[*] 已存在旧容器，删除..."
        docker rm -f $CONTAINER_NAME
    fi

    # 启动容器
    echo "[*] 启动 OpenWrt 容器..."
    # 注意：使用 --network host 时，OpenWrt 容器的 LAN IP (192.168.1.1) 会与宿主机 IP 冲突，
    # 且默认会接管宿主机的网络。这在某些环境中可能导致问题。
    # 建议在使用前确认其影响。
    docker run -d \
      --name $CONTAINER_NAME \
      --restart always \
      --network host \
      --privileged \
      $OPENWRT_IMAGE

    # 等待容器启动 (给点时间让 /bin/sh 准备好)
    sleep 3 

    # 设置 root 密码
    echo "[*] 设置 root 密码: $DEFAULT_PASSWORD"
    # 使用 bash 而不是 sh 以确保 chpasswd 命令可用
    if ! docker exec $CONTAINER_NAME /bin/bash -c "echo root:$DEFAULT_PASSWORD | chpasswd" 2>/dev/null; then
        # 尝试使用 sh
        docker exec $CONTAINER_NAME /bin/sh -c "echo root:$DEFAULT_PASSWORD | chpasswd"
    fi

    echo "✅ 安装完成！Web 管理: http://192.168.1.1"
    echo "   (注意: 如果宿主机 IP 地址不是 192.168.1.x，您需要等待 OpenWrt 接管网络后才能访问)"
}

uninstall_openwrt() {
    echo "=============================="
    echo "卸载 OpenWrt 容器"
    echo "=============================="
    if docker ps -a --format '{{.Names}}' | grep -qw "$CONTAINER_NAME"; then
        docker rm -f $CONTAINER_NAME
        echo "✅ 容器已删除"
    else
        echo "⚠️ 未检测到容器 $CONTAINER_NAME"
    fi
}

info_openwrt() {
    echo "=============================="
    echo "OpenWrt 容器信息"
    echo "=============================="
    if docker ps -a --format '{{.Names}}' | grep -qw "$CONTAINER_NAME"; then
        echo "状态:"
        docker ps -a | grep $CONTAINER_NAME
        echo "------------------------------"
        echo "架构: $ARCH"
        echo "镜像: $OPENWRT_IMAGE"
        echo "Web 管理: http://192.168.1.1"
        echo "用户名: root"
        echo "密码: $DEFAULT_PASSWORD"
    else
        echo "⚠️ 容器 $CONTAINER_NAME 未运行或不存在"
    fi
}

# ================== 菜单 ==================
while true; do
    echo "=============================="
    echo "OpenWrt 管理脚本 (基于通用标签)"
    echo "1) 安装 OpenWrt"
    echo "2) 卸载 OpenWrt"
    echo "3) 查看信息"
    echo "4) 退出"
    read -rp "请输入选择 [1-4]: " choice

    case "$choice" in
        1) install_openwrt ;;
        2) uninstall_openwrt ;;
        3) info_openwrt ;;
        4) exit 0 ;;
        *) echo "⚠️ 无效选择" ;;
    esac
done