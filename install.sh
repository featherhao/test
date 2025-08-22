#!/bin/bash
set -e

WORKDIR=/opt/moontv
COMPOSE_FILE=$WORKDIR/docker-compose.yml
ENV_FILE=$WORKDIR/.env

echo "📦 正在安装 Docker 和 Docker Compose..."
if ! command -v docker &> /dev/null; then
  curl -fsSL https://get.docker.com | bash
fi

if ! command -v docker compose &> /dev/null; then
  apt update && apt install -y docker-compose-plugin
fi

mkdir -p $WORKDIR
cd $WORKDIR

# 写 .env 文件（如果不存在）
if [ ! -f "$ENV_FILE" ]; then
  cat > $ENV_FILE <<EOF
USERNAME=admin
PASSWORD=103997250
AUTH_TOKEN= 337b3e253575cb228407060baaa0de74
EOF
  echo "⚠️ 已生成 .env 文件，请修改密码和 AUTH_TOKEN 后再用！"
fi

# 写 docker-compose.yml
cat > $COMPOSE_FILE <<'EOF'
version: '3.9'

services:
  moontv-core:
    image: ghcr.io/moontechlab/lunatv:latest
    container_name: moontv-core
    restart: unless-stopped
    ports:
      - '8080:3000'
    environment:
      - USERNAME=${USERNAME}
      - PASSWORD=${PASSWORD}
      - NEXT_PUBLIC_STORAGE_TYPE=kvrocks
      - KVROCKS_URL=redis://moontv-kvrocks:6666
      - AUTH_TOKEN=${AUTH_TOKEN}
    networks:
      - moontv-network
    depends_on:
      - moontv-kvrocks

  moontv-kvrocks:
    image: apache/kvrocks
    container_name: moontv-kvrocks
    restart: unless-stopped
    volumes:
      - kvrocks-data:/var/lib/kvrocks
    networks:
      - moontv-network

networks:
  moontv-network:
    driver: bridge

volumes:
  kvrocks-data:
EOF

# 启动服务
docker compose -f $COMPOSE_FILE up -d

echo "✅ MoonTV 已启动"
echo "👉 访问地址: http://$(hostname -I | awk '{print $1}'):8080"
echo "👉 用户名: $(grep USERNAME $ENV_FILE | cut -d '=' -f2)"
echo "👉 密码: $(grep PASSWORD $ENV_FILE | cut -d '=' -f2)"
