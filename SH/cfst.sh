#!/bin/bash

# 定义安装路径
INSTALL_DIR="/root/cfst"
DOWNLOAD_URL="https://github.com/XIU2/CloudflareSpeedTest/releases/latest/download/cfst_linux_arm64.tar.gz"

# 字体颜色定义
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # 无颜色

# 检查是否安装
check_status() {
    if [ -f "$INSTALL_DIR/cfst" ]; then
        return 0 # 已安装
    else
        return 1 # 未安装
    fi
}

# 安装功能
install_cfst() {
    if check_status; then
        echo -e "${YELLOW}[!] CloudflareSpeedTest 已经安装在 $INSTALL_DIR，无需重复安装。${NC}"
        return
    fi

    echo -e "${GREEN}[+] 正在创建安装目录: $INSTALL_DIR${NC}"
    mkdir -p "$INSTALL_DIR"
    cd "$INSTALL_DIR" || exit 1

    echo -e "${GREEN}[+] 正在下载最新版 CloudflareSpeedTest...${NC}"
    wget -N "$DOWNLOAD_URL"
    if [ $? -ne 0 ]; then
        echo -e "${RED}[-] 下载失败，请检查网络！${NC}"
        return 1
    fi

    echo -e "${GREEN}[+] 正在解压...${NC}"
    tar -zxf cfst_linux_arm64.tar.gz

    echo -e "${GREEN}[+] 正在赋予执行权限...${NC}"
    chmod +x cfst

    echo -e "${GREEN}[√] 安装完成！主程序路径: $INSTALL_DIR/cfst${NC}"
}

# 运行测速 (区域选择)
run_cfst() {
    if ! check_status; then
        echo -e "${RED}[-] 未检测到程序，请先选择 1 进行安装！${NC}"
        return 1
    fi

    cd "$INSTALL_DIR" || exit 1

    echo -e "\n${BLUE}=============================================${NC}"
    echo -e "         🌐 请选择你要测速的区域"
    echo -e "${BLUE}=============================================${NC}"
    echo " 1. 全球节点 (默认全部随机测试)"
    echo " 2. 仅中国香港节点 (低延迟)"
    echo " 3. 仅日本节点 (东京/大阪)"
    echo " 4. 仅美西节点 (洛杉矶/圣假塞/西雅图)"
    echo " 0. 返回上一级菜单"
    echo -e "${BLUE}=============================================${NC}"
    read -p "请选择区域 [0-4]: " region_num

    case "$region_num" in
        1)
            echo -e "${GREEN}[+] 开始运行全球节点测速...${NC}"
            ./cfst -tp 443 -tl 180 -dn 5 -dt 15
            ;;
        2)
            echo -e "${GREEN}[+] 开始运行仅中国香港(HKG)节点测速...${NC}"
            ./cfst -tp 443 -cfcolo HKG -tl 180 -dn 5 -dt 15
            ;;
        3)
            echo -e "${GREEN}[+] 开始运行仅日本(NRT,KIX)节点测速...${NC}"
            ./cfst -tp 443 -cfcolo NRT,KIX -tl 180 -dn 5 -dt 15
            ;;
        4)
            echo -e "${GREEN}[+] 开始运行仅美西(LAX,SJC,SEA)节点测速...${NC}"
            ./cfst -tp 443 -cfcolo LAX,SJC,SEA -tl 180 -dn 5 -dt 15
            ;;
        0)
            return
            ;;
        *)
            echo -e "${RED}[-] 输入错误，默认运行全球节点测速...${NC}"
            ./cfst -tp 443 -tl 180 -dn 5 -dt 15
            ;;
    esac
}

# 【特加功能】全明星高带宽专属扫描 (整合 162.159 / 104.28 / 188.114)
run_special_high_speed() {
    if ! check_status; then
        echo -e "${RED}[-] 未检测到程序，请先选择 1 进行安装！${NC}"
        return 1
    fi

    cd "$INSTALL_DIR" || exit 1
    echo -e "\n${GREEN}[+] 启动全明星高带宽专属网段扫描...${NC}"
    echo -e "${YELLOW}提示: 强力扫描 162.159 / 104.28 / 188.114 等 WARP 及官方特殊吞吐段，单线程极易破 10M+ 带宽。${NC}"
    
    # 强制将多个高带宽网段组合传入进行精细测试
    ./cfst -ip "162.159.0.0/16,104.28.0.0/16,188.114.96.0/20" -tp 443 -tl 200 -dn 8 -dt 15
}

# 指定单个 IP 测速
run_single_ip_cfst() {
    if ! check_status; then
        echo -e "${RED}[-] 未检测到程序，请先选择 1 进行安装！${NC}"
        return 1
    fi

    cd "$INSTALL_DIR" || exit 1
    
    echo -e "\n${BLUE}=============================================${NC}"
    echo -e "         🎯 指定单个 IP 测速"
    echo -e "${BLUE}=============================================${NC}"
    read -p "请输入要测试的 Cloudflare IP (例如 104.25.255.205): " target_ip

    if [ -z "$target_ip" ]; then
        echo -e "${RED}[-] IP 不能为空，已取消单点测速。${NC}"
        return 1
    fi

    echo -e "${GREEN}[+] 开始点名测试单个 IP: $target_ip${NC}"
    ./cfst -ip "$target_ip" -tp 443 -dt 15
}

# 卸载功能
uninstall_cfst() {
    if ! check_status; then
        echo -e "${YELLOW}[!] 系统中未检测到已安装的 CloudflareSpeedTest，无需卸载。${NC}"
        return
    fi

    read -p "确定要完全卸载并删除 $INSTALL_DIR 目录吗？(y/n): " confirm
    if [[ "$confirm" == [yY] || "$confirm" == [yY][eE][sS] ]]; then
        rm -rf "$INSTALL_DIR"
        echo -e "${GREEN}[√] 卸载成功，所有相关文件已清除。${NC}"
    else
        echo -e "${YELLOW}[*] 已取消卸载。${NC}"
    fi
}

# 主菜单界面
main_menu() {
    clear
    echo "============================================="
    echo "    CloudflareSpeedTest 交互式管理脚本      "
    echo "============================================="
    if check_status; then
        echo -e "当前状态: ${GREEN}已安装${NC}"
    else
        echo -e "当前状态: ${RED}未安装${NC}"
    fi
    echo "---------------------------------------------"
    echo " 1. 安装 CloudflareSpeedTest"
    echo " 2. 运行 优选测速 (可自选区域)"
    echo " 3. 运行 高带宽专项测速 (全明星 10M+ 极品段)"
    echo " 4. 指定单个 IP 测速 (点名测试)"
    echo " 5. 卸载 CloudflareSpeedTest"
    echo " 0. 退出脚本"
    echo "============================================="
    read -p "请选择操作 [0-5]: " num

    case "$num" in
        1) install_cfst ;;
        2) run_cfst ;;
        3) run_special_high_speed ;;
        4) run_single_ip_cfst ;;
        5) uninstall_cfst ;;
        0) exit 0 ;;
        *)
            echo -e "${RED}[-] 输入错误，请输入正确的数字！${NC}"
            sleep 1
            main_menu
            ;;
    esac
}

# 循环执行菜单
while true; do
    main_menu
    echo ""
    read -p "按回车键返回主菜单..." dummy
done
