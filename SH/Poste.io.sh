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
}

# 查找可用端口
find_available_port() {
    local start_port=80
    local current_port=$start_port
    while true; do
        if ! lsof -i :$current_port &> /dev/null && ! lsof -i :$((current_port + 443 - 80)) &> /dev/null; then
            echo "$current_port"
            return
        fi
        ((current_port++))
    done
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

    local http_port=$(find_available_port)
    local https_port=$((http_port + 443 - 80))

    cat > "$COMPOSE_FILE" << EOF
services:
  posteio:
    image: ${POSTEIO_IMAGE}
    container_name: poste.io
    restart: always
    hostname: ${DOMAIN}
    ports:
      - "25:25"
      - "${http_port}:80"
      - "${https_port}:443"
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
    echo "已生成 Docker Compose 文件：$COMPOSE_FILE"
    if [ "$http_port" -ne 80 ]; then
        echo "注意：由于默认端口被占用，已自动选择备用端口："
        echo "HTTP 端口: ${http_port}"
        echo "HTTPS 端口: ${https_port}"
    fi
}

# 显示安装信息
show_installed_info() {
    # 尝试从 docker-compose.yml 文件中获取端口和域名信息
    local http_port=$(grep -Po '^\s*-\s*"\K(\d+)(?=:80")' "$COMPOSE_FILE" || echo "未知")
    local https_port=$(grep -Po '^\s*-\s*"\K(\d+)(?=:443")' "$COMPOSE_FILE" || echo "未知")
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
    echo "访问地址："

    local chosen_ip=""
    if [ -n "$ipv4" ] && [ -n "$ipv6" ]; then
        echo "检测到 IPv4 和 IPv6 地址。请选择您希望使用的主要访问方式："
        echo "1) 使用 IPv4: $ipv4"
        echo "2) 使用 IPv6: $ipv6"
        read -rp "请输入选项 (1/2): " ip_choice
        if [ "$ip_choice" == "2" ]; then
            chosen_ip="[$ipv6]" # 加上中括号
        else
            chosen_ip="$ipv4"
        fi
    elif [ -n "$ipv4" ]; then
        chosen_ip="$ipv4"
    elif [ -n "$ipv6" ]; then
        chosen_ip="[$ipv6]" # 加上中括号
    fi

    if [ -n "$chosen_ip" ]; then
        echo "  - 使用IP访问 (请注意防火墙设置)："
        echo "    HTTP  : http://${chosen_ip}:${http_port}"
        echo "    HTTPS : https://${chosen_ip}:${https_port}"
    fi

    if [ "$domain" != "未设置" ]; then
        echo "  - 使用域名访问 (请确保DNS已解析到你的服务器IP)："
        echo "    HTTP  : http://${domain}:${http_port}"
        echo "    HTTPS : https://${domain}:${https_port}"
    fi
    
    echo "--------------------------"
    echo "后续步骤："
    echo "1. 访问上述 HTTP 地址来完成管理员账户设置。"
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

    # 检查是否已安装
    if docker ps -a --filter "name=poste.io" --format "{{.Names}}" | grep -q "poste.io"; then
        echo "ℹ️  检测到 Poste.io 容器已存在。正在显示当前信息..."
        show_installed_info
        exit 0
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
        exit 1
    fi

    echo "正在停止和删除容器..."
    if command -v docker-compose &> /dev/null; then
        docker-compose down
    else
        docker compose down
    fi

    echo "正在删除 Docker Compose 文件和数据..."
    rm -rf "$COMPOSE_FILE" "$DATA_DIR"

    echo "卸载完成。"
}

# 更新 Poste.io
update_poste() {
    echo "=== 开始更新 Poste.io ==="
    check_dependencies
    
    if [ ! -f "$COMPOSE_FILE" ]; then
        echo "错误：找不到 Docker Compose 文件。请先执行安装。"
        exit 1
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
                break
                ;;
            2)
                uninstall_poste
                break
                ;;
            3)
                update_poste
                break
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