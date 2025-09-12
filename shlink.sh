#!/bin/bash
set -e

# =====================
# 基础配置
# =====================
CONFIG_FILE="./shlink.conf"

GREEN="\033[0;32m"
RED="\033[0;31m"
NC="\033[0m"

# =====================
# 读取配置文件
# =====================
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
fi

# =====================
# 显示状态
# =====================
display_status() {
    echo
    echo "--- Shlink 已安装 ---"
    local backend_status=$(docker inspect -f '{{.State.Status}}' shlink 2>/dev/null || echo "not running")
    local frontend_status=$(docker inspect -f '{{.State.Status}}' shlink-web-client 2>/dev/null || echo "not running")

    echo -e "Shlink 后端状态: ${GREEN}${backend_status}${NC}"
    echo -e "Shlink 前端状态: ${GREEN}${frontend_status}${NC}"

    if [ -n "$DEFAULT_DOMAIN" ]; then
        echo -e "访问地址：http://${DEFAULT_DOMAIN}:${FRONTEND_PORT}"
        echo -e "后端API地址：http://${DEFAULT_DOMAIN}:${BACKEND_PORT}"
    else
        echo -e "访问地址：${RED}未设置域名/IP${NC}"
    fi

    if [ -n "$API_KEY" ]; then
        echo -e "Shlink API Key：${GREEN}${API_KEY}${NC}"
    else
        local api_key=$(docker exec shlink shlink api-key:list --no-interaction 2>/dev/null | grep -oP '^[0-9a-f-]{36}' | head -n 1)
        if [ -n "$api_key" ]; then
            echo -e "Shlink API Key：${GREEN}${api_key}${NC}"
        else
            echo -e "Shlink API Key：${RED}获取失败，请运行 docker exec shlink shlink api-key:list${NC}"
        fi
    fi
    echo
}

# =====================
# 安装 Shlink
# =====================
install_shlink() {
    echo "测到 IPv4 和 IPv6 地址："
    IPV4=$(curl -s ipv4.ip.sb || echo "未检测到")
    IPV6=$(curl -s ipv6.ip.sb || echo "未检测到")
    echo "  1) IPv4: $IPV4"
    echo "  2) IPv6: $IPV6"
    read -p "请选择一个作为默认访问地址 (回车默认使用 IPv4): " choice

    if [ "$choice" == "2" ] && [ "$IPV6" != "未检测到" ]; then
        DEFAULT_DOMAIN="[$IPV6]"
    else
        DEFAULT_DOMAIN="$IPV4"
    fi

    read -p "请设置 Shlink 后端访问端口 (回车默认 9040): " BACKEND_PORT
    BACKEND_PORT=${BACKEND_PORT:-9040}

    read -p "请设置 Shlink 前端访问端口 (回车默认 9050): " FRONTEND_PORT
    FRONTEND_PORT=${FRONTEND_PORT:-9050}

    echo
    echo "--- 部署配置确认 ---"
    echo "公网IP/域名: $DEFAULT_DOMAIN"
    echo "后端端口: $BACKEND_PORT"
    echo "前端端口: $FRONTEND_PORT"
    read -n 1 -s -r -p "请确认配置无误后按任意键继续... (Ctrl+C 取消)"
    echo

    echo
    echo "--- 正在部署 Shlink 后端 (Server)... ---"
    docker run -d --name shlink --restart unless-stopped \
        -p ${BACKEND_PORT}:8080 \
        -e DEFAULT_DOMAIN=$DEFAULT_DOMAIN \
        -e IS_HTTPS_ENABLED=false \
        shlinkio/shlink:stable

    echo "Shlink 后端部署成功！"

    echo
    echo "正在运行数据库迁移..."
    docker exec shlink shlink db:migrate
    echo "数据库迁移完成！"

    echo
    echo "正在生成 API Key..."
    API_KEY=$(docker exec shlink shlink api-key:generate --no-interaction | grep -oP '^[0-9a-f-]{36}' | head -n 1)
    echo "API Key 已生成：\"$API_KEY\""

    echo
    echo "--- 正在部署 Shlink 前端 (Web-Client)... ---"
    docker run -d --name shlink-web-client --restart unless-stopped \
        -p ${FRONTEND_PORT}:80 \
        -e SHLINK_SERVER_URL="http://${DEFAULT_DOMAIN}:${BACKEND_PORT}" \
        -e SHLINK_SERVER_API_KEY="$API_KEY" \
        shlinkio/shlink-web-client:stable

    echo "Shlink 前端部署成功！"

    # 保存配置
    echo "DEFAULT_DOMAIN=$DEFAULT_DOMAIN" > $CONFIG_FILE
    echo "BACKEND_PORT=$BACKEND_PORT" >> $CONFIG_FILE
    echo "FRONTEND_PORT=$FRONTEND_PORT" >> $CONFIG_FILE
    echo "API_KEY=$API_KEY" >> $CONFIG_FILE

    echo
    echo "--- 部署完成！ ---"
    display_status
}

# =====================
# 主菜单
# =====================
main_menu() {
    clear
    echo "===== Shlink 管理脚本 ====="
    echo "1. 安装 Shlink"
    echo "2. 查看状态"
    echo "0. 退出"
    read -p "请选择操作: " num

    case "$num" in
        1) install_shlink ;;
        2) display_status ;;
        0) exit 0 ;;
        *) echo "无效选择";;
    esac
}

main_menu
