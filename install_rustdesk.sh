#!/bin/bash
# RustDesk Server OSS 管理脚本

set -e

COMPOSE_FILE=/root/compose.yml
DOCKER_PROJECT=rustdesk-oss

# 获取本机公网 IP
get_ip() {
    IP=$(curl -s https://ip.sb)
    echo "$IP"
}

# 检查安装状态
check_status() {
    if docker ps -a --format '{{.Names}}' | grep -q rust_desk_hbbs; then
        STATUS="Docker 已启动 ✅"
    else
        STATUS="未安装 ❌"
    fi
}

# 清理占用端口
clear_ports() {
    for PORT in 21115 21116 21117; do
        while PID=$(lsof -tiTCP:$PORT -sTCP:LISTEN); do
            echo "⚠️ 端口 $PORT 被占用，杀掉 PID: $PID"
            kill -9 $PID 2>/dev/null || true
            while lsof -tiTCP:$PORT -sTCP:LISTEN >/dev/null; do
                sleep 0.5
            done
        done
    done
    echo "✅ 所有端口已释放"
}

# 安装 RustDesk OSS
install_rustdesk() {
    echo "🐳 下载 RustDesk OSS 官方 compose 文件..."
    curl -fsSL https://raw.githubusercontent.com/ynnie/rustdesk-server/master/docker-compose.yml -o $COMPOSE_FILE
    echo "✅ 下载完成"

    clear_ports

    echo "🚀 启动 RustDesk OSS 容器..."
    docker compose -f $COMPOSE_FILE up -d

    echo "⏳ 等待 hbbs 生成客户端 Key..."
    sleep 5

    echo "✅ 安装完成"
    IP=$(get_ip)
    echo "============================="
    echo "服务端状态: Docker 已启动 ✅"
    echo "🌐 RustDesk 服务端连接信息："
    echo "ID Server : $IP:21115"
    echo "Relay     : $IP:21116"
    echo "API       : $IP:21117"
    echo "🔑 客户端 Key：稍后生成"
    echo "============================="
}

# 卸载 RustDesk OSS
uninstall_rustdesk() {
    echo "⚠️ 正在卸载 RustDesk..."
    docker compose -f $COMPOSE_FILE down -v || true
    STATUS="未安装 ❌"
    echo "✅ RustDesk 已卸载"
}

# 重启 RustDesk OSS
restart_rustdesk() {
    echo "🔄 重启 RustDesk..."
    docker compose -f $COMPOSE_FILE restart
    echo "✅ RustDesk 已重启"
}

# 查看连接信息
show_info() {
    check_status
    IP=$(get_ip)
    echo "============================="
    echo "服务端状态: $STATUS"
    echo "🌐 RustDesk 服务端连接信息："
    echo "ID Server : $IP:21115"
    echo "Relay     : $IP:21116"
    echo "API       : $IP:21117"
    echo "🔑 客户端 Key：稍后生成"
    echo "============================="
    read -p "按回车返回菜单" dummy
}

# 主菜单
while true; do
    check_status
    echo "============================="
    echo "     RustDesk 服务端管理"
    echo "============================="
    echo "服务端状态: $STATUS"
    echo "1) 安装 RustDesk Server OSS (Docker)"
    echo "2) 卸载 RustDesk Server"
    echo "3) 重启 RustDesk Server"
    echo "4) 查看连接信息"
    echo "0) 退出"
    echo -n "请选择操作 [0-4]: "
    read opt
    case $opt in
        1) install_rustdesk ;;
        2) uninstall_rustdesk ;;
        3) restart_rustdesk ;;
        4) show_info ;;
        0) exit 0 ;;
        *) echo "无效选项" ;;
    esac
done
