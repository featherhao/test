#!/bin/bash
set -e

WORKDIR=/opt/moontv
COMPOSE_FILE=$WORKDIR/docker-compose.yml
ENV_FILE=$WORKDIR/.env

# === 安装 docker & docker-compose ===
install_docker() {
  echo "📦 正在安装 Docker 和 Docker Compose..."
  if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com | bash
  fi

  if ! command -v docker compose &> /dev/null && ! command -v docker-compose &> /dev/null; then
    apt update && apt install -y docker-compose-plugin || apt install -y docker-compose
  fi

  # 兼容 docker compose 命令
  if command -v docker-compose &>/dev/null; then
    DOCKER_COMPOSE="docker-compose"
  else
    DOCKER_COMPOSE="docker compose"
  fi
}

# === 输入配置参数 ===
input_config() {
  echo "⚙️  开始配置 MoonTV 参数："
  
  read -rp "请输入用户名 (默认 admin): " USERNAME
  USERNAME=${USERNAME:-admin}

  read -rp "请输入密码 (留空则自动生成随机密码): " PASSWORD
  PASSWORD=${PASSWORD:-$(openssl rand -hex 6)}

  read -rp "请输入 AUTH_TOKEN (留空则自动生成随机 token): " AUTH_TOKEN
  AUTH_TOKEN=${AUTH_TOKEN:-$(openssl rand -hex 16)}

  echo
  echo "================= 配置信息确认 ================="
  echo "👉 用户名: $USERNAME"
  echo "👉 密码: $PASSWORD"
  echo "👉 AUTH_TOKEN: $AUTH_TOKEN"
  echo "================================================"
  read -rp "是否确认保存？(y/N): " CONFIRM

  if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo "❌ 已取消配置"
    exit 1
  fi

  mkdir -p $WORKDIR
  cat > $ENV_FILE <<EOF
USERNAME=$USERNAME
PASSWORD=$PASSWORD
AUTH_TOKEN=$AUTH_TOKEN
EOF

  echo "✅ 配置已写入 $ENV_FILE"
}

# === 检查可用端口 ===
choose_port_and_write_compose() {
  POSSIBLE_PORTS=(8181 9090 10080 18080 28080)
  for p in "${POSSIBLE_PORTS[@]}"; do
    if ! ss -tulnp | grep -q ":$p" && ! lsof -i :$p &>/dev/null; then
      HOST_PORT=$p
      break
    fi
  done

  if [ -z "$HOST_PORT" ]; then
    echo "❌ 没有可用的端口，请手动修改 docker-compose.yml"
    exit 1
  fi

  echo "✅ 使用端口 $HOST_PORT"

  cat > $COMPOSE_FILE <<EOF
services:
  moontv-core:
    image: ghcr.io/moontechlab/lunatv:latest
    container_name: moontv-core
    restart: unless-stopped
    ports:
      - '${HOST_PORT}:3000'
    env_file:
      - .env
    environment:
      - NEXT_PUBLIC_STORAGE_TYPE=kvrocks
      - KVROCKS_URL=redis://moontv-kvrocks:6666
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
}

# === 主安装逻辑 ===
install_main() {
  install_docker

  if [ ! -f "$ENV_FILE" ]; then
    input_config
  else
    echo "✅ 已存在 .env 文件，跳过生成"
    echo "👉 用户名: $(grep USERNAME $ENV_FILE | cut -d '=' -f2)"
    echo "👉 密码: $(grep PASSWORD $ENV_FILE | cut -d '=' -f2)"
    echo "👉 AUTH_TOKEN: $(grep AUTH_TOKEN $ENV_FILE | cut -d '=' -f2)"
  fi

  choose_port_and_write_compose

  $DOCKER_COMPOSE -f $COMPOSE_FILE up -d

  echo "✅ MoonTV 已启动"
  echo "👉 访问地址: http://$(hostname -I | awk '{print $1}'):${HOST_PORT}"
  echo "👉 用户名: $(grep USERNAME $ENV_FILE | cut -d '=' -f2)"
  echo "👉 密码: $(grep PASSWORD $ENV_FILE | cut -d '=' -f2)"
}

# === 根据参数执行 ===
case "$1" in
  config)
    input_config
    ;;
  *)
    install_main
    ;;
esac
