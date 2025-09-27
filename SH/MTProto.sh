#!/usr/bin/env bash
# 一键安装 / 更新 / 卸载 / 查看 Telegram MTProto 代理
set -euo pipefail

IMAGE="telegrammessenger/proxy:latest"
CONTAINER_NAME="tg-mtproxy"
DATA_DIR="/etc/tg-proxy"
SECRET_FILE="${DATA_DIR}/secret"
DEFAULT_PORT=6688
PORT=""
SECRET=""

info() { echo -e "\e[1;34m$*\e[0m"; }
warn() { echo -e "\e[1;33m$*\e[0m"; }
err() { echo -e "\e[1;31m$*\e[0m"; }

detect_os() {
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
  else
    OS=$(uname -s)
  fi
}

find_free_port() {
  local port=$1
  while ss -ltn 2>/dev/null | awk '{print $4}' | grep -q ":$port\$"; do
    port=$((port+1))
  done
  echo "$port"
}

generate_secret() {
  mkdir -p "$DATA_DIR"
  if [[ -f "$SECRET_FILE" ]]; then
    SECRET=$(cat "$SECRET_FILE")
  else
    SECRET=$(openssl rand -hex 16)
    echo -n "$SECRET" > "$SECRET_FILE"
  fi
}

public_ip() {
  curl -fs --max-time 5 https://api.ipify.org || echo "UNKNOWN"
}

show_info() {
  IP=$(public_ip)
  echo
  info "————— Telegram MTProto 代理 信息 —————"
  echo "IP:       $IP"
  echo "端口:     $PORT"
  echo "secret:   $SECRET"
  echo
  echo "tg:// 链接:"
  echo "tg://proxy?server=${IP}&port=${PORT}&secret=${SECRET}"
  echo
  echo "t.me 分享链接:"
  echo "https://t.me/proxy?server=${IP}&port=${PORT}&secret=${SECRET}"
  echo "———————————————————————————————"
}

# ---------------- Ubuntu/Debian: Docker 部署 ----------------
install_docker_mode() {
  apt-get update -y
  apt-get install -y curl openssl docker.io
  systemctl enable --now docker

  generate_secret
  PORT=$(find_free_port "$DEFAULT_PORT")

  docker rm -f "$CONTAINER_NAME" 2>/dev/null || true
  docker pull "$IMAGE"
  docker run -d --name "$CONTAINER_NAME" --restart unless-stopped \
    -p "${PORT}:443" \
    -v "${DATA_DIR}:/data" \
    -e "MTPROXY_SECRET=$SECRET" \
    "$IMAGE"

  show_info
}

update_docker_mode() {
  generate_secret
  PORT=$(find_free_port "$DEFAULT_PORT")
  docker rm -f "$CONTAINER_NAME" 2>/dev/null || true
  docker pull "$IMAGE"
  docker run -d --name "$CONTAINER_NAME" --restart unless-stopped \
    -p "${PORT}:443" \
    -v "${DATA_DIR}:/data" \
    -e "MTPROXY_SECRET=$SECRET" \
    "$IMAGE"
  show_info
}

uninstall_docker_mode() {
  docker rm -f "$CONTAINER_NAME" 2>/dev/null || true
  warn "容器已移除"
}

# ---------------- Alpine: 二进制模式 ----------------
install_alpine_mode() {
  apk add --no-cache curl openssl bash

  mkdir -p "$DATA_DIR"
  generate_secret
  PORT=$(find_free_port "$DEFAULT_PORT")

  if ! command -v mtproto-proxy >/dev/null 2>&1; then
    curl -L -o /usr/local/bin/mtproto-proxy \
      https://github.com/TelegramMessenger/MTProxy/releases/latest/download/mtproto-proxy
    chmod +x /usr/local/bin/mtproto-proxy
  fi

  cat >/etc/init.d/mtproxy <<'EOF'
#!/sbin/openrc-run
command="/usr/local/bin/mtproto-proxy"
command_args="-u nobody -p 0 -H ${PORT} -S ${SECRET} --aes-pwd /etc/tg-proxy/proxy-secret /etc/tg-proxy/proxy-multi.conf"
command_background="yes"
pidfile="/var/run/mtproxy.pid"
EOF
  chmod +x /etc/init.d/mtproxy

  rc-update add mtproxy default
  rc-service mtproxy restart

  show_info
}

uninstall_alpine_mode() {
  rc-service mtproxy stop || true
  rc-update del mtproxy || true
  rm -f /usr/local/bin/mtproto-proxy /etc/init.d/mtproxy
  warn "MTProxy 已卸载"
}

# ---------------- 菜单逻辑 ----------------
menu() {
  cat <<EOF
请选择操作：
 1) 安装
 2) 更新
 3) 卸载
 4) 查看信息
 5) 退出
EOF
  read -r choice
  detect_os
  case "$choice" in
    1)
      if [[ "$OS" == "alpine" ]]; then install_alpine_mode; else install_docker_mode; fi
      ;;
    2)
      if [[ "$OS" == "alpine" ]]; then warn "Alpine 模式暂不支持更新，请卸载后重装"; else update_docker_mode; fi
      ;;
    3)
      if [[ "$OS" == "alpine" ]]; then uninstall_alpine_mode; else uninstall_docker_mode; fi
      ;;
    4) show_info ;;
    *) exit 0 ;;
  esac
}

menu
