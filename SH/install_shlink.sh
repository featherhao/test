#!/bin/bash
set -e

WORKDIR="/opt/shlink"
COMPOSE_FILE="$WORKDIR/docker-compose.yml"
ENV_FILE="$WORKDIR/.env"

# 检查Docker是否安装
check_docker() {
    if ! command -v docker &> /dev/null; then
        echo "错误: Docker未安装。请先安装Docker。"
        exit 1
    fi
}

# 检查Docker Compose是否可用
check_compose() {
    if ! docker compose version &> /dev/null && ! command -v docker-compose &> /dev/null; then
        echo "错误: Docker Compose未安装。请先安装Docker Compose。"
        exit 1
    fi
}

# 获取Compose命令
compose_cmd() {
    if docker compose version &> /dev/null; then
        echo "docker compose"
    else
        echo "docker-compose"
    fi
}

# 获取本机IP地址
get_ip() {
    local ipv4=$(curl -s4 https://ipinfo.io/ip || echo "无法获取IPv4")
    local ipv6=$(curl -s6 https://ipinfo.io/ip || echo "无法获取IPv6")
    echo "$ipv4" "$ipv6"
}

menu() {
    clear
    echo "============================"
    echo " Shlink 短链服务管理脚本"
    echo "============================"
    echo "1) 安装 Shlink 服务"
    echo "2) 卸载 Shlink 服务"
    echo "3) 更新 Shlink 服务"
    echo "4) 查看服务信息"
    echo "5) 重启服务"
    echo "0) 退出"
    echo "----------------------------"
    read -p "请输入选项: " choice

    case "$choice" in
        1) install_shlink ;;
        2) uninstall_shlink ;;
        3) update_shlink ;;
        4) info_shlink ;;
        5) restart_shlink ;;
        0) exit 0 ;;
        *) echo "无效选项，请重新输入" && sleep 2 && menu ;;
    esac
}

install_shlink() {
    echo "--- 开始部署 Shlink 短链服务 ---"
    
    # 检查依赖
    check_docker
    check_compose
    
    # 创建工作目录
    mkdir -p "$WORKDIR"
    cd "$WORKDIR"

    # 检查是否已安装
    if [ -f "$COMPOSE_FILE" ]; then
        echo "检测到已存在的Shlink安装。"
        read -p "是否要重新安装？这将删除所有现有数据！(y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "安装已取消。"
            sleep 2
            menu
            return
        fi
        uninstall_shlink
    fi

    # 获取用户输入
    echo "请输入配置信息（直接回车使用默认值）:"
    read -p "请输入短网址服务 API 域名 (例如: api.example.com): " API_DOMAIN
    read -p "请输入 Web Client 域名 (例如: short.example.com): " CLIENT_DOMAIN
    read -p "请输入 Shlink API 端口 [默认: 8080]: " API_PORT
    API_PORT=${API_PORT:-8080}
    read -p "请输入 Web Client 端口 [默认: 80]: " CLIENT_PORT
    CLIENT_PORT=${CLIENT_PORT:-80}
    read -p "请输入数据库密码 [默认: shlinkpass]: " DB_PASSWORD
    DB_PASSWORD=${DB_PASSWORD:-shlinkpass}
    read -p "请输入 GeoLite2 License Key (可选，留空则不启用): " GEO_KEY

    # 生成随机数据库密码（如果未提供）
    if [ -z "$DB_PASSWORD" ]; then
        DB_PASSWORD=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 16)
    fi

    # 生成环境变量文件
    cat > "$ENV_FILE" <<EOF
# Shlink 环境配置
API_DOMAIN=$API_DOMAIN
CLIENT_DOMAIN=$CLIENT_DOMAIN
API_PORT=$API_PORT
CLIENT_PORT=$CLIENT_PORT
DB_PASSWORD=$DB_PASSWORD
GEO_KEY=$GEO_KEY
EOF

    # 生成 docker-compose.yml
    cat > "$COMPOSE_FILE" <<EOF
version: "3.9"
services:
  shlink_db:
    image: postgres:15-alpine
    container_name: shlink_db
    restart: unless-stopped
    environment:
      POSTGRES_USER: shlink
      POSTGRES_PASSWORD: \$DB_PASSWORD
      POSTGRES_DB: shlink
    volumes:
      - db_data:/var/lib/postgresql/data
    networks:
      - shlink_net
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U shlink -d shlink"]
      interval: 10s
      timeout: 5s
      retries: 5

  shlink:
    image: shlinkio/shlink:stable
    container_name: shlink
    restart: unless-stopped
    depends_on:
      shlink_db:
        condition: service_healthy
    env_file:
      - .env
    environment:
      DEFAULT_DOMAIN: \$API_DOMAIN
      IS_HTTPS_ENABLED: "false"
      GEOLITE_LICENSE_KEY: \$GEO_KEY
      DB_DRIVER: postgres
      DB_USER: shlink
      DB_PASSWORD: \$DB_PASSWORD
      DB_HOST: shlink_db
      DB_NAME: shlink
      DB_PORT: 5432
    ports:
      - "\$API_PORT:8080"
    networks:
      - shlink_net
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 3

  shlink_web_client:
    image: shlinkio/shlink-web-client:stable
    container_name: shlink_web_client
    restart: unless-stopped
    depends_on:
      - shlink
    environment:
      SHLINK_SERVER_URL: http://\$API_DOMAIN:\$API_PORT
      SHLINK_SERVER_API_KEY: \${API_KEY:-}
    ports:
      - "\$CLIENT_PORT:80"
    networks:
      - shlink_net

networks:
  shlink_net:
    driver: bridge

volumes:
  db_data:
    driver: local
EOF

    echo "--- 启动 Shlink 服务 ---"
    $(compose_cmd) up -d

    echo "--- 等待 Shlink API 就绪（最多 60 秒）---"
    local READY=0
    for i in {1..30}; do
        if $(compose_cmd) exec shlink shlink api-key:list >/dev/null 2>&1; then
            READY=1
            break
        else
            echo "等待 API 启动... ($i/30)"
            sleep 2
        fi
    done

    if [ $READY -ne 1 ]; then
        echo "Shlink API 启动失败，请检查容器日志"
        $(compose_cmd) logs shlink
        exit 1
    fi

    echo "--- 生成 API Key ---"
    API_KEY=$($(compose_cmd) exec shlink shlink api-key:generate --expiration="never" | grep -oE '[0-9a-f-]{36}' | head -n1)
    
    # 更新环境变量文件
    echo "API_KEY=$API_KEY" >> "$ENV_FILE"
    
    # 重启Web Client以应用API Key
    $(compose_cmd) up -d shlink_web_client

    # 获取IP地址
    read ipv4 ipv6 <<< $(get_ip)

    echo "============================"
    echo " Shlink 部署完成！"
    echo "API Key: $API_KEY"
    echo ""
    echo "访问方式："
    echo "本机访问:"
    echo "  - API: http://localhost:$API_PORT"
    echo "  - Web: http://localhost:$CLIENT_PORT"
    echo "域名访问:"
    echo "  - API: http://$API_DOMAIN:$API_PORT"
    echo "  - Web: http://$CLIENT_DOMAIN:$CLIENT_PORT"
    
    if [ "$ipv4" != "无法获取IPv4" ]; then
        echo "IPv4访问:"
        echo "  - API: http://$ipv4:$API_PORT"
        echo "  - Web: http://$ipv4:$CLIENT_PORT"
    fi
    
    if [ "$ipv6" != "无法获取IPv6" ]; then
        echo "IPv6访问:"
        echo "  - API: http://[$ipv6]:$API_PORT"
        echo "  - Web: http://[$ipv6]:$CLIENT_PORT"
    fi
    
    echo ""
    echo "重要: 请确保您的域名已正确解析到本服务器"
    echo "============================"

    read -p "按回车键返回菜单..."
    menu
}

uninstall_shlink() {
    echo "--- 卸载 Shlink 服务 ---"
    
    if [ ! -f "$COMPOSE_FILE" ]; then
        echo "未找到Shlink安装。"
        read -p "按回车键返回菜单..."
        menu
        return
    fi
    
    cd "$WORKDIR"
    
    read -p "确定要卸载Shlink吗？这将删除所有数据！(y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "卸载已取消。"
        sleep 2
        menu
        return
    fi
    
    $(compose_cmd) down -v
    cd /opt
    rm -rf "$WORKDIR"
    echo "Shlink 已卸载"
    read -p "按回车键返回菜单..."
    menu
}

update_shlink() {
    echo "--- 更新 Shlink 服务 ---"
    
    if [ ! -f "$COMPOSE_FILE" ]; then
        echo "未找到Shlink安装。"
        read -p "按回车键返回菜单..."
        menu
        return
    fi
    
    cd "$WORKDIR"
    $(compose_cmd) pull
    $(compose_cmd) up -d
    echo "Shlink 已更新"
    read -p "按回车键返回菜单..."
    menu
}

restart_shlink() {
    echo "--- 重启 Shlink 服务 ---"
    
    if [ ! -f "$COMPOSE_FILE" ]; then
        echo "未找到Shlink安装。"
        read -p "按回车键返回菜单..."
        menu
        return
    fi
    
    cd "$WORKDIR"
    $(compose_cmd) restart
    echo "Shlink 已重启"
    read -p "按回车键返回菜单..."
    menu
}

info_shlink() {
    echo "--- Shlink 服务信息 ---"
    
    if [ ! -f "$COMPOSE_FILE" ]; then
        echo "未找到Shlink安装。"
        read -p "按回车键返回菜单..."
        menu
        return
    fi
    
    cd "$WORKDIR"
    echo "容器状态:"
    $(compose_cmd) ps
    
    echo -e "\n服务配置:"
    if [ -f "$ENV_FILE" ]; then
        grep -v "DB_PASSWORD\|API_KEY" "$ENV_FILE"
    fi
    
    read -p "按回车键返回菜单..."
    menu
}

# 启动菜单
check_docker
check_compose
menu