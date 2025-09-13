#!/bin/bash
set -e

# =======================================================
# Shlink 短网址服务 一键安装/管理脚本
# 终极无文件版：绕过本地文件系统，确保部署成功
# =======================================================

# -------------------------------------------------------
# 配置变量
# -------------------------------------------------------
SHLINK_API_CONTAINER="shlink_api"
SHLINK_WEB_CONTAINER="shlink_web_client"
SHLINK_DB_CONTAINER="shlink_db"

# -------------------------------------------------------
# 辅助函数
# -------------------------------------------------------

# Docker Compose 命令包装器，兼容新旧版本
DOCKER_COMPOSE() {
  if command -v docker-compose >/dev/null 2>&1; then
    docker-compose "$@"
  else
    docker compose "$@"
  fi
}

# 检查 Docker 和 Docker Compose 是否安装
check_prerequisites() {
    if ! command -v docker >/dev/null 2>&1; then
        echo "❌ 未检测到 Docker，正在为您安装..."
        curl -fsSL https://get.docker.com | sh
        if [ $? -ne 0 ]; then
            echo "Docker 安装失败。请手动安装后重试。"
            exit 1
        fi
        sudo usermod -aG docker "$USER"
        echo "✅ Docker 安装成功。请重新登录或运行 'newgrp docker' 以应用用户组更改。"
        exit 1
    fi

    if ! command -v docker-compose >/dev/null 2>&1 && ! docker compose version >/dev/null 2>&1; then
        echo "❌ 未检测到 Docker Compose，正在为您安装..."
        sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
        echo "✅ Docker Compose 安装成功。"
    fi
    echo "✅ Docker 和 Docker Compose 已就绪。"
}

# 检查容器状态
check_container_status() {
    local container_name=$1
    if docker ps -a --format "{{.Names}}" | grep -Eq "^${container_name}$"; then
        if docker ps --format "{{.Names}}" | grep -Eq "^${container_name}$"; then
            echo -e "✅ \033[32m${container_name}\033[0m 容器正在运行"
        else
            echo -e "⚠️ \033[33m${container_name}\033[0m 容器已停止"
        fi
    else
        echo -e "❌ \033[31m${container_name}\033[0m 容器未安装"
    fi
}

# -------------------------------------------------------
# 主要功能函数
# -------------------------------------------------------

# 部署服务
install_shlink() {
    check_prerequisites

    echo "--- 开始部署 Shlink 短链服务 ---"

    # 彻底清理所有残留的旧容器
    echo "正在彻底清理旧的 Shlink 容器..."
    docker stop ${SHLINK_API_CONTAINER} ${SHLINK_WEB_CONTAINER} ${SHLINK_DB_CONTAINER} &>/dev/null || true
    docker rm -f ${SHLINK_API_CONTAINER} ${SHLINK_WEB_CONTAINER} ${SHLINK_DB_CONTAINER} &>/dev/null || true
    
    # 引导用户输入配置
    read -p "请输入您短网址的域名 (例如: u.example.com): " DEFAULT_DOMAIN
    read -p "请输入 Web Client 的域名 (例如: app.example.com): " WEB_CLIENT_DOMAIN
    read -p "请输入短网址服务 (Shlink) 的监听端口 [默认: 9040]: " SHLINK_API_PORT
    SHLINK_API_PORT=${SHLINK_API_PORT:-9040}
    read -p "请输入 Web Client (前端) 的监听端口 [默认: 9050]: " SHLINK_WEB_PORT
    SHLINK_WEB_PORT=${SHLINK_WEB_PORT:-9050}
    read -p "请输入 GeoLite2 的 License Key (可选，留空则不启用地理统计): " GEOLITE_LICENSE_KEY

    # 自动生成数据库密码
    DB_PASSWORD=$(cat /dev/urandom | tr -dc A-Za-z0-9 | head -c 16)

    # 直接使用 docker-compose 管道部署，不创建文件
    echo "正在使用 Docker Compose 管道部署服务..."
    DOCKER_COMPOSE -f - up -d << EOF
version: '3.8'
services:
  shlink:
    image: shlinkio/shlink:stable
    container_name: ${SHLINK_API_CONTAINER}
    ports:
      - "127.0.0.1:${SHLINK_API_PORT}:8080"
    environment:
      - DEFAULT_DOMAIN=${DEFAULT_DOMAIN}
      - IS_HTTPS_ENABLED=true
      - GEOLITE_LICENSE_KEY=${GEOLITE_LICENSE_KEY}
      - DB_DRIVER=maria
      - DB_NAME=shlink
      - DB_USER=shlink
      - DB_PASSWORD=${DB_PASSWORD}
      - DB_HOST=db
      - DB_PORT=3306
      - TIMEZONE=UTC
      - REDIRECT_STATUS_CODE=301
    restart: always
  
  db:
    image: mariadb:10.11
    container_name: ${SHLINK_DB_CONTAINER}
    environment:
      - MYSQL_ROOT_PASSWORD=${DB_PASSWORD}
      - MYSQL_DATABASE=shlink
      - MYSQL_USER=shlink
      - MYSQL_PASSWORD=${DB_PASSWORD}
    volumes:
      - shlink_data:/var/lib/mysql
    restart: always

  shlink-web-client:
    image: shlinkio/shlink-web-client:stable
    container_name: ${SHLINK_WEB_CONTAINER}
    ports:
      - "127.0.0.1:${SHLINK_WEB_PORT}:8080"
    restart: always

volumes:
  shlink_data:
EOF

    echo "--- 部署完成！ ---"
    echo "所有服务已在后台启动。您可以使用 '查看服务信息' 选项来获取 API Key 和其他信息。"
    
    read -p "按任意键返回主菜单..."
}

# 卸载服务
uninstall_shlink() {
    echo "--- 开始卸载 Shlink 服务 ---"
    read -p "此操作将永久删除容器和数据卷。确定要继续吗? (y/n): " confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        echo "操作已取消。"
        return
    fi

    echo "正在强制停止并移除所有 Shlink 容器..."
    docker stop ${SHLINK_API_CONTAINER} ${SHLINK_WEB_CONTAINER} ${SHLINK_DB_CONTAINER} &>/dev/null || true
    docker rm -f ${SHLINK_API_CONTAINER} ${SHLINK_WEB_CONTAINER} ${SHLINK_DB_CONTAINER} &>/dev/null || true

    echo "✅ 卸载完成！"
    read -p "按任意键返回主菜单..."
}

# 更新服务
update_shlink() {
    echo "--- 开始更新 Shlink 服务 ---"
    echo "正在拉取最新镜像..."
    docker pull shlinkio/shlink:stable
    docker pull shlinkio/shlink-web-client:stable
    docker pull mariadb:10.11
    echo "✅ 镜像更新完成！"

    echo "正在重建并启动容器..."
    local DEFAULT_DOMAIN=$(docker exec ${SHLINK_API_CONTAINER} printenv DEFAULT_DOMAIN 2>/dev/null)
    local GEOLITE_LICENSE_KEY=$(docker exec ${SHLINK_API_CONTAINER} printenv GEOLITE_LICENSE_KEY 2>/dev/null)
    local DB_PASSWORD=$(docker exec ${SHLINK_DB_CONTAINER} printenv MYSQL_PASSWORD 2>/dev/null)
    
    DOCKER_COMPOSE -f - up -d --force-recreate << EOF
version: '3.8'
services:
  shlink:
    image: shlinkio/shlink:stable
    container_name: ${SHLINK_API_CONTAINER}
    ports:
      - "127.0.0.1:9040:8080"
    environment:
      - DEFAULT_DOMAIN=${DEFAULT_DOMAIN}
      - IS_HTTPS_ENABLED=true
      - GEOLITE_LICENSE_KEY=${GEOLITE_LICENSE_KEY}
      - DB_DRIVER=maria
      - DB_NAME=shlink
      - DB_USER=shlink
      - DB_PASSWORD=${DB_PASSWORD}
      - DB_HOST=db
      - DB_PORT=3306
      - TIMEZONE=UTC
      - REDIRECT_STATUS_CODE=301
    restart: always
  
  db:
    image: mariadb:10.11
    container_name: ${SHLINK_DB_CONTAINER}
    environment:
      - MYSQL_ROOT_PASSWORD=${DB_PASSWORD}
      - MYSQL_DATABASE=shlink
      - MYSQL_USER=shlink
      - MYSQL_PASSWORD=${DB_PASSWORD}
    volumes:
      - shlink_data:/var/lib/mysql
    restart: always

  shlink-web-client:
    image: shlinkio/shlink-web-client:stable
    container_name: ${SHLINK_WEB_CONTAINER}
    ports:
      - "127.0.0.1:9050:8080"
    restart: always

volumes:
  shlink_data:
EOF
    echo "✅ 更新完成！"
    show_info_from_running_containers
    read -p "按任意键返回主菜单..."
}

# 从运行中的容器获取信息
show_info_from_running_containers() {
    local public_ip=$(curl -s https://ipinfo.io/ip)
    
    local api_port=$(docker inspect --format='{{(index (index .NetworkSettings.Ports "8080/tcp") 0).HostPort}}' ${SHLINK_API_CONTAINER} 2>/dev/null || echo "无法获取")
    local web_port=$(docker inspect --format='{{(index (index .NetworkSettings.Ports "8080/tcp") 0).HostPort}}' ${SHLINK_WEB_CONTAINER} 2>/dev/null || echo "无法获取")
    local default_domain=$(docker exec ${SHLINK_API_CONTAINER} printenv DEFAULT_DOMAIN 2>/dev/null || echo "无法获取")
    local web_domain=$(docker exec ${SHLINK_API_CONTAINER} printenv WEB_CLIENT_DOMAIN 2>/dev/null || echo "无法获取")

    echo "等待 Shlink 服务初始化..."
    for i in {1..10}; do
        if docker exec ${SHLINK_API_CONTAINER} shlink api-key:list --no-interaction >/dev/null 2>&1; then
            break
        fi
        echo "Shlink 未就绪，5 秒后重试 ($i/10)..."
        sleep 5
    done

    echo "正在尝试获取 API Key..."
    API_KEY=$(docker exec ${SHLINK_API_CONTAINER} shlink api-key:list --no-interaction 2>/dev/null | awk 'NR==4 {print $1}')

    if [ -z "$API_KEY" ]; then
        echo "未检测到现有 API Key，正在生成新的..."
        API_KEY=$(docker exec ${SHLINK_API_CONTAINER} shlink api-key:generate --no-interaction 2>/dev/null | awk '/Key:/ {print $2}')
    fi

    echo "✅ API Key 已成功获取！"

    show_info "${default_domain}" "${web_domain}" "${api_port}" "${web_port}" "${API_KEY}"
    read -p "按任意键返回主菜单..."
}

# 显示最终信息
show_info() {
    local DEFAULT_DOMAIN=$1
    local WEB_CLIENT_DOMAIN=$2
    local SHLINK_API_PORT=$3
    local SHLINK_WEB_PORT=$4
    local API_KEY=$5
    local PUBLIC_IP=$(curl -s https://ipinfo.io/ip)

    echo "------------------------------------"
    echo "  🎉 Shlink 服务信息 🎉"
    echo "------------------------------------"
    echo "您的短网址域名 (Shlink API): ${DEFAULT_DOMAIN}"
    echo "您的管理面板域名 (Web Client): ${WEB_CLIENT_DOMAIN}"
    echo ""
    echo "以下为服务 IP 和端口，用于测试或调试："
    echo "  - 短网址服务 (Shlink API): http://${PUBLIC_IP}:${SHLINK_API_PORT}"
    echo "  - 管理面板 (Web Client): http://${PUBLIC_IP}:${SHLINK_WEB_PORT}"
    echo ""
    echo "默认 API Key (用于登录 Web Client):"
    echo "  - ${API_KEY}"
    echo ""
    echo "--- 接下来您需要配置 Nginx 反向代理 ---"
    echo "短网址域名 (${DEFAULT_DOMAIN}) 的 Nginx 配置："
    echo "  proxy_pass http://127.0.0.1:${SHLINK_API_PORT};"
    echo ""
    echo "管理面板域名 (${WEB_CLIENT_DOMAIN}) 的 Nginx 配置："
    echo "  proxy_pass http://127.0.0.1:${SHLINK_WEB_PORT};"
    echo "------------------------------------"
}

# 显示主菜单
show_menu() {
    while true; do
        echo "--- Shlink 短链服务管理 ---"
        check_container_status "${SHLINK_API_CONTAINER}"
        check_container_status "${SHLINK_WEB_CONTAINER}"
        echo "--------------------------"
        echo "1) 安装 Shlink 服务"
        echo "2) 卸载 Shlink 服务"
        echo "3) 更新 Shlink 服务"
        echo "4) 查看服务信息"
        echo "0) 退出"
        echo "--------------------------"
        read -p "请输入选项: " option

        case $option in
            1) install_shlink ;;
            2) uninstall_shlink ;;
            3) update_shlink ;;
            4) show_info_from_running_containers ;;
            0) echo "脚本已退出。"; exit 0 ;;
            *) echo "无效选项，请重新输入。" ;;
        esac
        echo ""
    done
}

show_menu
