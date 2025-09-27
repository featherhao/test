#!/bin/bash
set -Eeuo pipefail

# ================== 配置 ==================
MT_NAME="mtproxy"
DEFAULT_PORT=6688
DOCKER_IMAGE="telegrammessenger/proxy:latest"
DATA_DIR="/opt/mtproxy"

# 彩色输出
C_RESET="\e[0m"; C_GREEN="\e[32m"; C_RED="\e[31m"; C_YELLOW="\e[33m"
log() { echo -e "${C_GREEN}[INFO]${C_RESET} $1"; }
error() { echo -e "${C_RED}[ERROR]${C_RESET} $1"; }

# 统一错误处理
trap 'status=$?; line=${BASH_LINENO[0]}; echo -e "${C_RED}❌ 发生错误 (exit=$status) at line $line${C_RESET}" >&2; exit $status' ERR

# ================== 函数 ==================

check_docker() {
    if ! command -v docker &>/dev/null; then
        log "Docker 未安装，开始安装..."
        sudo apt update
        sudo apt install -y docker.io
        sudo systemctl enable docker
        sudo systemctl start docker
    fi
}

get_status() {
    docker ps --filter "name=$MT_NAME" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
}

install_mtproxy() {
    check_docker

    # 自动删除已有冲突容器
    if docker ps -a --format '{{.Names}}' | grep -q "^$MT_NAME$"; then
        log "检测到已有容器 $MT_NAME，正在删除..."
        docker rm -f "$MT_NAME"
    fi

    read -rp "请输入端口号 (留空使用默认 $DEFAULT_PORT): " PORT
    PORT=${PORT:-$DEFAULT_PORT}

    read -rp "请输入 secret (留空自动生成): " SECRET
    SECRET=${SECRET:-$(openssl rand -hex 16)}

    mkdir -p "$DATA_DIR"

    docker run -d --name "$MT_NAME" \
        -p "$PORT:$PORT" \
        -e SECRET="$SECRET" \
        "$DOCKER_IMAGE"

    log "MTProxy 安装完成！"
    IP=$(curl -s ifconfig.me)
    echo -e "————— Telegram MTProto 代理 信息 —————"
    echo "IP: $IP"
    echo "端口: $PORT"
    echo "secret: $SECRET"
    echo
    echo "tg:// 链接:"
    echo "tg://proxy?server=$IP&port=$PORT&secret=$SECRET"
    echo
    echo "t.me 分享链接:"
    echo "https://t.me/proxy?server=$IP&port=$PORT&secret=$SECRET"
    echo "———————————————————————————————"
}

update_mtproxy() {
    check_docker
    log "拉取最新镜像..."
    docker pull "$DOCKER_IMAGE"
    log "镜像已更新"
}

uninstall_mtproxy() {
    check_docker
    docker rm -f "$MT_NAME" 2>/dev/null || true
    docker rmi "$DOCKER_IMAGE" 2>/dev/null || true
    log "已卸载 MTProxy"
}

change_port() {
    check_docker
    read -rp "请输入新端口: " NEW_PORT
    CURRENT_SECRET=$(docker inspect -f '{{range .Config.Env}}{{println .}}{{end}}' "$MT_NAME" | grep SECRET | cut -d= -f2)
    docker rm -f "$MT_NAME"
    docker run -d --name "$MT_NAME" \
        -p "$NEW_PORT:$NEW_PORT" \
        -e SECRET="$CURRENT_SECRET" \
        "$DOCKER_IMAGE"
    log "端口已修改为 $NEW_PORT"
}

change_secret() {
    check_docker
    read -rp "请输入新 secret (留空自动生成): " NEW_SECRET
    NEW_SECRET=${NEW_SECRET:-$(openssl rand -hex 16)}
    PORT=$(docker inspect -f '{{(index (index .NetworkSettings.Ports "'"$DEFAULT_PORT"'/tcp") 0).HostPort}}' "$MT_NAME" 2>/dev/null || echo "$DEFAULT_PORT")
    docker rm -f "$MT_NAME"
    docker run -d --name "$MT_NAME" \
        -p "$PORT:$PORT" \
        -e SECRET="$NEW_SECRET" \
        "$DOCKER_IMAGE"
    log "Secret 已修改: $NEW_SECRET"
}

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
