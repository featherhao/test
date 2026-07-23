#!/bin/bash
set -Eeuo pipefail

# ================== 统一失败处理 ==================
trap 'status=$?; line=${BASH_LINENO[0]}; echo "❌ 发生错误 (exit=$status) at line $line" >&2; exit $status' ERR

# ================== 基础配置 ==================
SCRIPT_URL="https://raw.githubusercontent.com/featherhao/test/refs/heads/main/menu.sh"
SCRIPT_PATH="$HOME/menu.sh"
CASAOS_INSTALL_URL="https://get.casaos.io"
PROXY_URL="https://js.52zy.eu.org/"

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

# ================== 自动化网络检测与智能拉取 ==================
GH_PREFIX=""
DOCKER_PROXY=""

check_network() {
    info "📡 正在检测网络与 Docker 镜像仓就绪状态..."
    
    local is_overseas=false
    if curl -I -s --connect-timeout 1.5 "https://www.google.com" &>/dev/null; then
        is_overseas=true
    fi

    local docker_check
    docker_check=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 2 "https://auth.docker.io/token?service=registry.docker.io" || echo "000")

    if $is_overseas; then
        GH_PREFIX=""
        if [[ "$docker_check" == "401" || "$docker_check" == "200" ]]; then
            info "🌐 网络检测结果：${C_GREEN}海外直连环境，且 Docker 官方仓正常就绪。${C_RESET}"
            DOCKER_PROXY=""
        else
            warn "⚠️ 网络检测结果：海外环境，但检测到 Docker Hub 官方对当前 IP 存在限流或拉取阻断！"
            DOCKER_PROXY="docker.m.daocloud.io"
        fi
    else
        if curl -I -s --connect-timeout 2 "${PROXY_URL}" &>/dev/null; then
            info "🚀 网络检测结果：${C_GREEN}当前处于国内环境，已切换至 GHProxy 加速。${C_RESET}"
            GH_PREFIX="${PROXY_URL}"
            DOCKER_PROXY="docker.m.daocloud.io"
        else
            GH_PREFIX=""
            DOCKER_PROXY=""
        fi
    fi
}
check_network

fetch() { 
    local target_url="$1"
    shift
    if [[ -n "$GH_PREFIX" ]] && [[ "$target_url" =~ "github" ]] && [[ ! "$target_url" =~ "$PROXY_URL" ]]; then
        target_url="${GH_PREFIX}${target_url}"
    fi
    curl -fsSL --retry 3 --retry-delay 1 --connect-timeout 5 --max-time 30 "$@" "$target_url"
}

docker() {
    local cmd="$1"
    if [[ "$cmd" == "run" || "$cmd" == "pull" ]]; then
        local args=()
        local current_proxy="${DOCKER_PROXY:-}"
        for arg in "$@"; do
            if [[ -n "$current_proxy" ]] && [[ ! "$arg" =~ ^- ]] && [[ "$arg" =~ [a-zA-Z0-9_/-]+:[a-zA-Z0-9_.-]+ || "$arg" =~ [a-zA-Z0-9_/-]+$ ]] && [[ "$arg" != "$cmd" ]]; then
                if [[ ! "$arg" =~ "/" ]] && [[ ! "$arg" =~ "$current_proxy" ]]; then
                    arg="${current_proxy}/library/${arg}"
                elif [[ ! "$arg" =~ "$current_proxy" && ! "$arg" =~ "ghcr.io" && ! "$arg" =~ "quay.io" ]]; then
                    arg="${current_proxy}/${arg}"
                fi
            fi
            args+=("$arg")
        done
        command docker "${args[@]}"
    else
        command docker "$@"
    fi
}
export -f docker

# ================== 子脚本路径 ==================
FILEBROWSER_SCRIPT="https://raw.githubusercontent.com/featherhao/test/refs/heads/main/SH/fb.sh"
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
PANHUB_SCRIPT="https://raw.githubusercontent.com/featherhao/test/refs/heads/main/SH/panhub.sh"
POSTEIO_SCRIPT="https://raw.githubusercontent.com/featherhao/test/refs/heads/main/SH/Poste.io.sh"
WORKDIR_SEARXNG="/opt/searxng"
SEARXNG_SCRIPT="https://raw.githubusercontent.com/featherhao/test/refs/heads/main/SH/searxng.sh"
MTPROTO_SCRIPT="https://raw.githubusercontent.com/featherhao/test/refs/heads/main/SH/MTProto.sh"
SYSTEM_TOOL_SCRIPT="https://raw.githubusercontent.com/featherhao/test/refs/heads/main/SH/system_tool.sh"
CLEAN_VPS_SCRIPT="https://raw.githubusercontent.com/featherhao/test/refs/heads/main/SH/clean_vps.sh"
COSYVOICE_SCRIPT="https://raw.githubusercontent.com/featherhao/test/refs/heads/main/SH/cosyvoice.sh"
CFST_SCRIPT="https://raw.githubusercontent.com/featherhao/test/refs/heads/main/SH/cfst.sh"
TAILSCALE_SCRIPT="https://raw.githubusercontent.com/featherhao/test/refs/heads/main/SH/Tailscale"

# ================== 子脚本调用函数 ==================
filebrowser_menu() { bash <(fetch "${FILEBROWSER_SCRIPT}?t=$(date +%s)"); }
moon_menu() { bash <(fetch "${MOONTV_SCRIPT}?t=$(date +%s)"); }
rustdesk_menu() { bash <(fetch "${RUSTDESK_SCRIPT}?t=$(date +%s)"); }
libretv_menu() { bash <(fetch "${LIBRETV_SCRIPT}?t=$(date +%s)"); }
singbox_menu() { bash <(fetch "https://raw.githubusercontent.com/yonggekkk/sing-box-yg/main/sb.sh"); }
nginx_menu() { bash <(fetch "${NGINX_SCRIPT}?t=$(date +%s)"); }
panso_menu() { bash <(fetch "${PANSO_SCRIPT}?t=$(date +%s)"); }
panhub_menu() { bash <(fetch "${PANHUB_SCRIPT}?t=$(date +%s)"); }
zjsync_menu() { bash <(fetch "${ZJSYNC_SCRIPT}?t=$(date +%s)"); }
subconverter_menu() { bash <(fetch "${SUB_SCRIPT}?t=$(date +%s)"); }
shlink_menu() { bash <(fetch "${SHLINK_SCRIPT}?t=$(date +%s)"); }
argosb_menu() { bash <(fetch "${ARGOSB_SCRIPT}?t=$(date +%s)"); }
posteio_menu() { bash <(fetch "${POSTEIO_SCRIPT}?t=$(date +%s)"); }
searxng_menu() { bash <(fetch "${SEARXNG_SCRIPT}?t=$(date +%s)"); }
mtproto_menu() { bash <(fetch "${MTPROTO_SCRIPT}?t=$(date +%s)"); }
system_tool_menu() { bash <(fetch "${SYSTEM_TOOL_SCRIPT}?t=$(date +%s)"); }
cosyvoice_menu() { bash <(fetch "${COSYVOICE_SCRIPT}?t=$(date +%s)"); }
cfst_menu() { bash <(fetch "${CFST_SCRIPT}?t=$(date +%s)"); }
tailscale_menu() { bash <(fetch "${TAILSCALE_SCRIPT}?t=$(date +%s)"); }

casaos_menu() {
    clear
    if systemctl list-unit-files 2>/dev/null | grep -q "casaos.service"; then
        warn "⚠️ CasaOS 似乎已经安装！"
    else
        info "🚀 正在运行 CasaOS 安装脚本..."
        fetch "$CASAOS_INSTALL_URL" | sudo bash
    fi
}

# ================== 状态检测函数 ==================
check_docker_service() {
    if ! command -v docker &>/dev/null; then echo "❌ Docker 未安装"; return; fi
    if ! docker info &>/dev/null; then echo "❌ Docker 未运行"; return; fi
    if command docker ps -a --format '{{.Names}}' | grep -q "^${1}$"; then
        if command docker ps --format '{{.Names}}' | grep -q "^${1}$"; then echo "${C_GREEN}✅ 运行中${C_RESET}"; else echo "⚠️ 已停止"; fi
    else echo "❌ 未安装"; fi
}

rustdesk_status_check() {
    if ! command -v docker &>/dev/null; then echo "❌ 未安装"; return; fi
    # 同时检查两个核心容器
    if docker ps --format '{{.Names}}' | grep -q "^hbbs$" && docker ps --format '{{.Names}}' | grep -q "^hbbr$"; then
        echo "${C_GREEN}✅ 运行中${C_RESET}"
    elif docker ps -a --format '{{.Names}}' | grep -q "^hbbs$"; then
        echo "${C_YELLOW}⚠️ 已停止${C_RESET}"
    else
        echo "❌ 未安装"
    fi
}


casaos_status() {
    if systemctl list-unit-files 2>/dev/null | grep -q "casaos.service"; then
        systemctl is-active --quiet casaos && echo "${C_GREEN}✅ 运行中${C_RESET}" || echo "${C_YELLOW}⚠️ 已停止${C_RESET}"; return
    fi
    echo "❌ 未安装"
}

mtproto_status() {
    if systemctl is-active --quiet mtg 2>/dev/null; then
        echo "${C_GREEN}✅ 运行中${C_RESET}"
    elif systemctl list-unit-files 2>/dev/null | grep -q "mtg.service"; then
        echo "${C_YELLOW}⚠️ 已停止${C_RESET}"
    else
        echo "❌ 未安装"
    fi
}
argosb_status_check() {
    [[ -f "/opt/argosb/installed.flag" ]] && { echo "✅ 已安装 (标记文件)"; return; }
    echo "❌ 未安装"
}

tailscale_status_check() {
    if command -v tailscale &>/dev/null; then
        systemctl is-active --quiet tailscaled 2>/dev/null && echo "${C_GREEN}✅ 运行中${C_RESET}" || echo "${C_YELLOW}⚠️ 已停止${C_RESET}"
    else echo "❌ 未安装"; fi
}

update_menu_script() {
    info "🔄 正在从 GitHub 拉取最新的 menu.sh..."
    if fetch "${SCRIPT_URL}?t=$(date +%s)" -o "$SCRIPT_PATH"; then
        chmod +x "$SCRIPT_PATH"
        info "✅ menu.sh 已经成功更新！"
        info "🚀 正在为您自动重新载入..."
        sleep 1.5
        exec bash "$SCRIPT_PATH"
    else
        error "❌ 更新失败，请检查网络连接！"
    fi
}

# ================== 主菜单循环 ==================
while true; do
    moon_status=$([[ -d /opt/moontv ]] && echo "${C_GREEN}✅ 已安装${C_RESET}" || echo "❌ 未安装")
    libretv_status=$([[ -d /opt/libretv ]] && echo "${C_GREEN}✅ 已安装${C_RESET}" || echo "❌ 未安装")
    singbox_status=$(systemctl is-active --quiet sing-box 2>/dev/null && echo "${C_GREEN}✅ 运行中${C_RESET}" || (systemctl list-unit-files 2>/dev/null | grep -q "sing-box.service" && echo "${C_YELLOW}⚠️ 已停止${C_RESET}" || echo "❌ 未安装"))
    argosb_status=$(argosb_status_check)
    panso_status=$(check_docker_service "pansou-web")
    zjsync_status=$([[ -f /etc/zjsync.conf ]] && echo "${C_GREEN}✅ 已配置${C_RESET}" || echo "❌ 未配置")
    subconverter_status=$(check_docker_service "subconverter")
    shlink_status=$(check_docker_service "shlink")
    posteio_status=$(check_docker_service "poste.io")
    searxng_status=$(check_docker_service "searxng")
    casaos_current_status=$(casaos_status)
    cfst_status=$([[ -d /root/cfst ]] && echo "${C_GREEN}✅ 已安装${C_RESET}" || echo "❌ 未安装")
    tailscale_current_status=$(tailscale_status_check)
    filebrowser_status=$(check_docker_service "filebrowser")
    rustdesk_status=$(rustdesk_status_check)
    
    if command -v docker &>/dev/null && command docker ps --format '{{.Names}}' | grep -q "^panhub$"; then panhub_status="${C_GREEN}✅ 运行中 (Docker)${C_RESET}"
    else panhub_status="❌ 未安装"; fi

    render_menu "🚀 服务管理中心" \
        "1) MoonTV 安装                $moon_status" \
        "2) RustDesk 安装              $rustdesk_status" \
        "3) LibreTV 安装               $libretv_status" \
        "4) 甬哥Sing-box-yg安装        $singbox_status" \
        "5) 勇哥ArgoSB脚本             $argosb_status" \
        "6) Kejilion.sh 一键脚本工具箱 ⚡ 远程调用" \
        "7) zjsync（GitHub 文件自动同步） $zjsync_status" \
        "8) Pansou 网盘搜索            $panso_status" \
        "9) 域名绑定管理               ⚡ 远程调用" \
        "10) Subconverter API后端      $subconverter_status" \
        "11) Poste.io 邮件服务器       $posteio_status" \
        "12) Shlink 短链接生成         $shlink_status" \
        "13) SearxNG 一键安装/卸载      $searxng_status" \
        "14) Telegram MTProto 代理      $(mtproto_status)" \
        "15) CosyVoice 文本转语音       $(check_docker_service "cov")" \
        "16) 系统工具（Swap 管理 + 主机名修改） ⚡" \
        "17) CasaOS 一键安装/管理      $casaos_current_status" \
        "18) PanHub 盘搜聚合           $panhub_status" \
        "19) Cloudflare 优选 IP 工具箱  $cfst_status" \
        "20) Tailscale & DERP 组网工具  $tailscale_current_status" \
        "21) FileBrowser 网盘管理      $filebrowser_status" \
        "00) 更新菜单脚本 menu.sh" \
        "0) 退出"

    read -rp "请输入选项: " main_choice

    case "${main_choice}" in
        1) moon_menu ;; 2) rustdesk_menu ;; 3) libretv_menu ;; 4) singbox_menu ;; 5) argosb_menu ;;
        6) bash <(fetch "https://raw.githubusercontent.com/kejilion/sh/main/kejilion.sh") ;;
        7) zjsync_menu ;; 8) panso_menu ;; 9) nginx_menu ;; 10) subconverter_menu ;; 11) posteio_menu ;;
        12) shlink_menu ;; 13) searxng_menu ;; 14) mtproto_menu ;; 15) cosyvoice_menu ;; 16) system_tool_menu ;;
        17) casaos_menu ;; 18) panhub_menu ;; 19) cfst_menu ;; 20) tailscale_menu ;; 21) filebrowser_menu ;;
        00) update_menu_script ;; 0) exit 0 ;; *) error "❌ 无效输入"; sleep 1 ;;
    esac

    if [[ "$main_choice" != "0" ]]; then
        echo ""
        read -rp "按 [Enter] 键返回主菜单..."
    fi
done
