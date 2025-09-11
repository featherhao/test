#!/bin/bash

# ===============================================
# Nginx + HTTPS 一键自动化部署 Subconverter 脚本
# ===============================================

# 定义容器和端口
SUB_PORT=25500
SUB_CONTAINER_NAME="subconverter"
SUB_IMAGE_NAME="asdlokj1qpi23/subconverter:latest"
NGINX_CONTAINER_NAME="nginx-proxy"
NGINX_IMAGE_NAME="nginx:latest"
COMPOSE_FILE="docker-compose.yml"
NGINX_CONF_PATH="./nginx.conf"
CERTBOT_DIR="./certbot"

# 检查是否以 root 身份运行
if [ "$EUID" -ne 0 ]; then
  echo "请使用 root 权限运行此脚本，例如：sudo bash $0"
  exit 1
fi

# 检查并安装 Docker 和 Docker Compose
install_docker_and_compose() {
  echo "--- 正在检查和安装 Docker & Docker Compose ---"
  if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com | bash
  fi
  if ! command -v docker-compose &> /dev/null; then
    sudo curl -L "https://github.com/docker/compose/releases/download/v2.5.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
  fi
  echo "--- 安装完成 ---"
}

# 部署服务
deploy_service() {
  read -p "请输入你要绑定的域名 (例如: sub.example.com): " DOMAIN
  if [ -z "$DOMAIN" ]; then
    echo "域名不能为空，操作已取消。"
    exit 1
  fi
  
  echo "--- 正在部署 subconverter 和 Nginx (用于证书申请) ---"
  # 创建临时 docker-compose.yml 用于 Certbot 验证
  cat > "$COMPOSE_FILE" << EOF
version: '3'
services:
  $SUB_CONTAINER_NAME:
    image: $SUB_IMAGE_NAME
    container_name: $SUB_CONTAINER_NAME
    restart: always
    ports:
      - "$SUB_PORT:$SUB_PORT"

  $NGINX_CONTAINER_NAME:
    image: $NGINX_IMAGE_NAME
    container_name: $NGINX_CONTAINER_NAME
    restart: always
    ports:
      - "80:80"
    volumes:
      - ./nginx.conf:/etc/nginx/conf.d/default.conf
    depends_on:
      - $SUB_CONTAINER_NAME
EOF

  # 创建临时的 nginx.conf
  cat > "$NGINX_CONF_PATH" << EOF
server {
    listen 80;
    server_name $DOMAIN;
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }
    location / {
        return 301 https://\$host\$request_uri;
    }
}
EOF
  
  docker-compose up -d --force-recreate

  echo "--- 正在为 $DOMAIN 申请 SSL 证书 ---"
  mkdir -p "$CERTBOT_DIR"
  docker run -it --rm --name certbot \
    -v "$CERTBOT_DIR:/etc/letsencrypt" \
    -v "./nginx.conf:/etc/nginx/conf.d/default.conf" \
    -p 80:80 \
    certbot/certbot certonly --webroot -w /var/www/certbot \
    -d "$DOMAIN" --agree-tos --email your_email@example.com --no-eff-email

  # 检查证书是否申请成功
  if [ ! -d "$CERTBOT_DIR/live/$DOMAIN" ]; then
    echo "❌ 证书申请失败，请检查域名解析和防火墙设置。"
    exit 1
  fi
  echo "✅ 证书申请成功！"

  echo "--- 正在更新 Nginx 配置以支持 HTTPS ---"
  # 生成最终的 nginx.conf 文件
  cat > "$NGINX_CONF_PATH" << EOF
server {
    listen 80;
    server_name $DOMAIN;
    return 301 https://\$host\$request_uri;
}
server {
    listen 443 ssl http2;
    server_name $DOMAIN;
    ssl_certificate $CERTBOT_DIR/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key $CERTBOT_DIR/live/$DOMAIN/privkey.pem;
    include $CERTBOT_DIR/options-ssl-nginx.conf;
    ssl_dhparam $CERTBOT_DIR/ssl-dhparams.pem;

    location / {
        proxy_pass http://subconverter:$SUB_PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF
  
  # 更新 docker-compose.yml 以挂载证书和 ssl 参数
  cat > "$COMPOSE_FILE" << EOF
version: '3'
services:
  $SUB_CONTAINER_NAME:
    image: $SUB_IMAGE_NAME
    container_name: $SUB_CONTAINER_NAME
    restart: always
    ports:
      - "$SUB_PORT:$SUB_PORT"

  $NGINX_CONTAINER_NAME:
    image: $NGINX_IMAGE_NAME
    container_name: $NGINX_CONTAINER_NAME
    restart: always
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/conf.d/default.conf
      - $CERTBOT_DIR:/etc/letsencrypt
    depends_on:
      - $SUB_CONTAINER_NAME
EOF

  echo "--- 正在重启服务 ---"
  docker-compose up -d
  echo "✅ 服务已完全部署完成！"
}

# 卸载服务
uninstall_service() {
  echo "--- 正在卸载服务 ---"
  docker-compose down
  rm -rf "$COMPOSE_FILE" "$NGINX_CONF_PATH" "$CERTBOT_DIR"
  echo "✅ 服务已成功卸载。"
}

# 检查服务状态
check_status() {
  echo "--- 正在检查服务状态 ---"
  docker-compose ps
  echo "---"
  echo "请确保你的域名已正确解析到本服务器IP，且服务器防火墙已开放80和443端口。"
}

# 主菜单逻辑
main_menu() {
  echo "--- Nginx + HTTPS 部署脚本 ---"
  echo "请选择一个操作："
  echo "1) 部署服务"
  echo "2) 卸载服务"
  echo "3) 检查服务状态"
  echo "0) 退出脚本"
  read -p "请输入选项 [0-3]: " choice
  echo "---"

  case "$choice" in
    1)
      install_docker_and_compose
      deploy_service
      ;;
    2)
      uninstall_service
      ;;
    3)
      check_status
      ;;
    0)
      echo "退出脚本。"
      exit 0
      ;;
    *)
      echo "无效选项，请重新输入。"
      ;;
  esac
  echo "--- 操作完成 ---"
}

# 脚本主循环
while true; do
  main_menu
done
