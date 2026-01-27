#!/bin/bash
set -e

# ==========================================================
# IPTV Aggregator 傻瓜式一体化脚本
#
# 功能：
#   - 安装 / 启动
#   - 查看状态 / 日志
#   - 重启 / 卸载
#
# 说明：
#   - 使用 host 网络，绕过 iptables 问题
#   - docker-compose.yml 中【完整保留官方原始注释】
# ==========================================================

APP_NAME="iptv-aggregator"
INSTALL_DIR="/opt/${APP_NAME}"

# ================== 权限检查 ==================
if [ "$EUID" -ne 0 ]; then
  echo "❌ 请使用 root 用户运行"
  exit 1
fi

# ================== 输出工具 ==================
info() { echo -e "\033[32m[INFO]\033[0m $1"; }
warn() { echo -e "\033[33m[WARN]\033[0m $1"; }

# ================== Docker 安装 ==================
install_docker() {
  if ! command -v docker &>/dev/null; then
    info "未检测到 Docker，开始安装..."
    curl -fsSL https://get.docker.com | bash
    systemctl enable docker
    systemctl start docker
  else
    info "Docker 已安装"
  fi

  if ! docker compose version &>/dev/null; then
    info "未检测到 Docker Compose，开始安装..."
    mkdir -p /usr/local/lib/docker/cli-plugins
    curl -SL https://github.com/docker/compose/releases/download/v2.27.0/docker-compose-linux-x86_64 \
      -o /usr/local/lib/docker/cli-plugins/docker-compose
    chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
  else
    info "Docker Compose 已安装"
  fi
}

# ================== 写入 docker-compose.yml ==================
write_compose() {
  mkdir -p "${INSTALL_DIR}/data"
  cd "${INSTALL_DIR}"

  info "生成 docker-compose.yml（官方注释完整版）"

  cat > docker-compose.yml <<'EOF'
services:
  # Spider 服务：负责底层的爬虫工作
  spider:
    image: cqshushu/iptv-spider:v1.0
    container_name: iptv-spider
    restart: unless-stopped

    # ⚠ 使用 host 网络模式，避免 iptables / bridge 问题
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

    # ⚠ 使用 host 网络模式，避免 iptables / bridge 问题
    network_mode: host

    environment:
      # ==================== 用户自定义配置 ====================
      # Spider 登录密码（必填，需与上方 spider 默认密码一致，或者自行修改）
      - SPIDER_PASSWORD=103997250
      
      # 筛选条件配置
      - FILTER_DAYS=5                    # 采集最近N天的数据源 (建议5-15)
      - FILTER_TYPE=all                 # 数据源类型：hotel(酒店源), multicast(组播), all(全部)
      - PRIORITY_KEYWORDS=湖北,移动       # 优先关键词 (如 "山西,联通", 逗号分隔)
      - COLLECTION_PAGES=5                # 采集页数 (建议3-8，页数越多耗时越长)
      
      # 运行时间配置
      - REFRESH_INTERVAL_HOURS=12         # 自动更新间隔（小时）
      
      # ==================== 系统配置（一般无需修改） ====================
      - TZ=Asia/Shanghai                  # 时区设置

      # ⚠ host 网络下 spider 地址需使用 127.0.0.1
      - SPIDER_URL=http://127.0.0.1:50085 # Spider 服务地址

      - PORT=50086                        # Aggregator 服务端口
      - HTTP_TIMEOUT=8                    # HTTP 请求超时时间（秒）
      - SPIDER_READY_MAX_WAIT_SECONDS=600 # 等待 Spider 就绪的最大时间（秒）

    depends_on:
      - spider

    volumes:
      # 数据持久化目录（生成的 iptv.txt 会在这里）
      - ./data:/app/data

    working_dir: /app
EOF
}

# ================== 功能函数 ==================
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
  cd "${INSTALL_DIR}" || return
  docker compose logs -f
}

restart_app() {
  cd "${INSTALL_DIR}" || return
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
