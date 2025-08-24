#!/bin/bash
set -e

# -----------------------------
# 公共变量
# -----------------------------
PROJECT_NAME="rustdesk-oss"
WORKDIR="/opt/rustdesk"
COMPOSE_FILE="$WORKDIR/docker-compose.yml"
CONTAINERS=("rust_desk_hbbs" "rust_desk_hbbr")
VOLUMES=("rust_desk_hbbs_data" "rust_desk_hbbr_data")

# -----------------------------
# 工具函数
# -----------------------------
check_and_kill_port() {
    local port=$1
    local pid
    pid=$(lsof -iTCP:$port -sTCP:LISTEN -t || true)
    if [[ -n "$pid" ]]; then
        echo "⚠️ 端口 $port 被占用，杀掉 PID: $pid"
        kill -9 $pid
    fi
}

get_ip() {
    curl -s https://api.ipify.org || echo "127.0.0.1"
}

# -----------------------------
# RustDesk 管理
# -----------------------------
install_rustdesk() {
    echo "🐳 下载 RustDesk OSS 官方 compose 文件..."
    mkdir -p "$WORKDIR"
    curl -fsSL https://raw.githubusercontent.com/ynnie/rustdesk-server/master/docker-compose.yml -o "$COMPOSE_FILE"
    echo "✅ 下载完成"

    echo "⚠️ 检查并清理占用端口..."
    for port in 21115 21116 21117; do
        check_and_kill_port $port
    done
    echo "✅ 所有端口已释放"

    echo "🚀 启动 RustDesk OSS 容器..."
    docker compose -f "$COMPOSE_FILE" -p "$PROJECT_NAME" up -d

    echo "⏳ 等待 hbbs 生成客户端 Key..."
    sleep 5  # 可根据需要改成循环检测

    local ip=$(get_ip)
    echo "✅ 安装完成"
    echo "🌐 RustDesk 服务端连接信息："
    echo "ID Server : $ip:21115"
    echo "Relay     : $ip:21116"
    echo "API       : $ip:21117"
    echo "🔑 客户端 Key（稍后生成）"
}

uninstall_rustdesk() {
    echo "🧹 卸载 RustDesk..."
    docker compose -f "$COMPOSE_FILE" -p "$PROJECT_NAME" down --volumes 2>/dev/null || true
    for container in "${CONTAINERS[@]}"; do
        docker rm -f "$container" 2>/dev/null || true
    done
    for volume in "${VOLUMES[@]}"; do
        docker volume rm "$volume" 2>/dev/null || true
    done
    echo "✅ RustDesk 已卸载"
}

restart_rustdesk() {
    echo "🔄 重启 RustDesk..."
    for container in "${CONTAINERS[@]}"; do
        docker restart "$container" 2>/dev/null || true
    done
    echo "✅ RustDesk 已重启"
}

show_info() {
    local ip=$(get_ip)
    echo "🌐 RustDesk 服务端连接信息："
    echo "ID Server : $ip:21115"
    echo "Relay     : $ip:21116"
    echo "API       : $ip:21117"
    echo "🔑 客户端 Key（稍后生成）"
}

# -----------------------------
# RustDesk 子菜单
# -----------------------------
while true; do
    echo "============================="
    echo "     RustDesk 服务端管理"
    echo "============================="
    echo "1) 安装 RustDesk Server OSS (Docker)"
    echo "2) 卸载 RustDesk Server"
    echo "3) 重启 RustDesk Server"
    echo "4) 查看连接信息"
    echo "0) 退出"
    read -p "请选择操作 [0-4]: " choice
    case "$choice" in
        1) install_rustdesk ;;
        2) uninstall_rustdesk ;;
        3) restart_rustdesk ;;
        4) show_info ;;
        0) break ;;
        *) echo "⚠️ 请选择有效选项" ;;
    esac
done
