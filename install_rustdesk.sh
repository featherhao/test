#!/bin/bash
set -e

WORKDIR=/opt/rustdesk
COMPOSE_FILE=$WORKDIR/docker-compose.yml
DATA_DIR=$WORKDIR/data

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
    mkdir -p $DATA_DIR
    cd $WORKDIR

    cat > $COMPOSE_FILE <<EOF
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

    echo "⏳ 等待生成客户端 Key..."
    for i in {1..30}; do
        if [ -f "$DATA_DIR/id_ed25519" ]; then
            KEY=$(cat $DATA_DIR/id_ed25519)
            echo "✅ 客户端 Key 已生成：$KEY"
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
    local ip=$(curl -s ipv4.ip.sb || curl -s ifconfig.me)
    echo "🌐 RustDesk 服务端连接信息："
    echo "ID Server : $ip:21115"
    echo "Relay     : $ip:21116"
    echo "API       : $ip:21117"

    if [ -f "$DATA_DIR/id_ed25519" ]; then
        KEY=$(cat $DATA_DIR/id_ed25519)
        echo "🔑 客户端 Key：$KEY"
    else
        echo "🔑 客户端 Key：尚未生成"
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
