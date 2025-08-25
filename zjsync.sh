#!/bin/bash
set -e

CONFIG_FILE="/etc/zjsync_tasks.conf"
LOG_DIR="$HOME/zjsync_logs"
mkdir -p /etc
mkdir -p /usr/local/bin
mkdir -p "$LOG_DIR"

# ====== 读取已有任务 ======
declare -A TASKS
if [ -f "$CONFIG_FILE" ]; then
    current_task=""
    while IFS= read -r line; do
        line="${line%%#*}"
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
echo "2) 查看已有任务"
echo "3) 删除任务"
echo "4) 执行所有任务一次同步"
echo "5) 退出"
read -p "请选择操作 [1-5]: " CHOICE

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
    mkdir -p "$DEST"

    # 文件名
    FILE=$(basename "$URL")
    read -p "保存文件名 (默认 ${FILE}.txt): " NAME
    NAME=${NAME:-${FILE}.txt}

    # 同步间隔
    read -p "同步间隔(分钟, 默认 5): " MINUTES
    MINUTES=${MINUTES:-5}

    # 访问方式
    read -p "访问方式 (1=Token, 2=SSH) [1]: " MODE
    MODE=${MODE:-1}

    if [ "$MODE" = "1" ]; then
        read -p "请输入 GitHub Token: " TOKEN

        # ===== Token 验证 =====
        echo "🔍 正在验证 Token 是否有效..."
        API_URL="https://api.github.com/repos/${URL#*github.com/}"
        API_URL="${API_URL/blob\//contents/}"
        API_URL="${API_URL%%\?*}"  # 去掉 ?ref=xxx
        STATUS=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: token $TOKEN" -H "Accept: application/vnd.github.v3.raw" "$API_URL")
        if [ "$STATUS" -ne 200 ]; then
            echo "❌ Token 无效或无权限访问仓库，HTTP 状态码: $STATUS"
            continue
        else
            echo "✅ Token 验证成功"
        fi
    fi

    SCRIPT="/usr/local/bin/zjsync-${NAME}.sh"

    # ===== 生成同步脚本 =====
    if [ "$MODE" = "1" ]; then
cat > "$SCRIPT" <<EOF
#!/bin/bash
curl -H "Authorization: token $TOKEN" -H "Accept: application/vnd.github.v3.raw" -fsSL "$URL" -o "${DEST}/${NAME}"
EOF
    else
cat > "$SCRIPT" <<EOF
#!/bin/bash
cd "$DEST"
if [ ! -d ".git" ]; then
    git clone git@github.com:${URL#*github.com/}.git .
fi
git fetch --all
git checkout main
git reset --hard origin/main
cp "$FILE" "$NAME"
EOF
    fi
    chmod +x "$SCRIPT"

    # ===== 添加 cron =====
    CRON="*/${MINUTES} * * * *"
    (crontab -l 2>/dev/null; echo "${CRON} ${SCRIPT} >> ${LOG_DIR}/zjsync-${NAME}.log 2>&1") | crontab -

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
    # 查看任务
    echo "===== 当前任务列表 ====="
    grep "^\[task" "$CONFIG_FILE" || echo "没有任务"
    read -p "按回车返回菜单..."
    ;;
3)
    # 删除任务
    echo "===== 删除任务 ====="
    grep "^\[task" "$CONFIG_FILE"
    read -p "请输入要删除的任务编号: " DEL
    sed -i "/\[task${DEL}\]/,+5d" "$CONFIG_FILE"
    echo "✅ 任务 $DEL 已删除"
    read -p "按回车返回菜单..."
    ;;
4)
    # 执行所有任务
    grep "NAME=" "$CONFIG_FILE" | while IFS='=' read -r _ taskname; do
        SCRIPT="/usr/local/bin/zjsync-${taskname}.sh"
        LOG_FILE="${LOG_DIR}/zjsync-${taskname}.log"
        if [ -f "$SCRIPT" ]; then
            echo "📌 执行 $SCRIPT"
            $SCRIPT >> "$LOG_FILE" 2>&1
            if [ -f "$LOG_FILE" ]; then
                echo "最近日志（最后 10 行）："
                tail -n 10 "$LOG_FILE"
            else
                echo "📄 日志文件不存在，可能是首次同步，已生成日志目录"
            fi
            echo
        fi
    done
    read -p "按回车返回菜单..."
    ;;
5)
    exit 0
    ;;
*)
    echo "❌ 请选择 1-5"
    ;;
esac
done
