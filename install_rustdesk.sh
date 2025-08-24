#!/bin/bash
set -e

# RustDesk Server 管理脚本

COMPOSE_FILE="/root/compose.yml"

function check_docker() {
    if ! command -v docker >/dev/null 2>&1; then
        echo "❌ Docker 未安装，请先安装 Docker"
        exit 1
    fi
}

function generate_key_if_missing() {
    if [ ! -f /root/id_ed25519 ]; then
        echo "🔑 Key 不存在，正在生成..."
        ssh-keygen -t ed25519 -f /root/id_ed25519 -N ""
        echo "✅ Key 生成完成"
    fi
}

function get_public_ip() {
    PUB_IP=$(curl -s https://icanhazip.com || curl -s https://ifconfig.me || echo "无法获取公网 IP")
}

function install_rustdesk() {
    check_docker

    echo "🐳 使用 Docker 部署 RustDesk Server Pro..."
    curl -fsSL https://rustdesk.com/pro.yml -o $COMPOSE_FILE

    docker compose -f $COMPOSE_FILE up -d
    echo "✅ RustDesk Server 已安装（Docker）"
}

function uninstall_rustdesk() {
    if [ -f "$COMPOSE_FILE" ]; then
        docker compose -f $COMPOSE_FILE down
        rm -f $COMPOSE_FILE
        echo "✅ RustDesk Server 已卸载"
    else
        echo "⚠️ RustDesk Server 未安装"
    fi
}

function restart_rustdesk() {
    if [ -f "$COMPOSE_FILE" ]; then
        docker compose -f $COMPOSE_FILE down
        docker compose -f $COMPOSE_FILE up -d
        echo "✅ RustDesk Server 已重启"
    else
        echo "⚠️ RustDesk Server 未安装"
    fi
}

function show_info() {
    generate_key_if_missing
    get_public_ip

    echo "🌐 RustDesk 服务端连接信息："
    echo "公网 IPv4: $PUB_IP"
    echo "ID Server : $PUB_IP:21115"
    echo "Relay     : $PUB_IP:21116"
    echo "API       : $PUB_IP:21117"
    echo ""
    echo "🔑 私钥路径: /root/id_ed25519"
    echo "🔑 公钥路径: /root/id_ed25519.pub"
}

function check_status() {
    if [ -f "$COMPOSE_FILE" ] && docker compose -f $COMPOSE_FILE ps | grep hbbs >/dev/null 2>&1; then
        echo "Docker 已启动"
    else
        echo "未安装 ❌"
    fi
}

# 菜单
while true; do
    echo "============================"
    echo "     RustDesk 服务端管理     "
    echo "============================"
    echo "服务端状态: $(check_status)"
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
        *) echo "⚠️ 无效选项" ;;
    esac
    echo ""
    read -rp "按回车返回菜单..."
done
