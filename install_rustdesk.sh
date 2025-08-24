#!/bin/bash
set -e

# 配置
COMPOSE_URL="https://raw.githubusercontent.com/ynnie/rustdesk-server/master/docker-compose.yml"
COMPOSE_FILE="/root/rustdesk-docker-compose.yml"
HBBS_CONTAINER="rust_desk_hbbs"
HBBR_CONTAINER="rust_desk_hbbr"

# 获取公网 IP
get_ip() {
    IP=$(curl -s ifconfig.me || echo "0.0.0.0")
    echo "$IP"
}

# 检查 Docker 是否安装
check_docker() {
    if ! command -v docker &>/dev/null; then
        echo "Docker 未安装，请先安装 Docker"
        exit 1
    fi
}

# 检查 RustDesk 是否安装
check_installed() {
    docker ps -a | grep -q "$HBBS_CONTAINER" && echo "Docker 已启动 ✅" || echo "未安装 ❌"
}

# 清理端口和旧容器
cleanup() {
    echo "⚠️ 检查并清理占用端口..."
    for PORT in 21115 21116 21117; do
        PID=$(lsof -iTCP:$PORT -sTCP:LISTEN -t || true)
        if [ -n "$PID" ]; then
            echo "⚠️ 端口 $PORT 被占用，杀掉 PID: $PID"
            kill -9 $PID || true
        fi
    done
    for CONTAINER in $HBBS_CONTAINER $HBBR_CONTAINER; do
        if docker ps -a | grep -q "$CONTAINER"; then
            docker rm -f $CONTAINER
        fi
    done
}

# 安装 RustDesk OSS
install_rustdesk() {
    echo "🐳 下载 RustDesk OSS 官方 compose 文件..."
    curl -fsSL $COMPOSE_URL -o $COMPOSE_FILE
    echo "✅ 下载完成"
    
    cleanup
    echo "🚀 启动 RustDesk OSS 容器..."
    docker compose -f $COMPOSE_FILE up -d

    wait_for_hbbs
    echo "✅ 安装完成"
}

# 卸载 RustDesk
uninstall_rustdesk() {
    echo "⚠️ 卸载 RustDesk..."
    cleanup
    echo "✅ RustDesk 已卸载"
}

# 重启 RustDesk
restart_rustdesk() {
    echo "🔄 重启 RustDesk..."
    docker compose -f $COMPOSE_FILE restart
    wait_for_hbbs
    echo "✅ 重启完成"
}

# 等待 hbbs 容器生成 Key
wait_for_hbbs() {
    echo "⏳ 等待 hbbs 容器生成客户端 Key..."
    for i in {1..20}; do
        STATUS=$(docker inspect -f '{{.State.Running}}' $HBBS_CONTAINER 2>/dev/null || echo "false")
        if [ "$STATUS" == "true" ]; then
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

# 查看连接信息
show_info() {
    IP=$(get_ip)
    echo "🌐 RustDesk 服务端连接信息："
    echo "ID Server : $IP:21115"
    echo "Relay     : $IP:21116"
    echo "API       : $IP:21117"
    KEY=$(docker exec $HBBS_CONTAINER cat /root/.config/hbbs.key 2>/dev/null || echo "稍后生成")
    echo "🔑 客户端 Key：$KEY"
}

# 菜单
while true; do
    echo "============================="
    STATUS=$(docker ps -a | grep -q "$HBBS_CONTAINER" && echo "Docker 已启动 ✅" || echo "未安装 ❌")
    echo "服务端状态: $STATUS"
    echo "1) 安装 RustDesk Server OSS (Docker)"
    echo "2) 卸载 RustDesk Server"
    echo "3) 重启 RustDesk Server"
    echo "4) 查看连接信息"
    echo "0) 退出"
    read -rp "请选择操作 [0-4]: " CHOICE
    case "$CHOICE" in
        1) install_rustdesk ;;
        2) uninstall_rustdesk ;;
        3) restart_rustdesk ;;
        4) show_info ;;
        0) exit 0 ;;
        *) echo "无效选项" ;;
    esac
    read -rp "按回车返回菜单..."
done
