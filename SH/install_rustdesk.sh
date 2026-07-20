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
    echo "🌐 API地址: http://${SERVER_IP}:21114/_admin/"
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

    echo "⏳ 检查 Key..."
    sleep 3
    # 只有当文件不存在时才去尝试提取
    if [[ ! -f "$WORKDIR/data/id_ed25519.pub" ]]; then
        KEY=$(docker logs hbbs 2>&1 | grep "Key:" | tail -n1 | awk '{print $NF}')
        [[ -n "$KEY" ]] && echo "$KEY" > "$WORKDIR/data/id_ed25519.pub"
    fi
    echo "✅ Server 已运行 (Key 已保留)"
}

install_api() {
    if [[ ! -f "$WORKDIR/data/id_ed25519.pub" ]]; then
        echo "❌ 错误：请先安装 Server 生成 Key"
        return
    fi
    echo "📦 正在安装 API 模块..."
    docker rm -f rustdesk-api 2>/dev/null || true
    rm -rf $WORKDIR/api_data/*
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
    PASS=$(docker logs rustdesk-api 2>&1 | grep "Admin Password Is:" | tail -n1 | awk -F'Is: ' '{print $2}' | awk '{print $1}')
    echo -e "\n============================================"
    echo "👤 用户名: admin"
    echo "🔑 初始密码: ${PASS:-手动查看: docker logs rustdesk-api | grep 'Password Is'}"
    echo "============================================"
}

uninstall_server() {
    echo -e "\n🛠  卸载 Server 服务"
    read -p "是否保留数据目录（Key）？[Y/n]: " keep
    docker rm -f hbbs hbbr 2>/dev/null || true
    if [[ "$keep" =~ ^[Nn]$ ]]; then
        rm -rf $WORKDIR/data
        echo "✅ 数据已彻底清除。"
    else
        echo "✅ Key 已保留，下次安装 Server 将自动挂载。"
    fi
}

uninstall_all() {
    echo -e "\n⚠️  警告：将删除所有服务及数据 ($WORKDIR)！"
    read -p "确认彻底清理吗？[y/N]: " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        docker rm -f hbbs hbbr rustdesk-api 2>/dev/null || true
        rm -rf $WORKDIR
        echo "✅ 所有服务及数据已删除。"
    fi
}

# ==================
# 主菜单
# ==================
while true; do
    echo -e "\n============================="
    echo "   RustDesk 综合管理面板"
    echo "============================="
    echo "1) 安装/更新 Server (自动识别已有 Key)"
    echo "2) 安装/更新 API"
    echo "3) 卸载 Server (可选择是否保留 Key)"
    echo "4) 仅卸载 API"
    echo "5) 彻底卸载所有 (含 Key)"
    echo "6) 查看连接信息"
    echo "0) 退出"
    read -p "请选择: " choice

    case $choice in
        1) install_server ;;
        2) install_api ;;
        3) uninstall_server ;;
        4) docker rm -f rustdesk-api; rm -rf $WORKDIR/api_data; echo "✅ API 已卸载" ;;
        5) uninstall_all ;;
        6) show_info; read -p "按回车继续..." ;;
        0) exit 0 ;;
        *) echo "无效选项" ;;
    esac
done
