#!/bin/bash
set -e

# 基本配置
CONTAINER_NAME="pansou"
DEFAULT_PORT=6001
PAN_DIR="/root/pansou"
LOCAL_IP=$(hostname -I | awk '{print $1}')
FRONTEND_PORT=80  # 前端默认端口

# 检查端口是否可用
check_port() {
    PORT=$1
    if lsof -i :"$PORT" &>/dev/null; then
        return 1
    else
        return 0
    fi
}

choose_port() {
    PORT=$DEFAULT_PORT
    while ! check_port $PORT; do
        echo "⚠️ 端口 $PORT 已被占用"
        read -p "请输入一个未占用的端口用于 PanSou API (回车默认 $DEFAULT_PORT): " INPUT_PORT
        PORT=${INPUT_PORT:-$DEFAULT_PORT}
    done
    echo $PORT
}

install_pansou() {
    echo "⚙️ 开始安装 PanSou"

    # Docker
    if ! command -v docker &>/dev/null; then
        echo "⚙️ 未检测到 Docker，正在安装..."
        curl -fsSL https://get.docker.com | sh
        systemctl enable docker
        systemctl start docker
    else
        echo "✅ Docker 已安装"
    fi

    # Docker Compose
    if ! command -v docker-compose &>/dev/null && ! command -v docker &>/dev/null; then
        echo "⚙️ 未检测到 Docker Compose，正在安装..."
        curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose
    else
        echo "✅ Docker Compose 已安装"
    fi

    # 创建目录
    mkdir -p $PAN_DIR
    cd $PAN_DIR

    # 选择端口
    PORT=$(choose_port)
    echo "✅ 端口 $PORT 可用"

    # 写 docker-compose.yml
    cat > docker-compose.yml <<EOF
services:
  pansou:
    image: ghcr.io/fish2018/pansou:latest
    container_name: $CONTAINER_NAME
    restart: unless-stopped
    ports:
      - "$PORT:8888"
      - "$FRONTEND_PORT:80"
    volumes:
      - pansou-cache:/app/cache
    environment:
      CHANNELS: tgsearchers3

volumes:
  pansou-cache:
EOF

    echo "🚀 启动 PanSou 服务..."
    docker compose up -d
    sleep 5

    echo "✅ 安装完成！"
}

show_status() {
    cd $PAN_DIR
    if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}\$"; then
        echo "✅ PanSou 正在运行"
        echo "👉 前端地址: http://$LOCAL_IP:$FRONTEND_PORT"
        echo "👉 API 地址: http://$LOCAL_IP:$PORT/api/search"
    else
        echo "⚠️ PanSou 未运行"
    fi
}

stop_pansou() {
    cd $PAN_DIR
    docker compose down
    echo "✅ PanSou 已停止"
}

restart_pansou() {
    cd $PAN_DIR
    docker compose restart
    echo "✅ PanSou 已重启"
}

uninstall_pansou() {
    if [ -d "$PAN_DIR" ]; then
        cd $PAN_DIR
        docker compose down -v
        cd ~
        rm -rf $PAN_DIR
        echo "✅ PanSou 已卸载 (容器和缓存卷已删除)"
    else
        echo "⚠️ PanSou 未安装或已卸载"
    fi
}

# 交互菜单
menu() {
    while true; do
        echo ""
        echo "========== PanSou 管理菜单 =========="
        echo "1) 安装 / 启动 PanSou"
        echo "2) 查看状态"
        echo "3) 停止 PanSou"
        echo "4) 重启 PanSou"
        echo "5) 卸载 PanSou"
        echo "0) 退出"
        echo "===================================="
        read -p "请输入选项: " CHOICE
        case $CHOICE in
            1)
                if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}\$"; then
                    echo "✅ PanSou 已安装"
                    docker compose up -d
                else
                    install_pansou
                fi
                show_status
                ;;
            2)
                show_status
                ;;
            3)
                stop_pansou
                ;;
            4)
                restart_pansou
                ;;
            5)
                uninstall_pansou
                ;;
            0)
                echo "👋 退出"
                exit 0
                ;;
            *)
                echo "⚠️ 无效选项"
                ;;
        esac
    done
}

menu
