#!/bin/bash
set -e

# 目录与状态
INSTALL_DIR="/usr/local/bin"
DOCKER_LOG_DIR="$HOME/rustdesk/build.log"
DOCKER_RUNNING_FILE="$HOME/rustdesk/docker_running.flag"
STATUS="未安装 ❌"

check_installed() {
    if command -v rustdesk >/dev/null 2>&1; then
        STATUS="已安装 ✅"
    else
        STATUS="未安装 ❌"
    fi
}

install_official() {
    echo "📥 安装官方 RustDesk（官方 GUI 弹窗输入用户名）..."

    # 查找非 root 用户
    NON_ROOT_USER=$(awk -F: '$3 >= 1000 && $1 != "nobody" {print $1; exit}' /etc/passwd)
    
    # 如果没有，创建默认用户
    if [ -z "$NON_ROOT_USER" ]; then
        DEFAULT_USER="rustdesk"
        echo "⚠️ 系统没有非 root 用户，正在创建默认用户: $DEFAULT_USER"
        adduser --disabled-password --gecos "" "$DEFAULT_USER"
        NON_ROOT_USER="$DEFAULT_USER"
    fi

    # 显示用户名，确认
    echo "✅ 将使用非 root 用户: $NON_ROOT_USER"
    read -p "按回车确认，继续下一步安装..." dummy

    # 调用官方安装脚本
    bash <(curl -fsSL "https://github.com/rustdesk/rustdesk/releases/latest/download/rustdesk-remote.sh")
}

install_docker() {
    echo "🐳 使用 Docker 构建 RustDesk（后台运行）..."
    mkdir -p "$HOME/rustdesk"
    touch "$DOCKER_RUNNING_FILE"

    # 后台运行 Docker 构建
    bash -c "cd $HOME/rustdesk && git clone https://github.com/rustdesk/rustdesk 2>/dev/null || cd rustdesk && git pull && docker build -t rustdesk-builder . > $DOCKER_LOG_DIR 2>&1 && rm -f $DOCKER_RUNNING_FILE &"
    echo "📌 Docker 构建已在后台运行，日志保存在 $DOCKER_LOG_DIR"
    echo "⏳ 可以用 'tail -f $DOCKER_LOG_DIR' 查看进度"
}

cancel_docker() {
    if [ -f "$DOCKER_RUNNING_FILE" ]; then
        echo "❌ 正在取消 Docker 构建..."
        pkill -f "docker build -t rustdesk-builder" || true
        rm -f "$DOCKER_RUNNING_FILE"
        echo "✅ Docker 构建已取消"
    else
        echo "⚠️ 没有正在运行的 Docker 构建"
    fi
}

uninstall_rustdesk() {
    echo "🗑️ 卸载 RustDesk..."
    # 删除官方安装文件
    if command -v rustdesk >/dev/null 2>&1; then
        rm -f "$(command -v rustdesk)"
    fi
    # 删除 Docker 镜像和缓存
    docker rm -f rustdesk-builder >/dev/null 2>&1 || true
    docker rmi rustdesk-builder >/dev/null 2>&1 || true
    rm -rf "$HOME/rustdesk"
    echo "✅ RustDesk 已卸载"
}

show_menu() {
    check_installed
    echo "============================"
    echo "      RustDesk 管理脚本     "
    echo "============================"
    echo "当前状态: $STATUS"
    if [ -f "$DOCKER_RUNNING_FILE" ]; then
        echo "⏳ Docker 构建正在进行中，日志: $DOCKER_LOG_DIR"
    fi
    echo "1) 安装 RustDesk"
    echo "2) 更新 RustDesk"
    echo "3) 卸载 RustDesk"
    echo "4) 取消正在构建 Docker"
    echo "5) 退出"
}

main_loop() {
    while true; do
        show_menu
        read -p "请选择操作 [1-5]: " choice
        case "$choice" in
            1)
                echo "📦 选择安装方式："
                echo "1) 官方安装（GUI 弹窗输入用户名）"
                echo "2) Docker 构建（后台运行，支持 SSH 中断）"
                read -p "请选择 [1-2]: " method
                case "$method" in
                    1) install_official ;;
                    2) install_docker ;;
                    *) echo "⚠️ 选择无效" ;;
                esac
                ;;
            2)
                if [ -f "$DOCKER_RUNNING_FILE" ]; then
                    echo "⏳ Docker 构建正在进行中，请等待完成或取消后更新"
                else
                    echo "📦 更新 RustDesk..."
                    echo "请选择安装方式："
                    echo "1) 官方安装"
                    echo "2) Docker 构建"
                    read -p "请选择 [1-2]: " method
                    case "$method" in
                        1) install_official ;;
                        2) install_docker ;;
                        *) echo "⚠️ 选择无效" ;;
                    esac
                fi
                ;;
            3) uninstall_rustdesk ;;
            4) cancel_docker ;;
            5) exit 0 ;;
            *) echo "⚠️ 选择无效" ;;
        esac
    done
}

main_loop
