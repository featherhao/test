moontv_menu() {
  while true; do
    clear

    # 检查安装状态
    if [ -d "$WORKDIR" ] && [ -f "$COMPOSE_FILE" ]; then
      STATUS="已安装 ✅"
      CONFIG_DISPLAY="配置："
      if [ -f "$ENV_FILE" ]; then
        CONFIG_DISPLAY+=$'\n'"$(grep -E "USERNAME|PASSWORD|AUTH_TOKEN" "$ENV_FILE")"
      else
        CONFIG_DISPLAY+=" ❌ 配置文件不存在"
      fi
    else
      STATUS="未安装 ❌"
      CONFIG_DISPLAY=""
    fi

    echo "=============================="
    echo "       🎬 MoonTV 管理菜单"
    echo "=============================="
    echo "状态: $STATUS"
    [ -n "$CONFIG_DISPLAY" ] && echo -e "$CONFIG_DISPLAY"
    echo "------------------------------"
    echo "1) 安装 / 初始化 MoonTV"
    echo "2) 修改 MoonTV 配置"
    echo "3) 卸载 MoonTV"
    echo "4) 启动 MoonTV"
    echo "5) 停止 MoonTV"
    echo "6) 查看运行日志"
    echo "7) 更新 MoonTV"
    echo "b) 返回上一级"
    echo "0) 退出"
    echo "=============================="
    read -rp "请输入选项: " choice

    case "$choice" in
      1) install_main ;;
      2) input_config ;;
      3) uninstall ;;
      4)
        if [ "$STATUS" = "已安装 ✅" ]; then
          cd "$WORKDIR"
          if command -v docker-compose &>/dev/null; then
            docker-compose start
          elif docker compose version &>/dev/null 2>&1; then
            docker compose start
          fi
        else
          echo "❌ MoonTV 未安装"
        fi
        ;;
      5)
        if [ "$STATUS" = "已安装 ✅" ]; then
          cd "$WORKDIR"
          if command -v docker-compose &>/dev/null; then
            docker-compose stop
          elif docker compose version &>/dev/null 2>&1; then
            docker compose stop
          fi
        else
          echo "❌ MoonTV 未安装"
        fi
        ;;
      6)
        if [ "$STATUS" = "已安装 ✅" ]; then
          cd "$WORKDIR"
          read -rp "是否持续跟踪日志？(y/N): " LOG_FOLLOW
          if [[ "$LOG_FOLLOW" =~ ^[Yy]$ ]]; then
            if command -v docker-compose &>/dev/null; then
              docker-compose logs -f
            elif docker compose version &>/dev/null 2>&1; then
              docker compose logs -f
            fi
          else
            if command -v docker-compose &>/dev/null; then
              docker-compose logs --tail 50
            elif docker compose version &>/dev/null 2>&1; then
              docker compose logs --tail 50
            fi
          fi
        else
          echo "❌ MoonTV 未安装"
        fi
        ;;
      7)
        if [ "$STATUS" = "已安装 ✅" ]; then
          update
        else
          echo "❌ MoonTV 未安装，无法更新"
        fi
        ;;
      b|B) break ;;
      0) exit 0 ;;
      *) echo "❌ 无效输入，请重新选择" ;;
    esac

    read -rp "按回车继续..."
  done
}
