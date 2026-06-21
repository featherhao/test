#!/bin/bash

# ================== 基础配置 ==================
CONTAINER_NAME="panhub"
IMAGE_NAME="ghcr.io/wu529778790/panhub.shenzjd.com:latest"
DEFAULT_PORT=2999
DATA_DIR="/root/panhub/data"
APP_DIR="/root/panhub-app"

# 检测架构 (x86_64 或 aarch64)
ARCH=$(uname -m)

# 彩色输出
C_RESET="\e[0m"; C_GREEN="\e[32m"; C_RED="\e[31m"; C_YELLOW="\e[33m"; C_BLUE="\e[34m"; C_CYAN="\e[36m"

# ================== 核心功能函数 ==================

# 1. 安装 / 检查更新
install_panhub() {
    # 自动检测并拉取/克隆最新版
    if [[ "$ARCH" == "x86_64" ]]; then
        echo -e "${C_GREEN}检测到 AMD64 架构，正在使用 Docker 方案安装/更新...${C_RESET}"
        
        # 备份端口（如果已存在）
        if [ "$(docker ps -aq -f name=^${CONTAINER_NAME}$)" ]; then
            OLD_PORT=$(docker inspect --format='{{range $p, $conf := .HostConfig.PortBindings}}{{(index $conf 0).HostPort}}{{end}}' $CONTAINER_NAME 2>/dev/null)
            PORT=${OLD_PORT:-$DEFAULT_PORT}
            docker rm -f $CONTAINER_NAME &>/dev/null
        else
            read -rp "请输入映射端口 [默认: $DEFAULT_PORT]: " user_port
            PORT=${user_port:-$DEFAULT_PORT}
        fi

        mkdir -p "$DATA_DIR"
        docker pull "$IMAGE_NAME"
        docker run -d --name "$CONTAINER_NAME" \
          -p "$PORT":4000 \
          -v "$DATA_DIR":/app/data \
          --restart always \
          "$IMAGE_NAME"

    elif [[ "$ARCH" == "aarch64" ]]; then
        echo -e "${C_YELLOW}检测到 ARM64 架构，正在使用本地原生构建方案安装/更新...${C_RESET}"
        
        # 确保环境存在
        if ! command -v pnpm &>/dev/null; then
            echo -e "${C_CYAN}正在安装 Node环境、pnpm 及 pm2 守护工具...${C_RESET}"
            curl -fsSL https://fnm.vercel.app/install | bash || true
            export PATH="$HOME/.local/share/fnm:$PATH"
            eval "`fnm env`" || true
            fnm use --install-if-missing 20 || true
            npm install -g pnpm pm2 || true
        fi

        # 停止旧进程
        if command -v pm2 &>/dev/null && pm2 list | grep -q "$CONTAINER_NAME"; then
            pm2 delete "$CONTAINER_NAME" &>/dev/null || true
        else
            pkill -f "node .output/server/index.mjs" || true
        fi

        # 下载源码并编译
        cd /root
        rm -rf "$APP_DIR"
        echo -e "${C_CYAN}正在从 GitHub 克隆最新源码...${C_RESET}"
        git clone https://github.com/wu529778790/panhub.shenzjd.com.git "$APP_DIR"
        cd "$APP_DIR"
        
        echo -e "${C_CYAN}正在原生编译（请耐心等待）...${C_RESET}"
        pnpm install && pnpm build

        # 启动常驻
        read -rp "请输入运行端口 [默认: $DEFAULT_PORT]: " user_port
        PORT=${user_port:-$DEFAULT_PORT}

        if command -v pm2 &>/dev/null; then
            PORT=$PORT pm2 start .output/server/index.mjs --name "$CONTAINER_NAME"
            pm2 save &>/dev/null || true
        else
            PORT=$PORT nohup node .output/server/index.mjs > panhub.log 2>&1 &
        fi
    fi

    echo -e "${C_GREEN}🎉 PanHub 安装/更新流程执行完毕！端口: ${PORT}${C_RESET}"
}

# 2. 查看日志
view_logs() {
    if [[ "$ARCH" == "x86_64" ]]; then
        docker logs --tail 50 "$CONTAINER_NAME"
    elif [[ "$ARCH" == "aarch64" ]]; then
        if command -v pm2 &>/dev/null && pm2 list | grep -q "$CONTAINER_NAME"; then
            pm2 logs "$CONTAINER_NAME" --lines 50 --no-loop
        else
            if [ -f "$APP_DIR/panhub.log" ]; then
                tail -n 50 "$APP_DIR/panhub.log"
            else
                echo -e "${C_RED}未找到日志文件！${C_RESET}"
            fi
        fi
    fi
}

# 3. 重启服务
restart_panhub() {
    echo -e "${C_YELLOW}正在重启 PanHub...${C_RESET}"
    if [[ "$ARCH" == "x86_64" ]]; then
        docker restart "$CONTAINER_NAME"
    elif [[ "$ARCH" == "aarch64" ]]; then
        if command -v pm2 &>/dev/null && pm2 list | grep -q "$CONTAINER_NAME"; then
            pm2 restart "$CONTAINER_NAME"
        else
            pkill -f "node .output/server/index.mjs" || true
            sleep 1
            cd "$APP_DIR" && PORT=$DEFAULT_PORT nohup node .output/server/index.mjs > panhub.log 2>&1 &
        fi
    fi
    echo -e "${C_GREEN}重启成功！${C_RESET}"
}

# 4. 停止服务
stop_panhub() {
    echo -e "${C_YELLOW}正在停止 PanHub...${C_RESET}"
    if [[ "$ARCH" == "x86_64" ]]; then
        docker stop "$CONTAINER_NAME"
    elif [[ "$ARCH" == "aarch64" ]]; then
        if command -v pm2 &>/dev/null && pm2 list | grep -q "$CONTAINER_NAME"; then
            pm2 stop "$CONTAINER_NAME"
        else
            pkill -f "node .output/server/index.mjs" || true
        fi
    fi
    echo -e "${C_GREEN}服务已停止。${C_RESET}"
}

# 5. 启动服务
start_panhub() {
    echo -e "${C_GREEN}正在启动 PanHub...${C_RESET}"
    if [[ "$ARCH" == "x86_64" ]]; then
        docker start "$CONTAINER_NAME"
    elif [[ "$ARCH" == "aarch64" ]]; then
        if command -v pm2 &>/dev/null && pm2 list | grep -q "$CONTAINER_NAME"; then
            pm2 start "$CONTAINER_NAME"
        else
            cd "$APP_DIR" && PORT=$DEFAULT_PORT nohup node .output/server/index.mjs > panhub.log 2>&1 &
        fi
    fi
    echo -e "${C_GREEN}服务已启动。${C_RESET}"
}

# 6. 卸载服务
uninstall_panhub() {
    read -rp "⚠️ 确定要彻底卸载 PanHub 吗？(y/n): " confirm
    if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
        if [[ "$ARCH" == "x86_64" ]]; then
            docker rm -f "$CONTAINER_NAME" &>/dev/null || true
            docker rmi "$IMAGE_NAME" &>/dev/null || true
            rm -rf "$DATA_DIR"
        elif [[ "$ARCH" == "aarch64" ]]; then
            if command -v pm2 &>/dev/null && pm2 list | grep -q "$CONTAINER_NAME"; then
                pm2 delete "$CONTAINER_NAME" &>/dev/null || true
            fi
            pkill -f "node .output/server/index.mjs" || true
            rm -rf "$APP_DIR"
        fi
        echo -e "${C_GREEN}❌ PanHub 已成功从系统中彻底卸载！${C_RESET}"
    else
        echo -e "${C_BLUE}已取消卸载。${C_RESET}"
    fi
}

# ================== 交互菜单主循环 ==================
while true; do
    echo -e "\n${C_BOLD}===================================${C_RESET}"
    echo -e "      ${C_CYAN}PanHub 盘搜聚合管理菜单${C_RESET} (${C_BLUE}$ARCH${C_RESET})"
    echo -e "${C_BOLD}===================================${C_RESET}"
    echo -e " ${C_GREEN}1.${C_RESET} 安装 / 检查更新 PanHub"
    echo -e " ${C_GREEN}2.${C_RESET} 查看 容器/程序运行日志"
    echo -e " ${C_GREEN}3.${C_RESET} 重启 PanHub"
    echo -e " ${C_GREEN}4.${C_RESET} 停止 PanHub"
    echo -e " ${C_GREEN}5.${C_RESET} 启动 PanHub"
    echo -e " ${C_GREEN}6.${C_RESET} ${C_RED}卸载 PanHub${C_RESET}"
    echo -e " ${C_GREEN}0.${C_RESET} 退出脚本"
    echo -e "${C_BOLD}===================================${C_RESET}"
    
    read -rp "请选择操作 [0-6]: " choice
    case "$choice" in
        1) install_panhub ;;
        2) view_logs ;;
        3) restart_panhub ;;
        4) stop_panhub ;;
        5) start_panhub ;;
        6) uninstall_panhub ;;
        0) echo -e "${C_BLUE}退出菜单。${C_RESET}"; exit 0 ;;
        *) echo -e "${C_RED}无效输入，请重新选择！${C_RESET}"; sleep 1 ;;
    esac

    echo ""
    read -rp "按 [Enter] 键继续..."
done
