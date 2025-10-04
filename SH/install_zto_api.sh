#!/bin/bash
set -Eeuo pipefail

INSTALL_DIR="/opt/zto-api"
REPO_URL="https://github.com/libaxuan/ZtoApi.git"
ENV_FILE=".env.local"
PORT_DEFAULT=9090

# ================== 彩色输出 ==================
C_GREEN="\e[32m"
C_RED="\e[31m"
C_YELLOW="\e[33m"
C_RESET="\e[0m"

info() { echo -e "${C_GREEN}[INFO]${C_RESET} $1"; }
warn() { echo -e "${C_YELLOW}[WARN]${C_RESET} $1"; }
error() { echo -e "${C_RED}[ERROR]${C_RESET} $1"; }

# ================== 获取公网 IP ==================
get_public_ip() {
    curl -s https://api.ipify.org || echo "无法获取公网IP"
}

# ================== 安装 ZtoApi ==================
install_ztoapi() {
    info "开始安装 ZtoApi..."

    # 克隆仓库
    if [[ -d "$INSTALL_DIR" ]]; then
        warn "$INSTALL_DIR 已存在，跳过克隆"
    else
        git clone "$REPO_URL" "$INSTALL_DIR"
        info "已克隆仓库到 $INSTALL_DIR"
    fi

    cd "$INSTALL_DIR"

    # 生成默认环境文件
    if [[ ! -f "$ENV_FILE" ]]; then
        cp .env.example "$ENV_FILE"
        info "默认配置已生成于 $INSTALL_DIR/$ENV_FILE"
    fi

    # 启动服务
    info "启动 ZtoApi 服务..."
    PORT=$(grep -E '^PORT=' "$ENV_FILE" | cut -d= -f2 || echo "$PORT_DEFAULT")
    API_KEY=$(grep -E '^DEFAULT_KEY=' "$ENV_FILE" | cut -d= -f2 || echo "sk-your-key")
    MODEL_NAME=$(grep -E '^MODEL_NAME=' "$ENV_FILE" | cut -d= -f2 || echo "GLM-4.6")
    
    # 后台启动 Go 服务
    nohup go run main.go > ztoapi.log 2>&1 &
    sleep 2

    PUBLIC_IP=$(get_public_ip)

    info "ZtoApi 已安装"
    echo "访问地址: http://$PUBLIC_IP:$PORT"
    echo "API接口地址: http://$PUBLIC_IP:$PORT/v1"
    echo "Dashboard地址: http://$PUBLIC_IP:$PORT/dashboard"
}

# ================== 卸载 ZtoApi ==================
uninstall_ztoapi() {
    info "开始卸载 ZtoApi..."

    # 停止 Go 服务
    PIDS=$(pgrep -f "$INSTALL_DIR/main.go" || true)
    if [[ -n "$PIDS" ]]; then
        echo "$PIDS" | xargs kill -9
        info "已停止 Go 服务"
    fi

    # 停止 Docker 容器
    DOCKER_CONTAINER=$(docker ps -aq --filter "ancestor=zto-api" || true)
    if [[ -n "$DOCKER_CONTAINER" ]]; then
        docker stop $DOCKER_CONTAINER
        docker rm $DOCKER_CONTAINER
        info "已停止并删除 Docker 容器"
    fi

    # 删除安装目录
    if [[ -d "$INSTALL_DIR" ]]; then
        rm -rf "$INSTALL_DIR"
        info "已删除安装目录 $INSTALL_DIR"
    fi

    # 删除本地环境文件
    if [[ -f "$HOME/$ENV_FILE" ]]; then
        rm -f "$HOME/$ENV_FILE"
        info "已删除 $HOME/$ENV_FILE"
    fi

    info "ZtoApi 已彻底卸载"
}

# ================== 显示访问地址 ==================
show_address() {
    if [[ ! -d "$INSTALL_DIR" ]]; then
        warn "ZtoApi 未安装"
        return
    fi
    PORT=$(grep -E '^PORT=' "$INSTALL_DIR/$ENV_FILE" | cut -d= -f2 || echo "$PORT_DEFAULT")
    PUBLIC_IP=$(get_public_ip)
    echo "访问地址: http://$PUBLIC_IP:$PORT"
    echo "API接口地址: http://$PUBLIC_IP:$PORT/v1"
    echo "Dashboard地址: http://$PUBLIC_IP:$PORT/dashboard"
}

# ================== 菜单 ==================
while true; do
    echo ""
    echo "================ ZtoApi 管理菜单 ================"
    echo "1) 安装 ZtoApi (全部安装)"
    echo "2) 卸载 ZtoApi (全部卸载)"
    echo "3) 显示访问地址"
    echo "0) 退出"
    echo "=================================================="
    read -rp "请选择操作 [0-3]: " choice

    case $choice in
        1) install_ztoapi ;;
        2) uninstall_ztoapi ;;
        3) show_address ;;
        0) exit 0 ;;
        *) echo "无效选项，请重新选择" ;;
    esac
done
