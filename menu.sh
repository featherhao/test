#!/bin/bash
set -Eeuo pipefail

# ================== 统一失败处理 ==================
trap 'status=$?; line=${BASH_LINENO[0]}; echo -e "\e[31m❌ 发生错误 (exit=$status) at line $line\e[0m" >&2' ERR

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

fetch() { curl -fsSL --retry 3 --retry-delay 1 --connect-timeout 5 --max-time 30 "$@"; }
run_url() { bash <(fetch "$1"); }

# ================== 自我初始化 ==================
SCRIPT_IS_FIRST_RUN=false
if [[ "$0" == "/dev/fd/"* ]] || [[ "$0" == "bash" ]]; then
    info "⚡ 检测到你是通过 <(curl …) 临时运行的"
    info "👉 正在自动保存 menu.sh 到 $SCRIPT_PATH"
    curl -fsSL "${SCRIPT_URL}?t=$(date +%s)" -o "$SCRIPT_PATH"
    chmod +x "$SCRIPT_PATH"
    SCRIPT_IS_FIRST_RUN=true
    sleep 2
fi

# ================== 快捷键 q/Q ==================
set_q_shortcut_auto() {
    local shell_rc=""
    local script_cmd="bash ~/menu.sh"

    if command -v apk &>/dev/null; then
        shell_rc="$HOME/.profile"
        script_cmd="sh ~/menu.sh"
    elif [[ -n "${ZSH_VERSION:-}" ]]; then
        shell_rc="$HOME/.zshrc"
    else
        shell_rc="$HOME/.bashrc"
    fi

    if ! grep -q "alias Q='${script_cmd}'" "$shell_rc" 2>/dev/null; then
        echo "alias Q='${script_cmd}'" >> "$shell_rc"
        echo "alias q='${script_cmd}'" >> "$shell_rc"
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
WORKDIR_SEARXNG="/opt/searxng"
SEARXNG_SCRIPT="https://raw.githubusercontent.com/featherhao/test/refs/heads/main/SH/searxng.sh"
MTPROTO_SCRIPT="https://raw.githubusercontent.com/featherhao/test/refs/heads/main/SH/MTProto.sh"
SYSTEM_TOOL_SCRIPT="https://raw.githubusercontent.com/featherhao/test/refs/heads/main/SH/system_tool.sh"
CLEAN_VPS_SCRIPT="https://raw.githubusercontent.com/featherhao/test/refs/heads/main/SH/clean_vps.sh"
COSYVOICE_SCRIPT="https://raw.githubusercontent.com/featherhao/test/refs/heads/main/SH/cosyvoice.sh"

# ================== 子脚本调用函数（报错不退出） ==================
moon_menu()        { bash <(fetch "${MOONTV_SCRIPT}?t=$(date +%s)") || warn "MoonTV 子脚本报错，但已忽略"; }
rustdesk_menu()    { bash <(fetch "${RUSTDESK_SCRIPT}?t=$(date +%s)") || warn "RustDesk 子脚本报错，但已忽略"; }
libretv_menu()     { bash <(fetch "${LIBRETV_SCRIPT}?t=$(date +%s)") || warn "LibreTV 子脚本报错，但已忽略"; }
singbox_menu()     { bash <(fetch "https://raw.githubusercontent.com/yonggekkk/sing-box-yg/main/sb.sh") || warn "Sing-box 子脚本报错，但已忽略"; }
nginx_menu()       { bash <(fetch "${NGINX_SCRIPT}?t=$(date +%s)") || warn "Nginx 子脚本报错，但已忽略"; }
panso_menu()       { bash <(fetch "${PANSO_SCRIPT}?t=$(date +%s)") || warn "Pansou 子脚本报错，但已忽略"; }
zjsync_menu()      { bash <(fetch "${ZJSYNC_SCRIPT}?t=$(date +%s)") || warn "zjsync 子脚本报错，但已忽略"; }
subconverter_menu(){ bash <(fetch "${SUB_SCRIPT}?t=$(date +%s)") || warn "Subconverter 子脚本报错，但已忽略"; }
shlink_menu()      { bash <(fetch "${SHLINK_SCRIPT}?t=$(date +%s)") || warn "Shlink 子脚本报错，但已忽略"; }
argosb_menu()      { bash <(fetch "${ARGOSB_SCRIPT}?t=$(date +%s)") || warn "ArgoSB 子脚本报错，但已忽略"; }
posteio_menu()     { bash <(fetch "${POSTEIO_SCRIPT}?t=$(date +%s)") || warn "Poste.io 子脚本报错，但已忽略"; }
searxng_menu()     { bash <(fetch "${SEARXNG_SCRIPT}?t=$(date +%s)") || warn "SearxNG 子脚本报错，但已忽略"; }
mtproto_menu()     { bash <(fetch "${MTPROTO_SCRIPT}?t=$(date +%s)") || warn "MTProto 子脚本报错，但已忽略"; }
system_tool_menu(){ bash <(fetch "${SYSTEM_TOOL_SCRIPT}?t=$(date +%s)") || warn "系统工具子脚本报错，但已忽略"; }
cosyvoice_menu()   { bash <(fetch "${COSYVOICE_SCRIPT}?t=$(date +%s)") || warn "CosyVoice 子脚本报错，但已忽略"; }

# ================== 主菜单循环 ==================
while true; do
    # 状态检测
    moon_status=$([[ -d /opt/moontv ]] && echo "${C_GREEN}✅ 已安装${C_RESET}" || echo "❌ 未安装")
    rustdesk_status=$([[ -d /opt/rustdesk ]] && echo "${C_GREEN}✅ 已安装${C_RESET}" || echo "❌ 未安装")
    libretv_status=$([[ -d /opt/libretv ]] && echo "${C_GREEN}✅ 已安装${C_RESET}" || echo "❌ 未安装")
    singbox_status=$([[ -x "$(command -v sing-box)" || -x "$(command -v sb)" ]] && echo "${C_GREEN}✅ 已安装${C_RESET}" || echo "❌ 未安装")

    argosb_status=$([[ -f "/opt/argosb/installed.flag" ]] && echo "✅ 已安装 (标记文件)" || echo "❌ 未安装")
    panso_status=$(check_docker_service "pansou-web")
    zjsync_status=$([[ -f /etc/zjsync.conf ]] && echo "${C_GREEN}✅ 已配置${C_RESET}" || echo "❌ 未配置")
    subconverter_status=$(check_docker_service "subconverter")
    shlink_status=$(check_docker_service "shlink")
    posteio_status=$(check_docker_service "posteio")
    searxng_status=$(check_docker_service "searxng")

    render_menu "🚀 服务管理中心" \
        "1) MoonTV 安装                 $moon_status" \
        "2) RustDesk 安装               $rustdesk_status" \
        "3) LibreTV 安装                $libretv_status" \
        "4) 甬哥Sing-box-yg安装           $singbox_status" \
        "5) 勇哥ArgoSB脚本                $argosb_status" \
        "6) Kejilion.sh 一键脚本工具箱     ⚡ 远程调用" \
        "7) zjsync（GitHub 文件自动同步）   $zjsync_status" \
        "8) Pansou 网盘搜索               $panso_status" \
        "9) 域名绑定管理                  ⚡ 远程调用" \
        "10) Subconverter API后端         $subconverter_status" \
        "11) Poste.io 邮件服务器          $posteio_status" \
        "12) Shlink 短链接生成            $shlink_status" \
        "13) SearxNG 一键安装/卸载        $searxng_status" \
        "14) Telegram MTProto 代理         $(mtproto_status)" \
        "15) CosyVoice 文本转语音          $(check_docker_service "cov")" \
        "16) 系统工具（Swap 管理 + 主机名修改） ⚡" \
        "00) 更新菜单脚本 menu.sh" \
        "0) 退出" \
        "" \
        "提示：此脚本已自动设置 q 或 Q 快捷键，下次直接输入即可运行"

    read -rp "请输入选项: " main_choice
    case "${main_choice}" in
        1) moon_menu ;;
        2) rustdesk_menu ;;
        3) libretv_menu ;;
        4) singbox_menu ;;
        5) argosb_menu ;;
        6) bash <(fetch "https://raw.githubusercontent.com/kejilion/sh/main/kejilion.sh") || warn "远程工具报错";;
        7) zjsync_menu ;;
        8) panso_menu ;;
        9) nginx_menu ;;
        10) subconverter_menu ;;
        11) posteio_menu ;;
        12) shlink_menu ;;
        13) searxng_menu ;;
        14) mtproto_menu ;;
        15) cosyvoice_menu ;;
        16) system_tool_menu ;;
        00) update_menu_script ;;
        0) exit 0 ;;
        *) error "❌ 无效输入" ;;
    esac
    read -rp "按回车返回主菜单…"  # 等待用户确认再刷新
done
