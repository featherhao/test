#!/bin/bash
# RustDesk OSS Server 管理脚本

COMPOSE_FILE="/root/compose.yml"
HBBS_CONTAINER="rust_desk_hbbs"
HBBR_CONTAINER="rust_desk_hbbr"

# 安装 RustDesk OSS
install_rustdesk_oss() {
    echo "🐳 安装 RustDesk Server OSS..."
    echo "⬇️  下载官方 compose 文件..."
    curl -fsSL -o $COMPOSE_FILE https://raw.githubusercontent.com/ynnie/rustdesk-server/master/docker-compose.yml
    if [ $? -ne 0 ]; then
        echo "❌ 下载 compose 文件失败"
        return
    fi
    echo "✅ 下载完成"

    echo "⚠️ 检查并清理占用端口..."
    for port in 21115 21116 21117; do
        while pid=$(lsof -tiTCP:$port -sTCP:LISTEN); do
            echo "⚠️ 端口 $port 被占用，杀掉 PID: $pid"
            kill -9 $pid 2>/dev/null || true
            sleep 0.2
        done
    done
    echo "✅ 所有端口已释放"

    echo "🚀 启动容器..."
    docker compose -f $COMPOSE_FILE up -d
    if [ $? -ne 0 ]; then
        echo "❌ 启动容器失败"
        return
    fi

    echo "📜 hbbs 初始化日志（按 Ctrl+C 停止）..."
    docker logs -f $HBBS_CONTAINER

    echo "✅ 安装完成"

    echo "🌐 RustDesk 服务端连接信息："
    echo "ID Server : 0.0.0.0:21115"
    echo "Relay     : 0.0.0.0:21116"
    echo "API       : 0.0.0.0:21117"
    echo ""
    echo "🔑 客户端 Key（可能稍后生成）："
    docker exec -it $HBBS_CONTAINER cat /root/id_ed25519.pub 2>/dev/null || echo "未生成"
}

# 卸载 RustDesk
uninstall_rustdesk() {
    echo "🗑️ 卸载 RustDesk..."
    docker compose -f $COMPOSE_FILE down
    rm -f /root/id_ed25519 /root/id_ed25519.pub
    echo "✅ 卸载完成"
}

# 重启 RustDesk
restart_rustdesk() {
    echo "🔄 重启 RustDesk..."
    docker compose -f $COMPOSE_FILE restart
    echo "✅ 已重启"
}

# 查看连接信息
show_info() {
    echo "🌐 RustDesk 服务端连接信息："
    echo "ID Server : 0.0.0.0:21115"
    echo "Relay     : 0.0.0.0:21116"
    echo "API       : 0.0.0.0:21117"
    echo ""
    echo "🔑 客户端 Key："
    docker exec -it $HBBS_CONTAINER cat /root/id_ed25519.pub 2>/dev/null || echo "未生成"
}

# 主菜单
while true; do
    echo "============================="
    echo "     RustDesk 服务端管理"
    echo "============================="
    echo "服务端状态: $(docker ps | grep $HBBS_CONTAINER >/dev/null && echo 'Docker 已启动' || echo '未安装 ❌')"
    echo "1) 安装 RustDesk Server OSS (Docker)"
    echo "2) 卸载 RustDesk Server"
    echo "3) 重启 RustDesk Server"
    echo "4) 查看连接信息"
    echo "5) 退出"
    read -rp "请选择操作 [1-5]: " choice
    case $choice in
        1) install_rustdesk_oss ;;
        2) uninstall_rustdesk ;;
        3) restart_rustdesk ;;
        4) show_info ;;
        5) exit 0 ;;
        *) echo "❌ 无效选项" ;;
    esac
done
