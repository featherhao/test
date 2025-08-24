#!/bin/bash
set -e

# ====== 配置路径 ======
WORKDIR_MOONTV="/opt/moontv"
MOONTV_SCRIPT="https://raw.githubusercontent.com/featherhao/test/refs/heads/main/install.sh"
UPDATE_MOONTV_SCRIPT="https://raw.githubusercontent.com/featherhao/test/refs/heads/main/updatemtv.sh"

WORKDIR_RUSTDESK="/opt/rustdesk"
RUSTDESK_SCRIPT="https://raw.githubusercontent.com/featherhao/test/refs/heads/main/install_rustdesk.sh"
UPDATE_RUSTDESK_SCRIPT="https://raw.githubusercontent.com/featherhao/test/refs/heads/main/update_rustdesk.sh"


# ====== 子菜单：MoonTV ======
function moon_menu() {
  while true; do
    clear
    echo "=============================="
    echo "       🎬 MoonTV 管理菜单"
    echo "=============================="
    echo "1) 安装 / 初始化 MoonTV"
    echo "2) 更新 MoonTV"
    echo "3) 重启 MoonTV"
    echo "4) 停止 MoonTV"
    echo "5) 查看运行日志"
    echo "b) 返回上一级"
    echo "q) 退出"
    echo "=============================="
    read -rp "请输入选项: " choice

    case "$choice" in
      1) echo "📦 正在安装 MoonTV..." && bash <(curl -fsSL "$MOONTV_SCRIPT") ;;
      2) echo "🔄 正在更新 MoonTV..." && bash <(curl -fsSL "$UPDATE_MOONTV_SCRIPT") ;;
      3) [ -d "$WORKDIR_MOONTV" ] && cd "$WORKDIR_MOONTV" && docker compose restart || echo "⚠️ 未安装 MoonTV" ;;
      4) [ -d "$WORKDIR_MOONTV" ] && cd "$WORKDIR_MOONTV" && docker compose down || echo "⚠️ 未安装 MoonTV" ;;
      5) [ -d "$WORKDIR_MOONTV" ] && cd "$WORKDIR_MOONTV" && docker compose logs -f || echo "⚠️ 未安装 MoonTV" ;;
      b|B) break ;;
      q|Q) echo "👋 退出"; exit 0 ;;
      *) echo "❌ 无效输入" ;;
    esac
    echo
    read -rp "按回车继续..."
  done
}

# ====== 子菜单：RustDesk ======
function rustdesk_menu() {
  while true; do
    clear
    echo "=============================="
    echo "       🖥️ RustDesk 管理菜单"
    echo "=============================="
    echo "1) 安装 / 初始化 RustDesk"
    echo "2) 更新 RustDesk"
    echo "3) 重启 RustDesk"
    echo "4) 停止 RustDesk"
    echo "5) 查看运行日志"
    echo "b) 返回上一级"
    echo "q) 退出"
    echo "=============================="
    read -rp "请输入选项: " choice

    case "$choice" in
      1) echo "📦 正在安装 RustDesk..." && bash <(curl -fsSL "$RUSTDESK_SCRIPT") ;;
      2) echo "🔄 正在更新 RustDesk..." && bash <(curl -fsSL "$UPDATE_RUSTDESK_SCRIPT") ;;
      3) [ -d "$WORKDIR_RUSTDESK" ] && cd "$WORKDIR_RUSTDESK" && docker compose restart || echo "⚠️ 未安装 RustDesk" ;;
      4) [ -d "$WORKDIR_RUSTDESK" ] && cd "$WORKDIR_RUSTDESK" && docker compose down || echo "⚠️ 未安装 RustDesk" ;;
      5) [ -d "$WORKDIR_RUSTDESK" ] && cd "$WORKDIR_RUSTDESK" && docker compose logs -f || echo "⚠️ 未安装 RustDesk" ;;
      b|B) break ;;
      q|Q) echo "👋 退出"; exit 0 ;;
      *) echo "❌ 无效输入" ;;
    esac
    echo
    read -rp "按回车继续..."
  done
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
