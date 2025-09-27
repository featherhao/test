#!/bin/bash
# system_tool.sh - 系统工具脚本
# 功能: 1. Swap 管理  2. 修改系统主机名  3. VPS 容器/残留服务清理
# 用法: sudo bash system_tool.sh

set -e

SWAPFILE="/swapfile"

# ===== 内存与 Swap =====
show_swap() {
    echo "================= 内存使用情况 ================="
    free -h
    echo
    echo "================= 当前 Swap 状态 ================="
    if swapon --show | grep -q "$SWAPFILE"; then
        SIZE=$(swapon --show --bytes | awk -v f="$SWAPFILE" '$1==f {printf "%.1fG", $3/1024/1024/1024}')
        echo "Swap 已开启: $SWAPFILE, 大小 $SIZE"
    else
        echo "Swap 未开启"
    fi
    echo "================================================="
    echo
}

create_swap() {
    SIZE=$1
    echo "[INFO] 设置 Swap 大小为 $SIZE"

    if swapon --show | grep -q "$SWAPFILE"; then
        echo "[INFO] 关闭旧的 swap..."
        swapoff $SWAPFILE
    fi

    if [ -f "$SWAPFILE" ]; then
        echo "[INFO] 删除旧的 swap 文件..."
        rm -f $SWAPFILE
    fi

    echo "[INFO] 创建新的 swap 文件..."
    fallocate -l $SIZE $SWAPFILE || dd if=/dev/zero of=$SWAPFILE bs=1M count=${SIZE%G*}k
    chmod 600 $SWAPFILE
    mkswap $SWAPFILE
    swapon $SWAPFILE

    if ! grep -q "$SWAPFILE" /etc/fstab; then
        echo "$SWAPFILE none swap sw 0 0" >> /etc/fstab
    fi

    echo "[OK] Swap 修改完成"
    show_swap
}

# ===== 系统改名 =====
show_hostname() {
    echo "当前主机名: $(hostname)"
}

change_hostname() {
    read -p "请输入新的主机名: " NEWNAME
    if [ -z "$NEWNAME" ]; then
        echo "[WARN] 主机名不能为空"
        return
    fi
    echo "[INFO] 修改主机名为 $NEWNAME"
    hostnamectl set-hostname "$NEWNAME"
    echo "[OK] 主机名修改完成，重启后完全生效"
    show_hostname
}

# ===== VPS 清理 =====
CLEAN_VPS_SCRIPT="https://raw.githubusercontent.com/featherhao/test/refs/heads/main/SH/clean_vps.sh"

clean_vps() {
    echo "[INFO] 正在执行 VPS 容器/残留服务清理..."
    bash <(curl -fsSL "${CLEAN_VPS_SCRIPT}?t=$(date +%s)")
    echo "[OK] 清理完成"
}

# ===== 菜单 =====
menu() {
    while true; do
        echo "================= 系统工具脚本 ================="
        show_swap
        show_hostname
        echo "请选择操作:"
        echo "1) Swap 管理"
        echo "2) 修改系统主机名"
        echo "3) VPS 容器/残留服务清理"
        echo "0) 退出"
        read -p "请输入选项 [0-3]: " choice

        case "$choice" in
            1)
                echo "----- Swap 管理 -----"
                echo "1) 设置 Swap 1G"
                echo "2) 设置 Swap 2G"
                echo "3) 设置 Swap 4G"
                echo "4) 自定义 Swap 大小"
                echo "5) 查看 Swap 状态"
                echo "0) 返回主菜单"
                read -p "请输入选项 [0-5]: " swap_choice
                case "$swap_choice" in
                    1) create_swap 1G ;;
                    2) create_swap 2G ;;
                    3) create_swap 4G ;;
                    4) read -p "请输入大小(例如 3G 或 512M): " SIZE; create_swap $SIZE ;;
                    5) show_swap ;;
                    0) continue ;;
                    *) echo "[WARN] 无效选项";;
                esac
                ;;
            2) change_hostname ;;
            3) clean_vps ;;
            0) echo "退出"; exit 0 ;;
            *) echo "[WARN] 无效选项";;
        esac
    done
}

# ===== 主程序 =====
menu
