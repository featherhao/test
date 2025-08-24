#!/bin/bash
set -e

# -------- 配置 --------
PASSWORD="103997250"       # 修改为你想要的密码
PORT="8899"             # 修改为你想用的端口
COMPOSE_FILE="/opt/libretv/docker-compose.yml"

# -------- 检查 Docker 是否安装 --------
if ! command -v docker &>/dev/null; then
    echo "Docker 未安装，开始安装..."
    if [ -f /etc/debian_version ]; then
        # Debian / Ubuntu
        apt update
        apt install -y apt-transport-https ca-certificates curl gnupg lsb-release
        curl -fsSL https://download.docker.com/linux/$(. /etc/os-release; echo "$ID")/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/$(. /etc/os-release; echo "$ID") $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
        apt update
        apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    elif [ -f /etc/redhat-release ]; then
        # CentOS / RHEL
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

# -------- 创建 Docker Compose 文件 --------
mkdir -p "$(dirname "$COMPOSE_FILE")"

cat > "$COMPOSE_FILE" <<EOF
version: "3.9"
services:
  libretv:
    image: bestzwei/libretv:latest
    container_name: libretv
    ports:
      - "${PORT}:8080"
    environment
