#!/bin/bash
set -e

# 配置
WORKDIR=/root/rustdesk-oss
COMPOSE_FILE=$WORKDIR/docker-compose.yml
PORTS=(21115 21116 21117)

mkdir -p $WORKDIR
cd $WORKDIR

echo "🐳 下载 RustDesk OSS 官方 compose 文件..."
curl -fsSL https://raw.githubusercontent.com/ynnie/rustdesk-server/master/docker-compose.yml -o $COMPOSE_FILE
echo "✅ 下载完成"

# 检查并释放端口
echo "⚠️ 检查并清理占用端口..."
for PORT in "${PORTS[@]}"; do
    PID=$(lsof -iTCP:$PORT -sTCP:LISTEN -t || true)
    if [ -n "$PID" ]; then
        echo "⚠️ 端口 $PORT 被占用，杀掉 PID: $PID"
        kill -9 $PID || true
    fi
done
echo "✅ 所有端口已释放"

# 修正 compose 文件，去掉 PRO 版参数 -m
sed -i 's/-m//g' $COMPOSE_FILE

# 启动容器
echo "🚀 启动 RustDesk OSS 容器..."
docker compose -f $COMPOSE_FILE up -d

# 等待 hbbs 生成客户端 Key
echo "⏳ 等待 hbbs 生成客户端 Key..."
until docker exec rust_desk_hbbs test -f /root/id_ed25519.pub; do
    sleep 3
done
KEY=$(docker exec rust_desk_hbbs cat /root/id_ed25519.pub)

# 获取公网 IP
PUBLIC_IP=$(curl -s https://api.ipify.org)

# 显示信息
echo "✅ RustDesk OSS 安装完成"
echo "🌐 服务端连接信息："
echo "ID Server : $PUBLIC_IP:21115"
echo "Relay     : $PUBLIC_IP:21116"
echo "API       : $PUBLIC_IP:21117"
echo ""
echo "🔑 客户端 Key:"
echo "$KEY"
