#!/bin/bash
set -e

WORKDIR="/root"
DATADIR="$WORKDIR/posteio_data"
COMPOSE_FILE="$WORKDIR/poste.io.docker-compose.yml"
CONTAINER_NAME="poste.io"
IMAGE="analogic/poste.io"

# 检查容器是否存在
check_installed() {
  docker ps -a --format '{{.Names}}' | grep -q "^$CONTAINER_NAME$"
}

# 获取容器运行信息
show_info() {
  DOMAIN=$(grep "HOSTNAME=" $COMPOSE_FILE 2>/dev/null | cut -d "=" -f2)
  ADMIN_EMAIL=$(grep "POSTMASTER_ADDRESS=" $COMPOSE_FILE 2>/dev/null | cut -d "=" -f2)
  HTTP_PORT=$(grep -m1 ":[0-9]*:80" $COMPOSE_FILE 2>/dev/null | cut -d '"' -f2 | cut -d ":" -f1)
  HTTPS_PORT=$(grep -m1 ":[0-9]*:443" $COMPOSE_FILE 2>/dev/null | cut -d '"' -f2 | cut -d ":" -f1)
  SERVER_IP=$(hostname -I | awk '{print $1}')

  echo "--- Poste.io 运行信息 ---"
  echo "容器名称: $CONTAINER_NAME"
  echo "容器状态: $(docker inspect -f '{{.State.Status}}' $CONTAINER_NAME 2>/dev/null || echo '未运行')"
  echo "数据目录: $DATADIR"
  echo "管理员邮箱: $ADMIN_EMAIL"
  echo "访问地址："
  echo "  - http://$DOMAIN:$HTTP_PORT"
  echo "  - https://$DOMAIN:$HTTPS_PORT"
  echo "  - http://$SERVER_IP:$HTTP_PORT"
  echo "  - https://$SERVER_IP:$HTTPS_PORT"
  echo "--------------------------"
}

# 安装
install_poste() {
  echo "=== 开始安装 Poste.io ==="

  read -p "请输入您要使用的域名 (例如: mail.example.com): " DOMAIN
  read -p "请输入管理员邮箱 (例如: admin@$DOMAIN): " ADMIN_EMAIL
  read -p "请输入管理员密码: " ADMIN_PASS

  mkdir -p "$DATADIR"

  # 检查端口占用
  HTTP_PORT=80
  HTTPS_PORT=443
  if lsof -i:80 >/dev/null 2>&1; then HTTP_PORT=81; fi
  if lsof -i:443 >/dev/null 2>&1; then HTTPS_PORT=444; fi

  cat > "$COMPOSE_FILE" <<EOF
version: '3.3'
services:
  posteio:
    image: $IMAGE
    container_name: $CONTAINER_NAME
    restart: always
    ports:
      - "$HTTP_PORT:80"
      - "$HTTPS_PORT:443"
      - "25:25"
      - "465:465"
      - "587:587"
      - "110:110"
      - "995:995"
      - "143:143"
      - "993:993"
    volumes:
      - $DATADIR:/data
    environment:
      - HTTPS=OFF
      - DISABLE_CLAMAV=TRUE
      - DISABLE_SPAMASSASSIN=TRUE
      - LETSENCRYPT_EMAIL=$ADMIN_EMAIL
      - POSTMASTER_ADDRESS=$ADMIN_EMAIL
      - PASSWORD=$ADMIN_PASS
      - HOSTNAME=$DOMAIN
EOF

  echo "✅ 已生成 Docker Compose 文件：$COMPOSE_FILE"

  echo "正在启动 Poste.io 容器..."
  docker compose -f "$COMPOSE_FILE" up -d

  echo "✅ Poste.io 安装完成！"
  show_info
}

# 更新
update_poste() {
  echo "=== 开始更新 Poste.io ==="
  docker compose -f "$COMPOSE_FILE" pull
  docker compose -f "$COMPOSE_FILE" up -d
  echo "✅ Poste.io 已更新！"
  show_info
}

# 卸载
uninstall_poste() {
  echo "⚠️ 警告：卸载将删除容器和数据目录 $DATADIR"
  read -p "确定要继续吗？(y/n): " confirm
  if [[ "$confirm" != "y" ]]; then
    echo "❌ 已取消卸载"
    exit 1
  fi

  docker compose -f "$COMPOSE_FILE" down
  rm -rf "$COMPOSE_FILE" "$DATADIR"
  echo "✅ 卸载完成"
}

# 主菜单
main_menu() {
  echo "=============================="
  echo " Poste.io 管理脚本"
  echo "=============================="

  if check_installed; then
    echo "检测到 Poste.io 已安装"
    show_info
    echo "1) 更新 Poste.io"
    echo "2) 卸载 Poste.io"
    echo "0) 退出"
    read -p "请输入选项: " choice
    case $choice in
      1) update_poste ;;
      2) uninstall_poste ;;
      0) exit 0 ;;
      *) echo "无效选项" ;;
    esac
  else
    echo "尚未安装 Poste.io"
    echo "1) 安装 Poste.io"
    echo "0) 退出"
    read -p "请输入选项: " choice
    case $choice in
      1) install_poste ;;
      0) exit 0 ;;
      *) echo "无效选项" ;;
    esac
  fi
}

main_menu
