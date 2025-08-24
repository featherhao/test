#!/bin/bash
set -e

WORKDIR=/opt/rustdesk
COMPOSE_FILE=$WORKDIR/docker-compose.yml

# -------------------------
# 检查并释放端口
# -------------------------
release_ports() {
    for port in 21115 21116 21117 21118; do
        # 杀掉占用该端口的 docker 容器
        container=$(docker ps -q --filter "publish=$port")
        if [ -n "$container" ]; then
            echo "⚠️  端口 $port 被 Docker 容器占用，删除容器 $container"
            docker rm -f $container || true
        fi
        # 杀掉占用该端口的其他进程
        pid=$(lsof -t -i:$port 2>/dev/null || true)
        if [ -n "$pid" ]; then
            echo "⚠️  端口 $port 被进程 PID:$pid 占用，杀掉进程"
            kill -9 $pid || true
        fi
    done
}

# -------------------------
# 安装 RustDesk
# -------------------------
install_rustdesk() {
    mkdir -p $WORKDIR
    cd $WORKDIR

    cat > $COMPOSE_FILE <<EOF
services:
  hbbs:
    image: rustdesk/rustdesk-server:latest
    container_name: hbbs
    command: hbbs -r 0.0.0.0:21116
    network_mode: "host"
    restart: unless-stopped
    volumes:
      - ./data:/root

  hbbr:
    image: rustdesk/rustdesk-server:latest
    container_name: hbbr
    command: hbbr
    network_mode: "host"
    restart: unless-stopped
EOF

    release_ports

    echo "⏳ 启动 RustDesk 容器..."
    docker compose -f $COMPOSE_FILE up -d

    echo "⏳ 等待 hbbs 生成客户端 Key..."
    for i in {1..30}; do
        key=$(docker logs hbbs 2>&1 | grep 'Key:' | tail -n1 | awk '{print $2}')
        if [ -n "$key" ]; then
            echo "✅ 找到 Key: $key"
            echo "$key" > $WORKDIR/key.txt
            break
        fi
        sleep 2
    done
    if [ -z "$key" ]; then
        echo "❌ 未能获取客户端 Key，请检查容器日志"
    fi
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
    release_ports
    docker compose -f $COMPOSE_FILE down || true
    docker compose -f $COMPOSE_FILE up -d
    echo "✅ RustDesk 已重启"
}

# -------------------------
# 显示连接信息
# -------------------------
# -------------------------
# 显示连接信息
# -------------------------
show_info() {
    ip=$(curl -s ipv4.ip.sb || curl -s ifconfig.me)
    echo "🌐 RustDesk 服务端连接信息："
    echo "ID Server : $ip:21115"
    echo "Relay     : $ip:21116"
    echo "API       : $ip:21117"

    key_file="$WORKDIR/data/id_ed25519.pub"
    if [ -f "$key_file" ]; then
        key=$(cat "$key_file")
        echo "🔑 客户端 Key：$key"
    else
        echo "🔑 客户端 Key：未生成或找不到文件，请先安装 RustDesk 服务端"
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
