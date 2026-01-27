#!/bin/bash
set -e

# ==========================================================
# yiwanaishare / iptv-aggregator 一键安装脚本
# 项目地址：https://github.com/yiwanaishare/iptv-aggregator
# 功能：
#   - 自动安装 Docker / Docker Compose
#   - 生成官方 docker-compose.yml（保留原始注释）
#   - 启动 iptv-spider + iptv-aggregator
# ==========================================================

# ================== 基础配置 ==================
APP_NAME="iptv-aggregator"
INSTALL_DIR="/opt/${APP_NAME}"

# ================== 权限检查 ==================
if [ "$EUID" -ne 0 ]; then
  echo "❌ 请使用 root 用户运行此脚本"
  exit 1
fi

# ================== 安装 Docker ==================
if ! command -v docker &>/dev/null; then
  echo "▶ 未检测到 Docker，开始安装..."
  curl -fsSL https://get.docker.com | bash
  systemctl enable docker
  systemctl start docker
else
  echo "✔ Docker 已安装"
fi

# ================== 安装 Docker Compose ==================
if ! docker compose version &>/dev/null; then
  echo "▶ 未检测到 Docker Compose，开始安装..."
  mkdir -p /usr/local/lib/docker/cli-plugins
  curl -SL https://github.com/docker/compose/releases/download/v2.27.0/docker-compose-linux-x86_64 \
    -o /usr/local/lib/docker/cli-plugins/docker-compose
  chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
else
  echo "✔ Docker Compose 已安装"
fi

# ================== 创建目录 ==================
mkdir -p "${INSTALL_DIR}/data"
cd "${INSTALL_DIR}"

# ================== 写入 docker-compose.yml ==================
# ⚠️ 下面内容【完整保留官方原始注释】，只做了路径适配
cat > docker-compose.yml <<'EOF'
services:
  # Spider 服务：负责底层的爬虫工作
  spider:
    image: cqshushu/iptv-spider:v1.0
    container_name: iptv-spider
    restart: unless-stopped
    ports:
      - "50085:50085"
    environment:
      - TZ=Asia/Shanghai
    volumes:
      - ./data:/app/data

  # Aggregator 服务：负责调度爬虫、聚合数据并生成最终列表
  aggregator:
    image: yiwanaishare/iptv-aggregator:latest
    container_name: iptv-aggregator
    restart: unless-stopped
    ports:
      - "50086:50086"
    environment:
      # ==================== 用户自定义配置 ====================
      # Spider 登录密码（必填，需与上方 spider 默认密码一致，或者自行修改）
      - SPIDER_PASSWORD=yiwan123
      
      # 筛选条件配置
      - FILTER_DAYS=5                    # 采集最近N天的数据源 (建议5-15)
      - FILTER_TYPE=hotel                 # 数据源类型：hotel(酒店源), multicast(组播), all(全部)
      - PRIORITY_KEYWORDS=山西,联通       # 优先关键词 (如 "山西,联通", 逗号分隔)
      - COLLECTION_PAGES=5                # 采集页数 (建议3-8，页数越多耗时越长)
      
      # 运行时间配置
      - REFRESH_INTERVAL_HOURS=12         # 自动更新间隔（小时）
      
      # ==================== 系统配置（一般无需修改） ====================
      - TZ=Asia/Shanghai                  # 时区设置
      - SPIDER_URL=http://spider:50085    # Spider 服务地址
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

# ================== 启动服务 ==================
docker compose pull
docker compose up -d

# ================== 完成提示 ==================
IP=$(curl -s ipv4.ip.sb || echo "YOUR_SERVER_IP")

echo
echo "🎉 IPTV Aggregator 已启动"
echo "--------------------------------------------------"
echo "播放地址： http://${IP}:50086/iptv"
echo "安装目录： ${INSTALL_DIR}"
echo "配置文件： ${INSTALL_DIR}/docker-compose.yml"
echo "--------------------------------------------------"
