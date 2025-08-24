#!/bin/bash
set -e

WORKDIR=/root
COMPOSE_FILE=$WORKDIR/compose.yml

RUSTDESK_PORTS=(21115 21116 21117)

# 清理占用端口的旧进程
cleanup_ports() {
    echo "⚠️ 检查并清理占用端口..."
    for port in "${RUSTDESK_PORTS[@]}"; do
        PIDS=$(lsof -tiTCP:$port -sTCP:LISTEN)
        if [ -n "$PIDS" ]; then
            echo "端口 $port 被占用，杀掉 PID: $PIDS"
            sudo kill -9 $PIDS
        fi
    done
}

# 下载官方 docker-compose 文件
download_compose() {
    echo "⬇️  下载官方 compose 文件..."
    curl -fsSL https://raw.githubusercontent.com/ynnie/rustdesk-server/master/docker-compose.yml -o $COMPOSE_FILE
    echo "✅ 下载完成"
}

# 停止并清理旧容器
cleanup_containers() {
    echo "⚠️ 停止并清理旧容器..."
    docker compose -f $COMPOSE_FILE down || true
}

# 安装 RustDesk OSS
install_rustdesk() {
    cleanup_ports
    download_compose
    cleanup_containers

    echo "🚀 启动容器..."
    docker compose -f $COMPOSE_FILE up -d

    echo "📜 查看 hbbs 日志（按 Ctrl+C 停止）..."
    docker compose -f $COMPOSE_FILE logs -f hbbs
}

# 查看连接信息
show_info() {
    echo "🌐 RustDesk 服务端连接信息："
    # 获取公网 IP
    IP=$(curl -s ifconfig.me)
    echo "公网 IPv4: $IP"
    echo "ID Server : $IP:21115"
    echo "Relay     : $IP:21116"
    echo "API       : $IP:21117"
    echo ""
    echo "🔑 客户端可用 Key: （请查看 hbbs 日志中的 Key）"
}

# 主菜单
while true; do
    echo "============================="
    echo "     RustDesk 服务端管理"
    echo "============================="
    echo "服务端状态: Docker"
    echo "1) 安装 RustDesk Server OSS (Docker)"
    echo "2) 卸载 RustDesk Server"
    echo "3) 重启 RustDesk Server"
    echo "4) 查看连接信息"
    echo "5) 退出"
    read -p "请选择操作 [1-5]: " choice
    case $choice in
        1) install_rustdesk ;;
        2) cleanup_containers ;;
        3) docker compose -f $COMPOSE_FILE restart ;;
        4) show_info ;;
        5) exit 0 ;;
        *) echo "无效选项" ;;
    esac
done
