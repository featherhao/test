#!/bin/bash
set -e

# ======= 配置 =======
DOCKER_SERVER_COMPOSE="/root/compose.yml"
SERVER_STATUS_FILE="/root/.rustdesk_server_status"
CONTAINER_NAME="hbbs"
HOST_CONFIG_DIR="/root/.config/rustdesk-server"

# ======= 状态检测 =======
check_server_status() {
    if [ -f "$SERVER_STATUS_FILE" ]; then
        SERVER_STATUS=$(cat "$SERVER_STATUS_FILE")
    else
        SERVER_STATUS="未安装 ❌"
    fi
}

# ======= 显示连接信息 =======
show_info() {
    if [ "$SERVER_STATUS" != "未安装 ❌" ]; then
        echo "🌐 RustDesk 服务端连接信息："

        IP4=$(curl -s ipv4.icanhazip.com || true)
        IP6=$(curl -s ipv6.icanhazip.com || true)

        [ -n "$IP4" ] && echo -e "公网 IPv4: $IP4\nID Server : $IP4:21115\nRelay     : $IP4:21116\nAPI       : $IP4:21117"
        [ -n "$IP6" ] && echo -e "公网 IPv6: [$IP6]:21115\nRelay     : [$IP6]:21116\nAPI       : [$IP6]:21117"

        # 等待 Key 文件生成
        echo
        echo "⏳ 检查 Key 是否生成..."
        while true; do
            if [ -f "$HOST_CONFIG_DIR/id_ed25519.pub" ]; then
                echo "🔑 RustDesk Key (客户端输入用):"
                cat "$HOST_CONFIG_DIR/id_ed25519.pub"
                break
            fi
            sleep 2
        done

        echo
        echo "👉 在客户端设置 ID Server / Relay Server 和 Key 即可"
    fi
}

# ======= 菜单 =======
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
    echo "4) 查看连接信息"
    echo "5) 退出"
    echo -n "请选择操作 [1-5]: "
}

# ======= 服务端操作 =======
install_server() {
    echo "🐳 使用 Docker 部署 RustDesk Server Pro..."

    # 安装 Docker
    if ! command -v docker >/dev/null 2>&1; then
        echo "📥 未检测到 Docker，开始安装..."
        apt-get update
        apt-get install -y ca-certificates curl gnupg lsb-release
        install -m 0755 -d /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        chmod a+r /etc/apt/keyrings/docker.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list
        apt-get update
        apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
        systemctl enable --now docker
        echo "✅ Docker 安装完成"
    else
        echo "✅ 检测到 Docker 已安装，跳过安装步骤。"
    fi

    # 创建宿主机配置目录
    mkdir -p "$HOST_CONFIG_DIR"

    # 下载 Docker Compose 文件
    wget -O "$DOCKER_SERVER_COMPOSE" https://rustdesk.com/pro.yml

    # 修改 Compose 文件挂载卷
    sed -i "/volumes:/a\      - $HOST_CONFIG_DIR:/root/.config/rustdesk-server" "$DOCKER_SERVER_COMPOSE"

    # 启动容器
    docker compose -f "$DOCKER_SERVER_COMPOSE" up -d

    echo "Docker 已启动" > "$SERVER_STATUS_FILE"
    echo "✅ RustDesk Server 已安装（Docker）"

    show_info
}

uninstall_server() {
    echo "🗑️ 卸载 RustDesk Server..."
    docker compose -f "$DOCKER_SERVER_COMPOSE" down || true
    rm -f "$DOCKER_SERVER_COMPOSE" "$SERVER_STATUS_FILE"
    echo "✅ RustDesk Server 已卸载"
}

restart_server() {
    echo "🔄 重启 RustDesk Server..."
    docker compose -f "$DOCKER_SERVER_COMPOSE" restart
    echo "✅ RustDesk Server 已重启"
    show_info
}

# ======= 主循环 =======
while true; do
    show_menu
    read -r choice
    case $choice in
        1) install_server ;;
        2) uninstall_server ;;
        3) restart_server ;;
        4) show_info ;;
        5) exit 0 ;;
        *) echo "无效选项" ;;
    esac
    read -rp "按回车返回菜单..."
done
