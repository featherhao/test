#!/bin/bash
set -euo pipefail

CONTAINER_NAME="openwrt"
DEFAULT_PASSWORD="openwrt123"

# ================== 检测架构 ==================
ARCH=$(uname -m)
case "$ARCH" in
    aarch64|armv7l)
        OPENWRT_IMAGE="sulinggg/openwrt:r23.05.0-arm64"
        ;;
    x86_64|i386|i686)
        OPENWRT_IMAGE="sulinggg/openwrt:r23.05.0-x86_64"
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
        echo "[*] 安装 Docker..."
        sudo apt update
        sudo apt install -y docker.io
        sudo systemctl enable docker --now
    fi

    # 拉取镜像
    echo "[*] 拉取镜像: $OPENWRT_IMAGE"
    docker pull $OPENWRT_IMAGE

    # 删除旧容器
    if docker ps -a --format '{{.Names}}' | grep -qw "$CONTAINER_NAME"; then
        echo "[*] 已存在旧容器，删除..."
        docker rm -f $CONTAINER_NAME
    fi

    # 启动容器
    echo "[*] 启动 OpenWrt 容器..."
    docker run -d \
      --name $CONTAINER_NAME \
      --restart always \
      --network host \
      --privileged \
      $OPENWRT_IMAGE

    # 设置 root 密码
    echo "[*] 设置 root 密码: $DEFAULT_PASSWORD"
    docker exec -it $CONTAINER_NAME /bin/sh -c "echo root:$DEFAULT_PASSWORD | chpasswd"

    echo "✅ 安装完成！Web 管理: http://192.168.1.1"
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
        docker ps -a | grep $CONTAINER_NAME
        echo "架构: $ARCH"
        echo "镜像: $OPENWRT_IMAGE"
        echo "Web 管理: http://192.168.1.1"
        echo "用户名: root"
        echo "密码: $DEFAULT_PASSWORD"
    else
        echo "⚠️ 容器 $CONTAINER_NAME 未运行"
    fi
}

# ================== 菜单 ==================
while true; do
    echo "=============================="
    echo "OpenWrt 管理脚本"
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
