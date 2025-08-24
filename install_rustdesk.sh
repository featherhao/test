#!/bin/bash
set -e

MENU_FILE="/root/menu.sh"
COMPOSE_FILE="/root/compose.yml"
HBBR_CONTAINER="rust_desk_hbbr"
HBBS_CONTAINER="rust_desk_hbbs"

function rustdesk_menu() {
    while true; do
        echo "============================"
        echo "     RustDesk 服务端管理"
        echo "============================"

        # 检查容器状态
        if docker ps --format "{{.Names}}" | grep -q "$HBBR_CONTAINER"; then
            STATUS="Docker 已启动"
        else
            STATUS="未安装 ❌"
        fi

        echo "服务端状态: $STATUS"
        echo "1) 安装 RustDesk Server OSS (Docker)"
        echo "2) 卸载 RustDesk Server"
        echo "3) 重启 RustDesk Server"
        echo "4) 查看连接信息"
        echo "5) 退出"
        read -p "请选择操作 [1-5]: " choice

        case $choice in
            1)
                install_rustdesk_oss
                ;;
            2)
                uninstall_rustdesk
                ;;
            3)
                restart_rustdesk
                ;;
            4)
                show_info
                ;;
            5)
                break
                ;;
            *)
                echo "无效选项，请重新选择"
                ;;
        esac
    done
}

function install_rustdesk_oss() {
    echo "🐳 安装 RustDesk Server OSS..."
    echo "⬇️  下载官方 compose 文件..."
    curl -fsSL -o $COMPOSE_FILE https://raw.githubusercontent.com/ynnie/rustdesk-server/master/docker-compose.yml
    echo "✅ 下载完成"

    echo "⚠️ 停止并清理旧容器..."
    docker ps -a --format "{{.Names}}" | grep -E "${HBBR_CONTAINER}|${HBBS_CONTAINER}" &> /dev/null && \
        docker stop $HBBR_CONTAINER $HBBS_CONTAINER &> /dev/null
    docker rm $HBBR_CONTAINER $HBBS_CONTAINER &> /dev/null || true

    # 检查端口占用
    for port in 21115 21116 21117; do
        if lsof -iTCP:$port -sTCP:LISTEN -t &> /dev/null; then
            echo "⚠️ 端口 $port 已被占用，请先释放端口或修改 compose 文件"
            return
        fi
    done

    echo "🚀 启动容器..."
    docker compose -f $COMPOSE_FILE up -d

    echo "📜 hbbs 初始化日志（按 Ctrl+C 停止）..."
    docker logs -f $HBBS_CONTAINER | while read line; do
        echo "$line"
        if [[ $line == *"Key:"* ]]; then
            CLIENT_KEY=$(echo $line | awk -F'Key: ' '{print $2}')
            echo -e "\n🔑 客户端可用 Key: $CLIENT_KEY\n"
        fi
    done
}

function uninstall_rustdesk() {
    echo "⚠️ 停止并卸载 RustDesk Server..."
    docker stop $HBBR_CONTAINER $HBBS_CONTAINER &> /dev/null || true
    docker rm $HBBR_CONTAINER $HBBS_CONTAINER &> /dev/null || true
    rm -f /root/id_ed25519 /root/id_ed25519.pub
    echo "✅ 卸载完成"
}

function restart_rustdesk() {
    echo "🔄 重启 RustDesk Server..."
    docker restart $HBBR_CONTAINER $HBBS_CONTAINER
    echo "✅ 重启完成"
}

function show_info() {
    if docker ps --format "{{.Names}}" | grep -q "$HBBR_CONTAINER"; then
        IP=$(curl -s https://api.ip.sb/ip)
        echo "🌐 RustDesk 服务端连接信息："
        echo "公网 IPv4: $IP"
        echo "ID Server : $IP:21115"
        echo "Relay     : $IP:21116"
        echo "API       : $IP:21117"
        if [[ -f /root/id_ed25519 ]]; then
            echo "🔑 私钥路径: /root/id_ed25519"
            echo "🔑 公钥路径: /root/id_ed25519.pub"
        else
            echo "⚠️ 还未生成客户端 Key，请确保 hbbs 容器已启动并完成初始化"
        fi
    else
        echo "⚠️ RustDesk Server 未安装"
    fi
}

# 启动 RustDesk 菜单
rustdesk_menu
