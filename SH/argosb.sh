#!/bin/bash
# =========================
# 🚀 勇哥ArgosBX安装与管理菜单
# =========================
set -euo pipefail

MAIN_SCRIPT_URL="https://raw.githubusercontent.com/yonggekkk/argosbx/main/argosbx.sh"

# 检查curl或wget
download_cmd=""
if command -v curl &>/dev/null; then
    download_cmd="curl -Ls"
elif command -v wget &>/dev/null; then
    download_cmd="wget -qO-"
else
    echo "⚠️ 系统缺少 curl 或 wget，请先安装。"
    exit 1
fi

# 初始化变量
vlpt=""; xhpt=""; vxpt=""; sspt=""; anpt=""; arpt=""
vmpt=""; hypt=""; tupt=""; argo=""; agn=""; agk=""; uuid=""

# 生成随机UUID
uuid=$(cat /proc/sys/kernel/random/uuid)

function install_or_update_protocols() {
    echo ""
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

    for i in $choices; do
        case $i in
            1) read -rp "请输入 Vless-Reality-Vision 端口（留空随机）: " vlpt ;;
            2) read -rp "请输入 Vless-Xhttp-Reality 端口（留空随机）: " xhpt ;;
            3) read -rp "请输入 Vless-Xhttp 端口（留空随机）: " vxpt ;;
            4) read -rp "请输入 Shadowsocks-2022 端口（留空随机）: " sspt ;;
            5) read -rp "请输入 AnyTLS 端口（留空随机）: " anpt ;;
            6) read -rp "请输入 Any-Reality 端口（留空随机）: " arpt ;;
            7) read -rp "请输入 Vmess-ws 端口（留空随机）: " vmpt ;;
            8) read -rp "请输入 Hysteria2 端口（留空随机）: " hypt ;;
            9) read -rp "请输入 Tuic 端口（留空随机）: " tupt ;;
            10) argo="y"; echo "启用 Argo 临时隧道" ;;
            11) argo="y"; 
                read -rp "请输入 Argo固定隧道端口 (vmpt必须启用): " vmpt
                read -rp "请输入 Argo固定隧道域名 (agn): " agn
                read -rp "请输入 Argo固定隧道Token (agk): " agk ;;
            *) echo "无效选项: $i" ;;
        esac
    done

    # 组合变量
    vars=""
    [ -n "$vlpt" ] && vars+="vlpt=\"$vlpt\" "
    [ -n "$xhpt" ] && vars+="xhpt=\"$xhpt\" "
    [ -n "$vxpt" ] && vars+="vxpt=\"$vxpt\" "
    [ -n "$sspt" ] && vars+="sspt=\"$sspt\" "
    [ -n "$anpt" ] && vars+="anpt=\"$anpt\" "
    [ -n "$arpt" ] && vars+="arpt=\"$arpt\" "
    [ -n "$vmpt" ] && vars+="vmpt=\"$vmpt\" "
    [ -n "$hypt" ] && vars+="hypt=\"$hypt\" "
    [ -n "$tupt" ] && vars+="tupt=\"$tupt\" "
    [ -n "$argo" ] && vars+="argo=\"$argo\" "
    [ -n "$agn" ] && vars+="agn=\"$agn\" "
    [ -n "$agk" ] && vars+="agk=\"$agk\" "
    [ -n "$uuid" ] && vars+="uuid=\"$uuid\" "

    echo ""
    echo "==============================="
    echo "正在执行 Argosbx 主脚本..."
    bash <($download_cmd $MAIN_SCRIPT_URL)
    echo "安装或更新完成！"
}

function show_menu() {
    echo ""
    echo "🚀 勇哥ArgoSB协议管理"
    echo "==============================="
    echo "1) 添加或更新协议节点"
    echo "2) 查看节点信息 (agsbx list)"
    echo "3) 更新脚本 (建议卸载重装)"
    echo "4) 重启脚本 (agsbx res)"
    echo "5) 卸载脚本 (agsbx del)"
    echo "6) 临时切换 IPv4 / IPv6 节点显示"
    echo "7) 更改协议端口"
    echo "0) 退出"
    echo "==============================="
}

while true; do
    show_menu
    read -rp "请选择操作: " op
    case $op in
        1) install_or_update_protocols ;;
        2) agsbx list ;;
        3) bash <($download_cmd $MAIN_SCRIPT_URL) ;;
        4) agsbx res ;;
        5) agsbx del ;;
        6)
            read -rp "输入 4 查看IPv4节点，输入6查看IPv6节点: " ippz
            ippz="$ippz" agsbx list
            ;;
        7)
            echo "⚠️ 更改端口请重新运行安装更新协议功能"
            install_or_update_protocols
            ;;
        0) echo "退出脚本"; exit 0 ;;
        *) echo "无效选项" ;;
    esac
done
