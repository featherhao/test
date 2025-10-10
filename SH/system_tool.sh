#!/bin/bash
# system_tool.sh - 系统工具脚本
# 功能: 1. Swap 管理  2. 修改系统主机名  3. VPS 容器/残留服务清理  4. 磁盘占用分析
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

# ===== 磁盘占用分析 =====
disk_usage_analysis() {
    echo -e "\n🟢 VPS 磁盘总览:"
    df -h

    echo -e "\n🟢 各分区目录占用排行（前 10）:"
    for dir in / /var /home /usr /tmp; do
        if [ -d "$dir" ]; then
            echo -e "\n📁 $dir 下的大小:"
            du -h --max-depth=1 "$dir" 2>/dev/null | sort -hr | head -10
        fi
    done

    echo -e "\n🟢 系统安装软件占用排行（前 10）:"
    if command -v dpkg &>/dev/null; then
        dpkg-query -Wf '${Installed-Size}\t${Package}\n' 2>/dev/null | sort -nr | head -10
    elif command -v rpm &>/dev/null; then
        rpm -qa --qf '%{SIZE}\t%{NAME}\n' 2>/dev/null | sort -nr | head -10
    fi

    echo -e "\n🟢 查找大于 500MB 的文件:"
    find / -type f -size +500M -exec ls -lh {} \; 2>/dev/null | awk '{print $5, $9}' | sort -hr | head -20

    if command -v docker &>/dev/null; then
        echo -e "\n🟢 Docker 镜像/容器占用:"
        docker system df
    fi

    echo -e "\n🟢 建议清理目录或文件："
    echo "1. /var/log 下旧日志，可使用 logrotate 或 truncate 清理"
    echo "2. /tmp 下临时文件，可定期删除"
    echo "3. Docker 未使用镜像/悬挂容器，可用: docker system prune -af"
    echo "4. 数据库/缓存文件需谨慎清理，备份后操作"

    echo -e "\n✅ 分析完成！"
    read -p "按回车键返回主菜单..."
}

#=================哪吒监控安装==============
install_nezha() {
    echo "================ 安装哪吒监控 Agent ================"
    curl -L https://raw.githubusercontent.com/nezhahq/scripts/refs/heads/main/install.sh -o /tmp/nezha.sh
    chmod +x /tmp/nezha.sh
    sudo /tmp/nezha.sh
    echo "================ 安装完成 ==========================="
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
        echo "4) 磁盘占用分析"
        echo "5) 安装哪吒监控 Agent"
        echo "0) 退出"
        read -p "请输入选项 [0-4]: " choice

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
            4) disk_usage_analysis ;;
            5) install_nezha ;;
            0) echo "退出"; exit 0 ;;
            *) echo "[WARN] 无效选项";;
        esac
    done
}

# ===== 主程序 =====
menu
