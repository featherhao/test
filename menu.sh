# ====== 主菜单 ======
while true; do
  clear
  echo "=============================="
  echo "       🚀 服务管理中心"
  echo "=============================="
  echo "1) MoonTV 管理"
  echo "2) RustDesk 管理"
  echo "3) LibreTV 安装"
  echo "4) 甬哥Sing-box-yg管理"
  echo "5) 勇哥ArgoSB一键无交互小钢炮"
  echo "6) Kejilion.sh 一键脚本工具箱"
  echo "9) 设置快捷键 Q / q"
  echo "U) 更新菜单脚本 menu.sh"
  echo "8) 其他服务 (预留)"
  echo "0) 退出"
  echo "=============================="
  read -rp "请输入选项: " main_choice

  case "${main_choice^^}" in
    1) moon_menu ;;
    2) rustdesk_menu ;;
    3) libretv_menu ;;
    4) singbox_menu ;;
    5) argosb_menu ;;
    6) bash <(curl -sL kejilion.sh) ;;
    9) set_q_shortcut ;;
    U) update_menu_script ;;
    8) echo "⚠️ 其他服务还未实现"; sleep 1 ;;
    0) exit 0 ;;
    *) echo "❌ 无效输入"; sleep 1 ;;
  esac
done
