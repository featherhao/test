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
version: "3.8"
services:
  cov:
    image: $IMAGE
    container_name: cov
    ports:
      - "50000:50000"
    command: ["python", "web.py", "--port", "50000"]
    stdin_open: true
    tty: true
    restart: unless-stopped
EOF
}

# ================== 功能函数 ==================
install_cov() {
    detect_arch
    check_docker
    make_compose
    info "启动服务..."
    docker-compose up -d
    sleep 2
    status_cov
}

status_cov() {
    if docker ps --filter "name=cov" --filter "status=running" | grep cov &>/dev/null; then
        ip=$(hostname -I | awk '{print $1}')
        info "容器运行中"
        echo -e "📦 镜像: $IMAGE"
        echo -e "🌍 访问地址: ${green}http://$ip:50000${plain}"
    else
        error "容器未运行"
    fi
}

uninstall_cov() {
    if [[ -f docker-compose.yml ]]; then
        docker-compose down
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
