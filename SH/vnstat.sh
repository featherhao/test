#!/bin/bash

# 定义容器名
CONTAINER_NAME="vnstat"

# 检查是否以 root 权限运行
if [ "$EUID" -ne 0 ]; then
  echo "请使用 root 权限运行此脚本 (例如: sudo bash vnstat.sh)"
  exit 1
fi

# 1. 检查并安装 Docker
install_docker() {
    if ! command -v docker &> /dev/null; then
        echo "检测到未安装 Docker，正在自动安装..."
        curl -fsSL https://get.docker.com | sh
        systemctl enable --now docker
        echo "Docker 安装完成！"
    else
        echo "Docker 已安装。"
    fi
}

# 2. 部署或检查 vnstat 容器
deploy_vnstat() {
    if [ ! "$(docker ps -a -q -f name=^/${CONTAINER_NAME}$)" ]; then
        echo "正在部署 vnstat 容器..."
        docker run -d \
            --restart=unless-stopped \
            --network=host \
            -e HTTP_PORT=8685 \
            -v /etc/localtime:/etc/localtime:ro \
            -v /etc/timezone:/etc/timezone:ro \
            --name ${CONTAINER_NAME} \
            vergoh/vnstat
        echo "vnstat 容器部署成功！"
        
        # 等待几秒让容器初始化并自动添加网卡
        sleep 3
        # 尝试自动添加默认网卡
        DEFAULT_IF=$(docker exec ${CONTAINER_NAME} vnstat --iflist | awk 'NR==2{print $1}')
        if [ -n "$DEFAULT_IF" ]; then
            echo "检测到默认网卡: $DEFAULT_IF，正在加入监控..."
            docker exec ${CONTAINER_NAME} vnstat -i "$DEFAULT_IF" --add
        fi
    else
        echo "vnstat 容器已存在。"
    fi
}

# 3. 卸载 vnstat 容器及相关数据
uninstall_vnstat() {
    echo "=========================================="
    echo "         卸载 vnStat 流量监控             "
    echo "=========================================="
    read -p "确定要卸载 vnStat 吗？历史流量数据将会丢失！[y/N]: " confirm
    case "$confirm" in
        [yY][eE][sS]|[yY])
            if [ "$(docker ps -a -q -f name=^/${CONTAINER_NAME}$)" ]; then
                echo "正在停止并删除容器..."
                docker stop ${CONTAINER_NAME} &>/dev/null
                docker rm ${CONTAINER_NAME} &>/dev/null
                echo "vnstat 容器已成功卸载！"
            else
                echo "未检测到运行中的 vnstat 容器。"
            fi
            ;;
        *)
            echo "已取消卸载操作。"
            ;;
    esac
}

# 4. 交互菜单
show_menu() {
    clear
    echo "=========================================="
    echo "       VPS 流量统计管理面板 (vnStat)      "
    echo "=========================================="
    echo " 1. 查看流量综合概览 (Summary)"
    echo " 2. 查看最近几小时流量明细"
    echo " 3. 查看每日流量统计"
    echo " 4. 查看每月流量统计"
    echo " 5. 查看实时网卡带宽速率"
    echo " 6. 查看网页端访问地址 (Web UI)"
    echo " 7. 卸载 vnStat 服务"
    echo " 0. 退出脚本"
    echo "=========================================="
    read -p "请输入选项 [0-7]: " choice

    case "$choice" in
        1)
            echo "正在获取流量概览..."
            docker exec -it ${CONTAINER_NAME} vnstat
            ;;
        2)
            echo "正在获取每小时流量..."
            docker exec -it ${CONTAINER_NAME} vnstat -h
            ;;
        3)
            echo "正在获取每日流量..."
            docker exec -it ${CONTAINER_NAME} vnstat -d
            ;;
        4)
            echo "正在获取每月流量..."
            docker exec -it ${CONTAINER_NAME} vnstat -m
            ;;
        5)
            echo "正在实时监测带宽 (按 Ctrl+C 退出)..."
            docker exec -it ${CONTAINER_NAME} vnstat -l
            ;;
        6)
            SERVER_IP=$(curl -s ifconfig.me || hostname -I | awk '{print $1}')
            echo "=========================================="
            echo " 网页端地址: http://$SERVER_IP:8685"
            echo " (如果无法访问请检查 VPS 的防火墙/安全组)"
            echo "=========================================="
            ;;
        7)
            uninstall_vnstat
            ;;
        0)
            exit 0
            ;;
        *)
            echo "无效的输入，请重新选择！"
            ;;
    esac
    
    echo ""
    read -p "按回车键继续..."
    show_menu
}

# 主执行流程
install_docker
deploy_vnstat
show_menu
