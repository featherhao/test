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
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}✓${NC} $1"
}

warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

error() {
    echo -e "${RED}✗${NC} $1"
}

# 检查依赖
check_dependencies() {
    log "检查系统依赖..."
    local missing=0
    
    if ! command -v docker &> /dev/null; then
        error "Docker 未安装"
        missing=1
    fi
    
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        error "Docker Compose 未安装"
        missing=1
    fi
    
    if [ $missing -eq 1 ]; then
        log "尝试安装 Docker 和 Docker Compose..."
        # 尝试使用国内源安装 Docker
        curl -fsSL https://get.docker.com | bash -s docker --mirror Aliyun
        
        # 安装 Docker Compose
        COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep '"tag_name":' | cut -d'"' -f4)
        curl -L "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose
    fi
    
    success "依赖检查完成"
}

# 清理旧容器
cleanup_containers() {
    log "清理可能冲突的容器..."
    docker rm -f shlink_web_client shlink shlink_db 2>/dev/null || true
    docker network rm shlink_net 2>/dev/null || true
    sleep 2
}

# 检查端口占用
check_ports() {
    local api_port=$1
    local client_port=$2
    
    log "检查端口占用情况..."
    
    if lsof -i :$api_port &>/dev/null; then
        error "端口 $api_port 已被占用"
        return 1
    fi
    
    if lsof -i :$client_port &>/dev/null; then
        error "端口 $client_port 已被占用"
        return 1
    fi
    
    success "端口检查通过"
    return 0
}

# 等待服务就绪
wait_for_service() {
    local service=$1
    local max_attempts=${2:-30}
    local attempt=1
    
    log "等待 $service 服务就绪..."
    
    while [ $attempt -le $max_attempts ]; do
        if docker compose logs $service 2>&1 | grep -q "Server started"; then
            success "$service 服务已就绪"
            return 0
        fi
        
        if [ $attempt -eq $max_attempts ]; then
            error "$service 服务启动超时"
            return 1
        fi
        
        echo "等待中... ($attempt/$max_attempts)"
        sleep 5
        ((attempt++))
    done
}

# 生成 API Key
generate_api_key() {
    local max_attempts=5
    local attempt=1
    
    log "生成 API Key..."
    
    while [ $attempt -le $max_attempts ]; do
        # 尝试使用未来日期而不是 "never"
        API_KEY=$(docker compose exec -T shlink shlink api-key:generate --expiration-date="2030-01-01" 2>/dev/null | grep -oE '[0-9a-f-]{36}' | head -n1)
        
        if [ -n "$API_KEY" ]; then
            success "API Key 生成成功: $API_KEY"
            
            # 保存到环境变量文件
            if grep -q "API_KEY=" $ENV_FILE; then
                sed -i "s/API_KEY=.*/API_KEY=$API_KEY/" $ENV_FILE
            else
                echo "API_KEY=$API_KEY" >> $ENV_FILE
            fi
            
            return 0
        fi
        
        warning "API Key 生成尝试 $attempt 失败，重试..."
        sleep 3
        ((attempt++))
    done
    
    error "无法生成 API Key"
    return 1
}

# 安装 Shlink
install_shlink() {
    log "开始安装 Shlink..."
    
    # 检查依赖
    check_dependencies
    
    # 创建目录
    mkdir -p $WORKDIR
    cd $WORKDIR
    
    # 清理旧容器
    cleanup_containers
    
    # 获取用户配置
    echo "请输入 Shlink 配置信息:"
    read -p "API 域名 (例如: api.example.com): " API_DOMAIN
    read -p "Web Client 域名 (例如: short.example.com): " CLIENT_DOMAIN
    
    # 使用非标准端口
    API_PORT=9040
    CLIENT_PORT=9050
    
    # 检查端口
    if ! check_ports $API_PORT $CLIENT_PORT; then
        error "端口被占用，请选择其他端口或释放当前端口"
        exit 1
    fi
    
    read -p "数据库密码 [默认: $(tr -dc A-Za-z0-9 </dev/urandom | head -c 16)]: " DB_PASSWORD
    DB_PASSWORD=${DB_PASSWORD:-$(tr -dc A-Za-z0-9 </dev/urandom | head -c 16)}
    
    read -p "GeoLite2 License Key (可选): " GEO_KEY
    
    # 创建环境变量文件
    cat > $ENV_FILE <<EOF
# Shlink 环境配置
API_DOMAIN=$API_DOMAIN
CLIENT_DOMAIN=$CLIENT_DOMAIN
API_PORT=$API_PORT
CLIENT_PORT=$CLIENT_PORT
DB_PASSWORD=$DB_PASSWORD
GEO_KEY=$GEO_KEY
EOF

    # 创建 docker-compose.yml
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
    ports:
      - "0.0.0.0:\$API_PORT:8080"
    networks:
      - shlink_net
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 30s
      timeout: 15s
      retries: 5
      start_period: 60s

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

    # 启动服务
    log "启动 Shlink 服务..."
    docker compose up -d
    
    # 等待服务就绪
    wait_for_service shlink 40
    
    # 生成 API Key
    if generate_api_key; then
        # 重启 Web Client 以应用 API Key
        docker compose up -d shlink_web_client
        
        # 显示安装结果
        success "Shlink 安装完成!"
        echo ""
        echo "====================== 安装信息 ======================"
        echo "API 地址: http://$API_DOMAIN:$API_PORT"
        echo "Web 界面: http://$CLIENT_DOMAIN:$CLIENT_PORT"
        echo "API Key: $API_KEY"
        echo "数据库密码: $DB_PASSWORD"
        echo "======================================================"
        echo ""
        echo "下一步:"
        echo "1. 确保域名解析正确指向服务器 IP"
        echo "2. 访问 Web 界面开始使用 Shlink"
        echo "3. 妥善保存 API Key 和数据库密码"
    else
        error "安装过程中出现问题"
        echo "请检查日志: docker compose logs shlink"
        exit 1
    fi
}

# 修复安装
fix_installation() {
    log "尝试修复 Shlink 安装..."
    cd $WORKDIR
    
    # 停止服务
    docker compose down
    
    # 清理网络和卷（谨慎操作）
    read -p "是否清理数据卷？这将删除所有数据！(y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        docker volume rm -f shlink_db_data 2>/dev/null || true
    fi
    
    # 重新启动
    docker compose up -d
    
    # 等待并重新生成 API Key
    wait_for_service shlink 40
    generate_api_key
    docker compose up -d shlink_web_client
    
    success "修复完成"
}

# 卸载 Shlink
uninstall_shlink() {
    log "卸载 Shlink..."
    cd $WORKDIR 2>/dev/null || {
        error "Shlink 目录不存在"
        exit 1
    }
    
    read -p "确定要卸载 Shlink 吗？这将删除所有数据！(y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "卸载已取消"
        exit 0
    fi
    
    docker compose down -v
    rm -rf $WORKDIR
    success "Shlink 已卸载"
}

# 显示菜单
show_menu() {
    echo -e "${BLUE}=================================${NC}"
    echo -e "${BLUE}    Shlink 一键安装管理脚本     ${NC}"
    echo -e "${BLUE}=================================${NC}"
    echo "1) 安装 Shlink"
    echo "2) 修复安装"
    echo "3) 卸载 Shlink"
    echo "4) 查看状态"
    echo "5) 重启服务"
    echo "0) 退出"
    echo -e "${BLUE}=================================${NC}"
    read -p "请选择操作 [0-5]: " choice
    
    case $choice in
        1) install_shlink ;;
        2) fix_installation ;;
        3) uninstall_shlink ;;
        4) docker compose ps && docker compose logs --tail=10 ;;
        5) docker compose restart ;;
        0) exit 0 ;;
        *) echo "无效选择" ;;
    esac
}

# 主函数
main() {
    # 检查是否已安装
    if [ -f $COMPOSE_FILE ] && [ $# -eq 0 ]; then
        cd $WORKDIR
        show_menu
    else
        case ${1:-} in
            install) install_shlink ;;
            fix) fix_installation ;;
            uninstall) uninstall_shlink ;;
            status) docker compose ps ;;
            restart) docker compose restart ;;
            *) show_menu ;;
        esac
    fi
}

# 运行主函数
main "$@"