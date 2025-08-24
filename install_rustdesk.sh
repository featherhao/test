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

# ======= 显示连接信息（IPv4/IPv6 + Key） =======
show_info() {
    if [ "$SERVER_STATUS" != "未安装 ❌" ]; then
        echo "🌐 RustDesk 服务端连接信息："

        # 检测 IPv4 / IPv6
        IP4=$(curl -s ipv4.icanhazip.com || true)
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

        # 显示 Key
        PUB_KEY_FILE="/root/.config/rustdesk-server/id_ed25519.pub"
        if [ -f "$PUB_KEY_FILE" ]; then
            echo
            echo "🔑 RustDesk Key (客户端输入用):"
            cat "$PUB_KEY_FILE"
        else
            echo
            echo "⚠️ 公钥文件不存在，请确认服务器是否已启动一次"
        fi

        if [ -z "$IP4" ] && [ -z "$IP6" ]; then
            echo
            echo "⚠️ 无法检测到公网 IP，请手动配置域名或检查网络。"
        else
            echo
            echo "👉 在客户端设置 ID Server / Relay Server 和 Key 即可"
        fi
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
    echo -n "请选择操作
