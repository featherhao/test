#!/bin/bash
set -e

WORKDIR=/root
COMPOSE_FILE=$WORKDIR/compose.yml
HBBS_CONTAINER=hbbs
HBBR_CONTAINER=hbbr

# 检查 Docker
check_docker() {
    if ! command -v docker &> /dev/null; then
        echo "❌ Docker 未安装，请先安装 Docker"
        exit 1
    fi
}

# 安装 RustDesk Server OSS
install_rustdesk() {
    echo "🐳 安装 RustDesk Server OSS..."
    check_docker

    echo "⬇️  下载官方 compose 文件..."
    curl -fsSL https://raw.githubusercontent.com/rustdesk/rustdesk-server/main/docker-compose.yml -o $COMPOSE_FILE

    echo "⚠️ 停止并清理旧容器..."
    docker compose -f $COMPOSE_FILE down 2>/dev/null || true
    docker rm -f $HBBS_CONTAINER $HBBR_CONTAINER 2>/dev/null || true

    echo "🚀 启动容器并显示初始化日志..."
    docker compose -f $COMPOSE_FILE up -d

    echo "📜 查看 hbbs 日志获取客户端 Key（按 Ctrl+C 停止）..."
    docker logs -f $HBBS_CONTAINER &
    LOG_PID=$!

    # 等待一会儿让 Key 生成
    sleep 5

    # 从容器日志提取客户端 Key
    CLIENT_KEY=$(docker logs $HBBS_CONTAINER 2>&1 | grep -oP 'Key: \K.*' | head -1)
    if [ -n "$CLIENT_KEY" ]; then
        echo -e "\n✅ 安装完成"
        echo "🌐 RustDesk 服务端连接信息："
        echo "ID Server : 服务器IP:21115"
        echo "Relay     : 服务器IP:21116"
        echo "API       : 服务器IP:21114"
        echo -e "\n🔑 客户端可用 Key: $CLIENT_KEY"
    else
        echo "⚠️ Key 尚未生成，请稍等几秒后再查看日志"
    fi

    # 停止日志跟随
    kill $LOG_PID 2>/dev/null || true
}

# 卸载 RustDesk Server
uninstall_rustdesk() {
    echo "🗑️ 卸载 RustDesk Server..."
    docker compose -f $COMPOSE_FILE down 2>/dev/null || true
    docker rm -f $HBBS_CONTAINER $HBBR_CONTAINER 2>/dev/null || true
    rm -f $COMPOSE_FILE
    echo "✅ 已卸载"
}

# 重启 RustDesk Server
restart_rustdesk() {
    echo "🔄 重启 RustDesk Server..."
    docker compose -f $COMPOSE_FILE down
    docker compose -f $COMPOSE_FILE up -d
    echo "✅ 已重启"
}

# 查看连接信息
show_info() {
    CLIENT_KEY=$(docker logs $HBBS_CONTAINER 2>&1 | grep -oP 'Key: \K.*' | head -1 || true)

    echo "🌐 RustDesk 服务端连接信息："
    echo "ID Server : 服务器IP:21115"
    echo "Relay     : 服务器IP:21116"
    echo "API       : 服务器IP:21114"

    if [ -n "$CLIENT_KEY" ]; then
        echo "🔑 客户端可用 Key: $CLIENT_KEY"
    else
        echo "⚠️ 还未生成客户端 Key，请确保 hbbs 容器已启动"
    fi
}

# 菜单
while true; do
    echo "============================"
    echo "     RustDesk 服务端管理"
    echo "============================"
    # 检测容器状态
    if docker ps -q -f name=$HBBS_CONTAINER | grep -q .; then
        STATUS="Docker 已启动"
    else
        STATUS="未安装 ❌"
    fi
    echo "服务端状态: $STATUS"
    echo "1) 安装 RustDesk Server OSS (Docker)"
    echo "2) 卸载 RustDesk Server"
    echo "3) 重启 RustDesk Server"
    echo "4) 查看连接信息"
    echo "5) 退出"
    read -p "请选择操作 [1-5]: " choice
    case $choice in
        1) install_rustdesk ;;
        2) uninstall_rustdesk ;;
        3) restart_rustdesk ;;
        4) show_info ;;
        5) exit 0 ;;
        *) echo "❌ 无效选项" ;;
    esac
    echo "按回车返回菜单..."
    read
done
