#!/bin/bash
set -e

# ==========================================================
# IPTV Aggregator 傻瓜式一体化脚本
# Oracle / NAT / iptables 免疫（host 网络）
# ==========================================================

APP_NAME="iptv-aggregator"
INSTALL_DIR="/opt/${APP_NAME}"

# ================== 权限检查 ==================
if [ "$EUID" -ne 0 ]; then
  echo "❌ 请使用 root 用户运行"
  exit 1
fi

# ================== 工具函数 ==================
info()  { echo -e "\033[32m[INFO]\033[0m $1"; }
warn()  { echo -e "\033[33m[WARN]\033[0m $1"; }

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
      - SPIDER_PASSWORD=yiwan123
      - FILTER_DAYS=5
      - FILTER_TYPE=hotel
      - PRIORITY_KEYWORDS=山西,联通
      - COLLECTION_PAGES=5
      - REFRESH_INTERVAL_HOURS=12
      
      # ==================== 系统配置 ====================
      - TZ=Asia/Shanghai
      - SPIDER_URL=http://127.0.0.1:50085
      - PORT=50086
      - HTTP_TIMEOUT=8
      - SPIDER_READY_MAX_WAIT_SECONDS=600
    volumes:
      - ./data:/app/data
    working_dir: /app
EOF
}

install_app() {
  info "开始安装 IPTV Aggregator"
  install_docker
  write_compose
  cd "${INSTALL_DIR}"
  docker compose pull
  docker compose up -d
  IP=$(curl -s ipv4.ip.sb || echo "YOUR_SERVER_IP")
  info "安装完成，播放地址： http://${IP}:50086/iptv"
}

show_status() {
  docker ps | grep -E "iptv-spider|iptv-aggregator" || echo "未运行"
}

show_logs() {
  cd "${INSTALL_DIR}" || exit 0
  docker compose logs -f
}

restart_app() {
  cd "${INSTALL_DIR}" || exit 0
  docker compose restart
}

uninstall_app() {
  warn "即将卸载 IPTV Aggregator（包含数据）"
  read -rp "确认卸载？(y/N): " c
  [[ "$c" =~ ^[Yy]$ ]] || return

  if [ -d "${INSTALL_DIR}" ]; then
    cd "${INSTALL_DIR}"
    docker compose down --remove-orphans || true
  fi
  docker rm -f iptv-spider iptv-aggregator 2>/dev/null || true
  rm -rf "${INSTALL_DIR}"
  info "卸载完成"
}

# ================== 菜单 ==================
while true; do
  echo
  echo "========= IPTV Aggregator ========="
  echo "1) 安装 / 启动"
  echo "2) 查看运行状态"
  echo "3) 查看日志"
  echo "4) 重启服务"
  echo "5) 卸载（含数据）"
  echo "0) 退出"
  echo "=================================="
  read -rp "请输入选项 [0-5]: " choice

  case "$choice" in
    1) install_app ;;
    2) show_status ;;
    3) show_logs ;;
    4) restart_app ;;
    5) uninstall_app ;;
    0) exit 0 ;;
    *) echo "❌ 无效选项" ;;
  esac
done
