#!/bin/bash
set -e

WORKDIR=/opt/moontv
COMPOSE_FILE=$WORKDIR/docker-compose.yml
ENV_FILE=$WORKDIR/.env

# =========================
# 安装 Docker & Docker Compose
# =========================
install_docker() {
  echo "📦 安装 Docker 和 Docker Compose..."
  if ! command -v docker &>/dev/null; then
    curl -fsSL https://get.docker.com | bash
  fi
  if ! command -v docker compose &>/dev/null && ! command -v docker-compose &>/dev/null; then
    apt update && apt install -y docker-compose-plugin || apt install -y docker-compose
  fi
  if command -v docker-compose &>/dev/null; then
    DOCKER_COMPOSE="docker-compose"
  else
    DOCKER_COMPOSE="docker compose"
  fi
}

# =========================
# 输入配置
# =========================
input_config() {
  echo "⚙️ 配置 MoonTV 参数："
  read -rp "用户名 (默认 admin): " USERNAME
  USERNAME=${USERNAME:-admin}
  read -rp "密码 (留空自动生成): " PASSWORD
  PASSWORD=${PASSWORD:-$(openssl rand -hex 6)}
  read -rp "AUTH_TOKEN (留空自动生成): " AUTH_TOKEN
  AUTH_TOKEN=${AUTH_TOKEN:-$(openssl rand -hex 16)}

  echo
  echo "================= 配置信息确认 ================="
  echo "用户名: $USERNAME"
  echo "密码: $PASSWORD"
  echo "AUTH_TOKEN: $AUTH_TOKEN"
  echo "==============================================="
  read -rp "是否确认保存？(y/N): " CONFIRM
  [[ ! "$CONFIRM" =~ ^[Yy]$ ]] && { echo "已取消"; return 1; }

  mkdir -p $WORKDIR
  cat > $ENV_FILE <<EOF
USERNAME=$USERNAME
PASSWORD=$PASSWORD
AUTH_TOKEN=$AUTH_TOKEN
EOF
  echo "✅ 配置已保存"
}

# =========================
# 检查端口并生成 docker-compose.yml
# =========================
choose_port_and_write_compose() {
  POSSIBLE_PORTS=(8181 9090 10080 18080 28080)
  for p in "${POSSIBLE_PORTS[@]}"; do
    if ! ss -tulnp | grep -q ":$p" && ! lsof -i :$p &>/dev/null; then
      HOST_PORT=$p
      break
    fi
  done
  [[ -z "$HOST_PORT" ]] && { echo "没有可用端口"; return 1; }
  echo "使用端口 $HOST_PORT"

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

# =========================
# 安装 / 启动
# =========================
install_main() {
  install_docker
  [[ ! -f "$ENV_FILE" ]] && input_config || echo "✅ 已存在配置文件"
  choose_port_and_write_compose
  $DOCKER_COMPOSE -f $COMPOSE_FILE up -d

  # 获取 IPv4 和 IPv6 地址
  IPV4=$(hostname -I | awk '{print $1}')
  IPV6=$(ip -6 addr show scope global | grep inet6 | awk '{print $2}' | cut -d/ -f1 | head -n1)

  echo "✅ MoonTV 已启动"
  echo "👉 IPv4 访问地址: http://$IPV4:${HOST_PORT}"
  [[ -n "$IPV6" ]] && echo "👉 IPv6 访问地址: http://[$IPV6]:${HOST_PORT}"
  echo "👉 用户名: $(grep USERNAME $ENV_FILE | cut -d '=' -f2)"
  echo "👉 密码: $(grep PASSWORD $ENV_FILE | cut -d '=' -f2)"
}

# =========================
# 卸载
# =========================
uninstall() {
  echo "⚠️ 即将卸载 MoonTV"
  read -rp "确认？(y/N): " CONFIRM
  [[ ! "$CONFIRM" =~ ^[Yy]$ ]] && { echo "已取消"; return; }
  install_docker
  [ -f "$COMPOSE_FILE" ] && $DOCKER_COMPOSE -f $COMPOSE_FILE down -v
  read -rp "是否删除 $WORKDIR 目录？(y/N): " DEL_DIR
  [[ "$DEL_DIR" =~ ^[Yy]$ ]] && rm -rf "$WORKDIR"
  echo "✅ 卸载完成"
}

# =========================
# MoonTV 二级菜单
# =========================
moontv_menu() {
  while true; do
    clear
    echo "=============================="
    echo "       🎬 MoonTV 管理菜单"
    echo "=============================="
    echo "1) 安装 / 初始化 MoonTV"
    echo "2) 修改 MoonTV 配置"
    echo "3) 卸载 MoonTV"
    echo "4) 启动 MoonTV"
    echo "5) 停止 MoonTV"
    echo "6) 查看运行日志"
    echo "b) 返回上一级"
    echo "0) 退出"
    echo "=============================="
    read -rp "请输入选项: " choice

    case "$choice" in
      1) install_main ;;
      2) input_config ;;
      3) uninstall ;;
      4) cd /opt/moontv && $DOCKER_COMPOSE start ;;
      5) cd /opt/moontv && $DOCKER_COMPOSE stop ;;
      6) cd /opt/moontv && $DOCKER_COMPOSE logs -f ;;
      b|B) break ;;
      0) exit 0 ;;
      *) echo "❌ 无效输入，请重新选择" ;;
    esac
    read -rp "按回车继续..."
  done
}

# =========================
# 脚本入口
# =========================
moontv_menu
