#!/bin/bash

# 配置参数
INSTALL_DIR="$HOME/filebrowser"
APP_NAME="filebrowser"

# 检查是否安装了 Docker
if ! command -v docker &> /dev/null; then
    echo "未检测到 Docker，请先安装 Docker。"
    exit 1
fi

# 安装函数
install() {
    echo "--- 正在初始化目录 ---"
    mkdir -p "$INSTALL_DIR/data" "$INSTALL_DIR/config" "$INSTALL_DIR/database"
    cd "$INSTALL_DIR" || exit

    echo "--- 创建 docker-compose.yml ---"
    cat <<EOF > docker-compose.yml
version: '3'
services:
  filebrowser:
    image: filebrowser/filebrowser:s6
    container_name: $APP_NAME
    restart: always
    ports:
      - "8001:80"
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
    echo "访问地址: http://服务器IP:8001"
    echo "初始密码查找方法: 查看下方日志或运行: docker logs $APP_NAME"
    echo "=================================================="
    sleep 2
    docker logs $APP_NAME 2>&1 | grep "password"
}

# 卸载函数
uninstall() {
    echo "--- 正在停止并删除容器 ---"
    cd "$INSTALL_DIR" || exit
    docker compose down
    
    echo "--- 是否删除所有数据 (data/config/database)？(y/n) ---"
    read -r confirm
    if [ "$confirm" == "y" ]; then
        rm -rf "$INSTALL_DIR"
        echo "所有数据已删除。"
    else
        echo "容器已清理，数据目录保留在 $INSTALL_DIR"
    fi
    echo "卸载完成。"
}

# 菜单逻辑
case "$1" in
    install)
        install
        ;;
    uninstall)
        uninstall
        ;;
    *)
        echo "用法: $0 {install|uninstall}"
        exit 1
        ;;
esac
