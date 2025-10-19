#!/bin/bash
set -Eeuo pipefail

# ======================================
# iStore 一键安装脚本 (Ubuntu / Armbian)
# 自动尝试 GitHub Releases API 下载资产，若失败允许手动输入 URL
# ======================================

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
ISTORE_DIR="/opt/istore"
ISTORE_PORT=81
SERVICE_FILE="/etc/systemd/system/istore.service"
LOGFILE="/tmp/istore-install.log"

echo -e "${GREEN}=== iStore 自动安装（动态查找 release 资产 / 支持手动 URL）===${NC}"
echo "日志: $LOGFILE"
: >"$LOGFILE"

title(){ echo -e "${GREEN}\n=== $1 ===${NC}"; }

# detect arch
detect_arch(){
  ARCH_RAW=$(uname -m)
  case "$ARCH_RAW" in
    x86_64|amd64) ARCH_ALIAS="x86_64" ;;
    aarch64|arm64) ARCH_ALIAS="aarch64" ;;
    armv7l|armv7) ARCH_ALIAS="armv7" ;;
    *) echo -e "${RED}不支持的架构: $ARCH_RAW${NC}"; exit 1 ;;
  esac
}

detect_sys(){
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    if echo "$ID" | grep -qi ubuntu; then SYS="Ubuntu"; fi
    if echo "$ID" | grep -qi armbian; then SYS="Armbian"; fi
  fi
  SYS=${SYS:-Unknown}
}

install_deps(){
  title "安装依赖"
  echo "更新 apt 并安装 curl jq tar unzip (如已安装将跳过)" | tee -a "$LOGFILE"
  apt update -y >>"$LOGFILE" 2>&1 || true
  apt install -y curl jq tar unzip ca-certificates systemd >/dev/null 2>>"$LOGFILE" || true
}

# 尝试从 GitHub Releases 自动找到对应资产
# 参数: owner repo arch_keyword (例如: linkease istore aarch64)
find_asset_from_github(){
  owner="$1"; repo="$2"; arch="$3"
  api="https://api.github.com/repos/${owner}/${repo}/releases"
  echo "查询 $owner/$repo releases..." | tee -a "$LOGFILE"
  # 获取最近 10 个 release 里第一个匹配 arch 的 asset url
  curl -sSf "$api" 2>>"$LOGFILE" | jq -r --arg arch "$arch" '
    .[] | .assets[]? | select((.name|ascii_downcase) | contains($arch) )
    | {name:.name, url:.browser_download_url} ' | head -n 1 | jq -s 'first' 2>>"$LOGFILE" || true
}

# 下载文件（带重试）
download_with_retries(){
  url="$1"; out="$2"
  echo "下载: $url -> $out" | tee -a "$LOGFILE"
  for i in 1 2 3; do
    if curl -fSL "$url" -o "$out" >>"$LOGFILE" 2>&1; then
      return 0
    else
      echo "下载失败 (尝试 $i)，重试..." | tee -a "$LOGFILE"
      sleep 1
    fi
  done
  return 1
}

choose_source_and_get_urls(){
  echo -e "${YELLOW}请选择获取方式（脚本会先尝试自动查找 GitHub 资产）:${NC}"
  echo "1) 自动查找（尝试 linkease/istore 及常见相关仓库）"
  echo "2) 手动输入二进制完整下载 URL（我有链接）"
  read -p "请输入选项 [1/2, 默认1]: " pick
  pick=${pick:-1}

  if [ "$pick" = "2" ]; then
    read -p "请输入 istore-server 二进制下载 URL: " SERVER_URL
    read -p "请输入 istore-ui 压缩包下载 URL (或回车跳过): " UI_URL
    SERVER_URL=${SERVER_URL:-}
    UI_URL=${UI_URL:-}
    if [ -z "$SERVER_URL" ]; then
      echo -e "${RED}必须提供 istore-server 下载 URL${NC}"; exit 1
    fi
    DOWNLOAD_SERVER_URL="$SERVER_URL"
    DOWNLOAD_UI_URL="$UI_URL"
    return
  fi

  # 自动查找策略：按优先级尝试这些仓库名组合（会查 releases 中包含 arch 的资产）
  candidates=(
    "linkease istore" 
    "linkease istore-packages"
    "linkease istore-ui"
    "linkease istorepanel"
  )

  for item in "${candidates[@]}"; do
    owner=$(echo "$item" | awk '{print $1}')
    repo=$(echo "$item" | awk '{print $2}')
    # 查找 server
    asset_json=$(find_asset_from_github "$owner" "$repo" "$ARCH_ALIAS")
    if [ -n "$asset_json" ] && echo "$asset_json" | jq -e . >/dev/null 2>&1; then
      name=$(echo "$asset_json" | jq -r .name)
      url=$(echo "$asset_json" | jq -r .url)
      echo "发现资产: $owner/$repo -> $name ($url)" | tee -a "$LOGFILE"
      # Heuristic: 如果名字里包含 server 或 istore-server，优先作为 server
      lname=$(echo "$name" | tr 'A-Z' 'a-z')
      if echo "$lname" | grep -q "server"; then
        DOWNLOAD_SERVER_URL="$url"
      elif echo "$lname" | grep -q "ui" || echo "$lname" | grep -q "frontend"; then
        DOWNLOAD_UI_URL="$url"
      else
        # 如果还没有 server，先把它当作 server
        DOWNLOAD_SERVER_URL="${DOWNLOAD_SERVER_URL:-$url}"
      fi
    fi
  done

  # 如果未找到 UI / Server，允许多次尝试或回退到手动输入
  if [ -z "${DOWNLOAD_SERVER_URL:-}" ]; then
    echo -e "${YELLOW}自动查找没有找到可用的 istore-server 资产.${NC}"
    read -p "是否现在手动输入下载 URL ? [Y/n]: " yn
    yn=${yn:-Y}
    if [[ "$yn" =~ ^[Yy]$ ]]; then
      read -p "请输入 istore-server 二进制下载 URL: " SERVER_URL
      DOWNLOAD_SERVER_URL="$SERVER_URL"
    else
      echo "取消安装"; exit 1
    fi
  fi
  # UI 可选
  if [ -z "${DOWNLOAD_UI_URL:-}" ]; then
    echo -e "${YELLOW}未自动找到 istore-ui 资产（UI 可选，server 可独立运行）${NC}"
    read -p "是否手动输入 UI 压缩包 URL ? (回车跳过): " UI_URL
    DOWNLOAD_UI_URL=${UI_URL:-}
  fi
}

install_istore(){
  title "安装 / 修复 iStore"
  mkdir -p "$ISTORE_DIR"
  cd "$ISTORE_DIR"
  # 下载 server
  server_tar="/tmp/istore-server-asset"
  ui_tar="/tmp/istore-ui-asset"
  if download_with_retries "$DOWNLOAD_SERVER_URL" "$server_tar"; then
    echo "server 下载完成" | tee -a "$LOGFILE"
  else
    echo -e "${RED}下载 istore-server 失败，请检查 URL 或网络 (详见 $LOGFILE)${NC}"
    exit 1
  fi

  # 如果是压缩包则解压；如果是单可执行则直接移动
  file_type=$(file -b "$server_tar" | tr '[:upper:]' '[:lower:]')
  if echo "$file_type" | grep -q "gzip"; then
    tar -xzf "$server_tar" -C "$ISTORE_DIR" || (echo "解压 server 失败" | tee -a "$LOGFILE"; exit 1)
  else
    # 假设是可执行
    mv -f "$server_tar" "$ISTORE_DIR/istore-server"
  fi

  if [ -n "${DOWNLOAD_UI_URL:-}" ]; then
    if download_with_retries "$DOWNLOAD_UI_URL" "$ui_tar"; then
      echo "ui 下载完成" | tee -a "$LOGFILE"
      file_type_ui=$(file -b "$ui_tar" | tr '[:upper:]' '[:lower:]')
      if echo "$file_type_ui" | grep -q "gzip\|zip"; then
        mkdir -p "$ISTORE_DIR/istore-ui"
        tar -xzf "$ui_tar" -C "$ISTORE_DIR/istore-ui" || true
      else
        # 如果直接是目录打包之外的文件，尝试放到 istore-ui
        mkdir -p "$ISTORE_DIR/istore-ui"
        mv -f "$ui_tar" "$ISTORE_DIR/istore-ui/"
      fi
    else
      echo -e "${YELLOW}警告: UI 下载失败，继续以 server 方式尝试启动（UI 可选）${NC}"
    fi
  fi

  # 尝试找到可执行文件
  if [ -x "$ISTORE_DIR/istore-server" ]; then
    SERVER_BIN="$ISTORE_DIR/istore-server"
  else
    # 在目录里查找可能命名的二进制
    cand=$(find "$ISTORE_DIR" -maxdepth 2 -type f -perm /111 -name "*istore*" | head -n1 || true)
    if [ -n "$cand" ]; then
      SERVER_BIN="$cand"
    else
      # 尝试在解压目录下寻找任何可执行文件
      cand2=$(find "$ISTORE_DIR" -maxdepth 2 -type f -perm /111 | head -n1 || true)
      SERVER_BIN="${cand2:-}"
    fi
  fi

  if [ -z "${SERVER_BIN:-}" ]; then
    echo -e "${RED}找不到可执行的 istore-server，安装失败（查看 $LOGFILE）${NC}"
    exit 1
  fi

  chmod +x "$SERVER_BIN"
  # 写 systemd
  cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=iStore Web Service
After=network.target

[Service]
ExecStart=${SERVER_BIN} --port ${ISTORE_PORT} --ui ${ISTORE_DIR}/istore-ui
WorkingDirectory=${ISTORE_DIR}
Restart=always
User=root
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  systemctl enable istore.service
  systemctl restart istore.service || true
  sleep 1
  if systemctl is-active --quiet istore; then
    IP=$(hostname -I | awk '{print $1}')
    echo -e "${GREEN}✅ iStore 已启动: http://${IP}:${ISTORE_PORT}${NC}"
  else
    echo -e "${RED}❌ iStore 启动失败，请查看 systemctl status istore 与 $LOGFILE${NC}"
    systemctl status istore --no-pager || true
  fi
}

uninstall_istore(){
  title "卸载 iStore"
  systemctl stop istore 2>/dev/null || true
  systemctl disable istore 2>/dev/null || true
  rm -f "$SERVICE_FILE"
  rm -rf "$ISTORE_DIR"
  systemctl daemon-reload
  echo -e "${GREEN}卸载完成${NC}"
}

# interact menu
detect_arch
detect_sys
install_deps

while true; do
  echo -e "\n${YELLOW}系统: $SYS  架构: $ARCH_ALIAS${NC}"
  echo "1) 安装 / 修复 iStore"
  echo "2) 卸载 iStore"
  echo "3) 重启 服务"
  echo "4) 查看 服务 状态"
  echo "0) 退出"
  read -p "请输入选项: " opt
  case "$opt" in
    1) choose_source_and_get_urls; install_istore ;;
    2) uninstall_istore ;;
    3) systemctl restart istore && echo "已重启" ;;
    4) systemctl status istore --no-pager || true ;;
    0) exit 0 ;;
    *) echo "无效选项" ;;
  esac
done
