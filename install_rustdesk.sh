#!/bin/bash
set -e

# RustDesk Docker 项目名称
PROJECT="rustdesk-oss"
HBBS_CONTAINER="rust_desk_hbbs"
HBBR_CONTAINER="rust_desk_hbbr"
HBBS_VOLUME="rust_desk_hbbs_data"
HBBR_VOLUME="rust_desk_hbbr_data"
NETWORK="${PROJECT}_rust_desk_net"
COMPOSE_FILE="/root/compose.yml"

# 检查安装状态
check_status() {
    if docker ps -a | grep -q "$HBBS_CONTAINER"; then
        echo "服务端状态: Docker 已启动 ✅"
    else
        echo "服务端状态: 未安装 ❌"
    fi
}

# 获取本机公网 IP
get_ip() {
    IP=$(curl -s ifconfig.me || echo "0.0.0.0")
    echo "$IP"
}

# 等待 hbbs 生成客户端 Key
wait_for_hbbs() {
    echo "⏳ 等待 hbbs 容器生成客户端 Key..."
    for i in {1..30}; do
        STATUS=$(docker inspect -f '{{.State.Status}}' $HBBS_CONTAINER 2>/dev/null || echo "stopped")
        if [ "$STATUS" == "running" ]; then
            KEY=$(docker exec $HBBS_CONTAINER cat /root/.config/hbbs.key 2>/dev/null || true)
            if [ -n "$KEY" ]; then
                echo "🔑 客户端 Key 已生成"
                return
            fi
        fi
        sleep 2
    done
    echo "🔑 客户端 Key 暂未生成，请稍后"
}

# 安装 RustDesk
install_rustdesk() {
    echo "🐳 下载 RustDesk OSS 官方 compose 文件..."
    curl -fsSL -o $COMPOSE_FILE https://raw.githubusercontent.com/ynnie/rustdesk-server/master/docker-compose.yml
    echo "✅ 下载完成"

    # 清理占用端口
    for PORT in 21115 21116 21117; do
        PID=$(lsof -tiTCP:$PORT -sTCP:LISTEN)
        if [ -n "$PID" ]; then
            echo "⚠️ 端口 $PORT 被占用，杀掉 PID: $PID"
            kill -9 $PID
        fi
    done
    echo "✅ 所有端口已释放"

    # 删除旧容器
    docker rm -f $HBBS_CONTAINER $HBBR_CONTAINER 2>/dev/null || true
    docker network rm $NETWORK 2>/dev/null || true

    # 启动容器
    echo "🚀 启动 RustDesk OSS 容器..."
    docker-compose -f $COMPOSE_FILE up -d
    wait_for_hbbs

    echo "✅ 安装完成"
    IP=$(get_ip)
    echo "🌐 RustDesk 服务端连接信息："
    echo "ID Server : $IP:21115"
    echo "Relay     : $IP:21116"
    echo "API       : $IP:21117"
    KEY=$(docker exec $HBBS_CONTAINER cat /root/.config/hbbs.key 2>/dev/null || echo "稍后生成")
    echo "🔑 客户端 Key：$KEY"
}

# 卸载 RustDesk
uninstall_rustdesk() {
    docker-compose -f $COMPOSE_FILE down --volumes 2>/dev/null || true
    docker rm -f $HBBS_CONTAINER $HBBR_CONTAINER 2>/dev/null || true
    docker volume rm $HBBS_VOLUME $HBBR_VOLUME 2>/dev/null || true
    docker network rm $NETWORK 2>/dev/null || true
    echo "✅ RustDesk 已卸载"
}

# 重启 RustDesk
restart_rustdesk() {
    docker-compose -f $COMPOSE_FILE down
    docker-compose -f $COMPOSE_FILE up -d
    wait_for_hbbs
    echo "✅ RustDesk 已重启"
}

# 查看连接信息
show_info() {
    IP=$(get_ip)
    echo "🌐 RustDesk 服务端连接信息："
    echo "ID Server : $IP:21115"
    echo "Relay     : $IP:21116"
    echo "API       : $IP:21117"
    KEY=$(docker exec $HBBS_CONTAINER cat /root/.config/hbbs.key 2>/dev/null || echo "稍后生成")
    echo "🔑 客户端 Key：$KEY"
    read -p "按回车返回菜单"
}

# 主菜单
while true; do
    check_status
    echo "============================="
    echo "     RustDesk 服务端管理"
    echo "============================="
    echo "1) 安装 RustDesk Server OSS (Docker)"
    echo "2) 卸载 RustDesk Server"
    echo "3) 重启 RustDesk Server"
    echo "4) 查看连接信息"
    echo "0) 退出"
    read -p "请选择操作 [0-4]: " choice
    case $choice in
        1) install_rustdesk ;;
        2) uninstall_rustdesk ;;
        3) restart_rustdesk ;;
        4) show_info ;;
        0) exit ;;
        *) echo "无效选项" ;;
    esac
done
