#!/bin/bash
set -e

WORKDIR="/opt/rustdesk"
COMPOSE_FILE="$WORKDIR/docker-compose.yml"
DATA_DIR="$WORKDIR/data"

mkdir -p "$WORKDIR" "$DATA_DIR"

check_status() {
    if docker ps --format '{{.Names}}' | grep -q "hbbs"; then
        echo "已安装 ✅"
        return 0
    else
        echo "未安装 ❌"
        return 1
    fi
}

install_rustdesk() {
    echo "🐳 下载 RustDesk OSS 官方 compose 文件..."
    cat > $COMPOSE_FILE <<EOF
version: "3.9"
services:
  hbbs:
    image: rustdesk/rustdesk-server:latest
    container_name: hbbs
    restart: unless-stopped
    network_mode: host
    volumes:
      - $DATA_DIR:/root
    command: hbbs -r 0.0.0.0:21117

  hbbr:
    image: rustdesk/rustdesk-server:latest
    container_name: hbbr
    restart: unless-stopped
    network_mode: host
    volumes:
      - $DATA_DIR:/root
    command: hbbr
EOF
    echo "✅ 下载完成"

    # 检查端口占用
    for port in 21115 21116 21117; do
        pid=$(lsof -t -i:$port || true)
        if [ -n "$pid" ]; then
            echo "⚠️ 端口 $port 被占用，杀掉 PID: $pid"
            kill -9 $pid
        fi
    done

    echo "🚀 启动 RustDesk OSS 容器..."
    docker compose -f $COMPOSE_FILE up -d

    echo "⏳ 等待 hbbs 生成客户端 Key..."
    sleep 3
    echo "✅ 安装完成"
}

uninstall_rustdesk() {
    if [ -f "$COMPOSE_FILE" ]; then
        docker compose -f $COMPOSE_FILE down
        rm -rf "$WORKDIR"
        echo "🗑️ RustDesk 已卸载"
    else
        echo "❌ 未检测到安装"
    fi
}

restart_rustdesk() {
    if [ -f "$COMPOSE_FILE" ]; then
        echo "🔄 重启 RustDesk Server..."
        docker compose -f $COMPOSE_FILE restart
    else
        echo "❌ 未安装"
    fi
}

show_info() {
    local ip=$(curl -s ipv4.ip.sb || curl -s ifconfig.me)
    echo "🌐 RustDesk 服务端连接信息："
    echo "ID Server : $ip:21115"
    echo "Relay     : $ip:21116"
    echo "API       : $ip:21117"

    if [ -f "$DATA_DIR/id_ed25519.pub" ]; then
        echo "🔑 客户端 Key：$(cat $DATA_DIR/id_ed25519.pub)"
    else
        echo "🔑 客户端 Key：生成中..."
    fi
}

menu() {
    while true; do
        echo "============================="
        echo "     RustDesk 服务端管理"
        echo "============================="
        echo "服务端状态: $(check_status)"
        echo "1) 安装 RustDesk Server OSS (Docker)"
        echo "2) 卸载 RustDesk Server"
        echo "3) 重启 RustDesk Server"
        echo "4) 查看连接信息"
        echo "0) 退出"
        read -p "请选择操作 [0-4]: " choice
        case $choice in
            1) install_rustdesk ;;
            2) uninstall_rustdesk ;;
            3) restart_rustdesk ;;
            4) show_info; read -p "按回车继续..." ;;
            0) exit 0 ;;
            *) echo "❌ 无效选择" ;;
        esac
    done
}

menu
