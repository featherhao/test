#!/bin/bash
set -Eeuo pipefail

# 统一失败处理
trap 'status=$?; line=${BASH_LINENO[0]}; echo "❌ 发生错误 (exit=$status) at line $line" >&2; exit $status' ERR

# ================== 基础配置 ==================
SCRIPT_URL="https://raw.githubusercontent.com/featherhao/test/refs/heads/main/menu.sh"
SCRIPT_PATH="$HOME/menu.sh"

# ================== 彩色与日志 ==================
if [[ -t 1 ]] && command -v tput &>/dev/null; then
  C_RESET="\e[0m"; C_BOLD="\e[1m"
  C_GREEN="\e[32m"; C_RED="\e[31m"; C_YELLOW="\e[33m"; C_BLUE="\e[34m"; C_CYAN="\e[36m"
else
  C_RESET=""; C_BOLD=""; C_GREEN=""; C_RED=""; C_YELLOW=""; C_BLUE=""; C_CYAN=""
fi

info()  { echo -e "${C_CYAN}[*]${C_RESET} $*"; }
warn()  { echo -e "${C_YELLOW}[!]${C_RESET} $*"; }
error() { echo -e "${C_RED}[x]${C_RESET} $*"; }

print_header() {
  local title="$1"
  echo -e "${C_BOLD}==============================${C_RESET}"
  echo -e "  ${C_BOLD}${title}${C_RESET}"
  echo -e "${C_BOLD}==============================${C_RESET}"
}

render_menu() {
  # 参数：标题；其余为菜单项数组（每项一行已拼好字符串）
  local title="$1"; shift
  clear
  print_header "$title"
  local item
  for item in "$@"; do
    echo -e "$item"
  done
  echo "=============================="
}

# 统一网络获取封装（带超时与重试）
fetch() {
  curl -fsSL --retry 3 --retry-delay 1 --connect-timeout 5 --max-time 30 "$@"
}

run_url() {
  bash <(fetch "$1")
}

# ================== 自我初始化逻辑 ==================
if [[ "$0" == "/dev/fd/"* ]] || [[ "$0" == "bash" ]]; then
  echo "⚡ 检测到你是通过 <(curl …) 临时运行的"
  echo "👉 正在自动保存 menu.sh 到 $SCRIPT_PATH"
  curl -fsSL "${SCRIPT_URL}?t=$(date +%s)" -o "$SCRIPT_PATH"
  chmod +x "$SCRIPT_PATH"
  echo "✅ 已保存，下次可直接执行：bash ~/menu.sh 或 q"
  sleep 2
fi

# ================== docker compose 兼容 ==================
if command -v docker-compose &>/dev/null; then
  COMPOSE="docker-compose"
else
  COMPOSE="docker compose"
fi

# Panso/zjsync 状态改为在主循环动态检测
# ================== 子脚本路径 ==================
WORKDIR_MOONTV="/opt/moontv"
MOONTV_SCRIPT="https://raw.githubusercontent.com/featherhao/test/refs/heads/main/mootvinstall.sh"

WORKDIR_RUSTDESK="/opt/rustdesk"
RUSTDESK_SCRIPT="https://raw.githubusercontent.com/featherhao/test/refs/heads/main/install_rustdesk.sh"

WORKDIR_LIBRETV="/opt/libretv"
LIBRETV_SCRIPT="https://raw.githubusercontent.com/featherhao/test/refs/heads/main/install_libretv.sh"

ZJSYNC_SCRIPT="https://raw.githubusercontent.com/featherhao/test/refs/heads/main/zjsync.sh"
NGINX_SCRIPT="https://raw.githubusercontent.com/featherhao/test/refs/heads/main/nginx"

# ================== 调用子脚本 ==================
moon_menu() { bash <(curl -fsSL --retry 3 --retry-delay 1 --connect-timeout 5 --max-time 30 "${MOONTV_SCRIPT}?t=$(date +%s)"); }
rustdesk_menu() { bash <(curl -fsSL --retry 3 --retry-delay 1 --connect-timeout 5 --max-time 30 "${RUSTDESK_SCRIPT}?t=$(date +%s)"); }
libretv_menu() { bash <(curl -fsSL --retry 3 --retry-delay 1 --connect-timeout 5 --max-time 30 "${LIBRETV_SCRIPT}?t=$(date +%s)"); }
singbox_menu() { bash <(curl -fsSL --retry 3 --retry-delay 1 --connect-timeout 5 --max-time 30 https://raw.githubusercontent.com/yonggekkk/sing-box-yg/main/sb.sh); }
nginx_menu() { bash <(curl -fsSL --retry 3 --retry-delay 1 --connect-timeout 5 --max-time 30 "${NGINX_SCRIPT}?t=$(date +%s)"); }

panso_menu() {
    bash <(curl -fsSL --retry 3 --retry-delay 1 --connect-timeout 5 --max-time 30 https://raw.githubusercontent.com/featherhao/test/refs/heads/main/pansou.sh)
}


zjsync_menu() {
  bash <(curl -fsSL --retry 3 --retry-delay 1 --connect-timeout 5 --max-time 30 "${ZJSYNC_SCRIPT}?t=$(date +%s)")
}

# ================== 勇哥ArgoSB菜单 ==================
argosb_menu() {
  # 动态检测安装状态
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
        # 检测已安装协议
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
}

# ================== 更新菜单脚本 ==================
update_menu_script() {
  echo "🔄 正在更新 menu.sh..."
  curl -fsSL --retry 3 --retry-delay 1 --connect-timeout 5 --max-time 30 "${SCRIPT_URL}?t=$(date +%s)" -o "$SCRIPT_PATH"
  chmod +x "$SCRIPT_PATH"
  echo "✅ menu.sh 已更新到 $SCRIPT_PATH"
  echo "👉 以后可直接执行：bash ~/menu.sh 或 q"
  sleep 2
}

# ================== 设置快捷键 Q/q ==================
set_q_shortcut() {
  SHELL_RC="$HOME/.bashrc"
  [ -n "$ZSH_VERSION" ] && SHELL_RC="$HOME/.zshrc"

  sed -i '/alias Q=/d' "$SHELL_RC"
  sed -i '/alias q=/d' "$SHELL_RC"

  echo "alias Q='bash ~/menu.sh'" >> "$SHELL_RC"
  echo "alias q='bash ~/menu.sh'" >> "$SHELL_RC"
  echo "⚡ 请执行 'source $SHELL_RC' 或重启终端生效"
  sleep 2
}

# ================== 主菜单 ==================
while true; do
  # 动态检测安装状态
  [[ -d /opt/moontv ]] && moon_status="✅ 已安装" || moon_status="❌ 未安装"
  [[ -d /opt/rustdesk ]] && rustdesk_status="✅ 已安装" || rustdesk_status="❌ 未安装"
  [[ -d /opt/libretv ]] && libretv_status="✅ 已安装" || libretv_status="❌ 未安装"
  if command -v sing-box &>/dev/null || command -v sb &>/dev/null; then
    singbox_status="✅ 已安装"
  else
    singbox_status="❌ 未安装"
  fi
  if command -v agsb &>/dev/null || [[ -f /etc/opt/ArgoSB/config.json ]]; then
    argosb_status="✅ 已安装"
  else
    argosb_status="❌ 未安装"
  fi
  # 动态检测 Panso 与 zjsync 状态
  if docker ps -a --format '{{.Names}}' | grep -q "^pansou-web$"; then
      panso_status="✅ 已安装"
  else
      panso_status="❌ 未安装"
  fi
  if [[ -f /etc/zjsync.conf ]]; then
    zjsync_status="✅ 已配置"
  else
    zjsync_status="❌ 未配置"
  fi
  kejilion_status="⚡ 远程调用"
  nginx_status="⚡ 远程调用"

  render_menu "🚀 服务管理中心" \
    "1) MoonTV 管理  $moon_status" \
    "2) RustDesk 管理  $rustdesk_status" \
    "3) LibreTV 安装  $libretv_status" \
    "4) 甬哥Sing-box-yg管理  $singbox_status" \
    "5) 勇哥ArgoSB脚本  $argosb_status" \
    "6) Kejilion.sh 一键脚本工具箱  $kejilion_status" \
    "7) zjsync（GitHub 文件自动同步）  $zjsync_status" \
    "8) Panso 管理  $panso_status" \
    "9) 域名绑定管理  $nginx_status" \
    "10) 设置快捷键 Q / q" \
    "U) 更新菜单脚本 menu.sh" \
    "0) 退出"
  read -rp "请输入选项: " main_choice

  case "${main_choice^^}" in
    1) moon_menu ;;
    2) rustdesk_menu ;;
    3) libretv_menu ;;
    4) singbox_menu ;;
    5) argosb_menu ;;
    6) bash <(curl -fsSL --retry 3 --retry-delay 1 --connect-timeout 5 --max-time 30 kejilion.sh) ;;
    7) zjsync_menu ;;
    8) panso_menu ;;
    9) nginx_menu ;;
    10) set_q_shortcut ;;
    U) update_menu_script ;;
    0) exit 0 ;;
    *) echo "❌ 无效输入"; sleep 1 ;;

  esac
done
