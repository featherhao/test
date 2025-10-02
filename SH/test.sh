#!/bin/bash
set -e

WORKDIR="/root"
DATADIR="$WORKDIR/posteio_data"
COMPOSE_FILE="$WORKDIR/poste.io.docker-compose.yml"
CONTAINER_NAME="poste.io"
IMAGE="analogic/poste.io"

# docker compose wrapper (兼容 docker-compose 和 docker compose)
DOCKER_COMPOSE() {
  if command -v docker-compose >/dev/null 2>&1; then
    docker-compose "$@"
  else
    docker compose "$@"
  fi
}

# 简单检查 Docker
ensure_docker() {
  if ! command -v docker >/dev/null 2>&1; then
    echo "❌ 未检测到 docker，请先安装 Docker 后重试。"
    exit 1
  fi
}

# 检查是否已安装（容器存在）
check_installed() {
  docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"
}

# 从 compose 文件读取 DOMAIN / 端口（容错）
read_compose_info() {
  DOMAIN=""
  HTTP_PORT="80"
  HTTPS_PORT="443"
  ADMIN_EMAIL=""
  if [ -f "$COMPOSE_FILE" ]; then
    # 读取 HOSTNAME / POSTMASTER_ADDRESS
    DOMAIN=$(grep -m1 -E 'HOSTNAME=' "$COMPOSE_FILE" 2>/dev/null | sed -E 's/.*HOSTNAME=//;s/\s*$//' || true)
    ADMIN_EMAIL=$(grep -m1 -E 'POSTMASTER_ADDRESS=' "$COMPOSE_FILE" 2>/dev/null | sed -E 's/.*POSTMASTER_ADDRESS=//;s/\s*$//' || true)

    # 尝试读取映射到容器 80/443 的宿主端口（支持双引号格式 - "81:80"）
    if grep -q ':80"' "$COMPOSE_FILE" 2>/dev/null; then
      HTTP_PORT=$(grep -Po '^\s*-\s*"\K(\d+)(?=:80")' "$COMPOSE_FILE" 2>/dev/null || echo "80")
    elif grep -q ':80' "$COMPOSE_FILE" 2>/dev/null; then
      HTTP_PORT=$(grep -Po '^\s*-\s*\K(\d+)(?=:80)' "$COMPOSE_FILE" 2>/dev/null || echo "80")
    fi

    if grep -q ':443"' "$COMPOSE_FILE" 2>/dev/null; then
      HTTPS_PORT=$(grep -Po '^\s*-\s*"\K(\d+)(?=:443")' "$COMPOSE_FILE" 2>/dev/null || echo "443")
    elif grep -q ':443' "$COMPOSE_FILE" 2>/dev/null; then
      HTTPS_PORT=$(grep -Po '^\s*-\s*\K(\d+)(?=:443)' "$COMPOSE_FILE" 2>/dev/null || echo "443")
    fi
  fi
}

# 获取首个可用本机 IP（用于展示）
get_server_ip() {
  # 优先使用 hostname -I，如果没有再使用 curl 公网 IP（如果有）
  local ip
  ip=$(hostname -I 2>/dev/null | awk '{print $1}')
  if [ -z "$ip" ]; then
    if command -v curl >/dev/null 2>&1; then
      ip=$(curl -s4 https://api.ipify.org || true)
    fi
  fi
  echo "$ip"
}

# 显示信息：域名不带端口，IP 带端口（若为非标准端口）
show_info() {
  read_compose_info
  local server_ip
  server_ip=$(get_server_ip)

  echo "----- Poste.io 运行信息 -----"
  echo "容器名称: ${CONTAINER_NAME}"
  echo "容器状态: $(docker inspect -f '{{.State.Status}}' ${CONTAINER_NAME} 2>/dev/null || echo '未运行')"
  echo "数据目录: ${DATADIR}"
  [ -n "$ADMIN_EMAIL" ] && echo "管理员邮箱: ${ADMIN_EMAIL}"
  echo ""
  echo "访问地址："

  # 域名：直接显示不带端口（按你的要求）
  if [ -n "$DOMAIN" ]; then
    echo "  - 域名 (不带端口)："
    echo "      http  : http://${DOMAIN}"
    echo "      https : https://${DOMAIN}"
    # 如果使用了非标准端口，提示一下（可选）
    if [ "${HTTP_PORT}" != "80" ] || [ "${HTTPS_PORT}" != "443" ]; then
      echo "    ⚠️ 注意：宿主端口映射为 HTTP=${HTTP_PORT}, HTTPS=${HTTPS_PORT}，若未通过反向代理或 DNS 端口转发，直接访问域名可能需要额外配置。"
    fi
  else
    echo "  - 域名：未在 Compose 文件中检测到 HOSTNAME（未设置）"
  fi

  # IP：带端口（非标准端口才加）
  if [ -n "$server_ip" ]; then
    local http_ip_url="http://${server_ip}"
    local https_ip_url="https://${server_ip}"
    if [ "${HTTP_PORT}" != "80" ]; then
      http_ip_url="${http_ip_url}:${HTTP_PORT}"
    fi
    if [ "${HTTPS_PORT}" != "443" ]; then
      https_ip_url="${https_ip_url}:${HTTPS_PORT}"
    fi
    echo ""
    echo "  - IP (带端口)："
    echo "      ${http_ip_url}"
    echo "      ${https_ip_url}"
  else
    echo "  - 无可用本机 IP 用于显示"
  fi

  echo "----------------------------"
}

# 安装
install_poste() {
  ensure_docker

  if check_installed; then
    echo "ℹ️ 检测到 Poste.io 已存在，显示当前信息："
    show_info
    return
  fi

  echo "=== 开始安装 Poste.io ==="
  read -p "请输入您要使用的域名 (例如: mail.example.com): " DOMAIN
  read -p "请输入管理员邮箱 (例如: admin@$DOMAIN): " ADMIN_EMAIL
  read -p "请输入管理员密码: " ADMIN_PASS

  mkdir -p "$DATADIR"

  # 检查端口占用，优先 80/443，否则备用 81/444
  HTTP_PORT=80
  HTTPS_PORT=443
  if command -v lsof >/dev/null 2>&1; then
    if lsof -i :80 >/dev/null 2>&1; then HTTP_PORT=81; fi
    if lsof -i :443 >/dev/null 2>&1; then HTTPS_PORT=444; fi
  else
    # 没有 lsof 时用 ss 作为替代（更常见于精简系统）
    if ss -ltn "( sport = :80 )" >/dev/null 2>&1; then HTTP_PORT=81; fi
    if ss -ltn "( sport = :443 )" >/dev/null 2>&1; then HTTPS_PORT=444; fi
  fi

  # 生成 compose 文件
  cat > "$COMPOSE_FILE" <<EOF
version: '3.3'
services:
  posteio:
    image: ${IMAGE}
    container_name: ${CONTAINER_NAME}
    restart: always
    ports:
      - "${HTTP_PORT}:80"
      - "${HTTPS_PORT}:443"
      - "25:25"
      - "465:465"
      - "587:587"
      - "110:110"
      - "995:995"
      - "143:143"
      - "993:993"
    volumes:
      - ${DATADIR}:/data
    environment:
      - HTTPS=OFF
      - DISABLE_CLAMAV=TRUE
      - DISABLE_SPAMASSASSIN=TRUE
      - LETSENCRYPT_EMAIL=${ADMIN_EMAIL}
      - POSTMASTER_ADDRESS=${ADMIN_EMAIL}
      - PASSWORD=${ADMIN_PASS}
      - HOSTNAME=${DOMAIN}
EOF

  echo "✅ 已生成 Docker Compose 文件：${COMPOSE_FILE}"
  echo "正在启动 Poste.io 容器（如无 docker compose，请安装）..."
  DOCKER_COMPOSE -f "$COMPOSE_FILE" up -d

  echo "✅ Poste.io 安装并初始化完成！"
  show_info
}

# 更新
update_poste() {
  ensure_docker
  if ! check_installed; then
    echo "❌ 未检测到 Poste.io 容器，无法更新。请先安装。"
    return
  fi
  echo "=== 开始更新 Poste.io ==="
  DOCKER_COMPOSE -f "$COMPOSE_FILE" pull
  DOCKER_COMPOSE -f "$COMPOSE_FILE" up -d
  echo "✅ 更新完成。"
  show_info
}

# 卸载
uninstall_poste() {
  ensure_docker
  if ! check_installed; then
    echo "ℹ️ 未检测到 Poste.io 容器，已退出。"
    return
  fi
  echo "⚠️ 警告：卸载将停止并删除容器，数据目录 ${DATADIR} 也可能被删除。"
  read -p "是否继续卸载？(y/N): " confirm
  if [[ ! "${confirm}" =~ ^[Yy]$ ]]; then
    echo "已取消卸载。"
    return
  fi

  DOCKER_COMPOSE -f "$COMPOSE_FILE" down || true
  read -p "是否同时删除数据目录 ${DATADIR} ? (y/N): " deldata
  if [[ "${deldata}" =~ ^[Yy]$ ]]; then
    rm -rf "${DATADIR}"
    echo "已删除数据目录。"
  fi
  rm -f "${COMPOSE_FILE}"
  echo "✅ 卸载完成。"
}

# 主菜单循环
while true; do
  echo "=============================="
  echo " Poste.io 管理脚本"
  echo "=============================="

  if check_installed; then
    echo "检测到 Poste.io 已安装。"
    echo "1) 显示信息"
    echo "2) 更新 Poste.io"
    echo "3) 卸载 Poste.io"
    echo "0) 退出"
    read -p "请输入选项: " choice
    case "$choice" in
      1) show_info ;;
      2) update_poste ;;
      3) uninstall_poste ;;
      0) exit 0 ;;
      *) echo "无效选项";;
    esac
  else
    echo "尚未安装 Poste.io。"
    echo "1) 安装 Poste.io"
    echo "0) 退出"
    read -p "请输入选项: " choice
    case "$choice" in
      1) install_poste ;;
      0) exit 0 ;;
      *) echo "无效选项";;
    esac
  fi

  echo ""
done