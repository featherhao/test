#!/bin/bash
# ==========================================================
# Frp Server One-click Install / Uninstall / Update / Info
# Author: Clang + MvsCode (Enhanced by ChatGPT)
# Supports: CentOS / Debian / Ubuntu / Fedora
# ==========================================================

set -Eeuo pipefail

FRPS_DIR="/usr/local/frps"
FRPS_BIN="$FRPS_DIR/frps"
FRPS_CFG="$FRPS_DIR/frps.ini"
FRPS_SERVICE="/etc/systemd/system/frps.service"
REPO_URL="https://api.github.com/repos/fatedier/frp/releases/latest"
ARCH=$(uname -m)

# ========== 彩色输出 ==========
C_GREEN="\033[32m"; C_RED="\033[31m"; C_YELLOW="\033[33m"; C_BLUE="\033[34m"; C_RESET="\033[0m"

# ========== 检查 root 权限 ==========
if [[ $EUID -ne 0 ]]; then
  echo -e "${C_RED}请使用 root 权限运行此脚本${C_RESET}"
  exit 1
fi

# ========== 获取最新版本 ==========
get_latest_version() {
  local latest
  latest=$(curl -fsSL "$REPO_URL" | grep -oP '"tag_name":\s*"\K([^"]+)' | head -1 | tr -d '[:space:]')
  [[ -z "$latest" ]] && { echo "v0.0.0"; return 1; }
  echo "$latest"
}

# ========== 安装 ==========
install_frps() {
  if [[ -x $FRPS_BIN ]]; then
    echo -e "${C_YELLOW}检测到已安装 Frps，请先卸载或更新。${C_RESET}"
    exit 1
  fi

  echo -e "${C_BLUE}正在获取 Frp 最新版本...${C_RESET}"
  local version
  version=$(get_latest_version)
  echo -e "${C_GREEN}检测到最新版本：$version${C_RESET}"

  mkdir -p "$FRPS_DIR"
  cd "$FRPS_DIR"

  local file_name="frp_${version#v}_linux_amd64.tar.gz"
  [[ $ARCH == "aarch64" || $ARCH == "arm64" ]] && file_name="frp_${version#v}_linux_arm64.tar.gz"

  echo -e "${C_BLUE}正在下载：$file_name${C_RESET}"
  wget -q "https://github.com/fatedier/frp/releases/download/${version}/${file_name}" || {
    echo -e "${C_RED}❌ 下载失败，请检查网络或 GitHub 连接${C_RESET}"
    exit 1
  }

  tar -xzf "$file_name" --strip-components=1
  rm -f "$file_name"

  cat > "$FRPS_CFG" <<EOF
[common]
bind_port = 7000
dashboard_port = 7500
dashboard_user = admin
dashboard_pwd = admin
EOF

  cat > "$FRPS_SERVICE" <<EOF
[Unit]
Description=Frp Server Service
After=network.target

[Service]
Type=simple
ExecStart=$FRPS_BIN -c $FRPS_CFG
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  systemctl enable frps
  systemctl start frps

  echo -e "${C_GREEN}✅ Frps 安装完成！${C_RESET}"
  echo -e "Dashboard: http://$(hostname -I | awk '{print $1}'):7500"
  echo -e "配置文件: $FRPS_CFG"
  echo -e "服务控制: systemctl {start|stop|restart|status} frps"
}

# ========== 卸载 ==========
uninstall_frps() {
  echo -e "${C_YELLOW}正在卸载 Frps...${C_RESET}"
  systemctl stop frps 2>/dev/null || true
  systemctl disable frps 2>/dev/null || true
  rm -f "$FRPS_SERVICE"
  rm -rf "$FRPS_DIR"
  systemctl daemon-reload
  echo -e "${C_GREEN}✅ Frps 已卸载干净${C_RESET}"
}

# ========== 更新 ==========
update_frps() {
  if [[ ! -x $FRPS_BIN ]]; then
    echo -e "${C_RED}未检测到安装，请先执行安装。${C_RESET}"
    exit 1
  fi

  echo -e "${C_BLUE}正在获取 Frp 最新版本...${C_RESET}"
  local version
  version=$(get_latest_version)
  echo -e "${C_GREEN}检测到最新版本：$version${C_RESET}"

  cd "$FRPS_DIR"
  local file_name="frp_${version#v}_linux_amd64.tar.gz"
  [[ $ARCH == "aarch64" || $ARCH == "arm64" ]] && file_name="frp_${version#v}_linux_arm64.tar.gz"

  echo -e "${C_BLUE}正在下载更新包：$file_name${C_RESET}"
  wget -q "https://github.com/fatedier/frp/releases/download/${version}/${file_name}" || {
    echo -e "${C_RED}❌ 下载失败，请检查网络或 GitHub 连接${C_RESET}"
    exit 1
  }

  tar -xzf "$file_name" frps --overwrite
  rm -f "$file_name"
  systemctl restart frps
  echo -e "${C_GREEN}✅ Frps 已更新至 $version${C_RESET}"
}

# ========== 查看信息 ==========
info_frps() {
  echo -e "${C_BLUE}================= Frps 信息 =================${C_RESET}"
  if [[ ! -x $FRPS_BIN ]]; then
    echo -e "${C_RED}未检测到安装${C_RESET}"
    return
  fi
  systemctl status frps --no-pager | grep Active || true
  echo "版本：$($FRPS_BIN --version)"
  echo "配置文件路径：$FRPS_CFG"
  echo "运行目录：$FRPS_DIR"
  echo "服务管理：systemctl {start|stop|restart|status} frps"
  echo -e "${C_BLUE}=============================================${C_RESET}"
}

# ========== 主菜单 ==========
menu() {
  clear
  echo -e "${C_GREEN}================ Frps 管理菜单 ================${C_RESET}"
  echo "1) 安装 Frps"
  echo "2) 卸载 Frps"
  echo "3) 更新 Frps"
  echo "4) 查看运行信息"
  echo "0) 退出"
  echo "=============================================="
  read -rp "请选择操作 [0-4]: " choice
  case "$choice" in
    1) install_frps ;;
    2) uninstall_frps ;;
    3) update_frps ;;
    4) info_frps ;;
    0) exit 0 ;;
    *) echo "无效选项" ;;
  esac
}

menu
