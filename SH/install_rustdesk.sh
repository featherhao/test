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
        read -p "是否强制释放该端口？[y/N] " yn
        if [[ "$yn" =~ ^[Yy]$ ]]; then
            kill -9 $pid && echo "✅ 已释放端口 $port"
        else
            echo "❌ 操作已取消"
            return 1
        fi
    fi
}

# ==================
# 功能函数
# ==================
install_rustdesk() {
    echo "📦 正在安装/重置 RustDesk Server..."
    mkdir -p $WORKDIR/data
    
    # 检查并清理旧容器
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
    
    echo "✅ Server 已成功启动 (Key 已生成，可通过选项 5 查看)"
}

install_api() {
    echo "📦 正在部署 RustDesk API..."
    if [[ ! -f "$WORKDIR/data/id_ed25519.pub" ]]; then
        echo "❌ 错误：未找到 Key 文件，请先安装 Server (选项 1)"
        return
    fi
    
    local KEY=$(cat "$WORKDIR/data/id_ed25519.pub")
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
    
    echo "⏳ 等待 API 初始化 (5秒)..."
    sleep 5
    local PASS=$(docker logs rustdesk-api 2>&1 | grep "Admin Password Is:" | tail -n1 | awk '{print $NF}')
    
    echo "============================================"
    echo "🌐 管理地址: http://${SERVER_IP}:21114/_admin/"
    echo "👤 用户名: admin"
    echo "🔑 初始密码: ${PASS:-手动查询: docker logs rustdesk-api | grep 'Password Is'}"
    echo "============================================"
}

uninstall_api() {
    echo "🧹 正在清理 API 服务..."
    docker rm -f rustdesk-api && echo "✅ API 容器已移除"
    # 可选：清理镜像
    # docker rmi lejianwen/rustdesk-api 2>/dev/null
}

# ==================
# 主菜单
# ==================
while true; do
    echo -e "\n--- RustDesk 综合管理面板 ---"
    echo "1) 安装/重置 Server (hbbs/hbbr)"
    echo "2) 安装/更新 API"
    echo "3) 仅卸载 API"
    echo "4) 卸载所有服务"
    echo "5) 查看公钥 (Key)"
    echo "0) 退出"
    read -p "选择操作 [0-5]: " choice

    case $choice in
        1) install_rustdesk ;;
        2) install_api ;;
        3) uninstall_api ;;
        4) docker rm -f hbbs hbbr rustdesk-api 2>/dev/null; echo "✅ 所有服务已清理" ;;
        5) cat $WORKDIR/data/id_ed25519.pub 2>/dev/null || echo "⏳ 未找到 Key"; read -p "回车继续..." ;;
        0) exit 0 ;;
        *) echo "无效选项" ;;
    esac
done
