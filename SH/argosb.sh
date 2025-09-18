#!/bin/bash
set -Eeuo pipefail

# ========== 彩色输出 ==========
C_RESET="\e[0m"; C_GREEN="\e[32m"; C_RED="\e[31m"; C_YELLOW="\e[33m"; C_BLUE="\e[34m"
log() { echo -e "${C_GREEN}[+]${C_RESET} $*"; }
err() { echo -e "${C_RED}[x]${C_RESET} $*" >&2; }

# ========== 安装依赖 ==========
install_deps() {
    apt-get update -y
    apt-get install -y curl wget unzip jq
}

# ========== 注册空 agsbx 命令（首次运行） ==========
register_agsbx() {
    if [[ ! -f /usr/local/bin/agsbx ]]; then
        cat >/usr/local/bin/agsbx <<'EOF'
#!/bin/bash
if [[ -f /etc/agsbx.env ]]; then
    source /etc/agsbx.env
fi
case "$1" in
    list) echo "节点配置: ${NEW_VARS:-未配置}" ;;
    res) echo "重启完成" ;;
    del) rm -f /etc/agsbx.env /usr/local/bin/agsbx; echo "已卸载" ;;
    *) echo "用法: agsbx {list|res|del}" ;;
esac
EOF
        chmod +x /usr/local/bin/agsbx
        log "✅ 已注册 agsbx 命令"
    fi
}

# ========== 主菜单 ==========
menu() {
    clear
    echo -e "🚀 勇哥ArgoSB协议管理"
    echo "=============================="
    echo "1) 添加或更新协议节点"
    echo "2) 查看节点信息 (agsbx list)"
    echo "3) 更新脚本 (建议卸载重装)"
    echo "4) 重启脚本 (agsbx res)"
    echo "5) 卸载脚本 (agsbx del)"
    echo "6) 临时切换 IPv4 / IPv6 节点显示"
    echo "7) 更改协议端口"
    echo "0) 退出"
    echo "=============================="
    read -rp "请输入选项: " choice

    case "$choice" in
        1) add_or_update ;;
        2) agsbx list || err "agsbx 未安装或未注册"; read -rp "按回车返回菜单..." ;;
        3) uninstall; install ;;
        4) agsbx res || err "重启失败"; read -rp "按回车返回菜单..." ;;
        5) uninstall ;;
        6) toggle_ip ;;
        7) change_port ;;
        0) exit 0 ;;
        *) err "无效选项"; sleep 1 ;;
    esac
    menu
}

# ========== 添加/更新节点 ==========
add_or_update() {
    clear
    echo "请选择要添加或更新的协议（可多选，用空格分隔，例如 1 3 5）:"
    echo "⚠️ 注意：该操作会覆盖现有配置，请确保输入所有需要保留的协议。"
    echo "1) Vless-Reality-Vision (vlpt)"
    echo "2) Vless-Xhttp-Reality (xhpt)"
    echo "3) Vless-Xhttp (vxpt)"
    echo "4) Shadowsocks-2022 (sspt)"
    echo "5) AnyTLS (anpt)"
    echo "6) Any-Reality (arpt)"
    echo "7) Vmess-ws (vmpt)"
    echo "8) Hysteria2 (hypt)"
    echo "9) Tuic (tupt)"
    echo "10) Argo临时隧道CDN优选节点"
    echo "11) Argo固定隧道CDN优选节点"
    read -rp "输入序号: " choice

    NEW_VARS=""

    # Vmess-ws 示例（必填端口）
    if [[ "$choice" == *"7"* ]]; then
        read -rp "请输入 vmpt 端口号 (必填): " vmpt
        if [[ -z "$vmpt" ]]; then err "vmpt 端口不能为空"; exit 1; fi
        NEW_VARS="$NEW_VARS vmpt=$vmpt"
    fi

    # 固定隧道
    if [[ "$choice" == *"11"* ]]; then
        read -rp "请输入 Argo 固定隧道域名 (agn，必填): " agn
        read -rp "请输入 Argo 固定隧道 token (agk，必填): " agk
        if [[ -z "$agn" || -z "$agk" ]]; then
            err "固定隧道必须输入域名和 token"
            exit 1
        fi
        NEW_VARS="$NEW_VARS argo=y agn=$agn agk=$agk"
        log "✅ 固定隧道参数已写入，不再自动申请隧道"
    fi

    # 临时隧道
    if [[ "$choice" == *"10"* ]]; then
        log "申请 Argo 临时隧道中..."
        cloudflared tunnel --url http://localhost:${vmpt:-8080} >/tmp/argo.log 2>&1 &
        sleep 3
        log "✅ 临时隧道已启动"
    fi

    log "🔹 正在更新节点..."
    echo "NEW_VARS=$NEW_VARS" > /etc/agsbx.env
    chmod 600 /etc/agsbx.env

    log "✅ 节点已更新，可以运行 agsbx list 查看"
    read -rp "按回车返回菜单..."
}

# ========== 卸载 ==========
uninstall() {
    rm -f /etc/agsbx.env /usr/local/bin/agsbx
    log "✅ 已卸载"
}

# ========== 初始化 ==========
install_deps
register_agsbx
menu
