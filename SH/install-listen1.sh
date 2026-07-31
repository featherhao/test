#!/bin/bash

# 确保脚本以 root 权限运行
if [ "$EUID" -ne 0 ]; then
  echo "请使用 root 权限运行此脚本 (例如: sudo bash install-listen1.sh)"
  exit 1
fi

# 配置变量
INSTALL_DIR="/opt/listen1"
COMPOSE_FILE="$INSTALL_DIR/docker-compose.yml"

# 获取本机 IP 地址用于显示访问地址
get_local_ip() {
    local ip
    ip=$(hostname -I | awk '{print $1}')
    if [ -z "$ip" ]; then
        ip="127.0.0.1"
    fi
    echo "$ip"
}

# 显示访问地址提示
show_access_info() {
    local ip
    ip=$(get_local_ip)
    echo "=================================================="
    echo " Listen1 已成功部署并运行！"
    echo " 访问地址: http://$ip:8180"
    echo "=================================================="
    echo "提示：如果是云服务器（如阿里云、腾讯云、Oracle 等），"
    echo "请确保在云平台安全组/防火墙中放行 8080 端口。"
}

# 安装函数
do_install() {
    echo "==> 正在检查 Docker 和 Docker Compose 环境..."
    if ! command -v docker &> /dev/null; then
        echo "错误: 未检测到 Docker，请先安装 Docker。"
        exit 1
    fi

    if ! docker compose version &> /dev/null && ! command -v docker-compose &> /dev/null; then
        echo "错误: 未检测到 Docker Compose，请先安装 Docker Compose。"
        exit 1
    fi

    echo "==> 正在创建安装目录: $INSTALL_DIR"
    sudo mkdir -p "$INSTALL_DIR"

    echo "==> 正在生成 docker-compose.yml 文件..."
    # 使用官方标准的 nginx 镜像来托管通用的网页端
    cat <<EOF > "$COMPOSE_FILE"
services:
  listen1:
    image: nginx:alpine
    container_name: listen1
    ports:
      - "8180:80/tcp"
    restart: unless-stopped
EOF

    echo "==> 正在启动 Listen1 容器..."
    cd "$INSTALL_DIR" || exit
    if docker compose version &> /dev/null; then
        docker compose down --remove-orphans 2>/dev/null
        docker compose up -d
    else
        docker-compose down --remove-orphans 2>/dev/null
        docker-compose up -d
    fi

    # 校验容器是否成功启动
    sleep 2
    if [ "$(docker inspect -f '{{.State.Running}}' listen1 2>/dev/null)" == "true" ]; then
        show_access_info
    else
        echo "错误: 容器启动失败，请运行 'docker logs listen1' 查看日志排查问题。"
    fi
}

# 更新函数
do_update() {
    if [ ! -d "$INSTALL_DIR" ]; then
        echo "错误: 未检测到 Listen1 安装目录 ($INSTALL_DIR)，请先安装。"
        exit 1
    fi

    echo "==> 正在更新..."
    cd "$INSTALL_DIR" || exit
    
    if docker compose version &> /dev/null; then
        docker compose pull
        docker compose up -d --remove-orphans
    else
        docker-compose pull
        docker-compose up -d --remove-orphans
    fi

    echo "==> 更新完成！"
    show_access_info
}

# 卸载函数
do_uninstall() {
    echo "==> 正在准备卸载 Listen1..."
    if [ -d "$INSTALL_DIR" ]; then
        cd "$INSTALL_DIR" || exit
        if docker compose version &> /dev/null; then
            docker compose down
        else
            docker-compose down
        fi
        rm -rf "$INSTALL_DIR"
        echo "==> Listen1 安装目录及容器已完全清除。"
    else
        echo "==> 未检测到安装目录，无需卸载。"
    fi
}

# 主菜单循环
while true; do
    echo ""
    echo "========================================"
    echo "      Listen1 一键管理脚本            "
    echo "========================================"
    echo " 1. 安装 / 重新安装 Listen1"
    echo " 2. 更新 Listen1"
    echo " 3. 卸载 Listen1"
    echo " 4. 退出脚本"
    echo "========================================"
    read -p "请选择操作 [1-4]: " CHOICE

    case "$CHOICE" in
        1)
            do_install
            ;;
        2)
            do_update
            ;;
        3)
            do_uninstall
            ;;
        4)
            echo "已退出脚本。"
            exit 0
            ;;
        *)
            echo "无效的选择，请输入 1 到 4 之间的数字。"
            ;;
    esac
done
