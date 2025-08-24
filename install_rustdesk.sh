#!/bin/bash
set -e

COMPOSE_FILE=/root/compose.yml
PROJECT_NAME=rustdesk-oss

# 检查并释放端口
free_ports() {
    for port in 21115 21116 21117; do
        PID=$(lsof -tiTCP:$port -sTCP:LISTEN)
        if [ -n "$PID" ]; then
            echo "⚠️ 端口 $port 被占用，杀掉 PID: $PID"
            kill -9 $PID 2>/dev/null || true
            while lsof -tiTCP:$port -sTCP:LISTEN >/dev/null; do
                sleep 0.5
            done
            echo "✅ 端口 $port 已释放"
        fi
    done
}

# 安装 RustDesk OSS
install_rustdesk() {
    echo "🐳 下载 RustDesk OSS 官方 compose 文件..."
    curl -fsSL https://raw.githubusercontent.com/ynnie/rustdesk-server/master/docker-compose.yml -o $COMPOSE_FILE
    echo "✅ 下载完成"

    free_ports

    # 删除可能存在的旧容器
    docker rm -f rust_desk_hbbs rust_desk_hbbr 2>/dev/null || true

    echo "🚀 启动 RustDesk OSS 容器..."
    docker compose -f $COMPOSE_FILE -p $PROJECT_NAME up -d

    echo "⏳ 等待 hbbs 初始化..."
    sleep 5

    IP=$(hostname -I | awk '{print $1}')
    echo "🌐 RustDesk 服务端连接信息："
    echo "ID Server : $IP:21115"
    echo "Relay     : $IP:21116"
    echo "API       : $IP:21117"

    echo "🔑 客户端 Key（可能稍后生成）："
    CONTAINER=$(docker ps -q -f name=rust_desk_hbbs)
    if [ -n "$CONTAINER" ]; then
        docker exec "$CONTAINER" cat /root/.config/rustdesk/hbbs.key 2>/dev/null || echo "未生成"
    else
        echo "未生成"
    fi
}

# 卸载 RustDesk OSS
uninstall_rustdesk() {
    docker compose -f $COMPOSE_FILE -p $PROJECT_NAME down --volumes
    echo "✅ RustDesk 已卸载"
}

# 重启 RustDesk OSS
restart_rustdesk() {
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

    CONTAINER=$(docker ps -q -f name=rust_desk_hbbs)
    if [ -n "$CONTAINER" ]; then
        echo "🔑 客户端 Key："
        docker exec "$CONTAINER" cat /root/.config/rustdesk/hbbs.key 2>/dev/null || echo "未生成"
    else
        echo "客户端 Key 未生成"
    fi
}

# 菜单
while true; do
    echo "============================="
    echo "     RustDesk 服务端管理"
    echo "============================="
    echo "服务端状态: $(docker ps -q -f name=rust_desk_hbbr >/dev/null && echo 'Docker 已启动 ✅' || echo '未安装 ❌')"
    echo "1) 安装 RustDesk Server OSS (Docker)"
    echo "2) 卸载 RustDesk Server"
    echo "3) 重启 RustDesk Server"
    echo "4) 查看连接信息"
    echo "5) 退出"
    read -rp "请选择操作 [1-5]: " choice
    case $choice in
        1) install_rustdesk ;;
        2) uninstall_rustdesk ;;
        3) restart_rustdesk ;;
        4) show_info ;;
        5) exit 0 ;;
        *) echo "⚠️ 无效选项" ;;
    esac
done
