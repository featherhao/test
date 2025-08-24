#!/bin/bash
set -e

# 脚本地址
MOONTV_SCRIPT="https://raw.githubusercontent.com/featherhao/test/refs/heads/main/install.sh"
UPDATE_SCRIPT="https://raw.githubusercontent.com/featherhao/test/refs/heads/main/updatemtv.sh"

WORKDIR="/opt/moontv"

# 检查依赖
if ! command -v docker &>/dev/null; then
  echo "❌ 未检测到 Docker，请先安装 Docker"
  exit 1
fi
if ! docker compose version &>/dev/null; then
  echo "❌ 未检测到 Docker Compose，请安装 (docker compose plugin)"
  exit 1
fi

while true; do
  clear
  echo "=============================="
  echo "       🚀 MoonTV 管理器"
  echo "=============================="
  echo "1) 安装 / 初始化 MoonTV"
  echo "2) 更新 MoonTV"
  echo "3) 重启 MoonTV"
  echo "4) 停止 MoonTV"
  echo "5) 查看运行日志"
  echo "q) 退出"
  echo "=============================="
  read -rp "请输入选项: " choice

  case "$choice" in
    1)
      echo "📦 正在安装 MoonTV..."
      bash <(curl -fsSL "$MOONTV_SCRIPT")
      ;;
    2)
      echo "🔄 正在更新 MoonTV..."
      bash <(curl -fsSL "$UPDATE_SCRIPT")
      ;;
    3)
      if [ -d "$WORKDIR" ]; then
        echo "♻️  重启 MoonTV..."
        cd "$WORKDIR" && docker compose restart
      else
        echo "⚠️  未找到 $WORKDIR，请先安装"
      fi
      ;;
    4)
      if [ -d "$WORKDIR" ]; then
        echo "🛑 停止 MoonTV..."
        cd "$WORKDIR" && docker compose down
      else
        echo "⚠️  未找到 $WORKDIR，请先安装"
      fi
      ;;
    5)
      if [ -d "$WORKDIR" ]; then
        echo "📜 查看日志 (按 Ctrl+C 退出)"
        cd "$WORKDIR" && docker compose logs -f
      else
        echo "⚠️  未找到 $WORKDIR，请先安装"
      fi
      ;;
    0|q|Q)
      echo "👋 退出"
      exit 0
      ;;
    *)
      echo "❌ 无效输入，请重新选择"
      ;;
  esac

  echo
  read -rp "按回车继续..."
done
