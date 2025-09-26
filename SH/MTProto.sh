#!/usr/bin/env bash
set -e

IMAGE="telegrammessenger/proxy:latest"
CONTAINER_NAME="tg-mtproxy"
DATA_DIR="/etc/tg-proxy"
SECRET_FILE="${DATA_DIR}/secret"
DEFAULT_PORT=6688
PORT=""
SECRET=""

# 确保脚本使用 Bash 运行
if [ -z "$BASH_VERSION" ]; then
    echo -e "\033[1;31m错误：请使用 Bash 运行此脚本，例如: bash $0\033[0m"
    exit 1
fi

info() { printf "\033[1;34m%s\033[0m\n" "$*"; }
warn() { printf "\033[1;33m%s\033[0m\n" "$*"; }
error() { printf "\033[1;31m%s\033[0m\n" "$*"; exit 1; }

# ================= 系统依赖检查 =================
check_deps() {
    for cmd in curl docker openssl; do
        if ! command -v $cmd >/dev/null 2>&1; then
            if command -v apk >/dev/null 2>&1; then
                info "安装依赖 $cmd"
                apk add --no-cache $cmd
                # 修复 Alpine 缺少 ss 命令的问题
                [ "$cmd" == "docker" ] && apk add --no-cache iproute2
            elif command -v apt >/dev/null 2>&1; then
                info "安装依赖 $cmd"
                apt update && apt install -y $cmd iproute2
            elif command -v yum >/dev/null 2>&1; then
                info "安装依赖 $cmd"
                yum install -y $cmd iproute2
            else
                warn "未找到包管理器，请手动安装 $cmd 和 iproute2"
            fi
        fi
    done

    # Alpine 自动启动 Docker (不会影响 systemd/Ubuntu)
    if command -v rc-status >/dev/null 2>&1; then
        rc-update add docker boot 2>/dev/null || true
        service docker start || true
    fi

    # 检查 docker 可用性
    if ! docker info >/dev/null 2>&1; then
        error "Docker 未启动或无权限访问 /var/run/docker.sock"
    fi
}

# ================= 查找空闲端口 =================
find_free_port() {
    port="$1"
    # 使用 ss 检查端口占用，依赖 iproute2
    while ss -ltn 2>/dev/null | awk '{print $4}' | grep -q ":$port\$"; do
        port=$((port + 1))
    done
    echo "$port"
}

# ================= 生成 secret (保持不变) =================
generate_secret() {
    mkdir -p "$DATA_DIR"
    if [ -f "$SECRET_FILE" ]; then
        SECRET=$(cat "$SECRET_FILE")
    else
        if command -v openssl >/dev/null 2>&1; then
            SECRET=$(openssl rand -hex 16)
        else
            SECRET=$(head -c 16 /dev/urandom | od -An -tx1 | tr -d ' \n')
        fi
        echo -n "$SECRET" > "$SECRET_FILE"
    fi
}

# ================= 获取公网 IP (保持不变) =================
public_ip() {
    curl -fs --max-time 5 https://api.ipify.org \
    || curl -fs --max-time 5 https://ip.sb \
    || curl -fs --max-time 5 https://ipinfo.io/ip \
    || echo "UNKNOWN"
}

# ================= 启动容器 (增加错误处理) =================
run_container() {
    docker stop "$CONTAINER_NAME" 2>/dev/null || true
    docker rm "$CONTAINER_NAME" 2>/dev/null || true

    if ! docker run -d --name "$CONTAINER_NAME" --restart unless-stopped \
        -p "${PORT}:${PORT}" \
        -e "MTPROXY_SECRET=$SECRET" \
        -e "MTPROXY_PORT=$PORT" \
        "$IMAGE"; then
            
            # 捕获 LXC/Quota 错误
            LOG=$(docker logs "$CONTAINER_NAME" 2>&1 || true)
            if echo "$LOG" | grep -q "disk quota exceeded"; then
                error "
Docker 容器启动失败，错误原因很可能是您运行在 LXC/容器化的 VPS 上，存在 **Keyring 限制**。

请执行以下步骤修复：
1.  编辑 Docker 配置文件： \033[1;33msudo mkdir -p /etc/docker && sudo echo '{\"userns-remap\": \"default\"}' > /etc/docker/daemon.json\033[0m
2.  重启 Docker 服务： \033[1;33msudo service docker restart\033[0m
3.  \033[1;34m再次运行此脚本\033[0m
                "
            else
                error "Docker 容器启动失败，请检查权限或磁盘空间。详细日志：\n$(docker logs "$CONTAINER_NAME" 2>&1 || true)"
            fi
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
    # 尝试使用旧端口，否则寻找新端口
    OLD_PORT=$(docker inspect -f '{{range .Config.Env}}{{if hasPrefix . "MTPROXY_PORT"}}{{.}}{{end}}{{end}}' "$CONTAINER_NAME" 2>/dev/null | cut -d '=' -f 2)
    PORT=${OLD_PORT:-$(find_free_port "$DEFAULT_PORT")}
    
    docker pull "$IMAGE"
    run_container
    show_info
}

# ================= 更改端口 =================
change_port() {
    # 避免在 ash 中出现 'syntax error: bad substitution'
    read -r -p "请输入新的端口号 (留空自动选择): " new_port
    if [ -z "$new_port" ]; then
        PORT=$(find_free_port "$DEFAULT_PORT")
    else
        PORT=$(find_free_port "$new_port")
    fi
    run_container
    show_info
}

# ================= 更改 secret =================
change_secret() {
    if command -v openssl >/dev/null 2>&1; then
        SECRET=$(openssl rand -hex 16)
    else
        SECRET=$(head -c 16 /dev/urandom | od -An -tx1 | tr -d ' \n')
    fi
    echo -n "$SECRET" > "$SECRET_FILE"
    run_container
    show_info
}

# ================= 查看日志 (保持不变) =================
show_logs() {
    docker logs -f "$CONTAINER_NAME"
}

# ================= 卸载 (保持不变) =================
uninstall() {
    docker stop "$CONTAINER_NAME" 2>/dev/null || true
    docker rm "$CONTAINER_NAME" 2>/dev/null || true
    warn "容器已移除"
    read -r -p "是否删除镜像 $IMAGE? (y/N): " yn
    [ "$yn" = "y" ] || [ "$yn" = "Y" ] && docker rmi "$IMAGE"
    read -r -p "是否删除数据目录 $DATA_DIR? (y/N): " yn2
    [ "$yn2" = "y" ] || [ "$yn2" = "Y" ] && rm -rf "$DATA_DIR"
}

# ================= 显示节点信息 (保持不变) =================
show_info() {
    IP=$(public_ip)
    # 此处的变量替换在 bash 中无碍，现在脚本已强制使用 bash 运行。
    PROXY_LINK="tg://proxy?server=${IP}&port=${PORT}&secret=${SECRET}"
    TME_LINK="https://t.me/proxy?server=${IP}&port=${PORT}&secret=${SECRET}"

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

# ================= 菜单 (保持不变) =================
menu() {
    while :; do
        echo "请选择操作："
        echo " 1) 安装"
        echo " 2) 更新"
        echo " 3) 卸载"
        echo " 4) 查看信息"
        echo " 5) 更改端口"
        echo " 6) 更改 secret"
        echo " 7) 查看日志"
        echo " 8) 退出"
        read -r -p "请输入选项 [1-8]: " choice
        case "$choice" in
            1) install ;;
            2) update ;;
            3) uninstall ;;
            4) show_info ;;
            5) change_port ;;
            6) change_secret ;;
            7) show_logs ;;
            8) exit 0 ;;
            *) warn "输入无效，请重新输入" ;;
        esac
    done
}

# 启动菜单
menu