#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

# =========================================
# ZtoApi 一键安装/更新/卸载/探测脚本（含自动探测真实可达的访问地址与 API 地址）
# - 直接运行即可（回车使用默认）
# - 保留原有安装/构建逻辑，同时增加端点探测并显示准确的地址
# =========================================

# -------------------------
# 默认配置
# -------------------------
REPO_URL="https://github.com/your-username/ZtoApi.git"
BRANCH="main"
INSTALL_DIR="/opt/zto-api"
PORT="9090"
USE_DOCKER=false
ENABLE_SYSTEMD=true
GO_MIN_VERSION="1.23"
SERVICE_NAME="zto-api.service"
BINARY_PATH="/usr/local/bin/zto-api"

# -------------------------
# 彩色输出
# -------------------------
C_RESET="\e[0m"
C_BOLD="\e[1m"
C_GREEN="\e[32m"
C_YELLOW="\e[33m"
C_RED="\e[31m"
echo_info() { printf "${C_GREEN}[INFO]${C_RESET} %s\n" "$*"; }
echo_warn() { printf "${C_YELLOW}[WARN]${C_RESET} %s\n" "$*"; }
echo_err()  { printf "${C_RED}[ERROR]${C_RESET} %s\n" "$*"; }

# -------------------------
# 解析命令行（仍支持，但脚本也可直接运行）
# -------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo) REPO_URL="$2"; shift 2;;
    --branch) BRANCH="$2"; shift 2;;
    --dir) INSTALL_DIR="$2"; shift 2;;
    --port) PORT="$2"; shift 2;;
    --docker) USE_DOCKER=true; shift;;
    --no-systemd) ENABLE_SYSTEMD=false; shift;;
    --help|-h) sed -n '1,240p' "$0"; exit 0;;
    *) echo_err "Unknown arg: $1"; exit 1;;
  esac
done

# -------------------------
# Helper 函数
# -------------------------
require_root() {
  if [[ "$EUID" -ne 0 ]]; then
    echo_warn "建议以 root / sudo 运行以完成 systemd 服务与端口监听（脚本会尝试继续，但某些步骤可能因权限不足失败）"
  fi
}

# 读取 PORT（优先从 .env.local）
read_port_from_envfile() {
  local f="$1"
  if [[ -f "$f" ]]; then
    local p
    p=$(grep -E '^\s*PORT\s*=' "$f" 2>/dev/null | head -n1 | cut -d'=' -f2- | tr -d ' "')
    if [[ -n "$p" ]]; then
      echo "$p"
      return 0
    fi
  fi
  echo ""
  return 1
}

# 简单探测某个 URL，返回状态和 content-type（两个值，用空格分隔）
probe_url() {
  local url="$1"
  # status
  local status
  status=$(curl -sS -o /dev/null -w "%{http_code}" -I -m 3 --connect-timeout 2 "$url" 2>/dev/null || echo "000")
  # content type (may be empty)
  local ctype
  ctype=$(curl -sS -I -m 3 --connect-timeout 2 "$url" 2>/dev/null | tr -d '\r' | awk -F': ' '/[Cc]ontent-Type/ {print $2; exit}' || echo "")
  printf "%s|||%s" "$status" "$ctype"
}

# 判断是否已安装（若 systemd 单元或安装目录或二进制存在）
is_installed() {
  if [[ -f "/etc/systemd/system/${SERVICE_NAME}" ]] || [[ -d "${INSTALL_DIR}/.git" ]] || [[ -f "${BINARY_PATH}" ]]; then
    return 0
  fi
  return 1
}

# 停止并移除 systemd 服务（如果有）
remove_systemd_service() {
  if command -v systemctl >/dev/null 2>&1 && [[ -f "/etc/systemd/system/${SERVICE_NAME}" ]]; then
    systemctl stop "${SERVICE_NAME}" 2>/dev/null || true
    systemctl disable "${SERVICE_NAME}" 2>/dev/null || true
    rm -f "/etc/systemd/system/${SERVICE_NAME}"
    systemctl daemon-reload || true
  fi
}

# -------------------------
# 探测并打印真实可达的地址
# -------------------------
display_detected_addresses() {
  # 获取端口：优先 .env.local
  local envfile="${INSTALL_DIR}/.env.local"
  local port_from_file
  port_from_file=$(read_port_from_envfile "$envfile" || true)
  if [[ -n "$port_from_file" ]]; then
    PORT="$port_from_file"
  fi
  PORT=${PORT:-9090}

  # 获取主机 IP（首个非 loopback），并确保有回退
  local host_ip
  host_ip=$(hostname -I 2>/dev/null | awk '{ for(i=1;i<=NF;i++) if ($i !~ /^127\.|^::1$/) {print $i; exit} }' || true)
  if [[ -z "$host_ip" ]]; then
    # 尝试 ip route 方法
    host_ip=$(ip route get 1.1.1.1 2>/dev/null | awk '/src/ {for(i=1;i<=NF;i++){if($i=="src"){print $(i+1); exit}}}' || true)
  fi
  host_ip=${host_ip:-127.0.0.1}

  # 要探测的常见路径集合
  local paths=( "/docs" "/dashboard" "/v1/models" "/v1/chat/completions" "/openapi.json" "/swagger" "/redoc" "/docs/index.html" "/v1" "/" )

  # 尝试在 127.0.0.1 和 host_ip 上探测
  local addrs=( "127.0.0.1" "${host_ip}" )
  declare -A found_web
  declare -A found_api
  declare -A found_protected

  for a in "${addrs[@]}"; do
    for p in "${paths[@]}"; do
      url="http://${a}:${PORT}${p}"
      # probe (returns "status|||content-type")
      out=$(probe_url "$url")
      status="${out%%|||*}"
      ctype="${out##*|||}"
      # classify
      if [[ "$status" == "000" ]]; then
        # unreachable
        continue
      fi

      if [[ "$status" =~ ^2|^3 ]]; then
        # 2xx or 3xx -> likely reachable
        if [[ -n "$ctype" && "$ctype" =~ html ]]; then
          found_web["$a$p"]="$url (status:$status ctype:$ctype)"
        elif [[ -n "$ctype" && "$ctype" =~ json ]]; then
          found_api["$a$p"]="$url (status:$status ctype:$ctype)"
        else
          # ambiguous but reachable: treat by path heuristics
          if [[ "$p" =~ ^/v1|/openapi|/swagger ]]; then
            found_api["$a$p"]="$url (status:$status ctype:$ctype)"
          else
            found_web["$a$p"]="$url (status:$status ctype:$ctype)"
          fi
        fi
      else
        # not 2xx/3xx: 401/403/405 may still indicate endpoint exists (protected or method-specific)
        if [[ "$status" == "401" || "$status" == "403" ]]; then
          found_protected["$a$p"]="$url (status:$status ctype:$ctype)"
        elif [[ "$status" == "405" ]]; then
          # method not allowed -> likely an API endpoint that requires POST
          found_api["$a$p"]="$url (status:$status ctype:$ctype)"
        else
          # other codes: ignore for now
          continue
        fi
      fi
    done
  done

  # 判断是否只有 localhost 可达（如果 127.0.0.1 可达但 host_ip 不可达）
  local localhost_only=true
  for k in "${!found_web[@]}"; do
    if [[ "${k:0:9}" != "127.0.0.1" ]]; then localhost_only=false; fi
  done
  for k in "${!found_api[@]}"; do
    if [[ "${k:0:9}" != "127.0.0.1" ]]; then localhost_only=false; fi
  done
  for k in "${!found_protected[@]}"; do
    if [[ "${k:0:9}" != "127.0.0.1" ]]; then localhost_only=false; fi
  done

  echo
  echo -e "${C_BOLD}📍 当前服务信息（探测结果）：${C_RESET}"
  echo "--------------------------------"
  if ((${#found_web[@]} + ${#found_api[@]} + ${#found_protected[@]})); then
    if [[ ${#found_web[@]} -gt 0 ]]; then
      echo -e "${C_GREEN}Web 界面 (可能是 docs / dashboard)：${C_RESET}"
      for k in "${!found_web[@]}"; do
        echo "  - ${found_web[$k]}"
      done
      echo
    fi
    if [[ ${#found_api[@]} -gt 0 ]]; then
      echo -e "${C_GREEN}API 接口 (可程序调用)：${C_RESET}"
      for k in "${!found_api[@]}"; do
        echo "  - ${found_api[$k]}"
      done
      echo
    fi
    if [[ ${#found_protected[@]} -gt 0 ]]; then
      echo -e "${C_YELLOW}受保护 / 需授权（返回 401/403）或方法受限（405）的端点：${C_RESET}"
      for k in "${!found_protected[@]}"; do
        echo "  - ${found_protected[$k]}"
      done
      echo
    fi
  else
    echo_warn "未探测到常见的 docs/dashboard 或 v1 接口。请确认服务是否已启动或端口 ${PORT} 是否正确。"
  fi

  if [[ "$localhost_only" == true ]]; then
    echo_warn "注意：服务似乎仅在 127.0.0.1 上可达（外网/局域网主机可能无法直接访问）。"
    echo "如果需要外网访问，请修改服务绑定或使用反向代理/端口转发（例如 nginx 或 ssh -L / iptables 规则）。"
  fi

  echo "--------------------------------"
  echo
}

# -------------------------
# 菜单：安装 / 更新 / 卸载 / 状态（默认回车执行默认项）
# -------------------------
main_menu() {
  require_root

  local installed=false
  if is_installed; then
    installed=true
  fi

  echo "==============================="
  echo "       ZtoApi 管理菜单"
  echo "==============================="

  if [[ "$installed" == true ]]; then
    echo_info "检测到已安装 ZtoApi（systemd 单元或安装目录存在）"
    # 展示探测到的地址
    display_detected_addresses
    echo "1) 更新 ZtoApi (默认)"
    echo "2) 查看服务状态"
    echo "3) 卸载 ZtoApi"
    echo "0) 退出"
    echo "-------------------------------"
    read -rp "请输入选项 [默认: 1]: " action
    action=${action:-1}
  else
    echo_warn "未检测到已安装的 ZtoApi"
    echo "1) 安装 ZtoApi (默认)"
    echo "0) 退出"
    echo "-------------------------------"
    read -rp "请输入选项 [默认: 1]: " action
    action=${action:-1}
  fi

  case "$action" in
    1)
      if [[ "$installed" == true ]]; then
        do_update
      else
        do_install
      fi
      ;;
    2)
      show_status
      ;;
    3)
      do_uninstall
      ;;
    0)
      echo_info "退出"
      exit 0
      ;;
    *)
      echo_warn "无效选项，退出"
      exit 1
      ;;
  esac
}

# -------------------------
# 安装函数（复用并简化你原有逻辑）
# -------------------------
do_install() {
  echo_info "开始安装 ZtoApi..."
  echo_info "仓库: $REPO_URL 分支: $BRANCH 安装目录: $INSTALL_DIR 端口: $PORT"

  # 准备目录
  mkdir -p "$INSTALL_DIR"
  chown "$(whoami):$(whoami)" "$INSTALL_DIR" || true

  # 安装 git 若不存在
  if ! command -v git >/dev/null 2>&1; then
    echo_info "检测未安装 git，尝试安装..."
    if command -v apt-get >/dev/null 2>&1; then
      apt-get update && apt-get install -y git || true
    elif command -v yum >/dev/null 2>&1; then
      yum install -y git || true
    else
      echo_warn "无法自动安装 git，请手动安装后重试"
    fi
  fi

  # 克隆或更新
  if [[ -d "$INSTALL_DIR/.git" ]]; then
    echo_info "仓库已存在，拉取最新..."
    pushd "$INSTALL_DIR" >/dev/null
    git fetch --all --prune || true
    git checkout "$BRANCH" 2>/dev/null || true
    git pull --ff-only origin "$BRANCH" || true
    popd >/dev/null
  else
    echo_info "克隆仓库..."
    rm -rf "$INSTALL_DIR"
    git clone --depth 1 --branch "$BRANCH" "$REPO_URL" "$INSTALL_DIR"
  fi

  # 生成 .env.local 示例（如果不存在）
  local envfile="${INSTALL_DIR}/.env.local"
  if [[ ! -f "$envfile" ]]; then
    cat > "$envfile" <<EOF
# ZtoApi .env.local 示例（由安装脚本生成）
ZAI_TOKEN=
DEFAULT_KEY=sk-your-key
MODEL_NAME=GLM-4.6
PORT=${PORT}
DEBUG_MODE=false
DEFAULT_STREAM=true
DASHBOARD_ENABLED=true
ENABLE_THINKING=false
UPSTREAM_URL=https://chat.z.ai/api/chat/completions
EOF
    echo_info "已生成示例环境文件： $envfile （请根据需要修改）"
  else
    echo_info ".env.local 已存在，保留现有配置"
  fi

  pushd "$INSTALL_DIR" >/dev/null

  # Docker 优先（如果用户传 --docker 或系统中存在 Docker）
  if [[ "$USE_DOCKER" == true && -x "$(command -v docker)" ]]; then
    echo_info "构建并运行 Docker 镜像..."
    if [[ -f Dockerfile ]]; then
      docker build -t zto-api:latest .
    else
      # 生成临时 Dockerfile 并构建（fallback）
      cat > Dockerfile.tmp <<'DOCK'
FROM golang:1.23-alpine AS build
WORKDIR /src
COPY . .
RUN apk add --no-cache git && \
    go env -w GO111MODULE=on && \
    go build -o /zto-api main.go

FROM alpine:3.18
COPY --from=build /zto-api /usr/local/bin/zto-api
EXPOSE 9090
ENTRYPOINT ["/usr/local/bin/zto-api"]
DOCK
      docker build -t zto-api:latest -f Dockerfile.tmp .
      rm -f Dockerfile.tmp
    fi
    docker rm -f zto-api-container 2>/dev/null || true
    docker run -d --name zto-api-container -p "${PORT}:9090" -v "${envfile}:/app/.env.local:ro" zto-api:latest
    popd >/dev/null
    echo_info "Docker 模式部署完成"
    display_detected_addresses
    return 0
  fi

  # 非 Docker -> 尝试编译（需要 go）
  if ! command -v go >/dev/null 2>&1; then
    echo_warn "未检测到 go，尝试自动安装 go ${GO_MIN_VERSION}（仅支持常见发行版）"
    if command -v apt-get >/dev/null 2>&1; then
      apt-get update
      apt-get install -y wget tar || true
      GO_TAR="go1.23.linux-amd64.tar.gz"
      wget -q -c "https://golang.org/dl/${GO_TAR}" -O "/tmp/${GO_TAR}" || true
      tar -C /usr/local -xzf "/tmp/${GO_TAR}" || true
      export PATH=$PATH:/usr/local/go/bin
    elif command -v yum >/dev/null 2>&1; then
      yum install -y wget tar || true
      GO_TAR="go1.23.linux-amd64.tar.gz"
      wget -q -c "https://golang.org/dl/${GO_TAR}" -O "/tmp/${GO_TAR}" || true
      tar -C /usr/local -xzf "/tmp/${GO_TAR}" || true
      export PATH=$PATH:/usr/local/go/bin
    else
      echo_err "无法自动安装 go，请手动安装 Go ${GO_MIN_VERSION} 或更高版本"
      popd >/dev/null
      exit 1
    fi
  fi

  echo_info "开始构建可执行文件..."
  BUILD_BINARY="${BINARY_PATH}"
  if [[ -f Makefile ]]; then
    make build || true
  fi

  if [[ -f go.mod ]]; then
    export CGO_ENABLED=0
    go mod tidy || true
    go build -v -o "$BUILD_BINARY" ./... || go build -v -o "$BUILD_BINARY" main.go || true
  else
    go build -v -o "$BUILD_BINARY" main.go || go build -v -o "$BUILD_BINARY" ./... || true
  fi

  if [[ ! -f "$BUILD_BINARY" ]]; then
    # 尝试在项目内查找可执行文件
    FOUND_BIN=$(find . -maxdepth 3 -type f -perm -111 -name "zto-api" -print -quit || true)
    if [[ -n "$FOUND_BIN" ]]; then
      cp "$FOUND_BIN" "$BUILD_BINARY"
    else
      echo_err "构建失败：找不到可执行文件。请在仓库中检查构建方式（Makefile / main.go）。"
      popd >/dev/null
      exit 1
    fi
  fi

  chmod +x "$BUILD_BINARY"
  echo_info "可执行文件已安装到 ${BUILD_BINARY}"

  # 生成 start.sh
  cat > "${INSTALL_DIR}/start.sh" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
if [[ -f .env.local ]]; then
  export $(grep -v '^#' .env.local | xargs)
fi
exec /usr/local/bin/zto-api
EOF
  chmod +x "${INSTALL_DIR}/start.sh"
  echo_info "已生成 ${INSTALL_DIR}/start.sh"

  # systemd 单元
  if [[ "$ENABLE_SYSTEMD" == true ]]; then
    cat > "/etc/systemd/system/${SERVICE_NAME}" <<EOF
[Unit]
Description=ZtoApi (OpenAI-compatible proxy for Z.ai GLM-4.6)
After=network.target

[Service]
Type=simple
WorkingDirectory=${INSTALL_DIR}
EnvironmentFile=-${INSTALL_DIR}/.env.local
ExecStart=/usr/local/bin/zto-api
Restart=on-failure
RestartSec=3
User=$(whoami)
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF
    if command -v systemctl >/dev/null 2>&1; then
      systemctl daemon-reload || true
      systemctl enable --now "${SERVICE_NAME}" || true
      echo_info "systemd 服务已写入并尝试启动： systemctl status ${SERVICE_NAME}"
    else
      echo_warn "未检测到 systemctl，跳过 systemd 写入"
    fi
  fi

  popd >/dev/null

  echo_info "安装完成，开始探测已启动的端点..."
  # 等待短暂时间让服务起来（如果刚启动）
  sleep 1
  display_detected_addresses
}

# -------------------------
# 更新函数（拉取最新并重启）
# -------------------------
do_update() {
  echo_info "开始更新 ZtoApi..."
  if [[ -d "${INSTALL_DIR}/.git" ]]; then
    pushd "$INSTALL_DIR" >/dev/null
    git fetch --all --prune || true
    git reset --hard "origin/${BRANCH}" || true
    git pull --ff-only origin "$BRANCH" || true
    popd >/dev/null
  else
    echo_warn "未检测到 git 仓库，执行安装流程"
    do_install
    return
  fi

  # 重新构建（如有必要）
  pushd "$INSTALL_DIR" >/dev/null
  if [[ -f Makefile ]]; then
    make build || true
  fi
  if command -v go >/dev/null 2>&1 && [[ -f go.mod ]]; then
    export CGO_ENABLED=0
    go mod tidy || true
    go build -v -o "$BINARY_PATH" ./... || go build -v -o "$BINARY_PATH" main.go || true
  fi
  popd >/dev/null

  if command -v systemctl >/dev/null 2>&1; then
    systemctl restart "${SERVICE_NAME}" 2>/dev/null || true
    echo_info "已重启 systemd 服务 ${SERVICE_NAME}"
  else
    echo_warn "未检测到 systemctl，请手动重启服务（例如： ${INSTALL_DIR}/start.sh）"
  fi

  # 探测并显示
  sleep 1
  display_detected_addresses
}

# -------------------------
# 卸载函数
# -------------------------
do_uninstall() {
  echo_warn "准备卸载 ZtoApi。此操作会删除安装目录和 systemd 单元（若存在）。"
  read -rp "确定要卸载吗？(y/N): " confirm
  if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo_info "已取消卸载"
    return 0
  fi

  # 停止 systemd
  if command -v systemctl >/dev/null 2>&1; then
    systemctl stop "${SERVICE_NAME}" 2>/dev/null || true
    systemctl disable "${SERVICE_NAME}" 2>/dev/null || true
  fi

  # 移除 systemd 文件
  remove_systemd_service

  # Remove docker container if exists
  if command -v docker >/dev/null 2>&1; then
    docker rm -f zto-api-container 2>/dev/null || true
  fi

  # 删除 binary 和安装目录（谨慎）
  if [[ -f "${BINARY_PATH}" ]]; then
    rm -f "${BINARY_PATH}" || true
  fi
  if [[ -d "${INSTALL_DIR}" ]]; then
    rm -rf "${INSTALL_DIR}" || true
  fi

  echo_info "卸载完成（已尝试删除二进制、安装目录和 systemd 单元）"
}

# -------------------------
# 显示服务状态（简单）
# -------------------------
show_status() {
  echo "==============================="
  echo " ZtoApi 服务状态"
  echo "==============================="
  if command -v systemctl >/dev/null 2>&1; then
    systemctl status "${SERVICE_NAME}" --no-pager || true
  else
    echo_warn "systemctl 不可用，尝试显示进程信息"
    pgrep -a zto-api || true
  fi
  display_detected_addresses
}

# -------------------------
# 入口
# -------------------------
main_menu
