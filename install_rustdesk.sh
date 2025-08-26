#!/bin/bash
set -e

# ==================
# 基础配置
# ==================
WORKDIR="/opt/rustdesk"
SERVER_IP=$(curl -s ipv4.ip.sb || curl -s ifconfig.me || echo "0.0.0.0")

# ==================
# 工具函数
# ==================
check_port() {
    local port=$1
    if lsof -i:$port >/dev/null 2>&1; then
        pid=$(lsof -t -i:$port)
        echo "⚠️  端口 $port 已被进程 PID:$pid 占用"
        read -p "是否释放该端口？[y/N] " yn
        if [[ "$yn" =~ ^[Yy]$ ]]; then
            kill -9 $pid
            echo "✅ 已释放端口 $port"
        else
            echo "❌ 请修改端口或停止占用进程后再试"
            exit 1
        fi
    fi
}

get_rustdesk_key() {
    KEY_FILE="$WORKDIR/data/id_ed25519.pub"
    if [[ -f "$KEY_FILE" ]]; then
        cat "$KEY_FILE"
    else
        echo "⏳ Key 尚未生成，请稍后再查看"
    fi
}

check_update() {
    local image="rustdesk/rustdesk-server:latest"
    echo "🔍 检查更新中..."
    docker pull $image >/dev/null 2>&1
    local local_id=$(docker images -q $image)
    local remote_id=$(docker inspect --format='{{.Id}}' $image)
    if [[ "$local_id" != "$remote_id" ]]; then
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
    echo "🔑 客户端 Key：$(get_rustdesk_key)"
}

# ==================
# 安装
# ==================
install_rustdesk() {
    echo "📦 安装 RustDesk Server..."

    mkdir -p $WORKDIR/data
    chmod 777 $WORKDIR/data

    check_port 21115
    check_port 21116
    check_port 21117

    docker rm -f hbbs hbbr 2>/dev/null || true

    docker run -d --name hbbs \
        --restart unless-stopped \
        -v $WORKDIR/data:/data \
        -p 21115:21115 -p 21116:21116 -p 21116:21116/udp \
        rustdesk/rustdesk-server hbbs -r ${SERVER_IP}:21117

    docker run -d --name hbbr \
        --restart unless-stopped \
        -v $WORKDIR/data:/data \
        -p 21117:21117 \
        rustdesk/rustdesk-server hbbr

    echo "✅ 安装完成"

    # 等待 Key 文件生成（最多等待 10 秒）
    for i in {1..10}; do
        if [[ -f "$WORKDIR/data/id_ed25519.pub" ]]; then
            break
        fi
        sleep 1
    done

    show_info
}

# ==================
# 卸载
# ==================
uninstall_rustdesk() {
    echo "🗑️ 卸载 RustDesk Server..."
    docker rm -f hbbs hbbr 2>/dev/null || true
    read -p "是否删除数据文件 (Key/配置)? [y/N] " yn
    if [[ "$yn" =~ ^[Yy]$ ]]; then
        rm -rf $WORKDIR
        echo "🗑️ 数据文件已删除"
    fi
    echo "✅ 卸载完成"
}

# ==================
# 重启
# ==================
restart_rustdesk() {
    echo "🔄 重启 RustDesk Server..."
    docker restart hbbs hbbr
    echo "✅ 重启完成"
}

# ==================
# 更新
# ==================
update_rustdesk() {
    echo "⬆️ 更新 RustDesk Server..."
    docker pull rustdesk/rustdesk-server:latest
    docker rm -f hbbs hbbr 2>/dev/null || true
    install_rustdesk
    echo "✅ 更新完成"
}

# ==================
# 主菜单
# ==================
while true; do
    echo "============================="
    echo "     RustDesk 服务端管理"
    echo "============================="
    if docker ps --format '{{.Names}}' | grep -q hbbs; then
        echo "服务端状态: 已安装 ✅"
    else
        echo "服务端状态: 未安装 ❌"
    fi
    check_update

    echo "1) 安装 RustDesk Server"
    echo "2) 卸载 RustDesk Server"
    echo "3) 重启 RustDesk Server"
    echo "4) 查看连接信息"
    echo "5) 更新 RustDesk Server"
    echo "0) 退出"
    read -p "请选择操作 [0-5]: " choice

    case $choice in
        1) install_rustdesk ;;
        2) uninstall_rustdesk ;;
        3) restart_rustdesk ;;
        4) show_info; read -p "按回车继续..." ;;
        5) update_rustdesk; read -p "按回车继续..." ;;
        0) exit 0 ;;
        *) echo "无效选项，请重试" ;;
    esac
done
