#!/bin/bash

# ===============================================
# subconverter 交互式控制脚本
# 功能:
# - 安装 subconverter 服务 (可选择是否立即绑定绑定域名)
# - 卸载 subconverter 和 Caddy 服务
# - 检查服务运行状态 (显示IP和域名)
# ===============================================

# 定义 subconverter 和 Caddy 的参数
SUB_PORT=25500
SUB_CONTAINER_NAME="subconverter"
SUB_IMAGE_NAME="asdlokj1qpi23/subconverter:latest"

CADDY_CONTAINER_NAME="caddy_proxy"
CADDY_IMAGE_NAME="caddy:latest"
CADDY_DATA_PATH="/etc/caddy_data"
CADDY_CONFIG_PATH="/etc/caddy/Caddyfile"

# 检查是否以 root 身份运行
if [ "$EUID" -ne 0 ]; then
  echo "请使用 root 权限运行此脚本，例如：sudo sh $0"
  exit 1
fi

# 获取公网 IP 地址
get_public_ip() {
  curl -s ip.sb
}

# 检查 Docker 是否安装
check_docker() {
  if ! command -v docker &> /dev/null; then
    echo "Docker 未安装，正在自动安装..."
    curl -fsSL https://get.docker.com | bash
    if ! command -v docker &> /dev/null; then
      echo "Docker 安装失败，请手动安装后重试。"
      exit 1
    fi
    echo "Docker 安装成功。"
  else
    echo "Docker 已安装。"
  fi
}

# 部署 subconverter 服务 (不带反代)
deploy_subconverter_only() {
  echo "--- 正在部署 subconverter 容器 ---"
  docker pull "$SUB_IMAGE_NAME"
  docker run -d \
    --name "$SUB_CONTAINER_NAME" \
    --restart=always \
    -p "$SUB_PORT:$SUB_PORT" \
    "$SUB_IMAGE_NAME"
  if [ $? -ne 0 ]; then
    echo "subconverter 容器启动失败，请检查日志。"
    return 1
  fi
  echo "subconverter 已成功部署在端口 $SUB_PORT。"
  return 0
}

# 部署 Caddy 反向代理
deploy_caddy() {
  DOMAIN=$1
  echo "--- 正在部署 Caddy 反向代理 ---"

  # 确保 /etc/caddy 目录存在
  mkdir -p /etc/caddy

  # 创建 Caddyfile 文件，用于反向代理
  cat > "$CADDY_CONFIG_PATH" << EOF
$DOMAIN {
    reverse_proxy localhost:$SUB_PORT
}
EOF

  # 创建 Caddy 数据目录
  mkdir -p "$CADDY_DATA_PATH"

  echo "--- 正在拉取并启动 Caddy 镜像 ---"
  docker pull "$CADDY_IMAGE_NAME"
  docker run -d \
    --name "$CADDY_CONTAINER_NAME" \
    --restart=always \
    -p 80:80 -p 443:443 \
    -v "$CADDY_CONFIG_PATH":/etc/caddy/Caddyfile \
    -v "$CADDY_DATA_PATH":/data \
    "$CADDY_IMAGE_NAME"
  if [ $? -ne 0 ]; then
    echo "Caddy 容器启动失败，请检查日志：docker logs $CADDY_CONTAINER_NAME"
    return 1
  fi
  echo "Caddy 已成功部署，并绑定到域名 $DOMAIN。"
  return 0
}

# 卸载服务
uninstall_service() {
  echo "--- 正在卸载 subconverter 和 Caddy 服务 ---"
  docker stop "$SUB_CONTAINER_NAME" &> /dev/null
  docker rm "$SUB_CONTAINER_NAME" &> /dev/null
  docker stop "$CADDY_CONTAINER_NAME" &> /dev/null
  docker rm "$CADDY_CONTAINER_NAME" &> /dev/null
  
  # 强制递归删除 Caddyfile，以防它被错误创建成目录
  rm -rf "$CADDY_CONFIG_PATH"
  
  echo "服务已成功卸载。"
}

# 检查服务状态
check_status() {
  echo "--- 正在检查服务状态 ---"
  PUBLIC_IP=$(get_public_ip)
  
  SUB_STATUS=$(docker ps --filter "name=$SUB_CONTAINER_NAME" --format "{{.Status}}")
  if [ -n "$SUB_STATUS" ]; then
    echo "✅ subconverter 容器状态: $SUB_STATUS"
    echo "✅ 可通过 http://$PUBLIC_IP:$SUB_PORT 访问。"
  else
    echo "❌ subconverter 容器未运行。"
  fi

  CADDY_STATUS=$(docker ps --filter "name=$CADDY_CONTAINER_NAME" --format "{{.Status}}")
  if [ -n "$CADDY_STATUS" ]; then
    echo "✅ Caddy 容器状态: $CADDY_STATUS"
    echo "✅ 可通过你绑定的域名访问。"
  else
    echo "❌ Caddy 容器未运行。"
  fi
}

# 主菜单逻辑
main_menu() {
  echo "--- subconverter 自动化部署脚本 ---"
  echo "请选择一个操作："
  echo "1) 安装服务 (无域名)"
  echo "2) 安装服务并绑定域名"
  echo "3) 卸载服务"
  echo "4) 检查服务状态"
  echo "0) 退出脚本"
  read -p "请输入选项 [0-4]: " choice
  echo "---"

  case "$choice" in
    1)
      check_docker
      uninstall_service
      deploy_subconverter_only
      ;;
    2)
      check_docker
      uninstall_service
      read -p "请输入你要绑定的域名 (例如: sub.example.com): " DOMAIN
      if [ -z "$DOMAIN" ]; then
        echo "域名不能为空，操作已取消。"
        exit 1
      fi
      deploy_subconverter_only && deploy_caddy "$DOMAIN"
      ;;
    3)
      uninstall_service
      ;;
    4)
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
