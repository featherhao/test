#!/bin/bash
# RustDesk OSS 管理脚本
# 作者：ChatGPT
# 说明：独立脚本，无需主菜单

RUSTDESK_NET="rustdesk-oss_rust_desk_net"
HBBS_CONTAINER="rust_desk_hbbs"
HBBR_CONTAINER="rust_desk_hbbr"
HBBS_VOLUME="rust_desk_hbbs_data"
HBBR_VOLUME="rust_desk_hbbr_data"
COMPOSE_FILE="/root/compose.yml"

check_install_status() {
    if docker ps -a --format '{{.Names}}' | grep -q "$HBBS_CONTAINER"; then
        STATUS="Docker 已启动 ✅"
    else
        STATUS="未安装 ❌"
    fi
}

clear_ports() {
    for PORT in 21115 21116 21117; do
        while PID=$(lsof -tiTCP:$PORT -sTCP:LISTEN); do
            echo "⚠️ 端口 $PORT 被占用，杀掉 PID: $PID"
            kill -9 $PID
            sleep 1
        done
    done
    echo "✅ 所有端口已释放"
}

install_rustdesk() {
    echo "🐳 下载 RustDesk OSS 官方 compose 文件..."
    curl -fsSL https://raw.githubusercontent.com/ynnie/rustdesk-server/master/docker-compose.yml -o $COMPOSE_FILE
    echo "✅ 下载完成"

    echo "⚠️ 检查并清理占用端口..."
    clear_ports

    echo "🚀 启动 RustDesk OSS 容器..."
    docker network create $RUSTDESK_NET 2>/dev/null
    docker volume create $HBBS_VOLUME 2>/dev/null
    docker volume create $HBBR_VOLUME 2>/dev/null

    docker-compose -f $COMPOSE_FILE up -d

    echo "⏳ 等待 hbbs 生成客户端 Key..."
    sleep 5

    echo "✅ 安装完成"
    show_info
}

uninstall_rustdesk() {
    echo "⚠️ 卸载 RustDesk..."
    docker rm -f $HBBS_CONTAINER $HBBR_CONTAINER 2>/dev/null
    docker volume rm $HBBS_VOLUME $HBBR_VOLUME 2>/dev/null
    docker network rm $RUSTDESK_NET 2>/dev/null
    echo "✅ RustDesk 已卸载"
}

restart_rustdesk() {
    docker restart $HBBS_CONTAINER $HBBR_CONTAINER
    echo "✅ RustDesk 已重启"
}

show_info() {
    check_install_status
    echo "============================="
    echo "服务端状态: $STATUS"
    if [ "$STATUS" == "Docker 已启动 ✅" ]; then
        ID_IP=$(docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $HBBR_CONTAINER)
        echo "🌐 RustDesk 服务端连接信息："
        echo "ID Server : $ID_IP:21115"
        echo "Relay     : $ID_IP:21116"
        echo "API       : $ID_IP:21117"
        CLIENT_KEY=$(docker exec -i $HBBS_CONTAINER cat /root/.config/rustdesk/key.pub 2>/dev/null || echo "稍后生成")
        echo "🔑 客户端 Key：$CLIENT_KEY"
    fi
    echo "============================="
    read -p "按回车返回菜单..."
}

main_menu() {
    while true; do
        check_install_status
        clear
        echo "============================="
        echo "     RustDesk 服务端管理"
        echo "============================="
        echo "服务端状态: $STATUS"
        echo "1) 安装 RustDesk Server OSS (Docker)"
        echo "2) 卸载 RustDesk Server"
        echo "3) 重启 RustDesk Server"
        echo "4) 查看连接信息"
        echo "0) 退出"
        echo -n "请选择操作 [0-4]: "
        read -r CHOICE
        case $CHOICE in
            1) install_rustdesk ;;
            2) uninstall_rustdesk ;;
            3) restart_rustdesk ;;
            4) show_info ;;
            0) exit 0 ;;
            *) echo "❌ 无效选项" ;;
        esac
    done
}

main_menu
