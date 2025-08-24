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

show_info() {
    if [ "$SERVER_STATUS" != "未安装 ❌" ]; then
        echo "🌐 RustDesk 服务端连接信息："

        # 检测 IPv4
        IP4=$(curl -s ipv4.icanhazip.com || true)
        # 检测 IPv6
        IP6=$(curl -s ipv6.icanhazip.com || true)

        if [ -n "$IP4" ]; then
            echo "公网 IPv4: $IP4"
            echo "ID Server : $IP4:21115"
            echo "Relay     : $IP4:21116"
            echo "API       : $IP4:21117"
        fi

        if [ -n "$IP6" ]; then
            echo "公网 IPv6: $IP6"
            echo "ID Server : [$IP6]:21115"
            echo "Relay     : [$IP6]:21116"
            echo "API       : [$IP6]:21117"
        fi

        if [ -z "$IP4" ] && [ -z "$IP6" ]; then
            echo "⚠️ 无法检测到公网 IP，请手动配置域名或检查网络。"
        else
            echo "👉 在客户端设置 ID Server 和 Relay Server 为上面地址即可"
        fi
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
    echo "4) 查看连接信息"
    echo "5) 退出"
    echo -n "请选择操作 [1-5]: "
}

# ======= 服务端操作 =======
install_server() {
    echo "🐳 使用 Docker 部署 RustDesk Server Pro..."

    # 检测是否已安装 docker
    if ! command -v docker >/dev/null 2>&1; then
        echo "📥 未检测到 Docker，开始安装..."

        # 安装依赖
        apt-get update
        apt-get install -y ca-certificates curl gnupg lsb-release

        # 添加 Docker 官方 GPG key
        install -m 0755 -d /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        chmod a+r /etc/apt/keyrings/docker.gpg

        # 添加 Docker 仓库
        echo \
          "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
          https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
          > /etc/apt/sources.list.d/docker.list

        # 安装 Docker CE 和 compose 插件
        apt-get update
        apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

        systemctl enable --now docker
        echo "✅ Docker 安装完成"
    else
        echo "✅ 检测到 Docker 已安装，跳过安装步骤。"
    fi

    # 部署 RustDesk Server Pro
    wget -O "$DOCKER_SERVER_COMPOSE" https://rustdesk.com/pro.yml
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
