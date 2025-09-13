#!/bin/bash
set -e

WORKDIR="/opt/shlink"
COMPOSE_FILE="$WORKDIR/docker-compose.yml"

# ========================
# 菜单函数
# ========================
menu() {
  clear
  echo "============================"
  echo " Shlink 短链服务管理脚本"
  echo "============================"
  echo "1) 安装 Shlink 服务"
  echo "2) 卸载 Shlink 服务"
  echo "3) 更新 Shlink 服务"
  echo "4) 查看服务信息"
  echo "0) 退出"
  echo "----------------------------"
  read -p "请输入选项: " choice

  case "$choice" in
    1) install_shlink ;;
    2) uninstall_shlink ;;
    3) update_shlink ;;
    4) info_shlink ;;
    0) exit 0 ;;
    *) echo "无效选项，请重新输入" && sleep 2 && menu ;;
  esac
}

# ========================
# 安装函数
# ========================
install_shlink() {
  echo "--- 开始部署 Shlink 短链服务 ---"
  mkdir -p "$WORKDIR"

  read -p "请输入短网址域名 (例如: shlink.qqy.pp.ua): " SHLINK_DOMAIN
  read -p "请输入 Web Client 域名 (例如: shlinkapi.qqypp.ua): " CLIENT_DOMAIN
  read -p "请输入短网址服务 (Shlink API) 的监听端口 [默认: 9040]: " API_PORT
  API_PORT=${API_PORT:-9040}
  read -p "请输入 Web Client (前端) 的监听端口 [默认: 9050]: " CLIENT_PORT
  CLIENT_PORT=${CLIENT_PORT:-9050}
  read -p "请输入 GeoLite2 的 License Key (可选，留空则不启用地理统计): " GEO_KEY

  cat > "$COMPOSE_FILE" <<EOF
version: "3.8"

services:
  shlink_db:
    image: postgres:15
    container_name: shlink_db
    restart: always
    environment:
      POSTGRES_PASSWORD: shlinkpass
      POSTGRES_USER: shlink
      POSTGRES_DB: shlink
    volumes:
      - db_data:/var/lib/postgresql/data

  shlink:
    image: shlinkio/shlink:stable
    container_name: shlink
    restart: always
    depends_on:
      - shlink_db
    environment:
      DEFAULT_DOMAIN: ${SHLINK_DOMAIN}
      IS_HTTPS_ENABLED: true
      GEOLITE_LICENSE_KEY: ${GEO_KEY}
      DB_DRIVER: postgres
      DB_USER: shlink
      DB_PASSWORD: shlinkpass
      DB_HOST: shlink_db
      DB_NAME: shlink
    ports:
      - "${API_PORT}:8080"

  shlink_web_client:
    image: shlinkio/shlink-web-client:stable
    container_name: shlink_web_client
    restart: always
    environment:
      SHLINK_SERVER_URL: "http://${SHLINK_DOMAIN}:${API_PORT}"
      SHLINK_SERVER_API_KEY: "will_be_generated"
    ports:
      - "${CLIENT_PORT}:80"

volumes:
  db_data:
EOF

  echo "--- 启动 Docker Compose ---"
  docker compose -f "$COMPOSE_FILE" up -d

  echo "--- 生成 API Key ---"
  sleep 10
  API_KEY=$(docker exec shlink shlink api-key:generate | grep -oE '[0-9a-f-]{36}' | head -n1)

  echo "--- 配置 Web Client ---"
  docker stop shlink_web_client
  docker rm shlink_web_client
  docker run -d \
    --name shlink_web_client \
    -p ${CLIENT_PORT}:80 \
    -e SHLINK_SERVER_URL="http://${SHLINK_DOMAIN}:${API_PORT}" \
    -e SHLINK_SERVER_API_KEY="$API_KEY" \
    shlinkio/shlink-web-client:stable

  echo "============================"
  echo " Shlink 部署完成！"
  echo "短网址服务: http://${SHLINK_DOMAIN}:${API_PORT}"
  echo "Web Client: http://${CLIENT_DOMAIN}:${CLIENT_PORT}"
  echo "API Key: $API_KEY"
  echo "============================"
  read -p "按回车键返回菜单..."
  menu
}

# ========================
# 卸载函数
# ========================
uninstall_shlink() {
  echo "--- 卸载 Shlink 服务 ---"
  if [ -f "$COMPOSE_FILE" ]; then
    docker compose -f "$COMPOSE_FILE" down -v
    rm -rf "$WORKDIR"
    echo "Shlink 已卸载"
  else
    echo "未找到已安装的 Shlink"
  fi
  read -p "按回车键返回菜单..."
  menu
}

# ========================
# 更新函数
# ========================
update_shlink() {
  echo "--- 更新 Shlink 服务 ---"
  if [ -f "$COMPOSE_FILE" ]; then
    docker compose -f "$COMPOSE_FILE" pull
    docker compose -f "$COMPOSE_FILE" up -d
    echo "Shlink 已更新"
  else
    echo "未找到已安装的 Shlink"
  fi
  read -p "按回车键返回菜单..."
  menu
}

# ========================
# 查看信息函数
# ========================
info_shlink() {
  echo "--- Shlink 服务信息 ---"
  if [ -f "$COMPOSE_FILE" ]; then
    docker ps --filter "name=shlink" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
  else
    echo "未找到已安装的 Shlink"
  fi
  read -p "按回车键返回菜单..."
  menu
}

# ========================
# 启动菜单
# ========================
menu
