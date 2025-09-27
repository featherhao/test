#!/usr/bin/env bash
set -euo pipefail

IMAGE="telegrammessenger/proxy:latest"
CONTAINER_NAME="tg-mtproxy"
DATA_DIR="/etc/tg-proxy"
SECRET_FILE="${DATA_DIR}/secret"
DEFAULT_PORT=6688
PORT=""
SECRET=""

# ================= 彩色输出 =================
info() { printf "\033[1;34m%s\033[0m\n" "$*"; }
warn() { printf "\033[1;33m%s\033[0m\n" "$*"; }
error() { printf "\033[1;31m%s\033[0m\n" "$*"; exit 1; }

# ================= 系统依赖检查 =================
check_deps() {
    for cmd in curl docker openssl iptables; do
        if ! command -v $cmd >/dev/null 2>&1; then
            if command -v apt >/dev/null 2>&1; then
                info "安装依赖 $cmd"
                apt update && apt install -y $cmd
            elif command -v yum >/dev/null 2>&1; then
                info "安装依赖 $cmd"
                yum install -y $cmd
            elif command -v apk >/dev/null 2>&1; then
                info "安装依赖 $cmd"
                apk add --no-cache $cmd
            else
                warn "未找到包管理器，请手动安装 $cmd"
            fi
        fi
    done

    if ! docker info >/dev/null 2>&1; then
        error "Docker 未启动或无权限访问 /var/run/docker.sock"
    fi
}

# ================= 查找空闲端口 =================
find_free_port() {
    local port="$1"
    while ss -ltn 2>/dev/null | awk '{print $4}' | grep -q ":$port\$"; do
        port=$((port + 1))
    done
    echo "$port"
}

# ================= 生成 secret =================
generate_secret() {
    mkdir -p "$DATA_DIR"
    if [ -f "$SECRET_FILE" ]; then
        SECRET=$(cat "$SECRET_FILE")
    else
        SECRET=$(openssl rand -hex 32)  # 32 字节 = 64 hex
        echo -n "$SECRET" > "$SECRET_FILE"
    fi
}

# ================= 获取公网 IP =================
public_ip() {
    curl -fs --max-time 5 https://api.ipify.org \
    || curl -fs --max-time 5 https://ifconfig.me \
    || curl -fs --max-time 5 https://ip.sb \
    || echo "UNKNOWN"
}

# ================= 开放端口 =================
open_port() {
    local port="$1"
    if command -v ufw >/dev/null 2>&1; then
        sudo ufw allow "$port"/tcp || true
    fi
    sudo iptables -I INPUT -p tcp --dport "$port" -j ACCEPT || true
}

# ================= 启动容器 =================
run_container() {
    docker stop "$CONTAINER_NAME" 2>/dev/null || true
    docker rm "$CONTAINER_NAME" 2>/dev/null || true

    if ! docker run -d --name "$CONTAINER_NAME" --restart unless-stopped \
        --network host \
        -e "MTPROXY_SECRET=$SECRET" \
        -e "MTPROXY_PORT=$PORT" \
        "$IMAGE"; then
        LOG=$(docker logs "$CONTAINER_NAME" 2>&1 || true)
        error "Docker 容器启动失败，日志：\n$LOG"
    fi
}

# ================= 显示节点信息 =================
show_info() {
    IP=$(public_ip)
    PROXY_LINK="tg://proxy?server=${IP}&port=${PORT}&secret=${SECRET}"
    TME_LINK="https://t.me/proxy?server=${IP}&port=${PORT}&secret=${SECRET}"
    info "————— Telegram MTProto 代理 信息 —————"
    echo "IP: $IP"
    echo "端口: $PORT"
    echo "secret: $SECRET"
    echo
    echo "tg:// 链接:"
    echo "$PROXY_LINK"
    echo
    echo "t.me 分享链接:"
    echo "$TME_LINK"
    echo "———————————————————————————————"
}

# ================= 安装 =================
install() {
    check_deps
    generate_secret
    read -r -p "请输入端口号 (留空使用默认 $DEFAULT_PORT): " input_port
    PORT=$(find_free_port "${input_port:-$DEFAULT_PORT}")
    open_port "$PORT"
    docker pull "$IMAGE"
    run_container
    show_info
}

# ================= 更新 =================
update() {
    check_deps
    generate_secret
    OLD_PORT=$(docker inspect -f '{{range .Config.Env}}{{if hasPrefix . "MTPROXY_PORT"}}{{.}}{{end}}{{end}}' "$CONTAINER_NAME" 2>/dev/null | cut -d '=' -f 2)
    PORT=${OLD_PORT:-$(find_free_port "$DEFAULT_PORT")}
    open_port "$PORT"
    docker pull "$IMAGE"
    run_container
    show_info
}

# ================= 更改端口 =================
change_port() {
    read -r -p "请输入新的端口号 (留空自动选择): " new_port
    PORT=$(find_free_port "${new_port:-$DEFAULT_PORT}")
    open_port "$PORT"
    run_container
    show_info
}

# ================= 更改 secret =================
change_secret() {
    SECRET=$(openssl rand -hex 32)
    echo -n "$SECRET" > "$SECRET_FILE"
    run_container
    show_info
}

# ================= 查看日志 =================
show_logs() {
    docker logs -f "$CONTAINER_NAME"
}

# ================= 卸载 =================
uninstall() {
    docker stop "$CONTAINER_NAME" 2>/dev/null || true
    docker rm "$CONTAINER_NAME" 2>/dev/null || true
    warn "容器已移除"
    read -r -p "是否删除镜像 $IMAGE? (y/N): " yn
    [[ "$yn" =~ ^[Yy]$ ]] && docker rmi "$IMAGE"
    read -r -p "是否删除数据目录 $DATA_DIR? (y/N): " yn2
    [[ "$yn2" =~ ^[Yy]$ ]] && rm -rf "$DATA_DIR"
}

# ================= 菜单 =================
menu() {
    while :; do
        echo "请选择操作："
        echo " 1) 安装"
        echo " 2) 更新"
        echo " 3) 卸载"
        echo " 4) 查看信息"
        echo " 5) 更改端口"
        echo " 6) 更改 secret"
        echo " 7) 查看日志"
        echo " 8) 退出"
        read -r -p "请输入选项 [1-8]: " choice
        case "$choice" in
            1) install ;;
            2) update ;;
            3) uninstall ;;
            4) show_info ;;
            5) change_port ;;
            6) change_secret ;;
            7) show_logs ;;
            8) exit 0 ;;
            *) warn "输入无效，请重新输入" ;;
        esac
    done
}

menu
