#!/bin/bash

# 定义安装路径（可根据需要修改）
INSTALL_DIR="$HOME/cfst"
DOWNLOAD_URL="https://github.com/XIU2/CloudflareSpeedTest/releases/latest/download/cfst_linux_arm64.tar.gz"
# 国内加速镜像备选（如果需要默认国内加速，取消下面这行的注释即可）
#DOWNLOAD_URL="https://ghfast.top/https://github.com/XIU2/CloudflareSpeedTest/releases/latest/download/cfst_linux_arm64.tar.gz"

# 字体颜色定义
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
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
        echo -e "${RED}[-] 下载失败，请检查网络或更换加速镜像链接！${NC}"
        return 1
    fi

    echo -e "${GREEN}[+] 正在解压...${NC}"
    tar -zxf cfst_linux_amd64.tar.gz

    echo -e "${GREEN}[+] 正在赋予执行权限...${NC}"
    chmod +x cfst

    echo -e "${GREEN}[√] 安装完成！主程序路径: $INSTALL_DIR/cfst${NC}"
}

# 运行测速
run_cfst() {
    if ! check_status; then
        echo -e "${RED}[-] 未检测到程序，请先选择 1 进行安装！${NC}"
        return 1
    fi

    cd "$INSTALL_DIR" || exit 1
    echo -e "${GREEN}[+] 开始运行 CloudflareSpeedTest...${NC}"
    echo -e "${YELLOW}提示: 默认运行常用优选参数 (-tp 443 -tl 200 -dn 10)${NC}"
    ./cfst -tp 443 -tl 200 -dn 10
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
    echo " 2. 运行 优选测速"
    echo " 3. 卸载 CloudflareSpeedTest"
    echo " 0. 退出脚本"
    echo "============================================="
    read -p "请选择操作 [0-3]: " num

    case "$num" in
        1)
            install_cfst
            ;;
        2)
            run_cfst
            ;;
        3)
            uninstall_cfst
            ;;
        0)
            exit 0
            ;;
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
