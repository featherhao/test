#!/bin/bash
set -e

COMPOSE_FILE=/opt/rustdesk/docker-compose.yml
DATA_DIR=/opt/rustdesk
HBBS_CONTAINER=hbbs
HBBR_CONTAINER=hbbr

check_installed() {
    if docker ps -a --format '{{.Names}}' | grep -q "$HBBS_CONTAINER"; then
        return 0
    else
        return 1
    fi
}

get_key() {
    # 尝试从容器内部复制 Key 文件
    TMP_KEY="/tmp/rustdesk_key"
    if docker cp "$HBBS_CONTAINER":/root/.config/rustdesk/id_ed25519 "$TMP_KEY" 2>/dev/null; then
        cat "$TMP_KEY"
    else
        echo "稍后生成"
    fi
}

show_status() {
    if check_installed; then
        STATUS="已安装 ✅"
    else
        STATUS="未安装 ❌"
    fi
    echo "服务端状态: $STATUS"
}

install_rustdesk() {
    echo "🐳 下载 RustDesk OSS 官方 compose 文件..."
    mkdir -p "$DATA_DIR"
    curl -fsSL https://raw.githubusercontent.com/featherhao/test/refs/heads/main/docker-compose.yml -o "$COMPOSE_FILE"
    echo "✅ 下载完成"

    # 释放端口
    for port in 21115 21116 21117; do
        PID=$(lsof -ti tcp:$port)
        if [ -n "$PID" ]; then
            echo "⚠️ 端口 $port 被占用，杀掉 PID: $PID"
            kill -9 $PID
        fi
    done
    echo "✅ 所有端口已释放"

    echo "🚀 启动 RustDesk OSS 容器..."
    docker-compose -f "$COMPOSE_FILE" up -d

    echo "⏳ 等待 hbbs 生成客户端 Key..."
    sleep 5

    echo "✅ 安装完成"
    KEY=$(get_key)
    echo "🌐 RustDesk 服务端连接信息："
    echo "ID Server : 你的IP:21115"
    echo "Relay     : 你的IP:21116"
    echo "API       : 你的IP:21117"
    echo "🔑 客户端 Key：$KEY"
}

uninstall_rustdesk() {
    echo "🚀 卸载 RustDesk..."
    docker-compose -f "$COMPOSE_FILE" down -v || true
    echo "✅ RustDesk 已卸载"
}

restart_rustdesk() {
    echo "🔄 重启 RustDesk..."
    docker-compose -f "$COMPOSE_FILE" restart
    echo "✅ 已重启"
}

view_info() {
    show_status
    if check_installed; then
        KEY=$(get_key)
        echo "🌐 RustDesk 服务端连接信息："
        echo "ID Server : 你的IP:21115"
        echo "Relay     : 你的IP:21116"
        echo "API       : 你的IP:21117"
        echo "🔑 客户端 Key：$KEY"
    fi
    read -p "按回车继续..."
}

while true; do
    echo "============================="
    show_status
    echo "1) 安装 RustDesk Server OSS (Docker)"
    echo "2) 卸载 RustDesk Server"
    echo "3) 重启 RustDesk Server"
    echo "4) 查看连接信息"
    echo "0) 退出"
    echo -n "请选择操作 [0-4]: "
    read -r opt
    case $opt in
        1) install_rustdesk ;;
        2) uninstall_rustdesk ;;
        3) restart_rustdesk ;;
        4) view_info ;;
        0) exit 0 ;;
        *) echo "输入错误" ;;
    esac
done
