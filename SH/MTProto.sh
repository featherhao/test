#!/usr/bin/env bash
set -euo pipefail

# ============================================
# mtproto 一键部署（非容器版）
# 保留原有菜单风格，直接编译并在宿主机运行 mtproto-proxy
# ============================================

SCRIPT_NAME=$(basename "$0")
DATA_DIR="/etc/tg-proxy"
BIN_DIR="${DATA_DIR}/bin"
SRC_DIR="${DATA_DIR}/src"
BIN_FILE="${BIN_DIR}/mtproto-proxy"
SECRET_FILE="${DATA_DIR}/secret"
LOG_FILE="${DATA_DIR}/mtproxy.log"
PID_FILE="${DATA_DIR}/mtproxy.pid"
DEFAULT_PORT=6688

PORT=""
SECRET=""
USER_RUN="nobody"    # 运行用户（可改）

# 彩色输出
info()  { printf "\033[1;34m%s\033[0m\n" "$*"; }
warn()  { printf "\033[1;33m%s\033[0m\n" "$*"; }
error() { printf "\033[1;31m%s\033[0m\n" "$*"; exit 1; }

# ensure bash
if [ -z "${BASH_VERSION:-}" ]; then
    error "请使用 bash 运行脚本，例如: bash $SCRIPT_NAME"
fi

# ------------------ 基础工具检测/安装尝试 ------------------
detect_pkg_mgr() {
    if command -v apt >/dev/null 2>&1; then
        echo "apt"
    elif command -v yum >/dev/null 2>&1; then
        echo "yum"
    elif command -v dnf >/dev/null 2>&1; then
        echo "dnf"
    elif command -v apk >/dev/null 2>&1; then
        echo "apk"
    else
        echo "none"
    fi
}

install_build_deps() {
    PKG=$(detect_pkg_mgr)
    case "$PKG" in
        apt)
            info "检测到 apt，尝试安装编译依赖（需要 sudo）..."
            sudo apt update
            sudo apt install -y build-essential libssl-dev git wget curl || true
            ;;
        yum|dnf)
            info "检测到 yum/dnf，尝试安装编译依赖（需要 sudo）..."
            sudo ${PKG} install -y gcc make openssl-devel git wget curl || true
            ;;
        apk)
            info "检测到 apk (Alpine)，尝试安装编译依赖（需要 sudo）..."
            sudo apk add --no-cache build-base openssl-dev git wget curl || true
            ;;
        *)
            warn "未检测到支持的包管理器，请手动安装: gcc, make, libssl-dev (或 openssl-dev), git, wget, curl"
            ;;
    esac
}

# ------------------ 端口检查 ------------------
find_free_port() {
    local p="$1"
    # 使用 ss 或 netstat 检查
    while :
    do
        if command -v ss >/dev/null 2>&1; then
            if ss -ltn 2>/dev/null | awk '{print $4}' | grep -q ":$p\$"; then
                p=$((p+1)); continue
            fi
        elif command -v netstat >/dev/null 2>&1; then
            if netstat -ltn 2>/dev/null | awk '{print $4}' | grep -q ":$p\$"; then
                p=$((p+1)); continue
            fi
        fi
        break
    done
    echo "$p"
}

# ------------------ secret ------------------
generate_secret() {
    mkdir -p "$DATA_DIR" "$BIN_DIR" "$SRC_DIR"
    if [ -f "$SECRET_FILE" ]; then
        SECRET="$(cat "$SECRET_FILE")"
    else
        if command -v openssl >/dev/null 2>&1; then
            SECRET="$(openssl rand -hex 16)"
        else
            SECRET="$(head -c 16 /dev/urandom | od -An -tx1 | tr -d ' \n')"
        fi
        echo -n "$SECRET" > "$SECRET_FILE"
        info "已生成 secret 并写入 $SECRET_FILE"
    fi
}

# ------------------ 获取公网 IP ------------------
public_ip() {
    # 不使用 web.run —— 尝试常见服务
    curl -fs --max-time 5 https://api.ipify.org \
    || curl -fs --max-time 5 https://ip.sb \
    || curl -fs --max-time 5 https://ifconfig.me \
    || echo "UNKNOWN"
}

# ------------------ 下载并编译 mtproto-proxy ------------------
download_and_build() {
    if [ -x "$BIN_FILE" ]; then
        info "发现已编译的 mtproto-proxy：$BIN_FILE"
        return 0
    fi

    info "开始下载并编译 mtproto-proxy（源码在 $SRC_DIR），这可能需要几分钟..."
    cd "$SRC_DIR"
    # 尝试使用 git clone 官方仓库的 master（兼容多数系统）
    if command -v git >/dev/null 2>&1; then
        if [ -d "$SRC_DIR/.git" ]; then
            info "已有源码仓库，尝试 pull 更新"
            git -C "$SRC_DIR" pull || true
        else
            git clone https://github.com/TelegramMessenger/MTProxy.git "$SRC_DIR" || {
                warn "git clone 失败，尝试使用 tarball 下载"
                rm -rf "$SRC_DIR"/*
            }
        fi
    fi

    # 若目录看起来没源码，尝试用 tarball
    if [ ! -f "$SRC_DIR/Makefile" ] && [ ! -d "$SRC_DIR/objs" ]; then
        info "尝试从 GitHub 下载源码 tarball..."
        wget -qO- https://github.com/TelegramMessenger/MTProxy/archive/refs/heads/master.tar.gz | tar zx --strip-components=1 || true
    fi

    # 常见编译指令（不同源码可能路径不同）
    if [ -f "Makefile" ]; then
        # make 之前确保依赖
        if ! command -v gcc >/dev/null 2>&1 || ! command -v make >/dev/null 2>&1; then
            warn "未发现 gcc 或 make，尝试安装编译依赖..."
            install_build_deps
        fi

        # 编译
        make -j"$(nproc)" || {
            warn "make 编译失败，请检查缺少的依赖并手动编译，或查看 $SRC_DIR 目录。"
            return 1
        }

        # 常见位置 objs/bin/mtproto-proxy 或 objs/mtproto-proxy
        if [ -f "objs/bin/mtproto-proxy" ]; then
            mv -f objs/bin/mtproto-proxy "$BIN_FILE"
        elif [ -f "objs/mtproto-proxy" ]; then
            mv -f objs/mtproto-proxy "$BIN_FILE"
        else
            warn "编译后未找到 mtproto-proxy 可执行文件，请手动检查 $SRC_DIR"
            return 1
        fi
        chmod +x "$BIN_FILE"
        info "编译完成，二进制放在 $BIN_FILE"
    else
        warn "源码中找不到 Makefile，无法自动编译，请手动准备 mtproto-proxy 二进制放到 $BIN_FILE"
        return 1
    fi
}

# ------------------ 启动/停止/状态 ------------------
start_proxy() {
    if [ ! -x "$BIN_FILE" ]; then
        error "未找到可执行文件 $BIN_FILE，请先执行 安装 操作以编译或放置二进制。"
    fi

    if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
        warn "代理看起来已经在运行 (PID $(cat "$PID_FILE"))"
        return 0
    fi

    # 如果没有指定端口，自动选择
    if [ -z "${PORT}" ]; then
        PORT=$(find_free_port "$DEFAULT_PORT")
    fi

    # 启动
    info "启动 mtproto-proxy：端口 $PORT，secret 来自 $SECRET_FILE"
    # 不启用 aes-pwd（混淆）以简化部署；如果你需要混淆请在此处添加 --aes-pwd FILE KEY
    nohup "$BIN_FILE" -u "$USER_RUN" -p "$PORT" -H 0.0.0.0 -S "$SECRET" >> "$LOG_FILE" 2>&1 &

    echo $! > "$PID_FILE"
    sleep 1
    if kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
        info "启动成功 (PID $(cat "$PID_FILE")), 日志: $LOG_FILE"
    else
        warn "启动失败，请查看日志: $LOG_FILE"
        rm -f "$PID_FILE" || true
    fi
}

stop_proxy() {
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")
        if kill -0 "$PID" 2>/dev/null; then
            kill "$PID" && info "已停止 PID $PID"
        else
            warn "PID $PID 不存在"
        fi
        rm -f "$PID_FILE"
    else
        warn "未找到 PID 文件，可能未运行"
    fi
}

status_proxy() {
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")
        if kill -0 "$PID" 2>/dev/null; then
            info "mtproto 正在运行 (PID $PID)"
            ss -ltnp | grep ":$PORT" || true
        else
            warn "PID 文件存在但进程未运行"
        fi
    else
        warn "mtproto 未运行（未找到 $PID_FILE）"
    fi
}

# ------------------ 更新 ------------------
update() {
    info "开始更新：pull/重新编译并重启"
    download_and_build || warn "更新编译失败"
    stop_proxy
    start_proxy
    show_info
}

# ------------------ 更改端口/secret ------------------
change_port() {
    read -r -p "请输入新的端口号 (留空使用自动选择): " new_port
    if [ -z "$new_port" ]; then
        PORT=$(find_free_port "$DEFAULT_PORT")
    else
        PORT=$(find_free_port "$new_port")
    fi
    info "端口已改为 $PORT，正在重启服务..."
    stop_proxy
    start_proxy
    show_info
}

change_secret() {
    if command -v openssl >/dev/null 2>&1; then
        SECRET="$(openssl rand -hex 16)"
    else
        SECRET="$(head -c 16 /dev/urandom | od -An -tx1 | tr -d ' \n')"
    fi
    echo -n "$SECRET" > "$SECRET_FILE"
    info "已生成新 secret 并写入 $SECRET_FILE，正在重启服务..."
    stop_proxy
    start_proxy
    show_info
}

# ------------------ 日志/信息/卸载 ------------------
show_logs() {
    tail -n 500 -f "$LOG_FILE"
}

show_info() {
    IP="$(public_ip)"
    PORT_DISPLAY="${PORT:-$DEFAULT_PORT}"
    PROXY_LINK="tg://proxy?server=${IP}&port=${PORT_DISPLAY}&secret=${SECRET}"
    TME_LINK="https://t.me/proxy?server=${IP}&port=${PORT_DISPLAY}&secret=${SECRET}"

    info "————— Telegram MTProto 代理 信息 —————"
    echo "IP:       $IP"
    echo "端口:     $PORT_DISPLAY"
    echo "secret:   $SECRET"
    echo
    echo "tg:// 链接:"
    echo "$PROXY_LINK"
    echo
    echo "t.me 分享链接:"
    echo "$TME_LINK"
    echo "———————————————————————————————"
}

uninstall() {
    warn "即将停止并移除 mtproto 相关文件"
    stop_proxy
    read -r -p "是否删除数据目录 $DATA_DIR ? (y/N): " yn
    if [ "$yn" = "y" ] || [ "$yn" = "Y" ]; then
        rm -rf "$DATA_DIR"
        info "已删除 $DATA_DIR"
    else
        info "保留 $DATA_DIR"
    fi
}

# ------------------ 安装（编译 + 启动） ------------------
install_all() {
    install_build_deps || warn "自动安装依赖可能失败，请手动确保 gcc/make/libssl-dev/git 等已安装"
    generate_secret
    # 如果调用时提供端口参数则使用
    if [ -z "${PORT:-}" ]; then
        PORT=$(find_free_port "$DEFAULT_PORT")
    fi
    download_and_build || error "编译或获取二进制失败，安装中断"
    start_proxy
    show_info
    info "提示：若需要 systemd 管理（开机自启），可创建一个简单的 systemd unit，脚本后面有说明。"
}

# ------------------ 菜单 ------------------
menu() {
    while :; do
        echo
        echo "请选择操作："
        echo " 1) 安装 (编译并启动)"
        echo " 2) 更新 (重新编译并重启)"
        echo " 3) 卸载"
        echo " 4) 查看信息"
        echo " 5) 更改端口"
        echo " 6) 更改 secret"
        echo " 7) 查看日志"
        echo " 8) 启动"
        echo " 9) 停止"
        echo "10) 状态"
        echo "11) 退出"
        read -r -p "请输入选项 [1-11]: " choice
        case "$choice" in
            1) install_all ;;
            2) update ;;
            3) uninstall ;;
            4) show_info ;;
            5) change_port ;;
            6) change_secret ;;
            7) show_logs ;;
            8) start_proxy ;;
            9) stop_proxy ;;
            10) status_proxy ;;
            11) exit 0 ;;
            *) warn "输入无效，请重新输入" ;;
        esac
    done
}

# 启动菜单
menu
