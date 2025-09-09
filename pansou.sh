#!/bin/bash
set -e

CONTAINER_NAME="pansou"
DEFAULT_PORT=6001
LOCAL_IP=$(hostname -I | awk '{print $1}')

check_port() {
    PORT=$1
    if lsof -i :"$PORT" &>/dev/null; then
        return 1  # 被占用
    else
        return 0  # 可用
    fi
}

choose_port() {
    PORT=$DEFAULT_PORT
    while ! check_port $PORT; do
        echo "⚠️ 端口 $PORT 已被占用"
        read -p "请输入一个未占用的端口用于 PanSou API (回车默认 $DEFAULT_PORT): " INPUT_PORT
        PORT=${INPUT_PORT:-$DEFAULT_PORT}
    done
    echo "✅ 端口 $PORT 可用"
    echo
}

install_pansou() {
    echo "⚙️ 开始安装 PanSou"

    # 检查 docker
    if ! command -v docker &> /dev/null; then
        echo "⚙️ 未检测到 Docker，正在安装..."
        curl -fsSL https://get.docker.com | sh
        systemctl enable docker
        systemctl start docker
    else
        echo "✅ Docker 已安装"
    fi

    # 检查 docker-compose
    if ! command -v docker-compose &> /dev/null; then
        echo "⚙️ 未检测到 docker-compose，正在安装..."
        curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose
    else
        echo "✅ docker-compose 已安装"
    fi

    choose_port  # 检测或选择端口

    # 写入 docker-compose.yml
    cat > docker-compose.yml <<EOF
version: "3.9"
services:
  pansou:
    image: ghcr.io/fish2018/pansou:latest
    container_name: $CONTAINER_NAME
    restart: unless-stopped
    ports:
      - "$PORT:8888"
    volumes:
      - pansou-cache:/app/cache
    environment:
      - CHANNELS=tgsearchers3

volumes:
  pansou-cache:
EOF

    echo "🚀 启动 PanSou 服务..."
    docker-compose up -d
    sleep 5
    show_status $PORT
}

show_status() {
    PORT=${1:-$DEFAULT_PORT}
    if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}\$"; then
        echo "✅ PanSou 正在运行"
        echo "👉 后端 API 地址: http://$LOCAL_IP:$PORT/api/search"
        echo ""
        echo "📌 常用命令:"
        echo "  查看日志: docker-compose logs -f"
        echo "  停止服务: docker-compose down"
        echo "  重启服务: docker-compose restart"
    else
        echo "⚠️ PanSou 未运行"
    fi
}

uninstall_pansou() {
    if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}\$"; then
        echo "🛑 停止并卸载 PanSou..."
        docker-compose down -v
        rm -f docker-compose.yml
        echo "✅ PanSou 已卸载 (容器和缓存卷已删除)"
    else
        echo "⚠️ PanSou 未安装或已卸载"
    fi
}

# 主逻辑
case "$1" in
    install|"")
        if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}\$"; then
            echo "✅ PanSou 已经安装"
            show_status
        else
            install_pansou
        fi
        ;;
    status)
        show_status
        ;;
    uninstall)
        uninstall_pansou
        ;;
    *)
        echo "用法: $0 {install|status|uninstall}"
        ;;
esac
