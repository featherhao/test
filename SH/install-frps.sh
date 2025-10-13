#!/bin/bash
set -Eeuo pipefail

# ================== 彩色输出 ==================
C_RESET="\e[0m"; C_GREEN="\e[32m"; C_RED="\e[31m"; C_YELLOW="\e[33m"; C_BLUE="\e[36m"

INSTALL_DIR="/usr/local/frps"
SERVICE_FILE="/etc/systemd/system/frps.service"

# ================== 获取最新版本 ==================
get_latest_version() {
    echo -e "${C_YELLOW}正在获取 Frp 最新版本...${C_RESET}"
    LATEST_VERSION=$(curl -fsSL https://api.github.com/repos/fatedier/frp/releases/latest \
        | grep '"tag_name"' | cut -d '"' -f4 | tr -d '[:space:]')
    if [[ -z "$LATEST_VERSION" ]]; then
        echo -e "${C_RED}❌ 获取最新版本失败，请检查网络！${C_RESET}"
        exit 1
    fi
    echo -e "${C_GREEN}检测到最新版本：${LATEST_VERSION}${C_RESET}"
}

# ================== 检测架构 ==================
get_arch() {
    ARCH=$(uname -m)
    case "$ARCH" in
        x86_64) ARCH="amd64" ;;
        aarch64 | arm64) ARCH="arm64" ;;
        armv7l) ARCH="arm" ;;
        i386 | i686) ARCH="386" ;;
        *) echo -e "${C_RED}不支持的架构：${ARCH}${C_RESET}"; exit 1 ;;
    esac
}

# ================== 通用安装函数 ==================
install_frps_common() {
    local VERSION=$1
    local IS_FIXED=${2:-0}
    get_arch
    mkdir -p "$INSTALL_DIR"
    cd /tmp

    FILE="frp_${VERSION}_linux_${ARCH}.tar.gz"
    if [[ "$IS_FIXED" -eq 1 ]]; then
        URL="https://github.com/fatedier/frp/releases/download/v${VERSION}/${FILE}"
    else
        URL="https://github.com/fatedier/frp/releases/download/${VERSION}/${FILE}"
    fi

    echo -e "${C_YELLOW}正在下载：${FILE}${C_RESET}"
    if ! curl -L -o "$FILE" "$URL"; then
        echo -e "${C_RED}下载失败，请检查网络或 GitHub 连接${C_RESET}"
        return
    fi

    echo -e "${C_BLUE}正在解压文件...${C_RESET}"
    tar -zxvf "$FILE" -C /tmp >/dev/null 2>&1
    cp -f frp_*/frps "$INSTALL_DIR/"
    rm -rf frp_*

    # 生成随机 token
    TOKEN=$(openssl rand -hex 8)
    SERVER_IP=$(curl -s ipv4.icanhazip.com || hostname -I | awk '{print $1}')

    # 创建配置文件
    cat > "$INSTALL_DIR/frps.ini" <<EOF
[common]
bind_port = 7000
dashboard_port = 7500
dashboard_user = admin
dashboard_pwd = admin
token = ${TOKEN}
vhost_http_port = 8080
vhost_https_port = 8443
EOF

    # 创建 systemd 服务
    cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Frps Service
After=network.target

[Service]
ExecStart=${INSTALL_DIR}/frps -c ${INSTALL_DIR}/frps.ini
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable frps
    systemctl restart frps

    echo ""
    echo -e "${C_GREEN}✅ Frps ${VERSION} 安装完成！${C_RESET}"
    echo -e "--------------------------------------------------"
    echo -e "${C_YELLOW}Frps 服务已启动${C_RESET}"
    echo -e "${C_BLUE}服务端地址：${C_RESET}${SERVER_IP}"
    echo -e "${C_BLUE}绑定端口：${C_RESET}7000"
    echo -e "${C_BLUE}Token：${C_RESET}${TOKEN}"
    echo -e "${C_BLUE}Dashboard 地址：${C_RESET}http://${SERVER_IP}:7500"
    echo -e "${C_BLUE}Dashboard 用户名：${C_RESET}admin"
    echo -e "${C_BLUE}Dashboard 密码：${C_RESET}admin"
    echo -e "${C_BLUE}配置文件：${C_RESET}${INSTALL_DIR}/frps.ini"
    echo -e "--------------------------------------------------"
    echo -e "可执行命令：${C_YELLOW}systemctl status frps${C_RESET}"
    echo -e ""
}

# ================== 安装最新版本 ==================
install_frps_latest() {
    get_latest_version
    install_frps_common "${LATEST_VERSION#v}"
}

# ================== 安装固定 0.20.0 版本 ==================
install_frps_v020() {
    echo -e "${C_YELLOW}开始安装 Frps 0.20.0 版本...${C_RESET}"
    install_frps_common "0.20.0" 1
}

# ================== 卸载 ==================
uninstall_frps() {
    echo -e "${C_YELLOW}正在卸载 Frps...${C_RESET}"
    systemctl stop frps >/dev/null 2>&1 || true
    systemctl disable frps >/dev/null 2>&1 || true
    rm -f "$SERVICE_FILE"
    rm -rf "$INSTALL_DIR"
    systemctl daemon-reload
    echo -e "${C_GREEN}✅ Frps 已卸载${C_RESET}"
}

# ================== 更新 ==================
update_frps() {
    echo -e "${C_YELLOW}正在更新 Frps...${C_RESET}"
    uninstall_frps
    install_frps_latest
}

# ================== 查看信息 ==================
show_info() {
    echo -e "${C_YELLOW}========= Frps 状态信息 =========${C_RESET}"
    if systemctl is-active --quiet frps; then
        echo -e "${C_GREEN}✅ Frps 正在运行${C_RESET}"
    else
        echo -e "${C_RED}❌ Frps 未运行${C_RESET}"
    fi
    systemctl status frps --no-pager || true
    echo ""
    echo -e "${C_YELLOW}配置文件：${INSTALL_DIR}/frps.ini${C_RESET}"
    echo -e "${C_YELLOW}查看日志：journalctl -u frps -f${C_RESET}"
}

# ================== 菜单循环 ==================
while true; do
    echo ""
    echo "================ Frps 管理菜单 ================"
    echo "1) 安装 Frps 最新版"
    echo "2) 卸载 Frps"
    echo "3) 更新 Frps"
    echo "4) 查看运行信息"
    echo "5) 安装 Frps 0.20.0 版本"
    echo "0) 退出"
    echo "=============================================="
    read -rp "请选择操作 [0-5]: " choice
    case "$choice" in
        1) install_frps_latest ;;
        2) uninstall_frps ;;
        3) update_frps ;;
        4) show_info ;;
        5) install_frps_v020 ;;
        0) echo "已退出"; exit 0 ;;
        *) echo "无效选择，请重试。" ;;
    esac
done
