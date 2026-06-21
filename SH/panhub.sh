#!/bin/bash

# ====================================================================
# 脚本名称: PanHub 一键安装与管理脚本
# 适用系统: Ubuntu / Debian / CentOS
# 功能描述: 自动化安装 Docker、部署 PanHub 容器、提供状态管理
# ====================================================================

# 颜色定义
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # 无颜色

# 配置变量
CONTAINER_NAME="panhub"
IMAGE_NAME="ghcr.io/wu529778790/panhub.shenzjd.com:latest"
DATA_DIR="/root/panhub/data"
DEFAULT_PORT="3000"

# 必须以 root 用户运行
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}错误: 必须使用 root 权限运行此脚本！${NC}"
    exit 1
fi

# 检测并安装 Docker
check_docker() {
    if ! command -v docker &> /dev/null; then
        echo -e "${YELLOW}未检测到 Docker，正在为您安装...${NC}"
        curl -fsSL https://get.docker.com | bash
        systemctl start docker
        systemctl enable docker
        echo -e "${GREEN}Docker 安装成功！${NC}"
    else
        echo -e "${GREEN}检测到 Docker 已安装。${NC}"
    fi
}

# 安装 PanHub
install_panhub() {
    check_docker

    # 如果容器已存在，先处理
    if [ "$(docker ps -aq -f name=^${CONTAINER_NAME}$)" ]; then
        echo -e "${YELLOW}检测到已存在名为 ${CONTAINER_NAME} 的容器。${NC}"
        read -p "是否删除旧容器并重新安装？(y/n): " choice
        if [[ "$choice" == [Yy] ]]; then
            docker rm -f $CONTAINER_NAME
        else
            echo -e "${BLUE}已取消安装。${NC}"
            exit 0
        fi
    fi

    # 用户自定义配置
    echo -e "${BLUE}=== 自定义配置 (直接回车使用默认值) ===${NC}"
    
    read -p "请输入映射端口 [默认: $DEFAULT_PORT]: " user_port
    PORT=${user_port:-$DEFAULT_PORT}

    read -p "是否启用访问密码？(直接回车不启用，输入密码则启用): " search_pwd
    SEARCH_PASSWORD=$search_pwd

    # 创建持久化目录
    mkdir -p "$DATA_DIR"

    echo -e "${YELLOW}正在拉取最新镜像并启动容器...${NC}"

    # 组装 Docker 运行命令
    if [ -z "$SEARCH_PASSWORD" ]; then
        docker run -d \
            --name "$CONTAINER_NAME" \
            -p "$PORT":3000 \
            -v "$DATA_DIR":/app/data \
            --restart always \
            "$IMAGE_NAME"
    else
        docker run -d \
            --name "$CONTAINER_NAME" \
            -p "$PORT":3000 \
            -v "$DATA_DIR":/app/data \
            -e SEARCH_PASSWORD="$SEARCH_PASSWORD" \
            --restart always \
            "$IMAGE_NAME"
    fi

    if [ $? -eq 0 ]; then
        echo -e "\n${GREEN}===============================================${NC}"
        echo -e "${GREEN}🎉 PanHub 部署成功！${NC}"
        echo -e "${BLUE}访问地址:${NC} http://$(curl -s ifconfig.me):$PORT"
        echo -e "${BLUE}数据目录:${NC} $DATA_DIR"
        if [ ! -z "$SEARCH_PASSWORD" ]; then
            echo -e "${BLUE}访问密码:${NC} $SEARCH_PASSWORD"
        fi
        echo -e "${GREEN}===============================================${NC}"
    else
        echo -e "${RED}❌ 容器启动失败，请检查端口是否被占用或网络是否正常。${NC}"
    fi
}

# 卸载 PanHub
uninstall_panhub() {
    echo -e "${YELLOW}确定要卸载 PanHub 吗？${NC}"
    read -p "是否同时删除历史数据 ($DATA_DIR)？(y/n): " del_data
    
    docker rm -f $CONTAINER_NAME &> /dev/null
    
    if [[ "$del_data" == [Yy] ]]; then
        rm -rf "$DATA_DIR"
        echo -e "${GREEN}容器及数据已完全删除。${NC}"
    else
        echo -e "${GREEN}容器已删除，历史数据已保留在 $DATA_DIR。${NC}"
    fi
}

# 管理菜单
show_menu() {
    clear
    echo -e "${BLUE}=================================${NC}"
    echo -e "${GREEN}    PanHub 一键管理脚本          ${NC}"
    echo -e "${BLUE}=================================${NC}"
    echo -e " 1. 安装 / 更新 PanHub"
    echo -e " 2. 查看 容器运行日志"
    echo -e " 3. 重启 PanHub"
    echo -e " 4. 停止 PanHub"
    echo -e " 5. 启动 PanHub"
    echo -e " 6. 卸载 PanHub"
    echo -e " 0. 退出脚本"
    echo -e "${BLUE}=================================${NC}"
    read -p "请输入选项 [0-6]: " num

    case "$num" in
        1) install_panhub ;;
        2) docker logs -f $CONTAINER_NAME ;;
        3) docker restart $CONTAINER_NAME && echo -e "${GREEN}重启成功${NC}" ;;
        4) docker stop $CONTAINER_NAME && echo -e "${YELLOW}容器已停止${NC}" ;;
        5) docker start $CONTAINER_NAME && echo -e "${GREEN}容器已启动${NC}" ;;
        6) uninstall_panhub ;;
        0) exit 0 ;;
        *) echo -e "${RED}无效选项！${NC}" && sleep 1 && show_menu ;;
    esac
}

# 入口
show_menu
