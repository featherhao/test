#!/bin/bash

# 定义端口和配置文件
SHLINK_WEB_PORT=9050
SHLINK_API_PORT=9040
CONFIG_DIR="shlink_deploy"
CONFIG_FILE="${CONFIG_DIR}/shlink_config.txt"
COMPOSE_FILE="${CONFIG_DIR}/docker-compose.yml"

# 获取服务器公网 IP
PUBLIC_IP=$(curl -s https://ipinfo.io/ip)

# 检查 Docker 和 Docker Compose 是否安装
check_prerequisites() {
    if ! command -v docker &> /dev/null; then
        echo "Docker 未安装，正在为您安装..."
        curl -fsSL https://get.docker.com | sh
        if [ $? -ne 0 ]; then
            echo "Docker 安装失败，请手动安装后重试。"
            exit 1
        fi
        echo "Docker 安装成功！"
    fi
    systemctl start docker
    systemctl enable docker

    if ! command -v docker-compose &> /dev/null; then
        echo "Docker Compose 未安装，正在为您安装..."
        apt-get update && apt-get install -y docker-compose
        if [ $? -ne 0 ]; then
            echo "Docker Compose 安装失败，请手动安装后重试。"
            exit 1
        fi
        echo "Docker Compose 安装成功！"
    fi
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

# 部署服务
install_shlink() {
    check_prerequisites
    echo "--- 开始部署 Shlink 短链服务 (Docker Compose) ---"

    # 创建独立的部署目录并进入
    mkdir -p "${CONFIG_DIR}"
    cd "${CONFIG_DIR}"

    # 强制清理旧容器和数据卷，确保干净部署
    echo "正在彻底清理旧的 Shlink 容器和数据卷..."
    docker-compose down --volumes --rmi local &> /dev/null
    rm -f "${COMPOSE_FILE}" "${CONFIG_FILE}"

    # 生成 API Key 并保存到本地文件
    SHLINK_API_KEY=$(cat /proc/sys/kernel/random/uuid)
    echo "${SHLINK_API_KEY}" > "${CONFIG_FILE}"
    echo "已生成新的 API Key 并保存到 ${CONFIG_FILE} 文件。"

    # 生成 docker-compose.yml 文件
    echo "正在生成 docker-compose.yml 文件..."
    cat << EOF > "${COMPOSE_FILE}"
services:
  shlink:
    image: shlinkio/shlink:latest
    container_name: shlink
    restart: always
    ports:
      - "${SHLINK_API_PORT}:8080"
    volumes:
      - shlink-data:/var/www/html/data
    environment:
      - IS_HTTPS_ENABLED=false
      - GEOLITE_LICENSE_KEY=
      - INITIAL_API_KEYS=${SHLINK_API_KEY}

  shlink-web-client:
    image: shlinkio/shlink-web-client
    container_name: shlink-web-client
    restart: always
    ports:
      - "${SHLINK_WEB_PORT}:8080"
    environment:
      - SHLINK_API_URL=http://${PUBLIC_IP}:${SHLINK_API_PORT}
      - SHLINK_API_KEY=${SHLINK_API_KEY}

volumes:
  shlink-data:
EOF
    echo "docker-compose.yml 文件已生成。"

    # 使用 Docker Compose 启动服务
    echo "正在使用 Docker Compose 启动服务..."
    docker-compose up -d

    echo "--- 部署完成！ ---"
    cd ..
    show_info
}

# 卸载服务
uninstall_shlink() {
    echo "--- 开始卸载 Shlink 服务 ---"
    read -p "此操作将永久删除容器、数据卷和配置文件。确定要继续吗? (y/n): " confirm
    if [[ $confirm != "y" ]]; then
        echo "操作已取消。"
        return
    fi

    echo "正在使用 Docker Compose 停止并移除服务..."
    if [ -d "${CONFIG_DIR}" ]; then
        cd "${CONFIG_DIR}"
        docker-compose down --volumes --rmi local &> /dev/null
        cd ..
        rm -rf "${CONFIG_DIR}"
    fi

    echo "--- 卸载完成！ ---"
}

# 更新服务
update_shlink() {
    echo "--- 开始更新 Shlink 服务 ---"
    
    if [ ! -d "${CONFIG_DIR}" ]; then
        echo "未找到 Shlink 部署目录，请先安装服务。"
        return
    fi

    cd "${CONFIG_DIR}"
    echo "正在拉取最新镜像..."
    docker-compose pull
    
    echo "正在使用 Docker Compose 重新启动服务..."
    docker-compose up -d --force-recreate

    echo "--- 更新完成！ ---"
    cd ..
    show_info
}

# 查看服务信息
show_info() {
    # 尝试从配置文件读取 API Key
    if [ -f "${CONFIG_FILE}" ]; then
        SHLINK_API_KEY=$(cat "${CONFIG_FILE}")
    else
        SHLINK_API_KEY="未找到配置文件，请先运行安装或更新"
    fi

    echo "--- Shlink 服务信息 ---"
    echo "前端地址: http://${PUBLIC_IP}:${SHLINK_WEB_PORT}"
    echo "后端 API 地址: http://${PUBLIC_IP}:${SHLINK_API_PORT}"
    echo "默认 API Key: ${SHLINK_API_KEY}"
    echo "--------------------------"
    echo "请使用以上信息登录 Shlink 面板。"
}

# 显示主菜单
show_menu() {
    while true; do
        echo "--- Shlink 短链服务管理 ---"
        check_container_status "shlink"
        check_container_status "shlink-web-client"
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
            4) show_info ;;
            0) echo "脚本已退出。"; exit 0 ;;
            *) echo "无效选项，请重新输入。" ;;
        esac
        echo ""
    done
}

show_menu
