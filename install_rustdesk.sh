#!/bin/bash
set -e

COMPOSE_FILE=/root/compose.yml
PRIVATE_KEY=/root/id_ed25519
PUBLIC_KEY=/root/id_ed25519.pub

show_menu() {
    echo "============================"
    echo "     RustDesk 服务端管理     "
    echo "============================"

    # 检查 Docker 和容器状态
    if docker info >/dev/null 2>&1; then
        if docker compose -f "$COMPOSE_FILE" ps >/dev/null 2>&1; then
            echo "服务端状态: Docker 已启动"
        else
            echo "服务端状态: 未启动 ❌"
        fi
    else
        echo "服务端状态: Docker 未安装 ❌"
    fi

    echo "1) 安装 RustDesk Server Pro (Docker)"
    echo "2) 卸载 RustDesk Server"
    echo "3) 重启 RustDesk Server"
    echo "4) 查看连接信息"
    echo "5) 退出"
    read -rp "请选择操作 [1-5]: " choice
    case $choice in
        1) install_rustdesk ;;
        2) uninstall_rustdesk ;;
        3) restart_rustdesk ;;
        4) show_info ;;
        5) exit 0 ;;
        *) echo "无效选项"; sleep 1; show_menu ;;
    esac
}

install_rustdesk() {
    echo "🐳 使用 Docker 部署 RustDesk Server Pro..."
    if ! command -v docker >/dev/null 2>&1; then
        echo "⚠️ Docker 未安装，请先安装 Docker"
        return
    fi

    # 下载 compose 文件
    curl -fsSL https://rustdesk.com/pro.yml -o "$COMPOSE_FILE"

    # 启动容器
    docker compose -f "$COMPOSE_FILE" up -d
    echo "✅ RustDesk Server 已安装（Docker）"
    read -rp "按回车返回菜单..." dummy
    show_menu
}

uninstall_rustdesk() {
    echo "🗑 卸载 RustDesk Server..."
    docker compose -f "$COMPOSE_FILE" down
    rm -f "$COMPOSE_FILE"
    echo "✅ RustDesk Server 已卸载"
    read -rp "按回车返回菜单..." dummy
    show_menu
}

restart_rustdesk() {
    echo "🔄 重启 RustDesk Server..."
    docker compose -f "$COMPOSE_FILE" down
    docker compose -f "$COMPOSE_FILE" up -d
    echo "✅ RustDesk Server 已重启"
    read -rp "按回车返回菜单..." dummy
    show_menu
}

show_info() {
    echo "🌐 RustDesk 服务端连接信息："
    # 自动获取公网 IP
    IP=$(curl -s https://ip.sb)
    echo "公网 IPv4: $IP"

    echo "ID Server : $IP:21115"
    echo "Relay     : $IP:21116"
    echo "API       : $IP:21117"

    # 显示 Key 文件路径
    echo -e "\n🔑 私钥路径: $PRIVATE_KEY"
    echo "🔑 公钥路径: $PUBLIC_KEY"

    # 生成客户端可用 Key
    if [ -f "$PRIVATE_KEY" ]; then
        CLIENT_KEY=$(sed -n '2,$p' "$PRIVATE_KEY" | head -n -1 | tr -d '\n' | base64 -d | base64)
        echo "🔑 客户端可用 Key: $CLIENT_KEY"
    else
        echo "⚠️ 私钥不存在，无法生成客户端 Key"
    fi

    read -rp "按回车返回菜单..." dummy
    show_menu
}

# 启动菜单
show_menu
