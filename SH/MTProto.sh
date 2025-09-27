#!/usr/bin/env bash
set -euo pipefail

DATA_DIR="/etc/mtproxy"
SECRET_FILE="${DATA_DIR}/secret"
DEFAULT_PORT=6688
PORT=""
SECRET=""
LOG_FILE="${DATA_DIR}/mtproxy.log"

# ================= 彩色输出 =================
info() { printf "\033[1;34m%s\033[0m\n" "$*"; }
warn() { printf "\033[1;33m%s\033[0m\n" "$*"; }
error() { printf "\033[1;31m%s\033[0m\n" "$*"; exit 1; }

# ================= 系统依赖检查 =================
check_deps() {
    for cmd in curl git make g++ libssl-dev iptables; do
        if ! command -v $cmd >/dev/null 2>&1; then
            if command -v apt >/dev/null 2>&1; then
                info "安装依赖 $cmd"
                apt update && apt install -y $cmd
            elif command -v yum >/dev/null 2>&1; then
                info "安装依赖 $cmd"
                yum install -y $cmd
            else
                warn "请手动安装 $cmd"
            fi
        fi
    done
}

# ================= 查找空闲端口 =================
find_free_port() {
    local port="$1"
    while ss -ltn 2>/dev/null | awk '{print $4}' | grep -q ":$port\$"; do
        port=$((port + 1))
    done
    echo "$port"
}

# ================= 生成 secret =================
generate_secret() {
    mkdir -p "$DATA_DIR"
    if [ -f "$SECRET_FILE" ]; then
        SECRET=$(cat "$SECRET_FILE")
    else
        SECRET=$(openssl rand -hex 32)  # 64 hex
        echo -n "$SECRET" > "$SECRET_FILE"
    fi
}

# ================= 获取公网 IP =================
public_ip() {
    curl -fs --max-time 5 https://api.ipify.org \
    || curl -fs --max-time 5 https://ifconfig.me \
    || curl -fs --max-time 5 https://ip.sb \
    || echo "UNKNOWN"
}

# ================= 开放端口 =================
open_port() {
    local port="$1"
    if command -v ufw >/dev/null 2>&1; then
        sudo ufw allow "$port"/tcp || true
    fi
    sudo iptables -I INPUT -p tcp --dport "$port" -j ACCEPT || true
}

# ================= 安装 MTProxy =================
install_mtproxy() {
    check_deps
    generate_secret
    read -r -p "请输入端口号 (留空使用默认 $DEFAULT_PORT): " input_port
    PORT=$(find_free_port "${input_port:-$DEFAULT_PORT}")
    open_port "$PORT"

    # 下载并编译 MTProxy
    mkdir -p /opt/mtproxy
    cd /opt
    if [ ! -d "MTProxy" ]; then
        git clone https://github.com/TelegramMessenger/MTProxy
    fi
    cd MTProxy
    make -j$(nproc)

    # 写 systemd 服务
    mkdir -p "$DATA_DIR"
    cat > /etc/systemd/system/mtproxy.service <<EOF
[Unit]
Description=MTProxy
After=network.target

[Service]
Type=simple
User=nobody
WorkingDirectory=/opt/MTProxy
ExecStart=/opt/MTProxy/objs/bin/mtproto-proxy -u nobody -p $PORT -H 443 -S $SECRET --aes-pwd $DATA_DIR/proxy-secret $DATA_DIR/proxy-multi.conf -M 1
Restart=on-failure
StandardOutput=file:$LOG_FILE
StandardError=file:$LOG_FILE

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable mtproxy
    systemctl restart mtproxy
    info "MTProxy 安装完成并启动"
}

# ================= 更新 =================
update_mtproxy() {
    cd /opt/MTProxy
    git pull
    make -j$(nproc)
    systemctl restart mtproxy
    info "MTProxy 已更新并重启"
}

# ================= 更改端口 =================
change_port() {
    read -r -p "请输入新的端口号 (留空自动选择): " new_port
    PORT=$(find_free_port "${new_port:-$DEFAULT_PORT}")
    sed -i -r "s/-p [0-9]+/-p $PORT/" /etc/systemd/system/mtproxy.service
    open_port "$PORT"
    systemctl daemon-reload
    systemctl restart mtproxy
    info "端口已修改为 $PORT"
}

# ================= 更改 secret =================
change_secret() {
    SECRET=$(openssl rand -hex 32)
    echo -n "$SECRET" > "$SECRET_FILE"
    sed -i -r "s/-S [0-9a-f]{64}/-S $SECRET/" /etc/systemd/system/mtproxy.service
    systemctl daemon-reload
    systemctl restart mtproxy
    info "Secret 已更新"
}

# ================= 卸载 =================
uninstall_mtproxy() {
    systemctl stop mtproxy || true
    systemctl disable mtproxy || true
    rm -f /etc/systemd/system/mtproxy.service
    rm -rf /opt/MTProxy "$DATA_DIR"
    systemctl daemon-reload
    info "MTProxy 已卸载"
}

# ================= 查看信息 =================
show_info() {
    if [ -f "$SECRET_FILE" ]; then
        SECRET=$(cat "$SECRET_FILE")
    fi
    IP=$(public_ip)
    PROXY_LINK="tg://proxy?server=${IP}&port=${PORT}&secret=${SECRET}"
    TME_LINK="https://t.me/proxy?server=${IP}&port=${PORT}&secret=${SECRET}"
    info "————— Telegram MTProto 代理 信息 —————"
    echo "IP: $IP"
    echo "端口: $PORT"
    echo "secret: $SECRET"
    echo
    echo "tg:// 链接:"
    echo "$PROXY_LINK"
    echo
    echo "t.me 分享链接:"
    echo "$TME_LINK"
    echo "———————————————————————————————"
}

# ================= 查看日志 =================
show_logs() {
    tail -f "$LOG_FILE"
}

# ================= 菜单 =================
menu() {
    while :; do
        echo "请选择操作："
        echo " 1) 安装"
        echo " 2) 更新"
        echo " 3) 卸载"
        echo " 4) 查看信息"
        echo " 5) 更改端口"
        echo " 6) 更改 secret"
        echo " 7) 查看日志"
        echo " 8) 退出"
        read -r -p "请输入选项 [1-8]: " choice
        case "$choice" in
            1) install_mtproxy ;;
            2) update_mtproxy ;;
            3) uninstall_mtproxy ;;
            4) show_info ;;
            5) change_port ;;
            6) change_secret ;;
            7) show_logs ;;
            8) exit 0 ;;
            *) warn "输入无效，请重新输入" ;;
        esac
    done
}

menu
