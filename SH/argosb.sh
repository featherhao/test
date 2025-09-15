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
# 默认主脚本 URL
SCRIPT_URL="https://raw.githubusercontent.com/yonggekkk/argosb/main/argosb.sh"
MAIN_SCRIPT_CMD="bash <(curl -Ls ${SCRIPT_URL})"

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
        "8) 更改协议端口" \
        "0) 返回主菜单"
    read -rp "请输入选项: " main_choice

    case "$main_choice" in
        1)
            declare -A protocol_status
            # Initialize all protocol statuses to "❌ 未安装" to prevent unbound variable errors
            for p in vlpt xhpt vxpt sspt anpt arpt vmpt hypt tupt; do
                protocol_status[$p]="❌ 未安装"
            done

            if [[ -f /etc/opt/ArgoSB/config.json ]]; then
                for p in "${!protocol_status[@]}"; do
                    grep -q "\"$p\"" /etc/opt/ArgoSB/config.json && protocol_status[$p]="✅ 已安装" || true
                done
            fi

            echo "请选择要新增的协议（可多选，用空格分隔，例如 1 3 5）:"
            echo "1) Vless-Reality-Vision (vlpt) ${protocol_status[vlpt]}"
            echo "2) Vless-Xhttp-Reality (xhpt) ${protocol_status[xhpt]}"
            echo "3) Vless-Xhttp (vxpt) ${protocol_status[vxpt]}"
            echo "4) Shadowsocks-2022 (sspt) ${protocol_status[sspt]}"
            echo "5) AnyTLS (anpt) ${protocol_status[anpt]}"
            echo "6) Any-Reality (arpt) ${protocol_status[arpt]}"
            echo "7) Vmess-ws (vmpt) ${protocol_status[vmpt]}"
            echo "8) Hysteria2 (hypt) ${protocol_status[hypt]}"
            echo "9) Tuic (tupt) ${protocol_status[tupt]}"
            echo "10) Argo临时隧道CDN优选节点 (vmpt+argo=y)"
            read -rp "输入序号: " choices

            NEW_VARS=""
            for c in $choices; do
                # 修复: 移除 local 关键字
                protocol_name=""
                case $c in
                    1) protocol_name="vlpt" ;;
                    2) protocol_name="xhpt" ;;
                    3) protocol_name="vxpt" ;;
                    4) protocol_name="sspt" ;;
                    5) protocol_name="anpt" ;;
                    6) protocol_name="arpt" ;;
                    7) protocol_name="vmpt" ;;
                    8) protocol_name="hypt" ;;
                    9) protocol_name="tupt" ;;
                    10) protocol_name="vmpt"; NEW_VARS="$NEW_VARS argo=\"y\"" ;;
                    *) echo "⚠️ 无效选项: $c" ;;
                esac

                if [[ -n "$protocol_name" ]]; then
                    read -rp "为 $protocol_name 输入端口号 (留空则随机): " custom_port
                    if [[ -n "$custom_port" ]]; then
                        NEW_VARS="$NEW_VARS $protocol_name=\"$custom_port\""
                    else
                        NEW_VARS="$NEW_VARS $protocol_name=\"\""
                    fi
                fi
            done

            if [[ -n "$NEW_VARS" ]]; then
                echo "🔹 正在增量更新节点..."
                eval "$NEW_VARS ${MAIN_SCRIPT_CMD} rep"
            else
                echo "⚠️ 未选择有效协议"
            fi
            read -rp "按回车返回菜单..." dummy
            ;;
        2)
            echo "🔹 正在显示节点信息..."
            eval "${MAIN_SCRIPT_CMD} list"
            read -rp "按回车返回菜单..." dummy
            ;;
        3)
            echo "👉 请输入自定义变量，例如：vlpt=\"\" sspt=\"\""
            read -rp "变量: " custom_vars
            if [[ -n "$custom_vars" ]]; then
                eval "$custom_vars ${MAIN_SCRIPT_CMD} rep"
            else
                echo "⚠️ 没有输入变量"
            fi
            read -rp "按回车返回菜单..." dummy
            ;;
        4)
            eval "${MAIN_SCRIPT_CMD} rep"
            read -rp "按回车返回菜单..." dummy
            ;;
        5)
            eval "${MAIN_SCRIPT_CMD} res"
            read -rp "按回车返回菜单..." dummy
            ;;
        6)
            eval "${MAIN_SCRIPT_CMD} del"
            read -rp "按回车返回菜单..." dummy
            ;;
        7)
            echo "1) 显示 IPv4 节点配置"
            echo "2) 显示 IPv6 节点配置"
            read -rp "请输入选项: " ip_choice
            if [[ "$ip_choice" == "1" ]]; then
                eval "ippz=4 ${MAIN_SCRIPT_CMD} list"
            elif [[ "$ip_choice" == "2" ]]; then
                eval "ippz=6 ${MAIN_SCRIPT_CMD} list"
            fi
            read -rp "按回车返回菜单..." dummy
            ;;
        8)
            echo "👉 请输入要更改端口的协议名和新端口号，格式为：[协议名]=[端口号]"
            echo "例如：vlpt=12345"
            read -rp "输入: " port_change_input
            if [[ -n "$port_change_input" ]]; then
                eval "$port_change_input ${MAIN_SCRIPT_CMD} rep"
                echo "🔹 端口修改已提交，正在重新加载服务..."
                eval "${MAIN_SCRIPT_CMD} res"
            else
                echo "⚠️ 输入为空，操作取消。"
            fi
            read -rp "按回车返回菜单..." dummy
            ;;
        0) break ;;
        *)
            echo "❌ 无效输入"
            sleep 1
            ;;
    esac
done