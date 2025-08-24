#!/bin/bash
set -e

INSTALL_DIR="/opt/libretv"
DOCKER_COMPOSE_FILE="$INSTALL_DIR/docker-compose.yml"

function install_libretv() {
    # 交互式配置
    read -p "请输入 LibreTV 访问端口（默认 8899）: " PORT
    PORT=${PORT:-8899}

    read -p "请输入 LibreTV 密码（默认 111111）: " PASSWORD
    PASSWORD=${PASSWORD:-111111}

    # 安装 Docker
    if ! command -v docker &>/dev/null; then
        echo "Docker 未安装，开始安装..."
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
    fi

    # 创建安装目录
    mkdir -p "$INSTALL_DIR"
    cd "$INSTALL_DIR"

    # 生成 docker-compose.yml
    cat > docker-compose.yml <<EOF
version: "3.9"
services:
  libretv:
    image: bestzwei/libretv:latest
    container_name: libretv
    ports:
      - "${PORT}:8080"
    environment:
      - PASSWORD=${PASSWORD}
    restart: unless-stopped
EOF

    # 启动 LibreTV
    docker compose up -d

    # 输出访问信息
    IPV4=$(curl -s ifconfig.me || echo "localhost")
    IPV6=$(curl -6 -s https://ifconfig.co || echo "未获取到 IPv6")
    echo "----------------------------------"
    echo "LibreTV 已启动！"
    echo "访问地址 IPv4: http://${IPV4}:${PORT}"
    echo "访问地址 IPv6: http://[${IPV6}]:${PORT}"
    echo "访问密码: ${PASSWORD}"
    echo "----------------------------------"
}

function uninstall_libretv() {
    if [ -f "$DOCKER_COMPOSE_FILE" ]; then
        cd "$INSTALL_DIR"
        docker compose down
        rm -rf "$INSTALL_DIR"
        echo "LibreTV 已卸载。"
    else
        echo "未检测到 LibreTV 安装目录，可能未安装。"
    fi
}

# -------- 主菜单 --------
echo "选择操作："
echo "1) 安装 LibreTV"
echo "2) 卸载 LibreTV"
read -p "请输入数字 [1-2]: " CHOICE

case "$CHOICE" in
    1) install_libretv ;;
    2) uninstall_libretv ;;
    *) echo "无效选择"; exit 1 ;;
esac
