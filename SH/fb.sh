#!/bin/bash
INSTALL_DIR="$HOME/filebrowser"
APP_NAME="filebrowser"

get_port() {
    if [ -f "$INSTALL_DIR/docker-compose.yml" ]; then
        grep "ports:" -A 1 "$INSTALL_DIR/docker-compose.yml" | grep -oE '[0-9]+' | head -n 1
    else
        echo "8002"
    fi
}

install() {
    local PORT=$(get_port)
    mkdir -p "$INSTALL_DIR/data" "$INSTALL_DIR/config" "$INSTALL_DIR/database"
    cd "$INSTALL_DIR" || exit
    cat <<EOF > docker-compose.yml
services:
  filebrowser:
    image: filebrowser/filebrowser:s6
    container_name: $APP_NAME
    restart: always
    ports:
      - "$PORT:80"
    volumes:
      - ./data:/srv
      - ./config:/config
      - ./database:/database
    environment:
      - PUID=$(id -u)
      - PGID=$(id -g)
EOF
    docker compose up -d
    echo "--- 已尝试安装/更新，端口为 $PORT ---"
}

show_info() {
    local PORT=$(get_port)
    echo -e "\n=================================================="
    echo "访问地址: http://$(hostname -I | awk '{print $1}'):$PORT"
    echo "用户名: admin"
    echo -n "初始密码: "
    docker logs $APP_NAME 2>&1 | grep "password" | tail -n 1 | awk -F'password: ' '{print $2}'
    echo -e "=================================================="
}

uninstall() {
    cd "$INSTALL_DIR" && docker compose down
    echo "是否删除所有数据？(y/n)"
    read -r ans
    [ "$ans" == "y" ] && rm -rf "$INSTALL_DIR" && echo "已删除数据。"
}

# 子菜单循环
while true; do
    echo -e "\n--- FileBrowser 管理子菜单 ---"
    echo "1) 安装 / 更新"
    echo "2) 查看密码"
    echo "3) 卸载"
    echo "0) 返回主菜单"
    read -rp "请选择: " choice
    case "$choice" in
        1) install ;;
        2) show_info ;;
        3) uninstall ;;
        0) break ;;
        *) echo "无效选择" ;;
    esac
done
