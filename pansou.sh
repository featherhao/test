#!/bin/bash
set -e

CONTAINER_NAME="pansou"
API_PORT=6001
LOCAL_IP=$(hostname -I | awk '{print $1}')

show_usage() {
    echo "🚀 PanSou 一键管理脚本"
    echo ""
    echo "用法: $0 {install|status|uninstall}"
    echo ""
    echo "  install    安装并启动 PanSou"
    echo "  status     显示 PanSou 状态和访问地址"
    echo "  uninstall  停止并卸载 PanSou (删除容器和缓存卷)"
    echo ""
}

install_pansou() {
    echo "⚙️ 开始安装 PanSou (API 端口: $API_PORT)"

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

    # 检查是否已安装
    if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}\$"; then
        echo "✅ PanSou 已经安装"
        show_status
        exit 0
    fi

    # 写入 docker-compose.yml
    cat > docker-compose.yml <<EOF
version: "3.9"
services:
  pansou:
    image: ghcr.io/fish2018/pansou:latest
    container_name: $CONTAINER_NAME
    restart: unless-stopped
    ports:
      - "$API_PORT:8888"
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

    show_status
}

show_status() {
    if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}\$"; then
        echo "✅ PanSou 正在运行"
        echo "👉 API 地址: http://$LOCAL_IP:$API_PORT/api/search"
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
    echo "🛑 正在卸载 PanSou..."
    if [ -f docker-compose.yml ]; then
        docker-compose down -v
        rm -f docker-compose.yml
        echo "✅ PanSou 已卸载 (容器和缓存卷已删除)"
    else
        echo "⚠️ 未找到 docker-compose.yml，可能未安装 PanSou"
    fi
}

# 主逻辑
case "$1" in
    install)
        install_pansou
        ;;
    status)
        show_status
        ;;
    uninstall)
        uninstall_pansou
        ;;
    *)
        show_usage
        ;;
esac
