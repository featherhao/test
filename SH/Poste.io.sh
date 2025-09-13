#!/bin/bash
set -Eeuo pipefail

# ==============================================================================
# Poste.io 安装/卸载/更新管理脚本 (交互式菜单版)
# 作者：AI助手
# ------------------------------------------------------------------------------
# 脚本使用说明：
# 脚本启动时会自动检测安装状态。
# 如果已安装，会直接显示服务信息，然后回到主菜单。
# 如果未安装，会直接显示菜单并引导用户安装。
# ==============================================================================

# 定义变量
COMPOSE_FILE="docker-compose.yml"
DATA_DIR="./posteio_data"
POSTEIO_IMAGE="analogic/poste.io"

# 统一失败处理
trap 'status=$?; line=${BASH_LINENO[0]}; echo "❌ 发生错误 (exit=$status) at line $line" >&2; exit $status' ERR

# 检查依赖项
check_dependencies() {
    if ! command -v docker &> /dev/null; then
        echo "错误：未安装 Docker。请先安装 Docker。"
        exit 1
    fi
    # 兼容新旧版本的 docker-compose
    if ! command -v docker-compose &> /dev/null && ! command -v docker compose &> /dev/null; then
        echo "错误：未安装 Docker Compose。请先安装 Docker Compose。"
        echo "你可以使用以下命令安装：sudo apt-get install docker-compose"
        exit 1
    fi
    if ! command -v curl &> /dev/null; then
        echo "警告：未安装 curl，可能无法自动获取公网IP。"
        echo "你可以使用以下命令安装：sudo apt-get install curl"
    fi
    if ! command -v dig &> /dev/null; then
        echo "警告：未安装 dig，可能无法自动获取公网IP。"
        echo "你可以使用以下命令安装：sudo apt-get install dnsutils"
    fi
    if ! command -v lsof &> /dev/null; then
        echo "错误：未安装 lsof。请先安装 lsof。"
        echo "你可以使用以下命令安装：sudo apt-get install lsof"
        exit 1
    fi
}

# 检查端口是否被占用，并返回占用该端口的服务名
get_port_owner() {
    local port=$1
    local owner_pid=$(sudo lsof -t -i:$port 2>/dev/null || true)
    if [ -n "$owner_pid" ]; then
        local service_name=$(systemctl status "$owner_pid" 2>/dev/null | grep -Po 'Loaded: .*service; \K(.+)(?=\))' | cut -d'.' -f1 || true)
        if [ -n "$service_name" ]; then
            echo "$service_name"
        else
            echo "UNKNOWN_PID_$owner_pid"
        fi
    fi
}

# 获取公网IP地址
get_public_ip() {
    local ipv4=""
    local ipv6=""
    
    if command -v curl &> /dev/null; then
        ipv4=$(curl -s4 http://icanhazip.com || curl -s4 https://api.ipify.org)
        ipv6=$(curl -s6 http://icanhazip.com || curl -s6 https://api.ipify.org)
    fi
    
    if [ -z "$ipv4" ] && command -v dig &> /dev/null; then
        ipv4=$(dig @resolver4.opendns.com myip.opendns.com +short -4)
    fi
    
    if [ -z "$ipv6" ] && command -v dig &> /dev/null; then
        ipv6=$(dig @resolver4.opendns.com myip.opendns.com +short -6)
    fi
    
    echo "$ipv4" "$ipv6"
}

# 生成 Docker Compose 文件
generate_compose_file() {
    read -rp "请输入您要使用的域名 (例如: mail.example.com): " DOMAIN
    if [ -z "$DOMAIN" ]; then
        echo "域名不能为空，请重新运行脚本并输入有效的域名。"
        exit 1
    fi

    local port_owner_80=$(get_port_owner 80)
    local port_owner_443=$(get_port_owner 443)

    local web_ports_mapping='- "80:80"\n      - "443:443"'
    if [[ "$port_owner_80" == "nginx" || "$port_owner_80" == "openresty" || "$port_owner_443" == "nginx" || "$port_owner_443" == "openresty" ]]; then
        echo "ℹ️  检测到 OpenResty 或 Nginx 正在使用 80/443 端口。"
        echo "    将跳过端口映射，并自动生成反向代理配置。"
        web_ports_mapping=""
    else
        echo "✅ 端口 80/443 未被占用，将直接映射。"
    fi
    
    cat > "$COMPOSE_FILE" << EOF
services:
  posteio:
    image: ${POSTEIO_IMAGE}
    container_name: poste.io
    restart: always
    hostname: ${DOMAIN}
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
    platform: linux/amd64
EOF
    # 在 ports 块中插入 web 端口映射
    if [ -n "$web_ports_mapping" ]; then
        sed -i "/- \"25:25\"/a \ \ \ \ \ \ $web_ports_mapping" "$COMPOSE_FILE"
    fi

    echo "已生成 Docker Compose 文件：$COMPOSE_FILE"
}

# 配置 Nginx/OpenResty 反向代理
configure_reverse_proxy() {
    local domain=$(grep -Po '^\s*hostname:\s*\K(.+)' "$COMPOSE_FILE" || echo "未设置")
    if [ "$domain" == "未设置" ]; then
        echo "警告：未设置域名，无法配置反向代理。"
        return 1
    fi

    local proxy_service=$(get_port_owner 80)
    if [[ "$proxy_service" != "nginx" && "$proxy_service" != "openresty" ]]; then
        echo "ℹ️  未检测到 Nginx/OpenResty，跳过反向代理配置。"
        return 0
    fi
    
    echo "=== 开始自动配置反向代理 ==="
    echo "正在等待 Poste.io 容器启动..."
    sleep 5 # 等待容器获取IP
    
    local posteio_ip=$(docker inspect -f '{{.NetworkSettings.IPAddress}}' poste.io 2>/dev/null || true)
    if [ -z "$posteio_ip" ]; then
        echo "错误：无法获取 Poste.io 容器内部IP，请手动配置反向代理。"
        return 1
    fi

    echo "✅ 获取到 Poste.io 容器内部IP: $posteio_ip"
    local proxy_config_file="/etc/$proxy_service/sites-available/$domain.conf"
    local proxy_config_link="/etc/$proxy_service/sites-enabled/$domain.conf"

    echo "正在生成反向代理配置文件: $proxy_config_file"
    cat > "$proxy_config_file" << EOF
server {
    listen 80;
    server_name $domain;
    
    location / {
        proxy_pass http://$posteio_ip:80;
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
        rm "$proxy_config_link"
    fi
    sudo ln -s "$proxy_config_file" "$proxy_config_link"

    echo "正在重载 $proxy_service 服务..."
    if sudo systemctl reload "$proxy_service" || sudo openresty -s reload; then
        echo "🎉 反向代理配置成功！"
    else
        echo "警告：无法重载 $proxy_service 服务，请手动检查配置文件并重启服务。"
    fi
    return 0
}

# 显示安装信息
show_installed_info() {
    local web_ports_info=""
    local port_owner_80=$(get_port_owner 80)

    if [[ "$port_owner_80" == "nginx" || "$port_owner_80" == "openresty" ]]; then
        web_ports_info="（通过 $port_owner_80 反向代理）"
    fi

    local domain=$(grep -Po '^\s*hostname:\s*\K(.+)' "$COMPOSE_FILE" || echo "未设置")
    local container_status=$(docker ps --filter "name=poste.io" --format "{{.Status}}" || echo "未运行")
    
    local ip_addresses=($(get_public_ip))
    local ipv4=${ip_addresses[0]}
    local ipv6=${ip_addresses[1]}

    echo "--- Poste.io 运行信息 ---"
    echo "容器名称: poste.io"
    echo "容器状态: ${container_status}"
    echo "数据目录: $(pwd)/$DATA_DIR"
    echo "--------------------------"
    echo "访问地址：$web_ports_info"
    
    if [ -n "$ipv4" ]; then
        echo "  - IPv4访问: http://${ipv4}:80"
        echo "            https://${ipv4}:443"
    fi
    if [ -n "$ipv6" ]; then
        echo "  - IPv6访问: http://[${ipv6}]:80"
        echo "            https://[${ipv6}]:443"
    fi

    if [ "$domain" != "未设置" ]; then
        echo "  - 域名访问: http://${domain}"
        echo "            https://${domain}"
    fi
    
    echo "--------------------------"
    echo "后续步骤："
    echo "1. 访问上述地址来完成管理员账户设置。"
    echo "2. 在你的域名服务商后台，将以下DNS记录指向你的服务器IP："
    if [ -n "$ipv4" ]; then
        echo "   - A记录: $domain -> $ipv4"
    fi
    if [ -n "$ipv6" ]; then
        echo "   - AAAA记录: $domain -> $ipv6"
    fi
}

# 安装 Poste.io
install_poste() {
    echo "=== 开始安装 Poste.io ==="
    check_dependencies

    if docker ps -a --filter "name=poste.io" --format "{{.Names}}" | grep -q "poste.io"; then
        echo "ℹ️  检测到 Poste.io 容器已存在。正在显示当前信息..."
        show_installed_info
        return
    fi

    if [ -f "$COMPOSE_FILE" ]; then
        echo "警告：检测到旧的 Docker Compose 文件，正在自动删除..."
        rm "$COMPOSE_FILE"
    fi

    generate_compose_file

    echo "正在创建数据目录：$DATA_DIR"
    mkdir -p "$DATA_DIR"

    echo "正在启动 Poste.io 容器..."
    if command -v docker-compose &> /dev/null; then
        docker-compose up -d --pull always
    else
        docker compose up -d --pull always
    fi

    if [ $? -eq 0 ]; then
        echo "恭喜！Poste.io 安装成功！"
        if [ -n "$(get_port_owner 80)" ] || [ -n "$(get_port_owner 443)" ]; then
            configure_reverse_proxy
        fi
        show_installed_info
    else
        echo "安装失败，请检查上面的错误信息。"
    fi
}

# 卸载 Poste.io
uninstall_poste() {
    echo "=== 开始卸载 Poste.io ==="
    read -p "警告：卸载将永久删除所有容器、镜像和数据。你确定要继续吗？(y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "已取消卸载。"
        return
    fi

    echo "正在停止和删除容器..."
    if command -v docker-compose &> /dev/null; then
        docker-compose down
    else
        docker compose down
    fi

    echo "正在删除 Docker Compose 文件和数据..."
    rm -rf "$COMPOSE_FILE" "$DATA_DIR"

    # 清理反向代理配置
    local domain=$(grep -Po '^\s*hostname:\s*\K(.+)' "$COMPOSE_FILE" || echo "未设置")
    local proxy_service=$(get_port_owner 80)
    if [[ "$proxy_service" == "nginx" || "$proxy_service" == "openresty" ]]; then
        echo "正在清理反向代理配置..."
        local proxy_config_file="/etc/$proxy_service/sites-available/$domain.conf"
        local proxy_config_link="/etc/$proxy_service/sites-enabled/$domain.conf"
        if [ -L "$proxy_config_link" ]; then
            rm -f "$proxy_config_link"
        fi
        if [ -f "$proxy_config_file" ]; then
            rm -f "$proxy_config_file"
        fi
        sudo systemctl reload "$proxy_service" || sudo openresty -s reload
    fi

    echo "卸载完成。"
}

# 更新 Poste.io
update_poste() {
    echo "=== 开始更新 Poste.io ==="
    check_dependencies
    
    if [ ! -f "$COMPOSE_FILE" ]; then
        echo "错误：找不到 Docker Compose 文件。请先执行安装。"
        return
    fi

    echo "正在拉取最新的 Poste.io 镜像..."
    if command -v docker-compose &> /dev/null; then
        docker-compose pull
    else
        docker compose pull
    fi

    echo "正在重新创建和启动容器..."
    if command -v docker-compose &> /dev/null; then
        docker-compose up -d
    else
        docker compose up -d
    fi

    if [ $? -eq 0 ]; then
        echo "Poste.io 已成功更新到最新版本！"
    else
        echo "更新失败，请检查上面的错误信息。"
    fi
}

# 菜单主逻辑
show_main_menu() {
    while true; do
        echo "=============================="
        echo "   Poste.io 管理菜单"
        echo "=============================="
        echo "1) 安装 Poste.io"
        echo "2) 卸载 Poste.io"
        echo "3) 更新 Poste.io"
        echo "0) 退出"
        echo "=============================="
        read -rp "请输入选项: " choice
        echo

        case "$choice" in
            1)
                install_poste
                ;;
            2)
                uninstall_poste
                ;;
            3)
                update_poste
                ;;
            0)
                echo "退出脚本。"
                exit 0
                ;;
            *)
                echo "无效选项，请重新输入。"
                sleep 1
                ;;
        esac
    done
}

# 主入口
main() {
    check_dependencies
    
    if docker ps --filter "name=poste.io" --format "{{.Names}}" | grep -q "poste.io" && [ -f "$COMPOSE_FILE" ]; then
        echo "✅ Poste.io 容器正在运行，显示当前信息..."
        show_installed_info
    fi
    
    show_main_menu
}

# 启动主逻辑
main