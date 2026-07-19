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
        echo "⏳ Key 尚未生成"
    fi
}

# ==================
# 功能函数
# ==================
install_rustdesk() {
    echo "📦 安装/重置 RustDesk Server..."
    mkdir -p $WORKDIR/data
    check_port 21115
    check_port 21116
    check_port 21117

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
    
    echo "✅ Server 安装/启动完成"
}

install_api() {
    echo "📦 正在安装/更新 RustDesk API (lejianwen)..."
    check_port 21114
    
    if [[ ! -f "$WORKDIR/data/id_ed25519.pub" ]]; then
        echo "❌ 错误：未找到 Key 文件，请先确保已安装 Server"
        return
    fi
    
    local KEY=$(cat "$WORKDIR/data/id_ed25519.pub")
    
    # 如果容器已存在，先删除，确保重新部署能获取最新状态
    docker rm -f rustdesk-api 2>/dev/null || true
    
    docker run -d --name rustdesk-api \
    --restart unless-stopped \
    -p 21114:21114 \
    -v $WORKDIR/data:/app/data \
    -e RUSTDESK_API_RUSTDESK_ID_SERVER=${SERVER_IP}:21116 \
    -e RUSTDESK_API_RUSTDESK_RELAY_SERVER=${SERVER_IP}:21117 \
    -e RUSTDESK_API_RUSTDESK_API_SERVER=http://${SERVER_IP}:21114 \
    -e RUSTDESK_API_RUSTDESK_KEY=${KEY} \
    lejianwen/rustdesk-api
    
    echo "⏳ 正在等待容器初始化并获取初始密码..."
    sleep 5
    
    # 自动提取密码
    local PASS=$(docker logs rustdesk-api | grep "Admin Password Is:" | tail -n1 | awk '{print $NF}')
    
    echo "============================================"
    echo "✅ API 安装完成！"
    echo "🌐 管理地址: http://${SERVER_IP}:21114/_admin/"
    echo "👤 用户名: admin"
    echo "🔑 初始密码: ${PASS:-无法自动获取，请手动执行: docker logs rustdesk-api | grep 'Password Is'}"
    echo "============================================"
}

# ==================
# 主菜单
# ==================
while true; do
    echo -e "\n============================="
    echo "      RustDesk 综合管理"
    echo "============================="
    echo "1) 安装/覆盖安装 RustDesk Server (hbbs/hbbr)"
    echo "2) 安装/更新 RustDesk API"
    echo "3) 卸载 RustDesk API (安全，不影响 Server)"
    echo "4) 卸载所有服务 (含 Server)"
    echo "5) 查看当前连接信息"
    echo "0) 退出"
    read -p "请选择操作 [0-5]: " choice

    case $choice in
        1) install_rustdesk ;;
        2) install_api ;;
        3) uninstall_api ;;
        4) docker rm -f hbbs hbbr rustdesk-api; echo "✅ 所有容器已删除" ;;
        5) get_rustdesk_key; read -p "按回车继续..." ;;
        0) exit 0 ;;
        *) echo "无效选项" ;;
    esac
done
