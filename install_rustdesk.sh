#!/bin/bash
PRIVATE_KEY="/root/id_ed25519"
PUBLIC_KEY="/root/id_ed25519.pub"

check_docker() {
    if ! command -v docker &>/dev/null; then
        echo "⚠️ Docker 未安装，请先安装 Docker"
        exit 1
    fi
}

install_rustdesk() {
    echo "🐳 使用 Docker 部署 RustDesk Server Pro..."
    check_docker
    curl -fsSL https://rustdesk.com/pro.yml -o /root/compose.yml
    docker compose -f /root/compose.yml up -d
    echo "✅ RustDesk Server 已安装（Docker）"
    read -rp "按回车返回菜单..." dummy
}

uninstall_rustdesk() {
    docker compose -f /root/compose.yml down
    rm -f /root/compose.yml
    echo "✅ RustDesk Server 已卸载"
    read -rp "按回车返回菜单..." dummy
}

restart_rustdesk() {
    docker compose -f /root/compose.yml down
    docker compose -f /root/compose.yml up -d
    echo "✅ RustDesk Server 已重启"
    read -rp "按回车返回菜单..." dummy
}

show_info() {
    echo "🌐 RustDesk 服务端连接信息："
    
    # 使用可靠的 IP 服务
    IP=$(curl -s https://api.ip.sb/ip)  # 或 https://ipv4.icanhazip.com
    echo "公网 IPv4: $IP"

    echo "ID Server : $IP:21115"
    echo "Relay     : $IP:21116"
    echo "API       : $IP:21117"

    # 显示 Key 文件路径
    echo -e "\n🔑 私钥路径: $PRIVATE_KEY"
    echo "🔑 公钥路径: $PUBLIC_KEY"

    # 客户端可用 Key（直接 base64）
    if [ -f "$PRIVATE_KEY" ]; then
        CLIENT_KEY=$(sed -n '2,$p' "$PRIVATE_KEY" | head -n -1 | tr -d '\n' | base64 -d | base64)
        echo "🔑 客户端可用 Key: $CLIENT_KEY"
    else
        echo "⚠️ 私钥不存在，无法生成客户端 Key"
    fi

    read -rp "按回车返回菜单..." dummy
}

show_menu() {
    clear
    echo "============================"
    echo "     RustDesk 服务端管理     "
    echo "============================"
    # 检查 Docker 容器状态
    if docker ps --format '{{.Names}}' | grep -q 'hbbs'; then
        STATUS="Docker 已启动"
    else
        STATUS="未安装 ❌"
    fi
    echo "服务端状态: $STATUS"
    echo "1) 安装 RustDesk Server Pro (Docker)"
    echo "2) 卸载 RustDesk Server"
    echo "3) 重启 RustDesk Server"
    echo "4) 查看连接信息"
    echo "5) 退出"
    read -rp "请选择操作 [1-5]: " choice
    case "$choice" in
        1) install_rustdesk ;;
        2) uninstall_rustdesk ;;
        3) restart_rustdesk ;;
        4) show_info ;;
        5) exit 0 ;;
        *) echo "⚠️ 无效选项"; sleep 1; show_menu ;;
    esac
}

show_menu
