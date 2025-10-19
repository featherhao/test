#!/bin/bash
set -Eeuo pipefail

# ==============================
# iStore 一键安装脚本 (Ubuntu / Armbian)
# 作者: ChatGPT (2025)
# ==============================

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

ISTORE_DIR="/opt/istore"
ISTORE_PORT=81
SYSTEMD_SERVICE="/etc/systemd/system/istore.service"

echo -e "${GREEN}=== iStore 一键安装脚本 ===${NC}"

# ------------------------------
# 检测系统架构
# ------------------------------
ARCH=$(uname -m)
case "$ARCH" in
  x86_64) ARCH_ALIAS="x86_64" ;;
  aarch64) ARCH_ALIAS="aarch64" ;;
  armv7l) ARCH_ALIAS="armv7" ;;
  *) echo -e "${RED}不支持的架构: $ARCH${NC}"; exit 1 ;;
esac

# ------------------------------
# 检测系统类型
# ------------------------------
if grep -qi "ubuntu" /etc/os-release; then
  SYS="Ubuntu"
elif grep -qi "armbian" /etc/os-release; then
  SYS="Armbian"
else
  SYS="Unknown"
fi

echo -e "${YELLOW}系统: $SYS${NC}"
echo -e "${YELLOW}架构: $ARCH_ALIAS${NC}"

# ------------------------------
# 安装依赖
# ------------------------------
echo -e "${GREEN}安装依赖中...${NC}"
apt update -y && apt install -y curl wget unzip tar ca-certificates systemd

# ------------------------------
# 选择安装源
# ------------------------------
echo -e "${YELLOW}请选择安装源:${NC}"
echo "1) 官方源 (GitHub)"
echo "2) 国内镜像 (ghproxy.cn)"
read -p "请输入选项 [1/2, 默认1]: " SOURCE_CHOICE
SOURCE_CHOICE=${SOURCE_CHOICE:-1}

if [ "$SOURCE_CHOICE" = "2" ]; then
  BASE_URL="https://mirror.ghproxy.cn/https://github.com/linkease/istore/releases/latest/download"
else
  BASE_URL="https://github.com/linkease/istore/releases/latest/download"
fi

# ------------------------------
# 创建安装目录
# ------------------------------
mkdir -p "$ISTORE_DIR"
cd "$ISTORE_DIR"

# ------------------------------
# 下载并安装
# ------------------------------
SERVER_FILE="istore-server-linux-${ARCH_ALIAS}.tar.gz"
UI_FILE="istore-ui-${ARCH_ALIAS}.tar.gz"

echo -e "${GREEN}下载 iStore 组件中...${NC}"
curl -fSL "$BASE_URL/$SERVER_FILE" -o "$SERVER_FILE"
curl -fSL "$BASE_URL/$UI_FILE" -o "$UI_FILE"

echo -e "${GREEN}解压中...${NC}"
tar -xzf "$SERVER_FILE" -C "$ISTORE_DIR"
tar -xzf "$UI_FILE" -C "$ISTORE_DIR"

chmod +x "$ISTORE_DIR"/istore-server

# ------------------------------
# 创建 systemd 服务
# ------------------------------
cat > "$SYSTEMD_SERVICE" <<EOF
[Unit]
Description=iStore Web Service
After=network.target

[Service]
ExecStart=$ISTORE_DIR/istore-server --port $ISTORE_PORT --ui $ISTORE_DIR/istore-ui
WorkingDirectory=$ISTORE_DIR
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable istore.service
systemctl restart istore.service

# ------------------------------
# 检查服务状态
# ------------------------------
sleep 2
if systemctl is-active --quiet istore; then
  IP=$(hostname -I | awk '{print $1}')
  echo -e "${GREEN}✅ iStore 已启动成功！${NC}"
  echo -e "访问地址: ${YELLOW}http://$IP:$ISTORE_PORT${NC}"
else
  echo -e "${RED}❌ iStore 启动失败，请使用 'systemctl status istore' 检查日志${NC}"
fi

# ------------------------------
# 提供卸载选项
# ------------------------------
echo
echo -e "${YELLOW}是否创建卸载脚本？(y/N)${NC}"
read -r UNINSTALL
if [[ "$UNINSTALL" =~ ^[Yy]$ ]]; then
  cat > /usr/local/bin/uninstall-istore <<EOF
#!/bin/bash
systemctl stop istore 2>/dev/null || true
systemctl disable istore 2>/dev/null || true
rm -f /etc/systemd/system/istore.service
rm -rf $ISTORE_DIR
systemctl daemon-reload
echo "iStore 已卸载完成。"
EOF
  chmod +x /usr/local/bin/uninstall-istore
  echo -e "${GREEN}卸载命令已创建: uninstall-istore${NC}"
fi
