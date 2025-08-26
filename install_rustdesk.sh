#!/bin/bash
set -e

# ================== 基础配置 ==================
WORKDIR="/opt/rustdesk"
IMAGE="rustdesk/rustdesk-server:latest"
SERVER_IP=$(curl -s ipv4.ip.sb || curl -s ifconfig.me)

# ================== 工具函数 ==================
pause() {
    read -p "按回车继续..."
}

check_docker() {
    if ! command -v docker &>/dev/null; then
        echo "📦 正在安装 Docker..."
        curl -fsSL https://get.docker.com | bash
    fi
}

check_update() {
    echo "🔍 检查更新中..."
    docker pull $IMAGE >/dev/null
    LOCAL=$(docker images --format "{{.Repository}}:{{.Tag}} {{.ID}}" | grep "$IMAGE" | awk '{print $2}')
    REMOTE=$(docker inspect --format='{{.Id}}' $IMAGE 2>/dev/null || true)

    if [[ "$LOCAL" != "$REMOTE" ]]; then
        echo "⬆️  有新版本可更新！(选择 5 更新)"
    else
        echo "✅ 当前已是最新版本"
    fi
}

show_info() {
    echo "🌐 RustDesk 服务端连接信息："
    echo "ID Server : ${SERVER_IP}:21115"
    echo "Relay     : ${SERVER_IP}:21116"
    echo "API       : ${SERVER_IP}:21117"

    # 从容器读取 Key
    if docker exec hbbs test -f /root/.config/rustdesk/id_ed25519.pub 2>/dev/null; then
        KEY=$(docker exec hbbs cat /root/.config/rustdesk/id_ed25519.pub)
        echo "🔑 客户端 Key：$KEY"
    else
        echo "⚠️ 未找到客户端 Key 文件"
    fi

    pause
}

install_rustdesk() {
    check_docker
    mkdir -p $WORKDIR

    echo "📦 安装 RustDesk Server..."
    docker run -d --name hbbs --restart unless-stopped \
        -v $WORKDIR:/root/.config/rustdesk \
        -p 21115:21115 -p 21116:21116 -p 21116:21116/udp \
        $IMAGE hbbs

    docker run -d --name hbbr --restart unless-stopped \
        -v $WORKDIR:/root/.config/rustdesk \
        -p 21117:21117 \
        $IMAGE hbbr

    echo "✅ 安装完成"
    show_info
}

uninstall_rustdesk() {
    echo "🗑️ 卸载 RustDesk Server..."
    docker rm -f hbbs hbbr >/dev/null 2>&1 || true
    rm -rf $WORKDIR
    echo "✅ 卸载完成"
    pause
}

restart_rustdesk() {
    echo "🔄 重启 RustDesk Server..."
    docker restart hbbs hbbr >/dev/null
    echo "✅ 重启完成"
    pause
}

update_rustdesk() {
    echo "⬆️ 更新 RustDesk Server..."
    docker pull $IMAGE
    uninstall_rustdesk
    install_rustdesk
    echo "✅ 更新完成"
    pause
}

# ================== 主菜单 ==================
while true; do
    clear
    echo "============================="
    echo "     RustDesk 服务端管理"
    echo "============================="

    if docker ps -a --format '{{.Names}}' | grep -q hbbs; then
        echo "服务端状态: 已安装 ✅"
    else
        echo "服务端状态: 未安装 ❌"
    fi

    check_update

    cat <<EOF
1) 安装 RustDesk Server
2) 卸载 RustDesk Server
3) 重启 RustDesk Server
4) 查看连接信息
5) 更新 RustDesk Server
0) 退出
EOF

    read -p "请选择操作 [0-5]: " choice
    case $choice in
        1) install_rustdesk ;;
        2) uninstall_rustdesk ;;
        3) restart_rustdesk ;;
        4) show_info ;;
        5) update_rustdesk ;;
        0) exit 0 ;;
        *) echo "❌ 无效选项"; pause ;;
    esac
done
