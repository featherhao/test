#!/bin/bash
###
# @Author: man snow
# @Date: 2025-10-04
# @Description: ZtoApi 自动安装/启动脚本（OpenAI兼容API代理 for Z.ai GLM-4.6）
###

set -Eeuo pipefail

# ================== 彩色定义 ==================
C_RESET="\e[0m"
C_GREEN="\e[32m"
C_YELLOW="\e[33m"
C_RED="\e[31m"
C_BLUE="\e[34m"
C_BOLD="\e[1m"

info()  { echo -e "${C_GREEN}[INFO]${C_RESET} $*"; }
warn()  { echo -e "${C_YELLOW}[WARN]${C_RESET} $*"; }
error() { echo -e "${C_RED}[ERROR]${C_RESET} $*"; }

# ================== 配置 ==================
INSTALL_DIR="/opt/zto-api"
REPO_URL="https://github.com/forked-or-official/ZtoApi.git"
DEFAULT_PORT=9090

# ================== 安装依赖 ==================
install_dependencies() {
    info "安装必要依赖..."
    if command -v apt &>/dev/null; then
        sudo apt update
        sudo apt install -y git curl wget build-essential golang
    elif command -v yum &>/dev/null; then
        sudo yum install -y git curl wget golang
    fi
}

# ================== 克隆或更新仓库 ==================
clone_or_update_repo() {
    if [[ -d "$INSTALL_DIR" ]]; then
        info "仓库已存在，尝试更新..."
        cd "$INSTALL_DIR"
        git pull
    else
        info "克隆仓库到 $INSTALL_DIR ..."
        sudo git clone "$REPO_URL" "$INSTALL_DIR"
    fi
}

# ================== 配置文件 ==================
setup_env() {
    cd "$INSTALL_DIR"
    if [[ ! -f ".env.local" ]]; then
        info "复制配置模板..."
        cp .env.example .env.local
        warn "请根据需要编辑 .env.local 文件"
    fi
}

# ================== 启动服务 ==================
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
    detect_urls
}

# ================== Docker 启动 ==================
docker_run() {
    info "构建 Docker 镜像..."
    docker build -t zto-api .
    info "运行 Docker 容器..."
    docker run -d -p ${DEFAULT_PORT}:${DEFAULT_PORT} \
      -e ZAI_TOKEN=${ZAI_TOKEN:-""} \
      -e DEFAULT_KEY=${DEFAULT_KEY:-"sk-your-key"} \
      zto-api
    detect_urls
}

# ================== 显示访问地址 ==================
detect_urls() {
    local ip
    ip=$(hostname -I | awk '{print $1}')
    info "服务已启动！访问地址如下："
    echo -e "${C_BOLD}API Base URL:${C_RESET} http://${ip}:${DEFAULT_PORT}/v1"
    echo -e "${C_BOLD}API 文档:${C_RESET} http://${ip}:${DEFAULT_PORT}/docs"
    echo -e "${C_BOLD}Dashboard:${C_RESET} http://${ip}:${DEFAULT_PORT}/dashboard"
}

# ================== 菜单 ==================
show_menu() {
    echo -e "\n${C_BLUE}===== ZtoApi 安装与管理脚本 =====${C_RESET}"
    echo "1) 安装依赖"
    echo "2) 克隆/更新仓库"
    echo "3) 配置环境文件"
    echo "4) 启动服务"
    echo "5) Docker 启动"
    echo "0) 退出"
    echo -n "请选择操作 [0-5]: "
    read -r choice
    case $choice in
        1) install_dependencies ;;
        2) clone_or_update_repo ;;
        3) setup_env ;;
        4) start_service ;;
        5) docker_run ;;
        0) exit 0 ;;
        *) warn "无效选项" ;;
    esac
}

# ================== 主循环 ==================
while true; do
    show_menu
done
