#!/bin/bash
set -e

# 配置
RUSTDESK_DOCKER_REPO="https://github.com/rustdesk/rustdesk"
RUSTDESK_SCRIPT_URL="https://raw.githubusercontent.com/featherhao/test/refs/heads/main/install_rustdesk.sh"
RUSTDESK_DIR="$HOME/rustdesk"
DOCKER_DNS="8.8.8.8"  # Google 公共 DNS，可修改为你自己的 DNS
BUILD_LOG="$RUSTDESK_DIR/build.log"

check_requirements() {
    command -v curl >/dev/null 2>&1 || { echo "⚠️ 请先安装 curl"; exit 1; }
    command -v git >/dev/null 2>&1 || { echo "⚠️ 请先安装 git"; exit 1; }
    command -v docker >/dev/null 2>&1 || { echo "⚠️ 请先安装 docker"; exit 1; }
}

install_rustdesk() {
    echo "📦 选择安装方式："
    echo "1) 官方安装脚本"
    echo "2) Docker 构建（后台运行，完成后提醒）"
    read -rp "请选择 [1-2]: " method
    case $method in
        1)
            echo "📥 下载并执行官方安装脚本..."
            bash <(curl -fsSL "$RUSTDESK_SCRIPT_URL")
            echo "✅ RustDesk 安装完成"
            ;;
        2)
            echo "🐳 使用 Docker 构建 RustDesk..."
            if [ ! -d "$RUSTDESK_DIR" ]; then
                echo "📥 克隆 RustDesk 仓库..."
                git clone "$RUSTDESK_DOCKER_REPO" "$RUSTDESK_DIR"
            else
                echo "🔄 更新 RustDesk 仓库..."
                cd "$RUSTDESK_DIR"
                git fetch --all
                git reset --hard origin/master
            fi
            cd "$RUSTDESK_DIR"
            git submodule update --init --recursive

            echo "🔧 后台构建 Docker 镜像..."
            nohup bash -c "
docker build --network=host -t rustdesk-builder . &&
echo '✅ Docker 镜像构建完成！' | tee -a $BUILD_LOG &&
echo '🚀 你可以运行以下命令启动 RustDesk 构建容器:' | tee -a $BUILD_LOG &&
echo 'docker run --rm -it --network=host -v \$PWD:/home/user/rustdesk -v rustdesk-git-cache:/home/user/.cargo/git -v rustdesk-registry-cache:/home/user/.cargo/registry -e PUID=\$(id -u) -e PGID=\$(id -g) rustdesk-builder' | tee -a $BUILD_LOG &&
if command -v notify-send >/dev/null 2>&1; then
    notify-send 'RustDesk Docker 构建完成' '可以运行 RustDesk 容器了'
fi
" > "$BUILD_LOG" 2>&1 &
            echo "📌 Docker 构建已在后台运行，日志保存在 $BUILD_LOG"
            echo "⏳ 可以用 'tail -f $BUILD_LOG' 查看进度"
            ;;
        *)
            echo "⚠️ 无效选项"
            ;;
    esac
}

update_rustdesk() {
    echo "🔄 更新 RustDesk（执行官方脚本即可）..."
    bash <(curl -fsSL "$RUSTDESK_SCRIPT_URL")
    echo "✅ RustDesk 更新完成"
}

uninstall_rustdesk() {
    echo "🗑️ 卸载 RustDesk..."
    sudo rm -f /usr/local/bin/rustdesk /usr/bin/rustdesk
    echo "✅ RustDesk 已卸载"
}

show_menu() {
    echo "============================"
    echo "      RustDesk 管理脚本     "
    echo "============================"
    echo "1) 安装 RustDesk"
    echo "2) 更新 RustDesk"
    echo "3) 卸载 RustDesk"
    echo "4) 退出"
    echo -n "请选择操作 [1-4]: "
}

check_requirements

while true; do
    show_menu
    read -r choice
    case $choice in
        1) install_rustdesk ;;
        2) update_rustdesk ;;
        3) uninstall_rustdesk ;;
        4) echo "退出"; exit 0 ;;
        *) echo "⚠️ 无效选项，请输入 1-4" ;;
    esac
done
