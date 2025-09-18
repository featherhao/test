#!/bin/bash

# 统一失败处理
trap 'status=$?; line=${BASH_LINENO[0]}; echo "❌ 发生错误 (exit=$status) at line $line" >&2; exit $status' ERR

# ================== 彩色与日志 ==================
if [[ -t 1 ]] && command -v tput &>/dev/null || true; then
    C_RESET="\e[0m"; C_BOLD="\e[1m"
    C_GREEN="\e[32m"; C_RED="\e[31m"; C_YELLOW="\e[33m"; C_BLUE="\e[34m"; C_CYAN="\e[36m"
else
    C_RESET=""; C_BOLD=""; C_GREEN=""; C_RED=""; C_YELLOW=""; C_BLUE=""; C_CYAN=""
fi

info()  { echo -e "${C_CYAN}[*]${C_RESET} $*"; }
warn()  { echo -e "${C_YELLOW}[!]${C_RESET} $*"; }
error() { echo -e "${C_RED}[x]${C_RESET} $*" >&2; }

print_header() {
    local title="$1"
    echo -e "${C_BOLD}==============================${C_RESET}"
    echo -e "  ${C_BOLD}${title}${C_RESET}"
    echo -e "${C_BOLD}==============================${C_RESET}"
}

render_menu() {
    local title="$1"; shift
    clear
    print_header "$title"
    local item
    for item in "$@"; do
        echo -e "$item"
    done
    echo "=============================="
}

fetch() {
    curl -fsSL --retry 3 --retry-delay 1 --connect-timeout 5 --max-time 30 "$@"
}

# ================== 核心功能 ==================
SINGBOX_SCRIPT="https://raw.githubusercontent.com/yonggekkk/sing-box-yg/main/sb.sh"

check_status() {
    if command -v sing-box &>/dev/null || command -v sb &>/dev/null; then
        if systemctl is-active --quiet sing-box; then
            echo -e "${C_GREEN}✅ 正在运行${C_RESET}"
        else
            echo -e "${C_YELLOW}⚠️ 已停止${C_RESET}"
        fi
    else
        echo -e "${C_RED}❌ 未安装${C_RESET}"
    fi
}

install_singbox() {
    info "⚡️ 正在安装甬哥 Sing-box-yg..."
    bash <(fetch "${SINGBOX_SCRIPT}")
    info "✅ 安装脚本执行完毕。"
    sleep 2
}

start_service() {
    info "🚀 正在启动 sing-box 服务..."
    sudo systemctl start sing-box
    sleep 2
    check_status
}

stop_service() {
    info "🛑 正在停止 sing-box 服务..."
    sudo systemctl stop sing-box
    sleep 2
    check_status
}

restart_service() {
    info "🔄 正在重启 sing-box 服务..."
    sudo systemctl restart sing-box
    sleep 2
    check_status
}

uninstall_singbox() {
    warn "⚠️ 正在卸载 sing-box。此操作不可逆，请谨慎操作。"
    read -rp "确定要继续吗？ (y/N): " confirm
    if [[ "$confirm" =~ ^[yY]$ ]]; then
        bash <(fetch "${SINGBOX_SCRIPT}") --remove
        info "✅ sing-box 已卸载。"
        sleep 2
    else
        info "操作已取消。"
        sleep 1
    fi
}

# ================== 主菜单 ==================
main_menu() {
    while true; do
        local status=$(check_status)
        render_menu "🚀 Sing-box-yg 服务管理" \
            "当前状态: $status" \
            "------------------------------" \
            "1) 安装 / 更新" \
            "2) 启动服务" \
            "3) 停止服务" \
            "4) 重启服务" \
            "5) 查看日志 (实时)" \
            "6) 卸载服务" \
            "0) 退出"

        read -rp "请输入选项: " choice

        case "${choice}" in
            1) install_singbox ;;
            2) start_service ;;
            3) stop_service ;;
            4) restart_service ;;
            5) sudo journalctl -u sing-box -f ;;
            6) uninstall_singbox ;;
            0) exit 0 ;;
            *) error "❌ 无效输入"; sleep 1 ;;
        esac
    done
}

# 脚本入口
main_menu