#!/bin/bash
set -e

echo "🚀 PanSou 一键安装/检测脚本 (API 端口: 6001)"

# 容器名
CONTAINER_NAME="pansou"

# 检查 docker 是否安装
if ! command -v docker &> /dev/null; then
    echo "⚙️ 未检测到 Docker，正在安装..."
    curl -fsSL https://get.docker.com | sh
    systemctl enable docker
    systemctl start docker
else
    echo "✅ Docker 已安装"
fi

# 检查 docker-compose 是否安装
if ! command -v docker-compose &> /dev/null; then
    echo "⚙️ 未检测到 docker-compose，正在安装..."
    curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
else
    echo "✅ docker-compose 已安装"
fi

# 获取本机 IP
LOCAL_IP=$(hostname -I | awk '{print $1}')

# 检查容器是否已存在
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}\$"; then
    echo "✅ PanSou 已经安装"
    echo ""
    echo "👉 后端 API 地址: http://$LOCAL_IP:6001/api/search"
    echo ""
    echo "📌 常用命令:"
    echo "  查看日志: docker-compose logs -f"
    echo "  停止服务: docker-compose down"
    echo "  重启服务: docker-compose restart"
    exit 0
fi

# 写入 docker-compose.yml
cat > docker-compose.yml <<EOF
version: "3.9"
services:
  pansou:
    image: ghcr.io/fish2018/pansou:latest
    container_name: pansou
    restart: unless-stopped
    ports:
      - "6001:8888"
    volumes:
      - pansou-cache:/app/cache
    environment:
      - CHANNELS=tgsearchers3

volumes:
  pansou-cache:
EOF

# 启动服务
echo "🚀 首次安装并启动 PanSou 服务..."
docker-compose up -d

# 等待容器启动
sleep 5

echo "✅ PanSou 已安装并启动成功！"
echo ""
echo "👉 后端 API 地址: http://$LOCAL_IP:6001/api/search"
echo ""
echo "📌 常用命令:"
echo "  查看日志: docker-compose logs -f"
echo "  停止服务: docker-compose down"
echo "  重启服务: docker-compose restart"
