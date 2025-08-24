#!/bin/bash
set -e

WORKDIR=/opt/rustdesk
COMPOSE_FILE=$WORKDIR/docker-compose.yml
DATA_DIR=$WORKDIR/data

# -------------------------
# 清理旧容器和端口
# -------------------------
cleanup() {
    docker rm -f hbbs hbbr 2>/dev/null || true
    rm -rf $DATA_DIR/id_ed25519* $DATA_DIR/key.txt
}

# -------------------------
# 安装 RustDesk
# -------------------------
install_rustdesk() {
    mkdir -p $DATA_DIR
    cd $WORKDIR

    # 生成 docker-compose.yml
    cat > $COMPOSE_FILE <<EOF
version: "3.9"
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
    volumes:
      - ./data:/root
    depends_on:
      - hbbs
    restart: unless-stopped
EOF

    # 启动服务
    cleanup
    docker compose -f $COMPOSE_FILE up -d

    echo "⏳ 等待 hbbs 生成客户端 Key..."
    for i in {1..30}; do
        KEY=$(docker logs hbbs 2>&1 | grep "Key:" | tail -n1 | awk '{print $2}')
        if [ -n "$KEY" ]; then
            echo "✅ 找到 Key: $KEY"
            echo "$KEY" > $DATA_DIR/key.txt
            break
        fi
        sleep 1
    done

    echo "🌐 RustDesk 服务端安装完成"
    IP=$(curl -s ipv4.ip.sb || curl -s ifconfig.me)
    echo "ID Server : $IP:21115"
    echo "Relay     : $IP:21116"
    echo "API       : $IP:21117"
    echo "客户端 Key : $KEY"
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
        2)
            docker compose -f $COMPOSE_FILE down || true
            rm -rf $WORKDIR
            echo "✅ RustDesk 已卸载"
            ;;
        3)
            docker compose -f $COMPOSE_FILE down || true
            docker compose -f $COMPOSE_FILE up -d
            echo "✅ RustDesk 已重启"
            ;;
        4)
            IP=$(curl -s ipv4.ip.sb || curl -s ifconfig.me)
            if [ -f "$DATA_DIR/key.txt" ]; then
                KEY=$(cat $DATA_DIR/key.txt)
            else
                KEY="生成中，请稍等几秒后再查看"
            fi
            echo "🌐 RustDesk 服务端连接信息："
            echo "ID Server : $IP:21115"
            echo "Relay     : $IP:21116"
            echo "API       : $IP:21117"
            echo "客户端 Key：$KEY"
            read -p "按回车继续..."
            ;;
        0) exit 0 ;;
        *) echo "无效选项，请重试" ;;
    esac
done
