#!/bin/bash
set -e

RUSTDESK_DIR="$HOME/rustdesk"
BUILD_LOG="$RUSTDESK_DIR/build.log"
PID_FILE="$RUSTDESK_DIR/build.pid"

# 检查状态
check_status() {
    if command -v rustdesk >/dev/null 2>&1; then
        echo "当前状态: 已安装 (官方) ✅"
    elif docker images | grep -q "rustdesk-builder"; then
        echo "当前状态: 已安装 (Docker) ✅"
    else
        echo "当前状态: 未安装 ❌"
    fi
}

# 安装
install_rustdesk() {
    echo "📦 选择安装方式："
    echo "1) 官方安装脚本"
    echo "2) Docker 构建（后台运行，支持 SSH 中断恢复）"
    read -p "请选择 [1-2]: " method

    if [[ "$method" == "1" ]]; then
        echo "📥 执行官方安装脚本安装 RustDesk..."
        bash <(curl -fsSL "https://github.com/rustdesk/rustdesk/releases/latest/download/rustdesk-remote.sh")
        echo "✅ 安装完成"
    elif [[ "$method" == "2" ]]; then
        echo "🐳 使用 Docker 构建 RustDesk..."
        mkdir -p "$RUSTDESK_DIR"

        # 如果已有构建进程在跑
        if [[ -f "$PID_FILE" && -d "/proc/$(cat $PID_FILE)" ]]; then
            echo "⏳ Docker 构建正在进行中，日志: $BUILD_LOG"
            return
        fi

        # 拉取或更新源码
        if [[ ! -d "$RUSTDESK_DIR/.git" ]]; then
            git clone https://github.com/rustdesk/rustdesk.git "$RUSTDESK_DIR"
        else
            cd "$RUSTDESK_DIR"
            git fetch --all && git reset --hard origin/master
        fi

        # 后台构建
        (cd "$RUSTDESK_DIR" && docker build -t rustdesk-builder . >"$BUILD_LOG" 2>&1 & echo $! >"$PID_FILE")
        echo "📌 Docker 构建已在后台运行，日志保存在 $BUILD_LOG"
        echo "⏳ 可用: tail -f $BUILD_LOG 查看进度"
    else
        echo "❌ 输入无效"
    fi
}

# 更新
update_rustdesk() {
    if command -v rustdesk >/dev/null 2>&1; then
        echo "📥 执行官方更新..."
        bash <(curl -fsSL "https://github.com/rustdesk/rustdesk/releases/latest/download/rustdesk-remote.sh")
        echo "✅ 更新完成"
    elif docker images | grep -q "rustdesk-builder"; then
        echo "🐳 执行 Docker 更新..."
        cd "$RUSTDESK_DIR"
        git fetch --all && git reset --hard origin/master
        docker build -t rustdesk-builder . >"$BUILD_LOG" 2>&1 &
        echo "📌 更新已在后台进行，日志: $BUILD_LOG"
    else
        echo "⚠️ RustDesk 未安装"
    fi
}

# 卸载
uninstall_rustdesk() {
    echo "⚠️ 确认要卸载 RustDesk 吗？这将删除本地二进制、Docker 容器、镜像和缓存。"
    read -p "请输入 (y/n): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo "❌ 已取消卸载"
        return
    fi

    echo "🗑️ 卸载 RustDesk..."

    # 删除二进制
    sudo rm -f "/usr/local/bin/rustdesk" "/usr/bin/rustdesk" "$HOME/.local/bin/rustdesk"

    # 删除容器
    CONTAINERS=$(docker ps -a --filter "ancestor=rustdesk-builder" --format "{{.ID}}")
    if [ -n "$CONTAINERS" ]; then
        docker rm -f $CONTAINERS
    fi

    # 删除镜像
    if docker images | grep -q "rustdesk-builder"; then
        docker rmi -f rustdesk-builder
    fi

    # 删除缓存卷
    docker volume rm -f rustdesk-git-cache rustdesk-registry-cache >/dev/null 2>&1 || true

    # 删除源码目录
    rm -rf "$RUSTDESK_DIR"

    echo "✅ RustDesk 已彻底卸载"
}

# 取消构建
cancel_build() {
    if [[ -f "$PID_FILE" ]]; then
        PID=$(cat "$PID_FILE")
        if [[ -d "/proc/$PID" ]]; then
            kill -9 "$PID" || true
            rm -f "$PID_FILE"
            echo "🛑 已取消正在进行的 Docker 构建"
            return
        fi
    fi
    echo "ℹ️ 当前没有正在进行的构建"
}

# 主循环
while true; do
    echo "============================"
    echo "      RustDesk 管理脚本     "
    echo "============================"
    check_status
    echo "1) 安装 RustDesk"
    echo "2) 更新 RustDesk"
    echo "3) 卸载 RustDesk"
    echo "4) 取消正在构建 Docker"
    echo "5) 退出"
    read -p "请选择操作 [1-5]: " choice

    case $choice in
        1) install_rustdesk ;;
        2) update_rustdesk ;;
        3) uninstall_rustdesk ;;
        4) cancel_build ;;
        5) exit 0 ;;
        *) echo "❌ 无效选项" ;;
    esac
done
