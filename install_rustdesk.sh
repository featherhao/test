#!/bin/bash
set -e

WORKDIR="/root"
COMPOSE_FILE="$WORKDIR/compose.yml"
KEY_FILE="$WORKDIR/id_ed25519"
PUB_KEY_FILE="$WORKDIR/id_ed25519.pub"

# 函数：安装 RustDesk Server OSS
install_rustdesk() {
    echo "🐳 安装 RustDesk Server OSS..."
    
    # 下载官方或社区 compose 文件
    echo "⬇️  下载官方 compose 文件..."
    if ! wget -O "$COMPOSE_FILE" "https://raw.githubusercontent.com/ynnie/rustdesk-server/master/docker-compose.yml"; then
        echo "❌ 下载 compose 文件失败，请检查 URL"
        return 1
    fi

    # 停止并清理旧容器
    echo "⚠️ 停止并清理旧容器..."
    docker compose -f "$COMPOSE_FILE" down || true
    rm -f "$KEY_FILE" "$PUB_KEY_FILE"

    # 启动容器
    echo "🚀 启动容器并显示安装输出..."
    docker compose -f "$COMPOSE_FILE" up -d
    sleep 2

    # 生成密钥（如果不存在）
    if [ ! -f "$KEY_FILE" ]; then
        ssh-keygen -t ed25519 -f "$KEY_FILE" -N ""
    fi

    # 提示客户端 key
    CLIENT_KEY=$(ssh-keygen -yf "$KEY_FILE" | tr -d '\n')
    echo
    echo "✅ 安装完成"
    echo "🌐 RustDesk 服务端连接信息："
    echo "ID Server : <服务器IP>:21115"
    echo "Relay     : <服务器IP>:21116"
    echo "API       : <服务器IP>:21114"
    echo
    echo "🔑 客户端可用 Key: $CLIENT_KEY"
    echo "🔑 私钥路径: $KEY_FILE"
    echo "🔑 公钥路径: $PUB_KEY_FILE"
    echo "按回车返回菜单..."
    read
}

# 函数：卸载 RustDesk Server
uninstall_rustdesk() {
    echo "⚠️ 卸载 RustDesk Server..."
    docker compose -f "$COMPOSE_FILE" down || true
    rm -f "$KEY_FILE" "$PUB_KEY_FILE" "$COMPOSE_FILE"
    echo "✅ 卸载完成，按回车返回菜单..."
    read
}

# 函数：重启 RustDesk Server
restart_rustdesk() {
    echo "🔄 重启 RustDesk Server..."
    docker compose -f "$COMPOSE_FILE" down || true
    docker compose -f "$COMPOSE_FILE" up -d
    echo "✅ 重启完成，按回车返回菜单..."
    read
}

# 函数：查看连接信息
show_info() {
    echo "🌐 RustDesk 服务端连接信息："
    echo "ID Server : <服务器IP>:21115"
    echo "Relay     : <服务器IP>:21116"
    echo "API       : <服务器IP>:21114"
    if [ -f "$KEY_FILE" ]; then
        CLIENT_KEY=$(ssh-keygen -yf "$KEY_FILE" | tr -d '\n')
        echo "🔑 客户端可用 Key: $CLIENT_KEY"
        echo "🔑 私钥路径: $KEY_FILE"
        echo "🔑 公钥路径: $PUB_KEY_FILE"
    else
        echo "⚠️ 密钥尚未生成，请先安装或生成密钥"
    fi
    echo "按回车返回菜单..."
    read
}

# 菜单
while true; do
    clear
    echo "============================"
    echo "     RustDesk 服务端管理"
    echo "============================"
    STATUS=$(docker ps --filter "name=hbbs" --format "{{.Names}}")
    if [ -n "$STATUS" ]; then
        echo "服务端状态: Docker 已启动"
    else
        echo "服务端状态: 未安装 ❌"
    fi
    echo "1) 安装 RustDesk Server OSS (Docker)"
    echo "2) 卸载 RustDesk Server"
    echo "3) 重启 RustDesk Server"
    echo "4) 查看连接信息"
    echo "5) 退出"
    echo -n "请选择操作 [1-5]: "
    read CHOICE

    case "$CHOICE" in
        1) install_rustdesk ;;
        2) uninstall_rustdesk ;;
        3) restart_rustdesk ;;
        4) show_info ;;
        5) exit 0 ;;
        *) echo "❌ 无效选项"; sleep 1 ;;
    esac
done
