#!/bin/bash
set -e

WORKDIR="/opt/shlink"
COMPOSE_FILE="$WORKDIR/docker-compose.yml"
ENV_FILE="$WORKDIR/.env"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 检查Docker是否安装
check_docker() {
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}错误: Docker未安装。请先安装Docker。${NC}"
        exit 1
    fi
}

# 检查Docker Compose是否可用
check_compose() {
    if ! docker compose version &> /dev/null && ! command -v docker-compose &> /dev/null; then
        echo -e "${RED}错误: Docker Compose未安装。请先安装Docker Compose。${NC}"
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

# 清理冲突容器
cleanup_containers() {
    echo -e "${YELLOW}清理可能冲突的容器...${NC}"
    docker rm -f shlink_web_client shlink shlink_db 2>/dev/null || true
    # 清理可能存在的旧网络
    docker network rm shlink_net 2>/dev/null || true
    sleep 2
}

# 检查端口占用
check_ports() {
    local api_port=$1
    local client_port=$2
    
    echo -e "${YELLOW}检查端口占用情况...${NC}"
    
    if lsof -i :$api_port &>/dev/null; then
        echo -e "${RED}错误: 端口 $api_port 已被占用，请释放该端口或选择其他端口${NC}"
        return 1
    fi
    
    if lsof -i :$client_port &>/dev/null; then
        echo -e "${RED}错误: 端口 $client_port 已被占用，请释放该端口或选择其他端口${NC}"
        return 1
    fi
    
    echo -e "${GREEN}端口检查通过${NC}"
    return 0
}

# 获取本机IP地址
get_ip() {
    local ipv4=$(curl -s4 https://ipinfo.io/ip 2>/dev/null || echo "无法获取IPv4")
    local ipv6=$(ip -6 addr show scope global 2>/dev/null | grep inet6 | awk '{print $2}' | cut -d/ -f1 | head -n1 || echo "无法获取IPv6")
    echo "$ipv4" "$ipv6"
}

# 等待服务就绪并获取API Key
wait_for_service_and_get_key() {
    local max_attempts=30
    local attempt=1
    
    echo -e "${YELLOW}等待 Shlink 服务就绪...${NC}"
    
    while [ $attempt -le $max_attempts ]; do
        if docker compose exec shlink curl -f http://localhost:8080/health &>/dev/null; then
            echo -e "${GREEN}Shlink 服务已就绪${NC}"
            return 0
        fi
        
        echo "等待服务启动... ($attempt/$max_attempts)"
        sleep 2
        ((attempt++))
    done
    
    echo -e "${RED}Shlink 服务启动超时${NC}"
    return 1
}

# 手动生成API Key
generate_api_key_manually() {
    echo -e "${YELLOW}尝试手动生成 API Key...${NC}"
    
    # 多次尝试生成API Key
    for i in {1..5}; do
        echo "尝试生成 API Key (第 $i 次)..."
        
        # 使用更稳定的方式生成API Key
        API_KEY=$(docker compose exec -T shlink shlink api-key:generate --expiration="never" 2>/dev/null | grep -oE '[0-9a-f-]{36}' | head -n1)
        
        if [ -n "$API_KEY" ]; then
            echo -e "${GREEN}API Key 生成成功: $API_KEY${NC}"
            
            # 更新环境变量文件
            if grep -q "API_KEY=" "$ENV_FILE"; then
                sed -i "s/API_KEY=.*/API_KEY=$API_KEY/" "$ENV_FILE"
            else
                echo "API_KEY=$API_KEY" >> "$ENV_FILE"
            fi
            
            # 重启Web Client以应用新的API Key
            docker compose up -d shlink_web_client
            
            return 0
        fi
        
        sleep 3
    done
    
    echo -e "${RED}无法生成 API Key，请检查容器日志${NC}"
    docker compose logs shlink
    return 1
}

# 检查Web Client状态
check_web_client() {
    echo -e "${YELLOW}检查 Web Client 状态...${NC}"
    
    local max_attempts=10
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if docker compose ps | grep shlink_web_client | grep -q "healthy\|running"; then
            echo -e "${GREEN}Web Client 运行正常${NC}"
            return 0
        fi
        
        echo "等待 Web Client 启动... ($attempt/$max_attempts)"
        sleep 2
        ((attempt++))
    done
    
    echo -e "${RED}Web Client 启动异常${NC}"
    docker compose logs shlink_web_client
    return 1
}

show_menu() {
    clear
    echo -e "${BLUE}============================${NC}"
    echo -e "${BLUE} Shlink 短链服务管理脚本${NC}"
    echo -e "${BLUE}============================${NC}"
    echo -e "1) 安装 Shlink 服务"
    echo -e "2) 卸载 Shlink 服务"
    echo -e "3) 更新 Shlink 服务"
    echo -e "4) 查看服务信息"
    echo -e "5) 重启服务"
    echo -e "6) 修复服务问题"
    echo -e "0) 退出"
    echo -e "${BLUE}----------------------------${NC}"
    read -p "请输入选项: " choice

    case "$choice" in
        1) install_shlink ;;
        2) uninstall_shlink ;;
        3) update_shlink ;;
        4) info_shlink ;;
        5) restart_shlink ;;
        6) fix_issues ;;
        0) exit 0 ;;
        *) echo -e "${RED}无效选项，请重新输入${NC}" && sleep 2 && show_menu ;;
    esac
}

install_shlink() {
    echo -e "${GREEN}--- 开始部署 Shlink 短链服务 ---${NC}"
    
    # 检查依赖
    check_docker
    check_compose
    
    # 创建工作目录
    mkdir -p "$WORKDIR"
    cd "$WORKDIR"

    # 清理可能冲突的容器
    cleanup_containers

    # 获取用户输入
    echo "请输入配置信息:"
    read -p "请输入短网址服务 API 域名 (例如: api.q.qqy.pp.ua): " API_DOMAIN
    read -p "请输入 Web Client 域名 (例如: q.qqy.pp.ua): " CLIENT_DOMAIN
    
    # 使用您指定的端口
    API_PORT=9040
    CLIENT_PORT=9050
    
    # 检查端口占用
    if ! check_ports $API_PORT $CLIENT_PORT; then
        read -p "按回车键返回菜单..."
        show_menu
        return
    fi
    
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

    # 生成 docker-compose.yml (修复版本)
    cat > "$COMPOSE_FILE" <<EOF
version: "3.8"
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
      - "0.0.0.0:\$API_PORT:8080"
    networks:
      - shlink_net
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: 40s

  shlink_web_client:
    image: shlinkio/shlink-web-client:stable
    container_name: shlink_web_client
    restart: unless-stopped
    depends_on:
      - shlink
    environment:
      SHLINK_SERVER_URL: http://shlink:8080
      SHLINK_SERVER_API_KEY: \${API_KEY:-}
    ports:
      - "0.0.0.0:\$CLIENT_PORT:80"
    networks:
      - shlink_net
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:80"]
      interval: 30s
      timeout: 10s
      retries: 3

networks:
  shlink_net:
    driver: bridge

volumes:
  db_data:
    driver: local
EOF

    echo -e "${YELLOW}--- 启动 Shlink 服务 ---${NC}"
    $(compose_cmd) up -d

    # 等待服务就绪
    if ! wait_for_service_and_get_key; then
        echo -e "${RED}服务启动失败，尝试修复...${NC}"
        fix_issues
        return
    fi

    # 生成API Key
    if ! generate_api_key_manually; then
        echo -e "${RED}API Key 生成失败${NC}"
        read -p "按回车键返回菜单..."
        show_menu
        return
    fi

    # 检查Web Client状态
    check_web_client

    # 获取IP地址
    read ipv4 ipv6 <<< $(get_ip)

    echo -e "${GREEN}============================${NC}"
    echo -e "${GREEN} Shlink 部署完成！${NC}"
    echo -e "${GREEN}API Key: $API_KEY${NC}"
    echo ""
    echo -e "${BLUE}访问方式：${NC}"
    echo -e "本机访问:"
    echo -e "  - API: http://localhost:$API_PORT"
    echo -e "  - Web: http://localhost:$CLIENT_PORT"
    echo -e "域名访问:"
    echo -e "  - API: http://$API_DOMAIN:$API_PORT"
    echo -e "  - Web: http://$CLIENT_DOMAIN:$CLIENT_PORT"
    
    if [ "$ipv4" != "无法获取IPv4" ]; then
        echo -e "IPv4访问:"
        echo -e "  - API: http://$ipv4:$API_PORT"
        echo -e "  - Web: http://$ipv4:$CLIENT_PORT"
    fi
    
    if [ "$ipv6" != "无法获取IPv6" ]; then
        echo -e "IPv6访问:"
        echo -e "  - API: http://[$ipv6]:$API_PORT"
        echo -e "  - Web: http://[$ipv6]:$CLIENT_PORT"
    fi
    
    echo ""
    echo -e "${YELLOW}重要提示:${NC}"
    echo -e "1. 请确保域名解析正确"
    echo -e "2. 如果遇到502错误，请尝试选项6修复服务"
    echo -e "${GREEN}============================${NC}"

    read -p "按回车键返回菜单..."
    show_menu
}

fix_issues() {
    echo -e "${YELLOW}--- 修复 Shlink 服务问题 ---${NC}"
    
    if [ ! -f "$COMPOSE_FILE" ]; then
        echo -e "${YELLOW}未找到Shlink安装。${NC}"
        read -p "按回车键返回菜单..."
        show_menu
        return
    fi
    
    cd "$WORKDIR"
    
    echo -e "${YELLOW}停止服务...${NC}"
    $(compose_cmd) down
    
    echo -e "${YELLOW}清理临时文件...${NC}"
    docker system prune -f
    
    echo -e "${YELLOW}重新启动服务...${NC}"
    $(compose_cmd) up -d
    
    echo -e "${YELLOW}等待服务就绪...${NC}"
    sleep 10
    
    # 重新生成API Key
    if generate_api_key_manually; then
        echo -e "${GREEN}修复完成！${NC}"
    else
        echo -e "${RED}修复失败，请查看日志获取详细信息${NC}"
    fi
    
    read -p "按回车键返回菜单..."
    show_menu
}

uninstall_shlink() {
    echo -e "${RED}--- 卸载 Shlink 服务 ---${NC}"
    
    if [ ! -f "$COMPOSE_FILE" ]; then
        echo -e "${YELLOW}未找到Shlink安装。${NC}"
        read -p "按回车键返回菜单..."
        show_menu
        return
    fi
    
    cd "$WORKDIR"
    
    read -p "确定要卸载Shlink吗？这将删除所有数据！(y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}卸载已取消。${NC}"
        sleep 2
        show_menu
        return
    fi
    
    $(compose_cmd) down -v
    cd /opt
    rm -rf "$WORKDIR"
    echo -e "${GREEN}Shlink 已卸载${NC}"
    read -p "按回车键返回菜单..."
    show_menu
}

update_shlink() {
    echo -e "${YELLOW}--- 更新 Shlink 服务 ---${NC}"
    
    if [ ! -f "$COMPOSE_FILE" ]; then
        echo -e "${YELLOW}未找到Shlink安装。${NC}"
        read -p "按回车键返回菜单..."
        show_menu
        return
    fi
    
    cd "$WORKDIR"
    $(compose_cmd) pull
    $(compose_cmd) up -d
    
    # 更新后重新生成API Key
    generate_api_key_manually
    
    echo -e "${GREEN}Shlink 已更新${NC}"
    read -p "按回车键返回菜单..."
    show_menu
}

restart_shlink() {
    echo -e "${YELLOW}--- 重启 Shlink 服务 ---${NC}"
    
    if [ ! -f "$COMPOSE_FILE" ]; then
        echo -e "${YELLOW}未找到Shlink安装。${NC}"
        read -p "按回车键返回菜单..."
        show_menu
        return
    fi
    
    cd "$WORKDIR"
    $(compose_cmd) restart
    echo -e "${GREEN}Shlink 已重启${NC}"
    read -p "按回车键返回菜单..."
    show_menu
}

info_shlink() {
    echo -e "${BLUE}--- Shlink 服务信息 ---${NC}"
    
    if [ ! -f "$COMPOSE_FILE" ]; then
        echo -e "${YELLOW}未找到Shlink安装。${NC}"
        read -p "按回车键返回菜单..."
        show_menu
        return
    fi
    
    cd "$WORKDIR"
    echo -e "${GREEN}容器状态:${NC}"
    $(compose_cmd) ps
    
    echo -e "\n${GREEN}服务配置:${NC}"
    if [ -f "$ENV_FILE" ]; then
        grep -v "DB_PASSWORD\|API_KEY" "$ENV_FILE"
    fi
    
    echo -e "\n${GREEN}网络信息:${NC}"
    docker network inspect shlink_shlink_net --format '{{range .Containers}}{{.Name}} - {{.IPv4Address}}{{"\n"}}{{end}}' 2>/dev/null || echo "网络信息获取失败"
    
    read -p "按回车键返回菜单..."
    show_menu
}

# 主执行流程
main() {
    check_docker
    check_compose
    show_menu
}

# 启动脚本
main "$@"