#!/bin/bash
set -e

WORKDIR=/opt/rustdesk
COMPOSE_FILE=$WORKDIR/docker-compose.yml

# -------------------------
# 检查并释放端口
# -------------------------
check_port() {
    PORT=$1
    PID=$(lsof -t -i:$PORT 2>/dev/null || netstat -tulnp 2>/dev/null | grep ":$PORT " | awk '{print $7}' | cut -d'/' -f1)
    if [ -n "$PID" ]; then
        echo "⚠️  端口 $PORT 被占用，杀掉进程 PID: $PID"
        kill -9 $PID || true
    fi
}

release_ports() {
    for port in 21115 21116 21117 21118; do
        check_port $port
    done
}

# -------------------------
# 启动 RustDesk
# -------------------------
start_rustdesk() {
    echo "🚀 启动 RustDesk OSS..."
    release_ports
    docker compose -f $COMPOSE_FILE up -d

    echo "⏳ 等待 hbbs 生成客户端 Key..."
    for i in {1..30}; do
        KEY=$(docker logs hbbs 2>&1 | grep "Key:" | tail -n1 | awk '{print $2}')
        if [ -n "$KEY" ]; then
            echo "✅ 找到 Key: $KEY"
            echo "$KEY" > $WORKDIR/key.txt
            break
        fi
        sleep 1
    done
}

# -------------------------
# 显示连接信息
# -------------------------
show_info() {
    echo "🌐 RustDesk 服务端连接信息："
    echo "ID Server : $(curl -s ifconfig.me):21115"
    echo "Relay     : $(curl -s ifconfig.me):21116"
    echo "API       : $(curl -s ifconfig.me):21117"

    if [ -f "$WORKDIR/key.txt" ]; then
        echo "🔑 客户端 Key：$(cat $WORKDIR/key.txt)"
    else
        KEY=$(docker logs hbbs 2>&1 | grep "Key:" | tail -n1 | awk '{print $2}')
        if [ -n "$KEY" ]; then
            echo "🔑 客户端 Key：$KEY"
        else
            echo "⚠️  未找到 Key，请检查容器是否运行正常"
        fi
    fi
}
