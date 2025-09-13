#!/bin/bash
set -e

WORKDIR="/root"
DATADIR="$WORKDIR/posteio_data"
COMPOSE_FILE="$WORKDIR/poste.io.docker-compose.yml"
CONTAINER_NAME="poste.io"

# 检查容器是否存在
check_installed() {
  if docker ps -a --format '{{.Names}}' | grep -q "^$CONTAINER_NAME$"; then
    echo "✅ Poste.io 已安装"
    echo "容器名称: $CONTAINER_NAME"
    echo "容器状态: $(docker inspect -f '{{.State.Status}}' $CONTAINER_NAME)"
    echo "数据目录: $DATADIR"

    # 提取 docker-compose 配置里的端口和域名
    DOMAIN=$(grep "HOSTNAME=" $COMPOSE_FILE | cut -d "=" -f2)
    HTTP_PORT=$(grep -m1 ":[0-9]*:80" $COMPOSE_FILE | cut -d '"' -f2 | cut -d ":" -f1)
    HTTPS_PORT=$(grep -m1 ":[0-9]*:443" $COMPOSE_FILE | cut -d '"' -f2 | cut -d ":" -f1)
    SERVER_IP=$(hostname -I | awk '{print $1}')

    echo "访问地址："
    echo "  - http://$DOMAIN:$HTTP_PORT"
    echo "  - https://$DOMAIN:$HTTPS_PORT"
    echo "  - http://$SERVER_IP:$HTTP_PORT"
    echo "  - https://$SERVER_IP:$HTTPS_PORT"
    echo "--------------------------"
    exit 0
  fi
}

install_poste() {
  echo "=== 开始安装 Poste.io ==="

  read -p "请输入您要使用的域名 (例如: mail.example.com): " DOMAIN
  read -p "请输入管理员邮箱 (例如: admin@$DOMAIN): " ADMIN_EMAIL
  read -p "请输入管理员密码: " ADMIN_PASS

  mkdir -p "$DATADIR"

  # 检查端口占用
  HTTP_PORT=80
  HTTPS_PORT=443
  if lsof -i:80 >/dev/null 2>&1; then
    HTTP_PORT=81
  fi
  if lsof -i:443 >/dev/null 2>&1; then
    HTTPS_PORT=444
  fi

  cat > "$COMPOSE_FILE" <<EOF
version: '3.3'
services:
  posteio:
    image: analogic/poste.io
    container_name: $CONTAINER_NAME
    restart: always
    ports:
      - "$HTTP_PORT:80"
      - "$HTTPS_PORT:443"
      - "25:25"
      - "465:465"
      - "587:587"
      - "110:110"
      - "995:995"
      - "143:143"
      - "993:993"
    volumes:
      - $DATADIR:/data
    environment:
      - HTTPS=OFF
      - DISABLE_CLAMAV=TRUE
      - DISABLE_SPAMASSASSIN=TRUE
      - LETSENCRYPT_EMAIL=$ADMIN_EMAIL
      - POSTMASTER_ADDRESS=$ADMIN_EMAIL
      - PASSWORD=$ADMIN_PASS
      - HOSTNAME=$DOMAIN
EOF

  echo "✅ 已生成 Docker Compose 文件：$COMPOSE_FILE"

  echo "正在启动 Poste.io 容器..."
  docker compose -f "$COMPOSE_FILE" up -d

  SERVER_IP=$(hostname -I | awk '{print $1}')

  echo "✅ 恭喜！Poste.io 安装并初始化完成！"
  echo "--- Poste.io 运行信息 ---"
  echo "容器名称: $CONTAINER_NAME"
  echo "数据目录: $DATADIR"
  echo "访问地址："
  echo "  - http://$DOMAIN:$HTTP_PORT"
  echo "  - https://$DOMAIN:$HTTPS_PORT"
  echo "  - http://$SERVER_IP:$HTTP_PORT"
  echo "  - https://$SERVER_IP:$HTTPS_PORT"
  echo "--------------------------"
}

# 主逻辑：先检查是否已安装
check_installed
install_poste
