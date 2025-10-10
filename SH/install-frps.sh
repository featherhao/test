#!/bin/bash
set -Eeuo pipefail

# ================== 彩色输出 ==================
C_RESET="\e[0m"; C_GREEN="\e[32m"; C_RED="\e[31m"; C_YELLOW="\e[33m"

INSTALL_DIR="/usr/local/frps"
SERVICE_FILE="/etc/systemd/system/frps.service"

# ================== 获取最新版本 ==================
get_latest_version() {
    echo -e "${C_YELLOW}正在获取 Frp 最新版本...${C_RESET}"
    LATEST_VERSION=$(curl -fsSL https://api.github.com/repos/fatedier/frp/releases/latest | grep '"tag_name"' | cut -d '"' -f4 | tr -d '[:space:]')
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

# ================== 安装 ==================
install_frps() {
    get_latest_version
    get_arch
    echo -e "${C_GREEN}开始安装 Frps，请稍候...${C_RESET}"
    mkdir -p "$INSTALL_DIR"
    cd /tmp

    FILE="frp_${LATEST_VERSION#v}_linux_${ARCH}.tar.gz"
    URL="https://github.com/fatedier/frp/releases/download/${LATEST_VERSION}/${FILE}"

    echo -e "${C_YELLOW}正在下载：${FILE}${C_RESET}"
    if ! curl -L -o "$FILE" "$URL"; then
        echo -e "${C_RED}下载失败，请检查网络或 GitHub 连接${C_RESET}"
        return
    fi

    tar -zxvf "$FILE" -C /tmp >/dev/null 2>&1
    cp -f frp_*/frps "$INSTALL_DIR/"
    cp -f frp_*/frps.ini "$INSTALL_DIR/" 2>/dev/null || true
    rm -rf frp_*

    # 创建默认配置
    cat > "$INSTALL_DIR/frps.ini" <<EOF
[common]
bind_port = 7000
dashboard_port = 7500
dashboard_user = admin
dashboard_pwd = admin
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

    echo -e "${C_GREEN}✅ Frps 安装完成！${C_RESET}"
    echo -e "运行状态：${C_YELLOW}systemctl status frps${C_RESET}"
    echo -e "配置文件：${C_YELLOW}${INSTALL_DIR}/frps.ini${C_RESET}"
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
    install_frps
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
    echo -e "${C_YELLOW}配置文件：${INSTALL_DIR}/frps.ini${C_RESET}"
    echo -e "${C_YELLOW}日志查看：journalctl -u frps -f${C_RESET}"
}

# ================== 菜单 ==================
while true; do
    echo ""
    echo "================ Frps 管理菜单 ================"
    echo "1) 安装 Frps"
    echo "2) 卸载 Frps"
    echo "3) 更新 Frps"
    echo "4) 查看运行信息"
    echo "0) 退出"
    echo "=============================================="
    read -rp "请选择操作 [0-4]: " choice
    case "$choice" in
        1) install_frps ;;
        2) uninstall_frps ;;
        3) update_frps ;;
        4) show_info ;;
        0) echo "已退出"; exit 0 ;;
        *) echo "无效选择，请重试。" ;;
    esac
done
