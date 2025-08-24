#!/bin/bash
set -e

COMPOSE_FILE=/root/compose.yml
PROJECT_NAME=rustdesk-oss
CONTAINERS=("rust_desk_hbbs" "rust_desk_hbbr")
PORTS=(21115 21116 21117)
VOLUMES=("rust_desk_hbbs_data" "rust_desk_hbbr_data")

# 释放端口
free_ports() {
    for port in "${PORTS[@]}"; do
        PID=$(lsof -tiTCP:$port -sTCP:LISTEN)
        if [ -n "$PID" ]; then
            echo "⚠️ 端口 $port 被占用，杀掉 PID: $PID"
            kill -9 $PID 2>/dev/null || true
            while lsof -tiTCP:$port -sTCP:LISTEN >/dev/null; do sleep 0.5; done
            echo "✅ 端口 $port 已释放"
        fi
    done
}

# 卸载 RustDesk OSS
uninstall_rustdesk() {
    echo "🧹 卸载 RustDesk..."
    docker compose -f $COMPOSE_FILE -p $PROJECT_NAME down --volumes 2>/dev/null || true
    for container in "${CONTAINERS[@]}"; do
        docker rm -f $container 2>/dev/null || true
    done
    for volume in "${VOLUMES[@]}"; do
        docker volume rm $volume 2>/dev/null || true
    done
    echo "✅ RustDesk 已卸载干净"
}

# 安装 RustDesk OSS
install_rustdesk() {
    echo "🐳 下载 RustDesk OSS 官方 compose 文件..."
    curl -fsSL https://raw.githubusercontent.com/ynnie/rustdesk-server/master/docker-compose.yml -o $COMPOSE_FILE
    echo "✅ 下载完成"

    free_ports
    uninstall_rustdesk

    echo "🚀 启动 RustDesk OSS 容器..."
    docker compose -f $COMPOSE_FILE -p $PROJECT_NAME up -d

    echo "⏳ 等待 hbbs 初始化..."
    sleep 5

    show_info
}

# 重启 RustDesk OSS
restart_rustdesk() {
    echo "🔄 重启 RustDesk..."
    docker compose -f $COMPOSE_FILE -p $PROJECT_NAME restart
    echo "✅ RustDesk 已重启"
}

# 查看连接信息
show_info() {
    IP=$(hostname -I | awk '{print $1}')
    echo "🌐 RustDesk 服务端连接信息："
    echo "ID Server : $IP:21115"
    echo "Relay     : $IP:21116"
    echo "API       : $IP:21117"

    HBBS_CONTAINER=$(docker ps -q -f name=rust_desk_hbbs)
    if [ -n "$HBBS_CONTAINER" ]; then
        echo "🔑 客户端 Key："
        docker exec "$HBBS_CONTAINER" cat /root/.config/rustdesk/hbbs.key 2>/dev/null || echo "未生成"
    else
        echo "客户端 Key 未生成"
    fi
}

# 菜单
while true; do
    echo "============================="
    echo "     RustDesk 服务端管理"
    echo "============================="
    STATUS=$(docker ps -q -f name=rust_desk_hbbr >/dev/null && echo "Docker 已启动 ✅" || echo "未安装 ❌")
    echo "服务端状态: $STATUS"
    echo "1) 安装 RustDesk Server OSS (Docker)"
    echo "2) 卸载 RustDesk Server"
    echo "3) 重启 RustDesk Server"
    echo "4) 查看连接信息"
    echo "0) 退出"
    read -rp "请选择操作 [0-4]: " choice
    case $choice in
        1) install_rustdesk ;;
        2) uninstall_rustdesk ;;
        3) restart_rustdesk ;;
        4) show_info ;;
        0) exit 0 ;;
        *) echo "⚠️ 无效选项" ;;
    esac
done
