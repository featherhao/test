#!/bin/bash
set -Eeuo pipefail

# --- 变量定义 ---
SCRIPT_DIR="/home/mtproxy"
DOCKER_IMAGE="ellermister/mtproxy"
DOCKER_NAME="mtproxy"

C_RESET="\e[0m"; C_GREEN="\e[32m"; C_RED="\e[31m"; C_YELLOW="\e[33m"
log()   { echo -e "${C_GREEN}[INFO]${C_RESET} $1"; }
error() { echo -e "${C_RED}[ERROR]${C_RESET} $1"; }
warn()  { echo -e "${C_YELLOW}[WARN]${C_RESET} $1"; }

# --- 基础工具函数 ---
check_docker() {
    if ! command -v docker &>/dev/null; then
        warn "Docker 未安装，Docker 方式安装需要先安装 Docker。"
        read -rp "是否立即安装 Docker (y/N)? " CONFIRM
        if [[ "$CONFIRM" == [yY] ]]; then
            log "开始安装 Docker..."
            curl -fsSL https://get.docker.com -o get-docker.sh
            sh get-docker.sh
            log "Docker 安装完成。请重新运行脚本。"
            exit 0
        else
            error "Docker 安装已取消。"
            exit 1
        fi
    fi
}

# --- 1. 原生脚本安装方式 ---
install_script_mode() {
    log "选择：使用原生脚本安装 MTProxy..."
    log "建议：如果反复遇到错误，请更换为 Debian 9+ 或使用 Docker 方式。"

    log "清理并创建安装目录: $SCRIPT_DIR"
    rm -rf "$SCRIPT_DIR" || true
    mkdir -p "$SCRIPT_DIR" && cd "$SCRIPT_DIR"

    log "下载 MTProxy 安装脚本..."
    curl -fsSL -o mtproxy.sh https://github.com/ellermister/mtproxy/raw/master/mtproxy.sh
    chmod +x mtproxy.sh

    log "执行安装脚本进行安装/配置..."
    bash mtproxy.sh

    log "原生 MTProxy 安装流程启动完毕。请注意屏幕上的提示信息。"
}

# --- 2. Docker 镜像安装方式 ---
install_docker_mode() {
    check_docker

    log "选择：使用 Docker 镜像安装 MTProxy (开箱即用)..."
    log "警告：该方式集成了 Nginx 伪装和白名单功能，与原生脚本二选一，请勿混用。"

    docker rm -f "$DOCKER_NAME" &>/dev/null || true

    # 询问配置
    read -rp "请输入映射的外部 HTTP 端口 (推荐 8080): " HTTP_PORT
    read -rp "请输入映射的外部 HTTPS/TLS 端口 (推荐 8443): " HTTPS_PORT
    read -rp "请输入伪装域名 (默认 cloudflare.com): " DOMAIN
    DOMAIN=${DOMAIN:-"cloudflare.com"}

    read -rp "是否关闭 IP 白名单 (默认开启): [OFF/IP/IPSEG] (输入 OFF 禁用): " IP_WHITE_LIST
    IP_WHITE_LIST=${IP_WHITE_LIST:-"IP"}

    SECRET=""
    if [[ "$IP_WHITE_LIST" == "OFF" ]]; then
        read -rp "请输入自定义 Secret (32位十六进制，留空则自动生成): " CUSTOM_SECRET
        if [[ -n "$CUSTOM_SECRET" ]]; then
             SECRET="-e secret=\"$CUSTOM_SECRET\""
        fi
    fi

    log "配置信息:"
    log "  - HTTP 端口: $HTTP_PORT"
    log "  - HTTPS 端口: $HTTPS_PORT"
    log "  - 伪装域名: $DOMAIN"
    log "  - 白名单模式: $IP_WHITE_LIST"

    log "开始拉取并创建 Docker 容器..."
    
    # 构建 Docker run 命令
    DOCKER_RUN_CMD="docker run -d \
--name $DOCKER_NAME \
--restart=always \
-e domain=\"$DOMAIN\" \
-e ip_white_list=\"$IP_WHITE_LIST\" \
$SECRET \
-p $HTTP_PORT:80 \
-p $HTTPS_PORT:443 \
$DOCKER_IMAGE"

    # 执行命令
    eval "$DOCKER_RUN_CMD"

    sleep 3
    log "MTProxy Docker 容器已启动。请查看日志获取链接参数。"
    log "--------------------------------------------------------"
    log "执行 'docker logs -f $DOCKER_NAME' 查看最终链接和 Secret。"
    log "连接端口为外部映射端口，例如 $HTTPS_PORT。"
    log "--------------------------------------------------------"
}


# --- 3. Docker 管理功能 (简化) ---
docker_management() {
    local ACTION="$1"
    
    if ! docker ps -a --filter "name=$DOCKER_NAME" --format "{{.Names}}" | grep -q "$DOCKER_NAME"; then
        error "Docker 容器 '$DOCKER_NAME' 不存在，请先安装。"
        return 1
    fi

    case "$ACTION" in
        start)
            log "启动 Docker 容器..."
            docker start "$DOCKER_NAME"
            log "容器已启动。"
            ;;
        stop)
            log "停止 Docker 容器..."
            docker stop "$DOCKER_NAME"
            log "容器已停止。"
            ;;
        restart)
            log "重启 Docker 容器..."
            docker restart "$DOCKER_NAME"
            log "容器已重启。"
            ;;
        logs)
            log "查看 Docker 容器日志 (按 Ctrl+C 退出)..."
            docker logs -f "$DOCKER_NAME"
            ;;
        uninstall)
            log "卸载 Docker 容器和镜像..."
            docker rm -f "$DOCKER_NAME"
            read -rp "是否删除本地镜像 $DOCKER_IMAGE? [y/N]: " REMOVE_IMAGE
            if [[ "$REMOVE_IMAGE" == [yY] ]]; then
                docker rmi "$DOCKER_IMAGE" &>/dev/null || true
            fi
            log "Docker 版 MTProxy 已卸载。"
            ;;
        *)
            error "无效操作。"
            ;;
    esac
}


# --- 主菜单逻辑 ---

# 如果用户只传入一个参数，则可能是管理命令
if [[ $# -eq 1 ]]; then
    if [[ "$1" == "docker-start" ]]; then docker_management start; exit 0; fi
    if [[ "$1" == "docker-stop" ]]; then docker_management stop; exit 0; fi
    if [[ "$1" == "docker-restart" ]]; then docker_management restart; exit 0; fi
    if [[ "$1" == "docker-logs" ]]; then docker_management logs; exit 0; fi
    if [[ "$1" == "docker-uninstall" ]]; then docker_management uninstall; exit 0; fi
fi


while true; do
    echo
    echo "—————— MTProxy 一键安装管理脚本 ——————"
    echo "请选择安装模式："
    echo " 1) ${C_GREEN}原生脚本安装${C_RESET} (需要系统依赖, 运行官方脚本)"
    echo " 2) ${C_YELLOW}Docker 镜像安装${C_RESET} (开箱即用, 伪装/白名单)"
    echo "————————————————————————————————————"
    echo "管理现有 Docker 容器 (如果已安装):"
    echo " 3) 启动 Docker 容器"
    echo " 4) 停止 Docker 容器"
    echo " 5) 重启 Docker 容器"
    echo " 6) 查看 Docker 日志"
    echo " 7) 卸载 Docker 版本"
    echo " 8) 退出"
    echo "————————————————————————————————————"
    read -rp "请输入选项 [1-8]: " opt

    case $opt in
        1) install_script_mode ;;
        2) install_docker_mode ;;
        3) docker_management start ;;
        4) docker_management stop ;;
        5) docker_management restart ;;
        6) docker_management logs ;;
        7) docker_management uninstall ;;
        8) log "退出脚本。"; exit 0 ;;
        *) error "无效选项。" ;;
    esac
done