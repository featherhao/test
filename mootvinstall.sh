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
    if command -v apt &>/dev/null; then
      apt update && apt install -y docker-compose-plugin || apt install -y docker-compose
    elif command -v yum &>/dev/null; then
      yum install -y docker-compose-plugin || yum install -y docker-compose
    fi
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
  [ -f "$ENV_FILE" ] && cp "$ENV_FILE" "$ENV_FILE.bak.$(date +%s)"
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
    if ! ss -tulnp | grep -q ":$p"; then
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

  # 获取公网 IPv4 和 IPv6 地址
  IPV4=$(curl -4 -s ifconfig.me || hostname -I | awk '{print $1}')
  IPV6=$(curl -6 -s ifconfig.me || ip -6 addr show scope global | awk '{print $2}' | cut -d/ -f1 | head -n1)

  echo "✅ MoonTV 已启动"
  echo "👉 IPv4 访问地址: http://$IPV4:${HOST_PORT}"
  [[ -n "$IPV6" ]] && echo "👉 IPv6 访问地址: http://[$IPV6]:${HOST_PORT}"
  echo "👉 用户名: $(grep USERNAME $ENV_FILE | cut -d '=' -f2)"
  echo "👉 密码: $(grep PASSWORD $ENV_FILE | cut -d '=' -f2)"
}

# =========================
# 更新 MoonTV
# =========================
update() {
  echo "🔄 正在更新 MoonTV..."
  install_docker
  [ -f "$COMPOSE_FILE" ] || { echo "❌ 未找到 $COMPOSE_FILE，请先安装"; return 1; }

  cd $WORKDIR
  $DOCKER_COMPOSE pull
  $DOCKER_COMPOSE up -d
  echo "✅ 更新完成"
}

# =========================
# 卸载
# =========================
uninstall() {
  echo "⚠️ 即将卸载 MoonTV"
  read -rp "确认？(y/N): " CONFIRM
  [[ ! "$CONFIRM" =~ ^[Yy]$ ]] && { echo "已取消"; return; }
  install_docker
  if [ -f "$COMPOSE_FILE" ]; then
    read -rp "是否删除容器数据卷？(y/N): " DEL_VOL
    if [[ "$DEL_VOL" =~ ^[Yy]$ ]]; then
      $DOCKER_COMPOSE -f $COMPOSE_FILE down -v
    else
      $DOCKER_COMPOSE -f $COMPOSE_FILE down
    fi
  fi
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
    echo "7) 更新 MoonTV"
    echo "b) 返回上一级"
    echo "0) 退出"
    echo "=============================="
    read -rp "请输入选项: " choice

    case "$choice" in
      1) install_main ;;
      2) input_config ;;
      3) uninstall ;;
      4)
        if [ -d "$WORKDIR" ] && [ -f "$COMPOSE_FILE" ]; then
          cd "$WORKDIR"
          if command -v docker-compose &>/dev/null; then
            docker-compose start
          elif docker compose version &>/dev/null 2>&1; then
            docker compose start
          else
            echo "❌ Docker Compose 未安装"
          fi
        else
          echo "❌ MoonTV 未安装"
        fi
        ;;
      5)
        if [ -d "$WORKDIR" ] && [ -f "$COMPOSE_FILE" ]; then
          cd "$WORKDIR"
          if command -v docker-compose &>/dev/null; then
            docker-compose stop
          elif docker compose version &>/dev/null 2>&1; then
            docker compose stop
          else
            echo "❌ Docker Compose 未安装"
          fi
        else
          echo "❌ MoonTV 未安装"
        fi
        ;;
      6)
        if [ -d "$WORKDIR" ] && [ -f "$COMPOSE_FILE" ]; then
          cd "$WORKDIR"
          if command -v docker-compose &>/dev/null; then
            docker-compose logs -f
          elif docker compose version &>/dev/null 2>&1; then
            docker compose logs -f
          else
            echo "❌ Docker Compose 未安装，无法查看日志"
          fi
        else
          echo "❌ MoonTV 未安装或 $WORKDIR 不存在"
        fi
        ;;
      7) update ;;
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
