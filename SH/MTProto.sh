#!/bin/bash
set -Eeuo pipefail

# ---------------- 基础配置 ----------------
MT_NAME="mtproxy"
DEFAULT_PORT=443  # 最终建议使用 443 端口以获得最佳抗封锁效果
DOCKER_IMAGE="telegrammessenger/proxy:latest"
DATA_DIR="/opt/mtproxy"

# ****** 关键修正：伪装域名 Hex ******
# 使用 www.microsoft.com 的 16 字节 Hex 编码
FAKE_TLS_DOMAIN_HEX="7777772e6d6963726f736f66742e636f6d"

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

# ---------------- 自动获取运行配置 ----------------
update_global_config() {
    if docker inspect -f '{{.State.Running}}' "$MT_NAME" &>/dev/null; then
        
        # 提取 Secret
        GLOBAL_SECRET_RAW=$(docker inspect "$MT_NAME" | grep '"SECRET="' | awk -F'"' '{print $4}')
        if [[ -n "$GLOBAL_SECRET_RAW" ]]; then
            SECRET=$GLOBAL_SECRET_RAW
        fi
        
        # 提取端口 (Host 模式下从 ENV 变量获取)
        GLOBAL_PORT_RAW=$(docker inspect "$MT_NAME" | grep '"PORT="' | awk -F'"' '{print $4}')
        if [[ -n "$GLOBAL_PORT_RAW" ]]; then
             PORT=$GLOBAL_PORT_RAW
        elif [[ -z "$PORT" ]]; then
            # 最终回退到默认端口
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
            echo "—————————————————————————————————————"
            # Host 模式下 PORTS 字段会显示空白，这是正常的。
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
    local PURE_SECRET
    # 1. 生成纯 32 位 Hex Secret
    PURE_SECRET=$(openssl rand -hex 16)
    
    # 2. 拼接为 64 位 Hex (纯Secret + 伪装域名Hex)
    local FULL_64_HEX="${PURE_SECRET}${FAKE_TLS_DOMAIN_HEX}"
    
    # 3. ****** 关键修正：添加 'ee' 前缀，启用 Fake TLS 模式 ******
    # 最终长度是 66 位 (ee + 64位 Hex)
    echo "ee${FULL_64_HEX}"
}

# ---------------- 安装 MTProxy ----------------
install_mtproxy() {
    check_docker

    read -rp "请输入端口号 (强烈建议使用 443，留空使用默认 $DEFAULT_PORT): " INPUT_PORT
    PORT=${INPUT_PORT:-$DEFAULT_PORT}

    # SECRET 现在是完整的 ee + 64 位 Hex
    SECRET=$(generate_secret)

    log "生成 EE-Prefix Secret (Fake TLS): $SECRET"

    mkdir -p "$DATA_DIR"

    # 停止并删除旧容器
    docker rm -f "$MT_NAME" &>/dev/null || true

    log "开始启动 MTProxy 容器 (Host 网络模式)..."
    
    # ****** 核心修正：使用 --network host，并传递 PORT 环境变量 ******
    docker run -d --name "$MT_NAME" \
        --restart always \
        --network host \
        -e SECRET="$SECRET" \
        -e PORT="$PORT" \
        -v "$DATA_DIR":/data \
        "$DOCKER_IMAGE"

    # 等待一小会儿，确保容器启动
    sleep 3
    
    log "MTProxy 安装完成！请检查运行状态。"
    get_status
    log "****** 最终步骤：请务必检查 VPS 控制面板/安全组是否开放了端口 $PORT 的 TCP/UDP 流量。******"
}

# ---------------- 更改端口/Secret 的通用重启函数 ----------------
restart_with_new_config() {
    local NEW_PORT="$1"
    local NEW_SECRET="$2"
    
    if ! update_global_config; then
        error "无法获取当前容器配置，请先运行安装 (选项 1)。"
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
    
    log "停止并删除现有容器..."
    docker rm -f "$MT_NAME" &>/dev/null || true

    log "使用新配置 (Host 模式, 端口: $PORT, Secret: $SECRET) 启动容器..."
    
    # ****** 核心修正：使用 --network host，并传递 PORT 环境变量 ******
    docker run -d --name "$MT_NAME" \
        --restart always \
        --network host \
        -e SECRET="$SECRET" \
        -e PORT="$PORT" \
        -v "$DATA_DIR":/data \
        "$DOCKER_IMAGE"
        
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
    echo "—————— Telegram MTProxy 管理脚本 (Host 网络模式/EE-Prefix) ——————"
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
        *) error "无效选项：请输入 1-8 之间的数字。" ;;
    esac
done