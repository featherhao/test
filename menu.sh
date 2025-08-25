#!/bin/bash
set -e

# ================== 基础配置 ==================
SCRIPT_URL="https://raw.githubusercontent.com/featherhao/test/refs/heads/main/menu.sh"
SCRIPT_PATH="$HOME/menu.sh"

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

# ================== 子脚本路径 ==================
WORKDIR_MOONTV="/opt/moontv"
MOONTV_SCRIPT="https://raw.githubusercontent.com/featherhao/test/refs/heads/main/mootvinstall.sh"

WORKDIR_RUSTDESK="/opt/rustdesk"
RUSTDESK_SCRIPT="https://raw.githubusercontent.com/featherhao/test/refs/heads/main/install_rustdesk.sh"

WORKDIR_LIBRETV="/opt/libretv"
LIBRETV_SCRIPT="https://raw.githubusercontent.com/featherhao/test/refs/heads/main/install_libretv.sh"

# ================== 调用子脚本 ==================
moon_menu() { bash <(curl -fsSL "${MOONTV_SCRIPT}?t=$(date +%s)"); }
rustdesk_menu() { bash <(curl -fsSL "${RUSTDESK_SCRIPT}?t=$(date +%s)"); }
libretv_menu() { bash <(curl -fsSL "${LIBRETV_SCRIPT}?t=$(date +%s)"); }
singbox_menu() { bash <(wget -qO- https://raw.githubusercontent.com/yonggekkk/sing-box-yg/main/sb.sh); }

# ================== 勇哥ArgoSB菜单（增量协议） ==================
argosb_menu() {
  get_existing_protos() {
    local installed=""
    if command -v agsb &>/dev/null; then
      [[ $(agsb list | grep -q "Vless-Reality-Vision") ]] && installed="$installed vlpt=\"\""
      [[ $(agsb list | grep -q "Vless-Xhttp-Reality") ]] && installed="$installed xhpt=\"\""
      [[ $(agsb list | grep -q "Shadowsocks-2022") ]] && installed="$installed sspt=\"\""
      [[ $(agsb list | grep -q "AnyTLS") ]] && installed="$installed anpt=\"\""
      [[ $(agsb list | grep -q "Any-Reality") ]] && installed="$installed arpt=\"\""
      [[ $(agsb list | grep -q "Vmess-ws") ]] && installed="$installed vmpt=\"\""
      [[ $(agsb list | grep -q "Hysteria2") ]] && installed="$installed hypt=\"\""
      [[ $(agsb list | grep -q "Tuic") ]] && installed="$installed tupt=\"\""
    fi
    echo "$installed"
  }

  run_argosb() {
    local proto_vars="$1"
    eval "$proto_vars bash <(curl -Ls https://raw.githubusercontent.com/yonggekkk/argosb/main/argosb.sh)"
  }

  while true; do
    clear
    echo "=============================="
    echo "  🚀 勇哥ArgoSB增量协议管理"
    echo "=============================="
    echo "1) 安装/运行协议节点"
    echo "2) 查看节点信息 (agsb list)"
    echo "3) 更换代理协议变量组 (agsb rep)"
    echo "4) 更新脚本 (建议卸载重装)"
    echo "5) 重启脚本 (agsb res)"
    echo "6) 卸载脚本 (agsb del)"
    echo "7) 临时切换 IPv4 / IPv6 节点显示"
    echo "0) 返回主菜单"
    echo "=============================="
    read -rp "请输入选项: " main_choice

    case "$main_choice" in
      1)
        while true; do
          clear
          echo "请选择协议（增量添加）："
          echo "1) Vless-Reality-Vision (vlpt)"
          echo "2) Vless-Xhttp-Reality (xhpt)"
          echo "3) Shadowsocks-2022 (sspt)"
          echo "4) AnyTLS (anpt)"
          echo "5) Any-Reality (arpt)"
          echo "6) Vmess-ws (vmpt)"
          echo "7) Hysteria2 (hypt)"
          echo "8) Tuic (tupt)"
          echo "9) Argo临时隧道CDN优选节点 (vmpt+argo=y)"
          echo "0) 返回上级菜单"
          read -rp "请输入选项: " proto_choice

          EXISTING_PROTOS=$(get_existing_protos)

          case "$proto_choice" in
            1) NEW_PROTO='vlpt=""' ;;
            2) NEW_PROTO='xhpt=""' ;;
            3) NEW_PROTO='sspt=""' ;;
            4) NEW_PROTO='anpt=""' ;;
            5) NEW_PROTO='arpt=""' ;;
            6) NEW_PROTO='vmpt=""' ;;
            7) NEW_PROTO='hypt=""' ;;
            8) NEW_PROTO='tupt=""' ;;
            9) NEW_PROTO='vmpt="" argo="y"' ;;
            0) break ;;
            *) echo "❌ 无效输入"; sleep 1; continue ;;
          esac

          ALL_PROTOS="$EXISTING_PROTOS $NEW_PROTO"
          echo "🔹 正在增量添加协议..."
          run_argosb "$ALL_PROTOS"

          read -rp "按回车返回协议选择菜单..." dummy
        done
        ;;
      2)
        agsb list || bash <(curl -Ls https://raw.githubusercontent.com/yonggekkk/argosb/main/argosb.sh) list
        read -rp "按回车返回菜单..." dummy
        ;;
      3)
        agsb rep || bash <(curl -Ls https://raw.githubusercontent.com/yonggekkk/argosb/main/argosb.sh) rep
        read -rp "按回车返回菜单..." dummy
        ;;
      4)
        agsb rep || bash <(curl -Ls https://raw.githubusercontent.com/yonggekkk/argosb/main/argosb.sh) rep
        read -rp "按回车返回菜单..." dummy
        ;;
      5)
        agsb res || bash <(curl -Ls https://raw.githubusercontent.com/yonggekkk/argosb/main/argosb.sh) res
        read -rp "按回车返回菜单..." dummy
        ;;
      6)
        agsb del || bash <(curl -Ls https://raw.githubusercontent.com/yonggekkk/argosb/main/argosb.sh) del
        read -rp "按回车返回菜单..." dummy
        ;;
      7)
        echo "1) 显示 IPv4 节点配置"
        echo "2) 显示 IPv6 节点配置"
        read -rp "请输入选项: " ip_choice
        case "$ip_choice" in
          1) run_argosb 'ippz=4' ;;
          2) run_argosb 'ippz=6' ;;
          *) echo "❌ 无效输入"; sleep 1 ;;
        esac
        read -rp "按回车返回菜单..." dummy
        ;;
      0) break ;;
      *) echo "❌ 无效输入"; sleep 1 ;;
    esac
  done
}

# ================== 更新菜单脚本 ==================
update_menu_script() {
  echo "🔄 正在更新 menu.sh..."
  curl -fsSL "${SCRIPT_URL}?t=$(date +%s)" -o "$SCRIPT_PATH"
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

  echo "请选择快捷方式模式："
  echo "1) 本地模式 (bash ~/menu.sh)"
  echo "2) 远程模式 (始终运行最新脚本)"
  read -rp "请输入选项 [1/2]: " alias_mode

  if [ "$alias_mode" = "2" ]; then
    echo "alias Q='bash <(curl -fsSL ${SCRIPT_URL})'" >> "$SHELL_RC"
    echo "alias q='bash <(curl -fsSL ${SCRIPT_URL})'" >> "$SHELL_RC"
    echo "✅ 已设置为远程模式"
  else
    echo "alias Q='bash ~/menu.sh'" >> "$SHELL_RC"
    echo "alias q='bash ~/menu.sh'" >> "$SHELL_RC"
    echo "✅ 已设置为本地模式"
  fi

  echo "⚡ 请执行 'source $SHELL_RC' 或重启终端生效"
  sleep 2
}

# ================== 主菜单 ==================
while true; do
  clear
  echo "=============================="
  echo "       🚀 服务管理中心"
  echo "=============================="
  echo "1) MoonTV 管理"
  echo "2) RustDesk 管理"
  echo "3) LibreTV 安装"
  echo "4) 甬哥Sing-box-yg管理"
  echo "5) 勇哥ArgoSB一键无交互小钢炮"
  echo "6) Kejilion.sh 一键脚本工具箱"
  echo "9) 设置快捷键 Q / q"
  echo "U) 更新菜单脚本 menu.sh"
  echo "8) 其他服务 (预留)"
  echo "0) 退出"
  echo "=============================="
  read -rp "请输入选项: " main_choice

  case "${main_choice^^}" in
    1) moon_menu ;;
    2) rustdesk_menu ;;
    3) libretv_menu ;;
    4) singbox_menu ;;
    5) argosb_menu ;;
    6) bash <(curl -sL kejilion.sh) ;;
    9) set_q_shortcut ;;
    U) update_menu_script ;;
    8) echo "⚠️ 其他服务还未实现"; sleep 1 ;;
    0) exit 0 ;;
    *) echo "❌ 无效输入"; sleep 1 ;;
  esac
done
