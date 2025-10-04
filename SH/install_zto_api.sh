#!/bin/bash
set -Eeuo pipefail

# ================== 彩色输出 ==================
C_RESET="\e[0m"
C_GREEN="\e[32m"
C_RED="\e[31m"
C_YELLOW="\e[33m"
C_CYAN="\e[36m"

info() { echo -e "${C_GREEN}[INFO]${C_RESET} $*"; }
warn() { echo -e "${C_YELLOW}[WARN]${C_RESET} $*"; }
error() { echo -e "${C_RED}[ERROR]${C_RESET} $*"; }

# ================== 配置 ==================
INSTALL_DIR="/opt/zto-api"
PORT="${PORT:-9090}"
ZAI_TOKEN="${ZAI_TOKEN:-}"
DEFAULT_KEY="${DEFAULT_KEY:-sk-your-key}"

# ================== 功能函数 ==================
install_ztoapi() {
    info "开始安装 ZtoApi..."
    
    # 克隆仓库
    if [ ! -d "$INSTALL_DIR" ]; then
        info "克隆公开仓库到 $INSTALL_DIR ..."
        git clone https://github.com/your-username/ZtoApi.git "$INSTALL_DIR"
    else
        info "$INSTALL_DIR 已存在，跳过克隆"
    fi

    # 进入目录
    cd "$INSTALL_DIR"

    # 复制配置模板
    if [ ! -f ".env.local" ]; then
        cp .env.example .env.local
        info "复制 .env.example -> .env.local"
    fi

    # 设置环境变量
    export PORT="$PORT"
    export ZAI_TOKEN="$ZAI_TOKEN"
    export DEFAULT_KEY="$DEFAULT_KEY"

    # 启动服务
    chmod +x start.sh
    ./start.sh &

    sleep 3
    info "ZtoApi 安装完成！"
    info "访问地址: http://localhost:$PORT"
    info "Dashboard: http://localhost:$PORT/dashboard"
}

uninstall_ztoapi() {
    if [ -d "$INSTALL_DIR" ]; then
        info "停止服务..."
        pkill -f "go run main.go" || true
        pkill -f "$INSTALL_DIR" || true

        info "删除目录 $INSTALL_DIR ..."
        rm -rf "$INSTALL_DIR"

        info "卸载完成"
    else
        warn "未检测到安装目录 $INSTALL_DIR"
    fi
}

show_access_info() {
    if [ -d "$INSTALL_DIR" ]; then
        info "ZtoApi 已安装"
        info "访问地址: http://localhost:$PORT"
        info "Dashboard: http://localhost:$PORT/dashboard"
    else
        warn "ZtoApi 未安装"
    fi
}

# ================== 菜单 ==================
while true; do
    echo -e "\n================ ZtoApi 管理菜单 ================"
    echo "1) 安装 ZtoApi (全部安装)"
    echo "2) 卸载 ZtoApi (全部卸载)"
    echo "3) 显示访问地址"
    echo "0) 退出"
    echo "=================================================="
    read -rp "请选择操作 [0-3]: " choice

    case "$choice" in
        1) install_ztoapi ;;
        2) uninstall_ztoapi ;;
        3) show_access_info ;;
        0) exit 0 ;;
        *) warn "无效选项，请重新输入" ;;
    esac
done
