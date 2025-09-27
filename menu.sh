#!/bin/bash
set -Eeuo pipefail

# ================== 统一失败处理 ==================
trap 'status=$?; line=${BASH_LINENO[0]}; echo "❌ 发生错误 (exit=$status) at line $line" >&2; exit $status' ERR

# ================== 基础配置 ==================
SCRIPT_URL="https://raw.githubusercontent.com/featherhao/test/refs/heads/main/menu.sh"
SCRIPT_PATH="$HOME/menu.sh"

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
    for item in "$@"; do
        echo -e "$item"
    done
    echo "=============================="
}

fetch() {
    curl -fsSL --retry 3 --retry-delay 1 --connect-timeout 5 --max-time 30 "$@"
}

# ================== 子脚本路径 ==================
SYSTEM_TOOL_SCRIPT="https://raw.githubusercontent.com/featherhao/test/refs/heads/main/SH/system_tool.sh"

# ================== 调用子脚本 ==================
moon_menu() { bash <(fetch "${MOONTV_SCRIPT}?t=$(date +%s)"); }
rustdesk_menu() { bash <(fetch "${RUSTDESK_SCRIPT}?t=$(date +%s)"); }
libretv_menu() { bash <(fetch "${LIBRETV_SCRIPT}?t=$(date +%s)"); }
singbox_menu() { bash <(fetch "https://raw.githubusercontent.com/yonggekkk/sing-box-yg/main/sb.sh"); read -rp "按任意键返回主菜单..."; }
nginx_menu() { bash <(fetch "${NGINX_SCRIPT}?t=$(date +%s)"); }
panso_menu() { bash <(fetch "${PANSO_SCRIPT}?t=$(date +%s)"); }
zjsync_menu() { bash <(fetch "${ZJSYNC_SCRIPT}?t=$(date +%s)"); }
subconverter_menu() { bash <(fetch "${SUB_SCRIPT}?t=$(date +%s)"); }
shlink_menu() { bash <(fetch "${SHLINK_SCRIPT}?t=$(date +%s)"); }
argosb_menu() { bash <(fetch "${ARGOSB_SCRIPT}?t=$(date +%s)"); }
posteio_menu() { bash <(fetch "${POSTEIO_SCRIPT}?t=$(date +%s)"); }
searxng_menu() { bash <(fetch "${SEARXNG_SCRIPT}?t=$(date +%s)"); }
mtproto_menu() { bash <(fetch "${MTPROTO_SCRIPT}?t=$(date +%s)"); read -rp "按任意键返回主菜单..."; }
system_tool_menu() { bash <(fetch "${SYSTEM_TOOL_SCRIPT}?t=$(date +%s)"); read -rp "按任意键返回主菜单..."; }

# ================== 主菜单 ==================
while true; do
    [[ -d /opt/moontv ]] && moon_status="✅ 已安装" || moon_status="❌ 未安装"
    [[ -d /opt/rustdesk ]] && rustdesk_status="✅ 已安装" || rustdesk_status="❌ 未安装"
    [[ -d /opt/libretv ]] && libretv_status="✅ 已安装" || libretv_status="❌ 未安装"
    if command -v sing-box &>/dev/null || command -v sb &>/dev/null; then
        singbox_status="✅ 已安装"
    else
        singbox_status="❌ 未安装"
    fi
    argosb_status=$(argosb_status_check)
    panso_status=$(check_docker_service "pansou-web")
    zjsync_status=$([[ -f /etc/zjsync.conf ]] && echo "✅ 已配置" || echo "❌ 未配置")
    subconverter_status=$(check_docker_service "subconverter")
    shlink_status=$(check_docker_service "shlink")
    posteio_status=$(check_docker_service "posteio")
    searxng_status=$(check_docker_service "searxng")
    kejilion_status="⚡ 远程调用"

    render_menu "🚀 服务管理中心" \
        "1) MoonTV 安装                 $moon_status" \
        "2) RustDesk 安装               $rustdesk_status" \
        "3) LibreTV 安装                $libretv_status" \
        "4) 甬哥Sing-box-yg安装           $singbox_status" \
        "5) 勇哥ArgoSB脚本                $argosb_status" \
        "6) Kejilion.sh 一键脚本工具箱     $kejilion_status" \
        "7) zjsync（GitHub 文件自动同步）   $zjsync_status" \
        "8) Pansou 网盘搜索               $panso_status" \
        "9) 域名绑定管理                  ⚡ 远程调用" \
        "10) Subconverter- 订阅转换后端API $subconverter_status" \
        "11) Poste.io 邮件服务器          $posteio_status" \
        "12) Shlink 短链接生成            $shlink_status" \
        "13) SearxNG 一键安装/更新/卸载    $searxng_status" \
        "14) Telegram MTProto 代理         $(mtproto_status)" \
        "15) 系统工具（Swap/主机名/VPS清理） ⚡" \
        "00) 更新菜单脚本 menu.sh" \
        "0) 退出" \
        "" \
        "快捷键提示：此脚本已自动设置 q 或 Q 为快捷键，首次安装重启终端其生效"

    read -rp "请输入选项: " main_choice

    case "${main_choice}" in
        1) moon_menu ;;
        2) rustdesk_menu ;;
        3) libretv_menu ;;
        4) singbox_menu ;;
        5) argosb_menu ;;
        6) bash <(fetch "https://raw.githubusercontent.com/kejilion/sh/main/kejilion.sh") ;;
        7) zjsync_menu ;;
        8) panso_menu ;;
        9) nginx_menu ;;
        10) subconverter_menu ;;
        11) posteio_menu ;;
        12) shlink_menu ;;
        13) searxng_menu ;;
        14) mtproto_menu ;;
        15) system_tool_menu ;;
        00) update_menu_script ;;
        0) exit 0 ;;
        *) error "❌ 无效输入"; sleep 1 ;;
    esac
done
