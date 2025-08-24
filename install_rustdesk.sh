#!/bin/bash

RUSTDESK_DIR="/root"
COMPOSE_FILE="$RUSTDESK_DIR/compose.yml"
PRIVATE_KEY="$RUSTDESK_DIR/id_ed25519"
PUBLIC_KEY="$RUSTDESK_DIR/id_ed25519.pub"

function check_docker() {
    if ! command -v docker &>/dev/null; then
        echo "Docker 未安装，请先安装 Docker"
        exit 1
    fi
}

function install_rustdesk() {
    echo "🐳 使用 Docker 部署 RustDesk Server Pro..."
    check_docker
    wget -O $COMPOSE_FILE https://rustdesk.com/pro.yml
    docker compose -f $COMPOSE_FILE up -d
    echo "✅ RustDesk Server 已安装（Docker）"
}

function uninstall_rustdesk() {
    docker compose -f $COMPOSE_FILE down
    rm -f $COMPOSE_FILE
    echo "✅ RustDesk Server 已卸载"
}

function restart_rustdesk() {
    docker compose -f $COMPOSE_FILE down
    docker compose -f $COMPOSE_FILE up -d
    echo "✅ RustDesk Server 已重启"
}

function show_info() {
    # 获取公网 IP
    IPV4=$(curl -s4 ifconfig.me || echo "无法获取公网 IP")
    echo -e "\n🌐 RustDesk 服务端连接信息："
    echo "公网 IPv4: $IPV4"
    echo "ID Server : $IPV4:21115"
    echo "Relay     : $IPV4:21116"
    echo "API       : $IPV4:21117"

    # 检查 key
    if [[ -f $PRIVATE_KEY && -f $PUBLIC_KEY ]]; then
        echo -e "\n🔑 私钥 (/root/id_ed25519) 内容:"
        cat $PRIVATE_KEY
        echo -e "\n🔑 公钥 (/root/id_ed25519.pub) 内容:"
        cat $PUBLIC_KEY
    else
        echo -e "\n⚠ Key 不存在，建议先生成或重启服务端自动生成 Key。"
    fi
}

while true; do
    echo "============================"
    echo "     RustDesk 服务端管理     "
    echo "============================"
    
    # 检查 Docker 容器状态
    if docker ps --format '{{.Names}}' | grep -q hbbs; then
        echo "服务端状态: Docker 已启动"
    else
        echo "服务端状态: 未安装 ❌"
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
        *) echo "无效选项，请输入 1-5" ;;
    esac
    echo -e "\n按回车返回菜单..."
    read
done
