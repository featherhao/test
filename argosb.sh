#!/bin/bash
set -Eeuo pipefail

# ================== 彩色与日志 ==================
if [[ -t 1 ]] && command -v tput &>/dev/null; then
    C_RESET="\e[0m"; C_BOLD="\e[1m"
    C_GREEN="\e[32m"; C_RED="\e[31m"; C_YELLOW="\e[33m"; C_BLUE="\e[34m"; C_CYAN="\e[36m"
else
    C_RESET=""; C_BOLD=""; C_GREEN=""; C_RED=""; C_YELLOW=""; C_BLUE=""; C_CYAN=""
fi

print_header() {
    local title="$1"
    echo -e "${C_BOLD}==============================${C_RESET}"
    echo -e "  ${C_BOLD}${title}${C_RESET}"
    echo -e "${C_BOLD}==============================${C_RESET}"
}

render_menu() {
    local title="$1"; shift
    clear
    print_header "$title"
    local item
    for item in "$@"; do
        echo -e "$item"
    done
    echo "=============================="
}

# ================== 勇哥ArgoSB菜单 ==================
if command -v agsb &>/dev/null; then
    argosb_status="✅ 已安装"
else
    argosb_status="❌ 未安装"
fi

while true; do
    render_menu "🚀 勇哥ArgoSB协议管理 $argosb_status" \
        "1) 增量添加协议节点" \
        "2) 查看节点信息 (agsb list)" \
        "3) 手动更换协议变量组 (自定义变量 → agsb rep)" \
        "4) 更新脚本 (建议卸载重装)" \
        "5) 重启脚本 (agsb res)" \
        "6) 卸载脚本 (agsb del)" \
        "7) 临时切换 IPv4 / IPv6 节点显示" \
        "0) 返回主菜单"
    read -rp "请输入选项: " main_choice

    case "$main_choice" in
        1)
            declare -A protocol_status
            [[ -f /etc/opt/ArgoSB/config.json ]] && {
                for p in vlpt xhpt sspt anpt arpt vmpt hypt tupt; do
                    grep -q "$p" /etc/opt/ArgoSB/config.json && protocol_status[$p]="✅ 已安装" || protocol_status[$p]="❌ 未安装"
                done
            }

            echo "请选择要新增的协议（可多选，用空格分隔，例如 1 3 5）:"
            echo "1) Vless-Reality-Vision (vlpt) ${protocol_status[vlpt]}"
            echo "2) Vless-Xhttp-Reality (xhpt) ${protocol_status[xhpt]}"
            echo "3) Shadowsocks-2022 (sspt) ${protocol_status[sspt]}"
            echo "4) AnyTLS (anpt) ${protocol_status[anpt]}"
            echo "5) Any-Reality (arpt) ${protocol_status[arpt]}"
            echo "6) Vmess-ws (vmpt) ${protocol_status[vmpt]}"
            echo "7) Hysteria2 (hypt) ${protocol_status[hypt]}"
            echo "8) Tuic (tupt) ${protocol_status[tupt]}"
            echo "9) Argo临时隧道CDN优选节点 (vmpt+argo=y)"
            read -rp "输入序号: " choices

            NEW_VARS=""
            for c in $choices; do
                case $c in
                    1) NEW_VARS="$NEW_VARS vlpt=\"\"" ;;
                    2) NEW_VARS="$NEW_VARS xhpt=\"\"" ;;
                    3) NEW_VARS="$NEW_VARS sspt=\"\"" ;;
                    4) NEW_VARS="$NEW_VARS anpt=\"\"" ;;
                    5) NEW_VARS="$NEW_VARS arpt=\"\"" ;;
                    6) NEW_VARS="$NEW_VARS vmpt=\"\"" ;;
                    7) NEW_VARS="$NEW_VARS hypt=\"\"" ;;
                    8) NEW_VARS="$NEW_VARS tupt=\"\"" ;;
                    9) NEW_VARS="$NEW_VARS vmpt=\"\" argo=\"y\"" ;;
                esac
            done

            if [[ -n "$NEW_VARS" ]]; then
                echo "🔹 正在增量更新节点..."
                eval "$NEW_VARS bash <(curl -Ls https://raw.githubusercontent.com/yonggekkk/argosb/main/argosb.sh) rep"
            else
                echo "⚠️ 未选择有效协议"
            fi
            read -rp "按回车返回菜单..." dummy
            ;;
        2)
            echo "🔹 正在显示节点信息..."
            if command -v agsb &>/dev/null; then
                eval "agsb list"
            else
                eval "bash <(curl -Ls https://raw.githubusercontent.com/yonggekkk/argosb/main/argosb.sh) list"
            fi
            read -rp "按回车返回菜单..." dummy
            ;;
        3)
            echo "👉 请输入自定义变量，例如：vlpt=\"\" sspt=\"\""
            read -rp "变量: " custom_vars
            if [[ -n "$custom_vars" ]]; then
                eval "$custom_vars bash <(curl -Ls https://raw.githubusercontent.com/yonggekkk/argosb/main/argosb.sh) rep"
            else
                echo "⚠️ 没有输入变量"
            fi
            read -rp "按回车返回菜单..." dummy
            ;;
        4)
            eval "agsb rep || bash <(curl -Ls https://raw.githubusercontent.com/yonggekkk/argosb/main/argosb.sh) rep"
            read -rp "按回车返回菜单..." dummy
            ;;
        5)
            eval "agsb res || bash <(curl -Ls https://raw.githubusercontent.com/yonggekkk/argosb/main/argosb.sh) res"
            read -rp "按回车返回菜单..." dummy
            ;;
        6)
            eval "agsb del || bash <(curl -Ls https://raw.githubusercontent.com/yonggekkk/argosb/main/argosb.sh) del"
            read -rp "按回车返回菜单..." dummy
            ;;
        7)
            echo "1) 显示 IPv4 节点配置"
            echo "2) 显示 IPv6 节点配置"
            read -rp "请输入选项: " ip_choice
            [[ "$ip_choice" == "1" ]] && eval "ippz=4 agsb list"
            [[ "$ip_choice" == "2" ]] && eval "ippz=6 agsb list"
            read -rp "按回车返回菜单..." dummy
            ;;
        0) break ;;
        *)
            echo "❌ 无效输入"
            sleep 1
            ;;
    esac
done
