#!/bin/bash
set -e

WORKDIR=/root
COMPOSE_FILE=$WORKDIR/compose.yml

show_menu() {
    clear
    echo "============================"
    echo "     RustDesk 服务端管理"
    echo "============================"
    STATUS=$(docker ps -q -f name=hbbs)
    if [ -n "$STATUS" ]; then
        echo "服务端状态: Docker 已启动"
    else
        echo "服务端状态: 未安装 ❌"
    fi
    echo "1) 安装 RustDesk Server Pro (Docker)"
    echo "2) 卸载 RustDesk Server"
    echo "3) 重启 RustDesk Server"
    echo "4) 查看连接信息"
    echo "5) 退出"
    read -rp "请选择操作 [1-5]: " opt
    case $opt in
        1) install_rustdesk ;;
        2) uninstall_rustdesk ;;
        3) restart_rustdesk ;;
        4) show_info ;;
        5) exit 0 ;;
        *) echo "无效选项"; sleep 1; show_menu ;;
    esac
}

install_rustdesk() {
    echo "🐳 安装 RustDesk Server Pro..."
    mkdir -p $WORKDIR
    echo "⬇️  下载官方 compose 文件..."
    curl -fsSL https://rustdesk.com/pro.yml -o $COMPOSE_FILE

    echo "⚠️ 停止并清理旧容器..."
    docker compose -f $COMPOSE_FILE down 2>/dev/null || true

    echo "🚀 启动容器并显示安装输出..."
    docker compose -f $COMPOSE_FILE up -d

    echo "📜 hbbs 初始化日志（按 Ctrl+C 停止）..."
    docker logs -f hbbs & PID=$!
    # 等待 10 秒后提取 Key
    sleep 10
    CLIENT_KEY=$(docker logs hbbs 2>&1 | grep -oP '(?<=Key: ).*' | head -1)
    kill $PID 2>/dev/null || true

    echo
    echo "✅ 安装完成"
    echo "🌐 RustDesk 服务端连接信息："
    IP=$(curl -s https://api.ipify.org)
    echo "公网 IPv4: $IP"
    echo "ID Server : $IP:21115"
    echo "Relay     : $IP:21116"
    echo "API       : $IP:21117"
    echo
    echo "🔑 客户端可用 Key: $CLIENT_KEY"
    echo "🔑 私钥路径: $WORKDIR/id_ed25519"
    echo "🔑 公钥路径: $WORKDIR/id_ed25519.pub"
    read -rp "按回车返回菜单..."
    show_menu
}

uninstall_rustdesk() {
    echo "🗑️ 卸载 RustDesk Server..."
    docker compose -f $COMPOSE_FILE down 2>/dev/null || true
    rm -f $WORKDIR/id_ed25519 $WORKDIR/id_ed25519.pub $COMPOSE_FILE
    echo "✅ 已卸载"
    read -rp "按回车返回菜单..."
    show_menu
}

restart_rustdesk() {
    echo "🔄 重启 RustDesk Server..."
    docker compose -f $COMPOSE_FILE restart
    echo "✅ 已重启"
    read -rp "按回车返回菜单..."
    show_menu
}

show_info() {
    IP=$(curl -s https://api.ipify.org)
    echo "🌐 RustDesk 服务端连接信息："
    echo "公网 IPv4: $IP"
    echo "ID Server : $IP:21115"
    echo "Relay     : $IP:21116"
    echo "API       : $IP:21117"
    if [ -f $WORKDIR/id_ed25519 ]; then
        CLIENT_KEY=$(docker logs hbbs 2>&1 | grep -oP '(?<=Key: ).*' | head -1)
        echo
        echo "🔑 客户端可用 Key: $CLIENT_KEY"
        echo "🔑 私钥路径: $WORKDIR/id_ed25519"
        echo "🔑 公钥路径: $WORKDIR/id_ed25519.pub"
    else
        echo "⚠️  还未生成客户端 Key，请确保 hbbs 容器已启动并完成初始化"
    fi
    read -rp "按回车返回菜单..."
    show_menu
}

# 启动菜单
show_menu
