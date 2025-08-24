#!/bin/bash
set -e

# ======= 配置 =======
DOCKER_SERVER_COMPOSE="/root/compose.yml"
SERVER_STATUS_FILE="/root/.rustdesk_server_status"

# ======= 状态检测 =======
check_server_status() {
    if [ -f "$SERVER_STATUS_FILE" ]; then
        SERVER_STATUS=$(cat "$SERVER_STATUS_FILE")
    else
        SERVER_STATUS="未安装 ❌"
    fi
}

show_menu() {
    clear
    check_server_status
    echo "============================"
    echo "     RustDesk 服务端管理     "
    echo "============================"
    echo "服务端状态: $SERVER_STATUS"
    echo "1) 安装 RustDesk Server Pro (Docker)"
    echo "2) 卸载 RustDesk Server"
    echo "3) 重启 RustDesk Server"
    echo "4) 退出"
    echo -n "请选择操作 [1-4]: "
}

# ======= 服务端操作 =======
install_server() {
    echo "🐳 使用 Docker 部署 RustDesk Server Pro..."
    bash <(wget -qO- https://get.docker.com)
    wget https://rustdesk.com/pro.yml -O "$DOCKER_SERVER_COMPOSE"
    docker compose -f "$DOCKER_SERVER_COMPOSE" up -d
    echo "Docker 已启动" > "$SERVER_STATUS_FILE"
    echo "✅ RustDesk Server 已安装（Docker）"
}

uninstall_server() {
    echo "🗑️ 卸载 RustDesk Server..."
    docker compose -f "$DOCKER_SERVER_COMPOSE" down
    rm -f "$DOCKER_SERVER_COMPOSE" "$SERVER_STATUS_FILE"
    echo "✅ RustDesk Server 已卸载"
}

restart_server() {
    echo "🔄 重启 RustDesk Server..."
    docker compose -f "$DOCKER_SERVER_COMPOSE" restart
    echo "✅ RustDesk Server 已重启"
}

# ======= 主循环 =======
while true; do
    show_menu
    read -r choice
    case $choice in
        1) install_server ;;
        2) uninstall_server ;;
        3) restart_server ;;
        4) exit 0 ;;
        *) echo "无效选项" ;;
    esac
    read -rp "按回车返回菜单..."
done
