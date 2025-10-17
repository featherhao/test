#!/bin/bash
set -Eeuo pipefail

# ================== 彩色输出 ==================
C_RESET="\e[0m"; C_GREEN="\e[32m"; C_RED="\e[31m"; C_YELLOW="\e[33m"; C_BLUE="\e[36m"

FRPS_CONTAINER="frps"
CONFIG_DIR="/usr/local/frps"
CONFIG_FILE="${CONFIG_DIR}/frps.ini"

# ================== 自动识别架构 ==================
get_arch() {
    ARCH=$(uname -m)
    case "$ARCH" in
        x86_64) DOCKER_ARCH="amd64" ;;
        aarch64|arm64) DOCKER_ARCH="arm64" ;;
        armv7l|armv7) DOCKER_ARCH="arm32" ;;
        *) echo -e "${C_RED}❌ 不支持的架构：$ARCH${C_RESET}"; exit 1 ;;
    esac
}

# ================== 获取最新版本 ==================
get_latest_version() {
    echo -e "${C_YELLOW}正在获取 FRPS 最新版本...${C_RESET}"
    LATEST_VERSION=$(curl -fsSL https://api.github.com/repos/fatedier/frp/releases/latest \
        | grep '"tag_name"' | cut -d '"' -f4 | tr -d '[:space:]')
    if [[ -z "$LATEST_VERSION" ]]; then
        echo -e "${C_RED}❌ 获取最新版本失败${C_RESET}"
        exit 1
    fi
    LATEST_VERSION=${LATEST_VERSION#v}  # 去掉开头的 v
    echo -e "${C_GREEN}检测到最新版本：${LATEST_VERSION}${C_RESET}"
}

# ================== 获取 FRPS 镜像 ==================
get_frps_image() {
    local version=$1
    get_arch
    if [[ "$version" == "0.20.0" ]]; then
        case "$DOCKER_ARCH" in
            amd64) IMAGE="ghcr.io/fatedier/frps:v0.20.0-amd64" ;;
            arm64) IMAGE="ghcr.io/fatedier/frps:v0.20.0-arm64" ;;
            arm32) IMAGE="ghcr.io/fatedier/frps:v0.20.0-arm32" ;;
        esac
    else
        case "$DOCKER_ARCH" in
            amd64) IMAGE="ghcr.io/fatedier/frps:v${version}@sha256:5c0755b887dc051dc5a7164ab4849ec151ac3b447f7e87e1b9df5ff03de8a8e4" ;;
            arm64) IMAGE="ghcr.io/fatedier/frps:v${version}@sha256:a25093a82412bc3b9118a08a55ef4766ef84b52fd2d9de596d7124ae2d446218" ;;
            arm32) IMAGE="ghcr.io/fatedier/frps:v${version}@sha256:2bd9397e0e8cdac37eef0d3f8735b758890702afcd6066e9757bd03aebd030e4" ;;
        esac
    fi
}

# ================== 创建配置 ==================
create_config() {
    mkdir -p "$CONFIG_DIR"
    if [[ ! -f "$CONFIG_FILE" ]]; then
        TOKEN=$(openssl rand -hex 8)
        SERVER_IP=$(curl -s ipv4.icanhazip.com || hostname -I | awk '{print $1}')
        cat > "$CONFIG_FILE" <<EOF
[common]
bind_port = 7000
dashboard_port = 7500
dashboard_user = admin
dashboard_pwd = admin
token = ${TOKEN}
vhost_http_port = 8080
vhost_https_port = 8443
EOF
        echo -e "${C_GREEN}✅ 配置文件已生成：${CONFIG_FILE}${C_RESET}"
        echo -e "Token: ${C_YELLOW}${TOKEN}${C_RESET}"
        echo -e "Dashboard: http://${SERVER_IP}:7500 (admin/admin)"
    fi
}

# ================== 安装 FRPS ==================
install_frps() {
    local version=${1:-""}
    if [[ -z "$version" ]]; then
        get_latest_version
        version="$LATEST_VERSION"
    fi
    get_frps_image "$version"
    create_config

    echo -e "${C_YELLOW}正在拉取 FRPS Docker 镜像：${IMAGE}${C_RESET}"
    docker pull "$IMAGE"

    echo -e "${C_YELLOW}正在启动 FRPS 容器...${C_RESET}"
    docker rm -f "$FRPS_CONTAINER" >/dev/null 2>&1 || true
    docker run -d \
        --name "$FRPS_CONTAINER" \
        -p 7000:7000 \
        -p 7500:7500 \
        -p 8080:8080 \
        -p 8443:8443 \
        -v "$CONFIG_FILE":/frps.ini \
        "$IMAGE"

    echo -e "${C_GREEN}✅ FRPS ${version} 已启动${C_RESET}"
}

# ================== 卸载 FRPS ==================
uninstall_frps() {
    echo -e "${C_YELLOW}正在卸载 FRPS Docker 容器...${C_RESET}"
    docker rm -f "$FRPS_CONTAINER" >/dev/null 2>&1 || true
    echo -e "${C_YELLOW}删除镜像...${C_RESET}"
    get_frps_image "0.20.0"; docker rmi "$IMAGE" >/dev/null 2>&1 || true
    get_latest_version; get_frps_image "$LATEST_VERSION"; docker rmi "$IMAGE" >/dev/null 2>&1 || true
    echo -e "${C_GREEN}✅ FRPS 已卸载${C_RESET}"
}

# ================== 更新 FRPS ==================
update_frps() {
    echo -e "${C_YELLOW}开始更新 FRPS 到最新版本...${C_RESET}"
    get_latest_version
    echo -e "${C_YELLOW}拉取最新镜像...${C_RESET}"
    get_frps_image "$LATEST_VERSION"
    docker pull "$IMAGE"
    echo -e "${C_YELLOW}停止并删除旧容器...${C_RESET}"
    docker rm -f "$FRPS_CONTAINER" >/dev/null 2>&1 || true
    echo -e "${C_YELLOW}启动新容器...${C_RESET}"
    docker run -d \
        --name "$FRPS_CONTAINER" \
        -p 7000:7000 \
        -p 7500:7500 \
        -p 8080:8080 \
        -p 8443:8443 \
        -v "$CONFIG_FILE":/frps.ini \
        "$IMAGE"
    echo -e "${C_GREEN}✅ FRPS 已更新到最新版本 ${LATEST_VERSION}${C_RESET}"
}

# ================== 显示状态 ==================
show_info() {
    if docker ps -a --format '{{.Names}}' | grep -q "^$FRPS_CONTAINER\$"; then
        echo -e "${C_GREEN}✅ FRPS 容器存在${C_RESET}"
        docker logs --tail 20 "$FRPS_CONTAINER"
    else
        echo -e "${C_RED}❌ FRPS 容器未启动${C_RESET}"
    fi
    echo -e "配置文件: $CONFIG_FILE"
}

# ================== 脚本入口 ==================
if [[ $(docker ps -a --format '{{.Names}}' | grep -c "^$FRPS_CONTAINER\$") -eq 0 ]]; then
    echo -e "${C_YELLOW}检测到 FRPS 未安装，默认安装最新版本 ...${C_RESET}"
    install_frps
fi

# ================== 菜单 ==================
while true; do
    echo ""
    echo "============== FRPS Docker 管理 =============="
    echo "1) 安装最新 FRPS"
    echo "2) 安装 FRPS 0.20.0"
    echo "3) 卸载 FRPS"
    echo "4) 更新 FRPS 到最新版本"
    echo "5) 查看运行信息"
    echo "0) 退出"
    echo "============================================="
    read -rp "请选择 [0-5]: " choice
    case "$choice" in
        1) install_frps ;;
        2) install_frps "0.20.0" ;;
        3) uninstall_frps ;;
        4) update_frps ;;
        5) show_info ;;
        0) exit 0 ;;
        *) echo "无效选择，请重试。" ;;
    esac
done
