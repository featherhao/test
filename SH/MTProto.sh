#!/usr/bin/env bash
set -euo pipefail

IMAGE="telegrammessenger/proxy:latest"
CONTAINER_NAME="tg-mtproxy"
DATA_DIR="/etc/tg-proxy"
SECRET_FILE="${DATA_DIR}/secret"
DEFAULT_PORT=6688
PORT=""

info() { echo -e "\e[1;34m$*\e[0m"; }
warn() { echo -e "\e[1;33m$*\e[0m"; }

find_free_port() {
  local port=$1
  while true; do
    if ! ss -ltn 2>/dev/null | awk '{print $4}' | grep -q ":$port\$"; then
      echo "$port"
      return
    fi
    port=$((port+1))
  done
}

generate_secret() {
  mkdir -p "${DATA_DIR}"
  if [ -f "${SECRET_FILE}" ]; then
    SECRET="$(cat ${SECRET_FILE})"
  else
    SECRET="$(openssl rand -hex 32 2>/dev/null || head -c32 /dev/urandom | od -An -t x1 | tr -d ' \n')"
    echo -n "${SECRET}" > "${SECRET_FILE}"
    chmod 600 "${SECRET_FILE}"
  fi
}

public_ip() {
  curl -fs --max-time 5 https://api.ipify.org || echo "UNKNOWN"
}

run_container() {
  docker run -d --name "${CONTAINER_NAME}" --restart unless-stopped \
    -p "${PORT}:443" \
    -e "SECRET=${SECRET}" \
    "${IMAGE}"
}

install() {
  generate_secret
  PORT=$(find_free_port "$DEFAULT_PORT")
  info "使用端口: $PORT"
  docker pull "${IMAGE}"
  run_container
  show_info
}

update() {
  generate_secret
  PORT=$(find_free_port "$DEFAULT_PORT")
  info "使用端口: $PORT"
  docker stop "${CONTAINER_NAME}" 2>/dev/null || true
  docker rm "${CONTAINER_NAME}" 2>/dev/null || true
  docker pull "${IMAGE}"
  run_container
  show_info
}

change_port() {
  generate_secret
  echo -n "请输入新的端口号 (留空自动选择): "
  read -r new_port
  if [[ -z "$new_port" ]]; then
    PORT=$(find_free_port "$DEFAULT_PORT")
  else
    if ! [[ "$new_port" =~ ^[0-9]+$ ]]; then
      warn "无效端口号"
      return
    fi
    PORT=$(find_free_port "$new_port")
  fi

  info "切换到端口: $PORT"
  docker stop "${CONTAINER_NAME}" 2>/dev/null || true
  docker rm "${CONTAINER_NAME}" 2>/dev/null || true
  run_container
  show_info
}

uninstall() {
  docker stop "${CONTAINER_NAME}" 2>/dev/null || true
  docker rm "${CONTAINER_NAME}" 2>/dev/null || true
  info "容器已移除"
}

show_info() {
  IP=$(public_ip)
  PROXY_LINK="tg://proxy?server=${IP}&port=${PORT}&secret=${SECRET}"
  TME_LINK="https://t.me/proxy?server=${IP}&port=${PORT}&secret=${SECRET}"

  echo
  info "————— Telegram MTProto 代理 信息 —————"
  echo "端口：   ${PORT}"
  echo "secret： ${SECRET}"
  echo
  echo "tg:// 复制链接:"
  echo "${PROXY_LINK}"
  echo
  echo "t.me 分享链接:"
  echo "${TME_LINK}"
  echo "———————————————————————————————"
}

menu() {
  cat <<EOF
请选择操作：
 1) 安装
 2) 更新
 3) 卸载
 4) 查看信息
 5) 更改端口
 6) 退出
EOF
  read -r choice
  case "$choice" in
    1) install ;;
    2) update ;;
    3) uninstall ;;
    4) show_info ;;
    5) change_port ;;
    *) exit 0 ;;
  esac
}

menu
