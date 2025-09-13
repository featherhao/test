#!/bin/bash
set -e

WORKDIR="/root"
DATADIR="$WORKDIR/posteio_data"
COMPOSE_FILE="$WORKDIR/poste.io.docker-compose.yml"

menu() {
  clear
  echo "=============================="
  echo "      Poste.io 管理菜单"
  echo "=============================="
  echo "1) 安装 Poste.io"
  echo "2) 卸载 Poste.io"
  echo "3) 更新 Poste.io"
  echo "0) 退出"
  echo "=============================="
  read -p "请输入选项: " choice
  case $choice in
    1) install_poste ;;
    2) uninstall_poste ;;
    3) update_poste ;;
    0) exit 0 ;;
    *) echo "无效选项"; sleep 2; menu ;;
  esac
}

install_poste() {
  echo "=== 开始安装 Poste.io ==="

  read -p "请输入您要使用的域名 (例如: mail.example.com): " DOMAIN
  read -p "请输入管理员邮箱 (例如: admin@$DOMAIN): " ADMIN_EMAIL
  read -s -p "请输入管理员密码: " ADMIN_PASS
  echo

  mkdir -p "$DATADIR"

  # 检查 80 和 443 端口是否被占用
  HTTP_PORT=80
  HTTPS_PORT=443
  if lsof -i:80 >/dev/null 2>&1; then
    HTTP_PORT=81
  fi
  if lsof -i:443 >/dev/null 2>&1; then
    HTTPS_PORT=444
  fi

  cat > "$COMPOSE_FILE" <<EOF
version: '3.3'
services:
  posteio:
    image: analogic/poste.io
    container_name: poste.io
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

  echo "✅ 恭喜！Poste.io 安装并初始化完成！"
  echo "--- Poste.io 运行信息 ---"
  echo "容器名称: poste.io"
  echo "数据目录: $DATADIR"
  echo "访问地址："
  echo "  - http://$DOMAIN:$HTTP_PORT"
  echo "  - https://$DOMAIN:$HTTPS_PORT"
  echo "--------------------------"
}

uninstall_poste() {
  echo "=== 卸载 Poste.io ==="
  docker compose -f "$COMPOSE_FILE" down || true
  rm -rf "$DATADIR" "$COMPOSE_FILE"
  echo "✅ 卸载完成"
}

update_poste() {
  echo "=== 更新 Poste.io ==="
  docker compose -f "$COMPOSE_FILE" pull
  docker compose -f "$COMPOSE_FILE" up -d
  echo "✅ 更新完成"
}

menu
