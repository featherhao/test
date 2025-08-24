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
# 安装 RustDesk
# -------------------------
install_rustdesk() {
    mkdir -p $WORKDIR
    cd $WORKDIR

    cat > $COMPOSE_FILE <<EOF
version: "3"
services:
  hbbs:
    image: rustdesk/rustdesk-server:latest
    container_name: hbbs
    command: hbbs -r 0.0.0.0:21116
    ports:
      - "21115:21115"
      - "21116:21116"
      - "21117:21117"
      - "21118:21118"
    volumes:
      - ./data:/root
    restart: unless-stopped

  hbbr:
    image: rustdesk/rustdesk-server:latest
    container_name: hbbr
    command: hbbr
    network_mode: service:hbbs
    depends_on:
      - hbbs
    restart: unless-stopped
EOF

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
# 卸载
# -------------------------
uninstall_rustdesk() {
    docker compose -f $COMPOSE_FILE down || true
    rm -rf $WORKDIR
    echo "✅ RustDesk 已卸载"
}

# -------------------------
# 重启
# -------------------------
restart_rustdesk() {
    docker compose -f $COMPOSE_FILE down || true
    release_ports
    docker compose -f $COMPOSE_FILE up -d
    echo "✅ RustDesk 已重启"
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

# -------------------------
# 主菜单
# -------------------------
while true; do
    echo "============================="
    echo "     RustDesk 服务端管理"
    echo "============================="
    if docker ps --format '{{.Names}}' | grep -q hbbs; then
        echo "服务端状态: 已安装 ✅"
    else
        echo "服务端状态: 未安装 ❌"
    fi
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
        *) echo "无效选项，请重试" ;;
    esac
done
