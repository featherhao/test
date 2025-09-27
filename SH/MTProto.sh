#!/bin/bash
set -Eeuo pipefail

# ---------------- 基础配置 ----------------
MT_NAME="mtproxy"
DEFAULT_PORT=443
DOCKER_IMAGE="telegrammessenger/proxy:latest" 
DATA_DIR="/opt/mtproxy"

# ****** 关键修正：伪装域名 Hex 和纯域名 ******
FAKE_TLS_DOMAIN_HEX="7777772e6d6963726f736f66742e636f6d"
FAKE_TLS_DOMAIN="www.microsoft.com" 

# 全局变量，用于存储当前运行的端口和 Secret
PORT=$DEFAULT_PORT
SECRET=""
PURE_SECRET="" 

C_RESET="\e[0m"; C_GREEN="\e[32m"; C_RED="\e[31m"; C_YELLOW="\e[33m"

# ---------------- 彩色输出 ----------------
log()   { echo -e "${C_GREEN}[INFO]${C_RESET} $1"; }
error() { echo -e "${C_RED}[ERROR]${C_RESET} $1"; }
warn()  { echo -e "${C_YELLOW}[WARN]${C_RESET} $1"; }

# ---------------- 检查 Docker ----------------
check_docker() {
    if ! command -v docker &>/dev/null; then
        log "Docker 未安装，开始安装..."
        sudo apt update
        sudo apt install -y docker.io
        sudo systemctl enable docker
        sudo systemctl start docker
        log "Docker 安装并启动成功。"
    fi
}

# ---------------- 自动获取运行配置 ----------------
update_global_config() {
    if docker inspect -f '{{.State.Running}}' "$MT_NAME" &>/dev/null; then
        
        # 提取 PURE_SECRET
        GLOBAL_PURE_SECRET_RAW=$(docker inspect "$MT_NAME" | grep '"SECRET="' | awk -F'"' '{print $4}')
        if [[ -n "$GLOBAL_PURE_SECRET_RAW" ]]; then
            # 组合回完整的 EE-Secret 用于链接显示
            SECRET="ee${GLOBAL_PURE_SECRET_RAW}${FAKE_TLS_DOMAIN_HEX}"
        fi
        
        # 提取端口 (从容器的CMD参数中获取端口号)
        # 这需要一个更复杂的提取逻辑，但为了简化，我们先依赖用户输入的 PORT 变量，或者从默认值获取
        GLOBAL_PORT_RAW=$(docker inspect "$MT_NAME" | grep -A 1 '"Cmd"' | grep -oE '\<[0-9]{3,5}\>' | head -n 1)
        if [[ -n "$GLOBAL_PORT_RAW" ]]; then
             PORT=$GLOBAL_PORT_RAW
        elif [[ -z "$PORT" ]]; then
            PORT=$DEFAULT_PORT
        fi
        
        return 0
    else
        return 1
    fi
}

# ---------------- 获取运行状态 ----------------
get_status() {
    log "MTProxy 容器状态："
    
    if update_global_config; then
        PUBLIC_IP=$(curl -s ifconfig.me)

        if [[ -n "$SECRET" ]]; then
            log "当前配置 - IP: ${PUBLIC_IP} | 端口: ${PORT} | Secret: ${SECRET}"
            
            # 最终检查端口监听状态
            echo "—————————————————————————————————————"
            log "正在检查宿主机端口 $PORT 是否在监听..."
            sudo ss -tuln | grep "$PORT" || log "宿主机端口 $PORT 未监听（请检查日志或外部防火墙）"
            echo "—————————————————————————————————————"

            docker ps --filter "name=$MT_NAME" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
            
            echo "———————————————— Telegram MTProto 代理链接 ————————————————"
            echo "tg:// 链接: tg://proxy?server=${PUBLIC_IP}&port=${PORT}&secret=${SECRET}"
            echo "t.me 分享链接: https://t.me/proxy?server=${PUBLIC_IP}&port=${PORT}&secret=${SECRET}"
            echo "—————————————————————————————————————————————————————————"
        else
            error "无法从容器中提取 Secret，请尝试重新运行安装或检查日志。"
        fi
    else
        warn "MTProxy 容器 ($MT_NAME) 未运行或不存在。"
        echo "—————————————————————————————————————"
        docker ps -a --filter "name=$MT_NAME" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    fi
}

# ---------------- 自动生成合法的 EE-Prefix Fake TLS Secret ----------------
generate_secret() {
    local PURE_SECRET_GEN
    PURE_SECRET_GEN=$(openssl rand -hex 16)
    local FULL_64_HEX="${PURE_SECRET_GEN}${FAKE_TLS_DOMAIN_HEX}"
    echo "ee${FULL_64_HEX}"
}

# ---------------- 安装 MTProxy ----------------
install_mtproxy() {
    check_docker

    # ****** 核心步骤：强制清理环境，避免冲突 ******
    log "强制清理残留容器和Docker网络配置..."
    docker rm -f "$MT_NAME" &>/dev/null || true
    sudo systemctl daemon-reload
    sudo systemctl restart docker
    sleep 3
    log "清理完成，Docker已重启。"
    # **********************************************

    read -rp "请输入端口号 (推荐 26666，否则使用默认 $DEFAULT_PORT): " INPUT_PORT
    PORT=${INPUT_PORT:-$DEFAULT_PORT}

    SECRET=$(generate_secret) 
    PURE_SECRET=${SECRET:2:32} 

    log "生成 EE-Prefix Secret (用于链接): $SECRET"
    log "提取纯 Secret (用于容器启动): $PURE_SECRET"

    mkdir -p "$DATA_DIR"

    log "开始启动 MTProxy 容器 (Host 网络模式, 官方镜像/端口参数修正)..."
    
    # ****** 最终修正：将端口作为 CMD 参数传递，而不是环境变量 ******
    docker run -d --name "$MT_NAME" \
        --restart always \
        --network host \
        -e SECRET="$PURE_SECRET" \
        -e "FAKE_TLS_DOMAIN=$FAKE_TLS_DOMAIN" \
        -v "$DATA_DIR":/data \
        "$DOCKER_IMAGE" \
        --port "$PORT" # <- 关键修正：端口作为命令行参数

    # 等待一小会儿，确保容器启动
    sleep 3
    
    log "MTProxy 安装完成！请检查运行状态。"
    get_status
    log "****** 最终提醒：如果仍不通，请检查 VPS 控制面板/安全组是否开放了端口 $PORT 的 TCP/UDP 流量。******"
}

# ---------------- 更改端口/Secret 的通用重启函数 ----------------
restart_with_new_config() {
    local NEW_PORT="$1"
    local NEW_SECRET="$2"
    
    if ! update_global_config; then
        error "无法获取当前容器配置，请先运行安装 (选项 1) 或手动确定 Secret。"
        return 1
    fi

    if [[ -n "$NEW_PORT" ]]; then
        PORT="$NEW_PORT"
    fi
    if [[ -n "$NEW_SECRET" ]]; then
        SECRET="$NEW_SECRET"
    fi
    
    if [[ -z "$SECRET" ]]; then
        error "无法确定 Secret，无法重启。"
        return 1
    fi
    
    PURE_SECRET=${SECRET:2:32}

    log "停止并删除现有容器..."
    docker rm -f "$MT_NAME" &>/dev/null || true

    log "使用新配置 (Host 模式, 端口: $PORT, Secret: $SECRET) 启动容器..."
    
    # ****** 最终修正：将端口作为 CMD 参数传递，而不是环境变量 ******
    docker run -d --name "$MT_NAME" \
        --restart always \
        --network host \
        -e SECRET="$PURE_SECRET" \
        -e "FAKE_TLS_DOMAIN=$FAKE_TLS_DOMAIN" \
        -v "$DATA_DIR":/data \
        "$DOCKER_IMAGE" \
        --port "$PORT" # <- 关键修正：端口作为命令行参数
        
    log "MTProxy 已使用新配置重启。"
    get_status
    log "请务必检查 VPS 控制面板/安全组是否开放了端口 $PORT 的 TCP/UDP 流量。"
}

# ---------------- (其余功能函数不变) ----------------

update_mtproxy() {
    check_docker
    log "开始拉取最新镜像..."
    docker pull "$DOCKER_IMAGE"
    
    if docker ps -a --filter "name=$MT_NAME" --format "{{.Names}}" | grep -q "$MT_NAME"; then
        log "容器存在，将停止、删除并使用新镜像重启..."
        restart_with_new_config "" ""
    else
        log "容器不存在，请选择 (1) 安装 MTProxy。"
    fi
}

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


change_port() {
    if ! update_global_config; then
         error "MTProxy 容器未运行，请先运行安装 (选项 1)。"
         return 1
    fi
    
    read -rp "请输入新端口 (当前: $PORT): " NEW_PORT_INPUT
    if [[ -z "$NEW_PORT_INPUT" ]]; then
        error "端口号不能为空。"
        return 1
    fi
    
    log "准备修改端口为 $NEW_PORT_INPUT..."
    restart_with_new_config "$NEW_PORT_INPUT" ""
}

change_secret() {
    if ! update_global_config; then
         error "MTProxy 容器未运行，请先运行安装 (选项 1)。"
         return 1
    fi
    
    read -rp "请输入新 secret (留空自动生成): " NEW_SECRET_INPUT
    
    if [[ -z "$NEW_SECRET_INPUT" ]]; then
        NEW_SECRET_INPUT=$(generate_secret)
        log "自动生成新的 EE-Prefix Secret: $NEW_SECRET_INPUT"
    fi
    
    log "准备修改 Secret..."
    restart_with_new_config "" "$NEW_SECRET_INPUT"
}

show_logs() {
    log "正在查看 MTProxy 容器日志 (按 Ctrl+C 退出)..."
    docker logs -f "$MT_NAME"
}

# ---------------- 主菜单 ----------------
while true; do
    echo
    echo "—————— Telegram MTProxy 管理脚本 (端口参数修正) ——————"
    echo "当前容器名: ${MT_NAME} | 默认端口: ${DEFAULT_PORT}"
    echo "请选择操作："
    echo " 1) ${C_GREEN}安装/全新部署 (包含强制清理)${C_RESET}"
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
        *) error "无效选项：请输入 1-8 之间的数字。" ;;
    esac
done