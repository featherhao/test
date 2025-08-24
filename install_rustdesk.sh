#!/bin/bash
set -e

# ======= 配置 =======
CLIENT_USER="rustdesk"
CLIENT_DIR="/opt/rustdesk"
DOCKER_CLIENT_IMAGE="rustdesk-builder"
DOCKER_SERVER_COMPOSE="/root/compose.yml"
SERVER_STATUS_FILE="/root/.rustdesk_server_status"
CLIENT_STATUS_FILE="/root/.rustdesk_client_status"
LOG_FILE="/root/rustdesk/build.log"

# ======= 状态检测 =======
check_client_status() {
    if [ -f "$CLIENT_STATUS_FILE" ]; then
        CLIENT_STATUS=$(cat "$CLIENT_STATUS_FILE")
    else
        CLIENT_STATUS="未安装 ❌"
    fi
}

check_server_status() {
    if [ -f "$SERVER_STATUS_FILE" ]; then
        SERVER_STATUS=$(cat "$SERVER_STATUS_FILE")
    else
        SERVER_STATUS="未安装 ❌"
    fi
}

show_menu() {
    clear
    check_client_status
    check_server_status
    echo "============================"
    echo "      RustDesk 管理脚本     "
    echo "============================"
    echo "客户端状态: $CLIENT_STATUS"
    echo "服务端状态: $SERVER_STATUS"
    echo "1) 安装 RustDesk 客户端"
    echo "2) 更新 RustDesk 客户端"
    echo "3) 卸载 RustDesk 客户端"
    echo "4) 安装 RustDesk Server Pro"
    echo "5) 取消正在构建 Docker"
    echo "6) 退出"
    echo -n "请选择操作 [1-6]: "
}

# ======= 客户端操作 =======
install_client() {
    echo "📦 选择安装方式："
    echo "1) 官方安装脚本"
    echo "2) Docker 构建（后台运行，支持 SSH 中断恢复）"
    read -rp "请选择 [1-2]: " method
    if [ "$method" == "1" ]; then
        echo "📥 安装官方 RustDesk（官方 GUI 弹窗输入用户名）..."
        if ! id "$CLIENT_USER" &>/dev/null; then
            useradd -m -s /bin/bash "$CLIENT_USER"
            echo "✅ 已创建非 root 用户: $CLIENT_USER"
        else
            echo "✅ 系统已有非 root 用户: $CLIENT_USER"
        fi
        read -rp "按回车确认，继续下一步安装..."
        bash <(curl -fsSL https://github.com/rustdesk/rustdesk/releases/latest/download/rustdesk-remote.sh)
        echo "已安装" > "$CLIENT_STATUS_FILE"
    elif [ "$method" == "2" ]; then
        echo "🐳 使用 Docker 构建 RustDesk 客户端..."
        mkdir -p "$CLIENT_DIR"
        cd "$CLIENT_DIR"
        git clone https://github.com/rustdesk/rustdesk . || (git pull origin main)
        nohup docker build -t "$DOCKER_CLIENT_IMAGE" . > "$LOG_FILE" 2>&1 &
        echo "安装中（后台运行），日志: $LOG_FILE"
        echo "安装中 ⏳" > "$CLIENT_STATUS_FILE"
    fi
}

update_client() {
    echo "🔄 更新客户端..."
    if [ "$CLIENT_STATUS" == "未安装 ❌" ]; then
        echo "客户端未安装，请先安装。"
        return
    fi
    echo "更新完成（示例，实际可加入 git pull 或官方脚本更新逻辑）"
}

uninstall_client() {
    echo "🗑️ 卸载 RustDesk 客户端..."
    rm -rf "$CLIENT_DIR"
    docker rmi "$DOCKER_CLIENT_IMAGE" 2>/dev/null || true
    userdel -r "$CLIENT_USER" 2>/dev/null || true
    echo "未安装 ❌" > "$CLIENT_STATUS_FILE"
    echo "✅ RustDesk 客户端已卸载"
}

# ======= 服务端操作 =======
install_server() {
    echo "📦 选择安装方式："
    echo "1) Docker（推荐，后台运行）"
    echo "2) 官方 install.sh（交互式）"
    read -rp "请选择 [1-2]: " method
    if [ "$method" == "1" ]; then
        echo "🐳 使用 Docker 部署 RustDesk Server Pro..."
        bash <(wget -qO- https://get.docker.com)
        wget rustdesk.com/pro.yml -O "$DOCKER_SERVER_COMPOSE"
        docker compose -f "$DOCKER_SERVER_COMPOSE" up -d
        echo "Docker 已启动" > "$SERVER_STATUS_FILE"
        echo "✅ RustDesk Server 已安装（Docker）"
    elif [ "$method" == "2" ]; then
        echo "📥 执行官方 install.sh 安装 Server Pro..."
        bash <(wget -qO- https://raw.githubusercontent.com/rustdesk/rustdesk-server-pro/main/install.sh)
        echo "已安装" > "$SERVER_STATUS_FILE"
    fi
}

cancel_docker() {
    echo "🚫 取消正在构建的 Docker 客户端或 Server..."
    pkill -f "docker build" || true
    echo "取消完成"
}

# ======= 主循环 =======
while true; do
    show_menu
    read -r choice
    case $choice in
        1) install_client ;;
        2) update_client ;;
        3) uninstall_client ;;
        4) install_server ;;
        5) cancel_docker ;;
        6) exit 0 ;;
        *) echo "无效选项" ;;
    esac
    read -rp "按回车返回菜单..."
done
