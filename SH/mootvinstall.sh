#!/bin/bash
set -e

WORKDIR="/opt/moontv"
COMPOSE_FILE="$WORKDIR/docker-compose.yml"
ENV_FILE="$WORKDIR/.env"

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
  read -rp "是否确认保存？(Y/n): " CONFIRM
  CONFIRM=${CONFIRM:-Y} # 默认 Y
  [[ ! "$CONFIRM" =~ ^[Yy]$ ]] && { echo "已取消"; return 1; }

  mkdir -p "$WORKDIR"
  [ -f "$ENV_FILE" ] && cp "$ENV_FILE" "$ENV_FILE.bak.$(date +%s)"
  cat > "$ENV_FILE" <<EOF
USERNAME=$USERNAME
PASSWORD=$PASSWORD
AUTH_TOKEN=$AUTH_TOKEN
EOF
  chmod 600 "$ENV_FILE"
  echo "✅ 配置已保存"
}

# =========================
# 镜像选择
# =========================
choose_image() {
  echo "📦 请选择安装镜像："
  echo "1) 小黄人大佬镜像（带弹幕）(默认) ghcr.io/szemeng76/lunatv:latest"
  echo "2) 官方镜像 ghcr.io/moontechlab/lunatv:latest"
  echo "3) Docker Hub 镜像 (官方备用镜像) featherhao/lunatv:latest"
  echo "4) Docker Hub 镜像 （100版本号防作者删库用） featherhao/moontv:100"
  read -rp "请输入数字 [1-4] (默认 1): " img_choice
  img_choice=${img_choice:-1}
  case "$img_choice" in
    1) IMAGE="ghcr.io/szemeng76/lunatv:latest" ;;
    2) IMAGE="ghcr.io/moontechlab/lunatv:latest" ;;
    3) IMAGE="featherhao/lunatv:latest" ;;
    4) IMAGE="featherhao/moontv:100" ;;
    *) IMAGE="ghcr.io/szemeng76/lunatv:latest" ;;
  esac
  echo "使用镜像: $IMAGE"
}

# =========================
# 选择端口并生成 docker-compose.yml
# =========================
choose_port_and_write_compose() {
  POSSIBLE_PORTS=(8181 9090 10080 18080 28080)
  HOST_PORT=""
  for p in "${POSSIBLE_PORTS[@]}"; do
    if ! ss -tulnp | grep -q ":$p"; then
      HOST_PORT=$p
      break
    fi
  done
  [[ -z "$HOST_PORT" ]] && { echo "❌ 没有可用端口"; return 1; }
  echo "使用端口 $HOST_PORT"

  cat > "$COMPOSE_FILE" <<EOF
services:
  moontv-core:
    image: $IMAGE
    container_name: moontv-core
    restart: unless-stopped
    ports:
      - '$HOST_PORT:3000'
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
# 更新
# =========================
update() {
  echo "🔄 请选择更新镜像："
  choose_image
  if [ -f "$COMPOSE_FILE" ]; then
    cd "$WORKDIR"
    echo "📦 拉取镜像 $IMAGE..."
    docker pull "$IMAGE"
    $DOCKER_COMPOSE -f "$COMPOSE_FILE" up -d
    echo "✅ 更新完成"
  else
    echo "❌ 未找到 $COMPOSE_FILE，请先安装"
  fi
}

# =========================
# 卸载
# =========================
uninstall() {
  echo "⚠️ 即将卸载 MoonTV"
  read -rp "确认？(Y/n): " CONFIRM
  CONFIRM=${CONFIRM:-Y} # 默认 Y
  [[ ! "$CONFIRM" =~ ^[Yy]$ ]] && { echo "已取消"; return; }
  if [ -f "$COMPOSE_FILE" ]; then
    read -rp "是否删除容器数据卷？(Y/n): " DEL_VOL
    DEL_VOL=${DEL_VOL:-Y} # 默认 Y
    if [[ "$DEL_VOL" =~ ^[Yy]$ ]]; then
      $DOCKER_COMPOSE -f "$COMPOSE_FILE" down -v
    else
      $DOCKER_COMPOSE -f "$COMPOSE_FILE" down
    fi
  fi
  read -rp "是否删除 $WORKDIR 目录？(Y/n): " DEL_DIR
  DEL_DIR=${DEL_DIR:-Y} # 默认 Y
  [[ "$DEL_DIR" =~ ^[Yy]$ ]] && rm -rf "$WORKDIR"
  echo "✅ 卸载完成"
}

# =========================
# 管理菜单
# =========================
moontv_menu() {
  while true; do
    clear

    if [ -d "$WORKDIR" ] && [ -f "$COMPOSE_FILE" ]; then
      STATUS="已安装 ✅"
      CONFIG_DISPLAY="配置："

      if [ -f "$ENV_FILE" ]; then
        CONFIG_DISPLAY+=$'\n'"$(grep -E "USERNAME|PASSWORD|AUTH_TOKEN" "$ENV_FILE")"
      else
        CONFIG_DISPLAY+=" ❌ 配置文件不存在"
      fi

      HOST_PORT=$(grep -Po "(?<=- )\d+(?=:3000)" "$COMPOSE_FILE" | tr -d "'")
      HOST_PORT=${HOST_PORT:-8181}

      IPV4=$(curl -4 -s ifconfig.me || hostname -I | awk '{print $1}')
      IPV6=$(curl -6 -s ifconfig.me || ip -6 addr show scope global | awk '{print $2}' | cut -d/ -f1 | head -n1)

      CONFIG_DISPLAY+=$'\n'"访问地址："
      CONFIG_DISPLAY+=$'\n'"IPv4: http://$IPV4:$HOST_PORT"
      [[ -n "$IPV6" ]] && CONFIG_DISPLAY+=$'\n'"IPv6: http://[$IPV6]:$HOST_PORT"

    else
      STATUS="未安装 ❌"
      CONFIG_DISPLAY=""
    fi

    if [ "$STATUS" = "已安装 ✅" ]; then
      echo -e "状态: \e[32m$STATUS\e[0m"
    else
      echo -e "状态: \e[31m$STATUS\e[0m"
    fi

    [ -n "$CONFIG_DISPLAY" ] && echo -e "$CONFIG_DISPLAY"

    echo "------------------------------"
    echo "1) 安装 / 初始化 MoonTV"
    echo "2) 修改 MoonTV 配置"
    echo "3) 卸载 MoonTV"
    echo "4) 启动 MoonTV"
    echo "5) 停止 MoonTV"
    echo "6) 查看运行日志"
    echo "00) 更新 MoonTV" # 选项已修改
    echo "b) 返回上一级"
    echo "0) 退出"
    echo "=============================="
    read -rp "请输入选项: " choice

    case "$choice" in
      1)
        if [ "$STATUS" = "已安装 ✅" ]; then
          echo "❌ MoonTV 已安装，如需重新安装请先卸载"
        else
          input_config
          choose_image
          choose_port_and_write_compose
          $DOCKER_COMPOSE -f "$COMPOSE_FILE" up -d
          echo "✅ MoonTV 已启动"
        fi
        ;;
      2) input_config ;;
      3) uninstall ;;
      4)
        if [ "$STATUS" = "已安装 ✅" ]; then
          cd "$WORKDIR"
          $DOCKER_COMPOSE start
        else
          echo "❌ MoonTV 未安装"
        fi
        ;;
      5)
        if [ "$STATUS" = "已安装 ✅" ]; then
          cd "$WORKDIR"
          $DOCKER_COMPOSE stop
        else
          echo "❌ MoonTV 未安装"
        fi
        ;;
      6)
        if [ "$STATUS" = "已安装 ✅" ]; then
          cd "$WORKDIR"
          read -rp "是否持续跟踪日志？(Y/n): " LOG_FOLLOW
          LOG_FOLLOW=${LOG_FOLLOW:-Y} # 默认 Y
          if [[ "$LOG_FOLLOW" =~ ^[Yy]$ ]]; then
            $DOCKER_COMPOSE logs -f
          else
            $DOCKER_COMPOSE logs --tail 50
          fi
        else
          echo "❌ MoonTV 未安装"
        fi
        ;;
      00) # 对应新的更新选项
        if [ "$STATUS" = "已安装 ✅" ]; then
          update
        else
          echo "❌ MoonTV 未安装，无法更新"
        fi
        ;;
      b|B) break ;;
      0) exit 0 ;;
      *) echo "❌ 无效输入，请重新选择" ;;
    esac

    read -rp "按回车继续..."
  done
}

# =========================
# 自动检查安装并启动菜单
# =========================
install_docker
if [ ! -d "$WORKDIR" ] || [ ! -f "$COMPOSE_FILE" ]; then
  echo "ℹ️ MoonTV 未安装，开始初始化安装..."
  input_config
  IMAGE="ghcr.io/szemeng76/lunatv:latest" # 默认使用带弹幕的镜像
  echo "使用默认镜像: $IMAGE"
  choose_port_and_write_compose
  $DOCKER_COMPOSE -f "$COMPOSE_FILE" up -d

  IPV4=$(curl -4 -s ifconfig.me || hostname -I | awk '{print $1}')
  IPV6=$(curl -6 -s ifconfig.me || ip -6 addr show scope global | awk '{print $2}' | cut -d/ -f1 | head -n1)
  HOST_PORT=$(grep -Po "(?<=- )\d+(?=:3000)" "$COMPOSE_FILE" | tr -d "'")
  HOST_PORT=${HOST_PORT:-8181}

  echo "✅ MoonTV 已启动"
  echo "👉 IPv4 访问地址: http://$IPV4:$HOST_PORT"
  [[ -n "$IPV6" ]] && echo "👉 IPv6 访问地址: http://[$IPV6]:$HOST_PORT"
  echo "👉 用户名: $(grep USERNAME "$ENV_FILE" | cut -d '=' -f2)"
  echo "👉 密码: $(grep PASSWORD "$ENV_FILE" | cut -d '=' -f2)"
fi

moontv_menu