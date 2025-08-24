#!/bin/bash
set -e

RDS_DIR=/root
COMPOSE_FILE=$RDS_DIR/compose.yml

check_and_free_port() {
    local port=$1
    local pid
    pid=$(lsof -tiTCP:$port -sTCP:LISTEN)
    if [ -n "$pid" ]; then
        echo "⚠️ 端口 $port 被占用，杀掉 PID: $pid"
        kill -9 $pid 2>/dev/null || true
        # 等待端口释放
        while lsof -tiTCP:$port -sTCP:LISTEN >/dev/null; do
            sleep 0.2
        done
        echo "✅ 端口 $port 已释放"
    fi
}

install_rustdesk_oss() {
    echo "🐳 安装 RustDesk Server OSS..."
    echo "⬇️  下载官方 compose 文件..."
    curl -fsSL -o $COMPOSE_FILE https://raw.githubusercontent.com/ynnie/rustdesk-server/master/docker-compose.yml
    echo "✅ 下载完成"

    echo "⚠️ 检查并清理占用端口..."
    for port in 21115 21116 21117; do
        check_and_free_port $port
    done

    echo "🚀 启动容器..."
    docker compose -f $COMPOSE_FILE up -d

    echo "📜 hbbs 初始化日志（按 Ctrl+C 停止）..."
    docker logs -f rust_desk_hbbs
}

uninstall_rustdesk() {
    echo "⚠️ 卸载 RustDesk Server..."
    docker compose -f $COMPOSE_FILE down || true
    rm -f $COMPOSE_FILE
    echo "✅ 卸载完成"
}

show_info() {
    echo "🌐 RustDesk 服务端连接信息："
    echo "ID Server : 0.0.0.0:21115"
    echo "Relay     : 0.0.0.0:21116"
    echo "API       : 0.0.0.0:21117"
}

# 主菜单
while true; do
    echo "============================="
    echo "     RustDesk 服务端管理"
    echo "============================="
    echo "服务端状态: 未安装 ❌"
    echo "1) 安装 RustDesk Server OSS (Docker)"
    echo "2) 卸载 RustDesk Server"
    echo "3) 重启 RustDesk Server"
    echo "4) 查看连接信息"
    echo "5) 退出"
    read -p "请选择操作 [1-5]: " opt
    case $opt in
        1) install_rustdesk_oss ;;
        2) uninstall_rustdesk ;;
        3) docker compose -f $COMPOSE_FILE restart ;;
        4) show_info ;;
        5) exit 0 ;;
        *) echo "❌ 请输入正确选项 [1-5]" ;;
    esac
done
