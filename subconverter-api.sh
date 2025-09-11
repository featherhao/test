#!/bin/bash

# ===============================================
# subconverter 交互式控制脚本
# 功能:
# - 安装 subconverter 服务 (可选择是否立即绑定域名)
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

  #
