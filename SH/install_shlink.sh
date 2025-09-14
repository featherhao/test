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
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 日志函数
log() { echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"; }
success() { echo -e "${GREEN}✓${NC} $1"; }
warning() { echo -e "${YELLOW}⚠${NC} $1"; }
error() { echo -e "${RED}✗${NC} $1"; }
info() { echo -e "${CYAN}ℹ${NC} $1"; }

# 检查依赖
check_dependencies() {
    log "检查系统依赖..."
    if ! command -v docker &>/dev/null; then
        error "Docker 未安装，尝试自动安装..."
        curl -fsSL https://get.docker.com | bash
        systemctl start docker
        systemctl enable docker
    fi
    
    if ! docker compose version &>/dev/null && ! command -v docker-compose &>/dev/null; then
        error "Docker Compose 未安装，尝试自动安装..."
        COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep '"tag_name":' | cut -d'"' -f4)
        curl -L "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose
    fi
    success "依赖检查完成"
}

# 清理容器
cleanup_containers() {
    log "清理可能冲突的容器..."
    docker rm -f shlink_web_client shlink shlink_db 2>/dev/null || true
    docker network rm shlink_net 2>/dev/null || true
    sleep 2
}

# 检查端口占用
check_ports() {
    local api_port=9040
    local client_port=9050
    
    log "检查端口占用情况..."
    
    if command -v ss &>/dev/null && (ss -tln | grep -q ":${api_port}\|:${client_port}"); then
        error "端口 ${api_port} 或 ${client_port} 已被占用"
        return 1
    fi
    
    if command -v netstat &>/dev/null && (netstat -tln | grep -q ":${api_port}\|:${client_port}"); then
        error "端口 ${api_port} 或 ${client_port} 已被占用"
        return 1
    fi
    
    success "端口检查通过"
    return 0
}

# 获取IP地址
get_ip_addresses() {
    log "获取服务器IP地址..."
    IPV4=$(curl -s4 https://ipinfo.io/ip 2>/dev/null || echo "无法获取IPv4")
    IPV6=$(curl -s6 https://ipinfo.io/ip 2>/dev/null || echo "无法获取IPv6")
    
    if [ "$IPV4" = "无法获取IPv4" ] && [ "$IPV6" = "无法获取IPv6" ]; then
        IPV4=$(hostname -I | awk '{print $1}' | head -n1)
        IPV6=$(ip -6 addr show scope global 2>/dev/null | grep inet6 | awk '{print $2}' | cut -d/ -f1 | head -n1 || echo "无法获取IPv6")
    fi
}

# 生成API Key
generate_api_key() {
    local max_attempts=10
    local attempt=1
    
    log "生成 API Key..."
    
    while [ $attempt -le $max_attempts ]; do
        API_KEY=$(docker compose exec -T shlink shlink api-key:generate --expiration-date="2030-01-01" 2>/dev/null | grep -oE '[0-9a-f-]{36}' | head -n1)
        
        if [ -n "$API_KEY" ]; then
            success "API Key 生成成功: $API_KEY"
            echo "API_KEY=$API_KEY" >> "$ENV_FILE"
            return 0
        fi
        
        warning "API Key 生成尝试 $attempt 失败，重试..."
        sleep 3
        ((attempt++))
    done
    
    error "无法生成 API Key"
    return 1
}

# 显示访问信息
show_access_info() {
    source "$ENV_FILE" 2>/dev/null
    
    echo -e "${GREEN}"
    echo "================================================================"
    echo "                   Shlink 安装完成！                            "
    echo "================================================================"
    echo -e "${NC}"
    
    echo -e "${CYAN}🌐 Web 客户端访问方式:${NC}"
    echo -e "域名访问: ${GREEN}https://${CLIENT_DOMAIN}${NC}"
    echo -e "IPv4访问: ${GREEN}http://${IPV4}:9050${NC}"
    if [ "$IPV6" != "无法获取IPv6" ]; then
        echo -e "IPv6访问: ${GREEN}http://[${IPV6}]:9050${NC}"
    fi
    
    echo -e "${CYAN}📊 API 服务访问方式:${NC}"
    echo -e "域名访问: ${GREEN}https://${API_DOMAIN}${NC}"
    echo -e "IPv4访问: ${GREEN}http://${IPV4}:9040${NC}"
    if [ "$IPV6" != "无法获取IPv6" ]; then
        echo -e "IPv6访问: ${GREEN}http://[${IPV6}]:9040${NC}"
    fi
    echo -e "健康检查: ${GREEN}http://${IPV4}:9040/rest/health${NC}"
    
    echo -e "${CYAN}🔑 API 密钥:${NC} ${GREEN}${API_KEY}${NC}"
    echo -e "${CYAN}🗄️ 数据库密码:${NC} ${GREEN}${DB_PASSWORD}${NC}"
    
    echo -e "${CYAN}📝 重要提示:${NC}"
    echo -e "1. 请确保域名正确解析到服务器IP: ${IPV4}"
    echo -e "2. 配置反向代理（Nginx/Apache）将域名指向对应端口"
    echo -e "3. 防火墙需要开放端口 9040 和 9050（仅IP访问需要）"
    echo -e "4. API Key 请妥善保管"
    
    echo -e "${GREEN}================================================================"
    echo -e "${NC}"
}

# 等待服务就绪
wait_for_service() {
    local service=$1
    local max_attempts=50
    local attempt=1
    
    log "等待 $service 服务就绪..."
    
    while [ $attempt -le $max_attempts ]; do
        if [ "$service" = "shlink_db" ]; then
            if docker compose exec $service pg_isready -U shlink -d shlink &>/dev/null; then
                success "$service 服务已就绪"
                return 0
            fi
        else
            if docker compose exec $service curl -f http://localhost:8080/rest/health &>/dev/null; then
                success "$service 服务已就绪"
                return 0
            fi
            
            if docker compose logs $service 2>&1 | grep -q "Server started\|RoadRunner"; then
                success "$service 服务日志显示已启动"
                return 0
            fi
        fi
        
        if [ $((attempt % 10)) -eq 0 ]; then
            echo "等待中... ($attempt/$max_attempts)"
        fi
        
        if [ $attempt -eq $max_attempts ]; then
            error "$service 服务启动超时"
            return 1
        fi
        
        sleep 5
        ((attempt++))
    done
}

# 创建docker-compose配置
create_docker_compose_config() {
    cat > "$COMPOSE_FILE" <<'EOF'
services:
  shlink_db:
    image: postgres:15-alpine
    container_name: shlink_db
    restart: unless-stopped
    environment:
      POSTGRES_USER: shlink
      POSTGRES_PASSWORD: ${DB_PASSWORD}
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
    environment:
      DEFAULT_DOMAIN: ${API_DOMAIN}
      IS_HTTPS_ENABLED: "false"
      GEOLITE_LICENSE_KEY: ${GEO_KEY}
      DB_DRIVER: postgres
      DB_USER: shlink
      DB_PASSWORD: ${DB_PASSWORD}
      DB_HOST: shlink_db
      DB_NAME: shlink
      DB_PORT: 5432
      SHELL_VERBOSITY: 3
    ports:
      - "0.0.0.0:9040:8080"
    networks:
      - shlink_net
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/rest/health"]
      interval: 30s
      timeout: 20s
      retries: 10
      start_period: 120s

  shlink_web_client:
    image: shlinkio/shlink-web-client:stable
    container_name: shlink_web_client
    restart: unless-stopped
    depends_on:
      - shlink
    environment:
      SHLINK_SERVER_URL: http://shlink:8080
      SHLINK_SERVER_API_KEY: ${API_KEY}
    ports:
      - "0.0.0.0:9050:8080"
    networks:
      - shlink_net
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080"]
      interval: 30s
      timeout: 10s
      retries: 5

networks:
  shlink_net:
    driver: bridge

volumes:
  db_data:
    driver: local
EOF
}

# 查看服务状态
show_status() {
    echo -e "${CYAN}=== 服务状态 ===${NC}"
    docker compose ps
    
    echo -e "\n${CYAN}=== 资源使用情况 ===${NC}"
    docker stats --no-stream
    
    echo -e "\n${CYAN}=== 最近日志 ===${NC}"
    docker compose logs --tail=10
}

# 监控服务日志
monitor_logs() {
    echo -e "${CYAN}=== 开始监控日志（Ctrl+C 退出）===${NC}"
    docker compose logs -f
}

# 查看服务信息
show_service_info() {
    source "$ENV_FILE" 2>/dev/null
    echo -e "${CYAN}=== 服务配置信息 ===${NC}"
    echo -e "Web 域名: ${GREEN}https://${CLIENT_DOMAIN}${NC}"
    echo -e "API 域名: ${GREEN}https://${API_DOMAIN}${NC}"
    echo -e "服务器IP: ${GREEN}${IPV4}${NC}"
    echo -e "API 端口: ${GREEN}9040${NC}"
    echo -e "Web 端口: ${GREEN}9050${NC}"
    echo -e "API Key: ${GREEN}${API_KEY}${NC}"
}

# 主安装函数
install_shlink() {
    log "开始安装 Shlink..."
    
    check_dependencies
    mkdir -p "$WORKDIR"
    cd "$WORKDIR"
    
    cleanup_containers
    check_ports || exit 1
    
    # 获取用户配置
    echo "请输入 Shlink 配置信息:"
    read -p "API 域名 (例如: api.example.com): " API_DOMAIN
    read -p "Web Client 域名 (例如: short.example.com): " CLIENT_DOMAIN
    
    read -p "数据库密码 [默认: 随机生成]: " DB_PASSWORD
    DB_PASSWORD=${DB_PASSWORD:-$(tr -dc A-Za-z0-9 </dev/urandom | head -c 16)}
    read -p "GeoLite2 License Key (可选): " GEO_KEY

    # 创建环境文件
    cat > "$ENV_FILE" <<EOF
API_DOMAIN=$API_DOMAIN
CLIENT_DOMAIN=$CLIENT_DOMAIN
DB_PASSWORD=$DB_PASSWORD
GEO_KEY=$GEO_KEY
EOF

    get_ip_addresses
    
    create_docker_compose_config
    
    log "启动 Shlink 服务..."
    docker compose up -d
    
    wait_for_service "shlink_db"
    wait_for_service "shlink"
    
    if generate_api_key; then
        # 更新环境变量并重启web client
        docker compose up -d shlink_web_client
        wait_for_service "shlink_web_client"
        
        success "Shlink 安装成功完成！"
        show_access_info
        
        # 显示最终状态但不监控日志
        echo ""
        log "最终服务状态:"
        docker compose ps
        
        echo -e "\n${GREEN}安装完成！您可以通过菜单查看状态和日志。${NC}"
    else
        error "安装失败，请检查日志"
        docker compose logs shlink
        exit 1
    fi
}

# 显示主菜单
show_main_menu() {
    echo -e "${BLUE}=================================${NC}"
    echo -e "${BLUE}        Shlink 管理菜单          ${NC}"
    echo -e "${BLUE}=================================${NC}"
    echo "1) 安装 Shlink"
    echo "2) 查看服务状态"
    echo "3) 监控实时日志"
    echo "4) 查看服务信息"
    echo "5) 重启服务"
    echo "6) 停止服务"
    echo "7) 完全卸载"
    echo "0) 退出"
    echo -e "${BLUE}=================================${NC}"
}

# 处理菜单选择
handle_menu_choice() {
    local choice=$1
    
    case $choice in
        1) 
            install_shlink
            read -p "按回车键返回菜单..."
            ;;
        2) 
            cd "$WORKDIR" 2>/dev/null && show_status || error "未找到Shlink安装"
            read -p "按回车键返回菜单..."
            ;;
        3) 
            cd "$WORKDIR" 2>/dev/null && monitor_logs || error "未找到Shlink安装"
            ;;
        4) 
            cd "$WORKDIR" 2>/dev/null && show_service_info || error "未找到Shlink安装"
            read -p "按回车键返回菜单..."
            ;;
        5) 
            cd "$WORKDIR" 2>/dev/null && docker compose restart && success "服务已重启" || error "未找到Shlink安装"
            read -p "按回车键返回菜单..."
            ;;
        6) 
            cd "$WORKDIR" 2>/dev/null && docker compose stop && success "服务已停止" || error "未找到Shlink安装"
            read -p "按回车键返回菜单..."
            ;;
        7) 
            cd "$WORKDIR" 2>/dev/null && {
                read -p "确定要完全卸载Shlink吗？(y/N): " confirm
                if [[ $confirm == "y" || $confirm == "Y" ]]; then
                    docker compose down -v
                    rm -rf "$WORKDIR"
                    success "Shlink 已完全卸载"
                else
                    info "卸载已取消"
                fi
            } || error "未找到Shlink安装"
            read -p "按回车键返回菜单..."
            ;;
        0) 
            exit 0
            ;;
        *) 
            error "无效选择"
            sleep 1
            ;;
    esac
}

# 主函数
main() {
    # 检查是否已安装
    if [ -f "$COMPOSE_FILE" ]; then
        cd "$WORKDIR"
        while true; do
            clear
            show_main_menu
            read -p "请选择操作 [0-7]: " choice
            handle_menu_choice "$choice"
        done
    else
        install_shlink
    fi
}

# 启动脚本
main "$@"