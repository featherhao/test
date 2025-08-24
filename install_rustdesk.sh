#!/bin/bash
COMPOSE_FILE="/root/compose.yml"

rustdesk_menu() {
while true; do
    clear
    echo "============================="
    echo "     RustDesk 服务端管理"
    echo "============================="
    # 判断容器状态
    if docker ps | grep -q rust_desk_hbbs; then
        STATUS="Docker 已启动 ✅"
    else
        STATUS="未安装 ❌"
    fi
    echo "服务端状态: $STATUS"
    echo "1) 安装 RustDesk Server OSS (Docker)"
    echo "2) 卸载 RustDesk Server"
    echo "3) 重启 RustDesk Server"
    echo "4) 查看连接信息"
    echo "5) 退出"
    read -p "请选择操作 [1-5]: " opt
    case "$opt" in
        1) install_rustdesk_oss ;;
        2) uninstall_rustdesk ;;
        3) restart_rustdesk ;;
        4) show_info ;;
        5) break ;;
        *) echo "无效选项" ;;
    esac
    read -p "按回车返回菜单..."
done
}

install_rustdesk_oss() {
    echo "🐳 安装 RustDesk Server OSS..."
    
    # 检查并清理占用端口
    for port in 21115 21116 21117; do
        pid=$(lsof -tiTCP:$port -sTCP:LISTEN)
        if [ -n "$pid" ]; then
            echo "⚠️ 端口 $port 被占用，杀掉 PID: $pid"
            kill -9 $pid
            while lsof -tiTCP:$port -sTCP:LISTEN >/dev/null; do
                sleep 0.2
            done
            echo "✅ 端口 $port 已释放"
        fi
    done

    echo "⬇️  下载官方 compose 文件..."
    curl -fsSL https://raw.githubusercontent.com/ynnie/rustdesk-server/master/docker-compose.yml -o "$COMPOSE_FILE"
    echo "✅ 下载完成"

    echo "🚀 启动容器并显示安装输出..."
    docker compose -f "$COMPOSE_FILE" up -d

    echo "📜 hbbs 初始化日志（按 Ctrl+C 停止）..."
    docker logs -f rust_desk_hbbs & LOG_PID=$!

    # 等待一段时间尝试抓客户端 Key
    sleep 5
    CLIENT_KEY=$(docker logs rust_desk_hbbs 2>&1 | grep -oP 'Key: \K\S+')
    if [ -n "$CLIENT_KEY" ]; then
        echo "🔑 客户端可用 Key: $CLIENT_KEY"
    else
        echo "⚠️ 暂未获取到客户端 Key，请稍等 hbbs 完全初始化"
    fi

    kill $LOG_PID 2>/dev/null || true
    echo "✅ 安装完成"
}

uninstall_rustdesk() {
    echo "🗑️ 卸载 RustDesk Server..."
    docker compose -f "$COMPOSE_FILE" down
    echo "✅ 卸载完成"
}

restart_rustdesk() {
    echo "🔄 重启 RustDesk Server..."
    docker compose -f "$COMPOSE_FILE" restart
    echo "✅ 重启完成"
}

show_info() {
    if docker ps | grep -q rust_desk_hbbs; then
        IP=$(hostname -I | awk '{print $1}')
        echo "🌐 RustDesk 服务端连接信息："
        echo "ID Server : $IP:21115"
        echo "Relay     : $IP:21116"
        echo "API       : $IP:21117"
        CLIENT_KEY=$(docker logs rust_desk_hbbs 2>&1 | grep -oP 'Key: \K\S+')
        echo "🔑 客户端 Key: ${CLIENT_KEY:-未获取到}"
    else
        echo "⚠️ RustDesk 服务端未安装"
    fi
}

# 启动菜单
rustdesk_menu
