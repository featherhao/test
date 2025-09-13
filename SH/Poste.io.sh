#!/bin/bash
set -Eeuo pipefail

# ==============================================================================
# Poste.io 最终一键安装脚本
# 该脚本专为解决 Oracle 云服务器 ARM 架构兼容性问题而设计。
# ==============================================================================

# 定义变量
COMPOSE_FILE="docker-compose.yml"
DATA_DIR="./posteio_data"
POSTEIO_IMAGE="analogic/poste.io"

# 统一失败处理
trap 'status=$?; line=${BASH_LINENO[0]}; echo "❌ 发生错误 (exit=$status) at line $line" >&2; exit $status' ERR

# 检查依赖项
check_dependencies() {
    echo "=== 正在检查依赖项... ==="
    if ! command -v docker &> /dev/null; then
        echo "错误：未安装 Docker。请先安装 Docker。"
        exit 1
    fi
    if ! command -v docker-compose &> /dev/null && ! command -v docker compose &> /dev/null; then
        echo "错误：未安装 Docker Compose。请先安装 Docker Compose。"
        exit 1
    fi
    echo "✅ Docker 和 Docker Compose 已安装。"
}

# 获取公网IP地址
get_public_ip() {
    local ipv4=""
    local ipv6=""
    
    if command -v curl &> /dev/null; then
        ipv4=$(curl -s4 http://icanhazip.com || curl -s4 https://api.ipify.org)
        ipv6=$(curl -s6 http://icanhazip.com || curl -s6 https://api.ipify.org)
    fi
    
    echo "$ipv4" "$ipv6"
}

# 最终安装逻辑
install_poste_final() {
    echo "=== 开始安装 Poste.io ==="
    
    # 清理之前的安装
    echo "ℹ️  正在清理之前的安装文件和容器..."
    sudo docker-compose down --remove-orphans &> /dev/null || true
    rm -f "$COMPOSE_FILE"
    
    # 获取域名
    read -rp "请输入您要使用的域名 (例如: mail.example.com): " DOMAIN
    if [ -z "$DOMAIN" ]; then
        echo "域名不能为空，已退出。"
        exit 1
    fi
    
    echo "ℹ️  已选择反向代理模式，将跳过 80/443 端口映射。"
    
    # 生成 Docker Compose 文件并指定平台
    echo "正在生成 Docker Compose 文件：$COMPOSE_FILE"
    cat > "$COMPOSE_FILE" << EOF
services:
  posteio:
    image: ${POSTEIO_IMAGE}:latest
    container_name: poste.io
    restart: always
    hostname: ${DOMAIN}
    # 强制指定为 linux/amd64 平台以解决 'exec format error'
    platform: linux/amd64
    ports:
      - "25:25"
      - "110:110"
      - "143:143"
      - "465:465"
      - "587:587"
      - "993:993"
      - "995:995"
    environment:
      - TZ=Asia/Shanghai
    volumes:
      - "$DATA_DIR:/data"
EOF
    
    # 创建数据目录
    echo "正在创建数据目录：$DATA_DIR"
    mkdir -p "$DATA_DIR"
    
    # 启动容器
    echo "正在启动 Poste.io 容器..."
    if command -v docker-compose &> /dev/null; then
        sudo docker-compose up -d --pull always
    else
        sudo docker compose up -d --pull always
    fi
    
    if [ $? -ne 0 ]; then
        echo "安装失败，请检查上面的错误信息。"
        exit 1
    fi
    
    echo "恭喜！Poste.io 容器已成功启动！"
    
    # 强制配置反向代理
    echo "=== 开始强制配置反向代理 ==="
    echo "正在等待容器获取内部IP..."
    sleep 5 
    
    local posteio_ip=$(sudo docker inspect -f '{{.NetworkSettings.IPAddress}}' poste.io 2>/dev/null || true)
    if [ -z "$posteio_ip" ]; then
        echo "错误：无法获取 Poste.io 容器内部IP，请手动完成最后一步。"
        echo "请运行以下命令："
        echo "POSTEIO_IP=\$(sudo docker inspect -f '{{.NetworkSettings.IPAddress}}' poste.io) && sudo bash -c \"echo 'server { listen 80; server_name ${DOMAIN}; location / { proxy_pass http://\${POSTEIO_IP}:80; proxy_set_header Host \$host; proxy_set_header X-Real-IP \$remote_addr; proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for; proxy_set_header X-Forwarded-Proto \$scheme; client_max_body_size 0; } }' > /etc/openresty/sites-available/${DOMAIN}.conf\" && sudo ln -s /etc/openresty/sites-available/${DOMAIN}.conf /etc/openresty/sites-enabled/${DOMAIN}.conf && sudo openresty -s reload"
        exit 1
    fi
    
    echo "✅ 获取到 Poste.io 容器内部IP: $posteio_ip"
    local proxy_service="openresty"
    local proxy_config_file="/etc/$proxy_service/sites-available/$DOMAIN.conf"
    local proxy_config_link="/etc/$proxy_service/sites-enabled/$DOMAIN.conf"
    
    echo "正在生成反向代理配置文件: $proxy_config_file"
    cat > "$proxy_config_file" << EOF
server {
    listen 80;
    server_name ${DOMAIN};
    
    location / {
        proxy_pass http://${posteio_ip}:80;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        client_max_body_size 0;
    }
}
EOF
    
    echo "正在创建配置文件链接: $proxy_config_link"
    if [ -L "$proxy_config_link" ]; then
        sudo rm "$proxy_config_link"
    fi
    sudo ln -s "$proxy_config_file" "$proxy_config_link"
    
    echo "正在重载 ${proxy_service} 服务..."
    if sudo openresty -s reload; then
        echo "🎉 反向代理配置成功！"
    else
        echo "警告：无法重载 ${proxy_service} 服务，请手动检查配置文件并重启服务。"
    fi

    echo ""
    echo "--- Poste.io 安装成功 ---"
    local ip_addresses=($(get_public_ip))
    local ipv4=${ip_addresses[0]}
    local ipv6=${ip_addresses[1]}
    echo "访问地址：https://${DOMAIN}"
    echo "数据目录: $(pwd)/$DATA_DIR"
    echo "后续步骤：在你的域名服务商后台，将以下DNS记录指向你的服务器IP："
    if [ -n "$ipv4" ]; then
        echo "  - A记录: ${DOMAIN} -> ${ipv4}"
    fi
    if [ -n "$ipv6" ]; then
        echo "  - AAAA记录: ${DOMAIN} -> ${ipv6}"
    fi
    echo "--------------------------"
}

# 运行安装
check_dependencies
install_poste_final