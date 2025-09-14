#!/bin/bash
set -e

WORKDIR="/opt/shlink"
COMPOSE_FILE="$WORKDIR/docker-compose.yml"

menu() {
    clear
    echo "============================"
    echo " Shlink 短链服务管理脚本"
    echo "============================"
    echo "1) 安装 Shlink 服务"
    echo "2) 卸载 Shlink 服务"
    echo "3) 更新 Shlink 服务"
    echo "4) 查看服务信息"
    echo "0) 退出"
    echo "----------------------------"
    read -p "请输入选项: " choice

    case "$choice" in
        1) install_shlink ;;
        2) uninstall_shlink ;;
        3) update_shlink ;;
        4) info_shlink ;;
        0) exit 0 ;;
        *) echo "无效选项，请重新输入" && sleep 2 && menu ;;
    esac
}

install_shlink() {
    echo "--- 开始部署 Shlink 短链服务 ---"
    mkdir -p "$WORKDIR"

    # 删除旧容器和旧网络
    docker rm -f shlink_web_client shlink 2>/dev/null || true
    docker compose -f "$COMPOSE_FILE" down -v 2>/dev/null || true

    read -p "请输入短网址服务 API 域名 (例如: api.q.qqy.pp.ua): " API_DOMAIN
    read -p "请输入 Web Client 域名 (例如: q.qqy.pp.ua): " CLIENT_DOMAIN
    read -p "请输入 Shlink API 端口 [默认: 9040]: " API_PORT
    API_PORT=${API_PORT:-9040}
    read -p "请输入 Web Client 端口 [默认: 9050]: " CLIENT_PORT
    CLIENT_PORT=${CLIENT_PORT:-9050}
    read -p "请输入 GeoLite2 License Key (可选，留空则不启用): " GEO_KEY

    # 生成 docker-compose.yml
    cat > "$COMPOSE_FILE" <<EOF
version: "3.9"
services:
  shlink_db:
    image: postgres:15
    container_name: shlink_db
    restart: always
    environment:
      POSTGRES_USER: shlink
      POSTGRES_PASSWORD: shlinkpass
      POSTGRES_DB: shlink
    volumes:
      - db_data:/var/lib/postgresql/data
    networks:
      - shlink_net

  shlink:
    image: shlinkio/shlink:stable
    container_name: shlink
    restart: always
    depends_on:
      - shlink_db
    environment:
      DEFAULT_DOMAIN: "$API_DOMAIN"
      IS_HTTPS_ENABLED: "true"
      GEOLITE_LICENSE_KEY: "$GEO_KEY"
      DB_DRIVER: "postgres"
      DB_USER: "shlink"
      DB_PASSWORD: "shlinkpass"
      DB_HOST: "shlink_db"
      DB_NAME: "shlink"
    ports:
      - "0.0.0.0:$API_PORT:8080"
    networks:
      - shlink_net

networks:
  shlink_net:
    driver: bridge

volumes:
  db_data:
EOF

    echo "--- 启动 Shlink API 和数据库 ---"
    docker compose -f "$COMPOSE_FILE" up -d shlink_db shlink

    echo "--- 等待 Shlink API 就绪（最多 60 秒）---"
    READY=0
    for i in {1..30}; do
        if docker exec shlink shlink api-key:generate &>/dev/null; then
            READY=1
            break
        else
            echo "等待 API 启动..."
            sleep 2
        fi
    done

    if [ $READY -ne 1 ]; then
        echo "Shlink API 启动失败，请检查容器日志"
        docker logs shlink
        exit 1
    fi

    echo "--- 生成 API Key ---"
    API_KEY=$(docker exec shlink shlink api-key:generate | grep -oE '[0-9a-f-]{36}' | head -n1)
    echo "生成 API Key: $API_KEY"

    echo "--- 启动 Web Client ---"
    docker rm -f shlink_web_client 2>/dev/null || true
    docker run -d \
      --name shlink_web_client \
      -p ${CLIENT_PORT}:80 \
      -e SHLINK_SERVER_URL="http://$API_DOMAIN:$API_PORT" \
      -e SHLINK_SERVER_API_KEY="$API_KEY" \
      --network shlink_net \
      --restart always \
      shlinkio/shlink-web-client:stable

    # 获取宿主机 IP
    IPV4=$(curl -s https://ipinfo.io/ip)
    IPV6=$(ip -6 addr show scope global | grep inet6 | awk '{print $2}' | cut -d/ -f1 | head -n1)

    echo "============================"
    echo " Shlink 部署完成！"
    echo "API Key: $API_KEY"
    echo ""
    echo "访问方式："
    echo "本机访问:"
    echo "  - API: http://localhost:$API_PORT"
    echo "  - Web: http://localhost:$CLIENT_PORT"
    echo "域名访问:"
    echo "  - API: http://$API_DOMAIN:$API_PORT"
    echo "  - Web: http://$CLIENT_DOMAIN:$CLIENT_PORT"
    echo "IPv4访问:"
    echo "  - API: http://$IPV4:$API_PORT"
    echo "  - Web: http://$IPV4:$CLIENT_PORT"
    [[ -n "$IPV6" ]] && echo "IPv6访问:"
    [[ -n "$IPV6" ]] && echo "  - API: http://[$IPV6]:$API_PORT"
    [[ -n "$IPV6" ]] && echo "  - Web: http://[$IPV6]:$CLIENT_PORT"
    echo "============================"

    read -p "按回车键返回菜单..."
    menu
}

uninstall_shlink() {
    echo "--- 卸载 Shlink 服务 ---"
    docker rm -f shlink_web_client shlink 2>/dev/null || true
    docker compose -f "$COMPOSE_FILE" down -v 2>/dev/null || true
    rm -rf "$WORKDIR"
    echo "Shlink 已卸载"
    read -p "按回车键返回菜单..."
    menu
}

update_shlink() {
    echo "--- 更新 Shlink 服务 ---"
    docker compose -f "$COMPOSE_FILE" pull
    docker compose -f "$COMPOSE_FILE" up -d
    echo "Shlink 已更新"
    read -p "按回车键返回菜单..."
    menu
}

info_shlink() {
    echo "--- Shlink 服务信息 ---"
    docker ps --filter "name=shlink" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    docker ps --filter "name=shlink_web_client" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    read -p "按回车键返回菜单..."
    menu
}

menu
