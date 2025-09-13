#!/bin/bash
set -e

INSTALL_DIR="/opt/libretv"
DOCKER_COMPOSE_FILE="$INSTALL_DIR/docker-compose.yml"
CONTAINER_NAME="libretv"

# 高亮输出函数
function info() { echo -e "\e[34m[*]\e[0m $1"; }
function success() { echo -e "\e[32m[✓]\e[0m $1"; }
function error() { echo -e "\e[31m[✗]\e[0m $1"; }

# 显示状态函数
function show_status() {
    info "检查 LibreTV 当前状态..."

    # 获取端口 & 密码，如果 docker-compose.yml 不存在则用默认值
    if [ -f "$DOCKER_COMPOSE_FILE" ]; then
        PORT=$(grep -Po '(?<=- ")[0-9]+(?=:8080")' "$DOCKER_COMPOSE_FILE" 2>/dev/null || echo "8899")
        PASSWORD=$(grep -Po '(?<=PASSWORD=).*' "$DOCKER_COMPOSE_FILE" 2>/dev/null || echo "111111")
    else
        PORT=8899
        PASSWORD=111111
    fi

    # 容器状态
    if docker ps --filter "name=${CONTAINER_NAME}" --filter "status=running" -q | grep -q .; then
        success "LibreTV 容器正在运行"
    else
        error "LibreTV 容器未运行"
    fi

    # 端口监听
    if ss -tln | grep -q ":${PORT}"; then
        success "端口 ${PORT} 正在被监听"
    else
        error "端口 ${PORT} 未被监听"
    fi

    # HTTP 服务
    if curl -s --max-time 5 http://localhost:${PORT} >/dev/null; then
        success "LibreTV 服务可访问"
    else
        error "LibreTV 服务不可访问"
    fi

    # 公网 IPv4
    IPV4=$(curl -s ipv4.ip.sb || curl -s ifconfig.me || curl -s icanhazip.com || echo "localhost")
    success "访问地址 IPv4: http://${IPV4}:${PORT}   (密码: ${PASSWORD})"

    # 公网 IPv6
    IPV6=$(curl -s -6 ipv6.ip.sb || curl -s -6 icanhazip.com || echo "")
    if [[ "$IPV6" =~ ^([0-9a-fA-F:]+)$ ]]; then
        success "访问地址 IPv6: http://[${IPV6}]:${PORT}   (密码: ${PASSWORD})"
    else
        error "IPv6 地址未获取到"
    fi

    # 显示密码
    success "登录密码: ${PASSWORD}"

    echo "----------------------------------"
}

# 安装 LibreTV
function install_libretv() {
    echo "=== LibreTV 安装开始 ==="
    read -p "请输入 LibreTV 访问端口（默认 8899）: " PORT
    PORT=${PORT:-8899}
    read -p "请输入 LibreTV 密码（默认 111111）: " PASSWORD
    PASSWORD=${PASSWORD:-111111}

    # 安装 Docker
    if ! command -v docker &>/dev/null; then
        info "Docker 未安装，开始安装..."
        if [ -f /etc/debian_version ]; then
            apt update
            apt install -y apt-transport-https ca-certificates curl gnupg lsb-release
            curl -fsSL https://download.docker.com/linux/$(. /etc/os-release; echo "$ID")/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
            echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/$(. /etc/os-release; echo "$ID") $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
            apt update
            apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
        elif [ -f /etc/redhat-release ]; then
            yum install -y yum-utils
            yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
            yum install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
        else
            error "不支持的系统，请手动安装 Docker"
            exit 1
        fi
        systemctl enable docker
        systemctl start docker
        success "Docker 安装完成"
    else
        success "Docker 已安装"
    fi

    # 创建目录并生成 docker-compose.yml
    info "创建安装目录..."
    mkdir -p "$INSTALL_DIR"
    cd "$INSTALL_DIR"
    success "安装目录创建完成"

    info "生成 docker-compose.yml 文件..."
    cat > docker-compose.yml <<EOF
version: "3.9"
services:
  libretv:
    image: bestzwei/libretv:latest
    container_name: ${CONTAINER_NAME}
    ports:
      - "${PORT}:8080"
    environment:
      - PASSWORD=${PASSWORD}
    restart: unless-stopped
EOF
    success "docker-compose.yml 生成完成"

    info "启动 LibreTV 容器..."
    docker compose up -d
    success "LibreTV 容器启动完成"

    # 显示状态
    show_status
}

# 卸载 LibreTV
function uninstall_libretv() {
    echo "=== LibreTV 卸载开始 ==="
    if [ -f "$DOCKER_COMPOSE_FILE" ]; then
        cd "$INSTALL_DIR"
        docker compose down
        rm -rf "$INSTALL_DIR"
        success "LibreTV 已卸载"
    else
        error "未检测到 LibreTV 安装目录，可能未安装。"
    fi

    # 显示状态
    show_status
}

# -------- 脚本入口 --------
echo "=== LibreTV 管理脚本 ==="

# 主循环
while true; do
    # **进入脚本就显示当前状态**
    show_status

    # 提示操作
    echo "请选择操作："
    echo "1) 安装 LibreTV"
    echo "2) 卸载 LibreTV"
    echo "3) 退出"
    read -p "请输入数字 [1-3]: " CHOICE

    case "$CHOICE" in
        1) install_libretv ;;
        2) uninstall_libretv ;;
        3) exit 0 ;;
        *) error "无效选择";;
    esac

    echo ""   # 操作完成后换行
done
