#!/bin/bash

# ====================================================
# 脚本路径: /usr/local/bin/dkproxy
# 脚本功能: 一键开启/关闭 Docker 全局代理 (永久生效)
# ====================================================
# 【使用方法说明】
# 1. 开启 Docker 代理 (用于解决 docker pull 镜像拉不动):
#    dkproxy on
#
# 2. 关闭 Docker 代理 (恢复官方源直连拉取):
#    dkproxy off
#
# 【联动说明】
# 此脚本被 `/usr/local/bin/tool` 手册脚本调用，用于展示状态。
# ====================================================

# 配置变量
PROXY_ADDR="192.168.51.88:7890"
CONF_PATH="/etc/systemd/system/docker.service.d/http-proxy.conf"
CONF_DIR="/etc/systemd/system/docker.service.d"

toggle_proxy() {
    if [ "$1" == "on" ]; then
        sudo mkdir -p "$CONF_DIR"
        sudo bash -c "cat > $CONF_PATH <<EOF
[Service]
Environment=\"HTTP_PROXY=http://$PROXY_ADDR\"
Environment=\"HTTPS_PROXY=http://$PROXY_ADDR\"
Environment=\"NO_PROXY=localhost,127.0.0.1,192.168.51.0/24,status.moontv.top\"
EOF"
        echo "✅ Docker 代理已开启 -> $PROXY_ADDR"
    else
        if [ -f "$CONF_PATH" ]; then
            sudo rm "$CONF_PATH"
        fi
        echo "❌ Docker 代理已关闭"
    fi

    # 重启服务使生效
    sudo systemctl daemon-reload
    sudo systemctl restart docker
    echo "🔄 Docker 服务已重载"
}

case "$1" in
    on)  toggle_proxy "on" ;;
    off) toggle_proxy "off" ;;
    *)   echo "使用方法: dkproxy on | dkproxy off" ;;
esac
