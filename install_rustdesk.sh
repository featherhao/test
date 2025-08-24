#!/bin/bash
set -e

RUSTDESK_DIR="/root/rustdesk"
BIN_DIR="/opt/rustdesk"
BUILD_LOG="$RUSTDESK_DIR/build.log"
BUILD_DONE_FLAG="$RUSTDESK_DIR/.build_done"
BUILD_PID_FILE="$RUSTDESK_DIR/build_pid.pid"
DEFAULT_USER="rustdesk"

check_status() {
    if command -v rustdesk &>/dev/null || docker images | grep -q rustdesk-builder; then
        STATUS="已安装 ✅"
    else
        STATUS="未安装 ❌"
    fi

    if [[ -f "$BUILD_DONE_FLAG" ]]; then
        echo "✅ Docker 构建已完成！"
        echo "🚀 可运行 RustDesk 容器:"
        echo "docker run --rm -it --network=host -v \$PWD:/home/user/rustdesk \\"
        echo "  -v rustdesk-git-cache:/home/user/.cargo/git \\"
        echo "  -v rustdesk-registry-cache:/home/user/.cargo/registry \\"
        echo "  -e PUID=\$(id -u) -e PGID=\$(id -g) rustdesk-builder"
    elif [[ -f "$BUILD_PID_FILE" ]]; then
        PID=$(cat "$BUILD_PID_FILE")
        if ps -p "$PID" &>/dev/null; then
            echo "⏳ Docker 构建正在进行中，日志: $BUILD_LOG"
            STATUS="构建中 ⏳"
        else
            echo "⚠️ 构建进程异常终止，请重新构建"
            rm -f "$BUILD_PID_FILE"
        fi
    fi
}

install_official_binary() {
    echo "📥 下载官方 RustDesk 二进制..."

    # 检查非 root 用户
    non_root_user=$(awk -F: '$3 >= 1000 && $1 != "nobody" {print $1; exit}' /etc/passwd)
    if [ -z "$non_root_user" ]; then
        echo "⚠️ 没有找到非 root 用户，正在创建默认用户 $DEFAULT_USER..."
        adduser --disabled-password --gecos "" "$DEFAULT_USER"
        non_root_user="$DEFAULT_USER"
        echo "✅ 已创建用户: $non_root_user"
    else
        echo "✅ 系统已有非 root 用户: $non_root_user"
    fi
    read -p "按回车确认，继续下一步安装..." dummy

    # 获取最新 release URL
    RELEASE_URL=$(curl -s https://api.github.com/repos/rustdesk/rustdesk/releases/latest \
        | grep "rustdesk-server-linux-amd64.tar.gz" \
        | cut -d '"' -f 4)
    if [ -z "$RELEASE_URL" ]; then
        echo "❌ 获取最新 release URL 失败"
        return
    fi
    echo "⬇️ 下载最新版本: $RELEASE_URL"

    mkdir -p "$BIN_DIR"
    cd "$BIN_DIR" || exit
    curl -L -O "$RELEASE_URL"
    tar -xzf rustdesk-server-linux-amd64.tar.gz
    chmod +x rustdesk
    ln -sf "$BIN_DIR/rustdesk" /usr/local/bin/rustdesk

    # 安装完成提示，不自动返回菜单
    clear
    echo "============================"
    echo "      RustDesk 安装完成      "
    echo "============================"
    echo "✅ 官方二进制已安装完成！"
    echo "📌 可执行文件: $BIN_DIR/rustdesk"
    echo "📌 符号链接: /usr/local/bin/rustdesk"
    echo "🚀 运行命令: rustdesk"
    echo
    read -p "👉 按回车返回主菜单..." dummy
}

install_docker() {
    echo "🐳 使用 Docker 构建 RustDesk..."
    mkdir -p "$RUSTDESK_DIR"
    cd "$RUSTDESK_DIR" || exit
    if [[ ! -d "$RUSTDESK_DIR/.git" ]]; then
        git clone https://github.com/rustdesk/rustdesk.git "$RUSTDESK_DIR"
    else
        git -C "$RUSTDESK_DIR" pull
    fi
    nohup docker build -t rustdesk-builder "$RUSTDESK_DIR" >"$BUILD_LOG" 2>&1 &
    echo $! > "$BUILD_PID_FILE"
    echo "📌 Docker 构建已在后台运行，日志保存在 $BUILD_LOG"
    echo "⏳ 可用 'tail -f $BUILD_LOG' 查看进度"
    read -p "👉 按回车返回主菜单..." dummy
}

install_rustdesk() {
    echo "📦 选择安装方式："
    echo "1) 官方二进制安装（无需 GUI 输入）"
    echo "2) Docker 构建（后台运行，支持 SSH 中断恢复）"
    read -p "请选择 [1-2]: " METHOD

    case $METHOD in
        1) install_official_binary ;;
        2) install_docker ;;
        *) echo "⚠️ 无效选择"; sleep 1 ;;
    esac
}

update_rustdesk() {
    echo "🔄 更新 RustDesk..."
    if command -v rustdesk &>/dev/null; then
        install_official_binary
    elif docker images | grep -q rustdesk-builder; then
        cd "$RUSTDESK_DIR" || exit
        git pull
        docker build -t rustdesk-builder "$RUSTDESK_DIR"
    else
        echo "⚠️ RustDesk 未安装"
    fi
    echo "✅ RustDesk 更新完成"
    read -p "👉 按回车返回主菜单..." dummy
}

uninstall_rustdesk() {
    echo "🗑️ 卸载 RustDesk..."
    rm -f /usr/loc
