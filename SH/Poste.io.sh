#!/bin/bash
set -Eeuo pipefail

# ==============================================================================
# Poste.io 安装/卸载/更新管理脚本 (改进版)
# ==============================================================================
COMPOSE_FILE="poste.io.docker-compose.yml"
DATA_DIR="./posteio_data"
POSTEIO_IMAGE="analogic/poste.io"

trap 'status=$?; line=${BASH_LINENO[0]}; echo "❌ 发生错误 (exit=$status) at line $line" >&2; exit $status' ERR

# --- Docker Compose 包装 ---
DOCKER_COMPOSE() {
    if command -v docker-compose &>/dev/null; then
        docker-compose "$@"
    else
        docker compose "$@"
    fi
}

# --- 检查依赖 ---
check_dependencies() {
    if ! command -v docker &>/dev/null; then
        echo "❌ 错误：未安装 Docker。请先安装 Docker。"
        exit 1
    fi
    if ! command -v docker-compose &>/dev/null && ! command -v docker compose &>/dev/null; then
        echo "❌ 错误：未安装 Docker Compose。"
        echo "请执行：sudo apt-get install docker-compose"
        exit 1
    fi
    if ! command -v curl &>/dev/null; then
        echo "⚠️ 警告：未安装 curl，可能无法自动获取公网IP。"
    fi
    if ! command -v dig &>/dev/null; then
        echo "⚠️ 警告：未安装 dig，可能无法自动获取公网IP。"
    fi
}

# --- 获取公网IP ---
get_public_ip() {
    local ipv4="" ipv6=""
    if command -v curl &>/dev/null; then
        ipv4=$(curl -s4 http://icanhazip.com || curl -s4 https://api.ipify.org || curl -s4 https://1.1.1.1/cdn-cgi/trace | grep ip | cut -d= -f2)
        ipv6=$(curl -s6 http://icanhazip.com || curl -s6 https://api.ipify.org)
    fi
    if [ -z "$ipv4" ] && command -v dig &>/dev/null; then
        ipv4=$(dig @resolver4.opendns.com myip.opendns.com +short -4)
    fi
    if [ -z "$ipv6" ] && command -v dig &>/dev/null; then
        ipv6=$(dig @resolver4.opendns.com myip.opendns.com +short -6)
    fi
    echo "$ipv4" "$ipv6"
}

# --- 生成 Docker Compose 文件 ---
generate_compose_file() {
    read -rp "请输入您要使用的域名 (例如: mail.example.com): " DOMAIN
    if [ -z "$DOMAIN" ]; then
        echo "域名不能为空，请重新运行脚本。"
        exit 1
    fi

    local http_port=80 https_port=443
    if lsof -i :80 &>/dev/null || lsof -i :443 &>/dev/null; then
        http_port=81
        https_port=444
        echo "⚠️ 检测到 80/443 已被占用，改用备用端口：HTTP=${http_port}, HTTPS=${https_port}"
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
      - HTTPS=ON
      - HTTPS_PORT=${https_port}
      - VIRTUAL_HOST=${DOMAIN}
      - LETSENCRYPT_HOST=${DOMAIN}
    volumes:
      - "$DATA_DIR:/data"
    platform: linux/amd64
EOF
    echo "✅ 已生成 Docker Compose 文件：$COMPOSE_FILE"
}

# --- 显示安装信息 ---
show_installed_info() {
    local http_port=$(grep -Po '^\s*-\s*"\K(\d+)(?=:80")' "$COMPOSE_FILE" || echo "未知")
    local https_port=$(grep -Po '^\s*-\s*"\K(\d+)(?=:443")' "$COMPOSE_FILE" || echo "未知")
    local domain=$(grep -Po '^\s*hostname:\s*\K(.+)' "$COMPOSE_FILE" || echo "未设置")
    local container_status=$(docker ps --filter "name=poste.io" --format "{{.Status}}" || echo "未运行")
    local ip_addresses=($(get_public_ip))
    local ipv4=${ip_addresses[0]} ipv6=${ip_addresses[1]}

    echo "--- Poste.io 运行信息 ---"
    echo "容器名称: poste.io"
    echo "容器状态: ${container_status}"
    echo "数据目录: $(pwd)/$DATA_DIR"
    echo "--------------------------"
    echo "访问地址："
    if [ -n "$ipv4" ]; then
        echo "  - 使用IP访问 (请注意防火墙设置)："
        echo "    HTTP  : http://${ipv4}:${http_port}"
        echo "    HTTPS : https://${ipv4}:${https_port}"
    fi
    if [ "$domain" != "未设置" ]; then
        echo "  - 使用域名访问 (请确保DNS已解析)："
        echo "    HTTP  : http://${domain}:${http_port}"
        echo "    HTTPS : https://${domain}:${https_port}"
    fi
    echo "--------------------------"
}

# --- 安装 ---
install_poste() {
    echo "=== 开始安装 Poste.io ==="
    check_dependencies

    if docker ps -a --filter "name=poste.io" --format "{{.Names}}" | grep -q "poste.io"; then
        echo "ℹ️  已存在 Poste.io 容器。"
        show_installed_info
        exit 0
    fi

    [ -f "$COMPOSE_FILE" ] && rm -f "$COMPOSE_FILE"

    generate_compose_file
    mkdir -p "$DATA_DIR"

    echo "正在启动 Poste.io 容器..."
    DOCKER_COMPOSE -f "$COMPOSE_FILE" up -d --pull always

    echo "✅ Poste.io 安装完成！"
    show_installed_info
}

# --- 卸载 ---
uninstall_poste() {
    echo "=== 开始卸载 Poste.io ==="
    read -p "⚠️ 卸载会删除容器和镜像，是否继续？(y/n) " -n 1 -r
    echo
    [[ ! $REPLY =~ ^[Yy]$ ]] && exit 1

    DOCKER_COMPOSE -f "$COMPOSE_FILE" down || true

    read -p "是否同时删除数据目录 $DATA_DIR ? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf "$DATA_DIR"
        echo "✅ 数据已删除。"
    fi
    rm -f "$COMPOSE_FILE"
    echo "✅ 卸载完成。"
}

# --- 更新 ---
update_poste() {
    echo "=== 更新 Poste.io ==="
    check_dependencies
    [ ! -f "$COMPOSE_FILE" ] && { echo "❌ 未找到 Compose 文件，请先安装。"; exit 1; }

    DOCKER_COMPOSE -f "$COMPOSE_FILE" pull
    DOCKER_COMPOSE -f "$COMPOSE_FILE" up -d
    echo "✅ 更新完成。"
}

# --- 菜单 ---
show_main_menu() {
    while true; do
        echo "=============================="
        echo "      Poste.io 管理菜单"
        echo "=============================="
        echo "1) 安装 Poste.io"
        echo "2) 卸载 Poste.io"
        echo "3) 更新 Poste.io"
        echo "0) 退出"
        echo "=============================="
        read -rp "请输入选项: " choice
        echo
        case "$choice" in
            1) install_poste; break ;;
            2) uninstall_poste; break ;;
            3) update_poste; break ;;
            0) exit 0 ;;
            *) echo "无效选项，请重新输入。" ;;
        esac
    done
}

main() {
    check_dependencies
    show_main_menu
}
main
