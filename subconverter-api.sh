#!/bin/bash

# ===============================================
# Nginx + Docker Compose 部署 Subconverter 脚本
# 功能:
# - 安装 Docker 和 Docker Compose
# - 使用 Docker Compose 部署 subconverter 和 Nginx
# - 自动配置 Nginx 反向代理
# - 提供状态检查和卸载功能
# - 部署完成后自动显示服务状态
# ===============================================

# 定义容器和端口
SUB_PORT=25500
SUB_CONTAINER_NAME="subconverter"
SUB_IMAGE_NAME="asdlokj1qpi23/subconverter:latest"
NGINX_CONTAINER_NAME="nginx-proxy"
NGINX_IMAGE_NAME="nginx:latest"
COMPOSE_FILE="docker-compose.yml"
NGINX_CONF_PATH="./nginx.conf"

# 检查是否以 root 身份运行
if [ "$EUID" -ne 0 ]; then
  echo "请使用 root 权限运行此脚本，例如：sudo bash $0"
  exit 1
fi

# 获取公网 IP 地址
get_public_ip() {
  curl -s ip.sb
}

# 检查并安装 Docker 和 Docker Compose
install_docker_and_compose() {
  if ! command -v docker &> /dev/null; then
    echo "Docker 未安装，正在自动安装..."
    curl -fsSL https://get.docker.com | bash
    echo "Docker 安装完成。"
  else
    echo "Docker 已安装。"
  fi

  if ! command -v docker-compose &> /dev/null; then
    echo "Docker Compose 未安装，正在自动安装..."
    sudo curl -L "https://github.com/docker/compose/releases/download/v2.5.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    if ! command -v docker-compose &> /dev/null; then
      echo "Docker Compose 安装失败，请手动安装后重试。"
      exit 1
    fi
    echo "Docker Compose 安装完成。"
  else
    echo "Docker Compose 已安装。"
  fi
}

# 部署服务
deploy_service() {
  read -p "请输入你要绑定的域名 (例如: sub.example.com): " DOMAIN
  if [ -z "$DOMAIN" ]; then
    echo "域名不能为空，操作已取消。"
    exit 1
  fi
  
  echo "--- 正在生成 Nginx 配置文件 ---"
  cat > "$NGINX_CONF_PATH" << EOF
server {
    listen 80;
    listen [::]:80;
    server_name $DOMAIN;

    location / {
        proxy_pass http://subconverter:$SUB_PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

  echo "--- 正在生成 docker-compose.yml 文件 ---"
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

  echo "--- 正在启动服务 ---"
  docker-compose up -d
  echo "服务已部署完成。"
  echo "域名绑定成功: $DOMAIN"
  echo "---"
  check_status
}

# 卸载服务
uninstall_service() {
  echo "--- 正在卸载服务 ---"
  if [ -f "$COMPOSE_FILE" ]; then
    docker-compose down
    rm "$COMPOSE_FILE"
  fi
  if [ -f "$NGINX_CONF_PATH" ]; then
    rm "$NGINX_CONF_PATH"
  fi
  echo "服务已成功卸载。"
}

# 检查服务状态
check_status() {
  echo "--- 正在检查服务状态 ---"
  PUBLIC_IP=$(get_public_ip)
  
  SUB_STATUS=$(docker ps --filter "name=$SUB_CONTAINER_NAME" --format "{{.Status}}")
  if [ -n "$SUB_STATUS" ]; then
    echo "✅ subconverter 容器状态: $SUB_STATUS"
    IP_CHECK=$(curl -s --max-time 5 "http://$PUBLIC_IP:$SUB_PORT/version")
    if [ -n "$IP_CHECK" ]; then
      echo "✅ **通过 IP 地址访问成功**："
      echo "   http://$PUBLIC_IP:$SUB_PORT/version"
      echo "   版本信息：$IP_CHECK"
    else
      echo "❌ **通过 IP 地址访问失败**，请检查防火墙或服务日志。"
    fi
  else
    echo "❌ subconverter 容器未运行。"
  fi

  echo "---------------------------"

  NGINX_STATUS=$(docker ps --filter "name=$NGINX_CONTAINER_NAME" --format "{{.Status}}")
  if [ -n "$NGINX_STATUS" ]; then
    DOMAIN_CHECK=$(curl -s --max-time 5 "http://$DOMAIN/version")
    if [ -n "$DOMAIN_CHECK" ]; then
      echo "✅ **通过域名访问成功**："
      echo "   http://$DOMAIN/version"
      echo "   版本信息：$DOMAIN_CHECK"
    else
      echo "❌ **通过域名访问失败**，请检查 DNS 解析或防火墙。"
    fi
  else
    echo "❌ Nginx 容器未运行。"
  fi
}

# 主菜单逻辑
main_menu() {
  echo "--- Nginx + Docker Compose 部署脚本 ---"
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
