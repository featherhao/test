#!/bin/bash
set -e

# ====== 配置路径 ======
WORKDIR_MOONTV="/opt/moontv"
MOONTV_SCRIPT="https://raw.githubusercontent.com/featherhao/test/refs/heads/main/mootvinstall.sh"
UPDATE_MOONTV_SCRIPT="https://raw.githubusercontent.com/featherhao/test/refs/heads/main/updatemtv.sh"

WORKDIR_RUSTDESK="/opt/rustdesk"
RUSTDESK_SCRIPT="https://raw.githubusercontent.com/featherhao/test/refs/heads/main/install_rustdesk.sh"
UPDATE_RUSTDESK_SCRIPT="https://raw.githubusercontent.com/featherhao/test/refs/heads/main/update_rustdesk.sh"

# ====== 调用 MoonTV 子脚本（先下载再执行，兼容性更好） ======
moon_menu() {
  TMP_FILE=$(mktemp)
  curl -fsSL "${MOONTV_SCRIPT}?t=$(date +%s)" -o "$TMP_FILE"
  bash "$TMP_FILE"
  rm -f "$TMP_FILE"
}

# ====== 调用 RustDesk 子脚本 ======
rustdesk_menu() {
  TMP_FILE=$(mktemp)
  curl -fsSL "${RUSTDESK_SCRIPT}?t=$(date +%s)" -o "$TMP_FILE"
  bash "$TMP_FILE"
  rm -f "$TMP_FILE"
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

# ====== 更新所有脚本（简洁输出） ======
update_all_scripts() {
  echo "🔄 正在更新菜单及所有二级脚本，请稍候..."
  SCRIPTS=(
    "menu.sh"
    "mootvinstall.sh"
    "updatemtv.sh"
    "install_rustdesk.sh"
    "update_rustdesk.sh"
  )
  for file in "${SCRIPTS[@]}"; do
    curl -fsSL "https://raw.githubusercontent.com/featherhao/test/refs/heads/main/$file?t=$(date +%s)" -o "$HOME/$file"
    chmod +x "$HOME/$file"
  done
  echo "✅ 更新完成，所有脚本已更新到最新版本"
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
  echo "3) 其他服务 (预留)"
  echo "9) 设置快捷键 Q / q"
  echo "U) 更新菜单及所有二级脚本"
  echo "0) 退出"
  echo "=============================="
  read -rp "请输入选项: " main_choice

  case "${main_choice^^}" in
    1) moon_menu ;;
    2) rustdesk_menu ;;
    3) echo "⚠️ 其他服务还未实现"; sleep 1 ;;
    9) set_q_shortcut ;;
    U) update_all_scripts ;;
    0) exit 0 ;;
    *) echo "❌ 无效输入"; sleep 1 ;;
  esac
done
