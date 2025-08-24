#!/bin/bash
set -e

# RustDesk OSS 默认端口
ID_PORT=21115
RELAY_PORT=21116
API_PORT=21117

# Docker Compose 文件 URL
COMPOSE_URL="https://raw.githubusercontent.com/ynnie/rustdesk-server/master/docker-compose.yml"
COMPOSE_FILE="/root/rustdesk-oss-compose.yml"

# 获取公网 IP
get_ip() {
    ip addr | awk '/inet / && !/127.0.0.1/ {print $2}' | cut -d/ -f1 | head -n1
}

# 检查并杀掉占用端口的进程
free_ports() {
    for port in $ID_PORT $RELAY_PORT $API_PORT; do
        pid=$(lsof -iTCP:$port -sTCP:LISTEN -t || true)
        if [ -n "$pid" ]; then
            echo "⚠️ 端口 $port 被占用，杀掉 PID: $pid"
            kill -9 $pid
        fi
    done
}

# 清理旧容器和卷
cleanup() {
    echo "⚠️ 清理旧容器、网络和卷..."
    docker stop rust_desk_hbbr rust_desk_hbbs 2>/dev/null || true
    docker rm rust_desk_hbbr rust_desk_hbbs 2>/dev/null || true
    docker network rm rustdesk-oss_rust_desk_net 2>/dev/null || true
    docker volume rm rust_desk_hbbr_data rust_desk_hbbs_data 2>/dev/null || true
    echo "✅ 清理完成"
}

# 下载 compose 文件
download_compose() {
    echo "⬇️ 下载 RustDesk OSS 官方 compose 文件..."
    curl -fsSL "$COMPOSE_URL" -o "$COMPOSE_FILE"
    echo "✅ 下载完成"
}

# 安装 RustDesk OSS
install_rustdesk() {
    free_ports
    cleanup
    download_compose

    echo "🚀 启动 RustDesk OSS 容器..."
    docker compose -f $COMPOSE_FILE up -d

    echo "📜 查看 hbbs 日志（按 Ctrl+C 停止）..."
    docker logs -f rust_desk_hbbs &
    sleep 5

    IP=$(get_ip)
    echo -e "\n✅ 安装完成"
    echo "🌐 RustDesk 服务端连接信息："
    echo "ID Server : $IP:$ID_PORT"
    echo "Relay     : $IP:$RELAY_PORT"
    echo "API       : $IP:$API_PORT"

    KEY=$(docker exec rust_desk_hbbs cat /root/id_ed25519.pub 2>/dev/null || echo "未生成")
    echo "🔑 客户端 Key: $KEY"
}

# 卸载 RustDesk
uninstall_rustdesk() {
    cleanup
    echo "✅ RustDesk 已卸载"
}

# 重启 RustDesk
restart_rustdesk() {
    docker compose -f $COMPOSE_FILE restart
    echo "✅ RustDesk 已重启"
}

# 查看连接信息
show_info() {
    IP=$(get_ip)
    echo "🌐 RustDesk 服务端连接信息："
    echo "ID Server : $IP:$ID_PORT"
    echo "Relay     : $IP:$RELAY_PORT"
    echo "API       : $IP:$API_PORT"

    KEY=$(docker exec rust_desk_hbbs cat /root/id_ed25519.pub 2>/dev/null || echo "未生成")
    echo "🔑 客户端 Key: $KEY"
}

# 菜单
while true; do
    echo "============================="
    echo "     RustDesk 服务端管理"
    echo "============================="
    echo "服务端状态: $(docker ps | grep rust_desk_hbbr >/dev/null && echo 'Docker 已启动' || echo '未安装 ❌')"
    echo "1) 安装 RustDesk Server OSS (Docker)"
    echo "2) 卸载 RustDesk Server"
    echo "3) 重启 RustDesk Server"
    echo "4) 查看连接信息"
    echo "5) 退出"
    read -p "请选择操作 [1-5]: " choice

    case $choice in
        1) install_rustdesk ;;
        2) uninstall_rustdesk ;;
        3) restart_rustdesk ;;
        4) show_info ;;
        5) exit 0 ;;
        *) echo "无效选项" ;;
    esac
done
