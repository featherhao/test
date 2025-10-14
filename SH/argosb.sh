#!/bin/bash
set -Eeuo pipefail

# ================== 统一失败处理 ==================
trap 'status=$?; line=${BASH_LINENO[0]}; echo -e "\n❌ 发生错误 (exit=$status) at line $line" >&2; exit $status' ERR

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

# ================== 检测下载工具（curl/wget） ==================
detect_downloader() {
    if command -v curl >/dev/null 2>&1; then
        DOWNLOADER="curl"
    elif command -v wget >/dev/null 2>&1; then
        DOWNLOADER="wget"
    else
        echo "❌ 未检测到 curl 或 wget，请先安装其中一个工具再运行本脚本。"
        exit 1
    fi
}
detect_downloader

# helper: 构建远程执行命令（bash <(curl... ) 或 bash <(wget -qO- ...)）
fetch_cmd() {
    if [[ "$DOWNLOADER" == "curl" ]]; then
        echo "bash <(curl -Ls $SCRIPT_URL)"
    else
        echo "bash <(wget -qO- $SCRIPT_URL)"
    fi
}

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
    cat <<'EOF' > "$AGS_CMD"
#!/bin/bash
exec bash <(curl -Ls https://raw.githubusercontent.com/yonggekkk/argosbx/main/argosbx.sh) "$@"
EOF
    # 如果没有 curl 则写入 wget 版本
    if ! command -v curl >/dev/null 2>&1 && command -v wget >/dev/null 2>&1; then
        cat <<'EOF' > "$AGS_CMD"
#!/bin/bash
exec bash <(wget -qO- https://raw.githubusercontent.com/yonggekkk/argosbx/main/argosbx.sh) "$@"
EOF
    fi
    chmod +x "$AGS_CMD"
    mkdir -p "$(dirname "$INSTALLED_FLAG")"
    touch "$INSTALLED_FLAG"
    info "快捷方式已创建：$AGS_CMD （现在可使用 agsbx 命令）"
    info "首次创建后建议重新连接 SSH 以确保 PATH 生效（或直接使用 $AGS_CMD）。"
}

# ================== 菜单展示 ==================
show_menu() {
    clear
    if argosb_status_check; then
        status="✅ 已安装"
    else
        status="❌ 未安装"
    fi

    cat <<EOF
==============================
  🚀 勇哥 ArgoSBX 协议管理  $status
==============================
1) 添加或更新协议节点
2) 查看节点信息 (agsbx list)
3) 更新脚本 (建议卸载重装)
4) 重启脚本 (agsbx res)
5) 卸载脚本 (agsbx del)
6) 临时切换 IPv4 / IPv6 节点显示
7) 更改协议端口
8) 创建/重新创建快捷方式 (install agsbx)
0) 退出
==============================
EOF
}

# ================== 功能实现 ==================
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
    [[ -z "${selections// }" ]] && { echo "取消。"; return; }

    declare -a NEW_VARS=()
    for sel in $selections; do
        case $sel in
            1)  read -rp "为 vlpt 输入端口号 (留空则随机): " p; NEW_VARS+=("vlpt=\"$p\"") ;;
            2)  read -rp "为 xhpt 输入端口号 (留空则随机): " p; NEW_VARS+=("xhpt=\"$p\"") ;;
            3)  read -rp "为 vxpt 输入端口号 (留空则随机): " p; NEW_VARS+=("vxpt=\"$p\"") ;;
            4)  read -rp "为 sspt 输入端口号 (留空则随机): " p; NEW_VARS+=("sspt=\"$p\"") ;;
            5)  read -rp "为 anpt 输入端口号 (留空则随机): " p; NEW_VARS+=("anpt=\"$p\"") ;;
            6)  read -rp "为 arpt 输入端口号 (留空则随机): " p; NEW_VARS+=("arpt=\"$p\"") ;;
            7)  read -rp "为 vmpt 输入端口号 (留空则随机): " p; NEW_VARS+=("vmpt=\"$p\"") ;;
            8)  read -rp "为 sopt (Socks5) 输入端口号 (留空则随机): " p; NEW_VARS+=("sopt=\"$p\"") ;;
            9)  read -rp "为 hypt (Hysteria2) 输入端口号 (留空则随机): " p; NEW_VARS+=("hypt=\"$p\"") ;;
            10) read -rp "为 tupt (Tuic) 输入端口号 (留空则随机): " p; NEW_VARS+=("tupt=\"$p\"") ;;
            11)
                read -rp "启用 Argo 临时隧道? (y/n): " yn
                if [[ "$yn" == "y" ]]; then
                    NEW_VARS+=("argo=\"y\"")
                    # 若未指定 vmpt，提示输入可选 vmpt
                    read -rp "可选：为 vmpt 输入端口号（留空则脚本随机）: " p
                    NEW_VARS+=("vmpt=\"$p\"")
                fi
                ;;
            12)
                read -rp "为 Argo 固定隧道输入 vmpt 端口号: " p
                read -rp "输入 Argo 固定隧道域名 agn (CF 解析域名): " agn
                read -rp "输入 Argo 固定隧道 token agk (CF token): " agk
                NEW_VARS+=("vmpt=\"$p\"" "argo=\"y\"" "agn=\"$agn\"" "agk=\"$agk\"")
                ;;
            *)
                echo "跳过未知选项：$sel"
                ;;
        esac
    done

    echo "🔹 正在更新节点（一次性应用所有选择）..."
    # 将变量数组拼成一行环境变量导出，然后执行远程脚本
    envline=""
    for v in "${NEW_VARS[@]}"; do
        # v example: vlpt="1234" 或 vlpt=""
        envline+="$v "
    done
    cmd="$(fetch_cmd)"
    # 使用 eval 执行组合命令（谨慎：来自用户输入的变量已使用引号包裹）
    eval "$envline $cmd"
}

view_nodes() {
    # 直接运行 agsbx list（如果需要可通过 ippz=4/6 前缀显示）
    if [[ -x "$AGS_CMD" ]]; then
        "$AGS_CMD" list || true
    else
        # 尝试直接远程调用主脚本 list（当快捷方式未生效时）
        cmd="$(fetch_cmd)"
        eval "$cmd list" || true
    fi
}

update_script() {
    warn "更新脚本时建议卸载后重装以避免旧文件残留。"
    rm -f "$INSTALLED_FLAG"
    install_shortcut
    info "已重建快捷方式，下一次使用 agsbx 将使用最新主脚本。"
}

restart_script() {
    if [[ -x "$AGS_CMD" ]]; then
        "$AGS_CMD" res || true
    else
        cmd="$(fetch_cmd)"
        eval "$cmd res" || true
    fi
}

uninstall_script() {
    # 优雅执行主脚本 del（若存在）
    if [[ -x "$AGS_CMD" ]]; then
        "$AGS_CMD" del || true
    else
        # 也尝试远程 del
        cmd="$(fetch_cmd)"
        eval "$cmd del" || true
    fi
    rm -f "$INSTALLED_FLAG" "$AGS_CMD"
    info "脚本已卸载（快捷方式与标志已删除）。"
}

toggle_ipv4_ipv6() {
    read -rp "显示 IPv4 还是 IPv6 节点？(4/6): " ipver
    if [[ "$ipver" != "4" && "$ipver" != "6" ]]; then
        echo "无效选择，取消。"
        return
    fi
    if [[ -x "$AGS_CMD" ]]; then
        ippz="$ipver" "$AGS_CMD" list || true
    else
        cmd="$(fetch_cmd)"
        eval "ippz=$ipver $cmd list" || true
    fi
}

change_port() {
    read -rp "请输入协议标识 (例如 xhpt/vlpt/vmpt/vxpt/sopt 等): " proto
    if [[ -z "$proto" ]]; then
        echo "取消。"
        return
    fi
    read -rp "请输入新的端口号 (留空则随机): " port
    # 使用远程脚本执行单次变量替换
    cmd="$(fetch_cmd)"
    eval "$proto=\"$port\" $cmd"
}

create_shortcut_if_missing() {
    if [[ ! -x "$AGS_CMD" ]]; then
        echo "未检测到 agsbx 快捷方式，是否现在创建？(y/n)"
        read -rn1 answer
        echo
        if [[ "$answer" == "y" ]]; then
            install_shortcut
        else
            echo "跳过创建快捷方式。"
        fi
    else
        echo "快捷方式已存在：$AGS_CMD"
    fi
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
        8) create_shortcut_if_missing ;;
        0) echo "退出."; exit 0 ;;
        *) echo "无效选项，请重新输入。" ;;
    esac
    echo
    read -rp "按回车键返回菜单..." _
done
