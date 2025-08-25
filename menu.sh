#!/bin/bash
set -e

# ====== 配置路径 ======
WORKDIR_MOONTV="/opt/moontv"
MOONTV_SCRIPT="https://raw.githubusercontent.com/featherhao/test/refs/heads/main/mootvinstall.sh"

WORKDIR_RUSTDESK="/opt/rustdesk"
RUSTDESK_SCRIPT="https://raw.githubusercontent.com/featherhao/test/refs/heads/main/install_rustdesk.sh"

WORKDIR_LIBRETV="/opt/libretv"
LIBRETV_SCRIPT="https://raw.githubusercontent.com/featherhao/test/refs/heads/main/install_libretv.sh"

# ====== docker compose 兼容 ======
if command -v docker-compose &>/dev/null; then
  COMPOSE="docker-compose"
else
  COMPOSE="docker compose"
fi

# ====== 调用 MoonTV 子脚本 ======
moon_menu() {
  bash <(curl -fsSL "${MOONTV_SCRIPT}?t=$(date +%s)")
}

# ====== 调用 RustDesk 子脚本 ======
rustdesk_menu() {
  bash <(curl -fsSL "${RUSTDESK_SCRIPT}?t=$(date +%s)")
}

# ====== 调用 LibreTV 安装脚本 ======
libretv_menu() {
  bash <(curl -fsSL "${LIBRETV_SCRIPT}?t=$(date +%s)")
}

# ====== 调用 甬哥Sing-box-yg 脚本 ======
singbox_menu() {
  bash <(wget -qO- https://raw.githubusercontent.com/yonggekkk/sing-box-yg/main/sb.sh)
}

# ====== 勇哥ArgoSB菜单 ======
argosb_menu() {
  while true; do
    clear
    echo "=============================="
    echo "  🚀 勇哥ArgoSB一键无交互小钢炮管理"
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
          echo "请选择协议："
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
          case "$proto_choice" in
            1) vlpt="" bash <(curl -Ls https://raw.githubusercontent.com/yonggekkk/argosb/main/argosb.sh) ;;
            2) xhpt="" bash <(curl -Ls https://raw.githubusercontent.com/yonggekkk/argosb/main/argosb.sh) ;;
            3) sspt="" bash <(curl -Ls https://raw.githubusercontent.com/yonggekkk/argosb/main/argosb.sh) ;;
            4) anpt="" bash <(curl -Ls https://raw.githubusercontent.com/yonggekkk/argosb/main/argosb.sh) ;;
            5) arpt="" bash <(curl -Ls https://raw.githubusercontent.com/yonggekkk/argosb/main/argosb.sh) ;;
            6) vmpt="" bash <(curl -Ls https://raw.githubusercontent.com/yonggekkk/argosb/main/argosb.sh) ;;
            7) hypt="" bash <(curl -Ls https://raw.githubusercontent.com/yonggekkk/argosb/main/argosb.sh) ;;
            8) tupt="" bash <(curl -Ls https://raw.githubusercontent.com/yonggekkk/argosb/main/argosb.sh) ;;
            9) vmpt="" argo="y" bash <(curl -Ls https://raw.githubusercontent.com/yonggekkk/argosb/main/argosb.sh) ;;
            0) break ;;
            *) echo "❌ 无效输入"; sleep 1 ;;
          esac
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
          1) ippz=4 agsb list || ippz=4 bash <(curl -Ls https://raw.githubusercontent.com/yonggekkk/argosb/main/argosb.sh) list ;;
          2) ippz=6 agsb list || ippz=6 bash <(curl -Ls https://raw.githubusercontent.com/yonggekkk/argosb/main/argosb.sh) list ;;
          *) echo "❌ 无效输入"; sleep 1 ;;
        esac
        read -rp "按回车返回菜单..." dummy
        ;;
      0) break ;;
      *) echo "❌ 无效输入"; sleep 1 ;;
    esac
  done
}

# ====== 更新菜单脚本 ======
update_menu_script() {
  SCRIPT_PATH="$HOME/menu.sh"
  echo "🔄 正在更新 menu.sh..."
  curl -fsSL "https://raw.githubusercontent.com/featherhao/test/refs/heads/main/menu.sh?t=$(date +%s)" -o "$SCRIPT_PATH"
  chmod +x "$SCRIPT_PATH"
  echo "✅ menu.sh 已更新到 $SCRIPT_PATH"
  echo "👉 以后可直接执行：bash ~/menu.sh 启动最新菜单"
  sleep 2
}

# ====== 设置快捷键 Q / q 指向本地菜单 ======
set_q_shortcut() {
  SHELL_RC="$HOME/.bashrc"
  [ -n "$ZSH_VERSION" ] && SHELL_RC="$HOME/.zshrc"

  sed -i '/alias Q=/d' "$SHELL_RC"
  sed -i '/alias q=/d' "$SHELL_RC"

  echo "alias Q='bash ~/menu.sh'" >> "$SHELL_RC"
  echo "alias q='bash ~/menu.sh'" >> "$SHELL_RC"

  echo "✅ 快捷键 Q / q 已设置，请执行 'source $SHELL_RC' 或重启终端生效"
  sleep 2
}

# ====== 主菜单 ======
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
