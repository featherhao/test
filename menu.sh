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

# ================== 勇哥ArgoSB菜单（增量添加协议） ==================
argosb_menu() {
  while true; do
    clear
    echo "=============================="
    echo "  🚀 勇哥ArgoSB增量添加协议"
    echo "=============================="
    echo "1) 增量添加协议节点"
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
        # 自动读取已有变量
        EXISTING_VARS=""
        for var in vlpt xhpt sspt anpt arpt vmpt hypt tupt; do
          if [[ -n "${!var}" ]]; then
            EXISTING_VARS="$EXISTING_VARS $var=\"\""
          fi
        done

        # 用户选择新增协议
        echo "请选择要新增的协议（可多选，用空格分隔，例如 1 3 5）:"
        echo "1) Vless-Reality-Vision (vlpt)"
        echo "2) Vless-Xhttp-Reality (xhpt)"
        echo "3) Shadowsocks-2022 (sspt)"
        echo "4) AnyTLS (anpt)"
        echo "5) Any-Reality (arpt)"
        echo "6) Vmess-ws (vmpt)"
        echo "7) Hysteria2 (hypt)"
        echo "8) Tuic (tupt)"
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

        # 合并已有变量 + 新增变量，并执行 rep
        ALL_VARS="$EXISTING_VARS $NEW_VARS"
        if [[ -n "$ALL_VARS" ]]; then
          echo "🔹 正在增量更新节点..."
          eval "$ALL_VARS bash <(curl -Ls https://raw.githubusercontent.com/yonggekkk/argosb/main/argosb.sh) rep"
        else
          echo "⚠️ 未选择有效协议"
        fi
        read -rp "按回车返回菜单..." dummy
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
          1) ippz=4 bash <(curl -Ls https://raw.githubusercontent.com/yonggekkk/argosb/main/argosb.sh) list ;;
          2) ippz=6 bash <(curl -Ls https://raw.githubusercontent.com/yonggekkk/argosb/main/argosb.sh) list ;;
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

  echo "alias Q='bash ~/menu.sh'" >> "$SHELL_RC"
  echo "alias q='bash ~/menu.sh'" >> "$SHELL_RC"
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
  echo "5) 勇哥ArgoSB增量添加协议"
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
