#!/bin/bash
set -e

# ==========================================================
# IPTV Aggregator 一体化管理脚本
# 支持：
#   install   安装 / 启动
#   uninstall 卸载（含数据）
#   restart   重启服务
#   status    查看运行状态
#   logs      查看日志
#
# 特点：
#   - host 网络（绕过 iptables）
#   - 保留官方 docker-compose 原始注释
#   - 适合 Oracle / NAT / 精简 VPS
# ==========================================================

APP_NAME="iptv-aggregator"
INSTALL_DIR="/opt/${APP_NAME}"
COMPOSE_FILE="${INSTALL_DIR}/docker-compose.yml"

# ================== 权限检查 ==================
if [ "$EUID" -ne 0 ]; then
  echo "❌ 请使用 root 用户运行"
  exit 1
fi

# ================== 工具函数 ==================
info()  { echo -e "\033[32m[INFO]\033[0m $1"; }
warn()  { echo -e "\033[33m[WARN]\033[0m $1"; }
error() { echo -e "\033[31m[ERROR]\033[0m $1"; }

install_docker() {
  if ! command -v docker &>/dev/null; then
    info "安装 Docker..."
    curl -fsSL https://get.docker.com | bash
    systemctl enable docker
    systemctl start docker
  else
    info "Docker 已安装"
  fi

  if ! docker compose version &>/dev/null; then
    info "安装 Docker Compose..."
    mkdir -p /usr/local/lib/docker/cli-plugins
    curl -SL https://github.com/docker/compose/releases/download/v2.27.0/docker-compose-linux-x86_64 \
      -o /usr/local/lib/docker/cli-plugins/docker-compose
    chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
  else
    info "Docker Compose 已安装"
  fi
}

write_compose() {
  mkdir -p "${INSTALL_DIR}/data"
  cd "${INSTALL_DIR}"

  info "生成 docker-compose.yml（host 网络）"

  cat > docker-compose.yml <<'EOF'
services:
  # Spider 服务：负责底层的爬虫工作
  spider:
    image: cqshushu/iptv-spider:v1.0
    container_name: iptv-spider
    restart: unless-stopped
    network_mode: host
    environment:
      - TZ=Asia/Shanghai
    volumes:
      - ./data:/app/data

  # Aggregator 服务：负责调度爬虫、聚合数据并生成最终列表
  aggregator:
    image: yiwanaishare/iptv-aggregator:latest
    container_name: iptv-aggregator
    restart: unless-stopped
    network_mode: host
    environment:
      # ==================== 用户自定义配置 ====================
      # Spider 登录密码（必填，需与 spider 保持一致）
      - SPIDER_PASSWORD=yiwan123
      
      # 筛选条件配置
      - FILTER_DAYS=5                    # 采集最近N天的数据源 (建议5-15)
      - FILTER_TYPE=hotel                 # hotel / multicast / all
      - PRIORITY_KEYWORDS=山西,联通       # 优先关键词（逗号分隔）
      - COLLECTION_PAGES=5                # 采集页数 (建议3-8)
      
      # 运行时间配置
      - REFRESH_INTERVAL_HOURS=12         # 自动更新间隔（小时）
      
      # ==================== 系统配置（一般无需修改） ====================
      - TZ=Asia/Shanghai
      - SPIDER_URL=http://127.0.0.1:50085
      - PORT=50086
      - HTTP_TIMEOUT=8
      - SPIDER_READY_MAX_WAIT_SECONDS=600
    volumes:
      # 数据持久化目录（生成的 iptv.txt 会在这里）
      - ./data:/app/data
    working_dir: /app
EOF
}

do_install() {
  info "开始安装 IPTV Aggregator"
  install_docker
  write_compose
  cd "${INSTALL_DIR}"
  docker compose pull
  docker compose up -d
  IP=$(curl -s ipv4.ip.sb || echo "YOUR_SERVER_IP")
  info "安装完成： http://${IP}:50086/iptv"
}

do_uninstall() {
  warn "即将卸载 IPTV Aggregator（包含数据）"
  read -rp "确认卸载？(y/N): " c
  [[ "$c" =~ ^[Yy]$ ]] || exit 0

  if [ -d "${INSTALL_DIR}" ]; then
    cd "${INSTALL_DIR}"
    docker compose down --remove-orphans || true
  fi
  docker rm -f iptv-spider iptv-aggregator 2>/dev/null || true
  rm -rf "${INSTALL_DIR}"
  info "卸载完成"
}

do_restart() {
  cd "${INSTALL_DIR}" || exit 1
  docker compose restart
}

do_status() {
  docker ps | grep -E "iptv-spider|iptv-aggregator" || echo "未运行"
}

do_logs() {
  cd "${INSTALL_DIR}" || exit 1
  docker compose logs -f
}

# ================== 命令入口 ==================
case "$1" in
  install)   do_install ;;
  uninstall) do_uninstall ;;
  restart)   do_restart ;;
  status)    do_status ;;
  logs)      do_logs ;;
  *)
    echo "用法："
    echo "  $0 install     # 安装 / 启动"
    echo "  $0 uninstall   # 卸载（含数据）"
    echo "  $0 restart     # 重启服务"
    echo "  $0 status      # 查看状态"
    echo "  $0 logs        # 查看日志"
    ;;
esac
