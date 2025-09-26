#!/usr/bin/env bash
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

# ================= 自动切换 bash =================
if [ -z "$BASH_VERSION" ]; then
  if command -v bash >/dev/null 2>&1; then
    exec bash "$0" "$@"
  else
    echo "请先安装 bash"
    exit 1
  fi
fi

# ================= 系统依赖检查 =================
check_deps() {
  local pkgs="curl docker"
  local install_cmd=""

  if command -v apt >/dev/null 2>&1; then
    install_cmd="apt update && apt install -y"
  elif command -v yum >/dev/null 2>&1; then
    install_cmd="yum install -y"
  elif command -v apk >/dev/null 2>&1; then
    install_cmd="apk add --no-cache"
  fi

  for p in bash openssl $pkgs; do
    if ! command -v $p >/dev/null 2>&1; then
      if [ -n "$install_cmd" ]; then
        info "正在安装缺失依赖: $p"
        sh -c "$install_cmd $p"
      else
        warn "未找到包管理器，请手动安装 $p"
      fi
    fi
  done

  # Alpine 自动启动 Docker
  if command -v rc-status >/dev/null 2>&1; then
    rc-update add docker boot
    service docker start || true
  fi

  # 检查磁盘空间
  local disk_free=$(df / | tail -1 | awk '{print $4}')
  local inodes_free=$(df -i / | tail -1 | awk '{print $4}')
  if [[ $disk_free -lt 1048576 || $inodes_free -lt 1024 ]]; then
    warn "磁盘空间或 inode 不足，请清理后再运行 Docker"
    exit 1
  fi

  # 检查 docker 可用性
  if ! docker info >/dev/null 2>&1; then
    warn "Docker 似乎未启动或当前用户没有权限访问 /var/run/docker.sock"
    warn "请确保 Docker 已启动，并且当前用户可访问 docker"
    exit 1
  fi
}

# ================= 查找空闲端口 =================
find_free_port() {
  local port=$1
  while ss -ltn 2>/dev/null | awk '{print $4}' | grep -q ":$port\$"; do
    port=$((port+1))
  done
  echo "$port"
}

# ================= 生成 secret =================
generate_secret() {
  mkdir -p "$DATA_DIR"
  if [ -f "$SECRET_FILE" ]; then
    SECRET=$(cat "$SECRET_FILE")
  else
    if command -v openssl >/dev/null 2>&1; then
      SECRET=$(openssl rand -hex 16)
    else
      SECRET=$(head -c 16 /dev/urandom | hexdump -e '16/1 "%02x"')
    fi
    echo -n "$SECRET" > "$SECRET_FILE"
  fi
}

# ================= 获取公网 IP =================
public_ip() {
  curl -fs --max-time 5 https://api.ipify.org \
  || curl -fs --max-time 5 https://ip.sb \
  || curl -fs --max-time 5 https://ipinfo.io/ip \
  || echo "UNKNOWN"
}

# ================= 启动容器 =================
run_container() {
  if ! docker run -d --name "$CONTAINER_NAME" --restart unless-stopped \
      -p "${PORT}:${PORT}" \
      -e "MTPROXY_SECRET=$SECRET" \
      -e "MTPROXY_PORT=$PORT" \
      "$IMAGE"; then
    warn "Docker 容器启动失败，请检查磁盘配额或 session keyring 限制"
    exit 1
  fi
}

# ================= 安装 =================
install() {
  check_deps
  generate_secret
  PORT=$(find_free_port "$DEFAULT_PORT")
  docker pull "$IMAGE"
  run_container
  show_info
}

# ================= 更新 =================
update() {
  check_deps
  generate_secret
  PORT=$(find_free_port "$DEFAULT_PORT")
  docker stop "$CONTAINER_NAME" 2>/dev/null || true
  docker rm "$CONTAINER_NAME" 2>/dev/null || true
  docker pull "$IMAGE"
  run_container
  show_info
}

# ================= 更改端口 =================
change_port() {
  read -rp "请输入新的端口号 (留空自动选择): " new_port
  if [ -z "$new_port" ]; then
    PORT=$(find_free_port "$DEFAULT_PORT")
  else
    PORT=$(find_free_port "$new_port")
  fi
  docker stop "$CONTAINER_NAME" 2>/dev/null || true
  docker rm "$CONTAINER_NAME" 2>/dev/null || true
  run_container
  show_info
}

# ================= 更改 secret =================
change_secret() {
  SECRET=$(openssl rand -hex 16 2>/dev/null || head -c 16 /dev/urandom | hexdump -e '16/1 "%02x"')
  echo -n "$SECRET" > "$SECRET_FILE"
  docker stop "$CONTAINER_NAME" 2>/dev/null || true
  docker rm "$CONTAINER_NAME" 2>/dev/null || true
  run_container
  show_info
}

# ================= 查看日志 =================
show_logs() {
  docker logs -f "$CONTAINER_NAME"
}

# ================= 卸载 =================
uninstall() {
  docker stop "$CONTAINER_NAME" 2>/dev/null || true
  docker rm "$CONTAINER_NAME" 2>/dev/null || true
  warn "容器已移除"
  echo -n "是否删除镜像 $IMAGE? (y/N): "
  read -r yn
  [[ "$yn" =~ ^[Yy]$ ]] && docker rmi "$IMAGE"
  echo -n "是否删除数据目录 $DATA_DIR? (y/N): "
  read -r yn2
  [[ "$yn2" =~ ^[Yy]$ ]] && rm -rf "$DATA_DIR"
}

# ================= 显示节点信息 =================
show_info() {
  IP=$(public_ip)
  PROXY_LINK="tg://proxy?server=${IP}&port=${PORT}&secret=${SECRET}"
  TME_LINK="https://t.me/proxy?server=${IP}&port=${PORT}&secret=${SECRET}"

  echo
  info "————— Telegram MTProto 代理 信息 —————"
  echo "IP:       $IP"
  echo "端口:     $PORT"
  echo "secret:   $SECRET"
  echo
  echo "tg:// 链接:"
  echo "$PROXY_LINK"
  echo
  echo "t.me 分享链接:"
  echo "$TME_LINK"
  echo "———————————————————————————————"
}

# ================= 菜单 =================
menu() {
  while true; do
    cat <<EOF
请选择操作：
 1) 安装
 2) 更新
 3) 卸载
 4) 查看信息
 5) 更改端口
 6) 更改 secret
 7) 查看日志
 8) 退出
EOF
    read -rp "请输入选项 [1-8]: " choice
    case "$choice" in
      1) install ;;
      2) update ;;
      3) uninstall ;;
      4) show_info ;;
      5) change_port ;;
      6) change_secret ;;
      7) show_logs ;;
      *) exit 0 ;;
    esac
  done
}

# 启动菜单
menu
