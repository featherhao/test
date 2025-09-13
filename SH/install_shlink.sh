#!/bin/bash
set -e

# =======================================================
# Shlink 短网址服务 一键安装/管理脚本
# 增强版：支持自定义端口、域名和 Nginx 配置
# =======================================================

# -------------------------------------------------------
# 配置变量
# -------------------------------------------------------
CONFIG_DIR="shlink_deploy"
DATA_DIR="${CONFIG_DIR}/data"
COMPOSE_FILE="${CONFIG_DIR}/docker-compose.yml"
SHLINK_API_CONTAINER="shlink_api"
SHLINK_WEB_CONTAINER="shlink_web_client"

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

    if ! command -v docker-compose >/dev/null 2>&1; then
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

    # 清理旧部署，防止冲突
    echo "正在清理可能存在的旧部署..."
    if [ -d "${CONFIG_DIR}" ]; then
        cd "${CONFIG_DIR}" || true
        DOCKER_COMPOSE down --volumes --rmi local &>/dev/null || true
        cd ..
        rm -rf "${CONFIG_DIR}"
    fi

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

    # 创建部署目录
    mkdir -p "${DATA_DIR}"

    # 生成 docker-compose.yml 文件
    echo "正在生成 docker-compose.yml 文件..."
    cat > "${COMPOSE_FILE}" << EOF
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
      container_name: shlink_db
      environment:
        - MYSQL_ROOT_PASSWORD=${DB_PASSWORD}
        - MYSQL_DATABASE=shlink
        - MYSQL_USER=shlink
        - MYSQL_PASSWORD=${DB_PASSWORD}
      volumes:
        - ${DATA_DIR}:/var/lib/mysql
      restart: always

    shlink-web-client:
        image: shlinkio/shlink-web-client:stable
        container_name: ${SHLINK_WEB_CONTAINER}
        ports:
          - "127.0.0.1:${SHLINK_WEB_PORT}:8080"
        restart: always
EOF
    echo "docker-compose.yml 文件已生成。"
    echo "数据库密码: ${DB_PASSWORD} (已自动设置，无需手动输入)"

    # 启动服务
    echo "正在启动服务，这可能需要一些时间..."
    cd "${CONFIG_DIR}"
    DOCKER_COMPOSE up -d

    # 生成 API Key
    echo "正在生成 API Key..."
    API_KEY=$(docker exec -it "${SHLINK_API_CONTAINER}" shlink api-key:generate | grep -o 'API Key:.*' | awk '{print $NF}')
    if [ -z "$API_KEY" ]; then
        echo "❌ API Key 生成失败。请手动执行: docker exec -it ${SHLINK_API_CONTAINER} shlink api-key:generate"
        exit 1
    fi
    echo "✅ Shlink API Key 已生成: ${API_KEY}"

    echo "--- 部署完成！ ---"
    show_info "${DEFAULT_DOMAIN}" "${WEB_CLIENT_DOMAIN}" "${SHLINK_API_PORT}" "${SHLINK_WEB_PORT}" "${API_KEY}"
}

# 卸载服务
uninstall_shlink() {
    echo "--- 开始卸载 Shlink 服务 ---"
    read -p "此操作将永久删除容器、数据卷和配置文件。确定要继续吗? (y/n): " confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        echo "操作已取消。"
        return
    fi

    if [ -d "${CONFIG_DIR}" ]; then
        cd "${CONFIG_DIR}" || true
        echo "正在停止并移除 Docker 服务..."
        DOCKER_COMPOSE down --volumes --rmi local &>/dev/null || true
        cd ..
        echo "正在删除配置文件和数据目录..."
        rm -rf "${CONFIG_DIR}"
    else
        echo "未找到 Shlink 部署目录，无需卸载。"
    fi

    echo "✅ 卸载完成！"
}

# 更新服务
update_shlink() {
    if [ ! -d "${CONFIG_DIR}" ]; then
        echo "❌ 未找到 Shlink 部署目录，请先安装服务。"
        return
    fi

    echo "--- 开始更新 Shlink 服务 ---"
    cd "${CONFIG_DIR}"
    echo "正在拉取最新镜像..."
    DOCKER_COMPOSE pull
    echo "正在重新创建并启动容器..."
    DOCKER_COMPOSE up -d --force-recreate
    echo "✅ 更新完成！"
    show_info_from_file
}

# 查看服务信息 (从文件读取，更稳定)
show_info_from_file() {
    if [ ! -f "${COMPOSE_FILE}" ]; then
        echo "❌ 未找到部署文件，请先安装服务。"
        return
    fi

    local public_ip=$(curl -s https://ipinfo.io/ip)
    local api_port=$(grep -Po 'shlink:\s*ports:\s*-\s*"\K(\d+)(?=:8080")' "${COMPOSE_FILE}" || grep -Po 'shlink:\s*ports:\s*-\s*\K(\d+)(?=:8080)' "${COMPOSE_FILE}")
    local web_port=$(grep -Po 'shlink-web-client:\s*ports:\s*-\s*"\K(\d+)(?=:8080")' "${COMPOSE_FILE}" || grep -Po 'shlink-web-client:\s*ports:\s*-\s*\K(\d+)(?=:8080)' "${COMPOSE_FILE}")
    local default_domain=$(grep -m1 -E 'DEFAULT_DOMAIN=' "${COMPOSE_FILE}" | sed -E 's/.*DEFAULT_DOMAIN=//;s/\s*$//')
    local web_client_domain=$(grep -m1 -E 'SHLINK_WEB_CLIENT_DOMAIN=' "${COMPOSE_FILE}" | sed -E 's/.*SHLINK_WEB_CLIENT_DOMAIN=//;s/\s*$//' || true)
    
    # 动态获取 API Key
    local api_key=$(docker exec -it "${SHLINK_API_CONTAINER}" shlink api-key:list | grep -A1 'API Keys' | tail -n 1 | awk '{print $1}')
    if [ -z "$api_key" ]; then
        api_key="请手动生成，容器已停止或 API Key 列表为空"
    fi

    show_info "${default_domain}" "${web_client_domain}" "${api_port}" "${web_port}" "${api_key}"
}

# 显示最终信息
show_info() {
    local DEFAULT_DOMAIN=$1
    local WEB_CLIENT_DOMAIN=$2
    local SHLINK_API_PORT=$3
    local SHLINK_WEB_PORT=$4
    local API_KEY=$5

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
            4) show_info_from_file ;;
            0) echo "脚本已退出。"; exit 0 ;;
            *) echo "无效选项，请重新输入。" ;;
        esac
        echo ""
    done
}

show_menu