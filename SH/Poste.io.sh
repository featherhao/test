#!/bin/bash
set -e
# set -u 去掉，避免未定义变量直接退出
set -o pipefail

# ================= 基础配置 =================
WORKDIR="/opt/poste.io"
DATADIR="${WORKDIR}/data"
COMPOSE_FILE="${WORKDIR}/docker-compose.yml"
CONTAINER_NAME="poste.io"
POSTE_IMAGE="analogic/poste.io"
DEFAULT_DOMAIN="mail.example.com"
DEFAULT_ADMIN="admin@${DEFAULT_DOMAIN}"

# ================= 彩色输出 =================
info()  { echo -e "\e[32m[INFO]\e[0m $*"; }
warn()  { echo -e "\e[33m[WARN]\e[0m $*"; }
error() { echo -e "\e[31m[ERROR]\e[0m $*"; }

# ================= docker 检测 =================
ensure_docker() {
    if ! command -v docker >/dev/null 2>&1; then
        warn "未检测到 Docker，部分功能可能无法使用，请先安装 Docker。"
        return 1
    fi
    return 0
}

# ================= 安装检查 =================
check_installed() {
    if ! ensure_docker; then return 1; fi
    docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$" && return 0 || return 1
}

# ================= 环境变量 =================
save_env() {
    cat > "$ENV_FILE" <<EOF
DOMAIN=${DOMAIN}
ADMIN_EMAIL=${ADMIN_EMAIL}
HTTP_PORT=${HTTP_PORT}
HTTPS_PORT=${HTTPS_PORT}
CONTAINER_NAME=${CONTAINER_NAME}
EOF
}

load_env() {
    ENV_FILE="${WORKDIR}/.env"
    if [ -f "$ENV_FILE" ]; then
        source "$ENV_FILE"
    fi
    DOMAIN=${DOMAIN:-$DEFAULT_DOMAIN}
    ADMIN_EMAIL=${ADMIN_EMAIL:-$DEFAULT_ADMIN}
    HTTP_PORT=${HTTP_PORT:-80}
    HTTPS_PORT=${HTTPS_PORT:-443}
    CONTAINER_NAME=${CONTAINER_NAME:-poste.io}
}

# ================= 获取本机 IP =================
get_server_ip() {
    local ip
    ip=$(hostname -I 2>/dev/null | awk '{print $1}')
    [ -z "$ip" ] && ip=$(curl -s4 https://api.ipify.org 2>/dev/null || true)
    echo "${ip:-127.0.0.1}"
}

# ================= 检测端口 =================
detect_ports() {
    HTTP_PORT=80
    HTTPS_PORT=443
    if ss -ltn | grep -q ':80 '; then
        warn "80 端口已占用，改用 81"
        HTTP_PORT=81
    fi
    if ss -ltn | grep -q ':443 '; then
        warn "443 端口已占用，改用 444"
        HTTPS_PORT=444
    fi
}

check_25_port() {
    if timeout 3 bash -c "echo > /dev/tcp/smtp.qq.com/25" >/dev/null 2>&1; then
        info "25 端口出站可用"
    else
        warn "25 端口不可用，可能无法发送邮件"
    fi
}

# ================= 安装 =================
install_poste() {
    ensure_docker || return
    mkdir -p "$DATADIR"

    read -rp "请输入邮件域名 (默认: ${DEFAULT_DOMAIN}): " DOMAIN
    DOMAIN=${DOMAIN:-$DEFAULT_DOMAIN}
    read -rp "请输入管理员邮箱 (默认: ${DEFAULT_ADMIN}): " ADMIN_EMAIL
    ADMIN_EMAIL=${ADMIN_EMAIL:-$DEFAULT_ADMIN}

    BASE_DOMAIN=${DOMAIN#mail.}
    ipv4_address=$(get_server_ip)

    echo ""
    echo "=============== 请先解析以下 DNS 记录 ==============="
    echo "A      mail      $ipv4_address"
    echo "CNAME  imap      mail.${BASE_DOMAIN}"
    echo "CNAME  pop       mail.${BASE_DOMAIN}"
    echo "CNAME  smtp      mail.${BASE_DOMAIN}"
    echo "MX     @         mail.${BASE_DOMAIN}   优先级 10"
    echo "TXT    @         v=spf1 mx ~all"
    echo "TXT    _dmarc    v=DMARC1; p=none; rua=mailto:${ADMIN_EMAIL}"
    echo "===================================================="
    read -n1 -s -r -p "请确认 DNS 已添加，按任意键继续安装..."
    echo ""

    detect_ports
    check_25_port
    save_env

    cat > "$COMPOSE_FILE" <<EOF
version: '3.7'
services:
  poste:
    image: ${POSTE_IMAGE}:latest
    container_name: ${CONTAINER_NAME}
    restart: always
    ports:
      - "${HTTP_PORT}:80"
      - "${HTTPS_PORT}:443"
      - "25:25"
      - "587:587"
      - "110:110"
      - "143:143"
      - "465:465"
      - "995:995"
      - "993:993"
    volumes:
      - ${DATADIR}:/data
    environment:
      - DISABLE_CLAMAV=TRUE
      - DISABLE_SPAMASSASSIN=TRUE
      - HOSTNAME=${DOMAIN}
      - POSTMASTER_ADDRESS=${ADMIN_EMAIL}
EOF

    info "Docker Compose 文件已生成：${COMPOSE_FILE}"
    if ensure_docker; then
        docker compose -f "$COMPOSE_FILE" up -d --remove-orphans || warn "容器启动失败，请检查 Docker 日志。"
    else
        warn "Docker 未安装，跳过启动容器"
    fi
    info "Poste.io 安装完成！"
    show_info
}

# ================= 显示信息 =================
show_info() {
    load_env
    local ip=$(get_server_ip)
    BASE_DOMAIN=${DOMAIN#mail.}
    cat <<EOF

================== Poste.io 信息 ==================
容器名称:  ${CONTAINER_NAME}
访问地址:
  管理后台:   https://${DOMAIN}:${HTTPS_PORT}/admin
  Webmail:    https://${DOMAIN}:${HTTPS_PORT}/webmail
服务器 IP:  ${ip}
=================================================

EOF
}

# ================= 显示 DNS =================
show_dns() {
    load_env
    ipv4_address=$(get_server_ip)
    BASE_DOMAIN=${DOMAIN#mail.}
    echo ""
    echo "=============== DNS 配置建议 ==============="
    echo "A      mail      $ipv4_address"
    echo "CNAME  imap      mail.${BASE_DOMAIN}"
    echo "CNAME  pop       mail.${BASE_DOMAIN}"
    echo "CNAME  smtp      mail.${BASE_DOMAIN}"
    echo "MX     @         mail.${BASE_DOMAIN}   优先级 10"
    echo "TXT    @         v=spf1 mx ~all"
    echo "TXT    _dmarc    v=DMARC1; p=none; rua=mailto:${ADMIN_EMAIL}"
    echo "==========================================="
    echo ""
    read -n1 -s -r -p "按任意键返回..."
    echo ""
}

# ================= 更新 =================
update_poste() {
    ensure_docker || return
    load_env
    if ! check_installed; then
        warn "未检测到 Poste.io 容器，无法更新，请先安装。"
        return
    fi
    info "开始更新 Poste.io..."
    docker compose -f "$COMPOSE_FILE" pull || warn "拉取镜像失败"
    docker compose -f "$COMPOSE_FILE" up -d --remove-orphans || warn "启动容器失败"
    info "更新完成！"
    show_info
}

# ================= 卸载 =================
uninstall_poste() {
    ensure_docker
    load_env
    if ! check_installed; then
        warn "未检测到 Poste.io 容器。"
        return
    fi
    read -p "⚠️ 确认卸载 Poste.io 容器？(y/N): " confirm
    if [[ ! "${confirm}" =~ ^[Yy]$ ]]; then
        info "已取消卸载。"
        return
    fi
    if ensure_docker; then
        docker compose -f "$COMPOSE_FILE" down || warn "卸载容器失败"
    fi
    read -p "是否删除数据目录 ${DATADIR} ? (y/N): " deldata
    if [[ "${deldata}" =~ ^[Yy]$ ]]; then
        rm -rf "${DATADIR}"
        info "已删除数据目录。"
    fi
    rm -f "$COMPOSE_FILE" "$ENV_FILE"
    info "卸载完成。"
}

# ================= 主菜单 =================
if check_installed; then
    show_info
fi

while true; do
    echo "=============================="
    echo " Poste.io 管理脚本"
    echo "=============================="

    if check_installed; then
        echo "1) 显示运行信息"
        echo "2) 显示 DNS 配置"
        echo "3) 更新 Poste.io"
        echo "4) 卸载 Poste.io"
        echo "0) 退出"
        read -rp "请输入选项: " choice
        case "$choice" in
            1) show_info ;;
            2) show_dns ;;
            3) update_poste ;;
            4) uninstall_poste ;;
            0) exit 0 ;;
            *) warn "无效选项" ;;
        esac
    else
        echo "尚未安装 Poste.io。"
        echo "1) 安装 Poste.io"
        echo "2) 显示 DNS 配置"
        echo "0) 退出"
        read -rp "请输入选项: " choice
        case "$choice" in
            1) install_poste ;;
            2) show_dns ;;
            0) exit 0 ;;
            *) warn "无效选项" ;;
        esac
    fi
    echo ""
done
