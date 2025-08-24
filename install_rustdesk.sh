#!/bin/bash
# RustDesk OSS 管理脚本
# 支持 Docker 自动安装/卸载/重启/查看信息

# 默认端口
ID_PORT=21115
RELAY_PORT=21116
API_PORT=21117

COMPOSE_FILE=/root/compose.yml
PROJECT_NAME=rustdesk-oss

# 获取本机 IPv4
get_ip() {
    IP=$(hostname -I | awk '{print $1}')
    [ -z "$IP" ] && IP="127.0.0.1"
    echo "$IP"
}

# 检查 Docker 是否安装
check_docker() {
    if ! command -v docker >/dev/null 2>&1; then
        echo "❌ Docker 未安装，请先安装 Docker"
        exit 1
    fi
}

# 释放端口
free_ports() {
    for port in $ID_PORT $RELAY_PORT $API_PORT; do
        PID=$(lsof -tiTCP:$port -sTCP:LISTEN)
        if [ -n "$PID" ]; then
            echo "⚠️ 端口 $port 被占用，杀掉 PID: $PID"
            kill -9 $PID 2>/dev/null || true
            # 等待端口释放
            while lsof -tiTCP:$port -sTCP:LISTEN >/dev/null; do
                sleep 0.5
            done
            echo "✅ 端口 $port 已释放"
        fi
    done
}

# 下载 docker-compose.yml
download_compose() {
    echo "🐳 下载 RustDesk OSS 官方 compose 文件..."
    curl -fsSL https://raw.githubusercontent.com/ynnie/rustdesk-server/master/docker-compose.yml -o $COMPOSE_FILE
    if [ $? -eq 0 ]; then
        echo "✅ 下载完成"
    else
        echo "❌ 下载失败，请检查网络"
        exit 1
    fi
}

# 启动容器
start_containers() {
    free_ports
    echo "🚀 启动 RustDesk OSS 容器..."
    docker compose -f $COMPOSE_FILE -p $PROJECT_NAME up -d
    sleep 2
    echo "⏳ 等待 hbbs 初始化..."
    sleep 5
}

# 获取客户端 Key（可选）
get_client_key() {
    CONTAINER=$(docker ps -q -f name=rust_desk_hbbs)
    if [ -n "$CONTAINER" ]; then
        KEY=$(docker exec "$CONTAINER" cat /root/.config/rustdesk/hbbs.key 2>/dev/null || echo "未生成")
    else
        KEY="未生成"
    fi
    echo "$KEY"
}

# 显示连接信息
show_info() {
    IP=$(get_ip)
    echo "🌐 RustDesk 服务端连接信息："
    echo "ID Server : $IP:$ID_PORT"
    echo "Relay     : $IP:$RELAY_PORT"
    echo "API       : $IP:$API_PORT"
    echo
    echo "🔑 客户端 Key：$(get_client_key)"
}

# 卸载
uninstall() {
    echo "⚠️ 停止并卸载 RustDesk OSS..."
    docker compose -f $COMPOSE_FILE -p $PROJECT_NAME down
    echo "✅ 已卸载"
}

# 重启
restart() {
    docker compose -f $COMPOSE_FILE -p $PROJECT_NAME restart
    echo "✅ 已重启"
}

# 菜单
while true; do
    echo "============================="
    echo "     RustDesk 服务端管理"
    echo "============================="
    STATUS=$(docker ps -q -f name=rust_desk_hbbs)
    if [ -n "$STATUS" ]; then
        echo "服务端状态: Docker 已启动 ✅"
    else
        echo "服务端状态: 未安装 ❌"
    fi
    echo "1) 安装 RustDesk Server OSS (Docker)"
    echo "2) 卸载 RustDesk Server"
    echo "3) 重启 RustDesk Server"
    echo "4) 查看连接信息"
    echo "5) 退出"
    read -p "请选择操作 [1-5]: " opt
    case $opt in
        1)
            check_docker
            download_compose
            start_containers
            show_info
            ;;
        2)
            uninstall
            ;;
        3)
            restart
            ;;
        4)
            show_info
            ;;
        5)
            exit 0
            ;;
        *)
            echo "❌ 无效选项"
            ;;
    esac
done
