#!/bin/bash
# =========================================
#   RustDesk Server Pro Docker 管理脚本
# =========================================

RUSTDESK_DIR="/root"
COMPOSE_FILE="$RUSTDESK_DIR/compose.yml"
KEY_FILE="$RUSTDESK_DIR/id_ed25519"
PUB_KEY_FILE="$RUSTDESK_DIR/id_ed25519.pub"

function check_docker() {
    if ! command -v docker &>/dev/null; then
        echo "Docker 未安装，请先安装 Docker."
        exit 1
    fi
}

function generate_key() {
    if [ ! -f "$KEY_FILE" ]; then
        echo "🗝 生成 Ed25519 Key..."
        ssh-keygen -t ed25519 -f "$KEY_FILE" -N "" >/dev/null
        chmod 600 "$KEY_FILE"
        chmod 644 "$PUB_KEY_FILE"
        echo "✅ Key 生成完成: $KEY_FILE"
    else
        echo "🔑 Key 已存在，跳过生成"
    fi
}

function install_server() {
    echo "🐳 使用 Docker 部署 RustDesk Server Pro..."
    check_docker
    # 下载 compose 文件
    wget -O "$COMPOSE_FILE" https://rustdesk.com/pro.yml
    generate_key
    docker compose -f "$COMPOSE_FILE" up -d
    echo "✅ RustDesk Server 已安装（Docker）"
}

function uninstall_server() {
    echo "⚠️ 卸载 RustDesk Server..."
    docker compose -f "$COMPOSE_FILE" down
    rm -f "$COMPOSE_FILE"
    echo "✅ 卸载完成"
}

function restart_server() {
    echo "🔄 重启 RustDesk Server..."
    docker compose -f "$COMPOSE_FILE" down
    docker compose -f "$COMPOSE_FILE" up -d
    echo "✅ 重启完成"
}

function show_info() {
    echo "🌐 RustDesk 服务端连接信息："
    # 这里可根据实际 IP 修改
    PUB_IP=$(curl -s https://api.ip.sb/ip)
    echo "公网 IPv4: $PUB_IP"
    echo "ID Server : $PUB_IP:21115"
    echo "Relay     : $PUB_IP:21116"
    echo "API       : $PUB_IP:21117"
}

while true; do
    clear
    echo "============================"
    echo "     RustDesk 服务端管理     "
    echo "============================"
    
    if [ ! -f "$COMPOSE_FILE" ]; then
        echo "服务端状态: 未安装 ❌"
    else
        echo "服务端状态: Docker 已启动"
    fi

    echo "1) 安装 RustDesk Server Pro (Docker)"
    echo "2) 卸载 RustDesk Server"
    echo "3) 重启 RustDesk Server"
    echo "4) 查看连接信息"
    echo "5) 退出"
    read -rp "请选择操作 [1-5]: " choice

    case "$choice" in
        1) install_server; read -rp "按回车返回菜单..." ;;
        2) uninstall_server; read -rp "按回车返回菜单..." ;;
        3) restart_server; read -rp "按回车返回菜单..." ;;
        4) show_info; read -rp "按回车返回菜单..." ;;
        5) exit 0 ;;
        *) echo "❌ 选择无效，请重新输入"; sleep 1 ;;
    esac
done
