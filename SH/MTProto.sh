#!/bin/bash
set -Eeuo pipefail

# 统一错误处理
trap 'status=$?; line=${BASH_LINENO[0]}; echo -e "\e[31m❌ 发生错误 (exit=$status) at line $line\e[0m" >&2; exit $status' ERR

MT_NAME="mtproxy"
DEFAULT_PORT=6688
DOCKER_IMAGE="telegrammessenger/proxy:latest"
DATA_DIR="/opt/mtproxy"

# 彩色输出
C_RESET="\e[0m"; C_GREEN="\e[32m"; C_RED="\e[31m"; C_YELLOW="\e[33m"
log() { echo -e "${C_GREEN}[INFO]${C_RESET} $1"; }
error() { echo -e "${C_RED}[ERROR]${C_RESET} $1"; }

# 检查 Docker
check_docker() {
    if ! command -v docker &>/dev/null; then
        log "Docker 未安装，开始安装..."
        sudo apt update
        sudo apt install -y docker.io
        sudo systemctl enable docker
        sudo systemctl start docker
    fi
}

# 获取节点信息
get_status() {
    if docker ps --filter "name=$MT_NAME" --format '{{.Names}}' | grep -q "$MT_NAME"; then
        PORT=$(docker port "$MT_NAME" | awk -F: '{print $2}')
        SECRET=$(cat "$DATA_DIR/secret" 2>/dev/null || echo "未知")
        NODE_IP=$(curl -s ifconfig.me)
        echo -e "————— Telegram MTProto 代理 信息 —————"
        echo "IP: $NODE_IP"
        echo "端口: $PORT"
        echo "secret: $SECRET"
        echo
        echo "tg:// 链接:"
        echo "tg://proxy?server=$NODE_IP&port=$PORT&secret=$SECRET"
        echo
        echo "t.me 分享链接:"
        echo "https://t.me/proxy?server=$NODE_IP&port=$PORT&secret=$SECRET"
        echo "———————————————————————————————"
    else
        log "MTProxy 未运行"
    fi
}

# 安装 MTProxy
install_mtproxy() {
    check_docker

    read -rp "请输入端口号 (留空使用默认 $DEFAULT_PORT): " PORT
    PORT=${PORT:-$DEFAULT_PORT}

    SECRET=$(openssl rand -hex 16)
    mkdir -p "$DATA_DIR"
    echo "$SECRET" > "$DATA_DIR/secret"

    docker run -d --name "$MT_NAME" \
        -p "$PORT:$PORT" \
        -v "$DATA_DIR":/data \
        "$DOCKER_IMAGE" \
        -u nobody -p "$PORT" -H 0.0.0.0 -S "$SECRET"

    log "MTProxy 已启动"
    get_status
}

# 更新镜像
update_mtproxy() {
    check_docker
    docker pull "$DOCKER_IMAGE"
    log "镜像已更新"
}

# 卸载 MTProxy
uninstall_mtproxy() {
    docker rm -f "$MT_NAME" || true
    docker rmi "$DOCKER_IMAGE" || true
    log "已卸载 MTProxy"
}

# 更改端口
change_port() {
    if ! docker ps --filter "name=$MT_NAME" --format '{{.Names}}' | grep -q "$MT_NAME"; then
        error "MTProxy 未运行"
        return
    fi
    read -rp "请输入新端口: " NEW_PORT
    SECRET=$(cat "$DATA_DIR/secret")
    docker stop "$MT_NAME"
    docker rm "$MT_NAME"
    docker run -d --name "$MT_NAME" -p "$NEW_PORT:$NEW_PORT" -v "$DATA_DIR":/data "$DOCKER_IMAGE" -u nobody -p "$NEW_PORT" -H 0.0.0.0 -S "$SECRET"
    log "端口已修改为 $NEW_PORT"
    get_status
}

# 更改 secret
change_secret() {
    if ! docker ps --filter "name=$MT_NAME" --format '{{.Names}}' | grep -q "$MT_NAME"; then
        error "MTProxy 未运行"
        return
    fi
    read -rp "请输入新 secret (留空自动生成): " NEW_SECRET
    NEW_SECRET=${NEW_SECRET:-$(openssl rand -hex 16)}
    echo "$NEW_SECRET" > "$DATA_DIR/secret"
    PORT=$(docker port "$MT_NAME" | awk -F: '{print $2}')
    docker stop "$MT_NAME"
    docker rm "$MT_NAME"
    docker run -d --name "$MT_NAME" -p "$PORT:$PORT" -v "$DATA_DIR":/data "$DOCKER_IMAGE" -u nobody -p "$PORT" -H 0.0.0.0 -S "$NEW_SECRET"
    log "Secret 已修改: $NEW_SECRET"
    get_status
}

# 查看日志
show_logs() {
    docker logs -f "$MT_NAME"
}

# 主菜单
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
