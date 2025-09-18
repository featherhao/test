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
# 默认主脚本 URL (你提供的新地址)
SCRIPT_URL="https://raw.githubusercontent.com/yonggekkk/argosbx/refs/heads/main/argosbx.sh"

# ------- 辅助：下载并校验主脚本 -------
download_script() {
    local url="$SCRIPT_URL"
    local tmp
    tmp=$(mktemp -t argosbx.XXXXXX) || return 1
    # -f 失败时返回非 0，-s 静默，-S 显示错误（只在失败时）
    if ! curl -fsSL "$url" -o "$tmp"; then
        echo -e "${C_RED}错误：下载主脚本失败：${url}${C_RESET}"
        rm -f "$tmp"
        return 2
    fi
    # 快速检查：如果是 HTML（404 页面）就报错并打印前几行
    if head -n1 "$tmp" | grep -qiE '^<!DOCTYPE html>|<html|404 Not Found|Not Found'; then
        echo -e "${C_RED}错误：下载内容看起来像 HTML/404，不是脚本，请检查 URL:${C_RESET} $url"
        sed -n '1,12p' "$tmp"
        rm -f "$tmp"
        return 3
    fi
    echo "$tmp"
}

# run_main_with_env <env-assignments...> -- <script-args...>
# 例: run_main_with_env vlpt=123 argo=y -- rep
run_main_with_env() {
    local env_args=()
    # collect env args until --
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --) shift; break ;;
            *) env_args+=("$1"); shift ;;
        esac
    done
    local script_args=("$@")
    local script_file
    script_file="$(download_script)" || return $?
    # Debug print (只在 DEBUG=1 时)
    if [[ "${DEBUG:-0}" -eq 1 ]]; then
        echo -e "${C_CYAN}>>> Running main script with env: ${env_args[*]} args: ${script_args[*]}${C_RESET}"
    fi
    if [[ ${#env_args[@]} -gt 0 ]]; then
        env "${env_args[@]}" bash "$script_file" "${script_args[@]}"
    else
        bash "$script_file" "${script_args[@]}"
    fi
    local rc=$?
    rm -f "$script_file"
    return $rc
}

# ------- 更健壮的安装检测：检查多个可能命令名 -------
detect_installed() {
    local names=("agsbx" "argosbx" "agsb" "argosb")
    for n in "${names[@]}"; do
        if command -v "$n" &>/dev/null; then
            echo "$n"
            return 0
        fi
    done
    return 1
}

installed_cmd="$(detect_installed 2>/dev/null || true)"
if [[ -n "$installed_cmd" ]]; then
    argosb_status="✅ 已安装 (${installed_cmd})"
else
    argosb_status="❌ 未安装"
fi

# ---------------- 主菜单循环 ----------------
while true; do
    render_menu "🚀 勇哥ArgoSB协议管理 $argosb_status" \
        "1) 添加或更新协议节点" \
        "2) 查看节点信息 (list)" \
        "3) 更新脚本 (建议卸载重装)" \
        "4) 重启脚本 (res)" \
        "5) 卸载脚本 (del)" \
        "6) 临时切换 IPv4 / IPv6 节点显示" \
        "7) 更改协议端口" \
        "0) 返回主菜单"
    read -rp "请输入选项: " main_choice

    case "$main_choice" in
        1)
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
            echo "10) Argo临时隧道CDN优选节点 (vmpt+argo=y)"
            read -rp "输入序号: " choices

            NEW_ENV=()
            for c in $choices; do
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
                    10) protocol_name="vmpt"; NEW_ENV+=("argo=y") ;;
                    *) echo "⚠️ 无效选项: $c" ;;
                esac

                if [[ -n "$protocol_name" ]]; then
                    read -rp "为 $protocol_name 输入端口号 (留空则随机): " custom_port
                    # 注意：env 参数采用 KEY=VALUE 的形式（不带额外引号）
                    if [[ -n "$custom_port" ]]; then
                        NEW_ENV+=("$protocol_name=$custom_port")
                    else
                        NEW_ENV+=("$protocol_name=")
                    fi
                fi
            done

            if [[ ${#NEW_ENV[@]} -gt 0 ]]; then
                echo "🔹 正在更新节点..."
                if ! run_main_with_env "${NEW_ENV[@]}" -- rep; then
                    echo -e "${C_RED}❌ 更新节点失败，请查看上方错误输出或启用 DEBUG=1 重试。${C_RESET}"
                fi
                # 更新安装检测（若脚本改变了命令名）
                installed_cmd="$(detect_installed 2>/dev/null || true)"
                if [[ -n "$installed_cmd" ]]; then argosb_status="✅ 已安装 (${installed_cmd})"; else argosb_status="❌ 未安装"; fi
            else
                echo "⚠️ 未选择有效协议"
            fi
            read -rp "按回车返回菜单..." dummy
            ;;
        2)
            echo "🔹 正在显示节点信息..."
            if ! run_main_with_env -- list; then
                echo -e "${C_RED}❌ 执行 list 失败，请检查网络或主脚本输出。${C_RESET}"
            fi
            read -rp "按回车返回菜单..." dummy
            ;;
        3)
            echo "🔹 正在更新脚本，此操作会重新加载最新配置..."
            if ! run_main_with_env -- rep; then
                echo -e "${C_RED}❌ 更新失败（rep）。${C_RESET}"
            fi
            read -rp "按回车返回菜单..." dummy
            ;;
        4)
            if ! run_main_with_env -- res; then
                echo -e "${C_RED}❌ 重启失败（res）。${C_RESET}"
            fi
            read -rp "按回车返回菜单..." dummy
            ;;
        5)
            if ! run_main_with_env -- del; then
                echo -e "${C_RED}❌ 卸载失败（del）。${C_RESET}"
            fi
            read -rp "按回车返回菜单..." dummy
            ;;
        6)
            echo "1) 显示 IPv4 节点配置"
            echo "2) 显示 IPv6 节点配置"
            read -rp "请输入选项: " ip_choice
            if [[ "$ip_choice" == "1" ]]; then
                run_main_with_env ippz=4 -- list || echo -e "${C_RED}执行失败。${C_RESET}"
            elif [[ "$ip_choice" == "2" ]]; then
                run_main_with_env ippz=6 -- list || echo -e "${C_RED}执行失败。${C_RESET}"
            else
                echo "❌ 无效输入"
            fi
            read -rp "按回车返回菜单..." dummy
            ;;
        7)
            echo "👉 请输入要更改端口的协议名和新端口号，格式为：protocol=port（可空格分隔多个）"
            echo "⚠️ 注意：该操作会覆盖现有配置，请确保输入所有需要保留的协议。"
            read -rp "输入: " port_change_input
            if [[ -n "$port_change_input" ]]; then
                PORT_ARGS=()
                for p in $port_change_input; do
                    PORT_ARGS+=("$p")
                done
                if run_main_with_env "${PORT_ARGS[@]}" -- rep; then
                    echo "🔹 端口修改已提交，正在重新加载服务..."
                    run_main_with_env -- res || echo -e "${C_RED}重载失败（res）。${C_RESET}"
                else
                    echo -e "${C_RED}端口修改提交失败（rep）。${C_RESET}"
                fi
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
