#!/bin/bash
set -Eeuo pipefail

SCRIPT_URL="https://raw.githubusercontent.com/yonggekkk/argosbx/main/argosbx.sh"

# ========== 彩色输出 ==========
C_RESET="\e[0m"; C_GREEN="\e[32m"; C_RED="\e[31m"; C_YELLOW="\e[33m"
log() { echo -e "${C_GREEN}[+] $*${C_RESET}"; }
warn() { echo -e "${C_YELLOW}[!] $*${C_RESET}"; }
err() { echo -e "${C_RED}[-] $*${C_RESET}"; }

show_menu() {
    clear
    echo "🚀 勇哥ArgoSB协议管理 ✅ 已安装"
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
}

add_protocols() {
    echo "请选择要添加或更新的协议（可多选，用空格分隔，例如 1 3 5）："
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

    read -rp "输入序号: " selections

    for choice in $selections; do
        NEW_VARS=""

        case $choice in
        1) protocol_name="vlpt";;
        2) protocol_name="xhpt";;
        3) protocol_name="vxpt";;
        4) protocol_name="sspt";;
        5) protocol_name="anpt";;
        6) protocol_name="arpt";;
        7) protocol_name="vmpt";;
        8) protocol_name="hypt";;
        9) protocol_name="tupt";;

        10)
            # 临时隧道
            protocol_name="vmpt"
            read -rp "为 vmpt 输入端口号 (可留空): " custom_port
            if [[ -z "$custom_port" ]]; then
                NEW_VARS="$protocol_name=\"\" argo=\"y\""
            else
                NEW_VARS="$protocol_name=\"$custom_port\" argo=\"y\""
            fi
            ;;

        11)
            # 固定隧道
            protocol_name="vmpt"
            while true; do
                read -rp "请输入 vmpt 端口号 (必填): " custom_port
                [[ -n "$custom_port" ]] && break
                echo "⚠️ 固定隧道 vmpt 端口不能为空！"
            done

            read -rp "请输入 Argo 固定隧道域名 (agn，必填): " agn
            read -rp "请输入 Argo 固定隧道 token (agk，必填): " agk

            if [[ -z "$agn" || -z "$agk" ]]; then
                err "❌ 固定隧道必须填写域名和 token，操作取消！"
                continue
            fi

            NEW_VARS="$protocol_name=\"$custom_port\" argo=\"y\" agn=\"$agn\" agk=\"$agk\""
            ;;

        *)
            warn "未知选项: $choice"
            ;;
        esac

        if [[ -n "$NEW_VARS" ]]; then
            log "🔹 正在更新节点..."
            eval "$NEW_VARS bash <(curl -Ls $SCRIPT_URL)"
        fi
    done
}

while true; do
    show_menu
    read -rp "请输入选项: " option
    case $option in
        1) add_protocols ;;
        2) agsbx list ;;
        3) bash <(curl -Ls $SCRIPT_URL) ;;
        4) agsbx res ;;
        5) agsbx del ;;
        6) agsbx v4v6 ;;
        7) agsbx port ;;
        0) exit 0 ;;
        *) warn "无效选项" ;;
    esac
    read -rp "按回车返回菜单..."
done
