#!/bin/bash
# Banana Mall 一键安装/卸载脚本 for ARM Ubuntu (完全卸载版)
# 版本: 1.3
# 功能: 提供交互菜单，自动安装 Node.js 22, 克隆仓库, 安装依赖, 配置 SQLite, 使用 PM2 守护进程
#       卸载将彻底移除 Node.js、PM2、项目目录及 Nodesource 源

set -e  # 遇到错误立即退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 配置变量
INSTALL_DIR="/opt/banana-mall"
REPO_URL="https://github.com/ziguishian/banana-mall.git"
PM2_APP_NAME="banana-mall"
NODE_VERSION="22"            # 使用 Node.js 22（兼容最新依赖）
DB_PATH="file:./dev.db"

# 检查是否以 root 运行
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}请使用 sudo 运行此脚本${NC}"
    exit 1
fi

# 菜单函数
show_menu() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${GREEN}   Banana Mall 管理脚本${NC}"
    echo -e "${BLUE}================================${NC}"
    echo "1. 安装 Banana Mall"
    echo "2. 完全卸载 Banana Mall（移除 Node.js、PM2 等）"
    echo "3. 退出"
    echo -e "${BLUE}================================${NC}"
    read -p "请选择操作 [1-3]: " choice
    case $choice in
        1)
            install
            ;;
        2)
            uninstall
            ;;
        3)
            echo "退出脚本"
            exit 0
            ;;
        *)
            echo -e "${RED}无效选择，请重新运行脚本${NC}"
            exit 1
            ;;
    esac
}

# 安装 Node.js 22.x (ARM 兼容)
install_nodejs() {
    echo -e "${YELLOW}[1/6] 检查 Node.js 环境...${NC}"
    if command -v node &> /dev/null; then
        NODE_CUR_VER=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
        if [ "$NODE_CUR_VER" -ge "$NODE_VERSION" ]; then
            echo -e "${GREEN}Node.js 已满足要求 (v$(node -v))${NC}"
            return 0
        else
            echo -e "${YELLOW}Node.js 版本过低，将升级至 v${NODE_VERSION}${NC}"
        fi
    fi

    echo -e "${YELLOW}安装 Node.js ${NODE_VERSION}.x ...${NC}"
    curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | bash -
    apt-get install -y nodejs
    echo -e "${GREEN}Node.js 安装完成${NC}"
}

# 安装 PM2
install_pm2() {
    echo -e "${YELLOW}[2/6] 安装 PM2 进程管理器...${NC}"
    if command -v pm2 &> /dev/null; then
        echo -e "${GREEN}PM2 已安装${NC}"
    else
        npm install -g pm2
        echo -e "${GREEN}PM2 安装完成${NC}"
    fi
}

# 克隆项目并安装依赖
clone_and_install() {
    echo -e "${YELLOW}[3/6] 克隆项目到 ${INSTALL_DIR} ...${NC}"
    if [ -d "$INSTALL_DIR" ]; then
        echo -e "${YELLOW}目录已存在，删除旧版本...${NC}"
        rm -rf "$INSTALL_DIR"
    fi
    git clone "$REPO_URL" "$INSTALL_DIR"
    cd "$INSTALL_DIR"

    echo -e "${YELLOW}安装 npm 依赖...${NC}"
    npm install --production=false
    echo -e "${GREEN}依赖安装完成${NC}"
}

# 配置环境变量和数据库
setup_env_and_db() {
    echo -e "${YELLOW}[4/6] 配置环境变量和数据库...${NC}"
    cd "$INSTALL_DIR"
    if [ ! -f ".env" ]; then
        cp .env.example .env
    fi

    # 配置数据库为 SQLite
    if ! grep -q "DATABASE_URL" .env; then
        echo "DATABASE_URL=\"$DB_PATH\"" >> .env
    else
        sed -i "s|DATABASE_URL=.*|DATABASE_URL=\"$DB_PATH\"|" .env
    fi

    # API Key 留空，用户可通过网页设置界面填写
    sed -i "s|OPENAI_API_KEY=.*|OPENAI_API_KEY=|" .env
    sed -i "s|OPENAI_BASE_URL=.*|OPENAI_BASE_URL=|" .env

    # 生成 Prisma Client 并执行迁移
    echo -e "${YELLOW}初始化 Prisma...${NC}"
    npx prisma generate
    npx prisma migrate dev --name init --skip-seed
    echo -e "${GREEN}数据库初始化完成${NC}"
}

# 构建项目
build_project() {
    echo -e "${YELLOW}[5/6] 构建生产版本...${NC}"
    cd "$INSTALL_DIR"
    npm run build
    echo -e "${GREEN}构建完成${NC}"
}

# 使用 PM2 启动服务
start_with_pm2() {
    echo -e "${YELLOW}[6/6] 启动 PM2 服务...${NC}"
    cd "$INSTALL_DIR"
    # 如果已有同名应用，先删除
    pm2 delete "$PM2_APP_NAME" &>/dev/null || true
    pm2 start npm --name "$PM2_APP_NAME" -- start
    pm2 save
    pm2 startup systemd -u $(whoami) --hp /home/$(whoami) 2>/dev/null || true
    echo -e "${GREEN}服务已启动，监听端口 3000${NC}"
    echo -e "访问地址: http://$(hostname -I | awk '{print $1}'):3000"
}

# 安装主流程
install() {
    echo -e "${GREEN}开始安装 Banana Mall...${NC}"
    install_nodejs
    install_pm2
    clone_and_install
    setup_env_and_db
    build_project
    start_with_pm2
    echo -e "${GREEN}安装完成！${NC}"
}

# 完全卸载函数（移除 Node.js、PM2、项目目录等）
uninstall() {
    echo -e "${RED}开始完全卸载 Banana Mall...${NC}"
    
    # 1. 停止并删除 PM2 应用
    if command -v pm2 &> /dev/null; then
        echo -e "${YELLOW}停止并删除 PM2 应用...${NC}"
        pm2 stop "$PM2_APP_NAME" &>/dev/null || true
        pm2 delete "$PM2_APP_NAME" &>/dev/null || true
        pm2 save &>/dev/null || true
    fi
    
    # 2. 卸载 PM2 全局包
    if command -v npm &> /dev/null; then
        echo -e "${YELLOW}卸载 PM2 全局包...${NC}"
        npm uninstall -g pm2 &>/dev/null || true
    fi
    
    # 3. 删除项目目录
    if [ -d "$INSTALL_DIR" ]; then
        echo -e "${YELLOW}删除项目目录 ${INSTALL_DIR}...${NC}"
        rm -rf "$INSTALL_DIR"
        echo -e "${GREEN}已删除项目目录${NC}"
    else
        echo -e "${YELLOW}项目目录不存在${NC}"
    fi
    
    # 4. 卸载 Node.js 和 Nodesource 源
    echo -e "${YELLOW}卸载 Node.js 和 Nodesource 源...${NC}"
    apt-get purge -y nodejs &>/dev/null || true
    apt-get autoremove -y &>/dev/null || true
    rm -f /etc/apt/sources.list.d/nodesource.list
    rm -f /etc/apt/sources.list.d/nodesource.list.save
    apt-get update &>/dev/null || true
    echo -e "${GREEN}Node.js 和 Nodesource 源已卸载${NC}"
    
    echo -e "${GREEN}完全卸载完成！${NC}"
}

# 主逻辑：显示菜单
show_menu

exit 0
