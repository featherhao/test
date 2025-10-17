#!/bin/bash
set -e

CONFIG_FILE=/usr/local/frps/frps.ini
CONTAINER_NAME=frps

# ================== 彩色输出 ==================
C_RESET="\e[0m"; C_GREEN="\e[32m"; C_RED="\e[31m"; C_YELLOW="\e[33m"; C_BLUE="\e[36m"

# ================== 生成随机 token ==================
generate_token() {
    openssl rand -hex 8
}

# ================== 获取最新 FRPS 版本 ==================
get_latest_version() {
    LATEST=$(curl -fsSL https://api.github.com/repos/fatedier/frp/releases/latest \
        | grep '"tag_name"' | cut -d '"' -f4 | tr -d '[:space:]')
    if [[ -z "$LATEST" ]]; then
        echo -e "${C_RED}❌ 获取最新版本失败，请检查网络${C_RESET}"
        exit 1
    fi
    echo -e "${C_GREEN}检测到最新版本: $LATEST${C_RESET}"
}

# ================== 生成配置文件 ==================
generate_config() {
    local TOKEN=$1
    mkdir -p $(dirname $CONFIG_FILE)
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
    echo -e "${C_GREEN}✅ 配置文件已生成/更新：${CONFIG_FILE}${C_RESET}"
    echo -e "Token: ${C_YELLOW}${TOKEN}${C_RESET}"
}

# ================== 启动 FRPS Docker ==================
start_frps() {
    local IMAGE=$1

    # 停止并删除旧容器
    docker stop $CONTAINER_NAME >/dev/null 2>&1 || true
    docker rm $CONTAINER_NAME >/dev/null 2>&1 || true

    # 启动容器
    docker run -d --name $CONTAINER_NAME \
      -p 7000:7000 -p 7500:7500 -p 8080:8080 -p 8443:8443 \
      -v $CONFIG_FILE:/frps.ini \
      $IMAGE /usr/bin/frps -c /frps.ini

    # 等待 3 秒检查 Dashboard
    sleep 3
    if docker logs $CONTAINER_NAME --tail 20 | grep -q "dashboard listen"; then
        echo -e "${C_GREEN}✅ FRPS Docker 已启动，Dashboard 可用${C_RESET}"
        echo -e "Dashboard 地址: http://$(curl -s ipv4.icanhazip.com):7500 (admin/admin)"
    else
        echo -e "${C_RED}❌ Dashboard 启动失败，请检查日志${C_RESET}"
        docker logs $CONTAINER_NAME --tail 50
    fi
}

# ================== 卸载 ==================
uninstall_frps() {
    echo -e "${C_YELLOW}正在卸载 FRPS Docker...${C_RESET}"
    docker stop $CONTAINER_NAME >/dev/null 2>&1 || true
    docker rm $CONTAINER_NAME >/dev/null 2>&1 || true
    rm -f $CONFIG_FILE
    echo -e "${C_GREEN}✅ FRPS 已卸载${C_RESET}"
}

# ================== 更新 ==================
update_frps() {
    echo -e "${C_YELLOW}正在更新 FRPS Docker...${C_RESET}"
    uninstall_frps
    install_latest
}

# ================== 安装最新版本 ==================
install_latest() {
    get_latest_version
    IMAGE="ghcr.io/fatedier/frps:${LATEST}"
    TOKEN=$(generate_token)
    generate_config $TOKEN
    start_frps $IMAGE
}

# ================== 安装 0.20.0 ==================
install_v020() {
    echo -e "${C_YELLOW}正在安装 FRPS 0.20.0 Docker...${C_RESET}"
    IMAGE="ghcr.io/fatedier/frps:v0.20.0"
    TOKEN=$(generate_token)
    generate_config $TOKEN
    start_frps $IMAGE
}

# ================== 修改配置 ==================
modify_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        echo -e "${C_RED}❌ 配置文件不存在，请先安装 FRPS${C_RESET}"
        return
    fi
    echo -e "${C_YELLOW}修改配置文件:${CONFIG_FILE}${C_RESET}"
    nano "$CONFIG_FILE"
    echo -e "${C_YELLOW}修改完成，重启容器生效${C_RESET}"
    docker restart $CONTAINER_NAME
}

# ================== 查看信息 ==================
show_info() {
    if docker ps -a | grep -q $CONTAINER_NAME; then
        echo -e "${C_GREEN}✅ FRPS Docker 容器存在${C_RESET}"
        docker ps | grep $CONTAINER_NAME
        echo -e "${C_BLUE}配置文件: ${CONFIG_FILE}${C_RESET}"
        echo -e "${C_BLUE}查看日志: docker logs $CONTAINER_NAME --tail 50${C_RESET}"
    else
        echo -e "${C_RED}❌ FRPS Docker 容器不存在${C_RESET}"
    fi
}

# ================== 菜单 ==================
while true; do
    echo ""
    echo "============== FRPS Docker 管理 =============="
    echo "1) 安装最新 FRPS"
    echo "2) 安装 FRPS 0.20.0"
    echo "3) 卸载 FRPS"
    echo "4) 查看运行信息"
    echo "5) 修改配置"
    echo "0) 退出"
    echo "============================================="
    read -rp "请选择 [0-5]: " choice
    case "$choice" in
        1) install_latest ;;
        2) install_v020 ;;
        3) uninstall_frps ;;
        4) show_info ;;
        5) modify_config ;;
        0) echo "已退出"; exit 0 ;;
        *) echo "无效选择，请重试。" ;;
    esac
done
