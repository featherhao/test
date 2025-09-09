#!/bin/bash
set -e

# 配置
CONTAINER_NAME="pansou-web"
PAN_DIR="/root/pansou-web"
FRONTEND_PORT=80
CHANNELS_DEFAULT="tgsearchers1,tgsearchers2,tgsearchers3,tgsearchers4,tgsearchers5,tgsearchers6,tgsearchers7,tgsearchers8,tgsearchers9,tgsearchers10,tgsearchers11,tgsearchers12" # 可扩展
PLUGINS_ENABLED_DEFAULT="true"
PROXY_DEFAULT=""
EXT_DEFAULT='{"is_all":true}'

# 检查端口是否可用
check_port() {
    PORT=$1
    if lsof -i :"$PORT" &>/dev/null; then
        return 1
    else
        return 0
    fi
}

install_pansou_web() {
    echo "⚙️ 开始安装 PanSou 前后端集成版"

    # Docker
    if ! command -v docker &>/dev/null; then
        echo "⚙️ 未检测到 Docker，正在安装..."
        curl -fsSL https://get.docker.com | sh
        systemctl enable docker
        systemctl start docker
    else
        echo "✅ Docker 已安装"
    fi

    # Docker Compose
    if ! command -v docker-compose &>/dev/null; then
        echo "⚙️ 未检测到 Docker Compose，正在安装..."
        curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose
    else
        echo "✅ Docker Compose 已安装"
    fi

    # 创建目录
    mkdir -p $PAN_DIR
    cd $PAN_DIR

    # 检查端口
    if ! check_port $FRONTEND_PORT; then
        read -p "⚠️ 端口 $FRONTEND_PORT 已被占用，请输入新端口 (回车默认 8080): " INPUT_PORT
        FRONTEND_PORT=${INPUT_PORT:-8080}
    fi
    echo "✅ 前端端口 $FRONTEND_PORT 可用"

    # 写 docker-compose.yml
    cat > docker-compose.yml <<EOF
services:
  $CONTAINER_NAME:
    image: ghcr.io/fish2018/pansou-web
    container_name: $CONTAINER_NAME
    restart: unless-stopped
    ports:
      - "$FRONTEND_PORT:80"
    environment:
      CHANNELS: "$CHANNELS_DEFAULT"
      PLUGINS_ENABLED: "$PLUGINS_ENABLED_DEFAULT"
      PROXY: "$PROXY_DEFAULT"
      EXT: '$EXT_DEFAULT'
EOF

    # 启动服务
    echo "🚀 启动 PanSou 前后端集成版..."
    docker compose up -d
    sleep 5
    echo "✅ 安装完成！"
}

show_status() {
    cd $PAN_DIR
    if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}\$"; then
        PUBLIC_IP=$(curl -s ifconfig.me || echo "未检测到公网IP")
        echo "✅ PanSou 正在运行"
        echo "👉 前端地址: http://$PUBLIC_IP:$FRONTEND_PORT"
        echo "👉 API 地址: http://$PUBLIC_IP:$FRONTEND_PORT/api/search"

        CHANNELS_FULL=$(docker compose exec $CONTAINER_NAME printenv CHANNELS 2>/dev/null)
        CHANNELS_ARRAY=(${CHANNELS_FULL//,/ })
        TOTAL=${#CHANNELS_ARRAY[@]}
        DISPLAY=$(IFS=, ; echo "${CHANNELS_ARRAY[@]:0:10}")
        echo "📡 当前 TG 频道 (前10个 / 共 $TOTAL 个): $DISPLAY"

        echo "🧩 插件启用: $(docker compose exec $CONTAINER_NAME printenv PLUGINS_ENABLED 2>/dev/null)"
    else
        echo "⚠️ PanSou 未运行"
    fi
}

stop_pansou() {
    cd $PAN_DIR
    docker compose down
    echo "✅ PanSou 已停止"
}

restart_pansou() {
    cd $PAN_DIR
    docker compose restart
    echo "✅ PanSou 已重启"
}

uninstall_pansou() {
    if [ -d "$PAN_DIR" ]; then
        cd $PAN_DIR
        docker compose down -v
        cd ~
        rm -rf $PAN_DIR
        echo "✅ PanSou 已卸载 (容器和缓存卷已删除)"
    else
        echo "⚠️ PanSou 未安装或已卸载"
    fi
}

modify_env() {
    cd $PAN_DIR
    echo "当前环境变量："
    echo "1) CHANNELS: $(docker compose exec $CONTAINER_NAME printenv CHANNELS 2>/dev/null)"
    echo "2) PLUGINS_ENABLED: $(docker compose exec $CONTAINER_NAME printenv PLUGINS_ENABLED 2>/dev/null)"
    echo "3) PROXY: $(docker compose exec $CONTAINER_NAME printenv PROXY 2>/dev/null)"
    echo "4) EXT: $(docker compose exec $CONTAINER_NAME printenv EXT 2>/dev/null)"
    echo ""

    read -p "输入新的 TG 频道 (回车保持不变): " NEW_CHANNELS
    read -p "插件启用 (true/false, 回车保持不变): " NEW_PLUGINS
    read -p "代理 (socks5://..., 回车保持不变): " NEW_PROXY
    read -p "EXT JSON (回车保持不变): " NEW_EXT

    # 读取原有变量，未输入则保持原值
    CHANNELS=${NEW_CHANNELS:-$(docker compose exec $CONTAINER_NAME printenv CHANNELS 2>/dev/null)}
    PLUGINS_ENABLED=${NEW_PLUGINS:-$(docker compose exec $CONTAINER_NAME printenv PLUGINS_ENABLED 2>/dev/null)}
    PROXY=${NEW_PROXY:-$(docker compose exec $CONTAINER_NAME printenv PROXY 2>/dev/null)}
    EXT=${NEW_EXT:-$(docker compose exec $CONTAINER_NAME printenv EXT 2>/dev/null)}

    # 更新 docker-compose.yml
    cat > docker-compose.yml <<EOF
services:
  $CONTAINER_NAME:
    image: ghcr.io/fish2018/pansou-web
    container_name: $CONTAINER_NAME
    restart: unless-stopped
    ports:
      - "$FRONTEND_PORT:80"
    environment:
      CHANNELS: "$CHANNELS"
      PLUGINS_ENABLED: "$PLUGINS_ENABLED"
      PROXY: "$PROXY"
      EXT: '$EXT'
EOF

    # 重启服务
    docker compose up -d
    echo "✅ 环境变量已更新并重启容器"
}

# 交互菜单
menu() {
    while true; do
        echo ""
        echo "========== PanSou 管理菜单 =========="
        echo "1) 安装 / 启动 PanSou 前后端集成版"
        echo "2) 查看状态"
        echo "3) 停止 PanSou"
        echo "4) 重启 PanSou"
        echo "5) 修改环境变量并重启"
        echo "6) 卸载 PanSou"
        echo "0) 退出"
        echo "===================================="
        read -p "请输入选项: " CHOICE
        case $CHOICE in
            1)
                if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}\$"; then
                    echo "✅ PanSou 已安装"
                    docker compose up -d
                else
                    install_pansou_web
                fi
                show_status
                ;;
            2)
                show_status
                ;;
            3)
                stop_pansou
                ;;
            4)
                restart_pansou
                ;;
            5)
                modify_env
                ;;
            6)
                uninstall_pansou
                ;;
            0)
                echo "👋 退出"
                exit 0
                ;;
            *)
                echo "⚠️ 无效选项"
                ;;
        esac
    done
}

menu
