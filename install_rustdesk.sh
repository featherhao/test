#!/bin/bash

# ==============================
# RustDesk Server Pro 管理脚本
# ==============================

RUSTDESK_COMPOSE="/root/compose.yml"
ID_KEY="/root/id_ed25519"
PUB_KEY="/root/id_ed25519.pub"

check_docker() {
    if ! command -v docker &>/dev/null; then
        echo "❌ Docker 未安装，请先安装 Docker"
        exit 1
    fi
}

show_menu() {
    clear
    echo "============================="
    echo "     RustDesk 服务端管理     "
    echo "============================="
    
    if docker ps -q --filter name=hbbs | grep -q .; then
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

    check_docker

    # 停掉旧容器
    docker compose -f "$RUSTDESK_COMPOSE" down 2>/dev/null || true
    # 删除旧 Key
    rm -f "$ID_KEY" "$PUB_KEY"

    # 拉取官方 compose 文件
    echo "⬇️  下载官方 compose 文件..."
    curl -fsSL -o "$RUSTDESK_COMPOSE" https://rustdesk.com/pro.yml

    # 创建容器但不后台
    echo "🚀 启动容器并显示安装输出..."
    docker compose -f "$RUSTDESK_COMPOSE" up --no-start
    docker compose -f "$RUSTDESK_COMPOSE" start

    # 实时显示 hbbs 日志
    echo "📜 hbbs 初始化日志（按 Ctrl+C 停止）..."
    docker logs -f hbbs

    echo "✅ 安装完成"

    # 尝试获取客户端 Key
    CLIENT_KEY=$(docker logs hbbs 2>&1 | grep -oP '(?<=Client key: ).*')
    if [[ -n "$CLIENT_KEY" ]]; then
        echo "🔑 客户端可用 Key: $CLIENT_KEY"
    else
        echo "⚠️ 客户端 Key 尚未生成，请稍等 hbbs 容器初始化完成后再查看"
    fi

    read -rp "按回车返回菜单..." 
    show_menu
}

uninstall_rustdesk() {
    echo "🗑️ 卸载 RustDesk Server..."
    docker compose -f "$RUSTDESK_COMPOSE" down 2>/dev/null || true
    rm -f "$RUSTDESK_COMPOSE" "$ID_KEY" "$PUB_KEY"
    echo "✅ 卸载完成"
    read -rp "按回车返回菜单..." 
    show_menu
}

restart_rustdesk() {
    echo "🔄 重启 RustDesk Server..."
    docker compose -f "$RUSTDESK_COMPOSE" restart
    echo "✅ 重启完成"
    read -rp "按回车返回菜单..." 
    show_menu
}

show_info() {
    if docker ps -q --filter name=hbbs | grep -q .; then
        PUB_IP=$(curl -s ifconfig.me || echo "获取失败")
        echo "🌐 RustDesk 服务端连接信息："
        echo "公网 IPv4: $PUB_IP"
        echo "ID Server : $PUB_IP:21115"
        echo "Relay     : $PUB_IP:21116"
        echo "API       : $PUB_IP:21117"

        if [[ -f "$ID_KEY" && -f "$PUB_KEY" ]]; then
            echo ""
            echo "🔑 私钥路径: $ID_KEY"
            echo "🔑 公钥路径: $PUB_KEY"

            CLIENT_KEY=$(docker logs hbbs 2>&1 | grep -oP '(?<=Client key: ).*')
            if [[ -n "$CLIENT_KEY" ]]; then
                echo "🔑 客户端可用 Key: $CLIENT_KEY"
            else
                echo "⚠️ 客户端 Key 尚未生成，请确保 hbbs 容器已启动并完成初始化"
            fi
        else
            echo "⚠️ Key 文件不存在"
        fi
    else
        echo "❌ RustDesk 服务未启动"
    fi

    read -rp "按回车返回菜单..." 
    show_menu
}

# 主循环
while true; do
    show_menu
done
