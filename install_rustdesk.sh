#!/bin/bash

RUSTDESK_DIR="/root"
PRIVATE_KEY="$RUSTDESK_DIR/id_ed25519"
PUBLIC_KEY="$RUSTDESK_DIR/id_ed25519.pub"

get_public_ip() {
    # 获取公网 IPv4
    curl -s https://api.ip.sb/ip || echo "无法获取公网 IP"
}

get_client_key() {
    if [[ -f "$PRIVATE_KEY" ]]; then
        sed -n '2,$p' "$PRIVATE_KEY" | head -n -1 | tr -d '\n'
    else
        echo "私钥不存在，请先生成服务端 Key"
    fi
}

show_info() {
    IP=$(get_public_ip)
    echo
    echo "🌐 RustDesk 服务端连接信息："
    echo "公网 IPv4: $IP"
    echo "ID Server : $IP:21115"
    echo "Relay     : $IP:21116"
    echo "API       : $IP:21117"
    echo
    echo "🔑 私钥路径: $PRIVATE_KEY"
    echo "🔑 公钥路径: $PUBLIC_KEY"
    echo "🔑 客户端可用 Key: $(get_client_key)"
    echo
    read -p "按回车返回菜单..."
}

main_menu() {
    while true; do
        clear
        echo "============================"
        echo "     RustDesk 服务端管理     "
        echo "============================"
        if docker ps | grep -q hbbs; then
            echo "服务端状态: Docker 已启动"
        else
            echo "服务端状态: 未安装 ❌"
        fi
        echo "1) 安装 RustDesk Server Pro (Docker)"
        echo "2) 卸载 RustDesk Server"
        echo "3) 重启 RustDesk Server"
        echo "4) 查看连接信息"
        echo "5) 退出"
        echo -n "请选择操作 [1-5]: "
        read choice
        case $choice in
            1) bash /root/install_rustdesk.sh ;;  # 你的安装脚本
            2) bash /root/uninstall_rustdesk.sh ;; # 你的卸载脚本
            3) bash /root/restart_rustdesk.sh ;;   # 你的重启脚本
            4) show_info ;;
            5) exit ;;
            *) echo "无效选项"; sleep 1 ;;
        esac
    done
}

main_menu
