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
        menu1_text="修改/添加协议与配置（自动带 rep）"
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
7) 更改协议端口或变量
0) 退出
==============================
EOF
}

# ================== 内部函数：确保指定协议端口存在 ==================
ensure_proto_port() {
    local proto="$1"
    local curval="${!proto:-}"

    if [[ -z "$curval" ]]; then
        read -rp "检测到 ${proto} 未设置。请输入 ${proto} 端口（留空将使用随机端口）: " val
        if [[ -z "$val" ]]; then
            val=$((RANDOM%40000+10000))
            info "自动生成 ${proto} 端口: $val"
        fi
        export "$proto"="$val"
    fi
}

# ================== 添加或更新协议与配置 ==================
add_or_update_protocols() {
    echo ""
    echo "请选择要添加或更新的协议（可多选，用空格分隔，例如 1 3 14）:"
    echo "⚠️ 注意：该操作会覆盖现有配置，请确保输入所有需要保留的协议。"
    echo "--- Xray 可选协议 ---"
    echo "1) Vless-TCP-Reality (vlpt)"
    echo "2) Vless-Xhttp-Reality (xhpt)"
    echo "3) Vless-Xhttp (vxpt)"
    echo "4) Vless-ws-enc (vwpt)"
    echo "5) Vless-Xhttp-tls-UDP (xupt 新增)"
    echo "6) Vless-Xhttp-tls-TCP/UDP (xcpt 新增)"
    echo "--- Singbox 可选协议 ---"
    echo "7) Tuic (tupt)"
    echo "8) AnyTLS (anpt)"
    echo "9) Naiveproxy (nvpt 新增)"
    echo "10) Any-reality (arpt)"
    echo "11) Shadowsocks-2022 (sspt)"
    echo "--- 其他协议 ---"
    echo "12) Hysteria2 (hypt)"
    echo "13) Vmess-ws (vmpt)"
    echo "14) Socks5 (sopt)"
    echo "--- Argo 隧道 ---"
    echo "15) Argo 临时隧道"
    echo "16) Argo 固定隧道 (需 vmpt/vwpt/agn/agk)"
    read -rp "输入序号: " -a selections

    # 清空所有相关变量
    unset vlpt xhpt vxpt vwpt xupt xcpt tupt anpt nvpt arpt sspt hypt vmpt sopt agn agk argo uuid reym cfip alns cdnym warp ippz oap name sub subid subpt

    for sel in "${selections[@]}"; do
        case $sel in
            1) read -rp "vlpt 端口（留空随机）: " val; [[ -z "$val" ]] && val=$((RANDOM%40000+10000)); export vlpt="$val";;
            2) read -rp "xhpt 端口（留空随机）: " val; [[ -z "$val" ]] && val=$((RANDOM%40000+10000)); export xhpt="$val";;
            3) read -rp "vxpt 端口（留空随机）: " val; [[ -z "$val" ]] && val=$((RANDOM%40000+10000)); export vxpt="$val";;
            4) read -rp "vwpt 端口（留空随机）: " val; [[ -z "$val" ]] && val=$((RANDOM%40000+10000)); export vwpt="$val";;
            5) read -rp "xupt 端口（留空随机）: " val; [[ -z "$val" ]] && val=$((RANDOM%40000+10000)); export xupt="$val";;
            6) read -rp "xcpt 端口（留空随机）: " val; [[ -z "$val" ]] && val=$((RANDOM%40000+10000)); export xcpt="$val";;
            7) read -rp "tupt 端口（留空随机）: " val; [[ -z "$val" ]] && val=$((RANDOM%40000+10000)); export tupt="$val";;
            8) read -rp "anpt 端口（留空随机）: " val; [[ -z "$val" ]] && val=$((RANDOM%40000+10000)); export anpt="$val";;
            9) read -rp "nvpt 端口（留空随机）: " val; [[ -z "$val" ]] && val=$((RANDOM%40000+10000)); export nvpt="$val";;
            10) read -rp "arpt 端口（留空随机）: " val; [[ -z "$val" ]] && val=$((RANDOM%40000+10000)); export arpt="$val";;
            11) read -rp "sspt 端口（留空随机）: " val; [[ -z "$val" ]] && val=$((RANDOM%40000+10000)); export sspt="$val";;
            12) read -rp "hypt 端口（留空随机）: " val; [[ -z "$val" ]] && val=$((RANDOM%40000+10000)); export hypt="$val";;
            13) read -rp "vmpt 端口（留空随机）: " val; [[ -z "$val" ]] && val=$((RANDOM%40000+10000)); export vmpt="$val";;
            14) read -rp "sopt 端口（留空随机）: " val; [[ -z "$val" ]] && val=$((RANDOM%40000+10000)); export sopt="$val";;
            15)
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
            16)
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
                ;;
            *) echo "⚠️ 无效选项 $sel";;
        esac
    done

    # ================== 可选：全局高级配置项 ==================
    echo ""
    info "--- 接下来可配置全局参数（直接回车跳过使用默认值） ---"
    read -rp "UUID 密码 (uuid，留空随机): " val; [[ -n "$val" ]] && export uuid="$val"
    read -rp "Reality 域名 (reym，默认 apple.com): " val; [[ -n "$val" ]] && export reym="$val"
    read -rp "CDN优选域名 (cfip，空格分隔多个): " val; [[ -n "$val" ]] && export cfip="$val"
    read -rp "启用域名IP证书TLS (alns，留空默认关闭): " val; [[ -n "$val" ]] && export alns="$val"
    read -rp "CF解析IP的域名 (cdnym): " val; [[ -n "$val" ]] && export cdnym="$val"
    read -rp "套WARP-IP出站 (warp): " val; [[ -n "$val" ]] && export warp="$val"
    read -rp "IPv4/IPv6 配置导出 (ippz): " val; [[ -n "$val" ]] && export ippz="$val"
    read -rp "当前系统开放所有端口 (oap): " val; [[ -n "$val" ]] && export oap="$val"
    read -rp "导出节点名称前缀 (name): " val; [[ -n "$val" ]] && export name="$val"
    read -rp "启用订阅链接 (sub): " val; [[ -n "$val" ]] && export sub="$val"
    read -rp "订阅链接密码 (subid): " val; [[ -n "$val" ]] && export subid="$val"
    read -rp "订阅链接端口 (subpt): " val; [[ -n "$val" ]] && export subpt="$val"

    # ========== 显示最终环境 ==========
    info "当前配置: argo=${argo:-<none>} vmpt=${vmpt:-<unset>} vwpt=${vwpt:-<unset>}"
    info "固定隧道参数: agn=${agn:-<none>} agk=${agk:-<none>}"

    if argosb_status_check; then
        rep_flag="rep"
        info "🔹 已安装，命令自动添加 rep"
    else
        rep_flag=""
        info "🟡 首次安装"
    fi

    info "🚀 正在执行 ArgoSB 主程序..."
    bash <(curl -Ls "$MAIN_SCRIPT") $rep_flag

    install_shortcut
    info "✅ 操作完成"
}

view_nodes() { $AGSX_CMD list || true; }
update_script() { bash <(curl -Ls "$MAIN_SCRIPT"); install_shortcut; info "脚本已更新"; }
restart_script() { $AGSX_CMD res || true; }
uninstall_script() { $AGSX_CMD del || true; rm -f "$AGSX_CMD"; info "脚本已卸载"; }
toggle_ipv4_ipv6() { read -rp "显示 IPv4 节点请输入4，IPv6请输入6: " ipver; export ippz="$ipver"; $AGSX_CMD list || true; }
change_port() { read -rp "请输入协议标识或变量名 (如 vmpt/vwpt/uuid): " proto; read -rp "请输入新的值: " port; export "$proto"="$port"; bash <(curl -Ls "$MAIN_SCRIPT"); }

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
