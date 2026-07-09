#!/bin/bash
set -Eeuo pipefail

# ================== 统一失败处理 ==================
trap 'status=$?; line=${BASH_LINENO[0]}; echo "❌ 发生错误 (exit=$status) at line $line" >&2; exit $status' ERR

# ================== 基础配置 ==================
SCRIPT_URL="https://raw.githubusercontent.com/featherhao/test/refs/heads/main/menu.sh"
SCRIPT_PATH="$HOME/menu.sh"
CASAOS_INSTALL_URL="https://get.casaos.io" # CasaOS 安装地址变量
PROXY_URL="https://js.52zy.eu.org/"        # 你的 GHProxy 加速节点地址

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

# ================== 自动化网络检测与智能拉取（IP/环境精准识别版） ==================
GH_PREFIX=""
check_network() {
    info "📡 正在检测网络环境，自动适配最佳下载通道..."
    
    # 1. 核心判定：测试连接 Google（超时 1.5 秒），如果通了，铁定是海外 VPS
    if curl -I -s --connect-timeout 1.5 "https://www.google.com" &>/dev/null; then
        info "🌐 网络检测结果：${C_GREEN}当前处于海外环境，全面启用原生直连模式。${C_RESET}"
        GH_PREFIX=""
        return 0
    fi

    # 2. 如果不通谷歌，再检测国内加速节点是否可用
    if curl -I -s --connect-timeout 2 "${PROXY_URL}" &>/dev/null; then
        info "🚀 网络检测结果：${C_GREEN}当前处于国内环境，已自动切换至 GHProxy 加速模式。${C_RESET}"
        GH_PREFIX="${PROXY_URL}"
        return 0
    fi

    # 3. 终极兜底：两边都挂了
    echo -e "${C_RED}==================================================${C_RESET}"
    echo -e "${C_RED}[x] 严重警告：网络环境极差，海外通道与国内加速节点均无法连接！${C_RESET}"
    echo -e "${C_YELLOW}[!] 脚本将强行切回【官方原始链接】盲跑，请检查本地网络或代理。${C_RESET}"
    echo -e "${C_RED}==================================================${C_RESET}"
    sleep 3
    GH_PREFIX=""
}
check_network

# 智能拉取器：完美兼容 -o 保存文件或其他自定义位置参数
fetch() { 
    local target_url="$1"
    shift # 弹掉第一个 URL 参数，剩下的是可能存在的 -o "$SCRIPT_PATH" 等多余参数
    
    # 如果目标是 GitHub 相关的链接且需要代理加速，并且本身不含代理前缀，则自动套用
    if [[ -n "$GH_PREFIX" ]] && [[ "$target_url" =~ "github" ]] && [[ ! "$target_url" =~ "$PROXY_URL" ]]; then
        target_url="${GH_PREFIX}${target_url}"
    fi
    # 把其他参数 (如 -o) 规范地传给 curl，最后放 target_url
    curl -fsSL --retry 3 --retry-delay 1 --connect-timeout 5 --max-time 30 "$@" "$target_url"
}
run_url() { bash <(fetch "$1"); }

# ================== 自我初始化 ==================
SCRIPT_IS_FIRST_RUN=false
if [[ "$0" == "/dev/fd/"* ]] || [[ "$0" == "bash" ]]; then
    info "⚡ 检测到你是通过 <(curl …) 临时运行的"
    info "👉 正在自动保存 menu.sh 到 $SCRIPT_PATH"
    fetch "${SCRIPT_URL}?t=$(date +%s)" -o "$SCRIPT_PATH"
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
        script_cmd="bash ~/menu.sh"
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
PANHUB_SCRIPT="https://raw.githubusercontent.com/featherhao/test/refs/heads/main/SH/panhub.sh"
POSTEIO_SCRIPT="https://raw.githubusercontent.com/featherhao/test/refs/heads/main/SH/Poste.io.sh"
WORKDIR_SEARXNG="/opt/searxng"
SEARXNG_SCRIPT="https://raw.githubusercontent.com/featherhao/test/refs/heads/main/SH/searxng.sh"
MTPROTO_SCRIPT="https://raw.githubusercontent.com/featherhao/test/refs/heads/main/SH/MTProto.sh"
SYSTEM_TOOL_SCRIPT="https://raw.githubusercontent.com/featherhao/test/refs/heads/main/SH/system_tool.sh"
CLEAN_VPS_SCRIPT="https://raw.githubusercontent.com/featherhao/test/refs/heads/main/SH/clean_vps.sh"
COSYVOICE_SCRIPT="https://raw.githubusercontent.com/featherhao/test/refs/heads/main/SH/cosyvoice.sh"
CFST_SCRIPT="https://raw.githubusercontent.com/featherhao/test/refs/heads/main/SH/cfst.sh"

# ================== 子脚本调用函数 ==================
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

casaos_menu() {
    clear
    if systemctl list-unit-files 2>/dev/null | grep -q "casaos.service"; then
        warn "⚠️ CasaOS 似乎已经安装！"
        info "您可能不需要重复安装。"
        echo ""
        info "🏠 CasaOS访问地址通常是: http://<您的IP地址>:80 或 http://casaos.local"
    else
        info "🚀 正在运行 CasaOS 安装脚本..."
        info "这可能需要您输入sudo密码并花费一些时间。"
        
        if ! fetch "$CASAOS_INSTALL_URL" | sudo bash; then
            error "CasaOS 安装失败！请检查错误信息。"
            return 1
        fi
        info "✅ CasaOS 安装脚本已执行完毕。"
    fi
    
    echo ""
    print_header "CasaOS 第三方应用商店源"
    echo -e "${C_CYAN}# CasaOS 第三方应用商店源:${C_RESET} ${C_BOLD}https://play.cuse.eu.org/Cp0204-AppStore-Play.zip${C_RESET}"
    echo -e "    👉 您可以在 CasaOS UI界面的'App Store' -> '源' 中添加此链接。"
    echo -e "=============================="
    return 0
}

# ================== 状态检测函数 ==================
check_docker_service() {
    local service_name="$1"
    if ! command -v docker &>/dev/null; then
        echo "❌ Docker 未安装"; return
    fi
    if ! docker info &>/dev/null; then
        echo "❌ Docker 未运行"; return
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

casaos_status() {
    if systemctl list-unit-files 2>/dev/null | grep -q "casaos.service"; then
        if systemctl is-active --quiet casaos; then
            echo "${C_GREEN}✅ 运行中${C_RESET}"
        else
            echo "${C_YELLOW}⚠️ 已停止${C_RESET}"
        fi
        return
    fi
    if command -v casaos &>/dev/null; then
        echo "${C_YELLOW}⚠️ 已安装 (状态未知)${C_RESET}"
        return
    fi
    echo "❌ 未安装"
}

mtproto_status() {
    if systemctl list-unit-files 2>/dev/null | grep -q "mtg.service"; then
        systemctl is-active --quiet mtg && echo "✅ 运行中 (systemctl)" || echo "⚠️ 已停止 (systemctl)"
        return
    fi
    if command -v docker &>/dev/null; then
        local cid
        cid=$(docker ps -a --filter "ancestor=telegrammessenger/proxy" --format '{{.ID}}' | head -n1)
        [[ -z "$cid" ]] && cid=$(docker ps -a --filter "ancestor=mtproto" --format '{{.ID}}' | head -n1)
        if [[ -n "$cid" ]]; then
            docker ps --filter "id=$cid" --format '{{.ID}}' | grep -q . && echo "✅ 运行中 (docker)" || echo "⚠️ 已停止 (docker)"
            return
        fi
    fi
    echo "❌ 未安装"
}

argosb_status_check() {
    [[ -f "/opt/argosb/installed.flag" ]] && { echo "✅ 已安装 (标记文件)"; return; }
    command -v agsbx &>/dev/null || command -v agsb &>/dev/null && { echo "✅ 已安装 (命令可用)"; return; }
    echo "❌ 未安装"
}

update_menu_script() {
    info "🔄 正在更新 menu.sh..."
    fetch "${SCRIPT_URL}?t=$(date +%s)" -o "$SCRIPT_PATH"
    chmod +x "$SCRIPT_PATH"
    info "✅ menu.sh 已更新到 $SCRIPT_PATH"
    info "👉 以后可直接执行：bash ~/menu.sh"
}

# ================== 主菜单循环 ==================
while true; do
    # 刷新状态
    moon_status=$([[ -d /opt/moontv ]] && echo "${C_GREEN}✅ 已安装${C_RESET}" || echo "❌ 未安装")
    rustdesk_status=$([[ -d /opt/rustdesk ]] && echo "${C_GREEN}✅ 已安装${C_RESET}" || echo "❌ 未安装")
    libretv_status=$([[ -d /opt/libretv ]] && echo "${C_GREEN}✅ 已安装${C_RESET}" || echo "❌ 未安装")
    if command -v sing-box &>/dev/null || command -v sb &>/dev/null; then
        singbox_status="${C_GREEN}✅ 已安装${C_RESET}"
    else
        singbox_status="❌ 未安装"
    fi

    argosb_status=$(argosb_status_check)
    panso_status=$(check_docker_service "pansou-web")
    zjsync_status=$([[ -f /etc/zjsync.conf ]] && echo "${C_GREEN}✅ 已配置${C_RESET}" || echo "❌ 未配置")
    subconverter_status=$(check_docker_service "subconverter")
    shlink_status=$(check_docker_service "shlink")
    posteio_status=$(check_docker_service "posteio")
    searxng_status=$(check_docker_service "searxng")
    casaos_current_status=$(casaos_status)
    cfst_status=$([[ -d /root/cfst ]] && echo "${C_GREEN}✅ 已安装${C_RESET}" || echo "❌ 未安装")
    
    if command -v docker &>/dev/null && docker ps --format '{{.Names}}' | grep -q "^panhub$"; then
        panhub_status="${C_GREEN}✅ 运行中 (Docker)${C_RESET}"
    elif command -v docker &>/dev/null && docker ps -a --format '{{.Names}}' | grep -q "^panhub$"; then
        panhub_status="${C_YELLOW}⚠️ 已停止 (Docker)${C_RESET}"
    elif command -v pm2 &>/dev/null && pm2 list | grep -q "panhub"; then
        if pm2 list | grep "panhub" | grep -q "online"; then
            panhub_status="${C_GREEN}✅ 运行中 (PM2)${C_RESET}"
        else
            panhub_status="${C_YELLOW}⚠️ 已停止 (PM2)${C_RESET}"
        fi
    elif pgrep -f "node .output/server/index.mjs" &>/dev/null; then
        panhub_status="${C_GREEN}✅ 运行中 (原生进程)${C_RESET}"
    else
        panhub_status="❌ 未安装"
    fi

    # 渲染菜单
    render_menu "🚀 服务管理中心" \
        "1) MoonTV 安装                 $moon_status" \
        "2) RustDesk 安装                $rustdesk_status" \
        "3) LibreTV 安装                 $libretv_status" \
        "4) 甬哥Sing-box-yg安装           $singbox_status" \
        "5) 勇哥ArgoSB脚本                $argosb_status" \
        "6) Kejilion.sh 一键脚本工具箱      ⚡ 远程调用" \
        "7) zjsync（GitHub 文件自动同步）    $zjsync_status" \
        "8) Pansou 网盘搜索               $panso_status" \
        "9) 域名绑定管理                  ⚡ 远程调用" \
        "10) Subconverter API后端         $subconverter_status" \
        "11) Poste.io 邮件服务器           $posteio_status" \
        "12) Shlink 短链接生成             $shlink_status" \
        "13) SearxNG 一键安装/卸载         $searxng_status" \
        "14) Telegram MTProto 代理         $(mtproto_status)" \
        "15) CosyVoice 文本转语音          $(check_docker_service "cov")" \
        "16) 系统工具（Swap 管理 + 主机名修改） ⚡" \
        "17) CasaOS 一键安装/管理          $casaos_current_status" \
        "18) PanHub 盘搜聚合 (支持多架构)  $panhub_status" \
        "19) Cloudflare 优选 IP 工具箱     $cfst_status" \
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
        6) bash <(fetch "https://raw.githubusercontent.com/kejilion/sh/main/kejilion.sh") ;;
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
        17) casaos_menu ;;
        18) panhub_menu ;;
        19) cfst_menu ;;
        00) update_menu_script ;;
        0) exit 0 ;;
        *) error "❌ 无效输入"; sleep 2 ;;
    esac

    if [[ "$main_choice" != "0" ]]; then
        echo ""
        read -rp "按 [Enter] 键返回主菜单..."
    fi

done
