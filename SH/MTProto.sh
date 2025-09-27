#!/bin/bash
set -Eeuo pipefail

# ---------------- 基础配置 ----------------
MT_NAME="mtproxy"
DEFAULT_PORT=6688
DOCKER_IMAGE="telegrammessenger/proxy:latest"
DATA_DIR="/opt/mtproxy"
APP_NAME="myapp"  # Telegram app 名称，可修改

C_RESET="\e[0m"; C_GREEN="\e[32m"; C_RED="\e[31m"; C_YELLOW="\e[33m"

# ---------------- 彩色输出 ----------------
log()   { echo -e "${C_GREEN}[INFO]${C_RESET} $1"; }
error() { echo -e "${C_RED}[ERROR]${C_RESET} $1"; }

# ---------------- 检查 Docker ----------------
check_docker() {
    if ! command -v docker &>/dev/null; then
        log "Docker 未安装，开始安装..."
        sudo apt update
        sudo apt install -y docker.io
        sudo systemctl enable docker
        sudo systemctl start docker
    fi
}

# ---------------- 获取运行状态 ----------------
get_status() {
    docker ps --filter "name=$MT_NAME" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
}

# ---------------- 自动生成合法 secret ----------------
generate_secret() {
    local SECRET
    SECRET=$(openssl rand -hex 16)  # 16 字节 => 32 hex
    echo "${SECRET}.${APP_NAME}"
}

# ---------------- 安装 MTProxy ----------------
install_mtproxy() {
    check_docker

    read -rp "请输入端口号 (留空使用默认 $DEFAULT_PORT): " PORT
    PORT=${PORT:-$DEFAULT_PORT}

    SECRET=$(generate_secret)

    log "生成 secret: $SECRET"

    mkdir -p "$DATA_DIR"

    docker rm -f "$MT_NAME" &>/dev/null || true

    docker run -d --name "$MT_NAME" \
        -p "$PORT:$PORT" \
        -e SECRET="$SECRET" \
        -v "$DATA_DIR":/data \
        "$DOCKER_IMAGE"

    PUBLIC_IP=$(curl -s ifconfig.me)

    log "MTProxy 安装完成！"
    echo "————— Telegram MTProto 代理 信息 —————"
    echo "IP: $PUBLIC_IP"
    echo "端口: $PORT"
    echo "secret: $SECRET"
    echo
    echo "tg:// 链接:"
    echo "tg://proxy?server=${PUBLIC_IP}&port=${PORT}&secret=${SECRET}"
    echo
    echo "t.me 分享链接:"
    echo "https://t.me/proxy?server=${PUBLIC_IP}&port=${PORT}&secret=${SECRET}"
    echo "———————————————————————————————"
}

# ---------------- 更新镜像 ----------------
update_mtproxy() {
    check_docker
    docker pull "$DOCKER_IMAGE"
    log "镜像已更新"
}

# ---------------- 卸载 ----------------
uninstall_mtproxy() {
    docker rm -f "$MT_NAME" || true
    docker rmi "$DOCKER_IMAGE" || true
    log "已卸载 MTProxy"
}

# ---------------- 修改端口 ----------------
change_port() {
    read -rp "请输入新端口: " NEW_PORT
    PORT=$NEW_PORT
    docker stop "$MT_NAME" &>/dev/null || true
    docker rm "$MT_NAME" &>/dev/null || true
    docker run -d --name "$MT_NAME" -p "$PORT:$PORT" -e SECRET="$SECRET" "$DOCKER_IMAGE"
    log "端口已修改为 $PORT"
}

# ---------------- 修改 secret ----------------
change_secret() {
    read -rp "请输入新 secret (留空自动生成): " NEW_SECRET
    NEW_SECRET=${NEW_SECRET:-$(generate_secret)}
    SECRET=$NEW_SECRET
    docker stop "$MT_NAME" &>/dev/null || true
    docker rm "$MT_NAME" &>/dev/null || true
    docker run -d --name "$MT_NAME" -p "$PORT:$PORT" -e SECRET="$SECRET" "$DOCKER_IMAGE"
    log "Secret 已修改: $SECRET"
}

# ---------------- 查看日志 ----------------
show_logs() {
    docker logs -f "$MT_NAME"
}

# ---------------- 主菜单 ----------------
while true; do
    echo
    echo "请选择操作："
    echo " 1) 安装"
    echo " 2) 更新"
    echo " 3) 卸载"
    echo " 4) 查看信息"
    echo " 5) 更改端口"
    echo " 6) 更改 secret"
    echo " 7) 查看日志"
    echo " 8) 退出"
    read -rp "请输入选项 [1-8]: " opt

    case $opt in
        1) install_mtproxy ;;
        2) update_mtproxy ;;
        3) uninstall_mtproxy ;;
        4) get_status ;;
        5) change_port ;;
        6) change_secret ;;
        7) show_logs ;;
        8) exit 0 ;;
        *) echo "无效选项" ;;
    esac
done
