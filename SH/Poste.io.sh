#!/bin/bash
set -Eeuo pipefail

# ==============================================================================
# Poste.io 安装/卸载/更新管理脚本 (交互式菜单版)
# 作者：AI助手
# ------------------------------------------------------------------------------
# 脚本使用说明：
# 直接运行脚本即可，通过菜单进行安装、卸载或更新操作。
# ==============================================================================

# 定义变量
COMPOSE_FILE="docker-compose.yml"
DATA_DIR="./posteio_data"
# 新增：定义正确的镜像名称，方便统一修改
POSTEIO_IMAGE="docker.io/posteio/posteio:latest"

# 统一失败处理
trap 'status=$?; line=${BASH_LINENO[0]}; echo "❌ 发生错误 (exit=$status) at line $line" >&2; exit $status' ERR

# 检查依赖项
check_dependencies() {
    if ! command -v docker &> /dev/null; then
        echo "错误：未安装 Docker。请先安装 Docker。"
        exit 1
    fi
    if ! command -v docker-compose &> /dev/null; then
        echo "错误：未安装 Docker Compose。请先安装 Docker Compose。"
        echo "你可以使用以下命令安装：sudo apt-get install docker-compose"
        exit 1
    fi
}

# 生成 Docker Compose 文件，使用正确的、可公开访问的镜像名称
generate_compose_file() {
    cat > "$COMPOSE_FILE" << EOF
services:
  posteio:
    image: ${POSTEIO_IMAGE}
    container_name: poste.io
    restart: always
    hostname: mailserver.example.com  # <-- 请修改为你的域名
    ports:
      - "25:25"
      - "80:80"
      - "110:110"
      - "143:143"
      - "443:443"
      - "465:465"
      - "587:587"
      - "993:993"
      - "995:995"
    volumes:
      - "$DATA_DIR:/data"
EOF
    echo "已生成 Docker Compose 文件：$COMPOSE_FILE"
}

# 安装 Poste.io
install_poste() {
    echo "=== 开始安装 Poste.io ==="
    check_dependencies

    # 强制删除旧的配置文件，避免任何缓存或旧文件问题
    if [ -f "$COMPOSE_FILE" ]; then
        echo "警告：检测到旧的 Docker Compose 文件，正在自动删除..."
        rm "$COMPOSE_FILE"
    fi

    generate_compose_file

    echo "正在创建数据目录：$DATA_DIR"
    mkdir -p "$DATA_DIR"

    echo "正在启动 Poste.io 容器..."
    # 使用 --pull always 确保强制拉取最新镜像
    docker-compose up -d --pull always

    if [ $? -eq 0 ]; then
        echo "恭喜！Poste.io 安装成功！"
        echo "请将 $COMPOSE_FILE 中的 'mailserver.example.com' 替换为你的域名。"
        echo "然后重新运行：docker-compose up -d"
        echo "你可以在浏览器中访问你的服务器IP或域名来完成最后的设置。"
    else
        echo "安装失败，请检查上面的错误信息。"
    fi
}

# 卸载 Poste.io
uninstall_poste() {
    echo "=== 开始卸载 Poste.io ==="
    read -p "警告：卸载将永久删除所有容器、镜像和数据。你确定要继续吗？(y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "已取消卸载。"
        exit 1
    fi

    echo "正在停止和删除容器..."
    docker-compose down

    echo "正在删除 Docker Compose 文件和数据..."
    rm -rf "$COMPOSE_FILE" "$DATA_DIR"

    echo "卸载完成。"
}

# 更新 Poste.io
update_poste() {
    echo "=== 开始更新 Poste.io ==="
    check_dependencies
    
    if [ ! -f "$COMPOSE_FILE" ]; then
        echo "错误：找不到 Docker Compose 文件。请先执行安装。"
        exit 1
    fi

    echo "正在拉取最新的 Poste.io 镜像..."
    # 修复：使用完整的镜像名进行拉取
    docker-compose pull ${POSTEIO_IMAGE}

    echo "正在重新创建和启动容器..."
    docker-compose up -d

    if [ $? -eq 0 ]; then
        echo "Poste.io 已成功更新到最新版本！"
    else
        echo "更新失败，请检查上面的错误信息。"
    fi
}

# 菜单主逻辑
while true; do
    echo "=============================="
    echo "   Poste.io 管理菜单"
    echo "=============================="
    echo "1) 安装 Poste.io"
    echo "2) 卸载 Poste.io"
    echo "3) 更新 Poste.io"
    echo "0) 退出"
    echo "=============================="
    read -rp "请输入选项: " choice
    echo

    case "$choice" in
        1)
            install_poste
            break
            ;;
        2)
            uninstall_poste
            break
            ;;
        3)
            update_poste
            break
            ;;
        0)
            echo "退出脚本。"
            exit 0
            ;;
        *)
            echo "无效选项，请重新输入。"
            sleep 1
            ;;
    esac
done