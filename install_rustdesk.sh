#!/bin/bash

RUSTDESK_DIR="/root/rustdesk"
BUILD_LOG="$RUSTDESK_DIR/build.log"
BUILD_DONE_FLAG="$RUSTDESK_DIR/.build_done"

# 检查 RustDesk 是否安装
check_status() {
    if command -v rustdesk &>/dev/null; then
        STATUS="已安装 ✅"
    else
        STATUS="未安装 ❌"
    fi
}

# 显示菜单
show_menu() {
    clear
    echo "============================"
    echo "      RustDesk 管理脚本     "
    echo "============================"
    check_status
    echo "当前状态: $STATUS"

    if [[ -f "$BUILD_DONE_FLAG" ]]; then
        echo "✅ Docker 构建已完成！"
        echo "🚀 可运行 RustDesk 容器:"
        echo "docker run --rm -it --network=host -v \$PWD:/home/user/rustdesk \\"
        echo "  -v rustdesk-git-cache:/home/user/.cargo/git \\"
        echo "  -v rustdesk-registry-cache:/home/user/.cargo/registry \\"
        echo "  -e PUID=\$(id -u) -e PGID=\$(id -g) rustdesk-builder"
    elif pgrep -f "docker build" >/dev/null; then
        echo "⏳ Docker 构建正在进行中，日志: $BUILD_LOG"
    fi

    echo "1) 安装 RustDesk"
    echo "2) 更新 RustDesk"
    echo "3) 卸载 RustDesk"
    echo "4) 取消正在构建 Docker"
    echo "5) 退出"
    read -p "请选择操作 [1-5]: " CHOICE
}

# 安装 RustDesk
install_rustdesk() {
    echo "📦 选择安装方式："
    echo "1) 官方安装脚本"
    echo "2) Docker 构建（后台运行，支持 SSH 中断恢复）"
    read -p "请选择 [1-2]: " METHOD

    case $METHOD in
        1)
            echo "📥 执行官方安装脚本安装 RustDesk..."
            curl -fsSL https://raw.githubusercontent.com/rustdesk/rustdesk-server-pro/main/install.sh | bash
            ;;
        2)
            echo "🐳 使用 Docker 构建 RustDesk..."
            mkdir -p "$RUSTDESK_DIR"
            cd "$RUSTDESK_DIR" || exit
            if [[ ! -d "$RUSTDESK_DIR/.git" ]]; then
                git clone https://github.com/rustdesk/rustdesk.git "$RUSTDESK_DIR"
            else
                git -C "$RUSTDESK_DIR" pull
            fi
            nohup docker build -t rustdesk-builder "$RUSTDESK_DIR" >"$BUILD_LOG" 2>&1 && \
                echo "done" > "$BUILD_DONE_FLAG" &
            echo "📌 Docker 构建已在后台运行，日志保存在 $BUILD_LOG"
            echo "⏳ 可用 'tail -f $BUILD_LOG' 查看进度"
            ;;
    esac
}

# 更新 RustDesk
update_rustdesk() {
    if command -v rustdesk &>/dev/null; then
        echo "🔄 更新 RustDesk..."
        install_rustdesk
    else
        echo "⚠️ RustDesk 未安装，请先安装。"
    fi
}

# 卸载 RustDesk
uninstall_rustdesk() {
    echo "🗑️ 卸载 RustDesk..."
    apt remove --purge -y rustdesk || true
    rm -rf "$RUSTDESK_DIR" "$BUILD_LOG" "$BUILD_DONE_FLAG"
    docker rm -f $(docker ps -aq --filter ancestor=rustdesk-builder) 2>/dev/null || true
    docker rmi -f rustdesk-builder 2>/dev/null || true
    docker volume rm rustdesk-git-cache rustdesk-registry-cache 2>/dev/null || true
    echo "✅ RustDesk 已卸载"
}

# 取消正在构建
cancel_build() {
    echo "🛑 取消 Docker 构建..."
    pkill -f "docker build" && echo "✅ 已取消构建" || echo "⚠️ 没有正在运行的构建"
    rm -f "$BUILD_LOG"
}

# 主循环
while true; do
    show_menu
    case $CHOICE in
        1) install_rustdesk ;;
        2) update_rustdesk ;;
        3) uninstall_rustdesk ;;
        4) cancel_build ;;
        5) exit 0 ;;
        *) echo "❌ 无效选项";;
    esac
    read -p "按回车键继续..." dummy
done
