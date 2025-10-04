#!/bin/bash
set -Eeuo pipefail

# ================== 彩色日志 ==================
if [[ -t 1 ]] && command -v tput &>/dev/null; then
    C_RESET="\e[0m"; C_BOLD="\e[1m"
    C_GREEN="\e[32m"; C_RED="\e[31m"; C_YELLOW="\e[33m"; C_BLUE="\e[34m"; C_CYAN="\e[36m"
else
    C_RESET=""; C_BOLD=""; C_GREEN=""; C_RED=""; C_YELLOW=""; C_BLUE=""; C_CYAN=""
fi

info()    { echo -e "${C_GREEN}[INFO]${C_RESET} $*"; }
warn()    { echo -e "${C_YELLOW}[WARN]${C_RESET} $*"; }
error()   { echo -e "${C_RED}[ERROR]${C_RESET} $*"; }

# ================== 配置 ==================
INSTALL_DIR="/opt/zto-api"
REPO_URL="https://github.com/libaxuan/ZtoApi.git"
PORT_DEFAULT=9090

# ================== 函数 ==================
check_installed() {
    [[ -d "$INSTALL_DIR" ]]
}

show_address() {
    if check_installed; then
        info "ZtoApi 已安装"
        local port
        port=$(grep -E "^PORT=" "$INSTALL_DIR/.env.local" 2>/dev/null | cut -d '=' -f2 || echo "$PORT_DEFAULT")
        echo -e "${C_CYAN}访问地址: http://localhost:${port}${C_RESET}"
        echo -e "${C_CYAN}API接口地址: http://localhost:${port}/v1${C_RESET}"
        echo -e "${C_CYAN}Dashboard地址: http://localhost:${port}/dashboard${C_RESET}"
    else
        warn "ZtoApi 尚未安装"
    fi
}

install_ztoapi() {
    if check_installed; then
        warn "ZtoApi 已经安装"
        show_address
        return
    fi

    info "开始安装 ZtoApi..."
    git clone "$REPO_URL" "$INSTALL_DIR"

    # 复制配置模板
    cp "$INSTALL_DIR/.env.example" "$INSTALL_DIR/.env.local" || true
    info "默认配置已生成于 $INSTALL_DIR/.env.local"

    # 赋予启动脚本执行权限
    chmod +x "$INSTALL_DIR/start.sh" || true

    # 启动服务
    info "启动 ZtoApi 服务..."
    (cd "$INSTALL_DIR" && ./start.sh &)

    sleep 3
    show_address
    info "安装完成"
}

uninstall_ztoapi() {
    if ! check_installed; then
        warn "ZtoApi 未安装"
        return
    fi

    info "停止 ZtoApi 服务..."
    pkill -f "$INSTALL_DIR/start.sh" || true

    info "删除安装目录 $INSTALL_DIR ..."
    rm -rf "$INSTALL_DIR"

    info "卸载完成"
}

# ================== 菜单 ==================
while true; do
    echo
    echo "================ ZtoApi 管理菜单 ================"
    echo "1) 安装 ZtoApi (全部安装)"
    echo "2) 卸载 ZtoApi (全部卸载)"
    echo "3) 显示访问地址"
    echo "0) 退出"
    echo "=================================================="
    read -rp "请选择操作 [0-3]: " choice

    case "$choice" in
        1) install_ztoapi ;;
        2) uninstall_ztoapi ;;
        3) show_address ;;
        0) exit 0 ;;
        *) warn "无效选项，请重新输入" ;;
    esac
done
