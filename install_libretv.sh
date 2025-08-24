#!/bin/bash
set -e

INSTALL_DIR="/opt/libretv"
DOCKER_COMPOSE_FILE="$INSTALL_DIR/docker-compose.yml"
CONTAINER_NAME="libretv"

function install_libretv() {
    echo "=== LibreTV 安装开始 ==="

    # 交互式配置
    read -p "请输入 LibreTV 访问端口（默认 8899）: " PORT
    PORT=${PORT:-8899}

    read -p "请输入 LibreTV 密码（默认 111111）: " PASSWORD
    PASSWORD=${PASSWORD:-111111}

    # 安装 Docker
    if ! command -v docker &>/dev/null; then
        echo "[*] Docker 未安装，开始安装..."
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
            echo "不支持的系统，请手动安装 Docker"
            exit 1
        fi
        systemctl enable docker
        systemctl start docker
        echo "[✓] Docker 安装完成"
    else
        echo "[✓] Docker 已安装"
    fi

    # 创建安装目录
    echo "[*] 创建安装目录..."
    mkdir -p "$INSTALL_DIR"
    cd "$INSTALL_DIR"
    echo "[✓] 安装目录创建完成"

    # 生成 docker-compose.yml
    echo "[*] 生成 docker-compose.yml 文件..."
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
    echo "[✓] docker-compose.yml 生成完成"

    # 启动 LibreTV
    echo "[*] 启动 LibreTV 容器..."
    docker compose up -d
    echo "[✓] LibreTV 容器启动完成"

    # 输出访问信息
    IPV4=$(curl -s ifconfig.me || echo "localhost")
    IPV6=$(curl -6 -s https://ifconfig.co || echo "未获取到 IPv6")

    echo "----------------------------------"
    echo "LibreTV 已安装并运行！"
    echo "访问地址 IPv4: http://${IPV4}:${PORT}"
    if [[ $IPV6 != "未获取到 IPv6" ]]; then
        echo "访问地址 IPv6: http://[${IPV6}]:${PORT}"
    else
        echo "IPv6 地址未获取到"
    fi
    echo "访问密码: ${PASSWORD}"
    echo "----------------------------------"
}

function uninstall_libretv() {
    echo "=== LibreTV 卸载开始 ==="
    if [ -f "$DOCKER_COMPOSE_FILE" ]; then
        cd "$INSTALL_DIR"
        docker compose down
        rm -rf "$INSTALL_DIR"
        echo "[✓] LibreTV 已卸载"
    else
        echo "未检测到 LibreTV 安装目录，可能未安装。"
    fi
}

function check_libretv_status() {
    echo "=== 检查 LibreTV 状态 ==="

    # 检查容器状态
    if docker ps --filter "name=${CONTAINER_NAME}" --filter "status=running" -q | grep -q .; then
        echo "[✓] LibreTV 容器正在运行"
    else
        echo "[✗] LibreTV 容器未运行"
    fi

    # 检查端口监听
    PORT=$(grep -Po '(?<=- ")[0-9]+(?=:8080")' "$DOCKER_COMPOSE_FILE" 2>/dev/null || echo "8899")
    if ss -tln | grep -q ":${PORT}"; then
        echo "[✓] 端口 ${PORT} 正在被监听"
    else
        echo "[✗] 端口 ${PORT} 未被监听"
    fi

    # 检查 HTTP 服务
    if curl -s --max-time 5 http://localhost:${PORT} >/dev/null; then
        echo "[✓] LibreTV 服务可访问"
    else
        echo "[✗] LibreTV 服务不可访问"
    fi

    # 输出公网 IP
    IPV4=$(curl -s ifconfig.me || echo "localhost")
    IPV6=$(curl -6 -s https://ifconfig.co || echo "未获取到 IPv6")
    echo "访问地址 IPv4: http://${IPV4}:${PORT}"
    if [[ $IPV6 != "未获取到 IPv6" ]]; then
        echo "访问地址 IPv6: http://[${IPV6}]:${PORT}"
    fi
    echo "----------------------------------"
}

# -------- 主菜单 --------
echo "请选择操作："
echo "1) 安装 LibreTV"
echo "2) 卸载 LibreTV"
echo "3) 检查 LibreTV 状态"
read -p "请输入数字 [1-3]: " CHOICE

case "$CHOICE" in
    1) install_libretv ;;
    2) uninstall_libretv ;;
    3) check_libretv_status ;;
    *) echo "无效选择"; exit 1 ;;
esac
