#!/bin/bash
set -e

RDS_DIR="/root/rustdesk"
COMPOSE_FILE="$RDS_DIR/docker-compose.yml"
PUBLIC_IP=$(curl -s https://api.ipify.org)

mkdir -p $RDS_DIR

function check_ports() {
    PORTS=(21115 21116 21117)
    for P in "${PORTS[@]}"; do
        PID=$(lsof -tiTCP:$P -sTCP:LISTEN)
        if [ -n "$PID" ]; then
            echo "⚠️ 端口 $P 被占用，杀掉 PID: $PID"
            kill -9 $PID || true
        fi
    done
}

function install_rustdesk() {
    echo "🐳 安装 RustDesk Server OSS..."

    echo "⬇️  下载官方 compose 文件..."
    curl -fsSL https://raw.githubusercontent.com/ynnie/rustdesk-server/master/docker-compose.yml -o $COMPOSE_FILE
    echo "✅ 下载完成"

    echo "⚠️ 检查并清理占用端口..."
    check_ports
    echo "✅ 所有端口已释放"

    echo "🚀 启动容器..."
    docker compose -f $COMPOSE_FILE up -d

    sleep 3

    echo "📜 hbbs 初始化日志（显示最近 10 行）:"
    docker logs --tail 10 rust_desk_hbbs

    echo "✅ 安装完成"
    echo "🌐 RustDesk 服务端连接信息："
    echo "ID Server : $PUBLIC_IP:21115"
    echo "Relay     : $PUBLIC_IP:21116"
    echo "API       : $PUBLIC_IP:21117"

    # 尝试读取客户端 key
    if docker exec rust_desk_hbbs test -f /root/id_ed25519.pub; then
        KEY=$(docker exec rust_desk_hbbs cat /root/id_ed25519.pub)
        echo "🔑 客户端 Key: $KEY"
    else
        echo "🔑 客户端 Key（可能稍后生成）: 未生成"
    fi
}

function uninstall_rustdesk() {
    echo "⚠️ 停止并卸载 RustDesk Server..."
    docker compose -f $COMPOSE_FILE down || true
    rm -f $COMPOSE_FILE
    echo "✅ 卸载完成"
}

function restart_rustdesk() {
    docker compose -f $COMPOSE_FILE down || true
    check_ports
    docker compose -f $COMPOSE_FILE up -d
    echo "✅ RustDesk 已重启"
}

function show_info() {
    echo "🌐 RustDesk 服务端连接信息："
    echo "ID Server : $PUBLIC_IP:21115"
    echo "Relay     : $PUBLIC_IP:21116"
    echo "API       : $PUBLIC_IP:21117"
    if docker exec rust_desk_hbbs test -f /root/id_ed25519.pub; then
        KEY=$(docker exec rust_desk_hbbs cat /root/id_ed25519.pub)
        echo "🔑 客户端 Key: $KEY"
    else
        echo "🔑 客户端 Key: 未生成"
    fi
}

while true; do
    echo "============================="
    echo "     RustDesk 服务端管理"
    echo "============================="
    echo "服务端状态: $(docker ps -q --filter name=rust_desk_hbbs >/dev/null && echo 'Docker 已启动' || echo '未安装 ❌')"
    echo "1) 安装 RustDesk Server OSS (Docker)"
    echo "2) 卸载 RustDesk Server"
    echo "3) 重启 RustDesk Server"
    echo "4) 查看连接信息"
    echo "5) 退出"
    read -p "请选择操作 [1-5]: " opt
    case $opt in
        1) install_rustdesk ;;
        2) uninstall_rustdesk ;;
        3) restart_rustdesk ;;
        4) show_info ;;
        5) exit 0 ;;
        *) echo "无效选项" ;;
    esac
done
