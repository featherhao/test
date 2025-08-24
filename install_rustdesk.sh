#!/bin/bash
set -e

# RustDesk OSS Docker 管理脚本
WORKDIR=/root/rustdesk-oss
mkdir -p $WORKDIR
cd $WORKDIR

# 公共端口
ID_PORT=21115
RELAY_PORT=21116
API_PORT=21117

# 获取公网 IP
get_ip() {
    IP=$(curl -s https://ip.sb)
    echo "$IP"
}

# 检查并杀掉占用端口的进程
free_ports() {
    for port in $ID_PORT $RELAY_PORT $API_PORT; do
        PID=$(lsof -tiTCP:$port -sTCP:LISTEN)
        if [ -n "$PID" ]; then
            echo "⚠️ 端口 $port 被占用，杀掉 PID: $PID"
            kill -9 $PID
        fi
    done
}

# 安装 RustDesk OSS
install_rustdesk() {
    echo "🐳 下载 RustDesk OSS 官方 compose 文件..."
    curl -fsSL https://raw.githubusercontent.com/ynnie/rustdesk-server/master/docker-compose.yml -o compose.yml
    echo "✅ 下载完成"

    echo "⚠️ 检查并清理占用端口..."
    free_ports
    echo "✅ 所有端口已释放"

    # 清理旧容器
    docker rm -f rust_desk_hbbr rust_desk_hbbs 2>/dev/null || true
    docker volume rm rust_desk_hbbr_data rust_desk_hbbs_data 2>/dev/null || true

    echo "🚀 启动 RustDesk OSS 容器..."
    # 修改 compose.yml 确保 hbbs 参数正确
    sed -i '/command:/d' compose.yml

    docker compose up -d

    # 等待容器启动
    sleep 5
    IP=$(get_ip)

    echo "✅ 安装完成"
    echo "🌐 RustDesk 服务端连接信息："
    echo "ID Server : $IP:$ID_PORT"
    echo "Relay     : $IP:$RELAY_PORT"
    echo "API       : $IP:$API_PORT"

    echo "🔑 客户端 Key（稍后生成）:"
    docker exec rust_desk_hbbs cat /root/.config/rustdesk/id_ed25519.pub 2>/dev/null || echo "未生成"
}

# 卸载 RustDesk
uninstall_rustdesk() {
    docker rm -f rust_desk_hbbr rust_desk_hbbs 2>/dev/null || true
    docker volume rm rust_desk_hbbr_data rust_desk_hbbs_data 2>/dev/null || true
    echo "✅ RustDesk OSS 已卸载"
}

# 重启
restart_rustdesk() {
    docker compose down
    docker compose up -d
    echo "✅ RustDesk OSS 已重启"
}

# 查看连接信息
show_info() {
    IP=$(get_ip)
    echo "🌐 RustDesk 服务端连接信息："
    echo "ID Server : $IP:$ID_PORT"
    echo "Relay     : $IP:$RELAY_PORT"
    echo "API       : $IP:$API_PORT"
    echo "🔑 客户端 Key:"
    docker exec rust_desk_hbbs cat /root/.config/rustdesk/id_ed25519.pub 2>/dev/null || echo "未生成"
}

# 菜单
while true; do
    echo "=============================="
    echo "     RustDesk 服务端管理"
    echo "=============================="
    echo "服务端状态: $(docker ps | grep rust_desk_hbbs >/dev/null && echo 'Docker 已启动' || echo '未安装 ❌')"
    echo "1) 安装 RustDesk Server OSS (Docker)"
    echo "2) 卸载 RustDesk Server"
    echo "3) 重启 RustDesk Server"
    echo "4) 查看连接信息"
    echo "5) 退出"
    read -rp "请选择操作 [1-5]: " CHOICE
    case "$CHOICE" in
        1) install_rustdesk ;;
        2) uninstall_rustdesk ;;
        3) restart_rustdesk ;;
        4) show_info ;;
        5) exit ;;
        *) echo "❌ 无效选项" ;;
    esac
done
