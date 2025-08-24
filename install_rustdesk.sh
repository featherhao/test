#!/bin/bash
# RustDesk Server OSS 管理菜单
set -e

COMPOSE_FILE="/opt/rustdesk/docker-compose.yml"
DATA_DIR="/opt/rustdesk"

# 检查容器是否存在
check_installed() {
    if docker ps -a --format '{{.Names}}' | grep -q "rust_desk_hbbs"; then
        echo "Docker 已启动 ✅"
        return 0
    else
        echo "未安装 ❌"
        return 1
    fi
}

# 清理占用端口
clear_ports() {
    for PORT in 21115 21116 21117; do
        while PID=$(lsof -tiTCP:$PORT -sTCP:LISTEN); do
            echo "⚠️ 端口 $PORT 被占用，杀掉 PID: $PID"
            kill -9 $PID 2>/dev/null || true
            # 等待端口释放
            while lsof -tiTCP:$PORT -sTCP:LISTEN >/dev/null; do
                sleep 0.2
            done
        done
    done
    echo "✅ 所有端口已释放"
}

# 安装 RustDesk OSS
install_rustdesk() {
    echo "🐳 下载 RustDesk OSS 官方 compose 文件..."
    mkdir -p "$DATA_DIR"
    curl -fsSL https://raw.githubusercontent.com/ynnie/rustdesk-server/master/docker-compose.yml -o $COMPOSE_FILE
    echo "✅ 下载完成"

    clear_ports  # 先释放端口

    echo "🚀 启动 RustDesk OSS 容器..."
    docker compose -f $COMPOSE_FILE up -d || true
    sleep 2  # 等待容器启动

    IP=$(curl -s https://ip.sb || echo "127.0.0.1")

    echo "✅ 安装完成"
    echo "服务端状态: Docker 已启动 ✅"
    echo "🌐 RustDesk 服务端连接信息："
    echo "ID Server : $IP:21115"
    echo "Relay     : $IP:21116"
    echo "API       : $IP:21117"
    echo "🔑 客户端 Key：稍后生成"
    read -p "按回车返回菜单" dummy
}

# 卸载 RustDesk OSS
uninstall_rustdesk() {
    echo "⚠️ 卸载 RustDesk OSS..."
    docker compose -f $COMPOSE_FILE down --volumes || true
    rm -rf "$DATA_DIR"
    echo "✅ RustDesk 已卸载"
    read -p "按回车返回菜单" dummy
}

# 重启 RustDesk OSS
restart_rustdesk() {
    docker compose -f $COMPOSE_FILE down || true
    clear_ports
    docker compose -f $COMPOSE_FILE up -d || true
    echo "✅ RustDesk 已重启"
    read -p "按回车返回菜单" dummy
}

# 查看连接信息
show_info() {
    IP=$(curl -s https://ip.sb || echo "127.0.0.1")
    echo "🌐 RustDesk 服务端连接信息："
    echo "ID Server : $IP:21115"
    echo "Relay     : $IP:21116"
    echo "API       : $IP:21117"
    echo "🔑 客户端 Key：稍后生成"
    read -p "按回车返回菜单" dummy
}

# 主菜单
while true; do
    STATUS=$(check_installed)
    echo "============================="
    echo "     RustDesk 服务端管理"
    echo "============================="
    echo "服务端状态: $STATUS"
    echo "1) 安装 RustDesk Server OSS (Docker)"
    echo "2) 卸载 RustDesk Server"
    echo "3) 重启 RustDesk Server"
    echo "4) 查看连接信息"
    echo "0) 退出"
    read -p "请选择操作 [0-4]: " opt
    case "$opt" in
        1) install_rustdesk ;;
        2) uninstall_rustdesk ;;
        3) restart_rustdesk ;;
        4) show_info ;;
        0) exit 0 ;;
        *) echo "❌ 请输入有效选项 [0-4]" ;;
    esac
done
