#!/bin/bash

RUSTDESK_COMPOSE="/root/compose.yml"

check_and_kill_port() {
    PORTS=(21115 21116 21117)
    for PORT in "${PORTS[@]}"; do
        PID=$(lsof -tiTCP:$PORT -sTCP:LISTEN)
        if [ -n "$PID" ]; then
            echo "⚠️ 端口 $PORT 被占用，杀掉 PID: $PID"
            kill -9 "$PID"
            sleep 1
        fi
    done
}

install_rustdesk_oss() {
    echo "🐳 安装 RustDesk Server OSS..."
    echo "⬇️  下载官方 compose 文件..."
    curl -fsSL https://raw.githubusercontent.com/ynnie/rustdesk-server/master/docker-compose.yml -o $RUSTDESK_COMPOSE
    if [ $? -ne 0 ]; then
        echo "❌ 下载 compose 文件失败"
        return 1
    fi
    echo "✅ 下载完成"

    check_and_kill_port

    echo "🚀 启动容器并显示安装输出..."
    docker compose -f $RUSTDESK_COMPOSE up -d

    # 等待容器启动
    sleep 3

    HBBS_LOG_CONTAINER=$(docker ps --filter "name=hbbs" --format "{{.Names}}")
    if [ -n "$HBBS_LOG_CONTAINER" ]; then
        echo "📜 hbbs 初始化日志（按 Ctrl+C 停止）..."
        docker logs -f "$HBBS_LOG_CONTAINER" &
        LOG_PID=$!
        # 等待 5 秒，尝试抓取 Key
        sleep 5
        CLIENT_KEY=$(docker logs "$HBBS_LOG_CONTAINER" 2>&1 | grep "Key:" | tail -n1 | awk '{print $2}')
        kill $LOG_PID
        if [ -n "$CLIENT_KEY" ]; then
            echo "🔑 客户端可用 Key: $CLIENT_KEY"
        else
            echo "⚠️ 暂未获取到客户端 Key，请等待 hbbs 完全初始化"
        fi
    else
        echo "❌ hbbs 容器未启动成功"
    fi

    echo "✅ 安装完成"
    echo "🌐 RustDesk 服务端连接信息："
    echo "ID Server : 0.0.0.0:21115"
    echo "Relay     : 0.0.0.0:21116"
    echo "API       : 0.0.0.0:21117"
}

# 菜单调用示例
while true; do
    echo "============================="
    echo "     RustDesk 服务端管理"
    echo "============================="
    echo "服务端状态: 未安装 ❌"
    echo "1) 安装 RustDesk Server OSS (Docker)"
    echo "2) 卸载 RustDesk Server"
    echo "3) 重启 RustDesk Server"
    echo "4) 查看连接信息"
    echo "5) 退出"
    read -p "请选择操作 [1-5]: " opt
    case $opt in
        1) install_rustdesk_oss ;;
        5) exit 0 ;;
        *) echo "暂未实现" ;;
    esac
done
