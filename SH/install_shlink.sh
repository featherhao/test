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

# 日志函数
log() { echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"; }
success() { echo -e "${GREEN}✓${NC} $1"; }
warning() { echo -e "${YELLOW}⚠${NC} $1"; }
error() { echo -e "${RED}✗${NC} $1"; }

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
    local api_port=$1; local client_port=$2
    log "检查端口占用情况..."
    
    if command -v lsof &>/dev/null && (lsof -i :$api_port || lsof -i :$client_port) &>/dev/null; then
        error "端口 $api_port 或 $client_port 已被占用"
        return 1
    fi
    success "端口检查通过"; return 0
}

# 增强的健康检查等待
wait_for_service_enhanced() {
    local service=$1; local max_attempts=${2:-50}
    local attempt=1
    
    log "等待 $service 服务就绪（增强模式）..."
    
    while [ $attempt -le $max_attempts ]; do
        # 多种方式检查服务状态
        if docker compose exec $service curl -f http://localhost:8080/health &>/dev/null; then
            success "$service 服务已就绪"; return 0
        fi
        
        # 检查容器日志中的成功启动信息
        if docker compose logs $service 2>&1 | grep -q "Server started\|RoadRunner server started"; then
            success "$service 服务日志显示已启动"; return 0
        fi
        
        # 检查容器进程
        if docker compose exec $service ps aux | grep -q "rr\|php"; then
            success "$service 服务进程已运行"; return 0
        fi
        
        if [ $attempt -eq $max_attempts ]; then
            error "$service 服务启动超时，尝试修复..."
            return 1
        fi
        
        echo "等待中... ($attempt/$max_attempts)"
        sleep 5
        ((attempt++))
    done
}

# 生成API Key（兼容版本）
generate_api_key() {
    local max_attempts=8; local attempt=1
    
    log "生成 API Key..."
    
    while [ $attempt -le $max_attempts ]; do
        # 尝试多种日期格式
        API_KEY=$(docker compose exec -T shlink shlink api-key:generate --expiration-date="2030-01-01" 2>/dev/null | grep -oE '[0-9a-f-]{36}' | head -n1)
        
        if [ -n "$API_KEY" ]; then
            success "API Key 生成成功: $API_KEY"
            echo "API_KEY=$API_KEY" >> $ENV_FILE
            return 0
        fi
        
        # 尝试不带过期日期
        API_KEY=$(docker compose exec -T shlink shlink api-key:generate 2>/dev/null | grep -oE '[0-9a-f-]{36}' | head -n1)
        if [ -n "$API_KEY" ]; then
            success "API Key 生成成功: $API_KEY"
            echo "API_KEY=$API_KEY" >> $ENV_FILE
            return 0
        fi
        
        warning "API Key 生成尝试 $attempt 失败，重试..."
        sleep 4
        ((attempt++))
    done
    
    error "无法生成 API Key，尝试手动方法..."
    return 1
}

# 优化docker-compose配置
optimize_compose_config() {
    log "优化Docker Compose配置..."
    
    # 移除version行避免警告
    sed -i '/^version:/d' $COMPOSE_FILE 2>/dev/null || true
    
    # 增强健康检查配置
    if ! grep -q "start_period: 120s" $COMPOSE_FILE; then
        sed -i 's/start_period: [0-9]\+s/start_period: 120s/' $COMPOSE_FILE
        sed -i 's/retries: [0-9]\+/retries: 10/' $COMPOSE_FILE
        sed -i 's/timeout: [0-9]\+s/timeout: 30s/' $COMPOSE_FILE
    fi
    
    # 添加资源限制（如果服务器资源紧张）
    if ! grep -q "resources:" $COMPOSE_FILE; then
        sed -i '/shlink:/a\    deploy:\n      resources:\n        limits:\n          memory: 512M\n        reservations:\n          memory: 256M' $COMPOSE_FILE
    fi
    
    # 添加调试环境变量
    if ! grep -q "SHELL_VERBOSITY" $COMPOSE_FILE; then
        sed -i '/DB_PORT: 5432/a\      SHELL_VERBOSITY: 3' $COMPOSE_FILE
    fi
}

# 诊断服务问题
diagnose_service() {
    log "诊断服务问题..."
    
    echo -e "\n${YELLOW}=== 容器状态 ===${NC}"
    docker compose ps -a
    
    echo -e "\n${YELLOW}=== Shlink 日志（最后20行）===${NC}"
    docker compose logs shlink --tail=20
    
    echo -e "\n${YELLOW}=== 数据库日志（最后10行）===${NC}"
    docker compose logs shlink_db --tail=10
    
    echo -e "\n${YELLOW}=== 网络检查 ===${NC}"
    docker network inspect shlink_shlink_net --format '{{range .Containers}}{{.Name}} - {{.IPv4Address}}{{"\n"}}{{end}}' 2>/dev/null || echo "网络检查失败"
    
    echo -e "\n${YELLOW}=== 资源使用 ===${NC}"
    free -h | head -2
    df -h /opt
}

# 安装Shlink
install_shlink() {
    log "开始安装 Shlink..."
    check_dependencies
    mkdir -p $WORKDIR; cd $WORKDIR
    cleanup_containers

    # 获取配置
    echo "请输入 Shlink 配置信息:"
    read -p "API 域名 (例如: api.example.com): " API_DOMAIN
    read -p "Web Client 域名 (例如: short.example.com): " CLIENT_DOMAIN
    
    API_PORT=9040; CLIENT_PORT=9050
    check_ports $API_PORT $CLIENT_PORT || exit 1
    
    read -p "数据库密码 [默认: 随机生成]: " DB_PASSWORD
    DB_PASSWORD=${DB_PASSWORD:-$(tr -dc A-Za-z0-9 </dev/urandom | head -c 16)}
    read -p "GeoLite2 License Key (可选): " GEO_KEY

    # 创建环境文件
    cat > $ENV_FILE <<EOF
API_DOMAIN=$API_DOMAIN
CLIENT_DOMAIN=$CLIENT_DOMAIN
API_PORT=$API_PORT
CLIENT_PORT=$CLIENT_PORT
DB_PASSWORD=$DB_PASSWORD
GEO_KEY=$GEO_KEY
EOF

    # 创建docker-compose.yml
    cat > $COMPOSE_FILE <<EOF
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
      SHELL_VERBOSITY: 3
    ports:
      - "0.0.0.0:\$API_PORT:8080"
    networks:
      - shlink_net
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 30s
      timeout: 30s
      retries: 10
      start_period: 120s
    deploy:
      resources:
        limits:
          memory: 512M
        reservations:
          memory: 256M

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

    log "启动 Shlink 服务..."
    docker compose up -d
    
    # 使用增强的等待函数
    if wait_for_service_enhanced shlink 50; then
        if generate_api_key; then
            docker compose up -d shlink_web_client
            show_success_message
        else
            error "API Key生成失败，尝试手动生成..."
            try_manual_api_key_generation
        fi
    else
        error "服务启动超时，进行诊断..."
        diagnose_service
        try_manual_recovery
    fi
}

# 显示成功信息
show_success_message() {
    success "Shlink 安装完成!"
    echo -e "\n${GREEN}====================== 安装信息 ======================${NC}"
    echo "API 地址: http://$(grep 'API_DOMAIN' $ENV_FILE | cut -d= -f2):9040"
    echo "Web 界面: http://$(grep 'CLIENT_DOMAIN' $ENV_FILE | cut -d= -f2):9050"
    echo "API Key: $(grep 'API_KEY' $ENV_FILE | cut -d= -f2)"
    echo "数据库密码: $(grep 'DB_PASSWORD' $ENV_FILE | cut -d= -f2)"
    echo -e "${GREEN}======================================================${NC}"
}

# 手动恢复尝试
try_manual_recovery() {
    warning "尝试手动恢复..."
    docker compose restart shlink
    sleep 30
    
    if docker compose exec shlink curl -f http://localhost:8080/health; then
        success "手动恢复成功"
        generate_api_key
    else
        error "手动恢复失败，请检查日志"
        docker compose logs shlink
    fi
}

# 手动API Key生成
try_manual_api_key_generation() {
    warning "尝试手动生成API Key..."
    docker compose exec shlink shlink api-key:generate --expiration-date="2030-01-01"
    read -p "请输入上面显示的API Key: " MANUAL_API_KEY
    echo "API_KEY=$MANUAL_API_KEY" >> $ENV_FILE
    docker compose up -d shlink_web_client
    show_success_message
}

# 主菜单
show_menu() {
    echo -e "${BLUE}=================================${NC}"
    echo -e "${BLUE}    Shlink 一键安装管理脚本     ${NC}"
    echo -e "${BLUE}=================================${NC}"
    echo "1) 安装 Shlink"
    echo "2) 修复安装"
    echo "3) 诊断服务"
    echo "4) 查看状态"
    echo "5) 重启服务"
    echo "6) 卸载 Shlink"
    echo "0) 退出"
    echo -e "${BLUE}=================================${NC}"
    read -p "请选择操作 [0-6]: " choice

    case $choice in
        1) install_shlink ;;
        2) docker compose down && docker compose up -d ;;
        3) diagnose_service ;;
        4) docker compose ps ;;
        5) docker compose restart ;;
        6) docker compose down -v && rm -rf $WORKDIR ;;
        0) exit 0 ;;
        *) echo "无效选择" ;;
    esac
}

# 主函数
main() {
    if [ -f $COMPOSE_FILE ]; then
        cd $WORKDIR
        show_menu
    else
        install_shlink
    fi
}

main "$@"