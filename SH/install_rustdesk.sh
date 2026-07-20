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
get_rustdesk_key() {
    if [[ -f "$WORKDIR/data/id_ed25519.pub" ]]; then
        cat "$WORKDIR/data/id_ed25519.pub"
    else
        echo "⏳ Key 尚未生成"
    fi
}

show_info() {
    echo -e "\n🌐 RustDesk 连接信息："
    echo "ID Server : ${SERVER_IP}:21115"
    echo "Relay     : ${SERVER_IP}:21117"
    echo "🔑 Key    : $(get_rustdesk_key)"
}

# ==================
# 功能函数
# ==================
install_server() {
    echo "📦 正在安装/重置 Server..."
    mkdir -p $WORKDIR/data
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

    echo "⏳ 等待生成 Key..."
    sleep 6
    KEY=$(docker logs hbbs 2>&1 | grep "Key:" | tail -n1 | awk '{print $NF}')
    [[ -n "$KEY" ]] && echo "$KEY" > "$WORKDIR/data/id_ed25519.pub"
    echo "✅ Server 安装完成"
}

install_api() {
    if [[ ! -f "$WORKDIR/data/id_ed25519.pub" ]]; then
        echo "❌ 错误：请先安装 Server 生成 Key"
        return
    fi
    echo "📦 正在安装 API 模块..."
    docker rm -f rustdesk-api 2>/dev/null || true
    mkdir -p $WORKDIR/api_data
    
    docker run -d --name rustdesk-api \
    --restart unless-stopped \
    -p 21114:21114 \
    -v $WORKDIR/api_data:/app/data \
    -v $WORKDIR/data:/data \
    -e RUSTDESK_API_RUSTDESK_ID_SERVER=${SERVER_IP}:21116 \
    -e RUSTDESK_API_RUSTDESK_RELAY_SERVER=${SERVER_IP}:21117 \
    -e RUSTDESK_API_RUSTDESK_API_SERVER=http://${SERVER_IP}:21114 \
    -e RUSTDESK_API_RUSTDESK_KEY=$(cat $WORKDIR/data/id_ed25519.pub) \
    lejianwen/rustdesk-api
    
    echo "⏳ 等待 API 初始化..."
    sleep 6
    PASS=$(docker logs rustdesk-api 2>&1 | grep "Admin Password Is:" | tail -n1 | awk '{print $NF}')
    echo "============================================"
    echo "👤 管理员密码: ${PASS:-手动查询: docker logs rustdesk-api | grep 'Password Is'}"
    echo "============================================"
}

uninstall_all() {
    echo -e "\n⚠️  警告：将彻底删除所有服务及数据目录 ($WORKDIR)！"
    read -p "确认操作吗？[y/N]: " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        docker rm -f hbbs hbbr rustdesk-api 2>/dev/null || true
        rm -rf $WORKDIR
        echo "✅ 所有容器、配置及数据已清理。"
    else
        echo "❌ 取消卸载。"
    fi
}

# ==================
# 主菜单
# ==================
while true; do
    echo -e "\n============================="
    echo "   RustDesk 综合管理面板"
    echo "============================="
    echo "1) 安装/重置 Server"
    echo "2) 安装/更新 API"
    echo "3) 仅卸载 API"
    echo "4) 彻底卸载所有服务 (Server+API)"
    echo "5) 查看连接信息 (含 Key)"
    echo "0) 退出"
    read -p "请选择: " choice

    case $choice in
        1) install_server ;;
        2) install_api ;;
        3) docker rm -f rustdesk-api; echo "✅ API 已卸载" ;;
        4) uninstall_all ;;
        5) show_info; read -p "按回车继续..." ;;
        0) exit 0 ;;
        *) echo "无效选项" ;;
    esac
done
