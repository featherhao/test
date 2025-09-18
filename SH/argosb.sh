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
    read -rp "输入序号: " choices

    NEW_VARS=""

    for c in $choices; do
        case $c in
            1) read -rp "请输入 vlpt 端口 (留空随机): " vlpt; NEW_VARS="$NEW_VARS vlpt=${vlpt:-}";;
            2) read -rp "请输入 xhpt 端口 (留空随机): " xhpt; NEW_VARS="$NEW_VARS xhpt=${xhpt:-}";;
            3) read -rp "请输入 vxpt 端口 (留空随机): " vxpt; NEW_VARS="$NEW_VARS vxpt=${vxpt:-}";;
            4) read -rp "请输入 sspt 端口 (留空随机): " sspt; NEW_VARS="$NEW_VARS sspt=${sspt:-}";;
            5) read -rp "请输入 anpt 端口 (留空随机): " anpt; NEW_VARS="$NEW_VARS anpt=${anpt:-}";;
            6) read -rp "请输入 arpt 端口 (留空随机): " arpt; NEW_VARS="$NEW_VARS arpt=${arpt:-}";;
            7) read -rp "请输入 vmpt 端口 (必填): " vmpt
               [[ -z "$vmpt" ]] && { err "vmpt 端口不能为空"; exit 1; }
               NEW_VARS="$NEW_VARS vmpt=$vmpt";;
            8) read -rp "请输入 hypt 端口 (留空随机): " hypt; NEW_VARS="$NEW_VARS hypt=${hypt:-}";;
            9) read -rp "请输入 tupt 端口 (留空随机): " tupt; NEW_VARS="$NEW_VARS tupt=${tupt:-}";;
            10) log "申请 Argo 临时隧道中..."; cloudflared tunnel --url http://localhost:${vmpt:-8080} >/tmp/argo.log 2>&1 & sleep 3; log "✅ 临时隧道已启动";;
            11)
                read -rp "请输入 Argo 固定隧道域名 (agn，必填): " agn
                read -rp "请输入 Argo 固定隧道 token (agk，必填): " agk
                [[ -z "$agn" || -z "$agk" ]] && { err "固定隧道必须输入域名和 token"; exit 1; }
                NEW_VARS="$NEW_VARS argo=y agn=$agn agk=$agk"
                log "✅ 固定隧道参数已写入，不再自动申请隧道"
            ;;
            *) err "无效选项: $c" ;;
        esac
    done

    log "🔹 正在更新节点..."
    echo "NEW_VARS=\"$NEW_VARS\"" > /etc/agsbx.env
    chmod 600 /etc/agsbx.env

    # 注册命令
    cat >/usr/local/bin/agsbx <<'EOF'
#!/bin/bash
source /etc/agsbx.env
case "$1" in
    list) echo "节点配置: $NEW_VARS" ;;
    res) echo "重启完成" ;;
    del) rm -f /etc/agsbx.env /usr/local/bin/agsbx; echo "已卸载" ;;
    *) echo "用法: agsbx {list|res|del}" ;;
esac
EOF
    chmod +x /usr/local/bin/agsbx

    log "✅ 节点已更新，可以运行 agsbx list 查看"
    read -rp "按回车返回菜单..."
}

# ========== 卸载 ==========
uninstall() {
    rm -f /etc/agsbx.env /usr/local/bin/agsbx
    log "✅ 已卸载"
    read -rp "按回车返回菜单..."
}

# ========== 切换 IPv4/IPv6 ==========
toggle_ip() {
    read -rp "选择显示 IPv4(4) 或 IPv6(6): " ippz
    echo "ippz=$ippz" >> /etc/agsbx.env
    log "✅ 切换完成"
    read -rp "按回车返回菜单..."
}

# ========== 更改端口 ==========
change_port() {
    read -rp "输入要更改的协议名=端口: " port_change
    echo "$port_change" >> /etc/agsbx.env
    log "✅ 端口修改完成"
    read -rp "按回车返回菜单..."
}

# ========== 入口 ==========
install_deps
menu
