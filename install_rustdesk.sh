#!/bin/bash
set -e

# RustDesk Server Pro Docker 菜单管理
RUSTDESK_COMPOSE="/root/compose.yml"
ID_KEY="/root/id_ed25519"
PUB_KEY="/root/id_ed25519.pub"

show_menu() {
    clear
    echo "============================"
    echo "     RustDesk 服务端管理     "
    echo "============================"

    if docker ps --format '{{.Names}}' | grep -q hbbs; then
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
    echo -n "请选择操作 [1-5]: "
}

install_rustdesk() {
    echo "🐳 使用官方安装脚本部署 RustDesk Server Pro..."

    # 停掉旧容器，删除旧 Key
    docker compose -f $RUSTDESK_COMPOSE down 2>/dev/null || true
    rm -f $ID_KEY $PUB_KEY

    # 拉取官方 compose 文件
    curl -fsSL -o $RUSTDESK_COMPOSE https://rustdesk.com/pro.yml

    # 执行 Docker Compose 启动
    docker compose -f $RUSTDESK_COMPOSE up -d

    echo "📜 显示 hbbs 容器日志（安装输出和客户端 Key）:"
    docker logs hbbs --tail 100

    # 提取客户端 Key
    CLIENT_KEY=$(docker logs hbbs 2>&1 | grep -oP '(?<=Client key: ).*')
    if [[ -n "$CLIENT_KEY" ]]; then
        echo "🔑 客户端可用 Key: $CLIENT_KEY"
    else
        echo "⚠️ 客户端 Key 尚未生成，请确认 hbbs 容器已正确启动。"
    fi

    # 显示服务端信息
    PUBLIC_IP=$(curl -s ifconfig.me)
    echo "🌐 RustDesk 服务端连接信息："
    echo "公网 IPv4: $PUBLIC_IP"
    echo "ID Server : $PUBLIC_IP:21115"
    echo "Relay     : $PUBLIC_IP:21116"
    echo "API       : $PUBLIC_IP:21117"

    echo "🔑 私钥路径: $ID_KEY"
    echo "🔑 公钥路径: $PUB_KEY"

    read -rp "按回车返回菜单..."
}

uninstall_rustdesk() {
    docker compose -f $RUSTDESK_COMPOSE down 2>/dev/null || true
    rm -f $ID_KEY $PUB_KEY
    echo "✅ RustDesk Server 已卸载"
    read -rp "按回车返回菜单..."
}

restart_rustdesk() {
    docker compose -f $RUSTDESK_COMPOSE down
    docker compose -f $RUSTDESK_COMPOSE up -d
    echo "✅ RustDesk Server 已重启"
    read -rp "按回车返回菜单..."
}

show_info() {
    PUBLIC_IP=$(curl -s ifconfig.me)
    echo "🌐 RustDesk 服务端连接信息："
    echo "公网 IPv4: $PUBLIC_IP"
    echo "ID Server : $PUBLIC_IP:21115"
    echo "Relay     : $PUBLIC_IP:21116"
    echo "API       : $PUBLIC_IP:21117"

    if [[ -f "$ID_KEY" && -f "$PUB_KEY" ]]; then
        echo "🔑 私钥路径: $ID_KEY"
        echo "🔑 公钥路径: $PUB_KEY"
        CLIENT_KEY=$(docker logs hbbs 2>&1 | grep -oP '(?<=Client key: ).*')
        if [[ -n "$CLIENT_KEY" ]]; then
            echo "🔑 客户端可用 Key: $CLIENT_KEY"
        else
            echo "⚠️ 还未生成客户端 Key，请确保 hbbs 容器已启动并完成初始化"
        fi
    else
        echo "⚠️ Key 文件不存在，请先安装 RustDesk Server"
    fi

    read -rp "按回车返回菜单..."
}

while true; do
    show_menu
    read -r choice
    case $choice in
        1) install_rustdesk ;;
        2) uninstall_rustdesk ;;
        3) restart_rustdesk ;;
        4) show_info ;;
        5) exit 0 ;;
        *) echo "无效选项，请重新选择"; sleep 1 ;;
    esac
done
