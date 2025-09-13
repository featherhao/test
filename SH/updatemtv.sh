#!/bin/bash
set -e

WORKDIR=/opt/moontv
COMPOSE_FILE=$WORKDIR/docker-compose.yml

if [ ! -f "$COMPOSE_FILE" ]; then
  echo "❌ 没有找到 $COMPOSE_FILE，请先运行 install.sh 安装 MoonTV"
  exit 1
fi

cd $WORKDIR

echo "📦 拉取最新镜像..."
docker compose pull

echo "🔄 重启容器..."
docker compose up -d

echo "✅ 更新完成！"
