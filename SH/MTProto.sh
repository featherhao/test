#!/bin/bash
###
 # @Author: Vincent Young (中文化 & 增强版 by ChatGPT)
 # @Date: 2022-07-01
 # @LastEditors: ChatGPT
 # @FilePath: /MTProxy/mtproxy.sh
 # 
 # Copyright © 2022 by Vincent, All Rights Reserved.
### 

PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

# 定义颜色
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

# 必须使用 root 运行
[[ $EUID -ne 0 ]] && echo -e "[${red}错误${plain}] 请使用 root 用户运行该脚本！" && exit 1

# 显示连接信息
show_info(){
    if [[ -f "/etc/mtg.toml" ]]; then
        port=$(grep 'bind-to' /etc/mtg.toml | sed -E 's/.*:([0-9]+).*/\1/')
        secret=$(grep 'secret' /etc/mtg.toml | sed -E 's/.*"([^"]+)".*/\1/')
        public_ip=$(curl -s ipv4.ip.sb)
        subscription_config="tg://proxy?server=${public_ip}&port=${port}&secret=${secret}"
        subscription_link="https://t.me/proxy?server=${public_ip}&port=${port}&secret=${secret}"
        echo -e "\n========== MTProxy 当前配置信息 =========="
        echo -e "服务器IP   : ${green}${public_ip}${plain}"
        echo -e "监听端口   : ${green}${port}${plain}"
        echo -e "Secret     : ${green}${secret}${plain}"
        echo -e "TG 配置链接: ${yellow}${subscription_config}${plain}"
        echo -e "一键链接   : ${yellow}${subscription_link}${plain}"
        echo -e "=========================================\n"
    else
        echo -e "${red}未检测到配置文件 /etc/mtg.toml${plain}"
    fi
}

download_file(){
	echo "检查系统架构..."

	bit=`uname -m`
	if [[ ${bit} = "x86_64" ]]; then
		bit="amd64"
    elif [[ ${bit} = "aarch64" ]]; then
        bit="arm64"
    else
	    bit="386"
    fi

    last_version=$(curl -Ls "https://api.github.com/repos/9seconds/mtg/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    if [[ ! -n "$last_version" ]]; then
        echo -e "${red}获取 mtg 最新版本失败，可能是 Github API 限制，请稍后再试。${plain}"
        exit 1
    fi
    echo -e "检测到 mtg 最新版本: ${last_version}，开始安装..."
    version=$(echo ${last_version} | sed 's/v//g')
    wget -N --no-check-certificate -O mtg-${version}-linux-${bit}.tar.gz https://github.com/9seconds/mtg/releases/download/${last_version}/mtg-${version}-linux-${bit}.tar.gz
    if [[ ! -f "mtg-${version}-linux-${bit}.tar.gz" ]]; then
        echo -e "${red}下载 mtg-${version}-linux-${bit}.tar.gz 失败，请重试。${plain}"
        exit 1
    fi
    tar -xzf mtg-${version}-linux-${bit}.tar.gz
    mv mtg-${version}-linux-${bit}/mtg /usr/bin/mtg
    rm -f mtg-${version}-linux-${bit}.tar.gz
    rm -rf mtg-${version}-linux-${bit}
    chmod +x /usr/bin/mtg
    echo -e "mtg 安装完成，开始配置..."
}

configure_mtg(){
    echo -e "配置 mtg..."
    wget -N --no-check-certificate -O /etc/mtg.toml https://raw.githubusercontent.com/missuo/MTProxy/main/mtg.toml
    
    echo ""
    read -p "请输入伪装域名 (默认 itunes.apple.com): " domain
	[ -z "${domain}" ] && domain="itunes.apple.com"

	echo ""
    read -p "请输入监听端口 (默认 8443): " port
	[ -z "${port}" ] && port="8443"

    secret=$(mtg generate-secret --hex $domain)
    
    echo "正在写入配置..."

    sed -i "s/secret.*/secret = \"${secret}\"/g" /etc/mtg.toml
    sed -i "s/bind-to.*/bind-to = \"0.0.0.0:${port}\"/g" /etc/mtg.toml

    echo "mtg 配置完成，开始写入 systemctl 服务..."
}

configure_systemctl(){
    echo -e "配置 systemctl..."
    wget -N --no-check-certificate -O /etc/systemd/system/mtg.service https://raw.githubusercontent.com/missuo/MTProxy/main/mtg.service
    systemctl enable mtg
    systemctl start mtg
    echo "防火墙处理..."
    systemctl disable firewalld 2>/dev/null
    systemctl stop firewalld 2>/dev/null
    ufw disable 2>/dev/null
    echo "mtg 已启动！"
    show_info
}

change_port(){
    read -p "请输入要修改的端口 (默认 8443): " port
	[ -z "${port}" ] && port="8443"
    sed -i "s/bind-to.*/bind-to = \"0.0.0.0:${port}\"/g" /etc/mtg.toml
    echo "正在重启 MTProxy..."
    systemctl restart mtg
    echo "端口修改成功，MTProxy 已重启！"
    show_info
}

change_secret(){
    echo -e "注意：随意修改 Secret 可能导致 MTProxy 无法正常使用。"
    read -p "请输入要修改的 Secret (留空则自动生成): " secret
	[ -z "${secret}" ] && secret="$(mtg generate-secret --hex itunes.apple.com)"
    sed -i "s/secret.*/secret = \"${secret}\"/g" /etc/mtg.toml
    echo "Secret 修改成功！"
    echo "正在重启 MTProxy..."
    systemctl restart mtg
    echo "MTProxy 已重启！"
    show_info
}

update_mtg(){
    echo -e "正在更新 mtg..."
    download_file
    echo "更新完成，正在重启 MTProxy..."
    systemctl restart mtg
    echo "MTProxy 已更新并重启！"
    show_info
}

start_menu() {
    clear
    echo -e "  MTProxy v2 一键管理脚本
---- by Vincent | github.com/missuo/MTProxy ----
 ${green} 1.${plain} 安装 MTProxy
 ${green} 2.${plain} 卸载 MTProxy
————————————
 ${green} 3.${plain} 启动 MTProxy
 ${green} 4.${plain} 停止 MTProxy
 ${green} 5.${plain} 重启 MTProxy
 ${green} 6.${plain} 修改监听端口
 ${green} 7.${plain} 修改 Secret
 ${green} 8.${plain} 更新 MTProxy
————————————
 ${green} 9.${plain} 查看配置信息
————————————
 ${green} 0.${plain} 退出
————————————" && echo

    read -e -p "请输入选项 [0-9]: " num
    case "$num" in
    1)
        download_file
        configure_mtg
        configure_systemctl
        ;;
    2)
        echo "正在卸载 MTProxy..."
        systemctl stop mtg
        systemctl disable mtg
        rm -rf /usr/bin/mtg
        rm -rf /etc/mtg.toml
        rm -rf /etc/systemd/system/mtg.service
        echo "MTProxy 卸载成功！"
        ;;
    3) 
        echo "正在启动 MTProxy..."
        systemctl start mtg
        systemctl enable mtg
        echo "MTProxy 启动成功！"
        show_info
        ;;
    4) 
        echo "正在停止 MTProxy..."
        systemctl stop mtg
        systemctl disable mtg
        echo "MTProxy 已停止！"
        ;;
    5)  
        echo "正在重启 MTProxy..."
        systemctl restart mtg
        echo "MTProxy 重启成功！"
        show_info
        ;;
    6) 
        change_port
        ;;
    7)
        change_secret
        ;;
    8)
        update_mtg
        ;;
    9)
        show_info
        ;;
    0) exit 0
        ;;
    *) echo -e "${red}输入错误！请输入正确的数字 [0-9]。${plain}"
        ;;
    esac
}

# 主逻辑：先检测是否已安装
if [[ -f "/usr/bin/mtg" && -f "/etc/mtg.toml" ]]; then
    echo -e "${green}检测到已安装 MTProxy，直接显示配置信息：${plain}"
    show_info
    echo ""
    read -p "是否打开管理菜单？(y/n): " yn
    [[ "$yn" == "y" || "$yn" == "Y" ]] && start_menu
else
    start_menu
fi
