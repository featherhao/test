#!/bin/bash
set -e

# 配置
CONTAINER_NAME="pansou-web"
PAN_DIR="/root/pansou-web"
FRONTEND_PORT=8001 # 默认端口已修改为 8001
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
    mkdir -p "$PAN_DIR"
    cd "$PAN_DIR"

    # 检查端口
    if ! check_port "$FRONTEND_PORT"; then
        read -p "⚠️ 端口 $FRONTEND_PORT 已被占用，请输入新端口 (回车默认 8080): " INPUT_PORT
        FRONTEND_PORT=${INPUT_PORT:-8080}
    fi
    echo "✅ 前端端口 $FRONTEND_PORT 可用"

    # 写 docker-compose.yml，初次安装不设置 CHANNELS 环境变量
    cat > docker-compose.yml <<EOF
services:
  $CONTAINER_NAME:
    image: ghcr.io/fish2018/pansou-web
    container_name: $CONTAINER_NAME
    restart: unless-stopped
    ports:
      - "$FRONTEND_PORT:80"
    environment:
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
    cd "$PAN_DIR"
    if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}\$"; then
        PUBLIC_IPV4=$(curl -4 -s ifconfig.me 2>/dev/null || echo "无法获取IPv4")
        PUBLIC_IPV6=$(curl -6 -s ifconfig.me 2>/dev/null || echo "无法获取IPv6")
        
        # 动态获取当前正在使用的前端端口
        CURRENT_PORT=$(docker compose port "$CONTAINER_NAME" 80 | cut -d':' -f2 || echo "$FRONTEND_PORT")

        echo "✅ PanSou 正在运行"
        echo "👉 前端地址 (IPv4): http://$PUBLIC_IPV4:$CURRENT_PORT"
        echo "👉 前端地址 (IPv6): http://[$PUBLIC_IPV6]:$CURRENT_PORT"
        echo "👉 API 地址: http://$PUBLIC_IPV4:$CURRENT_PORT/api/search"

        CHANNELS_FULL=$(docker compose exec "$CONTAINER_NAME" printenv CHANNELS 2>/dev/null)
        
        # 检查 CHANNELS 是否为空，若为空则显示“使用镜像默认列表”
        if [ -z "$CHANNELS_FULL" ]; then
            echo "📡 当前 TG 频道: 使用镜像自带默认列表"
        else
            CHANNELS_ARRAY=(${CHANNELS_FULL//,/ })
            TOTAL=${#CHANNELS_ARRAY[@]}
            echo "📡 当前 TG 频道 (共 $TOTAL 个):"
            for (( i=0; i<${#CHANNELS_ARRAY[@]}; i+=10 )); do
                DISPLAY=$(IFS=, ; echo "${CHANNELS_ARRAY[@]:$i:10}")
                echo "   $DISPLAY"
            done
        fi
        
        echo "🧩 启用插件: $(docker compose exec "$CONTAINER_NAME" printenv PLUGINS_ENABLED 2>/dev/null)"
    else
        echo "⚠️ PanSou 未运行"
    fi
}

stop_pansou() {
    cd "$PAN_DIR"
    docker compose down
    echo "✅ PanSou 已停止"
}

restart_pansou() {
    cd "$PAN_DIR"
    docker compose restart
    echo "✅ PanSou 已重启"
}

uninstall_pansou() {
    if [ -d "$PAN_DIR" ]; then
        cd "$PAN_DIR"
        docker compose down -v
        cd ~
        rm -rf "$PAN_DIR"
        echo "✅ PanSou 已卸载 (容器和缓存卷已删除)"
    else
        echo "⚠️ PanSou 未安装或已卸载"
    fi
}

modify_env() {
    cd "$PAN_DIR"

    # 动态获取当前正在使用的前端端口
    FRONTEND_PORT=$(docker compose port "$CONTAINER_NAME" 80 | cut -d':' -f2 || echo "$FRONTEND_PORT")

    echo "当前环境变量："
    echo "1) CHANNELS: $(docker compose exec "$CONTAINER_NAME" printenv CHANNELS 2>/dev/null)"
    echo "2) PLUGINS_ENABLED: $(docker compose exec "$CONTAINER_NAME" printenv PLUGINS_ENABLED 2>/dev/null)"
    echo "3) PROXY: $(docker compose exec "$CONTAINER_NAME" printenv PROXY 2>/dev/null)"
    echo "4) EXT: $(docker compose exec "$CONTAINER_NAME" printenv EXT 2>/dev/null)"
    echo ""

    read -p "输入新的 TG 频道 (多个用逗号分隔，回车保留，或输入 'reset' 重置): " NEW_CHANNELS
    read -p "插件启用 (true/false, 回车保留): " NEW_PLUGINS
    read -p "代理 (socks5://..., 回车保留): " NEW_PROXY
    read -p "EXT JSON (回车保留): " NEW_EXT

    # 获取当前环境变量
    CURRENT_CHANNELS=$(docker compose exec "$CONTAINER_NAME" printenv CHANNELS 2>/dev/null)
    CURRENT_PLUGINS_ENABLED=$(docker compose exec "$CONTAINER_NAME" printenv PLUGINS_ENABLED 2>/dev/null)
    CURRENT_PROXY=$(docker compose exec "$CONTAINER_NAME" printenv PROXY 2>/dev/null)
    CURRENT_EXT=$(docker compose exec "$CONTAINER_NAME" printenv EXT 2>/dev/null)

    # 处理 CHANNELS 的逻辑
    if [ -n "$NEW_CHANNELS" ]; then
        if [ "$NEW_CHANNELS" = "reset" ]; then
            CHANNELS=""
        else
            if [ -n "$CURRENT_CHANNELS" ]; then
                CHANNELS="$CURRENT_CHANNELS,$NEW_CHANNELS"
            else
                CHANNELS="$NEW_CHANNELS"
            fi
        fi
    else
        CHANNELS="$CURRENT_CHANNELS"
    fi

    # 处理其他变量
    PLUGINS_ENABLED=${NEW_PLUGINS:-$CURRENT_PLUGINS_ENABLED}
    PROXY=${NEW_PROXY:-$CURRENT_PROXY}
    EXT=${NEW_EXT:-$CURRENT_EXT}

    # 更新 docker-compose.yml 文件
    cat > docker-compose.yml <<EOF
services:
  $CONTAINER_NAME:
    image: ghcr.io/fish2018/pansou-web
    container_name: $CONTAINER_NAME
    restart: unless-stopped
    ports:
      - "$FRONTEND_PORT:80"
    environment:
      PLUGINS_ENABLED: "$PLUGINS_ENABLED"
      PROXY: "$PROXY"
      EXT: '$EXT'
EOF

    if [ -n "$CHANNELS" ]; then
        sed -i "/environment:/a\      CHANNELS: \"$CHANNELS\"" docker-compose.yml
    fi

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
