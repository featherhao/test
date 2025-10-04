#!/bin/bash
set -Eeuo pipefail

C_RESET="\e[0m"
C_GREEN="\e[32m"
C_YELLOW="\e[33m"
C_RED="\e[31m"
C_BLUE="\e[34m"
C_BOLD="\e[1m"

info()  { echo -e "${C_GREEN}[INFO]${C_RESET} $*"; }
warn()  { echo -e "${C_YELLOW}[WARN]${C_RESET} $*"; }
error() { echo -e "${C_RED}[ERROR]${C_RESET} $*"; }

INSTALL_DIR="/opt/zto-api"
DEFAULT_PORT=9090
DOCKER_CONTAINER_NAME="zto-api"

# ---------------- 检测安装 ----------------
is_installed() {
    [[ -d "$INSTALL_DIR" ]]
}

# ---------------- 显示访问地址 ----------------
show_urls() {
    local ip
    ip=$(hostname -I | awk '{print $1}')
    [[ -z "$ip" ]] && ip="localhost"

    echo -e "\n${C_BOLD}已检测到 ZtoApi 已安装，访问地址如下：${C_RESET}"
    echo -e "${C_BOLD}API Base URL:${C_RESET} http://${ip}:${DEFAULT_PORT}/v1"
    echo -e "${C_BOLD}API 文档:${C_RESET} http://${ip}:${DEFAULT_PORT}/docs"
    echo -e "${C_BOLD}Dashboard:${C_RESET} http://${ip}:${DEFAULT_PORT}/dashboard"
    echo ""
}

# ---------------- 一键安装 ----------------
install_all() {
    if is_installed; then
        warn "检测到 ZtoApi 已经安装！"
        show_urls
        return
    fi

    info "开始一键安装 ZtoApi..."

    # 安装依赖
    install_dependencies

    # 克隆仓库
    clone_or_update_repo

    # 配置环境
    setup_env

    # 启动服务
    start_service

    info "一键安装完成！"
    show_urls
}

install_dependencies() {
    info "安装必要依赖..."
    if command -v apt &>/dev/null; then
        sudo apt update
        sudo apt install -y git curl wget build-essential golang
    elif command -v yum &>/dev/null; then
        sudo yum install -y git curl wget golang
    fi
}

clone_or_update_repo() {
    if [[ -d "$INSTALL_DIR" ]]; then
        info "仓库已存在，尝试更新..."
        cd "$INSTALL_DIR"
        git pull
    else
        info "克隆仓库到 $INSTALL_DIR ..."
        sudo git clone "https://github.com/forked-or-official/ZtoApi.git" "$INSTALL_DIR"
    fi
}

setup_env() {
    cd "$INSTALL_DIR"
    if [[ ! -f ".env.local" ]]; then
        info "复制配置模板..."
        cp .env.example .env.local
        warn "请根据需要编辑 .env.local 文件"
    fi
}

start_service() {
    cd "$INSTALL_DIR"
    if [[ -f "./start.sh" ]]; then
        info "使用 start.sh 启动服务..."
        chmod +x ./start.sh
        ./start.sh &
    else
        info "直接使用 go run 启动服务..."
        go run main.go &
    fi
    sleep 2
}

# ---------------- 一键卸载 ----------------
uninstall_all() {
    if ! is_installed; then
        warn "未检测到安装，跳过卸载"
        return
    fi

    warn "即将一键卸载 ZtoApi..."
    read -p "确认删除安装目录、停止服务并删除 Docker 容器和镜像吗？ [y/N]: " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        info "取消卸载"
        return
    fi

    # 停止 Go 服务
    pkill -f "go run main.go" || true

    # 停止 Docker 容器
    docker stop "$DOCKER_CONTAINER_NAME" 2>/dev/null || true
    docker rm "$DOCKER_CONTAINER_NAME" 2>/dev/null || true

    # 删除 Docker 镜像
    docker rmi zto-api 2>/dev/null || true

    # 删除安装目录
    sudo rm -rf "$INSTALL_DIR"

    info "ZtoApi 已全部卸载完成！"
}

# ---------------- 菜单 ----------------
show_menu() {
    clear
    echo -e "${C_BLUE}===== ZtoApi 管理脚本 =====${C_RESET}"

    # 如果已安装，显示访问地址
    is_installed && show_urls

    echo "1) 一键安装 ZtoApi"
    echo "2) 一键卸载 ZtoApi"
    echo "0) 退出"
    echo -n "请选择操作 [0-2]: "
    read -r choice
    case $choice in
        1) install_all ;;
        2) uninstall_all ;;
        0) exit 0 ;;
        *) warn "无效选项" ;;
    esac
}

# ---------------- 主循环 ----------------
while true; do
    show_menu
    echo -e "\n按回车继续..."
    read -r
done
