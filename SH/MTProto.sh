#!/bin/bash
set -Eeuo pipefail

# ================== 配置 ==================
MT_NAME="mtproxy"
DEFAULT_PORT=6688
DOCKER_IMAGE="telegrammessenger/proxy:latest"
DATA_DIR="/opt/mtproxy"

# 默认官方可用 secret（带 Telegram tag）
DEFAULT_SECRET="ee4322efd1df409c0e001799fa881e7f1c6974756e65732e6170706c652e636f6d"

# ================== 彩色输出 ==================
C_RESET="\e[0m"; C_GREEN="\e[32m"; C_RED="\e[31m"; C_YELLOW="\e[33m"
log() { echo -e "${C_GREEN}[INFO]${C_RESET} $1"; }
error() { echo -e "${C_RED}[ERROR]${C_RESET} $1"; }

# ================== 检查 Docker ==================
check_docker() {
    if ! command -v docker &>/dev/null; then
        log "Docker 未安装，开始安装..."
        sudo apt update
        sudo apt install -y docker.io
        sudo systemctl enable docker
        sudo systemctl start docker
    fi
}

# ================== 获取状态 ==================
get_status() {
    docker ps --filter "name=$MT_NAME" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
}

# ================== 安装 ==================
install_mtproxy() {
    check_docker

    read -rp "请输入端口号 (留空使用默认 $DEFAULT_PORT): " PORT
    PORT=${PORT:-$DEFAULT_PORT}

    read -rp "请输入 secret (留空使用默认可用 secret): " SECRET
    SECRET=${SECRET:-$DEFAULT_SECRET}

    mkdir -p "$DATA_DIR"

    # 移除已存在容器
    docker rm -f "$MT_NAME" 2>/dev/null || true

    docker run -d --name "$MT_NAME" \
        -p "$PORT:$PORT" \
        -e SECRET="$SECRET" \
        -v "$DATA_DIR":/data \
        "$DOCKER_IMAGE"

    echo -e "————— Telegram MTProto 代理 信息 —————"
    echo "IP: $(curl -s ifconfig.me)"
    echo "端口: $PORT"
    echo "secret: $SECRET"
    echo
    echo "tg:// 链接:"
    echo "tg://proxy?server=$(curl -s ifconfig.me)&port=$PORT&secret=$SECRET"
    echo
    echo "t.me 分享链接:"
    echo "https://t.me/proxy?server=$(curl -s ifconfig.me)&port=$PORT&secret=$SECRET"
    echo "———————————————————————————————"
    log "MTProxy 安装完成！"
}

# ================== 更新 ==================
update_mtproxy() {
    check_docker
    docker pull "$DOCKER_IMAGE"
    log "镜像已更新"
}

# ================== 卸载 ==================
uninstall_mtproxy() {
    docker rm -f "$MT_NAME" || true
    docker rmi "$DOCKER_IMAGE" || true
    log "已卸载 MTProxy"
}

# ================== 更改端口 ==================
change_port() {
    read -rp "请输入新端口: " NEW_PORT
    docker stop "$MT_NAME"
    docker rm "$MT_NAME"
    docker run -d --name "$MT_NAME" -p "$NEW_PORT:$NEW_PORT" -e SECRET="$DEFAULT_SECRET" "$DOCKER_IMAGE"
    log "端口已修改为 $NEW_PORT"
}

# ================== 更改 secret ==================
change_secret() {
    read -rp "请输入新 secret (留空使用默认可用 secret): " NEW_SECRET
    NEW_SECRET=${NEW_SECRET:-$DEFAULT_SECRET}
    PORT=$(docker port "$MT_NAME" | awk -F: '{print $2}')
    docker stop "$MT_NAME"
    docker rm "$MT_NAME"
    docker run -d --name "$MT_NAME" -p "$PORT:$PORT" -e SECRET="$NEW_SECRET" "$DOCKER_IMAGE"
    log "Secret 已修改: $NEW_SECRET"
}

# ================== 查看日志 ==================
show_logs() {
    docker logs -f "$MT_NAME"
}

# ================== 主菜单 ==================
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
