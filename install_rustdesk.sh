#!/bin/bash
# RustDesk 服务端管理脚本
# 支持 Docker 安装、卸载、重启和查看连接信息

RUSTDESK_NET="rustdesk-oss_rust_desk_net"
HBBS_CONTAINER="rust_desk_hbbs"
HBBR_CONTAINER="rust_desk_hbbr"
HBBS_DATA="rust_desk_hbbs_data"
HBBR_DATA="rust_desk_hbbr_data"
COMPOSE_FILE="/root/compose.yml"

check_status() {
    if docker ps --format '{{.Names}}' | grep -q "$HBBS_CONTAINER"; then
        echo "Docker 已启动 ✅"
    else
        echo "未安装 ❌"
    fi
}

clean_ports() {
    for PORT in 21115 21116 21117; do
        PID=$(lsof -iTCP:$PORT -sTCP:LISTEN -t)
        if [ -n "$PID" ]; then
            echo "⚠️ 端口 $PORT 被占用，杀掉 PID: $PID"
            kill -9 $PID
        fi
    done
}

install_rustdesk() {
    echo "🐳 下载 RustDesk OSS 官方 compose 文件..."
    curl -fsSL https://raw.githubusercontent.com/ynnie/rustdesk-server/master/docker-compose.yml -o $COMPOSE_FILE
    echo "✅ 下载完成"

    echo "⚠️ 检查并清理占用端口..."
    clean_ports
    echo "✅ 所有端口已释放"

    # 删除旧容器和网络
    docker rm -f $HBBS_CONTAINER $HBBR_CONTAINER 2>/dev/null
    docker network rm $RUSTDESK_NET 2>/dev/null
    docker volume rm $HBBS_DATA $HBBR_DATA 2>/dev/null

    echo "🚀 启动 RustDesk OSS 容器..."
    docker compose -f $COMPOSE_FILE up -d

    echo "⏳ 等待 hbbs 生成客户端 Key..."
    sleep 5

    echo "✅ 安装完成"
    show_info
}

uninstall_rustdesk() {
    echo "⚠️ 卸载 RustDesk..."
    docker rm -f $HBBS_CONTAINER $HBBR_CONTAINER 2>/dev/null
    docker network rm $RUSTDESK_NET 2>/dev/null
    docker volume rm $HBBS_DATA $HBBR_DATA 2>/dev/null
    echo "✅ RustDesk 已卸载"
}

restart_rustdesk() {
    echo "🔄 重启 RustDesk..."
    docker restart $HBBS_CONTAINER $HBBR_CONTAINER
    echo "✅ 重启完成"
}

show_info() {
    STATUS=$(check_status)
    IP=$(curl -s https://api.ipify.org)
    if docker ps --format '{{.Names}}' | grep -q "$HBBS_CONTAINER"; then
        CLIENT_KEY=$(docker exec $HBBS_CONTAINER cat /root/.config/hbbs.key 2>/dev/null || echo "稍后生成")
    else
        CLIENT_KEY="未安装"
    fi

    echo "============================="
    echo "服务端状态: $STATUS"
    echo "🌐 RustDesk 服务端连接信息："
    echo "ID Server : $IP:21115"
    echo "Relay     : $IP:21116"
    echo "API       : $IP:21117"
    echo "🔑 客户端 Key：$CLIENT_KEY"
    echo "============================="
    read -p "按回车返回菜单"
}

# 主菜单
while true; do
    STATUS=$(check_status)
    echo "============================="
    echo "     RustDesk 服务端管理"
    echo "============================="
    echo "服务端状态: $STATUS"
    echo "1) 安装 RustDesk Server OSS (Docker)"
    echo "2) 卸载 RustDesk Server"
    echo "3) 重启 RustDesk Server"
    echo "4) 查看连接信息"
    echo "0) 退出"
    echo -n "请选择操作 [0-4]: "
    read -r choice
    case $choice in
        1) install_rustdesk ;;
        2) uninstall_rustdesk ;;
        3) restart_rustdesk ;;
        4) show_info ;;
        0) exit 0 ;;
        *) echo "❌ 无效选项" ;;
    esac
done
