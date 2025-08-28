#!/bin/bash
set -e

# =========================
# 配置
# =========================
REPO_URL="https://github.com/featherhao/LunaTV.git"
WORKDIR="/opt/lunatv"
IMAGE_NAME="lunatvn:latest"
KVROCKS_VOLUME="$WORKDIR/kvrocks-data"

# 默认用户名、密码和授权码，可修改
USERNAME="admin"
PASSWORD="admin_password"
AUTH_TOKEN="授权码"

# =========================
# 安装 Docker & Docker Compose
# =========================
echo "📦 安装 Docker..."
if ! command -v docker &>/dev/null; then
    curl -fsSL https://get.docker.com | bash
fi

echo "📦 安装 Docker Compose..."
if ! command -v docker compose &>/dev/null; then
    apt update && apt install -y docker-compose-plugin || echo "请手动安装 docker compose"
fi

# =========================
# 克隆项目
# =========================
echo "📥 克隆项目..."
rm -rf "$WORKDIR"
git clone "$REPO_URL" "$WORKDIR"
cd "$WORKDIR"

# =========================
# 创建 Dockerfile
# =========================
echo "📄 创建 Dockerfile..."
cat > Dockerfile <<EOF
FROM node:20-alpine
WORKDIR /app
COPY package.json pnpm-lock.yaml ./
RUN npm install -g pnpm && pnpm install
COPY . .
EXPOSE 3000
CMD ["node", "start.js"]
EOF

# =========================
# 构建 Docker 镜像
# =========================
echo "🛠 构建 Docker 镜像..."
docker build -t $IMAGE_NAME .

# =========================
# 创建 docker-compose.yml
# =========================
echo "📄 创建 docker-compose.yml..."
cat > docker-compose.yml <<EOF
version: "3.9"
services:
  lunatv-core:
    image: $IMAGE_NAME
    container_name: lunatv-core
    restart: on-failure
    ports:
      - '3000:3000'
    environment:
      - USERNAME=$USERNAME
      - PASSWORD=$PASSWORD
      - NEXT_PUBLIC_STORAGE_TYPE=kvrocks
      - KVROCKS_URL=redis://lunatv-kvrocks:6666
      - AUTH_TOKEN=$AUTH_TOKEN
    depends_on:
      - lunatv-kvrocks

  lunatv-kvrocks:
    image: apache/kvrocks
    container_name: lunatv-kvrocks
    restart: unless-stopped
    volumes:
      - $KVROCKS_VOLUME:/var/lib/kvrocks
EOF

# =========================
# 启动服务
# =========================
echo "🚀 启动 LunaTV + KVrocks..."
docker compose up -d

echo "✅ 部署完成！访问地址: http://<服务器IP>:3000"
echo "用户名：$USERNAME"
echo "密码：$PASSWORD"
echo "授权码：$AUTH_TOKEN"
