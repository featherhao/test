#!/bin/bash

# ===============================================
# Subconverter 核心服务自动化脚本 (无域名)
# ===============================================

# 定义容器和端口
SUB_PORT=25500
SUB_CONTAINER_NAME="subconverter"
SUB_IMAGE_NAME="asdlokj1qpi23/subconverter:latest"
COMPOSE_FILE="docker-compose.yml"

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

# 配置防火墙
configure_firewall() {
  echo "--- 正在尝试自动配置防火墙 ---"
  local ports_to_open="$SUB_PORT"

  if command -v ufw &> /dev/null; then
    echo "检测到 UFW 防火墙，正在放行端口 $ports_to_open..."
    sudo ufw allow $ports_to_open/tcp comment "Allow subconverter traffic"
    echo "UFW 端口已放行。"
  elif command -v firewall-cmd &> /dev/null; then
    echo "检测到 firewalld 防火墙，正在放行端口 $ports_to_open..."
    sudo firewall-cmd --zone=public --add-port=$ports_to_open/tcp --permanent
    sudo firewall-cmd --reload
    echo "firewalld 端口已放行。"
  else
    echo "未检测到常见防火墙管理工具 (UFW 或 firewalld)。"
    echo "请手动在你的云服务商控制台或服务器防火墙中放行 TCP 端口 $ports_to_open。"
  fi
}

# 部署 Subconverter 核心服务
deploy_service() {
  echo "--- 正在部署 subconverter 核心服务 ---"
  echo "请选择网络模式："
  echo "1) 仅使用 IPv4 (推荐，解决连接问题)"
  echo "2) 仅使用 IPv6 (如果你的服务器支持并需要)"
  read -p "请输入选项 [1-2]: " ip_choice

  if [[ "$ip_choice" == "1" ]]; then
    cat > "$COMPOSE_FILE" << EOF
version: '3'
services:
  $SUB_CONTAINER_NAME:
    image: $SUB_IMAGE_NAME
    container_name: $SUB_CONTAINER_NAME
    restart: always
    # 新增: 强制禁用 IPv6 网络栈和使用 IPv4 DNS 服务器
    sysctls:
      net.ipv6.conf.all.disable_ipv6: 1
    dns:
      - 8.8.8.8
    ports:
      - "$SUB_PORT:$SUB_PORT"
EOF
    echo "✅ 已选择 **仅使用 IPv4** 模式。"
  elif [[ "$ip_choice" == "2" ]]; then
    cat > "$COMPOSE_FILE" << EOF
version: '3'
services:
  $SUB_CONTAINER_NAME:
    image: $SUB_IMAGE_NAME
    container_name: $SUB_CONTAINER_NAME
    restart: always
    # 新增: 强制禁用 IPv4
    sysctls:
      net.ipv4.conf.all.disable_ipv4: 1
    ports:
      - "$SUB_PORT:$SUB_PORT"
EOF
    echo "✅ 已选择 **仅使用 IPv6** 模式。"
  else
    echo "⚠️ 无效选项，将默认使用 **仅使用 IPv4** 模式。"
    cat > "$COMPOSE_FILE" << EOF
version: '3'
services:
  $SUB_CONTAINER_NAME:
    image: $SUB_IMAGE_NAME
    container_name: $SUB_CONTAINER_NAME
    restart: always
    # 默认使用 IPv4 DNS 服务器并禁用 IPv6 网络栈
    sysctls:
      net.ipv6.conf.all.disable_ipv6: 1
    dns:
      - 8.8.8.8
    ports:
      - "$SUB_PORT:$SUB_PORT"
EOF
  fi
  
  configure_firewall
  docker-compose up -d --force-recreate
  echo "✅ subconverter 服务已部署完成。"
  check_status
}

# 卸载服务
uninstall_service() {
  echo "--- 正在卸载服务 ---"
  if [ -f "$COMPOSE_FILE" ]; then
    docker-compose down
    rm "$COMPOSE_FILE"
  fi
  echo "✅ 服务已成功卸载。"
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
      echo "    http://$PUBLIC_IP:$SUB_PORT/version"
      echo "    版本信息：$IP_CHECK"
    else
      echo "❌ **通过 IP 地址访问失败**，请检查防火墙或服务日志。"
    fi
    echo ""
    echo "--- 容器日志 (最近10行) ---"
    docker logs $SUB_CONTAINER_NAME --tail 10
    echo "--- 日志结束 ---"
  else
    echo "❌ subconverter 容器未运行。"
  fi
}

# 主菜单逻辑
main_menu() {
  echo "--- Subconverter 自动化脚本 (无域名) ---"
  echo "请选择一个操作："
  echo "1) 安装服务"
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
