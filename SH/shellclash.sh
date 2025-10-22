#!/bin/bash
set -eo pipefail

# ShellClash 官方安装链接
CLASH_INSTALL_URL="https://raw.githubusercontent.com/juewuy/ShellClash/master/install.sh"
# ShellClash 默认的启动命令或路径（安装后系统会自动创建 shellclash 命令）
CLASH_EXEC_CMD="shellclash"
# 默认的安装目录（官方脚本默认路径，用于卸载）
CLASH_INSTALL_DIR="/etc/openclash"

echo "=========================================="
echo "      ShellClash 菜单式管理脚本           "
echo "=========================================="

# 检查当前用户权限
if [[ $EUID -ne 0 ]]; then
    SUDO_CMD="sudo"
else
    SUDO_CMD=""
fi

# 检查 ShellClash 是否已安装
is_installed() {
    if command -v "$CLASH_EXEC_CMD" &> /dev/null || [ -d "$CLASH_INSTALL_DIR" ]; then
        return 0 # 已安装
    else
        return 1 # 未安装
    fi
}

# ================== 功能函数 ==================

install_shellclash() {
    echo "=========================================="
    echo "         1) 安装 ShellClash"
    echo "=========================================="

    if is_installed; then
        echo "✅ ShellClash 已安装。若需重新安装，请先选择 '卸载'。"
        return
    fi

    echo "[*] 正在从官方源下载并执行安装脚本..."
    echo "[*] 安装过程中，请按提示选择安装目录和 Clash 内核。"

    if $SUDO_CMD bash <(curl -fsSL "$CLASH_INSTALL_URL"); then
        echo ""
        echo "------------------------------------------"
        echo "✅ ShellClash 安装成功！"
        echo "------------------------------------------"
        
        # 尝试启动菜单，引导用户初始化
        echo "[*] 正在启动首次配置菜单..."
        if command -v "$CLASH_EXEC_CMD" &> /dev/null; then
            $SUDO_CMD "$CLASH_EXEC_CMD"
        elif [ -f "$CLASH_INSTALL_DIR/clash.sh" ]; then
             $SUDO_CMD "$CLASH_INSTALL_DIR/clash.sh"
        else
            echo "⚠️ 无法自动启动菜单。请手动执行 'shellclash' 或 '/etc/openclash/clash.sh'。"
        fi

    else
        echo "❌ ShellClash 安装失败。请检查网络和依赖（如 curl）。"
    fi
}

uninstall_shellclash() {
    echo "=========================================="
    echo "         2) 卸载 ShellClash"
    echo "=========================================="

    if ! is_installed; then
        echo "⚠️ ShellClash 未安装。"
        return
    fi

    echo "[*] 警告：这将删除所有配置文件和内核！"
    echo -n "确定要卸载 ShellClash 吗? (y/N): "
    read confirmation

    if [[ "$confirmation" =~ ^[Yy]$ ]]; then
        # 官方卸载方法是运行安装目录下的 unistall.sh 脚本
        if [ -f "$CLASH_INSTALL_DIR/uninstall.sh" ]; then
            $SUDO_CMD "$CLASH_INSTALL_DIR/uninstall.sh"
            echo "✅ ShellClash 已成功卸载。"
        else
            echo "❌ 卸载脚本未找到。请手动删除 $CLASH_INSTALL_DIR 目录。"
        fi
    else
        echo "操作已取消。"
    fi
}

update_shellclash() {
    echo "=========================================="
    echo "         3) 更新 ShellClash"
    echo "=========================================="

    if ! is_installed; then
        echo "⚠️ ShellClash 未安装，请先安装。"
        return
    fi
    
    # 官方更新方法是启动菜单后选择更新
    echo "[*] 正在启动 ShellClash 菜单，请选择 'u' 或 'g' 选项进行更新。"

    if command -v "$CLASH_EXEC_CMD" &> /dev/null; then
        $SUDO_CMD "$CLASH_EXEC_CMD"
    elif [ -f "$CLASH_INSTALL_DIR/clash.sh" ]; then
         $SUDO_CMD "$CLASH_INSTALL_DIR/clash.sh"
    else
        echo "❌ 无法启动 ShellClash 菜单进行更新。请检查安装路径。"
    fi
}

show_info() {
    echo "=========================================="
    echo "         4) 查看 ShellClash 状态"
    echo "=========================================="

    if ! is_installed; then
        echo "状态: ❌ 未安装"
        return
    fi

    echo "状态: ✅ 已安装"
    echo "执行命令: shellclash 或 $CLASH_INSTALL_DIR/clash.sh"
    echo "核心版本:"
    # 尝试启动菜单并显示状态（通过官方脚本显示）
    if command -v "$CLASH_EXEC_CMD" &> /dev/null; then
        $SUDO_CMD "$CLASH_EXEC_CMD" status
    elif [ -f "$CLASH_INSTALL_DIR/clash.sh" ]; then
         $SUDO_CMD "$CLASH_INSTALL_DIR/clash.sh" status
    else
        echo "❌ 无法获取状态信息。"
    fi
    echo "------------------------------------------"
    echo "Web 面板（如果已启用）: 通常是 http://<您的IP>:9090/ui"
}

# ================== 主菜单 ==================
while true; do
    echo "=========================================="
    echo "请选择操作:"
    echo "1) 安装 ShellClash (首次安装)"
    echo "2) 卸载 ShellClash (移除所有文件)"
    echo "3) 更新 ShellClash (进入菜单选择 u 或 g)"
    echo "4) 查看信息 (显示安装状态和版本)"
    echo "5) 启动 ShellClash 菜单 (高级配置/运行)"
    echo "6) 退出"

    echo -n "请输入选择 [1-6]: "
    read choice

    case "$choice" in
        1) install_shellclash ;;
        2) uninstall_shellclash ;;
        3) update_shellclash ;;
        4) show_info ;;
        5) 
            if is_installed; then
                $SUDO_CMD "$CLASH_EXEC_CMD"
            else
                echo "⚠️ ShellClash 未安装，请先选择 '安装'。"
            fi
            ;;
        6) exit 0 ;;
        *) echo "⚠️ 无效选择，请重新输入" ;;
    esac
done