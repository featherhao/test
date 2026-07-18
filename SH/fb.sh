#!/bin/bash

INSTALL_DIR="$HOME/filebrowser"
APP_NAME="filebrowser"
DEFAULT_PORT=8002

# 获取可用端口（如果占用则自动递增）
get_available_port() {
    local port=$DEFAULT_PORT
    while lsof -Pi :$port -sTCP:LISTEN -t >/dev/null ; do
        echo "端口 $port 已被占用，尝试使用 $((port + 1))..."
        port=$((port + 1))
    done
    echo $port
}

PORT=$(get_available_port)

install() {
    echo "--- 正在初始化目录 (端口: $PORT) ---"
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

    echo "--- 启动容器 ---"
    docker compose up -d
    
    echo "=================================================="
    echo "安装成功！"
    echo "访问地址: http://服务器IP:$PORT"
    show_credentials
    echo "=================================================="
}

show_credentials() {
    if [ "$(docker ps -q -f name=$APP_NAME)" ]; then
        echo "当前配置端口: $PORT"
        echo "默认用户名: admin"
        echo "初始密码日志如下:"
        docker logs $APP_NAME 2>&1 | grep "password" | tail -n 1
    else
        echo "容器未运行，请先执行 install。"
    fi
}

uninstall() {
    echo "--- 正在停止并删除容器 ---"
    if [ -d "$INSTALL_DIR" ]; then
        cd "$INSTALL_DIR" || exit
        docker compose down
        echo "是否删除数据文件？(y/n)"
        read -r confirm
        if [ "$confirm" == "y" ]; then
            rm -rf "$INSTALL_DIR"
            echo "所有数据已彻底清除。"
        fi
    fi
}

# 交互式菜单
echo "--- FileBrowser 管理工具 ---"
echo "1) 安装 / 更新"
echo "2) 卸载"
echo "3) 查看账户信息"
read -p "请选择 [1-3]: " choice

case "$choice" in
    1) install ;;
    2) uninstall ;;
    3) show_credentials ;;
    *) echo "无效选择" ;;
esac
