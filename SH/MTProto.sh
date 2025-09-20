#!/usr/bin/env bash
# 一键安装 / 更新 / 卸载 / 查看 MTProto 代理 (Docker + seriyps/mtproto-proxy)
set -euo pipefail

IMAGE="seriyps/mtproto-proxy:latest"
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
    SECRET="$(openssl rand -hex 16 2>/dev/null || head -c16 /dev/urandom | xxd -p -c32)"
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
    -v "${DATA_DIR}:/data" \
    -e "SECRET=${SECRET}" \
    -e "WORKERS=1" \
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
  warn "容器已移除"
  echo -n "是否删除镜像 ${IMAGE}? (y/N): "
  read -r yn
  if [[ "$yn" =~ ^[Yy]$ ]]; then
    docker rmi "${IMAGE}" || true
  fi
  echo -n "是否删除数据目录 ${DATA_DIR}? (y/N): "
  read -r yn2
  if [[ "$yn2" =~ ^[Yy]$ ]]; then
    rm -rf "${DATA_DIR}"
  fi
}

show_info() {
  IP=$(public_ip)
  PROXY_LINK="tg://proxy?server=${IP}&port=${PORT}&secret=${SECRET}"
  TME_LINK="https://t.me/proxy?server=${IP}&port=${PORT}&secret=${SECRET}"

  echo
  info "————— Telegram MTProto 代理 信息 —————"
  echo "容器名:   ${CONTAINER_NAME}"
  echo "端口:     ${PORT}"
  echo "secret:   ${SECRET}"
  echo
  echo "tg:// 链接 (客户端直接导入):"
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
