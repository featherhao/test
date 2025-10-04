#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

# 一键安装脚本：ZtoApi (OpenAI-compatible API proxy for Z.ai GLM-4.6)
# Usage:
#   sudo ./install_zto_api.sh [--repo REPO_URL] [--branch BRANCH] [--port PORT] [--docker] [--no-systemd]
#
# 默认行为：克隆 https://github.com/your-username/ZtoApi.git 到 /opt/zto-api，编译并以 systemd 服务运行
#
# 注意：为了安全，请在运行后编辑 /opt/zto-api/.env.local 填入你的 ZAI_TOKEN / DEFAULT_KEY 等
# 作者：ChatGPT (示例脚本) — 仅供参考，请在生产部署前检查

# -------------------------
# 默认配置（可通过命令行覆盖）
# -------------------------
REPO_URL="https://github.com/your-username/ZtoApi.git"
BRANCH="main"
INSTALL_DIR="/opt/zto-api"
PORT="9090"
USE_DOCKER=false
ENABLE_SYSTEMD=true
GO_MIN_VERSION="1.23"

# -------------------------
# 解析参数
# -------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo) REPO_URL="$2"; shift 2;;
    --branch) BRANCH="$2"; shift 2;;
    --dir) INSTALL_DIR="$2"; shift 2;;
    --port) PORT="$2"; shift 2;;
    --docker) USE_DOCKER=true; shift;;
    --no-systemd) ENABLE_SYSTEMD=false; shift;;
    --help|-h) sed -n '1,120p' "$0"; exit 0;;
    *) echo "Unknown arg: $1"; exit 1;;
  esac
done

# -------------------------
# helper
# -------------------------
echo_info() { printf "\e[32m[INFO]\e[0m %s\n" "$*"; }
echo_warn() { printf "\e[33m[WARN]\e[0m %s\n" "$*"; }
echo_err()  { printf "\e[31m[ERROR]\e[0m %s\n" "$*"; }

require_root() {
  if [[ "$EUID" -ne 0 ]]; then
    echo_warn "建议以 root / sudo 运行以完成 systemd 服务与端口监听（会尝试继续，但某些步骤会失败）"
  fi
}

# -------------------------
# 开始
# -------------------------
require_root
echo_info "开始部署 ZtoApi（OpenAI-compatible proxy for Z.ai GLM-4.6）"
echo_info "仓库: $REPO_URL"
echo_info "分支: $BRANCH"
echo_info "安装目录: $INSTALL_DIR"
echo_info "端口: $PORT"
echo_info "使用 Docker: $USE_DOCKER"
echo_info "启用 systemd: $ENABLE_SYSTEMD"

# -------------------------
# 准备目录
# -------------------------
if [[ -d "$INSTALL_DIR" && ! -d "$INSTALL_DIR/.git" ]]; then
  echo_warn "目录 $INSTALL_DIR 已存在但不是 git 仓库，保留并继续"
fi

mkdir -p "$INSTALL_DIR"
chown "$(whoami):$(whoami)" "$INSTALL_DIR" || true

# -------------------------
# 安装 git（如果没有）
# -------------------------
if ! command -v git >/dev/null 2>&1; then
  echo_info "检测到未安装 git，尝试安装..."
  if command -v apt-get >/dev/null 2>&1; then
    apt-get update && apt-get install -y git || true
  elif command -v yum >/dev/null 2>&1; then
    yum install -y git || true
  else
    echo_warn "未能自动安装 git，请手动安装后重试"
  fi
fi

# -------------------------
# 克隆或更新仓库
# -------------------------
if [[ -d "$INSTALL_DIR/.git" ]]; then
  echo_info "仓库已存在，尝试拉取最新代码..."
  pushd "$INSTALL_DIR" >/dev/null
  git fetch --all --prune || true
  git checkout "$BRANCH" 2>/dev/null || true
  git pull --ff-only origin "$BRANCH" || true
  popd >/dev/null
else
  echo_info "克隆仓库到 $INSTALL_DIR ..."
  rm -rf "$INSTALL_DIR"
  git clone --depth 1 --branch "$BRANCH" "$REPO_URL" "$INSTALL_DIR"
fi

# -------------------------
# 生成示例 .env.local（如果不存在）
# -------------------------
ENV_FILE="$INSTALL_DIR/.env.local"
if [[ ! -f "$ENV_FILE" ]]; then
  echo_info "生成示例环境文件 $ENV_FILE （记得编辑填入真实 token/key）"
  cat > "$ENV_FILE" <<EOF
# ZtoApi .env.local 示例
# 注意：不要将真实的 ZAI_TOKEN 提交到公共仓库
# ZAI_TOKEN 为空时会启用匿名 token 机制（每次对话不同）
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
  echo_info "已写入示例 .env.local。请用编辑器修改： nano $ENV_FILE"
else
  echo_info "$ENV_FILE 已存在，保留现有配置"
fi

# -------------------------
# 编译或 Docker 构建
# -------------------------
pushd "$INSTALL_DIR" >/dev/null

if [[ "$USE_DOCKER" == true ]]; then
  # 检查 docker
  if ! command -v docker >/dev/null 2>&1; then
    echo_warn "Docker 未安装。尝试安装 docker 或使用非 Docker 模式编译运行。"
  else
    echo_info "构建 Docker 镜像 zto-api:latest ..."
    # 尝试使用仓库内 Dockerfile
    if [[ -f Dockerfile ]]; then
      docker build -t zto-api:latest .
    else
      echo_warn "仓库中未检测到 Dockerfile，生成临时 Dockerfile 并构建..."
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

    echo_info "运行容器（后台，映射端口 $PORT -> 9090）"
    docker rm -f zto-api-container 2>/dev/null || true
    docker run -d --name zto-api-container -p "${PORT}:9090" \
      -v "$ENV_FILE:/app/.env.local:ro" \
      zto-api:latest
    echo_info "Docker 容器已启动。使用：docker logs -f zto-api-container"
    popd >/dev/null
    echo_info "部署完成（Docker 模式）。访问: http://$(hostname -I | awk '{print $1}'):${PORT}/v1/models"
    exit 0
  fi
fi

# 非 Docker 模式 -> 需要 Go 环境
if ! command -v go >/dev/null 2>&1; then
  echo_warn "未检测到 go。尝试自动安装 go ${GO_MIN_VERSION}（仅支持常见发行版）"
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

# go 版本检测（非严格）
if command -v go >/dev/null 2>&1; then
  echo_info "Go 版本： $(go version || true)"
fi

# 尝试构建
echo_info "开始构建可执行文件..."
# 如果仓库提供 Makefile 或 build 脚本，优先使用
if [[ -f Makefile ]]; then
  make build || true
fi

# 直接用 go build（假设主入口为 main.go）
BUILD_BINARY="/usr/local/bin/zto-api"
echo_info "go build -o ${BUILD_BINARY} ..."
# 为了兼容，尝试用 go build mod tidy && go build
if [[ -f go.mod ]]; then
  export CGO_ENABLED=0
  go mod tidy || true
  go build -v -o "$BUILD_BINARY" ./... || go build -v -o "$BUILD_BINARY" main.go || true
else
  go build -v -o "$BUILD_BINARY" main.go || go build -v -o "$BUILD_BINARY" ./... || true
fi

if [[ ! -f "$BUILD_BINARY" ]]; then
  # 备选：项目可能生成二进制到 ./bin 或 ./build
  echo_warn "没有在 ${BUILD_BINARY} 找到生成的二进制，尝试在项目内查找可执行文件..."
  FOUND_BIN=$(find . -maxdepth 2 -type f -perm -111 -name "zto-api" -print -quit || true)
  if [[ -n "$FOUND_BIN" ]]; then
    echo_info "找到可执行文件：$FOUND_BIN，复制到 ${BUILD_BINARY}"
    cp "$FOUND_BIN" "$BUILD_BINARY"
  else
    echo_err "构建失败：找不到生成的可执行文件。请在仓库中检查构建方式（Makefile / build 脚本 / main.go）。"
    popd >/dev/null
    exit 1
  fi
fi

chmod +x "$BUILD_BINARY"
echo_info "可执行文件已安装： $BUILD_BINARY"

# 生成 start.sh（便于直接运行）
cat > "$INSTALL_DIR/start.sh" <<EOF
#!/usr/bin/env bash
set -Eeuo pipefail
cd "$(dirname "\${BASH_SOURCE[0]}")"
# 自动加载 .env.local
if [[ -f .env.local ]]; then
  export \$(grep -v '^#' .env.local | xargs)
fi
# 启动
exec /usr/local/bin/zto-api
EOF
chmod +x "$INSTALL_DIR/start.sh"
echo_info "已生成 $INSTALL_DIR/start.sh"

# -------------------------
# systemd 单元（可选）
# -------------------------
SERVICE_NAME="zto-api.service"
SERVICE_PATH="/etc/systemd/system/${SERVICE_NAME}"

if [[ "$ENABLE_SYSTEMD" == true ]]; then
  echo_info "尝试创建 systemd 服务: $SERVICE_PATH"
  cat > "$SERVICE_PATH" <<EOF
[Unit]
Description=ZtoApi (OpenAI-compatible proxy for Z.ai GLM-4.6)
After=network.target

[Service]
Type=simple
WorkingDirectory=${INSTALL_DIR}
EnvironmentFile=-${ENV_FILE}
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
    echo_info "systemd 服务已写入并尝试启动： systemctl status ${SERVICE_NAME}（如需查看日志： journalctl -u ${SERVICE_NAME} -f）"
  else
    echo_warn "未检测到 systemctl，跳过 systemd 启动。你可以手动运行 ${INSTALL_DIR}/start.sh"
  fi
fi

popd >/dev/null

# -------------------------
# 健康检查（简单 curl 测试）
# -------------------------
sleep 1
HOST_IP="$(hostname -I 2>/dev/null | awk '{print $1}' || echo "127.0.0.1")"
URL="http://${HOST_IP}:${PORT}/v1/models"
echo_info "进行健康检查： $URL"
if command -v curl >/dev/null 2>&1; then
  set +e
  RESP=$(curl -sS --max-time 5 "$URL" || true)
  set -e
  if [[ -n "$RESP" ]]; then
    echo_info "检测到响应（可能正常）："
    echo "$RESP" | sed -n '1,20p'
  else
    echo_warn "未检测到响应，请确认服务是否启动或端口是否被占用。尝试查看日志："
    if command -v systemctl >/dev/null 2>&1; then
      echo "  sudo journalctl -u ${SERVICE_NAME} -f --no-pager"
    else
      echo "  tail -n 200 ${INSTALL_DIR}/logs/* (若存在)"
    fi
  fi
else
  echo_warn "系统未安装 curl，跳过健康检查"
fi

# -------------------------
# 后续提示
# -------------------------
echo
echo_info "部署步骤已完成（或已尝试）。请执行以下操作以完成配置："
echo "  1) 编辑环境文件并填入你的 token/key："
echo "       nano ${ENV_FILE}"
echo "     请确保不要将真实 token 推送到公开仓库，建议把 .env.local 加入 .gitignore"
echo "  2) 如果你修改了 .env.local，请重启服务："
if command -v systemctl >/dev/null 2>&1 && [[ "$ENABLE_SYSTEMD" == true ]]; then
  echo "       sudo systemctl restart ${SERVICE_NAME}"
else
  echo "       cd ${INSTALL_DIR} && ./start.sh &"
fi
echo "  3) 访问 API 文档： http://${HOST_IP}:${PORT}/docs"
echo "  4) 测试接口："
echo "       curl -X GET http://${HOST_IP}:${PORT}/v1/models"
echo
echo_info "安全建议：不要将 ZAI_TOKEN / DEFAULT_KEY 提交到公共仓库。将 ${ENV_FILE} 加入仓库根目录的 .gitignore。"
echo_info "如果需要我把脚本改成只用 Docker、或在其他发行版上做特殊适配（比如 Amazon Linux / Rocky / Alma），告诉我你要的方式及目标主机信息（系统/是否能 sudo）。"

exit 0
