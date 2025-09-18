#!/bin/bash
set -euo pipefail

SCRIPT_URL="https://raw.githubusercontent.com/yonggekkk/argosbx/main/argosbx.sh"

# ========== 彩色输出 ==========
C_RESET="\e[0m"; C_GREEN="\e[32m"; C_RED="\e[31m"; C_YELLOW="\e[33m"; C_BLUE="\e[34m"
log() { echo -e "${C_GREEN}[+]${C_RESET} $*"; }
warn() { echo -e "${C_YELLOW}[!]${C_RESET} $*"; }
err() { echo -e "${C_RED}[-]${C_RESET} $*" >&2; }

# ========== 协议管理 ==========
add_or_update_protocol() {
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

  for choice in $choices; do
    case "$choice" in
      1) read -rp "请输入 vlpt 端口号: " vlpt; NEW_VARS+=" vlpt=\"$vlpt\"" ;;
      2) read -rp "请输入 xhpt 端口号: " xhpt; NEW_VARS+=" xhpt=\"$xhpt\"" ;;
      3) read -rp "请输入 vxpt 端口号: " vxpt; NEW_VARS+=" vxpt=\"$vxpt\"" ;;
      4) read -rp "请输入 sspt 端口号: " sspt; NEW_VARS+=" sspt=\"$sspt\"" ;;
      5) read -rp "请输入 anpt 端口号: " anpt; NEW_VARS+=" anpt=\"$anpt\"" ;;
      6) read -rp "请输入 arpt 端口号: " arpt; NEW_VARS+=" arpt=\"$arpt\"" ;;
      7) read -rp "请输入 vmpt 端口号: " vmpt; NEW_VARS+=" vmpt=\"$vmpt\"" ;;
      8) read -rp "请输入 hypt 端口号: " hypt; NEW_VARS+=" hypt=\"$hypt\"" ;;
      9) read -rp "请输入 tupt 端口号: " tupt; NEW_VARS+=" tupt=\"$tupt\"" ;;
      10) read -rp "请输入 vmpt 端口号 (必填): " vmpt; NEW_VARS+=" vmpt=\"$vmpt\" argo=\"y\"" ;;
      11)
        read -rp "请输入 vmpt 端口号 (必填): " vmpt
        read -rp "请输入 Argo 固定隧道域名 (agn，必填): " agn
        read -rp "请输入 Argo 固定隧道 token (agk，必填): " agk
        if [[ -z "$vmpt" || -z "$agn" || -z "$agk" ]]; then
          err "❌ 固定隧道必须填写 vmpt / agn / agk"
          return 1
        fi
        NEW_VARS+=" vmpt=\"$vmpt\" argo=\"y\" agn=\"$agn\" agk=\"$agk\""
        ;;
      *) warn "无效选项: $choice" ;;
    esac
  done

  log "🔹 正在更新节点..."
  eval $NEW_VARS bash <(curl -Ls $SCRIPT_URL)
}

# ========== 主菜单 ==========
main_menu() {
  while true; do
    clear
    echo -e "🚀 勇哥ArgoSB协议管理 ✅ 已安装"
    echo "=============================="
    echo "1) 添加或更新协议节点"
    echo "2) 查看节点信息"
    echo "3) 更新脚本 (建议卸载重装)"
    echo "4) 重启脚本"
    echo "5) 卸载脚本"
    echo "6) 临时切换 IPv4 / IPv6 节点显示"
    echo "7) 更改协议端口"
    echo "0) 退出"
    echo "=============================="
    read -rp "请输入选项: " choice

    case "$choice" in
      1) add_or_update_protocol ;;
      2) bash <(curl -Ls $SCRIPT_URL) list ;;
      3) bash <(curl -Ls $SCRIPT_URL) rep ;;
      4) bash <(curl -Ls $SCRIPT_URL) res ;;
      5) bash <(curl -Ls $SCRIPT_URL) del ;;
      6)
        echo "1) 显示 IPv4 节点"
        echo "2) 显示 IPv6 节点"
        read -rp "请选择: " ip_choice
        if [[ "$ip_choice" == "1" ]]; then
          ippz=4 bash <(curl -Ls $SCRIPT_URL) list
        else
          ippz=6 bash <(curl -Ls $SCRIPT_URL) list
        fi
        ;;
      7) bash <(curl -Ls $SCRIPT_URL) port ;;
      0) exit 0 ;;
      *) err "❌ 无效选项" ;;
    esac
    read -rp "按回车键返回菜单..."
  done
}

main_menu
