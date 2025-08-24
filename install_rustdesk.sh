#!/bin/bash
set -e

# RustDesk OSS 菜单脚本
MENU_FILE="/root/menu.sh"
COMPOSE_FILE="/root/compose.yml"

check_ports() {
    for port in 21115 21116 21117; do
        pid=$(lsof -tiTCP:$port -sTCP:LISTEN)
        if [ -n "$pid" ]; then
            echo "⚠️ 端口 $port 被占用，杀掉 PID: $pid"
            kill -9 $pid
        fi
    done
}

install_rustdesk_oss() {
    echo "🐳 安装 RustDesk Server OSS..."
    echo "⬇️  下载官方 compose 文件..."
    curl -fsSL https://raw.githubusercontent.com/ynnie/rustdesk-server/master/docker-compose.yml -o "$COMPOSE_FILE"
    echo "✅ 下载完成"

    echo "⚠️ 检查并清理占用端口..."
    check_ports

    echo "🚀 启动容器并显示安装输出..."
    docker compose -f "$COMPOSE_FILE" up -d

    echo "📜 hbbs 初始化日志（按 Ctrl+C 停止）..."
    docker logs -f rust_desk_hbbs & LOG_PID=$!

    echo "⏳ 等待 hbbs 完全初始化生成 Key..."
    sleep 5  # 等待一会儿让 Key 写入

    # 尝试抓取客户端 Key
    CLIENT_KEY=$(docker logs rust_desk_hbbs 2>&1 | grep -oP 'Key: \K\S+')
    if [ -n "$CLIENT_KEY" ]; then
        echo "🔑 客户端可用 Key: $CLIENT_KEY"
    else
        echo "⚠️ 暂未获取到客户端 Key，请稍等 hbbs 完全初始化"
    fi

    # 停止日志追踪
    kill $LOG_PID 2>/dev/null || true

    echo "✅ 安装完成"
    echo "🌐 RustDesk 服务端连接信息："
    echo "ID Server : 0.0.0.0:21115"
    echo "Relay     : 0.0.0.0:21116"
    echo "API       : 0.0.0.0:21117"
}

uninstall_rustdesk() {
    echo "🧹 卸载 RustDesk Server..."
    docker compose -f "$COMPOSE_FILE" down || true
    rm -f "$COMPOSE_FILE"
    echo "✅ 卸载完成"
}

restart_rustdesk() {
    echo "🔄 重启 RustDesk Server..."
    docker compose -f "$COMPOSE_FILE" restart
    echo "✅ 重启完成"
}

show_info() {
    echo "🌐 RustDesk 服务端连接信息："
    docker ps --filter "name=rust_desk" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    CLIENT_KEY=$(docker logs rust_desk_hbbs 2>&1 | grep -oP 'Key: \K\S+')
    if [ -n "$CLIENT_KEY" ]; then
        echo "🔑 客户端可用 Key: $CLIENT_KEY"
    else
        echo "⚠️ 客户端 Key 暂未生成"
    fi
}

# 主菜单
while true; do
    echo "============================="
    echo "     RustDesk 服务端管理"
    echo "============================="
    STATUS=$(docker ps -q --filter "name=rust_desk_hbbs")
    if [ -n "$STATUS" ]; then
        echo "服务端状态: Docker 已启动 ✅"
    else
        echo "服务端状态: 未安装 ❌"
    fi
    echo "1) 安装 RustDesk Server OSS (Docker)"
    echo "2) 卸载 RustDesk Server"
    echo "3) 重启 RustDesk Server"
    echo "4) 查看连接信息"
    echo "5) 退出"
    read -rp "请选择操作 [1-5]: " opt
    case "$opt" in
        1) install_rustdesk_oss ;;
        2) uninstall_rustdesk ;;
        3) restart_rustdesk ;;
        4) show_info ;;
        5) exit 0 ;;
        *) echo "无效选项" ;;
    esac
done
