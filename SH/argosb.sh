#!/bin/bash
set -euo pipefail

# ================== 基础配置 ==================
MAIN_SCRIPT="https://raw.githubusercontent.com/yonggekkk/argosbx/main/argosbx.sh"
BIN_DIR="/root/bin"
AGSX_CMD="$BIN_DIR/agsbx"

# ================== 彩色输出 ==================
green='\033[0;32m'; yellow='\033[1;33m'; red='\033[0;31m'; plain='\033[0m'
info() { echo -e "${green}[INFO]${plain} $*"; }
warn() { echo -e "${yellow}[WARN]${plain} $*"; }
error() { echo -e "${red}[ERROR]${plain} $*"; }

# ================== 检查 ArgoSB 是否安装 ==================
argosb_status_check() {
    $AGSX_CMD list &>/dev/null
}

# ================== 安装快捷方式 ==================
install_shortcut() {
    mkdir -p "$BIN_DIR"
    cat > "$AGSX_CMD" <<EOF
#!/bin/bash
exec bash <(curl -Ls $MAIN_SCRIPT) "\$@"
EOF
    chmod +x "$AGSX_CMD"
    info "✅ 快捷方式已创建：$AGSX_CMD"
}

# ================== 菜单 ==================
show_menu() {
    clear
    if argosb_status_check; then
        menu1_text="修改/添加协议（自动带 rep）"
        status="✅ 已安装"
    else
        menu1_text="安装 ArgoSB 并添加协议"
        status="❌ 未安装"
    fi
    cat <<EOF
==============================
🚀 勇哥ArgoSB协议管理 $status
==============================
1) $menu1_text
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

# ================== 内部函数：确保指定协议端口存在 ==================
ensure_proto_port() {
    # $1 = proto name ("vmpt" or "vwpt")
    local proto="$1"
    local curval
    curval="${!proto:-}"
    if [[ -z "$curval" ]]; then
        # 交互：提示用户输入，若留空则生成随机端口
        read -rp "检测到 ${proto} 未设置。请输入 ${proto} 端口（留空将使用随机端口）: " val
        if [[ -z "$val" ]]; then
            val=$((RANDOM%40000+10000))
            info "自动生成 ${proto} 端口: $val"
        fi
        export "$proto"="$val"
    fi
}

# ================== 添加或更新协议 ==================
add_or_update_protocols() {
    echo ""
    echo "请选择要添加或更新的协议（可多选，用空格分隔，例如 1 3 5）:"
    echo "⚠️ 注意：该操作会覆盖现有配置，请确保输入所有需要保留的协议。"
    echo "1) Vless-TCP-Reality (vlpt)"
    echo "2) Vless-Xhttp-Reality (xhpt)"
    echo "3) Vless-Xhttp (vxpt)"
    echo "4) Shadowsocks-2022 (sspt)"
    echo "5) AnyTLS (anpt)"
    echo "6) Any-Reality (arpt)"
    echo "7) Vmess-ws (vmpt)"
    echo "8) VLESS-ws-enc (vwpt 新增)"
    echo "9) Socks5 (sopt)"
    echo "10) Hysteria2 (hypt)"
    echo "11) Tuic (tupt)"
    echo "12) Argo 临时隧道"
    echo "13) Argo 固定隧道 (需 vmpt/vwpt/agn/agk)"
    read -rp "输入序号: " -a selections

    # 清理旧的本次会话导出变量（仅取消临时变量，避免意外残留）
    unset vlpt xhpt vxpt sspt anpt arpt vmpt vwpt hypt tupt sopt agn agk argo

    for sel in "${selections[@]}"; do
        case $sel in
            1) read -rp "vlpt 端口（留空随机）: " val; [[ -z "$val" ]] && val=$((RANDOM%40000+10000)); export vlpt="$val";;
            2) read -rp "xhpt 端口（留空随机）: " val; [[ -z "$val" ]] && val=$((RANDOM%40000+10000)); export xhpt="$val";;
            3) read -rp "vxpt 端口（留空随机）: " val; [[ -z "$val" ]] && val=$((RANDOM%40000+10000)); export vxpt="$val";;
            4) read -rp "sspt 端口（留空随机）: " val; [[ -z "$val" ]] && val=$((RANDOM%40000+10000)); export sspt="$val";;
            5) read -rp "anpt 端口（留空随机）: " val; [[ -z "$val" ]] && val=$((RANDOM%40000+10000)); export anpt="$val";;
            6) read -rp "arpt 端口（留空随机）: " val; [[ -z "$val" ]] && val=$((RANDOM%40000+10000)); export arpt="$val";;
            7) read -rp "vmpt 端口（留空随机）: " val; [[ -z "$val" ]] && val=$((RANDOM%40000+10000)); export vmpt="$val";;
            8) read -rp "vwpt 端口（留空随机）: " val; [[ -z "$val" ]] && val=$((RANDOM%40000+10000)); export vwpt="$val";;
            9) read -rp "sopt 端口（留空随机）: " val; [[ -z "$val" ]] && val=$((RANDOM%40000+10000)); export sopt="$val";;
            10) read -rp "hypt 端口（留空随机）: " val; [[ -z "$val" ]] && val=$((RANDOM%40000+10000)); export hypt="$val";;
            11) read -rp "tupt 端口（留空随机）: " val; [[ -z "$val" ]] && val=$((RANDOM%40000+10000)); export tupt="$val";;
            12)
                # 临时隧道：选择底层协议并确保相应端口存在
                echo "选择用于穿 Argo 的底层协议："
                echo "1) VLESS-ws-enc (vwpt)"
                echo "2) Vmess-ws (vmpt)"
                read -rp "选择 (1/2): " choose
                if [[ "$choose" == "1" ]]; then
                    export argo="vwpt"
                    ensure_proto_port "vwpt"
                else
                    export argo="vmpt"
                    ensure_proto_port "vmpt"
                fi
                ;;
            13)
                # 固定隧道：选择协议、确保端口，并要求 agn/agk
                echo "固定隧道使用协议："
                echo "1) VLESS-ws-enc (vwpt)"
                echo "2) Vmess-ws (vmpt)"
                read -rp "选择 (1/2): " choose
                if [[ "$choose" == "1" ]]; then
                    export argo="vwpt"
                    ensure_proto_port "vwpt"
                else
                    export argo="vmpt"
                    ensure_proto_port "vmpt"
                fi

                read -rp "请输入 Argo 固定隧道域名 agn: " val; export agn="$val"
                read -rp "请输入 Argo 固定隧道Token agk: " val; export agk="$val"
                if [[ -z "${agn:-}" || -z "${agk:-}" ]]; then
                    warn "agn 或 agk 为空：固定隧道可能无法生效，请检查。"
                fi
                ;;
            *) echo "⚠️ 无效选项 $sel";;
        esac
    done

    if [[ "${argo:-}" == "y" ]]; then
        warn "❌ 检测到 argo=y：此值已废弃，请使用 argo=vwpt 或 argo=vmpt"
    fi

    # 最终检查：如果设置了 argo，但对应端口变量仍为空，则自动补齐随机端口（防止主脚本跳过生成）
    if [[ -n "${argo:-}" ]]; then
        if [[ "$argo" == "vwpt" && -z "${vwpt:-}" ]]; then
            info "自动补齐 vwpt 随机端口"
            export vwpt=$((RANDOM%40000+10000))
        elif [[ "$argo" == "vmpt" && -z "${vmpt:-}" ]]; then
            info "自动补齐 vmpt 随机端口"
            export vmpt=$((RANDOM%40000+10000))
        fi
        info "当前 argo=$argo; vmpt=${vmpt:-}<unset>; vwpt=${vwpt:-}<unset>"
    fi

    if argosb_status_check; then
        rep_flag="rep"
        info "🔹 已安装，命令自动添加 rep"
    else
        rep_flag=""
        info "🟡 首次安装"
    fi

    info "🚀 正在执行 ArgoSB 主程序..."
    # 显示最终将传给主脚本的关键环境变量，便于调试
    info "环境预览: argo=${argo:-}<none> vmpt=${vmpt:-}<none> vwpt=${vwpt:-}<none> agn=${agn:-}<none> agk=${agk:-}<none>"
    bash <(curl -Ls "$MAIN_SCRIPT") $rep_flag
    install_shortcut
    info "✅ 操作完成"
}

view_nodes() { $AGSX_CMD list || true; }
update_script() { bash <(curl -Ls "$MAIN_SCRIPT"); install_shortcut; info "脚本已更新"; }
restart_script() { $AGSX_CMD res || true; }
uninstall_script() { $AGSX_CMD del || true; rm -f "$AGSX_CMD"; info "脚本已卸载"; }
toggle_ipv4_ipv6() { read -rp "显示 IPv4 节点请输入4，IPv6请输入6: " ipver; export ippz="$ipver"; $AGSX_CMD list || true; }
change_port() { read -rp "请输入协议标识 (如 vmpt/vwpt): " proto; read -rp "请输入新的端口: " port; export "$proto"="$port"; bash <(curl -Ls "$MAIN_SCRIPT"); }

install_shortcut

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
        *) echo "⚠️ 无效选项" ;;
    esac
    echo
    read -rp "按回车继续..." _
done
