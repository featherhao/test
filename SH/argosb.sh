#!/bin/bash
set -Eeuo pipefail

# ================== 统一失败处理 ==================
trap 'status=$?; line=${BASH_LINENO[0]}; echo "❌ 发生错误 (exit=$status) at line $line" >&2; exit $status' ERR

# ================== 基础配置 ==================
SCRIPT_URL="https://raw.githubusercontent.com/yonggekkk/argosbx/main/argosbx.sh"
INSTALLED_FLAG="/opt/argosb/installed.flag"
BIN_DIR="/root/bin"
AGS_CMD="$BIN_DIR/agsbx"

# ================== 彩色输出 ==================
green='\033[0;32m'
yellow='\033[1;33m'
red='\033[0;31m'
plain='\033[0m'
info()    { echo -e "${green}[INFO]${plain} $*"; }
warn()    { echo -e "${yellow}[WARN]${plain} $*"; }
error()   { echo -e "${red}[ERROR]${plain} $*"; }

# ================== 环境检测 ==================
command -v curl >/dev/null 2>&1 || { echo "❌ 未检测到 curl，请先安装后再运行"; exit 1; }

# ================== 检查状态 ==================
argosb_status_check() {
    if [[ -x "$AGS_CMD" || -f "$INSTALLED_FLAG" ]]; then
        return 0
    else
        return 1
    fi
}

# ================== 安装快捷方式 ==================
install_shortcut() {
    mkdir -p "$BIN_DIR"
    cat <<'EOF' > "$BIN_DIR/agsbx"
#!/bin/bash
exec bash <(curl -Ls https://raw.githubusercontent.com/yonggekkk/argosbx/main/argosbx.sh) "$@"
EOF
    chmod +x "$BIN_DIR/agsbx"
    mkdir -p "$(dirname "$INSTALLED_FLAG")"
    touch "$INSTALLED_FLAG"
    info "快捷方式已创建，可使用 agsbx 命令直接管理。"
}

# ================== 菜单 ==================
show_menu() {
    clear
    if argosb_status_check; then
        status="✅ 已安装"
    else
        status="❌ 未安装"
    fi

    cat <<EOF
==============================
  🚀 勇哥ArgoSBX协议管理 $status
==============================
1) 添加或更新协议节点
2) 查看节点信息 (agsbx list)
3) 更新脚本 (建议卸载重装)
4) 重启脚本 (agsbx res)
5) 卸载脚本 (agsbx del)
6) 临时切换 IPv4 / IPv6 节点显示
7) 更改协议端口
0) 返回主菜单 / 退出
==============================
EOF
}

# ================== 功能函数 ==================
add_or_update_protocols() {
    cat <<EOF
请选择要添加或更新的协议（可多选，用空格分隔，例如 1 3 5）:
⚠️ 注意：该操作会覆盖现有配置，请确保输入所有需要保留的协议。
1) Vless-Reality-Vision (vlpt)
2) Vless-Xhttp-Reality (xhpt)
3) Vless-Xhttp (vxpt)
4) Shadowsocks-2022 (sspt)
5) AnyTLS (anpt)
6) Any-Reality (arpt)
7) Vmess-ws (vmpt)
8) Hysteria2 (hypt)
9) Tuic (tupt)
10) Argo临时隧道CDN优选节点
11) Argo固定隧道CDN优选节点
EOF

    read -rp "输入序号: " selections

    declare -a NEW_VARS=()
    for sel in $selections; do
        case $sel in
            1)  read -rp "为 vlpt 输入端口号 (留空则随机): " p; NEW_VARS+=("vlpt=$p") ;;
            2)  read -rp "为 xhpt 输入端口号 (留空则随机): " p; NEW_VARS+=("xhpt=$p") ;;
            3)  read -rp "为 vxpt 输入端口号 (留空则随机): " p; NEW_VARS+=("vxpt=$p") ;;
            4)  read -rp "为 sspt 输入端口号 (留空则随机): " p; NEW_VARS+=("sspt=$p") ;;
            5)  read -rp "为 anpt 输入端口号 (留空则随机): " p; NEW_VARS+=("anpt=$p") ;;
            6)  read -rp "为 arpt 输入端口号 (留空则随机): " p; NEW_VARS+=("arpt=$p") ;;
            7)  read -rp "为 vmpt 输入端口号 (留空则随机): " p; NEW_VARS+=("vmpt=$p") ;;
            8)  read -rp "为 hypt 输入端口号 (留空则随机): " p; NEW_VARS+=("hypt=$p") ;;
            9)  read -rp "为 tupt 输入端口号 (留空则随机): " p; NEW_VARS+=("tupt=$p") ;;
            10) read -rp "为 Argo临时隧道 输入端口号 (留空则随机): " p; NEW_VARS+=("argo=$p") ;;
            11) read -rp "为 Argo固定隧道 输入端口号 (留空则随机): " p; NEW_VARS+=("argof=$p") ;;
        esac
    done

    echo "🔹 正在更新节点（一次性应用所有选择）..."
    eval "${NEW_VARS[*]} bash <(curl -Ls $SCRIPT_URL)"
}

view_nodes() {
    "$AGS_CMD" list || true
}

update_script() {
    warn "更新脚本时建议卸载后重装！"
    rm -f "$INSTALLED_FLAG"
    install_shortcut
    info "已更新快捷方式，下次运行将使用最新脚本。"
}

restart_script() {
    "$AGS_CMD" res || true
}

uninstall_script() {
    if [[ -x "$AGS_CMD" ]]; then
        "$AGS_CMD" del || true
    fi
    rm -f "$INSTALLED_FLAG" "$AGS_CMD"
    info "脚本已卸载。"
}

toggle_ipv4_ipv6() {
    "$AGS_CMD" ip || true
}

change_port() {
    read -rp "请输入协议标识 (例如 xhpt): " proto
    read -rp "请输入新的端口号: " port
    eval "$proto=$port bash <(curl -Ls $SCRIPT_URL)"
}

# ================== 主循环 ==================
while true; do
    show_menu
    read -rp "请输入选项: " opt
    case $opt in
        1) add_or_update_protocols ;;
        2) view_nodes ;;
        3) update_script ;;
        4) restart_script ;;
        5) uninstall_script ;;
        6) toggle_ipv4_ipv6 ;;
        7) change_port ;;
        0) exit 0 ;;
        *) echo "无效选项，请重新输入。" ;;
    esac
    echo
    read -rp "按回车键返回菜单..." _
done
