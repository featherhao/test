#!/bin/bash
set -Eeuo pipefail

# ================== 基础配置 ==================
SERVICE_NAME="mtproxy"
MTBIN="/usr/local/bin/mtproto-proxy"
WORKDIR="/etc/mtproxy"

# ================== 系统判断 ==================
if [[ -f /etc/os-release ]]; then
    . /etc/os-release
else
    echo "无法识别系统类型"
    exit 1
fi

# ================== 公用函数 ==================
gen_secret() {
    openssl rand -hex 16
}

show_info() {
    local ip=$(curl -s ifconfig.me || echo "0.0.0.0")
    local port=$(cat "$WORKDIR/port" 2>/dev/null || echo "6688")
    local secret=$(cat "$WORKDIR/secret" 2>/dev/null || echo "none")
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

# ================== Alpine 部署 ==================
install_alpine() {
    echo "正在安装依赖..."
    apk add --no-cache curl openssl su-exec

    mkdir -p "$WORKDIR"

    echo "正在下载 MTProxy 二进制..."
    curl -L -o "$MTBIN" https://github.com/TelegramMessenger/MTProxy/releases/download/v0.01/mtproto-proxy
    chmod +x "$MTBIN"

    # 生成 secret
    local secret=$(gen_secret)
    echo "$secret" > "$WORKDIR/secret"

    # 让用户输入母机外部端口
    echo -n "请输入母机映射的外部端口（例如 10000）: "
    read port
    echo "$port" > "$WORKDIR/port"

    # 写 OpenRC 服务
    cat >/etc/init.d/$SERVICE_NAME <<EOF
#!/sbin/openrc-run
command="$MTBIN"
command_args="-u nobody -p 0.0.0.0:6688 -S $secret --aes-pwd $WORKDIR/proxy-secret $WORKDIR/proxy-multi.conf -M 1"
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

# ================== Ubuntu/Debian 部署 ==================
install_debian() {
    echo "正在安装依赖..."
    apt-get update -y
    apt-get install -y docker.io openssl curl

    mkdir -p "$WORKDIR"
    local secret=$(gen_secret)
    echo "$secret" > "$WORKDIR/secret"
    local port=6688
    echo "$port" > "$WORKDIR/port"

    docker rm -f tg-mtproxy >/dev/null 2>&1 || true

    docker run -d --name tg-mtproxy --restart always \
        -p ${port}:443 \
        -v $WORKDIR:/data \
        telegrammessenger/proxy:latest \
        -p 443 -H 443 -S $secret

    show_info
}

# ================== 主菜单 ==================
menu() {
    clear
    echo "=============================="
    echo "   Telegram MTProto 管理菜单"
    echo "=============================="
    echo " 1) 安装"
    echo " 2) 更新"
    echo " 3) 卸载"
    echo " 4) 查看信息"
    echo " 5) 退出"
    echo "=============================="
    echo -n "请输入选项 [1-5]: "
    read choice

    case $choice in
        1)
            case "$ID" in
                alpine) install_alpine ;;
                ubuntu|debian) install_debian ;;
                *) echo "暂不支持此系统: $ID" ;;
            esac
            ;;
        2)
            echo "更新功能待实现"
            ;;
        3)
            if [[ "$ID" == "alpine" ]]; then
                rc-service $SERVICE_NAME stop || true
                rc-update del $SERVICE_NAME default || true
                rm -f /etc/init.d/$SERVICE_NAME $MTBIN
            else
                docker rm -f tg-mtproxy || true
            fi
            rm -rf "$WORKDIR"
            echo "已卸载完成"
            ;;
        4) show_info ;;
        5) exit 0 ;;
        *) echo "无效选项" ;;
    esac
}

menu
