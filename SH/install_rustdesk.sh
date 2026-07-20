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
            exit 1
        fi
    fi
}

# ==================
# 功能函数
# ==================
install_rustdesk() {
    echo "📦 正在安装/重置 RustDesk Server..."
    mkdir -p $WORKDIR/data
    check_port 21115; check_port 21116; check_port 21117

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
    
    echo "✅ Server 已成功启动"
}

install_api() {
    echo "📦 正在部署 RustDesk API..."
    if [[ ! -f "$WORKDIR/data/id_ed25519.pub" ]]; then
        echo "❌ 错误：未找到 Key 文件，请先安装 Server (选项 1)"
        return
    fi
    
    check_port 21114
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
    
    echo "⏳ 等待 API 初始化..."
    sleep 6
    local PASS=$(docker logs rustdesk-api 2>&1 | grep "Admin Password Is:" | tail -n1 | awk '{print $NF}')
    
    echo "============================================"
    echo "🌐 管理地址: http://${SERVER_IP}:21114/_admin/"
    echo "👤 用户名: admin"
    echo "🔑 初始密码: ${PASS:-[未检测到密码，若无法登录请尝试选项3重置API数据]}"
    echo "============================================"
}

uninstall_service() {
    echo -e "\n--- 请选择清理模式 ---"
    echo "1) 仅清理 API 容器 (保留数据)"
    echo "2) 彻底重置 API (删除 API 数据库，强制重新生成密码)"
    echo "3) 卸载所有服务 (Server + API + 清理数据)"
    echo "4) 取消"
    read -p "请输入选项 [1-4]: " un_choice

    case $un_choice in
        1) docker rm -f rustdesk-api; echo "✅ API 容器已移除" ;;
        2) 
            docker rm -f rustdesk-api
            rm -f $WORKDIR/data/db.sqlite3 2>/dev/null || echo "未找到数据库文件"
            echo "✅ API 数据已清空，下次安装时将重新生成初始密码" 
            ;;
        3)
            read -p "⚠️ 警告：将删除所有服务及数据，确认？[y/N] " confirm
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                docker rm -f hbbs hbbr rustdesk-api 2>/dev/null
                rm -rf $WORKDIR/data
                echo "✅ 所有服务及数据已彻底清理。"
            fi
            ;;
        *) echo "操作已取消" ;;
    esac
}

# ==================
# 主菜单
# ==================
while true; do
    echo -e "\n============================="
    echo "      RustDesk 综合管理"
    echo "============================="
    echo "1) 安装/重置 Server (hbbs/hbbr)"
    echo "2) 安装/更新 API"
    echo "3) 卸载/管理 API 数据"
    echo "4) 查看公钥 (Key)"
    echo "0) 退出"
    read -p "请选择操作 [0-4]: " choice

    case $choice in
        1) install_rustdesk ;;
        2) install_api ;;
        3) uninstall_service ;;
        4) cat $WORKDIR/data/id_ed25519.pub 2>/dev/null || echo "⏳ 未找到 Key"; read -p "回车继续..." ;;
        0) exit 0 ;;
        *) echo "无效选项" ;;
    esac
done
