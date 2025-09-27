#!/bin/bash
set -Eeuo pipefail

# ---------------- 基础配置 ----------------
MT_NAME="mtproxy"
DEFAULT_PORT=6688
DOCKER_IMAGE="telegrammessenger/proxy:latest"
DATA_DIR="/opt/mtproxy"
APP_NAME="myapp" # Telegram app 名称，可修改

# 全局变量，用于存储当前运行的端口和 Secret
PORT=$DEFAULT_PORT
SECRET=""

C_RESET="\e[0m"; C_GREEN="\e[32m"; C_RED="\e[31m"; C_YELLOW="\e[33m"

# ---------------- 彩色输出 ----------------
log()   { echo -e "${C_GREEN}[INFO]${C_RESET} $1"; }
error() { echo -e "${C_RED}[ERROR]${C_RESET} $1"; }
warn()  { echo -e "${C_YELLOW}[WARN]${C_RESET} $1"; }

# ---------------- 检查 Docker ----------------
check_docker() {
    if ! command -v docker &>/dev/null; then
        log "Docker 未安装，开始安装..."
        # 适用于 Debian/Ubuntu
        sudo apt update
        sudo apt install -y docker.io
        sudo systemctl enable docker
        sudo systemctl start docker
        log "Docker 安装并启动成功。"
    fi
}

# ---------------- 获取运行状态 ----------------
get_status() {
    log "MTProxy 容器状态："
    # 尝试获取并更新全局变量 PORT 和 SECRET，以供其他函数使用
    if docker inspect -f '{{.State.Running}}' "$MT_NAME" &>/dev/null; then
        # 从 Docker inspect 中获取映射的端口（需要处理多端口映射，这里假设只有一个）
        GLOBAL_PORT_RAW=$(docker inspect --format='{{range $p, $conf := .NetworkSettings.Ports}}{{(index $conf 0).HostPort}}{{end}}' "$MT_NAME")
        if [[ -n "$GLOBAL_PORT_RAW" ]]; then
             PORT=$GLOBAL_PORT_RAW
        fi
        
        # 从 Docker inspect 中获取 Secret
        GLOBAL_SECRET_RAW=$(docker inspect --format='{{range .Config.Env}}{{if hasPrefix "SECRET=" .}}{{trimPrefix "SECRET=" .}}{{end}}{{end}}' "$MT_NAME")
        if [[ -n "$GLOBAL_SECRET_RAW" ]]; then
            SECRET=$GLOBAL_SECRET_RAW
        fi

        log "当前配置 - IP: $(curl -s ifconfig.me) | 端口: $PORT | Secret: $SECRET"
        echo "—————————————————————————————————————"
        docker ps --filter "name=$MT_NAME" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
        
        if [[ -n "$SECRET" ]]; then
            PUBLIC_IP=$(curl -s ifconfig.me)
            echo "———————————————— Telegram MTProto 代理链接 ————————————————"
            echo "tg:// 链接: tg://proxy?server=${PUBLIC_IP}&port=${PORT}&secret=${SECRET}"
            echo "t.me 分享链接: https://t.me/proxy?server=${PUBLIC_IP}&port=${PORT}&secret=${SECRET}"
            echo "—————————————————————————————————————————————————————————"
        fi
    else
        warn "MTProxy 容器 ($MT_NAME) 未运行或不存在。"
        echo "—————————————————————————————————————"
        docker ps -a --filter "name=$MT_NAME" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    fi
}


# ---------------- 自动生成合法 secret ----------------
generate_secret() {
    local NEW_SECRET
    # 16 字节 => 32 hex
    NEW_SECRET=$(openssl rand -hex 16)
    echo "${NEW_SECRET}${APP_NAME}"
}

# ---------------- 安装 MTProxy ----------------
install_mtproxy() {
    check_docker

    read -rp "请输入端口号 (留空使用默认 $DEFAULT_PORT): " INPUT_PORT
    PORT=${INPUT_PORT:-$DEFAULT_PORT}

    SECRET=$(generate_secret)

    log "生成 secret: $SECRET"

    mkdir -p "$DATA_DIR"

    # 停止并删除旧容器
    docker rm -f "$MT_NAME" &>/dev/null || true

    log "开始启动 MTProxy 容器..."
    
    # 运行容器
    docker run -d --name "$MT_NAME" \
        --restart always \
        -p "$PORT:$PORT" \
        -e SECRET="$SECRET" \
        -v "$DATA_DIR":/data \
        "$DOCKER_IMAGE"

    # 等待一小会儿，确保容器启动
    sleep 3
    
    log "MTProxy 安装完成！请检查运行状态。"
    get_status
}

# ---------------- 更新镜像 ----------------
update_mtproxy() {
    check_docker
    log "开始拉取最新镜像..."
    docker pull "$DOCKER_IMAGE"
    
    # 如果容器存在，则重启
    if docker ps -a --filter "name=$MT_NAME" --format "{{.Names}}" | grep -q "$MT_NAME"; then
        log "容器存在，将停止、删除并使用新镜像重启..."
        # 停止并删除旧容器
        docker rm -f "$MT_NAME" || true
        # 尝试从容器环境中获取旧配置，如果获取失败则退出
        if ! get_status &>/dev/null; then
            error "无法获取当前容器的配置（端口和 Secret），请手动输入或运行安装！"
            return 1
        fi
        
        # 重新运行容器使用新的镜像和旧的配置
        log "使用旧配置 (端口: $PORT, Secret: $SECRET) 启动新容器..."
        docker run -d --name "$MT_NAME" \
            --restart always \
            -p "$PORT:$PORT" \
            -e SECRET="$SECRET" \
            -v "$DATA_DIR":/data \
            "$DOCKER_IMAGE"
        log "MTProxy 已使用新镜像更新并重启。"
    else
        log "容器不存在，请选择 (1) 安装 MTProxy。"
    fi
}

# ---------------- 卸载 ----------------
uninstall_mtproxy() {
    read -rp "警告: 确定要卸载 MTProxy 容器和镜像吗? [y/N]: " CONFIRM
    if [[ "$CONFIRM" != [yY] ]]; then
        log "卸载已取消。"
        return
    fi
    
    log "停止并删除容器..."
    docker rm -f "$MT_NAME" &>/dev/null || true
    
    read -rp "是否删除本地数据目录 $DATA_DIR ? [y/N]: " REMOVE_DATA
    if [[ "$REMOVE_DATA" == [yY] ]]; then
        log "删除数据目录 $DATA_DIR ..."
        rm -rf "$DATA_DIR"
    fi
    
    log "删除 Docker 镜像..."
    docker rmi "$DOCKER_IMAGE" &>/dev/null || true
    
    log "MTProxy 已彻底卸载。"
}

# ---------------- 更改端口/Secret 的通用重启函数 ----------------
restart_with_new_config() {
    local NEW_PORT="$1"
    local NEW_SECRET="$2"
    
    # 尝试获取旧配置
    get_status &>/dev/null 

    # 如果有新端口，则使用新端口，否则使用旧端口
    if [[ -n "$NEW_PORT" ]]; then
        PORT="$NEW_PORT"
    fi
    # 如果有新 Secret，则使用新 Secret，否则使用旧 Secret
    if [[ -n "$NEW_SECRET" ]]; then
        SECRET="$NEW_SECRET"
    fi
    
    if [[ -z "$SECRET" ]]; then
        error "无法确定 Secret，无法重启。请先运行安装或手动指定 Secret。"
        return 1
    fi
    
    log "停止并删除现有容器..."
    docker rm -f "$MT_NAME" &>/dev/null || true

    log "使用新配置 (端口: $PORT, Secret: $SECRET) 启动容器..."
    
    docker run -d --name "$MT_NAME" \
        --restart always \
        -p "$PORT:$PORT" \
        -e SECRET="$SECRET" \
        -v "$DATA_DIR":/data \
        "$DOCKER_IMAGE"
        
    log "MTProxy 已使用新配置重启。"
    get_status
}

# ---------------- 修改端口 ----------------
change_port() {
    read -rp "请输入新端口 (当前: $PORT): " NEW_PORT_INPUT
    if [[ -z "$NEW_PORT_INPUT" ]]; then
        error "端口号不能为空。"
        return 1
    fi
    
    log "准备修改端口为 $NEW_PORT_INPUT..."
    restart_with_new_config "$NEW_PORT_INPUT" ""
}

# ---------------- 修改 secret ----------------
change_secret() {
    read -rp "请输入新 secret (留空自动生成): " NEW_SECRET_INPUT
    
    if [[ -z "$NEW_SECRET_INPUT" ]]; then
        NEW_SECRET_INPUT=$(generate_secret)
        log "自动生成新的 secret: $NEW_SECRET_INPUT"
    fi
    
    log "准备修改 Secret..."
    restart_with_new_config "" "$NEW_SECRET_INPUT"
}

# ---------------- 查看日志 ----------------
show_logs() {
    log "正在查看 MTProxy 容器日志 (按 Ctrl+C 退出)..."
    docker logs -f "$MT_NAME"
}

# ---------------- 主菜单 ----------------
while true; do
    echo
    echo "—————— Telegram MTProxy 管理脚本 ——————"
    echo "当前容器名: ${MT_NAME} | 默认端口: ${DEFAULT_PORT}"
    echo "请选择操作："
    echo " 1) ${C_GREEN}安装/全新部署${C_RESET}"
    echo " 2) 更新镜像并重启"
    echo " 3) 卸载"
    echo " 4) 查看信息 (状态/IP/链接)"
    echo " 5) 更改端口"
    echo " 6) 更改 secret"
    echo " 7) 查看日志"
    echo " 8) 退出"
    echo "—————————————————————————————————————"
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