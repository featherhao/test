#!/bin/bash

RUSTDESK_DIR=/root
COMPOSE_FILE=$RUSTDESK_DIR/compose.yml
HBBS_CONTAINER=hbbs

show_info() {
    echo "🌐 RustDesk 服务端连接信息："
    # 获取宿主机公网 IP
    PUB_IP=$(curl -s https://api.ipify.org)
    echo "公网 IPv4: $PUB_IP"
    echo "ID Server : $PUB_IP:21115"
    echo "Relay     : $PUB_IP:21116"
    echo "API       : $PUB_IP:21117"
    echo

    # 获取客户端 Key
    CLIENT_KEY=$(docker logs $HBBS_CONTAINER 2>&1 | grep 'Client key:' | tail -n1 | awk '{print $NF}')
    if [ -z "$CLIENT_KEY" ]; then
        echo "⚠️ 还未生成客户端 Key，请确保 hbbs 容器已启动并完成初始化"
    else
        echo "🔑 客户端可用 Key: $CLIENT_KEY"
        echo "   复制此 Key 到 RustDesk 客户端即可连接"
    fi
    echo
}

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
    read -p "请选择操作 [1-5]: " CHOICE

    case $CHOICE in
        1)
            echo "🐳 安装 RustDesk Server Pro..."
            docker compose -f $COMPOSE_FILE up -d
            echo "✅ 安装完成"
            read -p "按回车返回菜单..."
            ;;
        2)
            echo "🗑 卸载 RustDesk Server..."
            docker compose -f $COMPOSE_FILE down
            rm -f $RUSTDESK_DIR/id_ed25519 $RUSTDESK_DIR/id_ed25519.pub
            echo "✅ 卸载完成"
            read -p "按回车返回菜单..."
            ;;
        3)
            echo "🔄 重启 RustDesk Server..."
            docker compose -f $COMPOSE_FILE restart
            echo "✅ 重启完成"
            read -p "按回车返回菜单..."
            ;;
        4)
            show_info
            read -p "按回车返回菜单..."
            ;;
        5)
            exit 0
            ;;
        *)
            echo "无效选项"
            ;;
    esac
done
