#!/bin/bash
set -e

COMPOSE_FILE="/root/rustdesk-docker-compose.yml"
PROJECT_NAME="rustdesk-oss"
CONTAINERS=("rust_desk_hbbs" "rust_desk_hbbr")
VOLUMES=("rust_desk_hbbs_data" "rust_desk_hbbr_data")
PORTS=(21115 21116 21117)

# 获取本机外网 IP
get_ip() {
    IP=$(curl -s4 ifconfig.me || curl -s4 icanhazip.com || echo "0.0.0.0")
    echo "$IP"
}

# 判断服务状态
check_status() {
    local running=0
    for c in "${CONTAINERS[@]}"; do
        if docker ps -q -f name="$c" >/dev/null; then
            running=1
        fi
    done
    if [ $running -eq 1 ]; then
        echo "Docker 已启动 ✅"
    else
        echo "未安装 ❌"
    fi
}

# 清理占用端口
free_ports() {
    for p in "${PORTS[@]}"; do
        pid=$(lsof -tiTCP:$p -sTCP:LISTEN)
        if [ -n "$pid" ]; then
            echo "⚠️ 端口 $p 被占用，杀掉 PID: $pid"
            kill -9 $pid
        fi
    done
}

# 安装 RustDesk OSS
install_rustdesk() {
    echo "🐳 下载 RustDesk OSS 官方 compose 文件..."
    curl -fsSL https://raw.githubusercontent.com/ynnie/rustdesk-server/master/docker-compose.yml -o "$COMPOSE_FILE"
    echo "✅ 下载完成"

    free_ports
    echo "✅ 所有端口已释放"

    echo "🚀 启动 RustDesk OSS 容器..."
    docker compose -f "$COMPOSE_FILE" -p "$PROJECT_NAME" up -d

    echo "⏳ 等待 hbbs 生成客户端 Key..."
    sleep 5  # 等待容器启动
    IP=$(get_ip)
    echo "🌐 RustDesk 服务端连接信息："
    echo "ID Server : $IP:21115"
    echo "Relay     : $IP:21116"
    echo "API       : $IP:21117"
    echo "🔑 客户端 Key（稍后生成）"
}

# 卸载 RustDesk
uninstall_rus_
