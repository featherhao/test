#!/bin/bash
# RustDesk Server OSS 管理脚本 (Docker)
# Author: Featherhao

COMPOSE_FILE=/opt/rustdesk/docker-compose.yml
DATA_DIR=/opt/rustdesk
STATUS="未安装 ❌"

mkdir -p "$DATA_DIR"

# 检测是否安装
check_installed() {
    if docker ps -a --format '{{.Names}}' | grep -q rust_desk_hbbs; then
        STATUS="Docker 已启动 ✅"
    else
        STATUS="未安装 ❌"
    fi
}

# 获取公网 IP
get_ip() {
    curl -s https://api.ipify.org || echo "0.0.0.0"
}

# 安装 RustDesk
install_rustdesk() {
    echo "🐳 下载 RustDesk OSS 官方 compose 文件..."
    mkdir -p "$DATA_DIR"
    curl -fsSL -o "$COMPOSE_FILE" https://raw.githubusercontent.com/rustdesk/rustdesk-server/master/docker-compose.yml
    echo "✅ 下载完成"

    echo "⚠️ 检查并清理占用端口..."
    for port in 21115 21116 21117; do
        pid=$(lsof -tiTCP:$port -sTCP:LISTEN)
        if [[ -n "$pid" ]]; then
            echo "⚠️ 端口 $port 被占用，杀掉 PID: $pid"
            kill -9 $pid
        fi
    done
    echo "✅ 所有端口已释放"

    echo "🚀 启动 RustDesk OSS 容器..."
    docker-compose -f "$COMPOSE_FILE" up -d
    echo "⏳ 等待 hbbs 生成客户端 Key..."
    sleep 5
    echo "✅ 安装完成"
}

# 卸载 RustDesk
uninstall_rustdesk() {
    echo "⚠️ 停止并删除容器..."
    docker-compose -f "$COMPOSE_FILE" down
    echo "⚠️ 删除数据卷..."
    docker volume rm rust_desk_hbbs_data rust_desk_hbbr_data 2>/dev/null || true
    rm -rf "$DATA_DIR"
    echo "✅ RustDesk 已卸载"
}

# 重启 RustDesk
restart_rustdesk() {
    docker-compose -f "$COMPOSE_FILE" restart
    echo "✅ RustDesk 已重启"
}

# 查看连接信息
show_info() {
    ip=$(get_ip)
    echo "🌐 RustDesk 服务端连接信息："
    echo "ID Server : $ip:21115"
    echo "Relay     : $ip:21116"
    echo "API       : $ip:21117"
    key=$(docker exec rust_desk_hbbs cat /root/.config/rustdesk/id || echo "稍后生成")
    echo "🔑 客户端 Key：$key"
}

# 主菜单
while true; do
    check_installed
    echo "============================="
    echo "     RustDesk 服务端管理"
    echo "============================="
    echo "服务端状态: $STATUS"
    echo "1) 安装 RustDesk Server OSS (Docker)"
    echo "2) 卸载 RustDesk Server"
    echo "3) 重启 RustDesk Server"
    echo "4) 查看连接信息"
    echo "0) 退出"
    read -rp "请选择操作 [0-4]: " choice

    case $choice in
        1) install_rustdesk ;;
        2) uninstall_rustdesk ;;
        3) restart_rustdesk ;;
        4) show_info ;;
        0) break ;;
        *) echo "请输入有效选项 [0-4]" ;;
    esac
    echo "============================="
done
