#!/bin/bash
set -Eeuo pipefail

# ================== 架构检测 ==================
arch=$(uname -m)
if [[ "$arch" == "x86_64" ]]; then
    IMAGE="eureka6688/cosyvoice:latest"
elif [[ "$arch" =~ ^arm|aarch64$ ]]; then
    IMAGE="eureka6688/cosyvoice:arm"
else
    echo "❌ 暂不支持的架构: $arch"
    exit 1
fi

# ================== Docker 检查 ==================
if ! command -v docker &>/dev/null; then
    echo "⚙️ 未检测到 Docker，正在安装..."
    curl -fsSL https://get.docker.com | sh
    systemctl enable docker
    systemctl start docker
fi

if ! command -v docker-compose &>/dev/null; then
    echo "⚙️ 未检测到 docker-compose，正在安装..."
    curl -L "https://github.com/docker/compose/releases/download/2.29.7/docker-compose-$(uname -s)-$(uname -m)" \
        -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
fi

# ================== docker-compose.yml 生成 ==================
cat > docker-compose.yml <<EOF
version: "3.8"
services:
  cov:
    image: $IMAGE
    container_name: cov
    ports:
      - "50000:50000"
    command: ["python", "web.py", "--port", "50000"]
    stdin_open: true
    tty: true
    restart: unless-stopped
EOF

# ================== 启动 ==================
docker-compose up -d

# ================== 状态与地址 ==================
sleep 2
if docker ps --filter "name=cov" --filter "status=running" | grep cov &>/dev/null; then
    ip=$(hostname -I | awk '{print $1}')
    echo "✅ 容器已启动成功！"
    echo "📦 镜像: $IMAGE"
    echo "🌍 访问地址: http://$ip:50000"
else
    echo "❌ 容器启动失败，请检查日志： docker logs cov"
fi
