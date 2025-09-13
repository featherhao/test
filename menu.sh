#!/bin/bash
set -Eeuo pipefail

# 统一失败处理
trap 'status=$?; line=${BASH_LINENO[0]}; echo "❌ 发生错误 (exit=$status) at line $line" >&2; exit $status' ERR

# ================== 基础配置 ==================
# menu.sh 自身的 URL 保持不变，因为它还在根目录
SCRIPT_URL="https://raw.githubusercontent.com/featherhao/test/refs/heads/main/menu.sh"
SCRIPT_PATH="$HOME/menu.sh"

# ================== 彩色与日志 ==================
if [[ -t 1 ]] && command -v tput &>/dev/null; then
    C_RESET="\e[0m"; C_BOLD="\e[1m"
    C_GREEN="\e[32m"; C_RED="\e[31m"; C_YELLOW="\e[33m"; C_BLUE="\e[34m"; C_CYAN="\e[36m"
else
    C_RESET=""; C_BOLD=""; C_GREEN=""; C_RED=""; C_YELLOW=""; C_BLUE=""; C_CYAN=""
fi

info()  { echo -e "${C_CYAN}[*]${C_RESET} $*"; }
warn()  { echo -e "${C_YELLOW}[!]${C_RESET} $*"; }
error() { echo -e "${C_RED}[x]${C_RESET} $*"; }

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

run_url() {
    bash <(fetch "$1")
}

# ================== 自我初始化逻辑 ==================
if [[ "$0" == "/dev/fd/"* ]] || [[ "$0" == "bash" ]]; then
    echo "⚡ 检测到你是通过 <(curl …) 临时运行的"
    echo "👉 正在自动保存 menu.sh 到 $SCRIPT_PATH"
    curl -fsSL "${SCRIPT_URL}?t=$(date +%s)" -o "$SCRIPT_PATH"
    chmod +x "$SCRIPT_PATH"
    echo "✅ 已保存，下次可直接执行：bash ~/menu.sh"
    sleep 2
fi

# ================== docker compose 兼容 ==================
if command -v docker-compose &>/dev/null; then
    COMPOSE="docker-compose"
else
    COMPOSE="docker compose"
fi

# ================== 子脚本路径 (已更新为 SH 目录) ==================
WORKDIR_MOONTV="/opt/moontv"
MOONTV_SCRIPT="https://raw.githubusercontent.com/featherhao/test/refs/heads/main/SH/mootvinstall.sh"
WORKDIR_RUSTDESK="/opt/rustdesk"
RUSTDESK_SCRIPT="https://raw.githubusercontent.com/featherhao/test/refs/heads/main/SH/install_rustdesk.sh"
WORKDIR_LIBRETV="/opt/libretv"
LIBRETV_SCRIPT="https://raw.githubusercontent.com/featherhao/test/refs/heads/main/SH/install_libretv.sh"
ZJSYNC_SCRIPT="https://raw.githubusercontent.com/featherhao/test/refs/heads/main/SH/zjsync.sh"
NGINX_SCRIPT="https://raw.githubusercontent.com/featherhao/test/refs/heads/main/SH/nginx"
SUB_SCRIPT="https://raw.githubusercontent.com/featherhao/test/refs/heads/main/SH/subconverter-api.sh"
SHLINK_SCRIPT="https://raw.githubusercontent.com/featherhao/test/refs/heads/main/SH/shlink.sh"
ARGOSB_SCRIPT="https://raw.githubusercontent.com/featherhao/test/refs/heads/main/SH/argosb.sh"
PANSO_SCRIPT="https://raw.githubusercontent.com/featherhao/test/refs/heads/main/SH/pansou.sh"

# ================== 调用子脚本 (已更新为 SH 目录) ==================
moon_menu() { bash <(curl -fsSL --retry 3 --retry-delay 1 --connect-timeout 5 --max-time 30 "${MOONTV_SCRIPT}?t=$(date +%s)"); }
rustdesk_menu() { bash <(curl -fsSL --retry 3 --retry-delay 1 --connect-timeout 5 --max-time 30 "${RUSTDESK_SCRIPT}?t=$(date +%s)"); }
libretv_menu() { bash <(curl -fsSL --retry 3 --retry-delay 1 --connect-timeout 5 --max-time 30 "${LIBRETV_SCRIPT}?t=$(date +%s)"); }
singbox_menu() { bash <(curl -fsSL --retry 3 --retry-delay 1 --connect-timeout 5 --max-time 30 https://raw.githubusercontent.com/yonggekkk/sing-box-yg/main/sb.sh); }
nginx_menu() { bash <(curl -fsSL --retry 3 --retry-delay 1 --connect-timeout 5 --max-time 30 "${NGINX_SCRIPT}?t=$(date +%s)"); }
panso_menu() {
    bash <(curl -fsSL --retry 3 --retry-delay 1 --connect-timeout 5 --max-time 30 "${PANSO_SCRIPT}?t=$(date +%s)")
}
zjsync_menu() {
    bash <(curl -fsSL --retry 3 --retry-delay 1 --connect-timeout 5 --max-time 30 "${ZJSYNC_SCRIPT}?t=$(date +%s)")
}
subconverter_menu() {
    bash <(curl -fsSL --retry 3 --retry-delay 1 --connect-timeout 5 --max-time 30 "${SUB_SCRIPT}?t=$(date +%s)")
}
shlink_menu() {
    bash <(curl -fsSL --retry 3 --retry-delay 1 --connect-timeout 5 --max-time 30 "${SHLINK_SCRIPT}?t=$(date +%s)")
}
argosb_menu() { bash <(curl -fsSL --retry 3 --retry-delay 1 --connect-timeout 5 --max-time 30 "${ARGOSB_SCRIPT}?t=$(date +%s)"); }

# ================== 更新菜单脚本 ==================
update_menu_script() {
    echo "🔄 正在更新 menu.sh..."
    curl -fsSL --retry 3 --retry-delay 1 --connect-timeout 5 --max-time 30 "${SCRIPT_URL}?t=$(date +%s)" -o "$SCRIPT_PATH"
    chmod +x "$SCRIPT_PATH"
    echo "✅ menu.sh 已更新到 $SCRIPT_PATH"
    echo "👉 以后可直接执行：bash ~/menu.sh"
    sleep 2
}

# ================== 设置快捷键 Q/q ==================
set_q_shortcut() {
    SHELL_RC="$HOME/.bashrc"
    [ -n "$ZSH_VERSION" ] && SHELL_RC="$HOME/.zshrc"
    sed -i '/alias Q=/d' "$SHELL_RC"
    sed -i '/alias q=/d' "$SHELL_RC"
    echo "alias Q='bash ~/menu.sh'" >> "$SHELL_RC"
    echo "alias q='bash ~/menu.sh'" >> "$SHELL_RC"
    echo "⚡ 请执行 'source $SHELL_RC' 或重启终端生效"
    sleep 2
}

# ================== 主菜单 ==================
while true; do
    # 动态检测安装状态
    [[ -d /opt/moontv ]] && moon_status="✅ 已安装" || moon_status="❌ 未安装"
    [[ -d /opt/rustdesk ]] && rustdesk_status="✅ 已安装" || rustdesk_status="❌ 未安装"
    [[ -d /opt/libretv ]] && libretv_status="✅ 已安装" || libretv_status="❌ 未安装"
    if command -v sing-box &>/dev/null || command -v sb &>/dev/null; then
        singbox_status="✅ 已安装"
    else
        singbox_status="❌ 未安装"
    fi
    if command -v agsb &>/dev/null || [[ -f /etc/opt/ArgoSB/config.json ]]; then
        argosb_status="✅ 已安装"
    else
        argosb_status="❌ 未安装"
    fi
    if docker ps -a --format '{{.Names}}' | grep -q "^pansou-web$"; then
        panso_status="✅ 已安装"
    else
        panso_status="❌ 未安装"
    fi
    if [[ -f /etc/zjsync.conf ]]; then
        zjsync_status="✅ 已配置"
    else
        zjsync_status="❌ 未配置"
    fi
    if docker ps -a --filter "name=subconverter" --format "{{.Status}}" | grep -q "Up"; then
        subconverter_status="✅ 运行中"
    else
        subconverter_status="❌ 未运行"
    fi
    
    # 移除 Shlink 状态检测
    # if docker ps -a --format '{{.Names}}' | grep -q 'shlink'; then
    #    shlink_status="✅ 已安装"
    # else
    #    shlink_status="❌ 未安装"
    # fi

    kejilion_status="⚡ 远程调用"
    nginx_status="⚡ 远程调用"

    render_menu "🚀 服务管理中心" \
        "1) MoonTV 安装             $moon_status" \
        "2) RustDesk 安装            $rustdesk_status" \
        "3) LibreTV 安装             $libretv_status" \
        "4) 甬哥Sing-box-yg安装      $singbox_status" \
        "5) 勇哥ArgoSB脚本           $argosb_status" \
        "6) Kejilion.sh 一键脚本工具箱 $kejilion_status" \
        "7) zjsync（GitHub 文件自动同步）$zjsync_status" \
        "8) Pansou 网盘搜索          $panso_status" \
        "9) 域名绑定管理             $nginx_status" \
        "10) Subconverter- 订阅转换后端API $subconverter_status" \
        "11) 设置快捷键 Q / q" \
        "U) 更新菜单脚本 menu.sh" \
        "0) 退出"
    read -rp "请输入选项: " main_choice

    case "${main_choice^^}" in
        1) moon_menu ;;
        2) rustdesk_menu ;;
        3) libretv_menu ;;
        4) singbox_menu ;;
        5) argosb_menu ;;
        # 修复：使用官方推荐的完整 URL
        6) bash <(curl -fsSL --retry 3 --retry-delay 1 --connect-timeout 5 --max-time 30 https://raw.githubusercontent.com/kejilion/sh/main/kejilion.sh) ;;
        7) zjsync_menu ;;
        8) panso_menu ;;
        9) nginx_menu ;;
        10) subconverter_menu ;;
        11) set_q_shortcut ;;
        U) update_menu_script ;;
        0) exit 0 ;;
        *) echo "❌ 无效输入"; sleep 1 ;;
    esac
done