#!/bin/bash
set -e

DATA_DIR=/opt/rustdesk
COMPOSE_FILE=$DATA_DIR/docker-compose.yml

# 检查是否安装
check_installed() {
    if docker ps -a --format '{{.Names}}' | grep -q hbbs; then
        echo "已安装 ✅"
        return 0
    else
        echo "未安装 ❌"
        return 1
    fi
}

show_menu() {
    clear
    echo "============================="
    echo "     RustDesk 服务端管理"
    echo "============================="
    echo -n "服务端状态: "
    STATUS=$(check_installed || true)
    echo "$STATUS"
    echo "1) 安装 RustDesk Server OSS (Docker)"
    echo "2) 卸载 RustDesk Server"
    echo "3) 重启 RustDesk Server"
    echo "4) 查看连接信息"
    echo "0) 退出"
    read -rp "请选择操作 [0-4]: " choice
}

install_rustdesk() {
    mkdir -p "$DATA_DIR"
    echo "🐳 下载 RustDesk OSS 官方 compose 文件..."
    cat > "$COMPOSE_FILE" <<EOF
version: "3"
services:
  hbbs:
    image: rustdesk/rustdesk-server:latest
    container_name: hbbs
    restart: unless-stopped
    network_mode: host
    command: hbbs -r 0.0.0.0:21116
    volumes:
      - $DATA_DIR:/root

  hbbr:
    image: rustdesk/rustdesk-server:latest
    container_name: hbbr
    restart: unless-stopped
    network_mode: host
    command: hbbr
    volumes:
      - $DATA_DIR:/root
EOF

    echo "🚀 启动 RustDesk OSS 容器..."
    docker compose -f "$COMPOSE_FILE" up -d

    echo "⏳ 等待 hbbs 生成客户端 Key..."
    sleep 5
    echo "✅ 安装完成"
}

uninstall_rustdesk() {
    if [ -f "$COMPOSE_FILE" ]; then
        docker compose -f "$COMPOSE_FILE" down -v
        rm -rf "$DATA_DIR"
        echo "🗑️ 已卸载 RustDesk Server"
    else
        echo "⚠️ 未找到安装目录 $DATA_DIR"
    fi
}

restart_rustdesk() {
    if [ -f "$COMPOSE_FILE" ]; then
        docker compose -f "$COMPOSE_FILE" restart
        echo "🔄 已重启 RustDesk Server"
    else
        echo "⚠️ RustDesk 未安装"
    fi
}

show_info() {
    IP=$(curl -s ifconfig.me || echo "获取失败")
    echo "🌐 RustDesk 服务端连接信息："
    echo "ID Server : ${IP}:21115"
    echo "Relay     : ${IP}:21116"
    echo "API       : ${IP}:21117"

    if docker ps --format '{{.Names}}' | grep -q hbbs; then
        KEY=$(docker exec hbbs cat /root/id_ed25519.pub 2>/dev/null || echo "稍后生成")
        echo "🔑 客户端 Key：$KEY"
    else
        echo "🔑 客户端 Key：服务未运行"
    fi
}

# 主循环
while true; do
    show_menu
    case $choice in
        1) install_rustdesk ;;
        2) uninstall_rustdesk ;;
        3) restart_rustdesk ;;
        4) show_info ;;
        0) exit 0 ;;
        *) echo "无效选项" ;;
    esac
    read -rp "按回车继续..." enter
done
