#!/bin/bash
###
 # @Author: ChatGPT (IPv6 版本)
 # @Date: 2025-09-28
 # @Description: MTProto IPv6 一键管理脚本 (纯二进制，无 Docker)
###

PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

# 定义颜色
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

[[ $EUID -ne 0 ]] && echo -e "[${red}错误${plain}] 请使用 root 用户运行！" && exit 1

# 显示连接信息
show_info(){
    if [[ -f "/etc/mtg6.toml" ]]; then
        port=$(grep 'bind-to' /etc/mtg6.toml | sed -E 's/.*:([0-9]+).*/\1/')
        secret=$(grep 'secret' /etc/mtg6.toml | sed -E 's/.*"([^"]+)".*/\1/')
        public_ip=$(curl -s ipv6.ip.sb)
        subscription_config="tg://proxy?server=[${public_ip}]&port=${port}&secret=${secret}"
        subscription_link="https://t.me/proxy?server=[${public_ip}]&port=${port}&secret=${secret}"
        echo -e "\n========== MTProxy IPv6 配置信息 =========="
        echo -e "服务器IPv6 : ${green}${public_ip}${plain}"
        echo -e "监听端口   : ${green}${port}${plain}"
        echo -e "Secret     : ${green}${secret}${plain}"
        echo -e "TG 配置链接: ${yellow}${subscription_config}${plain}"
        echo -e "一键链接   : ${yellow}${subscription_link}${plain}"
        echo -e "=========================================\n"
        echo -e "${yellow}注意事项：${plain}"
        echo -e "1. 客户端必须支持 IPv6 或使用绑定域名"
        echo -e "2. IPv6 地址在链接中必须加 [ ]"
        echo -e "3. 若要 IPv4 客户端访问，请配合 Cloudflare Tunnel 或反代"
        echo -e "4. 修改端口或 secret 后，MTProxy 需重启"
    else
        echo -e "${red}未检测到配置文件 /etc/mtg6.toml${plain}"
    fi
}

download_file(){
    echo "检查系统架构..."
	bit=$(uname -m)
	if [[ ${bit} = "x86_64" ]]; then
		bit="amd64"
    elif [[ ${bit} = "aarch64" ]]; then
        bit="arm64"
    else
	    bit="386"
    fi

    last_version=$(curl -Ls "https://api.github.com/repos/9seconds/mtg/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    [[ -z "$last_version" ]] && { echo -e "${red}获取 mtg 最新版本失败${plain}"; exit 1; }

    version=${last_version#v}
    wget -N --no-check-certificate -O mtg-${version}-linux-${bit}.tar.gz "https://github.com/9seconds/mtg/releases/download/${last_version}/mtg-${version}-linux-${bit}.tar.gz"
    tar -xzf mtg-${version}-linux-${bit}.tar.gz
    mv mtg-${version}-linux-${bit}/mtg /usr/bin/mtg
    chmod +x /usr/bin/mtg
    rm -rf mtg-${version}-linux-${bit} mtg-${version}-linux-${bit}.tar.gz
    echo -e "mtg 安装完成，开始配置..."
}

configure_mtg(){
    echo -e "配置 mtg IPv6..."
    wget -N --no-check-certificate -O /etc/mtg6.toml https://raw.githubusercontent.com/missuo/MTProxy/main/mtg.toml

    read -p "请输入伪装域名 (默认 itunes.apple.com): " domain
	[ -z "${domain}" ] && domain="itunes.apple.com"

    read -p "请输入监听端口 (默认 8443): " port
	[ -z "${port}" ] && port="8443"

    secret=$(mtg generate-secret --hex $domain)
    sed -i "s/secret.*/secret = \"${secret}\"/g" /etc/mtg6.toml
    sed -i "s/bind-to.*/bind-to = \"[::]:${port}\"/g" /etc/mtg6.toml

    echo "配置完成，开始写入 systemctl 服务..."
}

configure_systemctl(){
    wget -N --no-check-certificate -O /etc/systemd/system/mtg6.service https://raw.githubusercontent.com/missuo/MTProxy/main/mtg.service
    sed -i 's/ExecStart=.*/ExecStart=\/usr\/bin\/mtg run \/etc\/mtg6.toml/g' /etc/systemd/system/mtg6.service
    systemctl daemon-reload
    systemctl enable mtg6
    systemctl start mtg6
    echo "MTProxy IPv6 已启动！"
    show_info
}

change_port(){
    read -p "请输入要修改的端口 (默认 8443): " port
	[ -z "${port}" ] && port="8443"
    sed -i "s/bind-to.*/bind-to = \"[::]:${port}\"/g" /etc/mtg6.toml
    systemctl restart mtg6
    echo "端口修改成功，MTProxy IPv6 已重启！"
    show_info
}

change_secret(){
    read -p "请输入要修改的 Secret (留空则自动生成): " secret
	[ -z "${secret}" ] && secret=$(mtg generate-secret --hex itunes.apple.com)
    sed -i "s/secret.*/secret = \"${secret}\"/g" /etc/mtg6.toml
    systemctl restart mtg6
    echo "Secret 修改成功，MTProxy IPv6 已重启！"
    show_info
}

update_mtg(){
    download_file
    systemctl restart mtg6
    echo "MTProxy IPv6 已更新并重启！"
    show_info
}

start_menu(){
    while true; do
        clear
        show_info
        echo -e "  MTProxy IPv6 一键管理脚本
 ${green}1.${plain} 安装 MTProxy IPv6
 ${green}2.${plain} 卸载 MTProxy IPv6
————————————
 ${green}3.${plain} 启动 MTProxy IPv6
 ${green}4.${plain} 停止 MTProxy IPv6
 ${green}5.${plain} 重启 MTProxy IPv6
 ${green}6.${plain} 修改监听端口
 ${green}7.${plain} 修改 Secret
 ${green}8.${plain} 更新 MTProxy
————————————
 ${green}0.${plain} 退出
————————————"

        read -e -p "请输入选项 [0-8]: " num
        case "$num" in
        1) download_file; configure_mtg; configure_systemctl ;;
        2) systemctl stop mtg6; systemctl disable mtg6; rm -rf /usr/bin/mtg; rm -rf /etc/mtg6.toml; rm -rf /etc/systemd/system/mtg6.service; echo "卸载完成" ;;
        3) systemctl start mtg6; echo "已启动" ;;
        4) systemctl stop mtg6; echo "已停止" ;;
        5) systemctl restart mtg6; echo "已重启" ;;
        6) change_port ;;
        7) change_secret ;;
        8) update_mtg ;;
        0) break ;;
        *) echo -e "${red}输入错误！请输入正确的数字 [0-8]${plain}" ;;
        esac
        echo -e "\n按任意键返回菜单..."
        read -n1
    done
}

start_menu
