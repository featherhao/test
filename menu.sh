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

# ====== 设置快捷键 Q / q ======
set_q_shortcut() {
  SHELL_RC="$HOME/.bashrc"
  [ -n "$ZSH_VERSION" ] && SHELL_RC="$HOME/.zshrc"

  sed -i '/alias Q=/d' "$SHELL_RC"
  sed -i '/alias q=/d' "$SHELL_RC"

  echo "alias Q='bash <(curl -fsSL \"https://raw.githubusercontent.com/featherhao/test/refs/heads/main/menu.sh?t=\$(date +%s)\")'" >> "$SHELL_RC"
  echo "alias q='bash <(curl -fsSL \"https://raw.githubusercontent.com/featherhao/test/refs/heads/main/menu.sh?t=\$(date +%s)\")'" >> "$SHELL_RC"

  echo "✅ 快捷键 Q / q 已设置，请执行 'source $SHELL_RC' 或重启终端生效"
  sleep 2
}

# ====== 更新 menu.sh 脚本 ======
update_menu_script() {
  SCRIPT_PATH="$HOME/menu.sh"
  echo "🔄 正在更新 menu.sh..."
  curl -fsSL "https://raw.githubusercontent.com/featherhao/test/refs/heads/main/menu.sh?t=$(date +%s)" -o "$SCRIPT_PATH"
  chmod +x "$SCRIPT_PATH"
  echo "✅ menu.sh 已更新，保存路径：$SCRIPT_PATH"
  echo "👉 执行：bash $SCRIPT_PATH 启动最新菜单"
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
  echo "5) 其他服务 (预留)"
  echo "9) 设置快捷键 Q / q"
  echo "U) 更新菜单脚本 menu.sh"
  echo "0) 退出"
  echo "=============================="
  read -rp "请输入选项: " main_choice

  case "${main_choice^^}" in
    1) moon_menu ;;
    2) rustdesk_menu ;;
    3) libretv_menu ;;
    4) singbox_menu ;;
    5) echo "⚠️ 其他服务还未实现"; sleep 1 ;;
    9) set_q_shortcut ;;
    U) update_menu_script ;;
    0) exit 0 ;;
    *) echo "❌ 无效输入"; sleep 1 ;;
  esac
done
