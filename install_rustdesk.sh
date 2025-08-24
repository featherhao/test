#!/bin/bash
set -e

# 配置
RUSTDESK_SCRIPT_URL="https://raw.githubusercontent.com/featherhao/test/refs/heads/main/install_rustdesk.sh"
RUSTDESK_DIR="$HOME/rustdesk"
BUILD_LOG="$RUSTDESK_DIR/build.log"
BUILD_PID_FILE="$RUSTDESK_DIR/build.pid"
BUILD_DONE_FLAG="$RUSTDESK_DIR/build_done.flag"
RUSTDESK_DOCKER_REPO="https://github.com/rustdesk/rustdesk"

check_requirements() {
    command -v curl >/dev/null 2>&1 || { echo "⚠️ 请先安装 curl"; exit 1; }
    command -v git >/dev/null 2>&1 || { echo "⚠️ 请先安装 git"; exit 1; }
    command -v docker >/dev/null 2>&1 || { echo "⚠️ 请先安装 docker"; exit 1; }
    command -v sudo >/dev/null 2>&1 || { echo "⚠️ 请先安装 sudo"; exit 1; }
}

# 改进后的安装状态检测
get_rustdesk_status() {
    if command -v rustdesk >/dev/null 2>&1 || \
       [ -f "/usr/local/bin/rustdesk" ] || \
       [ -f "/usr/bin/rustdesk" ] || \
       [ -f "$HOME/.local/bin/rustdesk" ]; then
        echo "已安装 ✅"
    else
        echo "未安装 ❌"
    fi
}

install_rustdesk() {
    echo "📦 选择安装方式："
    echo "1) 官方安装脚本"
    echo "2) Docker 构建（后台运行，支持 SSH 中断恢复）"
    read -rp "请选择 [1-2]: " method
    case $method in
        1)
            echo "📥 执行官方安装脚本安装 RustDesk..."
            bash <(curl -fsSL "$RUSTDESK_SCRIPT_URL")
            echo "✅ RustDesk 安装完成"
            # 等待用户确认再返回菜单
            read -rp "按回车键返回主菜单..." _
            ;;
        2)
            mkdir -p "$RUSTDESK_DIR"
            cd "$RUSTDESK_DIR"

            if [ -f "$BUILD_DONE_FLAG" ]; then
                echo "✅ 上次 Docker 构建已完成"
                return
            fi

            if [ -f "$BUILD_PID_FILE" ]; then
                PID=$(cat "$BUILD_PID_FILE")
                if kill -0 "$PID" 2>/dev/null; then
                    echo "⏳ Docker 构建正在进行中，日志: $BUILD_LOG"
                    return
                fi
            fi

            # 克隆或更新仓库
            if [ ! -d "$RUSTDESK_DIR/.git" ]; then
                echo "📥 克隆 RustDesk 仓库..."
                git clone "$RUSTDESK_DOCKER_REPO" "$RUSTDESK_DIR"
            else
                echo "🔄 更新 RustDesk 仓库..."
                git fetch --all
                git reset --hard origin/master
            fi
            git submodule update --init --recursive

            # 后台构建
            echo "🔧 后台构建 Docker 镜像..."
            nohup bash -c "
docker build --network=host -t rustdesk-builder . > $BUILD_LOG 2>&1 &&
touch $BUILD_DONE_FLAG &&
echo '✅ Docker 构建完成！' | tee -a $BUILD_LOG &&
echo '🚀 可运行 RustDesk 容器:' | tee -a $BUILD_LOG &&
echo 'docker run --rm -it --network=host -v \$PWD:/home/user/rustdesk -v rustdesk-git-cache:/home/user/.cargo/git -v rustdesk-registry-cache:/home/user/.cargo/registry -e PUID=\$(id -u) -e PGID=\$(id -g) rustdesk-builder' | tee -a $BUILD_LOG &&
if command -v notify-send >/dev/null 2>&1; then
    notify-send 'RustDesk Docker 构建完成' '可以运行 RustDesk 容器了'
fi
" &
            echo $! > "$BUILD_PID_FILE"
            rm -f "$BUILD_DONE_FLAG"
            echo "📌 Docker 构建已在后台运行，日志: $BUILD_LOG"
            ;;
        *)
            echo "⚠️ 无效选项"
            ;;
    esac
}

cancel_docker_build() {
    if [ -f "$BUILD_PID_FILE" ]; then
        PID=$(cat "$BUILD_PID_FILE")
        if kill -0 "$PID" 2>/dev/null; then
            kill -9 "$PID"
            echo "🛑 Docker 构建已取消"
        else
            echo "⚠️ Docker 构建进程不存在"
        fi
        rm -f "$BUILD_PID_FILE" "$BUILD_DONE_FLAG" "$BUILD_LOG"
    else
        echo "⚠️ 没有正在进行的 Docker 构建"
    fi
}

update_rustdesk() {
    echo "🔄 更新 RustDesk（官方安装脚本）..."
    bash <(curl -fsSL "$RUSTDESK_SCRIPT_URL")
    echo "✅ RustDesk 更新完成"
}

uninstall_rustdesk() {
    echo "🗑️ 卸载 RustDesk..."
    # 删除所有可能安装位置
    sudo rm -f "/usr/local/bin/rustdesk" "/usr/bin/rustdesk" "$HOME/.local/bin/rustdesk"
    echo "✅ RustDesk 已卸载"
}

show_menu() {
    echo "============================"
    echo "      RustDesk 管理脚本     "
    echo "============================"

    # RustDesk 安装状态
    echo "当前状态: $(get_rustdesk_status)"

    # 构建状态提示（不阻塞菜单）
    if [ -f "$BUILD_PID_FILE" ]; then
        PID=$(cat "$BUILD_PID_FILE")
        if kill -0 "$PID" 2>/dev/null; then
            echo "⏳ Docker 构建正在进行中，日志: $BUILD_LOG"
        else
            rm -f "$BUILD_PID_FILE"
        fi
    fi
    if [ -f "$BUILD_DONE_FLAG" ]; then
        echo "✅ Docker 构建已完成！"
        echo "🚀 可运行 RustDesk 容器:"
        echo "docker run --rm -it --network=host -v \$PWD:/home/user/rustdesk -v rustdesk-git-cache:/home/user/.cargo/git -v rustdesk-registry-cache:/home/user/.cargo/registry -e PUID=\$(id -u) -e PGID=\$(id -g) rustdesk-builder"
    fi

    echo "1) 安装 RustDesk"
    echo "2) 更新 RustDesk"
    echo "3) 卸载 RustDesk"
    echo "4) 取消正在构建 Docker"
    echo "5) 退出"
    echo -n "请选择操作 [1-5]: "
}

check_requirements

while true; do
    show_menu
    read -r choice
    case $choice in
        1) install_rustdesk ;;
        2) update_rustdesk ;;
        3) uninstall_rustdesk ;;
        4) cancel_docker_build ;;
        5) echo "退出"; exit 0 ;;
        *) echo "⚠️ 无效选项，请输入 1-5" ;;
    esac
done
