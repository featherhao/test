#!/bin/bash
###
# MTProto IPv6 + Cloudflare Tunnel 一键安装脚本
# Author: ChatGPT
# Date: 2025-09-28
###

set -Eeuo pipefail

# 彩色输出
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

info()  { echo -e "${green}[INFO]${plain} $*"; }
warn()  { echo -e "${yellow}[WARN]${plain} $*"; }
error() { echo -e "${red}[ERROR]${plain} $*"; }

[[ $EUID -ne 0 ]] && error "请使用 root 用户运行" && exit 1

# 检查 IPv6 可用性
if ! ping6 -c1 ipv6.google.com &>/dev/null; then
    warn "检测不到 IPv6 连接，确保 VPS 支持 IPv6 或使用 Cloudflare Tunnel 转发"
fi

# 安装 mtg
install_mtg(){
    info "安装 MTProto mtg"
    bit=$(uname -m)
    [[ "$bit" == "x86_64" ]] && bit="amd64"
    [[ "$bit" == "aarch64" ]] && bit="arm64"
    last_ver=$(curl -Ls "https://api.github.com/repos/9seconds/mtg/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    version=${last_ver#v}
    wget -N --no-check-certificate "https://github.com/9seconds/mtg/releases/download/${last_ver}/mtg-${version}-linux-${bit}.tar.gz"
    tar -xzf mtg-${version}-linux-${bit}.tar.gz
    mv mtg-${version}-linux-${bit}/mtg /usr/bin/mtg
    chmod +x /usr/bin/mtg
    rm -rf mtg-${version}-linux-${bit} mtg-${version}-linux-${bit}.tar.gz
    info "mtg 安装完成"
}

# 配置 mtg
configure_mtg(){
    info "配置 MTProto IPv6"
    wget -N --no-check-certificate -O /etc/mtg6.toml https://raw.githubusercontent.com/missuo/MTProxy/main/mtg.toml

    read -p "请输入伪装域名 (默认 itunes.apple.com): " domain
    [ -z "$domain" ] && domain="itunes.apple.com"

    read -p "请输入监听端口 (默认 8443): " port
    [ -z "$port" ] && port="8443"

    secret=$(mtg generate-secret --hex $domain)
    sed -i "s/secret.*/secret = \"${secret}\"/g" /etc/mtg6.toml
    sed -i "s/bind-to.*/bind-to = \"[::]:${port}\"/g" /etc/mtg6.toml
}

# 安装 systemd 服务
install_service(){
    wget -N --no-check-certificate -O /etc/systemd/system/mtg6.service https://raw.githubusercontent.com/missuo/MTProxy/main/mtg.service
    sed -i 's/ExecStart=.*/ExecStart=\/usr\/bin\/mtg run \/etc\/mtg6.toml/g' /etc/systemd/system/mtg6.service
    systemctl daemon-reload
    systemctl enable mtg6
    systemctl start mtg6
    info "MTProto IPv6 已启动"
}

# 安装 cloudflared
install_cloudflared(){
    if ! command -v cloudflared &>/dev/null; then
        info "安装 cloudflared"
        curl -fsSL https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -o /usr/local/bin/cloudflared
        chmod +x /usr/local/bin/cloudflared
    fi
}

# Cloudflare Tunnel 配置
configure_tunnel(){
    if [[ ! -f /root/.cloudflared/cert.pem ]]; then
        warn "Cloudflare Tunnel 首次运行需要登录"
        echo -e "${yellow}请复制以下 URL 到本地浏览器完成登录:${plain}"
        cloudflared tunnel login
    fi

    TUNNEL_NAME="mtproto-ipv6"
    if ! cloudflared tunnel list | grep -q "$TUNNEL_NAME"; then
        cloudflared tunnel create $TUNNEL_NAME
    fi

    IPV6_ADDR=$(ip -6 addr show scope global | grep inet6 | awk '{print $2}' | cut -d/ -f1 | head -n1)

    cat >/root/.cloudflared/config.yml <<EOF
tunnel: $TUNNEL_NAME
credentials-file: /root/.cloudflared/$(ls /root/.cloudflared | grep json | head -n1)

ingress:
  - hostname: tg.yourdomain.com
    service: tcp://[${IPV6_ADDR}]:${port}
  - service: http_status:404
EOF

    systemctl stop cloudflared 2>/dev/null || true
    cloudflared service install
    systemctl enable cloudflared
    systemctl restart cloudflared
}

# 输出信息
show_final_info(){
    echo -e "${green}部署完成！${plain}"
    echo -e "IPv6 地址: [${IPV6_ADDR}]"
    echo -e "MTProto Secret: ${secret}"
    echo -e "TG 链接 (IPv6): tg://proxy?server=[${IPV6_ADDR}]&port=${port}&secret=${secret}"
    echo -e "TG 链接 (域名+Tunnel): tg://proxy?server=tg.yourdomain.com&port=${port}&secret=${secret}"
    echo -e "${yellow}注意事项:${plain}"
    echo -e "1. IPv4 客户端请使用绑定域名 + Cloudflare Tunnel"
    echo -e "2. IPv6 客户端可直接使用 IPv6 链接"
    echo -e "3. IPv6 地址必须加方括号 [ ]"
}

main(){
    install_mtg
    configure_mtg
    install_service
    install_cloudflared
    configure_tunnel
    show_final_info
}

main
