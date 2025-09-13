#!/bin/bash
set -e

# =========================
# Shlink 管理脚本 (修正版)
# =========================

DATA_DIR="/opt/shlink"
INFO_FILE="${DATA_DIR}/info.env"

mkdir -p "$DATA_DIR"

# -------------------------
# 加载信息
# -------------------------
load_info() {
  if [[ -f "$INFO_FILE" ]]; then
    source "$INFO_FILE"
  fi
}

# -------------------------
# 保存信息
# -------------------------
save_info() {
  cat > "$INFO_FILE" <<EOF
SHLINK_API_DOMAIN="${SHLINK_API_DOMAIN}"
SHLINK_WEB_DOMAIN="${SHLINK_WEB_DOMAIN}"
SHLINK_API_PORT="${SHLINK_API_PORT}"
SHLINK_WEB_PORT="${SHLINK_WEB_PORT}"
API_KEY="${API_KEY}"
EOF
}

# -------------------------
# 安装 Shlink
# -------------------------
install_shlink() {
  echo "--- 开始部署 Shlink 短链服务 ---"
  docker compose -f "${DATA_DIR}/docker-compose.yml" down -v || true

  read -rp "请输入短网址域名 (例如: shlink.qqy.pp.ua): " SHLINK_API_DOMAIN
  [[ -z "$SHLINK_API_DOMAIN" ]] && SHLINK_API_DOMAIN="shlink.qqy.pp.ua"

  read -rp "请输入 Web Client 域名 (例如: shlinkapi.qqypp.ua): " SHLINK_WEB_DOMAIN
  [[ -z "$SHLINK_WEB_DOMAIN" ]] && SHLINK_WEB_DOMAIN="admin.${SHLINK_API_DOMAIN}"

  read -rp "请输入短网址服务 (Shlink API) 的监听端口 [默认: 9040]: " SHLINK_API_PORT
  [[ -z "$SHLINK_API_PORT" ]] && SHLINK_API_PORT=9040

  read -rp "请输入 Web Client (前端) 的监听端口 [默认: 9050]: " SHLINK_WEB_PORT
  [[ -z "$SHLINK_WEB_PORT" ]] && SHLINK_WEB_PORT=9050

  read -rp "请输入 GeoLite2 的 License Key (可选，留空则不启用地理统计): " GEOLITE_KEY

  cat > "${DATA_DIR}/docker-compose.yml" <<EOF
services:
  shlink_db:
    image: postgres:15-alpine
    container_name: shlink_db
    restart: always
    environment:
      POSTGRES_USER=shlink
      POSTGRES_PASSWORD=shlinkpass
      POSTGRES_DB=shlink
    volumes:
      - ${DATA_DIR}/db:/var/lib/postgresql/data

  shlink_api:
    image: shlinkio/shlink:stable
    container_name: shlink_api
    restart: always
    depends_on:
      - shlink_db
    environment:
      - DEFAULT_DOMAIN=${SHLINK_API_DOMAIN}
      - IS_HTTPS_ENABLED=true
      - DB_DRIVER=postgres
      - DB_USER=shlink
      - DB_PASSWORD=shlinkpass
      - DB_HOST=shlink_db
      - DB_NAME=shlink
      - GEOLITE_LICENSE_KEY=${GEOLITE_KEY}
    ports:
      - "${SHLINK_API_PORT}:8080"
    volumes:
      - ${DATA_DIR}/data:/etc/shlink

  shlink_web_client:
    image: shlinkio/shlink-web-client:latest
    container_name: shlink_web_client
    restart: always
    ports:
      - "${SHLINK_WEB_PORT}:80"
EOF

  docker compose -f "${DATA_DIR}/docker-compose.yml" up -d

  echo "等待 Shlink 初始化..."
  sleep 15

  # 生成 API Key
  echo "正在生成 API Key..."
  API_KEY=$(docker exec shlink_api shlink api-key:generate | grep -oE '[a-f0-9\-]\{36\}' | head -n1)

  save_info
  echo "✅ Shlink 安装完成！"
}

# -------------------------
# 卸载 Shlink
# -------------------------
uninstall_shlink() {
  echo "--- 正在卸载 Shlink 服务 ---"
  docker compose -f "${DATA_DIR}/docker-compose.yml" down -v || true
  rm -rf "$DATA_DIR"
  echo "✅ 已卸载 Shlink 服务！"
}

# -------------------------
# 更新 Shlink
# -------------------------
update_shlink() {
  echo "--- 正在更新 Shlink 服务 ---"
  docker compose -f "${DATA_DIR}/docker-compose.yml" pull
  docker compose -f "${DATA_DIR}/docker-compose.yml" up -d
  echo "✅ 已更新 Shlink 服务！"
}

# -------------------------
# 查看服务信息
# -------------------------
show_info() {
  load_info

  echo "等待 Shlink 服务初始化..."
  sleep 5

  # 如果 API Key 不存在，重新生成
  if [[ -z "$API_KEY" ]]; then
    echo "未检测到现有 API Key，正在生成新的..."
    API_KEY=$(docker exec shlink_api shlink api-key:generate | grep -oE '[a-f0-9\-]\{36\}' | head -n1)
    save_info
  fi

  LOCAL_IP=$(hostname -I | awk '{print $1}')

  echo "✅ API Key 已成功获取！"
  echo "------------------------------------"
  echo "  🎉 Shlink 服务信息 🎉"
  echo "------------------------------------"
  echo "您的短网址域名 (Shlink API): ${SHLINK_API_DOMAIN}"
  echo "您的管理面板域名 (Web Client): ${SHLINK_WEB_DOMAIN}"
  echo
  echo "以下为服务 IP 和端口 (调试用)："
  echo "  - 短网址服务 (API): http://${LOCAL_IP}:${SHLINK_API_PORT}"
  echo "  - 管理面板 (Web): http://${LOCAL_IP}:${SHLINK_WEB_PORT}"
  echo
  echo "默认 API Key (用于登录 Web Client):"
  echo "  - ${API_KEY}"
  echo
  echo "--- Nginx 配置参考 ---"
  echo "短网址域名 (${SHLINK_API_DOMAIN}):"
  echo "  proxy_pass http://127.0.0.1:${SHLINK_API_PORT};"
  echo
  echo "管理面板域名 (${SHLINK_WEB_DOMAIN}):"
  echo "  proxy_pass http://127.0.0.1:${SHLINK_WEB_PORT};"
  echo "------------------------------------"
}

# -------------------------
# 主菜单
# -------------------------
while true; do
  clear
  echo "--- Shlink 短链服务管理 ---"
  echo "1) 安装 Shlink 服务"
  echo "2) 卸载 Shlink 服务"
  echo "3) 更新 Shlink 服务"
  echo "4) 查看服务信息"
  echo "0) 退出"
  echo "--------------------------"
  read -rp "请输入选项: " opt

  case $opt in
    1) install_shlink ;;
    2) uninstall_shlink ;;
    3) update_shlink ;;
    4) show_info ;;
    0) exit 0 ;;
    *) echo "无效选项！"; sleep 1 ;;
  esac

  read -n1 -rsp "按任意键返回主菜单..."
done
