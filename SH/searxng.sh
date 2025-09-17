#!/bin/bash
set -Eeuo pipefail

# ========== 配置 ==========
WORKDIR="/opt/searxng"
SERVICE_NAME="searxng"
COMPOSE_FILE="docker-compose.yaml"
BASE_PORT=8585

# ========== 彩色输出 ==========
C_RESET="\e[0m"; C_GREEN="\e[32m"; C_RED="\e[31m"; C_YELLOW="\e[33m"
log() { echo -e "${C_GREEN}[INFO]${C_RESET} $*"; }
warn() { echo -e "${C_YELLOW}[WARN]${C_RESET} $*"; }
error() { echo -e "${C_RED}[ERROR]${C_RESET} $*" >&2; }

# ========== 获取公网 IP ==========
get_public_ip() {
  ipv4=$(curl -s --max-time 5 ipv4.icanhazip.com || true)
  ipv6=$(curl -s --max-time 5 ipv6.icanhazip.com || true)
  [ -n "$ipv4" ] && echo "http://$ipv4:$1"
  [ -n "$ipv6" ] && echo "http://[$ipv6]:$1"
}

# ========== 查找可用端口 ==========
find_free_port() {
  port=$BASE_PORT
  while ss -tuln | grep -q ":$port "; do
    port=$((port+1))
  done
  echo $port
}

# ========== 工具检查 ==========
check_requirements() {
  if ! command -v docker &>/dev/null; then
    log "正在安装 Docker..."
    apt-get update
    apt-get install -y docker.io
  fi
  if ! command -v docker-compose &>/dev/null; then
    log "正在安装 Docker Compose..."
    apt-get install -y docker-compose
  fi
  if ! command -v curl &>/dev/null; then
    apt-get install -y curl
  fi
}

# ========== docker-compose 配置 ==========
generate_compose() {
  port=$(find_free_port)
  mkdir -p "$WORKDIR"
  cat >"$WORKDIR/$COMPOSE_FILE" <<EOF
version: '3'

services:
  searxng:
    image: searxng/searxng:latest
    container_name: searxng
    restart: always
    ports:
      - "$port:8080"
    volumes:
      - ./searxng:/etc/searxng
EOF
  echo $port >"$WORKDIR/port"
}

get_port() {
  if [ -f "$WORKDIR/port" ]; then
    cat "$WORKDIR/port"
  else
    echo $BASE_PORT
  fi
}

# ========== 安装 ==========
action_install() {
  check_requirements
  if [ ! -f "$WORKDIR/$COMPOSE_FILE" ]; then
    log "生成 docker-compose 配置..."
    generate_compose
  fi
  log "启动 SearxNG..."
  (cd "$WORKDIR" && docker-compose up -d)
  port=$(get_port)
  log "✅ 安装完成！访问地址："
  get_public_ip $port
}

# ========== 更新 ==========
action_update() {
  if [ ! -f "$WORKDIR/$COMPOSE_FILE" ]; then
    error "未安装 SearxNG！"
    return
  fi
  log "更新镜像并重启..."
  (cd "$WORKDIR" && docker-compose pull && docker-compose up -d)
  port=$(get_port)
  log "✅ 更新完成！访问地址："
  get_public_ip $port
}

# ========== 卸载 ==========
action_uninstall() {
  if [ -f "$WORKDIR/$COMPOSE_FILE" ]; then
    log "正在卸载..."
    (cd "$WORKDIR" && docker-compose down -v)
    rm -rf "$WORKDIR"
    systemctl disable "$SERVICE_NAME" >/dev/null 2>&1 || true
    rm -f "/etc/systemd/system/${SERVICE_NAME}.service"
    systemctl daemon-reload
    log "✅ 卸载完成！"
  else
    warn "未检测到安装目录，无需卸载。"
  fi
}

# ========== 开机自启 ==========
action_enable_service() {
  cat >/etc/systemd/system/${SERVICE_NAME}.service <<EOF
[Unit]
Description=SearxNG Service
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
WorkingDirectory=$WORKDIR
ExecStart=/usr/bin/docker-compose up -d
ExecStop=/usr/bin/docker-compose down
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  systemctl enable ${SERVICE_NAME}
  log "✅ 已设置开机自启！"
}

# ========== 菜单 ==========
interactive_menu() {
  while true; do
    cat <<EOF

====================================
   🚀 SearxNG 管理菜单
   安装目录: $WORKDIR
------------------------------------
   1) 安装 SearxNG
   2) 更新并重启
   3) 卸载 SearxNG
   4) 查看容器状态
   5) 查看运行日志
   6) 编辑配置 (docker-compose.yaml)
   7) 设置开机自启
   0) 退出菜单
====================================

EOF
    read -r -p "请输入选择(0-7): " choice
    case "$choice" in
      1) action_install ;;
      2) action_update ;;
      3) action_uninstall ;;
      4) (cd "$WORKDIR" && docker-compose ps) || warn "无法获取状态" ;;
      5) (cd "$WORKDIR" && docker-compose logs -f --tail=100) ;;
      6) ${EDITOR:-vi} "$WORKDIR/$COMPOSE_FILE" ;;
      7) action_enable_service ;;
      0) log "已退出菜单"; break ;;
      *) warn "无效选择，请重新输入" ;;
    esac
  done
}

# ========== 主程序 ==========
interactive_menu
