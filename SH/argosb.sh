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
    status=$(argosb_status_check && echo "✅ 已安装" || echo "❌ 未安装")
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
    echo "8) Socks5 (sopt)"
    echo "9) Hysteria2 (hypt)"
    echo "10) Tuic (tupt)"
    echo "11) Argo 临时隧道"
    echo "12) Argo 固定隧道 (需 vmpt/agn/agk)"
    read -rp "输入序号: " -a selections

    # 清空旧变量
    unset vlpt xhpt vxpt sspt anpt arpt vmpt hypt tupt argo agn agk
    vmess_enabled=0

    for sel in "${selections[@]}"; do
        case $sel in
            1) read -rp "请输入 vlpt 端口（留空随机）: " val; [[ -z "$val" ]] && val=$((RANDOM%40000+10000)); export vlpt="$val";;
            2) read -rp "请输入 xhpt 端口（留空随机）: " val; [[ -z "$val" ]] && val=$((RANDOM%40000+10000)); export xhpt="$val";;
            3) read -rp "请输入 vxpt 端口（留空随机）: " val; [[ -z "$val" ]] && val=$((RANDOM%40000+10000)); export vxpt="$val";;
            4) read -rp "请输入 sspt 端口（留空随机）: " val; [[ -z "$val" ]] && val=$((RANDOM%40000+10000)); export sspt="$val";;
            5) read -rp "请输入 anpt 端口（留空随机）: " val; [[ -z "$val" ]] && val=$((RANDOM%40000+10000)); export anpt="$val";;
            6) read -rp "请输入 arpt 端口（留空随机）: " val; [[ -z "$val" ]] && val=$((RANDOM%40000+10000)); export arpt="$val";;
            7) read -rp "请输入 vmpt 端口（留空随机）: " val; [[ -z "$val" ]] && val=$((RANDOM%40000+10000)); export vmpt="$val"; vmess_enabled=1;;
            8) read -rp "请输入 sopt 端口（留空随机）: " val; [[ -z "$val" ]] && val=$((RANDOM%40000+10000)); export sopt="$val";;
            9) read -rp "请输入 hypt 端口（留空随机）: " val; [[ -z "$val" ]] && val=$((RANDOM%40000+10000)); export hypt="$val";;
            10) read -rp "请输入 tupt 端口（留空随机）: " val; [[ -z "$val" ]] && val=$((RANDOM%40000+10000)); export tupt="$val";;
            11) export argo="y";;
            12)
                if [ $vmess_enabled -eq 0 ]; then
                    echo "⚠️ Argo固定隧道必须启用 vmpt，请先选择 7) Vmess-ws"
                    continue 2
                fi
                if [ -z "${vmpt:-}" ]; then
                    read -rp "请输入 Argo固定隧道端口 vmpt: " val
                    export vmpt="$val"
                fi
                read -rp "请输入 Argo固定隧道域名 agn: " val; export agn="$val"
                read -rp "请输入 Argo固定隧道Token agk: " val; export agk="$val"
                export argo="y"
                ;;
            *) echo "⚠️ 无效选项 $sel";;
        esac
    done

    info "🚀 正在执行 ArgoSB 脚本..."
    bash <(curl -Ls "$MAIN_SCRIPT")
    info "✅ 协议更新完成"
}

# ================== 其他操作 ==================
view_nodes() { $AGSX_CMD list || true; }
update_script() { bash <(curl -Ls "$MAIN_SCRIPT"); install_shortcut; info "脚本已更新"; }
restart_script() { $AGSX_CMD res || true; }
uninstall_script() { $AGSX_CMD del || true; rm -f "$AGSX_CMD"; info "脚本已卸载"; }
toggle_ipv4_ipv6() { read -rp "显示 IPv4 节点请输入4，IPv6请输入6: " ipver; export ippz="$ipver"; $AGSX_CMD list || true; }
change_port() { read -rp "请输入协议标识 (例如 xhpt): " proto; read -rp "请输入新的端口号: " port; export "$proto"="$port"; bash <(curl -Ls "$MAIN_SCRIPT"); }

# ================== 主循环 ==================
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
    read -rp "按回车键继续..." _
done
