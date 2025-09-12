#!/bin/bash

SHLINK_WEB_PORT=9050
SHLINK_API_PORT=9040

# 定义配置文件路径
CONFIG_FILE="shlink_config.txt"

# 获取服务器公网 IP
PUBLIC_IP=$(curl -s https://ipinfo.io/ip)

# 检查 Docker 是否安装
check_docker() {
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
    check_docker
    echo "--- 开始部署 Shlink 短链服务 ---"

    # 检查并生成或读取 API Key
    if [ -f "$CONFIG_FILE" ]; then
        SHLINK_API_KEY=$(cat "$CONFIG_FILE")
        echo "已找到配置文件，使用已有的 API Key: ${SHLINK_API_KEY}"
    else
        SHLINK_API_KEY=$(cat /proc/sys/kernel/random/uuid)
        echo "${SHLINK_API_KEY}" > "$CONFIG_FILE"
        echo "首次运行，已生成新的 API Key 并保存到 ${CONFIG_FILE} 文件。"
    fi
    
    # 部署后端容器
    if ! docker ps -a --format "{{.Names}}" | grep -Eq "^shlink$"; then
        echo "正在部署 Shlink 后端容器..."
        docker run --name shlink -d --restart=always \
            -v shlink-data:/var/www/html/data \
            -p ${SHLINK_API_PORT}:8080 \
            -e IS_HTTPS_ENABLED=false \
            -e GEOLITE_LICENSE_KEY="" \
            -e DEFAULT_DOMAIN="${PUBLIC_IP}" \
            -e NEW_API_KEYS="${SHLINK_API_KEY}" \
            shlinkio/shlink:latest
        echo "Shlink 后端容器部署完成。"
    else
        echo "Shlink 后端容器已存在，跳过部署。"
    fi

    # 部署前端容器
    if ! docker ps -a --format "{{.Names}}" | grep -Eq "^shlink-web-client$"; then
        echo "正在部署 Shlink 前端容器..."
        docker run -d --name shlink-web-client --restart=always -p ${SHLINK_WEB_PORT}:8080 \
            -e SHLINK_API_URL="http://${PUBLIC_IP}:${SHLINK_API_PORT}" \
            -e SHLINK_API_KEY="${SHLINK_API_KEY}" \
            shlinkio/shlink-web-client
        echo "Shlink 前端容器部署完成。"
    else
        echo "Shlink 前端容器已存在，跳过部署。"
    fi

    echo "--- 部署完成！ ---"
    show_info
}

# 卸载服务
uninstall_shlink() {
    echo "--- 开始卸载 Shlink 服务 ---"
    read -p "此操作将永久删除容器和数据卷。确定要继续吗? (y/n): " confirm
    if [[ $confirm != "y" ]]; then
        echo "操作已取消。"
        return
    fi

    echo "正在停止并移除 Shlink 容器..."
    docker stop shlink shlink-web-client &> /dev/null
    docker rm shlink shlink-web-client &> /dev/null

    echo "正在移除数据卷 shlink-data..."
    docker volume rm shlink-data &> /dev/null

    echo "正在删除配置文件..."
    rm -f "${CONFIG_FILE}"

    echo "--- 卸载完成！ ---"
}

# 更新服务
update_shlink() {
    echo "--- 开始更新 Shlink 服务 ---"
    echo "正在拉取最新镜像..."
    docker pull shlinkio/shlink:latest
    docker pull shlinkio/shlink-web-client:latest

    echo "正在停止并移除旧容器..."
    docker stop shlink shlink-web-client &> /dev/null
    docker rm shlink shlink-web-client &> /dev/null
    
    echo "正在使用最新镜像重新部署..."
    install_shlink

    echo "--- 更新完成！ ---"
}

# 查看服务信息
show_info() {
    # 尝试从配置文件读取 API Key
    if [ -f "$CONFIG_FILE" ]; then
        SHLINK_API_KEY=$(cat "$CONFIG_FILE")
    else
        SHLINK_API_KEY="未找到配置文件，可能未安装"
    fi

    echo "--- Shlink 服务信息 ---"
    echo "Frontend 地址: http://${PUBLIC_IP}:${SHLINK_WEB_PORT}"
    echo "Backend API 地址: http://${PUBLIC_IP}:${SHLINK_API_PORT}"
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
