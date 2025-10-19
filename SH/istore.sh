#!/bin/bash
set -e

echo "=============================="
echo " 🚀 iStore 一键安装脚本 (增强版)"
echo "=============================="
echo

# ================== 基础配置 ==================
INSTALL_DIR="/opt/istore"
SERVICE_NAME="istore"
SERVICE_PORT=81
TMP_DIR="/tmp/istore_install"
OFFICIAL_URL="https://raw.githubusercontent.com/istoreos/istoreos-cloud/main/bootstrap.sh"
MIRROR_URL="https://ghproxy.cn/https://raw.githubusercontent.com/istoreos/istoreos-cloud/main/bootstrap.sh"

# ================== 检测架构 ==================
ARCH=$(uname -m)
case "$ARCH" in
    x86_64) ARCH_ALIAS="x86_64" ;;
    aarch64) ARCH_ALIAS="aarch64" ;;
    armv7l) ARCH_ALIAS="armv7" ;;
    *) echo "❌ 未知架构: $ARCH"; exit 1 ;;
esac
echo "✅ 检测到架构: $ARCH_ALIAS"
echo

# ================== 菜单 ==================
echo "请选择操作:"
echo "1) 安装 / 修复 iStore"
echo "2) 卸载 iStore"
echo "3) 退出"
read -rp "请输入选项 [1/2/3, 默认1]: " ACTION
ACTION=${ACTION:-1}
echo

# ================== 安装源选择 ==================
if [ "$ACTION" = "1" ]; then
    echo "请选择安装源:"
    echo "1) 官方源 (GitHub)"
    echo "2) 国内镜像 (ghproxy.cn)"
    read -rp "请输入选项 [1/2, 默认1]: " SOURCE_CHOICE
    SOURCE_CHOICE=${SOURCE_CHOICE:-1}

    if [ "$SOURCE_CHOICE" = "2" ]; then
        BOOTSTRAP_URL="$MIRROR_URL"
    else
        BOOTSTRAP_URL="$OFFICIAL_URL"
    fi

    echo "📦 下载并执行 iStore 官方安装脚本..."
    echo "👉 来源: $BOOTSTRAP_URL"
    echo

    mkdir -p "$TMP_DIR"
    cd "$TMP_DIR"

    curl -fsSL "$BOOTSTRAP_URL" -o bootstrap.sh
    chmod +x bootstrap.sh

    echo "⚙️ 运行安装脚本..."
    bash bootstrap.sh

    echo
    echo "✅ iStore 安装完成！"
    echo "🌐 请访问: http://$(hostname -I | awk '{print $1}'):$SERVICE_PORT"
    echo "🔧 默认账号: admin / password"
    echo
    exit 0
fi

# ================== 卸载逻辑 ==================
if [ "$ACTION" = "2" ]; then
    echo "⚠️ 确认要卸载 iStore 吗？此操作将删除所有相关文件。"
    read -rp "输入 Y 确认卸载: " CONFIRM
    if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
        echo "🧹 正在卸载 iStore..."
        systemctl stop "$SERVICE_NAME" 2>/dev/null || true
        systemctl disable "$SERVICE_NAME" 2>/dev/null || true
        rm -rf /etc/systemd/system/${SERVICE_NAME}.service
        rm -rf "$INSTALL_DIR"
        rm -rf "$TMP_DIR"
        echo "✅ iStore 已彻底卸载。"
    else
        echo "操作已取消。"
    fi
    exit 0
fi

echo "已退出脚本。"
