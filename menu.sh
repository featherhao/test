#!/bin/bash
set -e

# ====== 配置路径 ======
WORKDIR_MOONTV="/opt/moontv"
MOONTV_SCRIPT="https://raw.githubusercontent.com/featherhao/test/refs/heads/main/mootvinstall.sh"
UPDATE_MOONTV_SCRIPT="https://raw.githubusercontent.com/featherhao/test/refs/heads/main/updatemtv.sh"

WORKDIR_RUSTDESK="/opt/rustdesk"
RUSTDESK_SCRIPT="https://raw.githubusercontent.com/featherhao/test/refs/heads/main/install_rustdesk.sh"
UPDATE_RUSTDESK_SCRIPT="https://raw.githubusercontent.com/featherhao/test/refs/heads/main/update_rustdesk.sh"

# ====== 主菜单：MoonTV ======
function moon_menu() {
  # 直接调用远端脚本 mootvinstall.sh（子脚本里已经包含二级菜单）
  bash <(curl -fsSL "${MOONTV_SCRIPT}?t=$(date +%s)")
}

# ====== 主菜单：RustDesk ======
function rustdesk_menu() {
  # 直接调用远端脚本 install_rustdesk.sh（子脚本里已经包含二级菜单）
  bash <(curl -fsSL "${RUSTDESK_SCRIPT}?t=$(date +%s)")
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
  echo "0) 退出"
  echo "=============================="
  read -rp "请输入选项: " main_choice

  case "$main_choice" in
    1) moon_menu ;;
    2) rustdesk_menu ;;
    3) echo "⚠️ 其他服务还未实现"; sleep 1 ;;
    0|q|Q) echo "👋 退出"; exit 0 ;;
    *) echo "❌ 无效输入"; sleep 1 ;;
  esac
done
