#!/bin/bash
set -e

RUSTDESK_SCRIPT_URL="https://github.com/rustdesk/rustdesk/releases/latest/download/rustdesk-remote.sh"

check_curl() {
    command -v curl >/dev/null 2>&1 || { echo "⚠️ 请先安装 curl"; exit 1; }
}

install_rustdesk() {
    echo "📦 正在安装 RustDesk..."
    bash <(curl -fsSL "$RUSTDESK_SCRIPT_URL")
    echo "✅ RustDesk 安装完成"
}

update_rustdesk() {
    echo "🔄 正在更新 RustDesk..."
    bash <(curl -fsSL "$RUSTDESK_SCRIPT_URL")
    echo "✅ RustDesk 更新完成"
}

uninstall_rustdesk() {
    echo "🗑️ 正在卸载 RustDesk..."
    if [ -f /usr/local/bin/rustdesk ] || [ -f /usr/bin/rustdesk ]; then
        sudo rm -f /usr/local/bin/rustdesk /usr/bin/rustdesk
    fi
    echo "✅ RustDesk 已卸载"
}

show_menu() {
    echo "============================"
    echo "      RustDesk 管理脚本     "
    echo "============================"
    echo "1) 安装 RustDesk"
    echo "2) 更新 RustDesk"
    echo "3) 卸载 RustDesk"
    echo "4) 退出"
    echo -n "请选择操作 [1-4]: "
}

check_curl

while true; do
    show_menu
    read -r choice
    case $choice in
        1) install_rustdesk ;;
        2) update_rustdesk ;;
        3) uninstall_rustdesk ;;
        4) echo "退出"; exit 0 ;;
        *) echo "⚠️ 无效选项，请输入 1-4" ;;
    esac
done
