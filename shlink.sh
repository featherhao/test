#!/bin/bash

# --- 全局变量 ---
CONFIG_FILE="./shlink.conf"
DEFAULT_DOMAIN=""
BACKEND_PORT=""
FRONTEND_PORT=""
GEOLITE_LICENSE_KEY=""
API_KEY=""

# --- 颜色设置 ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# --- 配置文件加载 ---
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
    fi
}

save_config() {
    cat > "$CONFIG_FILE" <<EOF
DEFAULT_DOMAIN=$DEFAULT_DOMAIN
BACKEND_PORT=$BACKEND_PORT
FRONTEND_PORT=$FRONTEND_PORT
GEOLITE_LICENSE_KEY=$GEOLITE_LICENSE_KEY
API_KEY=$API_KEY
EOF
}

# --- 辅助函数 ---

check_docker() {
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}错误：未检测到 Docker。请先安装 Docker。${NC}"
        read -p "是否要安装 Docker 和 Docker-compose？(y/n): " install_docker
        if [[ "$install_docker" =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}正在安装 Docker...${NC}"
            curl -fsSL https://get.docker.com -o get-docker.sh
            sudo sh get-docker.sh
            sudo apt-get update
            sudo apt-get install -y docker-compose
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}Docker 和 Docker-compose 安装成功！${NC}"
            else
                echo -e "${RED}Docker 和 Docker-compose 安装失败，请手动安装后重试。${NC}"
                exit 1
            fi
        else
            echo -e "${RED}请先手动安装 Docker 和 Docker-compose，然后再次运行脚本。${NC}"
            exit 1
        fi
    fi
}

get_config() {
    echo -e "\n${YELLOW}--- 请输入配置信息 ---${NC}"

    if [ -z "$GEOLITE_LICENSE_KEY" ]; then
        read -p "请输入 MaxMind GeoLite2 许可证密钥 (可回车跳过): " GEOLITE_LICENSE_KEY
    else
        echo -e "已加载 GeoLite2 Key: ${GREEN}${GEOLITE_LICENSE_KEY}${NC}"
    fi

    PUBLIC_IPv4=$(curl -s https://api.ipify.org)
    PUBLIC_IPv6=$(curl -s -6 https://api64.ipify.org)

    echo "测到 IPv4: ${PUBLIC_IPv4:-无}"
    echo "测到 IPv6: ${PUBLIC_IPv6:-无}"
    read -p "请选择一个作为默认访问地址 (回车默认使用 IPv4): " input_domain

    if [ -n "$input_domain" ]; then
        DEFAULT_DOMAIN="$input_domain"
    else
        DEFAULT_DOMAIN="${PUBLIC_IPv4:-$PUBLIC_IPv6}"
    fi

    read -p "请设置 Shlink 后端访问端口 (回车默认 9040): " BACKEND_PORT
    read -p "请设置 Shlink 前端访问端口 (回车默认 9050): " FRONTEND_PORT

    BACKEND_PORT=${BACKEND_PORT:-9040}
    FRONTEND_PORT=${FRONTEND_PORT:-9050}
}

uninstall_shlink_core() {
    echo -e "${YELLOW}正在停止并删除 Shlink 容器...${NC}"
    docker stop shlink shlink-web-client &>/dev/null
    docker rm -v shlink shlink-web-client &>/dev/null
    echo -e "${GREEN}Shlink 容器已成功删除。${NC}"
}

check_and_uninstall() {
    if docker ps -a --format '{{.Names}}' | grep -q shlink; then
        echo -e "\n${YELLOW}--- 检测到已安装的 Shlink ---${NC}"
        local backend_port=$(docker inspect shlink --format '{{(index (index .NetworkSettings.Ports "8080/tcp") 0).HostPort}}' 2>/dev/null)
        local frontend_port=$(docker inspect shlink-web-client --format '{{(index (index .NetworkSettings.Ports "8080/tcp") 0).HostPort}}' 2>/dev/null)
        local domain=$(docker inspect shlink --format '{{range .Config.Env}}{{if contains . "DEFAULT_DOMAIN"}}{{printf "%s" .}}{{end}}{{end}}' 2>/dev/null | cut -d'=' -f2)

        echo -e "当前后端端口: ${GREEN}${backend_port}${NC}"
        echo -e "当前前端端口: ${GREEN}${frontend_port}${NC}"
        echo -e "当前域名/IP: ${GREEN}${domain}${NC}"

        read -p "是否要继续安装并覆盖现有配置？(y/n): " confirm_reinstall
        if [[ ! "$confirm_reinstall" =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}已取消安装。${NC}"
            return 1
        fi

        uninstall_shlink_core
    fi
    return 0
}

display_status() {
    local shlink_running=$(docker ps -a --format '{{.Names}}' | grep -q shlink; echo $?)
    if [ "$shlink_running" -eq 0 ]; then
        echo -e "\n${GREEN}--- Shlink 已安装 ---${NC}"
        local backend_status=$(docker inspect --format='{{.State.Status}}' shlink 2>/dev/null)
        local frontend_status=$(docker inspect --format='{{.State.Status}}' shlink-web-client 2>/dev/null)
        local backend_host_port=$(docker port shlink 8080/tcp | cut -d: -f2)
        local frontend_host_port=$(docker port shlink-web-client 8080/tcp | cut -d: -f2)
        local domain=$(docker inspect shlink --format '{{range .Config.Env}}{{if contains . "DEFAULT_DOMAIN"}}{{printf "%s" .}}{{end}}{{end}}' 2>/dev/null | cut -d'=' -f2)

        echo -e "Shlink 后端状态: ${GREEN}${backend_status}${NC}"
        echo -e "Shlink 前端状态: ${GREEN}${frontend_status}${NC}"
        echo -e "访问地址：${YELLOW}http://${domain}:${frontend_host_port}${NC}"
        echo -e "后端API地址：${YELLOW}http://${domain}:${backend_host_port}${NC}"

        if [ -n "$API_KEY" ]; then
            echo -e "Shlink API Key：${GREEN}${API_KEY}${NC}"
        else
            local api_key=$(docker exec shlink shlink api-key:list --no-interaction 2>/dev/null | grep -oP '^[0-9a-f-]{36}' | head -n 1)
            if [ -n "$api_key" ]; then
                echo -e "Shlink API Key：${GREEN}${api_key}${NC}"
            else
                echo -e "Shlink API Key：${RED}获取失败，请运行 docker exec shlink shlink api-key:list${NC}"
            fi
        fi
    else
        echo -e "\n${YELLOW}--- Shlink 未安装 ---${NC}"
    fi
}

# --- 功能函数 ---

install_shlink() {
    get_config

    echo -e "\n${YELLOW}--- 部署配置确认 ---${NC}"
    echo -e "公网IP/域名: ${GREEN}${DEFAULT_DOMAIN}${NC}"
    echo -e "后端端口: ${GREEN}${BACKEND_PORT}${NC}"
    echo -e "前端端口: ${GREEN}${FRONTEND_PORT}${NC}"
    read -p "请确认配置无误后按任意键继续... (Ctrl+C 取消)"

    echo -e "\n${GREEN}--- 正在部署 Shlink 后端 (Server)... ---${NC}"
    docker run --name shlink -d --restart=always \
      -p ${BACKEND_PORT}:8080 \
      -e DEFAULT_DOMAIN="${DEFAULT_DOMAIN}" \
      -e IS_HTTPS_ENABLED=false \
      -e GEOLITE_LICENSE_KEY="${GEOLITE_LICENSE_KEY}" \
      shlinkio/shlink:latest

    if [ $? -ne 0 ]; then
        echo -e "${RED}Shlink 后端部署失败。${NC}"
        exit 1
    fi
    echo -e "${GREEN}Shlink 后端部署成功！${NC}"

    echo -e "\n${YELLOW}正在运行数据库迁移...${NC}"
    sleep 5
    docker exec shlink shlink db:migrate --no-interaction

    echo -e "\n${YELLOW}正在生成 API Key...${NC}"
    API_KEY=$(docker exec shlink shlink api-key:generate | grep -oP '(?<=Generated API key: ).*')

    echo -e "\n${GREEN}--- 正在部署 Shlink 前端 (Web-Client)... ---${NC}"
    docker run -d --name shlink-web-client --restart=always -p ${FRONTEND_PORT}:8080 \
      -e SHLINK_API_URL="http://${DEFAULT_DOMAIN}:${BACKEND_PORT}" \
      -e SHLINK_API_KEY="${API_KEY}" \
      shlinkio/shlink-web-client

    echo -e "\n${GREEN}--- 部署完成！ ---${NC}"

    save_config
    display_status
}

uninstall_shlink() {
    echo -e "${RED}--- 警告：这将永久删除 Shlink 相关的所有 Docker 容器和数据。 ---${NC}"
    read -p "你确定要卸载 Shlink 吗？(y/n): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}取消卸载。${NC}"
        return
    fi
    uninstall_shlink_core
    rm -f "$CONFIG_FILE"
    echo -e "${GREEN}Shlink 已成功卸载。${NC}"
}

update_shlink() {
    echo -e "${YELLOW}--- 正在更新 Shlink... ---${NC}"
    uninstall_shlink_core
    docker pull shlinkio/shlink:latest
    docker pull shlinkio/shlink-web-client:latest
    install_shlink
    echo -e "${GREEN}--- Shlink 更新完成！ ---${NC}"
}

# --- 主菜单 ---

main_menu() {
    load_config
    display_status

    while true; do
        echo -e "\n${YELLOW}--- Shlink 管理脚本 ---${NC}"
        echo -e "1. ${GREEN}安装 Shlink${NC}"
        echo -e "2. ${YELLOW}更新 Shlink${NC}"
        echo -e "3. ${RED}卸载 Shlink${NC}"
        echo -e "4. ${NC}退出"
        read -p "请选择一个操作 (1-4): " choice

        case "$choice" in
            1)
                check_docker
                if check_and_uninstall; then
                    install_shlink
                fi
                read -p "按任意键返回主菜单..."
                clear
                display_status
                ;;
            2)
                check_docker
                update_shlink
                read -p "按任意键返回主菜单..."
                clear
                display_status
                ;;
            3)
                uninstall_shlink
                read -p "按任意键返回主菜单..."
                clear
                display_status
                ;;
            4)
                echo -e "${GREEN}再见！${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}无效选项，请重新选择。${NC}"
                read -p "按任意键继续..."
                clear
                display_status
                ;;
        esac
    done
}

main_menu
