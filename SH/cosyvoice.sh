#!/bin/bash
set -Eeuo pipefail

# ================== 彩色输出 ==================
green="\033[32m"
red="\033[31m"
yellow="\033[33m"
plain="\033[0m"

info()  { echo -e "${green}[INFO]${plain} $1"; }
warn()  { echo -e "${yellow}[WARN]${plain} $1"; }
error() { echo -e "${red}[ERROR]${plain} $1"; }

# ================== 获取公网 IP ==================
get_public_ip() {
    for svc in "https://api.ipify.org" "https://ifconfig.co" "https://icanhazip.com" "https://ipinfo.io/ip"; do
        ip=$(curl -fsS --max-time 3 "$svc" 2>/dev/null || true)
        if [[ $ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            echo "$ip"
            return 0
        fi
    done
    ip=$(ip route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="src") print $(i+1)}' | head -n1)
    if [[ $ip ]]; then echo "$ip"; return 0; fi
    echo "$(hostname -I 2>/dev/null | awk '{print $1}')"
}

# ================== 架构检测 ==================
detect_arch() {
    arch=$(uname -m)
    if [[ "$arch" == "x86_64" ]]; then
        IMAGE="eureka6688/cosyvoice:latest"
    elif [[ "$arch" =~ ^arm|aarch64$ ]]; then
        IMAGE="eureka6688/cosyvoice:arm"
    else
        error "暂不支持的架构: $arch"
        exit 1
    fi
}

# ================== Docker 检查 ==================
check_docker() {
    if ! command -v docker &>/dev/null; then
        warn "未检测到 Docker，正在安装..."
        curl -fsSL https://get.docker.com | sh
        systemctl enable docker
        systemctl start docker
    fi

    if ! command -v docker-compose &>/dev/null; then
        warn "未检测到 docker-compose，正在安装..."
        curl -L "https://github.com/docker/compose/releases/download/2.29.7/docker-compose-$(uname -s)-$(uname -m)" \
            -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose
    fi
}

# ================== docker-compose.yml 生成 ==================
make_compose() {
    cat > docker-compose.yml <<EOF
services:
  cov:
    image: $IMAGE
    container_name: cov
    ports:
      - "$PORT:50000"
    command: ["python", "web.py", "--port", "50000"]
    stdin_open: true
    tty: true
    restart: unless-stopped
EOF
}

# ================== 安装/启动 ==================
install_cov() {
    detect_arch
    check_docker
    read -p "请输入服务端口 [默认50000]: " port
    PORT=${port:-50000}

    if docker ps -a --format '{{.Names}}' | grep -xq cov; then
        info "检测到已有容器 cov，正在启动..."
        docker start cov || true
    else
        make_compose
        info "首次安装容器..."
        docker-compose up -d || true
    fi

    sleep 3
    status_cov
}

# ================== 查看状态 ==================
status_cov() {
    if ! docker ps --filter "name=^/cov$" --filter "status=running" --format '{{.Names}}' | grep -xq cov; then
        error "容器 cov 未运行"
        return 1
    fi

    # 容器端口映射
    bind_info=$(docker port cov 2>/dev/null | grep -E '0.0.0.0|::' | xargs)
    [[ -n "$bind_info" ]] && echo -e "🔌 端口映射: $bind_info"

    echo -e "${green}[INFO]${plain} 容器运行中： cov"
    echo -e "📦 镜像: $(docker inspect --format='{{.Config.Image}}' cov 2>/dev/null || echo 'unknown')"

    # 公网 IP
    public_ip=$(get_public_ip)
    exposed_port=$(docker port cov 50000/tcp 2>/dev/null | head -n1 | awk -F':' '{print $2}')
    exposed_port=${exposed_port:-50000}

    ip_note=""
    if [[ $public_ip =~ ^(10\.|192\.168\.|172\.(1[6-9]|2[0-9]|3[0-1])\.) ]]; then
        ip_note="（内网地址，可能无法公网访问）"
    fi
    [[ -n "$public_ip" ]] && echo -e "🌍 建议访问地址: http://$public_ip:$exposed_port $ip_note"

    # 本机 IPv4（默认出口）
    ipv4=$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="src") print $(i+1)}')
    echo -e "📡 本机 IPv4: ${ipv4:-未知}"

    # 本机全局 IPv6
    ipv6=$(ip -6 addr show scope global 2>/dev/null | grep 'inet6' | awk '{print $2}' | cut -d/ -f1 | xargs)
    echo -e "📡 本机 IPv6: ${ipv6:-无}"

    if [[ $ip_note != "" ]]; then
        echo -e "\n${yellow}[WARN]${plain} 当前返回的地址为内网地址，请确保端口映射或使用公网 IP 访问。"
    fi
}

# ================== 卸载 ==================
uninstall_cov() {
    if [[ -f docker-compose.yml ]]; then
        docker-compose down || true
        rm -f docker-compose.yml
        info "容器已卸载，配置已删除"
    else
        warn "未检测到 docker-compose.yml，无需卸载"
    fi
}

# ================== 菜单 ==================
menu() {
    clear
    echo "================= CosyVoice 管理菜单 ================="
    echo " 1) 安装/启动"
    echo " 2) 查看状态"
    echo " 3) 卸载"
    echo " 0) 退出"
    echo "======================================================"
    read -p "请输入选项 [0-3]: " choice
    case "$choice" in
        1) install_cov ;;
        2) status_cov ;;
        3) uninstall_cov ;;
        0) exit 0 ;;
        *) error "无效选项，请重新输入" ;;
    esac
}

# ================== 主程序循环 ==================
while true; do
    menu
    echo
    read -p "按回车键继续..." enter
done
