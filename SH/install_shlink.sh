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

# 检查系统资源
check_system_resources() {
    log "检查系统资源..."
    
    # 检查内存
    local free_mem=$(free -m | awk '/Mem:/{print $7}')
    if [ "$free_mem" -lt 512 ]; then
        warning "可用内存较低: ${free_mem}MB (建议至少512MB)"
    fi
    
    # 检查磁盘空间
    local disk_free=$(df -m / | awk 'NR==2{print $4}')
    if [ "$disk_free" -lt 1024 ]; then
        warning "磁盘空间较低: ${disk_free}MB (建议至少1GB)"
    fi
    
    # 检查CPU核心数
    local cpu_cores=$(nproc)
    if [ "$cpu_cores" -lt 2 ]; then
        warning "CPU核心数较少: ${cpu_cores} (建议至少2核心)"
    fi
}

# 增强的服务等待函数
wait_for_service_enhanced() {
    local service=$1
    local max_attempts=60
    local attempt=1
    
    log "等待 $service 服务就绪（增强模式）..."
    
    while [ $attempt -le $max_attempts ]; do
        # 多种方式检查服务状态
        if docker compose exec $service curl -f http://localhost:8080/rest/health &>/dev/null; then
            success "$service 服务已就绪"
            return 0
        fi
        
        # 检查容器日志中的成功启动信息
        if docker compose logs $service 2>&1 | grep -q "Server started\|RoadRunner server started"; then
            success "$service 服务日志显示已启动"
            return 0
        fi
        
        # 检查容器进程
        if docker compose exec $service ps aux | grep -q "rr\|php"; then
            success "$service 服务进程已运行"
            return 0
        fi
        
        # 每10次尝试显示一次进度
        if [ $((attempt % 10)) -eq 0 ]; then
            echo "等待中... ($attempt/$max_attempts)"
            # 同时显示一些诊断信息
            docker compose logs $service --tail=5
        fi
        
        if [ $attempt -eq $max_attempts ]; then
            error "$service 服务启动超时，尝试自动修复..."
            return 1
        fi
        
        sleep 5
        ((attempt++))
    done
}

# 自动修复服务启动问题
auto_fix_service_issues() {
    local service=$1
    
    log "尝试自动修复 $service 服务问题..."
    
    # 1. 首先重启服务
    docker compose restart $service
    sleep 10
    
    # 2. 检查资源使用情况
    local mem_usage=$(docker stats $service --no-stream --format "{{.MemUsage}}" | cut -d'/' -f1 | tr -d '[:alpha:]')
    if [ -n "$mem_usage" ] && [ "$mem_usage" -gt 0 ]; then
        info "$service 内存使用: ${mem_usage}MB"
    fi
    
    # 3. 调整健康检查参数（如果服务是shlink）
    if [ "$service" = "shlink" ]; then
        log "优化健康检查配置..."
        sed -i '/healthcheck:/,/test:/!b; /test:/a\  interval: 45s\n  timeout: 30s\n  retries: 8\n  start_period: 180s' $COMPOSE_FILE
    fi
    
    # 4. 增加资源限制（如果资源紧张）
    if ! grep -q "resources:" $COMPOSE_FILE; then
        log "增加资源限制..."
        sed -i '/shlink:/a\    deploy:\n      resources:\n        limits:\n          memory: 768M\n          cpus: "1.0"\n        reservations:\n          memory: 256M' $COMPOSE_FILE
    fi
    
    # 5. 重新部署
    docker compose up -d $service
    sleep 20
    
    # 6. 最终检查
    if docker compose exec $service curl -f http://localhost:8080/rest/health &>/dev/null; then
        success "$service 服务修复成功"
        return 0
    else
        error "$service 服务修复失败，需要手动干预"
        return 1
    fi
}

# 创建优化的docker-compose配置
create_optimized_compose_config() {
    cat > "$COMPOSE_FILE" <<EOF
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
    deploy:
      resources:
        limits:
          memory: 256M
        reservations:
          memory: 128M

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
      - "0.0.0.0:9040:8080"
    networks:
      - shlink_net
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/rest/health"]
      interval: 45s
      timeout: 30s
      retries: 8
      start_period: 180s
    deploy:
      resources:
        limits:
          memory: 768M
          cpus: "1.0"
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
      - "0.0.0.0:9050:8080"
    networks:
      - shlink_net
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080"]
      interval: 30s
      timeout: 10s
      retries: 3
    deploy:
      resources:
        limits:
          memory: 256M
        reservations:
          memory: 128M

networks:
  shlink_net:
    driver: bridge
    ipam:
      config:
        - subnet: 172.24.0.0/16

volumes:
  db_data:
    driver: local
EOF
}

# 完整的安装流程
install_shlink_complete() {
    log "开始完整安装流程..."
    
    # 检查系统资源
    check_system_resources
    
    # 清理和准备
    cleanup_containers
    check_ports || exit 1
    
    # 获取配置
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

    # 创建优化的docker-compose配置
    create_optimized_compose_config
    
    log "启动 Shlink 服务（优化配置）..."
    docker compose up -d
    
    # 等待服务（使用增强版等待函数）
    if wait_for_service_enhanced "shlink"; then
        generate_api_key
        docker compose up -d shlink_web_client
        show_access_info
    else
        warning "服务启动较慢，尝试自动优化..."
        if auto_fix_service_issues "shlink"; then
            generate_api_key
            docker compose up -d shlink_web_client
            show_access_info
        else
            error "安装失败，请查看日志手动修复"
            docker compose logs shlink
            exit 1
        fi
    fi
}

# 主安装函数
install_shlink() {
    log "开始安装 Shlink..."
    check_dependencies
    mkdir -p $WORKDIR
    cd $WORKDIR
    
    install_shlink_complete
}

# 主菜单
show_menu() {
    echo -e "${BLUE}=================================${NC}"
    echo -e "${BLUE}    Shlink 一键安装管理脚本     ${NC}"
    echo -e "${BLUE}=================================${NC}"
    echo "1) 安装 Shlink (自动修复版)"
    echo "2) 修复现有安装"
    echo "3) 查看状态和日志"
    echo "4) 重启服务"
    echo "5) 完全卸载"
    echo "0) 退出"
    echo -e "${BLUE}=================================${NC}"
    read -p "请选择操作 [0-5]: " choice
    
    case $choice in
        1) install_shlink ;;
        2) auto_fix_existing_installation ;;
        3) show_status_and_logs ;;
        4) docker compose restart ;;
        5) docker compose down -v && rm -rf $WORKDIR ;;
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

# 包含其他函数（check_dependencies, cleanup_containers, check_ports, generate_api_key, show_access_info等）
# ... [之前定义的其他函数]

main "$@"