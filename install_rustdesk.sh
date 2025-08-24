#!/bin/bash
# RustDesk Server Pro 管理菜单

HBBS_CONTAINER="hbbs"
COMPOSE_FILE="/root/compose.yml"

function check_docker() {
    if ! command -v docker &>/dev/null; then
        echo "❌ Docker 未安装，请先安装 Docker"
        exit 1
    fi
}

function install_rustdesk() {
    echo "🐳 使用 Docker 部署 RustDesk Server Pro..."
    check_docker

    # 下载 compose 文件
    wget -q -O "$COMPOSE_FILE" https://rustdesk.com/pro.yml

    # 启动容器
    docker compose -f "$COMPOSE_FILE" up -d
    echo "✅ RustDesk Server 已安装（Docker）"
    read -p "按回车返回菜单..."
}

function uninstall_rustdesk() {
    echo "⚠️ 卸载 RustDesk Server..."
    docker compose -f "$COMPOSE_FILE" down
    rm -f "$COMPOSE_FILE"
    echo "✅ RustDesk Server 已卸载"
    read -p "按回车返回菜单..."
}

function restart_rustdesk() {
    echo "🔄 重启 RustDesk Server..."
    docker compose -f "$COMPOSE_FILE" restart
    echo "✅ 已重启"
    read -p "按回车返回菜单..."
}

function show_info() {
    echo "🌐 RustDesk 服务端连接信息："

    # 获取宿主机公网 IP
    PUB_IP=$(curl -s https://api.ipify.org)
    echo "公网 IPv4: $PUB_IP"
    echo "ID Server : $PUB_IP:21115"
    echo "Relay     : $PUB_IP:21116"
    echo "API       : $PUB_IP:21117"

    # 检查 Key 是否生成
    CLIENT_KEY=$(docker logs $HBBS_CONTAINER 2>&1 | grep -oP '(?<=Client key: ).*' | tail -1)
    if [ -n "$CLIENT_KEY" ]; then
        echo ""
        echo "🔑 客户端可用 Key: $CLIENT_KEY"
    else
        echo ""
        echo "⚠️ 还未生成客户端 Key，请确保 hbbs 容器已启动"
    fi

    # 显示私钥/公钥路径
    echo ""
    echo "🔑 私钥路径: /root/id_ed25519"
    echo "🔑 公钥路径: /root/id_ed25519.pub"

    read -p "按回车返回菜单..."
}

# 主菜单
while true; do
    clear
    echo "============================"
    echo "     RustDesk 服务端管理     "
    echo "============================"
    
    # 检查 Docker 容器状态
    if docker ps --format '{{.Names}}' | grep -q "$HBBS_CONTAINER"; then
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
    
    read -p "请选择操作 [1-5]: " choice
    case $choice in
        1) install_rustdesk ;;
        2) uninstall_rustdesk ;;
        3) restart_rustdesk ;;
        4) show_info ;;
        5) exit 0 ;;
        *) echo "❌ 无效选项"; sleep 1 ;;
    esac
done
