#!/bin/bash
set -Eeuo pipefail

# ---------------- 基础配置 (BASE CONFIGURATION) ----------------
MT_NAME="mtproxy"
DEFAULT_PORT=6688
DOCKER_IMAGE="telegrammessenger/proxy:latest"
DATA_DIR="/opt/mtproxy"
APP_NAME="myapp"  # Telegram app 名称，可修改

C_RESET="\e[0m"; C_GREEN="\e[32m"; C_RED="\e[31m"; C_YELLOW="\e[33m"; C_BLUE="\e[34m"

# 动态配置变量 (Dynamic Configuration Variables)
CURRENT_PORT=$DEFAULT_PORT
CURRENT_SECRET=""
PUBLIC_IP=""

# ---------------- 彩色输出 (COLOR OUTPUT) ----------------
log()   { echo -e "${C_GREEN}[INFO]${C_RESET} $1"; }
error() { echo -e "${C_RED}[ERROR]${C_RESET} $1"; }
warn()  { echo -e "${C_YELLOW}[WARN]${C_RESET} $1"; }
info()  { echo -e "${C_BLUE}[CONFIG]${C_RESET} $1"; }

# ---------------- 检查 Docker (CHECK DOCKER) ----------------
check_docker() {
    if ! command -v docker &>/dev/null; then
        log "Docker 未安装，开始安装..."
        sudo apt update -qq >/dev/null
        sudo apt install -y docker.io >/dev/null
        sudo systemctl enable docker
        sudo systemctl start docker
        log "Docker 安装完成。"
    fi
}

# ---------------- 自动生成合法 secret (GENERATE SECRET) ----------------
generate_secret() {
    local SECRET_HEX
    SECRET_HEX=$(openssl rand -hex 16)  # 16 字节 => 32 hex
    echo "${SECRET_HEX}${APP_NAME}"
}

# ---------------- 防火墙管理 (FIREWALL MANAGEMENT) ----------------
manage_firewall() {
    local ACTION=$1 # "add" or "delete"
    local PORT_NUM=$2

    # 优先使用 UFW (Ubuntu/Debian)
    if command -v ufw &>/dev/null; then
        if [[ "$ACTION" == "add" ]]; then
            log "使用 UFW 开放端口 $PORT_NUM/tcp..."
            sudo ufw allow "$PORT_NUM"/tcp comment 'MTProxy'
            sudo ufw reload >/dev/null
        elif [[ "$ACTION" == "delete" ]]; then
            # 检查规则是否存在再删除，避免报错
            if sudo ufw status | grep -q "$PORT_NUM/tcp"; then
                log "使用 UFW 关闭端口 $PORT_NUM/tcp..."
                # 使用 y 确认删除，避免交互式提示
                echo "y" | sudo ufw delete allow "$PORT_NUM"/tcp >/dev/null 2>&1
            fi
        fi
    elif command -v firewall-cmd &>/dev/null; then
        # Firewalld (CentOS/RHEL) 仅做提示，推荐用户手动操作
        log "检测到 firewalld，但脚本不自动配置。请手动执行:"
        echo "  sudo firewall-cmd --zone=public --add-port=$PORT_NUM/tcp --permanent"
        echo "  sudo firewall-cmd --reload"
    else
        warn "未检测到 UFW 或 Firewall-cmd。请务必检查并手动开放系统防火墙 (端口: $PORT_NUM)！"
    fi
}


# ---------------- 加载当前配置 (LOAD CURRENT CONFIG) ----------------
load_config() {
    PUBLIC_IP=$(curl -s ifconfig.me)

    # 检查容器是否在运行或已创建
    if docker ps -a --filter "name=$MT_NAME" --format "{{.Names}}" | grep -q "$MT_NAME"; then
        # 尝试从 Docker 容器中提取当前端口和 Secret
        local PORT_BINDING
        PORT_BINDING=$(docker inspect -f '{{range $p, $conf := .HostConfig.PortBindings}}{{(index $conf 0).HostPort}}{{end}}' "$MT_NAME" 2>/dev/null)
        local SECRET_ENV
        SECRET_ENV=$(docker inspect -f '{{range .Config.Env}}{{if hasPrefix . "SECRET="}}{{.}}{{end}}{{end}}' "$MT_NAME" | cut -d'=' -f2)

        if [[ -n "$PORT_BINDING" ]]; then
            CURRENT_PORT=$PORT_BINDING
        else
            CURRENT_PORT=$DEFAULT_PORT
            warn "未能从容器获取端口，使用默认端口 $DEFAULT_PORT。"
        fi

        if [[ -n "$SECRET_ENV" ]]; then
            CURRENT_SECRET=$SECRET_ENV
        else
            CURRENT_SECRET=$(generate_secret)
            warn "未能从容器获取 Secret，已生成新的 Secret (请重新启动容器)。"
        fi
    else
        # 如果容器不存在，使用默认值
        CURRENT_PORT=$DEFAULT_PORT
        CURRENT_SECRET=$(generate_secret)
    fi
}

# ---------------- 获取运行状态 (GET STATUS) ----------------
get_status() {
    load_config
    echo "————————————— ${C_YELLOW}MTProxy 状态概览${C_RESET} —————————————"
    docker ps --all --filter "name=$MT_NAME" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}\t{{.ID}}"

    local CONTAINER_ID
    CONTAINER_ID=$(docker ps -a --filter "name=$MT_NAME" --format "{{.ID}}")
    if [[ -z "$CONTAINER_ID" ]]; then
        warn "MTProxy 容器未找到或未运行。"
        echo "—————————————————————————————————————————————"
        return 1
    fi

    echo
    info "对外 IP: ${PUBLIC_IP}"
    info "端口: ${CURRENT_PORT}"
    info "Secret: ${CURRENT_SECRET}"
    echo
    echo "${C_YELLOW}tg:// 链接:${C_RESET}"
    echo "tg://proxy?server=${PUBLIC_IP}&port=${CURRENT_PORT}&secret=${CURRENT_SECRET}"
    echo
    echo "${C_YELLOW}t.me 分享链接:${C_RESET}"
    echo "https://t.me/proxy?server=${PUBLIC_IP}&port=${CURRENT_PORT}&secret=${CURRENT_SECRET}"
    echo "—————————————————————————————————————————————"
}

# ---------------- 运行/安装 MTProxy (INSTALL MTProxy) ----------------
install_mtproxy() {
    check_docker
    load_config # 确保获取最新的 PUBLIC_IP

    read -rp "请输入端口号 (留空使用默认 $DEFAULT_PORT): " PORT_INPUT
    local NEW_PORT=${PORT_INPUT:-$DEFAULT_PORT}
    local NEW_SECRET=$(generate_secret)

    log "生成的 Secret: ${NEW_SECRET}"

    mkdir -p "$DATA_DIR"

    # 停止并移除现有容器
    docker rm -f "$MT_NAME" &>/dev/null || true

    # 启动新容器
    docker run -d --name "$MT_NAME" \
        -p "$NEW_PORT:$NEW_PORT" \
        -e SECRET="$NEW_SECRET" \
        -v "$DATA_DIR":/data \
        "$DOCKER_IMAGE"

    CURRENT_PORT=$NEW_PORT
    CURRENT_SECRET=$NEW_SECRET

    # 配置防火墙
    manage_firewall "add" "$CURRENT_PORT"

    log "MTProxy 安装完成！"
    get_status
}

# ---------------- 更新镜像 (UPDATE IMAGE) ----------------
update_mtproxy() {
    check_docker
    log "开始拉取最新镜像 $DOCKER_IMAGE..."
    docker pull "$DOCKER_IMAGE"
    log "镜像已更新。请考虑重新安装 (选项 1) 以应用新镜像。"
}

# ---------------- 卸载 (UNINSTALL) ----------------
uninstall_mtproxy() {
    load_config # 获取当前端口以便移除防火墙规则
    docker rm -f "$MT_NAME" &>/dev/null || true
    docker rmi "$DOCKER_IMAGE" &>/dev/null || true
    manage_firewall "delete" "$CURRENT_PORT"
    log "已彻底卸载 MTProxy 容器和镜像。"
}

# ---------------- 修改端口 (CHANGE PORT) ----------------
change_port() {
    load_config
    
    if ! docker ps -a --filter "name=$MT_NAME" --format "{{.Names}}" | grep -q "$MT_NAME"; then
        error "MTProxy 容器不存在或未运行，请先安装 (选项 1)。"
        return 1
    fi

    read -rp "请输入新端口 (当前: ${CURRENT_PORT}): " NEW_PORT
    if [[ -z "$NEW_PORT" ]]; then
        error "端口号不能为空。"
        return 1
    fi
    
    # 移除旧端口的防火墙规则
    manage_firewall "delete" "$CURRENT_PORT"
    
    # 停止/移除旧容器
    docker stop "$MT_NAME" &>/dev/null || true
    docker rm "$MT_NAME" &>/dev/null || true
    
    # 设置新端口
    local OLD_PORT=$CURRENT_PORT
    CURRENT_PORT=$NEW_PORT
    
    # 运行新容器 (使用现有的 Secret)
    docker run -d --name "$MT_NAME" \
        -p "$CURRENT_PORT:$CURRENT_PORT" \
        -e SECRET="$CURRENT_SECRET" \
        -v "$DATA_DIR":/data \
        "$DOCKER_IMAGE"

    # 添加新端口的防火墙规则
    manage_firewall "add" "$CURRENT_PORT"
    
    log "端口已从 $OLD_PORT 修改为 ${CURRENT_PORT}。"
}

# ---------------- 修改 secret (CHANGE SECRET) ----------------
change_secret() {
    load_config

    if ! docker ps -a --filter "name=$MT_NAME" --format "{{.Names}}" | grep -q "$MT_NAME"; then
        error "MTProxy 容器不存在或未运行，请先安装 (选项 1)。"
        return 1
    fi

    read -rp "请输入新 secret (留空自动生成): " NEW_SECRET
    local GENERATED_SECRET=$(generate_secret)
    local FINAL_SECRET=${NEW_SECRET:-$GENERATED_SECRET}

    # 停止/移除旧容器
    docker stop "$MT_NAME" &>/dev/null || true
    docker rm "$MT_NAME" &>/dev/null || true
    
    # 设置新 secret
    CURRENT_SECRET=$FINAL_SECRET
    
    # 运行新容器 (使用现有的端口)
    docker run -d --name "$MT_NAME" \
        -p "$CURRENT_PORT:$CURRENT_PORT" \
        -e SECRET="$CURRENT_SECRET" \
        -v "$DATA_DIR":/data \
        "$DOCKER_IMAGE"

    log "Secret 已修改: ${CURRENT_SECRET}"
    get_status
}

# ---------------- 查看日志 (SHOW LOGS) ----------------
show_logs() {
    if ! docker ps -a --filter "name=$MT_NAME" --format "{{.Names}}" | grep -q "$MT_NAME"; then
        error "MTProxy 容器未找到。"
        return 1
    fi
    docker logs -f "$MT_NAME"
}

# ---------------- 主菜单 (MAIN MENU) ----------------
load_config
while true; do
    echo
    echo "————————————— ${C_GREEN}MTProxy 管理工具${C_RESET} —————————————"
    docker ps --filter "name=$MT_NAME" --format "状态: {{.Status}}" | sed 's/^/ /' || echo " 状态: 未运行"
    echo " 当前配置: IP=${PUBLIC_IP} 端口=${CURRENT_PORT}"
    echo "—————————————————————————————————————————————"
    echo "请选择操作："
    echo " 1) ${C_GREEN}安装/重新运行${C_RESET} MTProxy"
    echo " 2) 更新 Docker 镜像"
    echo " 3) 卸载 MTProxy"
    echo " 4) 查看信息 (${C_YELLOW}检查连接信息${C_RESET})"
    echo " 5) 更改端口"
    echo " 6) 更改 secret"
    echo " 7) 查看日志"
    echo " 8) 退出"
    echo "—————————————————————————————————————————————"

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
        *) error "无效选项" ;;
    esac
done
