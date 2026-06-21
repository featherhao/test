#!/bin/bash

# ====================================================================
# 脚本名称: PanHub 一键安装与管理脚本 (支持无损更新 & 智能多架构兼容)
# 适用系统: Ubuntu / Debian / CentOS (完美兼容 ARM64 / x86_64)
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

# 自动检测系统架构
ARCH=$(uname -m)
PLATFORM_ARG=""

if [[ "$ARCH" == "aarch64" || "$ARCH" == "arm64" ]]; then
    echo -e "${YELLOW}检测到当前服务器为 ARM 架构 (${ARCH})，将自动启用多架构兼容模式运行。${NC}"
    PLATFORM_ARG="--platform linux/amd64"
fi

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

    # 如果是 ARM 架构，自动尝试初始化 QEMU 环境（防止镜像因没有 arm64 标签而报错）
    if [ ! -z "$PLATFORM_ARG" ]; then
        docker run --rm --privileged multiarch/qemu-user-static --reset -p yes &>/dev/null
    fi
}

# 安装 / 更新 PanHub
# 安装 / 更新 PanHub
install_panhub() {
    check_docker

    # 如果容器已存在，说明是更新或重装
    if [ "$(docker ps -aq -f name=^${CONTAINER_NAME}$)" ]; then
        echo -e "${YELLOW}检测到已存在名为 ${CONTAINER_NAME} 的容器，正在为您执行更新/重装流程...${NC}"
        
        # 1. 自动备份旧容器的端口和密码配置
        OLD_PORT=$(docker inspect --format='{{range $p, $conf := .HostConfig.PortBindings}}{{(index $conf 0).HostPort}}{{end}}' $CONTAINER_NAME 2>/dev/null)
        OLD_PWD=$(docker inspect --format='{{range .Config.Env}}{{if grep "SEARCH_PASSWORD=" .}}{{.}}{{end}}{{end}}' $CONTAINER_NAME 2>/dev/null | sed 's/SEARCH_PASSWORD=//')
        
        PORT=${OLD_PORT:-$DEFAULT_PORT}
        SEARCH_PASSWORD=$OLD_PWD

        echo -e "${BLUE}检测到旧容器配置: 端口=${PORT}, 密码=${SEARCH_PASSWORD:-无}${NC}"
        
        # 2. 停止并删除旧容器
        echo -e "${YELLOW}正在停止并删除旧容器...${NC}"
        docker stop $CONTAINER_NAME &>/dev/null
        docker rm -f $CONTAINER_NAME &>/dev/null
    else
        # 新安装流程：手动输入配置
        echo -e "${BLUE}=== 自定义配置 (直接回车使用默认值) ===${NC}"
        read -p "请输入映射端口 [默认: $DEFAULT_PORT]: " user_port
        PORT=${user_port:-$DEFAULT_PORT}

        read -p "是否启用访问密码？(直接回车不启用，输入密码则启用): " search_pwd
        SEARCH_PASSWORD=$search_pwd
    fi

    # 3. 创建持久化目录（如果不存在）
    mkdir -p "$DATA_DIR"

    # 4. 强制拉取最新镜像
    echo -e "${YELLOW}正在从 GHCR 拉取作者最新的 PanHub 镜像...${NC}"
    docker pull $PLATFORM_ARG "$IMAGE_NAME"

    echo -e "${YELLOW}正在启动新版容器...${NC}"

    # 5. 组装 Docker 运行命令 (内部端口全面修正为 4000)
    if [ -z "$SEARCH_PASSWORD" ]; then
        docker run -d $PLATFORM_ARG \
            --name "$CONTAINER_NAME" \
            -p "$PORT":4000 \
            -v "$DATA_DIR":/app/data \
            --restart always \
            "$IMAGE_NAME"
    else
        docker run -d $PLATFORM_ARG \
            --name "$CONTAINER_NAME" \
            -p "$PORT":4000 \
            -v "$DATA_DIR":/app/data \
            -e SEARCH_PASSWORD="$SEARCH_PASSWORD" \
            --restart always \
            "$IMAGE_NAME"
    fi

    if [ $? -eq 0 ]; then
        echo -e "\n${GREEN}===============================================${NC}"
        echo -e "${GREEN}🎉 PanHub 安装/更新成功！${NC}"
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
    echo -e "${GREEN}    PanHub 一键管理脚本 (多架构版) ${NC}"
    echo -e "${BLUE}=================================${NC}"
    echo -e " 1. 安装 / 检查更新 PanHub"
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
