#!/bin/bash
set -euo pipefail

MAIN_SCRIPT="https://raw.githubusercontent.com/yonggekkk/argosbx/main/argosbx.sh"

echo "🚀 勇哥ArgoSB协议管理"
echo "=============================="

while true; do
    echo ""
    echo "1) 添加或更新协议节点"
    echo "2) 查看节点信息 (agsbx list)"
    echo "3) 更新脚本 (建议卸载重装)"
    echo "4) 重启脚本 (agsbx res)"
    echo "5) 卸载脚本 (agsbx del)"
    echo "6) 临时切换 IPv4 / IPv6 节点显示"
    echo "7) 更改协议端口"
    echo "0) 退出"
    read -rp "选择操作: " action

    case $action in
        1)
            echo ""
            echo "请选择要添加或更新的协议（可多选，用空格分隔，例如 1 3 5）:"
            echo "⚠️ 注意：该操作会覆盖现有配置，请确保输入所有需要保留的协议。"
            echo "1) Vless-Reality-Vision (vlpt)"
            echo "2) Vless-Xhttp-Reality (xhpt)"
            echo "3) Vless-Xhttp (vxpt)"
            echo "4) Shadowsocks-2022 (sspt)"
            echo "5) AnyTLS (anpt)"
            echo "6) Any-Reality (arpt)"
            echo "7) Vmess-ws (vmpt)"
            echo "8) Hysteria2 (hypt)"
            echo "9) Tuic (tupt)"
            echo "10) Argo临时隧道CDN优选节点"
            echo "11) Argo固定隧道CDN优选节点"
            read -rp "输入序号: " -a selections

            # 清空旧变量
            unset vlpt xhpt vxpt sspt anpt arpt vmpt hypt tupt argo agn agk cdnym ippz name uuid reym

            vmess_enabled=0
            for sel in "${selections[@]}"; do
                case $sel in
                    1) read -rp "请输入 Vless-Reality-Vision 端口（留空随机）: " val; export vlpt="$val";;
                    2) read -rp "请输入 Vless-Xhttp-Reality 端口（留空随机）: " val; export xhpt="$val";;
                    3) read -rp "请输入 Vless-Xhttp 端口（留空随机）: " val; export vxpt="$val";;
                    4) read -rp "请输入 Shadowsocks-2022 端口（留空随机）: " val; export sspt="$val";;
                    5) read -rp "请输入 AnyTLS 端口（留空随机）: " val; export anpt="$val";;
                    6) read -rp "请输入 Any-Reality 端口（留空随机）: " val; export arpt="$val";;
                    7) read -rp "请输入 Vmess-ws 端口（留空随机）: " val; export vmpt="$val"; vmess_enabled=1;;
                    8) read -rp "请输入 Hysteria2 端口（留空随机）: " val; export hypt="$val";;
                    9) read -rp "请输入 Tuic 端口（留空随机）: " val; export tupt="$val";;
                    10) export argo="y";;
                    11)
                        if [ $vmess_enabled -eq 0 ]; then
                            echo "⚠️ Argo固定隧道必须启用 Vmess-ws 协议，请先选择 7) Vmess-ws"
                            continue 2
                        fi
                        # 固定隧道端口保留原输入
                        if [ -z "${vmpt:-}" ]; then
                            read -rp "请输入 Argo固定隧道端口 (vmpt必须启用): " val
                            export vmpt="$val"
                        fi
                        read -rp "请输入 Argo固定隧道域名 (agn): " agn; export agn
                        read -rp "请输入 Argo固定隧道Token (agk): " agk; export agk
                        export argo="y"
                        ;;
                    *)
                        echo "⚠️ 无效选项 $sel"
                        ;;
                esac
            done

            echo "==============================="
            echo "正在执行 Argosbx 主脚本..."
            bash <(curl -Ls "$MAIN_SCRIPT")
            echo "安装或更新完成！"
            ;;
        2) bash <(curl -Ls "$MAIN_SCRIPT") list;;
        3) bash <(curl -Ls "$MAIN_SCRIPT") rep;;
        4) bash <(curl -Ls "$MAIN_SCRIPT") res;;
        5) bash <(curl -Ls "$MAIN_SCRIPT") del;;
        6)
            read -rp "显示 IPv4 节点请输入4，IPv6请输入6: " ipver
            export ippz="$ipver"
            bash <(curl -Ls "$MAIN_SCRIPT") list
            ;;
        7)
            echo "更改协议端口请使用自定义变量组 rep 功能:"
            echo "示例: bash <(curl -Ls $MAIN_SCRIPT) rep"
            ;;
        0) exit 0;;
        *) echo "⚠️ 无效操作，请重新选择";;
    esac
done
