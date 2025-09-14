#!/bin/bash
set -Eeuo pipefail

# 统一失败处理
trap 'status=$?; line=${BASH_LINENO[0]}; echo "❌ 发生错误 (exit=$status) at line $line" >&2; exit $status' ERR

# ================== 基础配置 ==================
# menu.sh 自身的 URL
readonly SCRIPT_URL="https://raw.githubusercontent.com/featherhao/test/refs/heads/main/menu.sh"
readonly SCRIPT_PATH="$HOME/menu.sh"

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

# ================== 核心函数 ==================
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

# 统一的 fetch 函数，带有重试和超时逻辑
fetch() {
    curl -fsSL --retry 3 --retry-delay 1 --connect-timeout 5 --max-time 30 "$1"
}

# 动态调用子脚本
run_remote_script() {
    local script_url="$1"
    info "正在加载并执行 $script_url..."
    fetch "$script_url?t=$(date +%s)" | bash
}

# ================== 自我初始化逻辑 ==================
if [[ "$0" == "/dev/fd/"* ]] || [[ "$0" == "bash" ]]; then
    echo "⚡ 检测到你是通过 <(curl ...) 临时运行的"
    echo "👉 正在自动保存 menu.sh 到 $SCRIPT_PATH"
    fetch "${SCRIPT_URL}" -o "$SCRIPT_PATH"
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

# ================== 子脚本 URL (已统一目录) ==================
readonly SUB_SCRIPT_BASE="https://raw.githubusercontent.com/featherhao/test/refs/heads/main/SH"
readonly MOONTV_SCRIPT="$SUB_SCRIPT_BASE/mootvinstall.sh"
readonly RUSTDESK_SCRIPT="$SUB_SCRIPT_BASE/install_rustdesk.sh"
readonly LIBRETV_SCRIPT="$SUB_SCRIPT_BASE/install_libretv.sh"
readonly ZJSYNC_SCRIPT="$SUB_SCRIPT_BASE/zjsync.sh"
readonly NGINX_SCRIPT="$SUB_SCRIPT_BASE/nginx"
readonly SUB_SCRIPT="$SUB_SCRIPT_BASE/subconverter-api.sh"
readonly PANSO_SCRIPT="$SUB_SCRIPT_BASE/pansou.sh"
readonly ARGOSB_SCRIPT="$SUB_SCRIPT_BASE/argosb.sh"
readonly POSTEIO_SCRIPT="$SUB_SCRIPT_BASE/Poste.io.sh"
readonly SHLINK_SCRIPT="$SUB_SCRIPT_BASE/install_shlink.sh"
readonly KEJILION_SCRIPT="https://raw.githubusercontent.com/kejilion/sh/main/kejilion.sh"
readonly SINGBOX_SCRIPT="https://raw.githubusercontent.com/yonggekkk/sing-box-yg/main/sb.sh"

# ================== 调用子脚本函数 (使用新函数) ==================
moon_menu() { run_remote_script "$MOONTV_SCRIPT"; }
rustdesk_menu() { run_remote_script "$RUSTDESK_SCRIPT"; }
libretv_menu() { run_remote_script "$LIBRETV_SCRIPT"; }
singbox_menu() { run_remote_script "$SINGBOX_SCRIPT"; }
nginx_menu() { run_remote_script "$NGINX_SCRIPT"; }
panso_menu() { run_remote_script "$PANSO_SCRIPT"; }
zjsync_menu() { run_remote_script "$ZJSYNC_SCRIPT"; }
subconverter_menu() { run_remote_script "$SUB_SCRIPT"; }
argosb_menu() { run_remote_script "$ARGOSB_SCRIPT"; }
posteio_menu() { run_remote_script "$POSTEIO_SCRIPT"; }
shlink_menu() { run_remote_script "$SHLINK_SCRIPT"; }
kejilion_menu() { run_remote_script "$KEJILION_SCRIPT"; }


# ================== 更新菜单脚本 ==================
update_menu_script() {
    info "正在更新 menu.sh..."
    fetch "${SCRIPT_URL}?t=$(date +%s)" -o "$SCRIPT_PATH"
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
    # 确保以下所有行都没有 'local'
    moon_status="❌ 未安装"; [[ -d /opt/moontv ]] && moon_status="✅ 已安装"
    rustdesk_status="❌ 未安装"; [[ -d /opt/rustdesk ]] && rustdesk_status="✅ 已安装"
    libretv_status="❌ 未安装"; [[ -d /opt/libretv ]] && libretv_status="✅ 已安装"
    singbox_status="❌ 未安装"; command -v sing-box &>/dev/null || command -v sb &>/dev/null && singbox_status="✅ 已安装"
    argosb_status="❌ 未安装"; command -v agsb &>/dev/null || [[ -f /etc/opt/ArgoSB/config.json ]] && argosb_status="✅ 已安装"
    panso_status="❌ 未安装"; docker ps -a --format '{{.Names}}' | grep -q "^pansou-web$" && panso_status="✅ 已安装"
    zjsync_status="❌ 未配置"; [[ -f /etc/zjsync.conf ]] && zjsync_status="✅ 已配置"
    subconverter_status="❌ 未运行"; docker ps -a --filter "name=subconverter" --format "{{.Status}}" | grep -q "Up" && subconverter_status="✅ 运行中"
    
    posteio_status="❌ 未安装"; docker ps -a --filter "name=posteio" --format "{{.Status}}" | grep -q "Up" && posteio_status="✅ 运行中"
    shlink_status="❌ 未安装"; docker ps -a --filter "name=shlink_web" --format "{{.Status}}" | grep -q "Up" && shlink_status="✅ 运行中"

    kejilion_status="⚡ 远程调用"
    nginx_status="⚡ 远程调用"

    render_menu "🚀 服务管理中心" \
        "1) MoonTV 安装             $moon_status" \
        "2) RustDesk 安装          $rustdesk_status" \
        "3) LibreTV 安装           $libretv_status" \
        "4) 甬哥Sing-box-yg安装    $singbox_status" \
        "5) 勇哥ArgoSB脚本         $argosb_status" \
        "6) Kejilion.sh 一键脚本工具箱 $kejilion_status" \
        "7) zjsync（GitHub 文件自动同步）$zjsync_status" \
        "8) Pansou 网盘搜索        $panso_status" \
        "9) 域名绑定管理           $nginx_status" \
        "10) Subconverter- 订阅转换后端API $subconverter_status" \
        "11) Poste.io 邮件服务器      $posteio_status" \
        "12) Shlink 短链接生成      $shlink_status" \
        "13) 设置快捷键 Q / q" \
        "U) 更新菜单脚本 menu.sh" \
        "0) 退出"

    read -rp "请输入选项: " main_choice

    case "${main_choice^^}" in
        1) moon_menu ;;
        2) rustdesk_menu ;;
        3) libretv_menu ;;
        4) singbox_menu ;;
        5) argosb_menu ;;
        6) kejilion_menu ;;
        7) zjsync_menu ;;
        8) panso_menu ;;
        9) nginx_menu ;;
        10) subconverter_menu ;;
        11) posteio_menu ;;
        12) shlink_menu ;;
        13) set_q_shortcut ;;
        U) update_menu_script ;;
        0) exit 0 ;;
        *) echo "❌ 无效输入"; sleep 1 ;;
    esac
done