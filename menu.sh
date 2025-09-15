#!/bin/bash
set -Eeuo pipefail

# 统一失败处理
trap 'status=$?; line=${BASH_LINENO[0]}; echo "❌ 发生错误 (exit=$status) at line $line" >&2; exit $status' ERR

# ================== 基础配置 ==================
SCRIPT_URL="https://raw.githubusercontent.com/featherhao/test/refs/heads/main/menu.sh"
SCRIPT_PATH="$HOME/menu.sh"

# ================== 彩色与日志 ==================
# 优化：使用 || true 避免在严格模式下因 tput 不存在而导致的脚本退出
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

run_url() {
    bash <(fetch "$1")
}

# ================== 自我初始化与快捷键设置 ==================
# 标志位：判断脚本是否是首次通过 curl 方式运行
SCRIPT_IS_FIRST_RUN=false
if [[ "$0" == "/dev/fd/"* ]] || [[ "$0" == "bash" ]]; then
    info "⚡ 检测到你是通过 <(curl …) 临时运行的"
    info "👉 正在自动保存 menu.sh 到 $SCRIPT_PATH"
    curl -fsSL "${SCRIPT_URL}?t=$(date +%s)" -o "$SCRIPT_PATH"
    chmod +x "$SCRIPT_PATH"
    SCRIPT_IS_FIRST_RUN=true # 标记为首次运行
    sleep 2
fi

# 修复：智能设置快捷键，自动适配 Alpine 和其他系统
set_q_shortcut_auto() {
    local shell_rc=""
    local script_cmd="bash ~/menu.sh"

    if command -v apk &>/dev/null; then
        # 检测到 Alpine，使用 .profile 和 sh 命令
        shell_rc="$HOME/.profile"
        script_cmd="sh ~/menu.sh"
    elif [[ -n "${ZSH_VERSION:-}" ]]; then
        shell_rc="$HOME/.zshrc"
    else
        # 默认为 Ubuntu/Debian，使用 .bashrc 和 bash 命令
        shell_rc="$HOME/.bashrc"
    fi

    if ! grep -q "alias Q='${script_cmd}'" "$shell_rc" 2>/dev/null; then
        echo "alias Q='${script_cmd}'" >> "$shell_rc"
        echo "alias q='${script_cmd}'" >> "$shell_rc"
        
        # 只有在首次运行时才显示提示
        if $SCRIPT_IS_FIRST_RUN; then
            info "✅ 已自动设置快捷键，下次可直接输入 q 或 Q 运行。"
            info "👉 请执行 'source $shell_rc' 或重启终端以使其生效。"
        fi
    fi
}

set_q_shortcut_auto

# ================== docker compose 兼容 ==================
if command -v docker-compose &>/dev/null; then
    COMPOSE="docker-compose"
else
    COMPOSE="docker compose"
fi

# ================== 子脚本路径 ==================
WORKDIR_MOONTV="/opt/moontv"
MOONTV_SCRIPT="https://raw.githubusercontent.com/featherhao/test/refs/heads/main/SH/mootvinstall.sh"
WORKDIR_RUSTDESK="/opt/rustdesk"
RUSTDESK_SCRIPT="https://raw.githubusercontent.com/featherhao/test/refs/heads/main/SH/install_rustdesk.sh"
WORKDIR_LIBRETV="/opt/libretv"
LIBRETV_SCRIPT="https://raw.githubusercontent.com/featherhao/test/refs/heads/main/SH/install_libretv.sh"
ZJSYNC_SCRIPT="https://raw.githubusercontent.com/featherhao/test/refs/heads/main/SH/zjsync.sh"
NGINX_SCRIPT="https://raw.githubusercontent.com/featherhao/test/refs/heads/main/SH/nginx"
SUB_SCRIPT="https://raw.githubusercontent.com/featherhao/test/refs/heads/main/SH/subconverter-api.sh"
SHLINK_SCRIPT="https://raw.githubusercontent.com/featherhao/test/refs/heads/main/SH/install_shlink.sh"
ARGOSB_SCRIPT="https://raw.githubusercontent.com/featherhao/test/refs/heads/main/SH/argosb.sh"
PANSO_SCRIPT="https://raw.githubusercontent.com/featherhao/test/refs/heads/main/SH/pansou.sh"
POSTEIO_SCRIPT="https://raw.githubusercontent.com/featherhao/test/refs/heads/main/SH/Poste.io.sh"

# ================== 调用子脚本 ==================
moon_menu() { bash <(fetch "${MOONTV_SCRIPT}?t=$(date +%s)"); }
rustdesk_menu() { bash <(fetch "${RUSTDESK_SCRIPT}?t=$(date +%s)"); }
libretv_menu() { bash <(fetch "${LIBRETV_SCRIPT}?t=$(date +%s)"); }
singbox_menu() { bash <(fetch "https://raw.githubusercontent.com/yonggekkk/sing-box-yg/main/sb.sh"); }
nginx_menu() { bash <(fetch "${NGINX_SCRIPT}?t=$(date +%s)"); }
panso_menu() { bash <(fetch "${PANSO_SCRIPT}?t=$(date +%s)"); }
zjsync_menu() { bash <(fetch "${ZJSYNC_SCRIPT}?t=$(date +%s)"); }
subconverter_menu() { bash <(fetch "${SUB_SCRIPT}?t=$(date +%s)"); }
shlink_menu() { bash <(fetch "${SHLINK_SCRIPT}?t=$(date +%s)"); }
argosb_menu() { bash <(fetch "${ARGOSB_SCRIPT}?t=$(date +%s)"); }
posteio_menu() { bash <(fetch "${POSTEIO_SCRIPT}?t=$(date +%s)"); }

# ================== Docker 服务检查 ==================
check_docker_service() {
    local service_name="$1"
    if ! command -v docker &>/dev/null; then
        echo "❌ Docker 未安装"
        return
    fi
    
    if ! docker info &>/dev/null; then
        echo "❌ Docker 未运行"
        return
    fi
    
    if docker ps -a --format '{{.Names}}' | grep -q "^${service_name}$"; then
        if docker ps --format '{{.Names}}' | grep -q "^${service_name}$"; then
            echo "✅ 运行中"
        else
            echo "⚠️ 已停止"
        fi
    else
        echo "❌ 未安装"
    fi
}

# ================== 更新菜单脚本 ==================
update_menu_script() {
    info "🔄 正在更新 menu.sh..."
    fetch "${SCRIPT_URL}?t=$(date +%s)" -o "$SCRIPT_PATH"
    chmod +x "$SCRIPT_PATH"
    info "✅ menu.sh 已更新到 $SCRIPT_PATH"
    info "👉 以后可直接执行：bash ~/menu.sh"
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
    
    # 使用新的 Docker 服务检查函数
    panso_status=$(check_docker_service "pansou-web")
    zjsync_status=$([[ -f /etc/zjsync.conf ]] && echo "✅ 已配置" || echo "❌ 未配置")
    subconverter_status=$(check_docker_service "subconverter")
    shlink_status=$(check_docker_service "shlink")
    posteio_status=$(check_docker_service "posteio")
    
    kejilion_status="⚡ 远程调用"
    nginx_status="⚡ 远程调用"

    render_menu "🚀 服务管理中心" \
        "1) MoonTV 安装          $moon_status" \
        "2) RustDesk 安装        $rustdesk_status" \
        "3) LibreTV 安装         $libretv_status" \
        "4) 甬哥Sing-box-yg安装     $singbox_status" \
        "5) 勇哥ArgoSB脚本          $argosb_status" \
        "6) Kejilion.sh 一键脚本工具箱  $kejilion_status" \
        "7) zjsync（GitHub 文件自动同步）$zjsync_status" \
        "8) Pansou 网盘搜索         $panso_status" \
        "9) 域名绑定管理          $nginx_status" \
        "10) Subconverter- 订阅转换后端API   $subconverter_status" \
        "11) Poste.io 邮件服务器      $posteio_status" \
        "12) Shlink 短链接生成        $shlink_status" \
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
        00) update_menu_script ;;
        0) exit 0 ;;
        *) error "❌ 无效输入"; sleep 1 ;;
    esac
done