#!/bin/bash
set -e

WORKDIR="/opt/rustdesk"
IMAGE="rustdesk/rustdesk-server:latest"

mkdir -p $WORKDIR

print_info() {
  echo "🌐 RustDesk 服务端连接信息："
  echo "ID Server : $(curl -s ifconfig.me):21115"
  echo "Relay     : $(curl -s ifconfig.me):21116"
  echo "API       : $(curl -s ifconfig.me):21117"
  local key=$(docker exec hbbs hbbs -g | grep "key" | awk '{print $2}')
  echo "🔑 客户端 Key：$key"
}

install_rustdesk() {
  echo "📦 安装 RustDesk Server..."
  docker run -d --name hbbs --restart unless-stopped \
    -p 21115:21115 -p 21116:21116 -p 21116:21116/udp \
    -p 21117:21117 \
    $IMAGE hbbs

  docker run -d --name hbbr --restart unless-stopped \
    -p 21118:21118 -p 21119:21119 \
    $IMAGE hbbr

  echo "✅ 安装完成"
  print_info
}

uninstall_rustdesk() {
  echo "🗑️ 卸载 RustDesk Server..."
  docker rm -f hbbs hbbr >/dev/null 2>&1 || true
  echo "✅ 卸载完成"
}

restart_rustdesk() {
  echo "🔄 重启 RustDesk Server..."
  docker restart hbbs hbbr
  echo "✅ 重启完成"
}

check_update() {
  echo "🔍 检查更新中..."
  local local_id=$(docker images --no-trunc --quiet "$IMAGE" 2>/dev/null || echo "")
  docker pull "$IMAGE" >/tmp/rustdesk_update.log 2>&1
  local remote_id=$(docker images --no-trunc --quiet "$IMAGE" 2>/dev/null || echo "")

  if [[ "$local_id" == "$remote_id" && -n "$local_id" ]]; then
    echo "✅ 当前已是最新版本"
    return 1
  else
    echo "⬆️  有新版本可更新！(选择 5 更新)"
    return 0
  fi
}

update_rustdesk() {
  echo "⬆️ 更新 RustDesk Server..."
  docker pull "$IMAGE"
  uninstall_rustdesk
  install_rustdesk
  echo "✅ 更新完成"
}

menu() {
  while true; do
    clear
    echo "============================="
    echo "     RustDesk 服务端管理"
    echo "============================="
    if docker ps -a --format '{{.Names}}' | grep -q hbbs; then
      echo "服务端状态: 已安装 ✅"
    else
      echo "服务端状态: 未安装 ❌"
    fi

    if check_update; then
      update_available=1
    else
      update_available=0
    fi

    echo "1) 安装 RustDesk Server"
    echo "2) 卸载 RustDesk Server"
    echo "3) 重启 RustDesk Server"
    echo "4) 查看连接信息"
    echo "5) 更新 RustDesk Server"
    echo "0) 退出"
    read -p "请选择操作 [0-5]: " choice

    case $choice in
      1) install_rustdesk ;;
      2) uninstall_rustdesk ;;
      3) restart_rustdesk ;;
      4) print_info ;;
      5) 
         if [[ $update_available -eq 1 ]]; then
           update_rustdesk
         else
           echo "✅ 已是最新版本，无需更新"
         fi
         ;;
      0) exit 0 ;;
      *) echo "❌ 无效选择";;
    esac
    read -p "按回车继续..."
  done
}

menu
