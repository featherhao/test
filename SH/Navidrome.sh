#!/bin/bash

# 确保脚本以 root 权限运行
if [ "$EUID" -ne 0 ]; then
  echo "请使用 root 权限运行此脚本 (例如: sudo bash install.sh)"
  exit 1
fi

# 配置变量
INSTALL_DIR="/opt/navidrome"
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

# 显示访问地址
show_access_info() {
    local ip
    ip=$(get_local_ip)
    echo "=================================================="
    echo " Navidrome 已成功运行！"
    echo " 访问地址: http://$ip:4533"
    echo "=================================================="
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

    echo "==> 创建安装目录: $INSTALL_DIR"
    mkdir -p "$INSTALL_DIR"
    
    # 提示用户输入音乐目录路径
    read -p "请输入您的本地音乐库绝对路径 (默认: /data/music): " MUSIC_PATH
    MUSIC_PATH=${MUSIC_PATH:-"/data/music"}

    echo "==> 正在生成 docker-compose.yml 文件..."
    cat <<EOF > "$COMPOSE_FILE"
services:
  navidrome:
    image: deluan/navidrome:latest
    container_name: navidrome
    user: "1000:1000"
    ports:
      - "4533:4533"
    restart: unless-stopped
    environment:
      - ND_LOGLEVEL=info
    volumes:
      - "$INSTALL_DIR/data:/data"
      - "$MUSIC_PATH:/music:ro"
EOF

    echo "==> 正在启动 Navidrome 容器..."
    cd "$INSTALL_DIR" || exit
    if docker compose version &> /dev/null; then
        docker compose up -d
    else
        docker-compose up -d
    fi

    show_access_info
}

# 更新函数
do_update() {
    if [ ! -d "$INSTALL_DIR" ]; then
        echo "错误: 未检测到 Navidrome 安装目录 ($INSTALL_DIR)，请先安装。"
        exit 1
    fi

    echo "==> 正在更新 Navidrome..."
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
    echo "==> 正在准备卸载 Navidrome..."
    read -p "是否同时删除所有配置和数据库数据？[y/N]: " DELETE_DATA

    if [ -d "$INSTALL_DIR" ]; then
        cd "$INSTALL_DIR" || exit
        if docker compose version &> /dev/null; then
            docker compose down
        else
            docker-compose down
        fi
    fi

    if [[ "$DELETE_DATA" =~ ^[Yy]$ ]]; then
        rm -rf "$INSTALL_DIR"
        echo "==> 数据及安装目录已完全清除。"
    else
        echo "==> 容器已停止，数据目录保留在: $INSTALL_DIR"
    fi

    echo "==> Navidrome 卸载完成。"
}

# 菜单选择
echo "========================================"
echo "      Navidrome 一键管理脚本            "
echo "========================================"
echo " 1. 安装 Navidrome"
echo " 2. 更新 Navidrome"
echo " 3. 卸载 Navidrome"
echo "========================================"
read -p "请选择操作 [1-3]: " CHOICE

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
    *)
        echo "无效的选择，请输入 1、2 或 3。"
        exit 1
        ;;
esac
