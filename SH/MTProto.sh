#!/bin/bash
set -Eeuo pipefail

# ================== 基础配置 ==================
SERVICE_NAME="mtproxy"
WORKDIR="/etc/mtproxy"
MTBIN="$WORKDIR/mtproto-proxy"

# ================== 系统判断 ==================
if [[ -f /etc/os-release ]]; then
    . /etc/os-release
else
    echo "无法识别系统类型"
    exit 1
fi

# ================== 公共函数 ==================
gen_secret() {
    openssl rand -hex 16
}

show_info() {
    local ip
    ip=$(curl -s ifconfig.me || echo "0.0.0.0")
    local port
    port=$(cat "$WORKDIR/port" 2>/dev/null || echo "6688")
    local secret
    secret=$(cat "$WORKDIR/secret" 2>/dev/null || echo "none")
    echo
    echo "————— Telegram MTProto 代理 信息 —————"
    echo "IP:       $ip"
    echo "端口:     $port"
    echo "secret:   $secret"
    echo
    echo "tg:// 链接:"
    echo "tg://proxy?server=$ip&port=$port&secret=dd$secret"
    echo
    echo "t.me 分享链接:"
    echo "https://t.me/proxy?server=$ip&port=$port&secret=dd$secret"
    echo "————————————————————————————"
}

# ================== Alpine 安装 ==================
install_alpine() {
    echo "正在安装依赖..."
    apk add --no-cache curl openssl su-exec

    mkdir -p "$WORKDIR"

    echo "正在下载 MTProxy 二进制..."
    curl -L -o "$MTBIN" https://github.com/TelegramMessenger/MTProxy/releases/download/v0.01/mtproto-proxy
    chmod +x "$MTBIN"

    # 生成 secret
    local secret
    secret=$(gen_secret)
    echo "$secret" > "$WORKDIR/secret"

    # 内部监听端口固定 6688
    local PORT=6688
    echo "$PORT" > "$WORKDIR/port"

    # 写 OpenRC 服务
    cat >/etc/init.d/$SERVICE_NAME <<EOF
#!/sbin/openrc-run
command="$MTBIN"
command_args="-u nobody -p 0.0.0.0:$PORT -S $secret --aes-pwd $WORKDIR/proxy-secret $WORKDIR/proxy-multi.conf -M 1"
command_background="yes"
pidfile="/var/run/$SERVICE_NAME.pid"
depend() {
    need net
}
EOF
    chmod +x /etc/init.d/$SERVICE_NAME
    rc-update add $SERVICE_NAME default
    rc-service $SERVICE_NAME restart

    show_info
}

# ================== Ubuntu/Debian 安装 ==================
install_debian() {
    echo "检查 Docker 是否已安装..."
    if ! command -v docker >/dev/null 2>&1; then
        echo "Docker 未安装，正在安装..."
        apt-get update -y
        apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list
        apt-get update -y
        apt-get install -y docker-ce docker-ce-cli containerd.io
        systemctl enable docker
        systemctl start docker
    else
        echo "检测到 Docker 已安装"
    fi

    mkdir -p "$WORKDIR"
    local secret
    secret=$(gen_secret)
    echo "$secret" > "$WORKDIR/secret"
    local port=6688
    echo "$port" > "$WORKDIR/port"

    docker rm -f tg-mtproxy >/dev/null 2>&1 || true

    docker run -d --name tg-mtproxy --restart always \
        -p ${port}:443 \
        -v $WORKDIR:/data \
        telegrammessenger/proxy:latest \
        -S $secret --aes-pwd /data/proxy-secret /data/proxy-multi.conf -M 1

    show_info
}

# ================== 修改 secret ==================
change_secret() {
    load_conf
    local SECRET
    SECRET=$(gen_secret)
    echo "$SECRET" > "$WORKDIR/secret"

    if [[ "$ID" == "alpine" ]]; then
        rc-service $SERVICE_NAME restart
    else
        docker stop tg-mtproxy
        docker rm tg-mtproxy
        docker run -d --name tg-mtproxy --restart always \
            -p 6688:443 \
            -v $WORKDIR:/data \
            telegrammessenger/proxy:latest \
            -S $SECRET --aes-pwd /data/proxy-secret /data/proxy-multi.conf -M 1
    fi
    show_info
}

# ================== 读配置 ==================
load_conf() {
    [ -f "$WORKDIR/port" ] && PORT=$(cat "$WORKDIR/port")
    [ -f "$WORKDIR/secret" ] && SECRET=$(cat "$WORKDIR/secret")
}

# ================== 卸载 ==================
uninstall() {
    if [[ "$ID" == "alpine" ]]; then
        rc-service $SERVICE_NAME stop || true
        rc-update del $SERVICE_NAME default || true
        rm -f /etc/init.d/$SERVICE_NAME $MTBIN
    else
        docker rm -f tg-mtproxy || true
    fi
    rm -rf "$WORKDIR"
    echo "已卸载完成"
}

# ================== 菜单 ==================
while true; do
    echo
    echo "=============================="
    echo "   Telegram MTProto 管理菜单"
    echo "=============================="
    echo " 1) 安装"
    echo " 2) 卸载"
    echo " 3) 查看信息"
    echo " 4) 修改 secret"
    echo " 0) 退出"
    echo "=============================="
    echo -n "请输入选项 [0-4]: "
    read choice

    case $choice in
        1)
            case "$ID" in
                alpine) install_alpine ;;
                ubuntu|debian) install_debian ;;
                *) echo "暂不支持此系统: $ID" ;;
            esac
            ;;
        2) uninstall ;;
        3) show_info ;;
        4) change_secret ;;
        0) exit 0 ;;
        *) echo "无效选项" ;;
    esac
done
