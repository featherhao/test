#!/bin/bash
set -Eeuo pipefail

# ================== 统一失败处理 ==================
trap 'status=$?; line=${BASH_LINENO[0]}; echo "❌ 发生错误 (exit=$status) at line $line" >&2; exit $status' ERR

# ================== 基础配置 ==================
SCRIPT_URL="https://raw.githubusercontent.com/yonggekkk/argosbx/main/argosbx.sh"
INSTALLED_FLAG="/opt/argosb/installed.flag"
BIN_DIR="/root/bin"
AGSX_CMD="$BIN_DIR/agsbx"

# ================== 彩色输出 ==================
green='\033[0;32m'
yellow='\033[1;33m'
red='\033[0;31m'
plain='\033[0m'
info()    { echo -e "${green}[INFO]${plain} $*"; }
warn()    { echo -e "${yellow}[WARN]${plain} $*"; }
error()   { echo -e "${red}[ERROR]${plain} $*"; }

# ================== 检查状态 ==================
argosb_status_check() {
    [[ -x "$AGSX_CMD" && -f "$INSTALLED_FLAG" ]] && return 0 || return 1
}

# ================== 安装快捷方式 ==================
install_shortcut() {
    mkdir -p "$BIN_DIR"
    cat > "$AGSX_CMD" <<EOF
#!/bin/bash
exec bash <(curl -Ls $SCRIPT_URL) "\$@"
EOF
    chmod +x "$AGSX_CMD"
    mkdir -p "$(dirname "$INSTALLED_FLAG")"
    touch "$INSTALLED_FLAG"
    info "✅ 快捷方式已创建：$AGSX_CMD"
}

# ================== 安装 ArgoSB ==================
install_argosb() {
    if ! argosb_status_check; then
        info "⚠️ ArgoSB 未安装，正在安装..."
        bash <(curl -Ls "$SCRIPT_URL")
        install_shortcut
        info "✅ ArgoSB 已成功安装"
    fi
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
  🚀 勇哥ArgoSB协议管理 $status
==============================
1) 添加或更新协议节点
2) 查看节点信息 (agsbx list)
3) 更新脚本 (建议卸载重装)
4) 重启脚本 (agsbx res)
5) 卸载脚本 (agsbx del)
6) 临时切换 IPv4 / IPv6 节点显示
7) 更改协议端口
0) 退出
==============================
EOF
}

# ================== 操作函数 ==================
add_or_update_protocols() {
    cat <<EOF
请选择要添加或更新的协议（可多选，用空格分隔，例如 1 3 5；回车取消）:
⚠️ 注意：该操作会覆盖现有配置，请确保输入所有需要保留的协议。
1) Vless-TCP-Reality (vlpt)
2) Vless-Xhttp-Reality (xhpt)
3) Vless-Xhttp (vxpt)
4) Shadowsocks-2022 (sspt)
5) AnyTLS (anpt)
6) Any-Reality (arpt)
7) Vmess-ws (vmpt)
8) Socks5 (sopt)
9) Hysteria2 (hypt)
10) Tuic (tupt)
11) Argo 临时隧道 优选节点
12) Argo 固定隧道 (需 vmpt/agn/agk)
EOF

    read -rp "输入序号: " selections
    [[ -z "$selections" ]] && return

    VAR_STR=""
    for sel in $selections; do
        case $sel in
            1) read -rp "为 vlpt 输入端口号 (留空随机): " p; VAR_STR+="vlpt=\"$p\" " ;;
            2) read -rp "为 xhpt 输入端口号 (留空随机): " p; VAR_STR+="xhpt=\"$p\" " ;;
            3) read -rp "为 vxpt 输入端口号 (留空随机): " p; VAR_STR+="vxpt=\"$p\" " ;;
            4) read -rp "为 sspt 输入端口号 (留空随机): " p; VAR_STR+="sspt=\"$p\" " ;;
            5) read -rp "为 anpt 输入端口号 (留空随机): " p; VAR_STR+="anpt=\"$p\" " ;;
            6) read -rp "为 arpt 输入端口号 (留空随机): " p; VAR_STR+="arpt=\"$p\" " ;;
            7) read -rp "为 vmpt 输入端口号 (留空随机): " p; VAR_STR+="vmpt=\"$p\" " ;;
            8) read -rp "为 sopt 输入端口号 (留空随机): " p; VAR_STR+="sopt=\"$p\" " ;;
            9) read -rp "为 hypt 输入端口号 (留空随机): " p; VAR_STR+="hypt=\"$p\" " ;;
            10) read -rp "为 tupt 输入端口号 (留空随机): " p; VAR_STR+="tupt=\"$p\" " ;;
            11) read -rp "为 Argo 临时隧道 输入端口号 (留空随机): " p; VAR_STR+="argo=\"$p\" " ;;
            12) 
                read -rp "为 Argo 固定隧道输入 vmpt 端口号: " p
                read -rp "输入 Argo 固定隧道域名 agn (CF 解析域名): " agn
                read -rp "输入 Argo 固定隧道 token agk (CF token): " agk
                VAR_STR+="vmpt=\"$p\" argo=\"y\" agn=\"$agn\" agk=\"$agk\" "
                ;;
        esac
    done

    # 安装 ArgoSB 脚本（如果未安装）
    install_argosb

    info "🔹 正在更新节点..."
    bash <(curl -Ls "$SCRIPT_URL") $VAR_STR
}

view_nodes() { $AGSX_CMD list || true; }
update_script() { rm -f "$INSTALLED_FLAG"; install_argosb; info "脚本已更新"; }
restart_script() { $AGSX_CMD res || true; }
uninstall_script() { $AGSX_CMD del || true; rm -f "$INSTALLED_FLAG" "$AGSX_CMD"; info "脚本已卸载"; }
toggle_ipv4_ipv6() { $AGSX_CMD ip || true; }
change_port() { read -rp "请输入协议标识 (例如 xhpt): " proto; read -rp "请输入新的端口号: " port; bash <(curl -Ls "$SCRIPT_URL") "$proto=$port"; }

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
        *) echo "无效选项" ;;
    esac
    echo
    read -rp "按回车键继续..." _
done
