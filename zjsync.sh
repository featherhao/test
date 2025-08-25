#!/bin/bash
set -e

CONFIG_FILE="/etc/zjsync_tasks.conf"
mkdir -p /etc
mkdir -p /usr/local/bin

# ====== 读取已有任务 ======
declare -A TASKS
if [ -f "$CONFIG_FILE" ]; then
    current_task=""
    while IFS= read -r line; do
        line="${line%%#*}"  # 去掉注释
        line="${line%%$'\r'}"
        if [[ "$line" =~ \[task([0-9]+)\] ]]; then
            current_task="${BASH_REMATCH[1]}"
        elif [[ "$line" =~ ^([^=]+)=(.*)$ ]]; then
            key="${BASH_REMATCH[1]}"
            value="${BASH_REMATCH[2]}"
            TASKS["$current_task-$key"]="$value"
        fi
    done < "$CONFIG_FILE"
fi

# ====== 菜单 ======
while true; do
echo
echo "===== zjsync 批量管理 ====="
echo "1) 添加新同步任务"
echo "2) 查看/编辑已有任务"
echo "3) 执行所有任务一次同步"
echo "4) 退出"
read -p "请选择操作 [1-4]: " CHOICE

case "$CHOICE" in
1)
    # ===== 添加新任务 =====
    TASK_NUM=1
    while [[ -n "${TASKS[$TASK_NUM-URL]}" ]]; do
        ((TASK_NUM++))
    done
    echo "添加任务编号: $TASK_NUM"

    # 输入 URL
    while true; do
        read -p "请输入 GitHub 文件 URL: " URL
        [ -n "$URL" ] && break
        echo "❌ URL 不能为空"
    done

    # 保存目录
    read -p "保存目录 (默认 /var/www/zj): " DEST
    DEST=${DEST:-/var/www/zj}

    # 自动解析 URL
    TOKEN_IN_URL=""
    if [[ "$URL" =~ github\.com/([^/]+)/([^/]+)/blob/([^/]+)/(.+) ]]; then
        REPO="${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
        BRANCH="${BASH_REMATCH[3]}"
        FILE="${BASH_REMATCH[4]}"
        RAW_URL="https://raw.githubusercontent.com/${REPO}/${BRANCH}/${FILE}"
    elif [[ "$URL" =~ raw\.githubusercontent\.com/([^/]+)/([^/]+)/refs/heads/([^/]+)/([^?]+)\?token=(.+) ]]; then
        REPO="${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
        BRANCH="${BASH_REMATCH[3]}"
        FILE="${BASH_REMATCH[4]}"
        TOKEN_IN_URL="${BASH_REMATCH[5]}"
        RAW_URL="https://raw.githubusercontent.com/${REPO}/${BRANCH}/${FILE}"
    else
        echo "❌ URL 格式错误"
        continue
    fi

    # 文件名
    read -p "保存文件名 (默认 ${FILE}.txt): " NAME
    NAME=${NAME:-${FILE}.txt}

    # 同步间隔
    read -p "同步间隔(分钟, 默认 5): " MINUTES
    MINUTES=${MINUTES:-5}

    # 访问方式
    if [ -n "$TOKEN_IN_URL" ]; then
        echo "检测到 URL 带 token，默认使用 Token 模式"
        MODE=1
        TOKEN="$TOKEN_IN_URL"
    else
        read -p "访问方式 (1=Token, 2=SSH) [1]: " MODE
        MODE=${MODE:-1}
        if [ "$MODE" = "1" ]; then
            read -p "请输入 GitHub Token: " TOKEN
        fi
    fi

    mkdir -p "$DEST"
    SCRIPT="/usr/local/bin/zjsync-${NAME}.sh"

    # ===== 生成同步脚本 =====
    if [ "$MODE" = "1" ]; then
cat > "$SCRIPT" <<EOF
#!/bin/bash
curl -H "Authorization: token $TOKEN" -H "Accept: application/vnd.github.v3.raw" -fsSL "$RAW_URL" -o "${DEST}/${NAME}"
EOF
    else
cat > "$SCRIPT" <<EOF
#!/bin/bash
cd "$DEST"
if [ ! -d ".git" ]; then
    git clone git@github.com:${REPO}.git .
fi
git fetch --all
git checkout $BRANCH
git reset --hard origin/$BRANCH
cp "$FILE" "$NAME"
EOF
    fi
    chmod +x "$SCRIPT"

    # ===== 添加 cron =====
    CRON="*/${MINUTES} * * * *"
    (crontab -l 2>/dev/null; echo "${CRON} ${SCRIPT} >> /var/log/zjsync-${NAME}.log 2>&1") | crontab -

    # ===== 保存到配置文件 =====
    {
        echo "[task$TASK_NUM]"
        echo "URL=$URL"
        echo "DEST=$DEST"
        echo "NAME=$NAME"
        echo "MINUTES=$MINUTES"
        echo "MODE=$MODE"
        [ "$MODE" = "1" ] && echo "TOKEN=$TOKEN"
    } >> "$CONFIG_FILE"

    echo "✅ 任务 $TASK_NUM 添加完成, 脚本: $SCRIPT"
    ;;
2)
    # ===== 查看已有任务 =====
    echo "===== 当前任务列表 ====="
    grep "^\[task" "$CONFIG_FILE" || echo "没有任务"
    echo
    read -p "按回车返回菜单..."
    ;;
3)
    # ===== 执行所有任务 =====
    grep "NAME=" "$CONFIG_FILE" | while IFS='=' read -r _ taskname; do
        SCRIPT="/usr/local/bin/zjsync-${taskname}.sh"
        if [ -f "$SCRIPT" ]; then
            echo "📌 执行 $SCRIPT"
            $SCRIPT
            echo "最近日志（最后 10 行）："
            tail -n 10 /var/log/zjsync-${taskname}.log
            echo
        fi
    done
    read -p "按回车返回菜单..."
    ;;
4)
    exit 0
    ;;
*)
    echo "❌ 请选择 1-4"
    ;;
esac
done
