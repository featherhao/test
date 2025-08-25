#!/bin/bash
set -e

CONFIG_FILE="/etc/zjsync_tasks.conf"
LOG_DIR="$HOME/zjsync_logs"
mkdir -p /etc /usr/local/bin "$LOG_DIR"

declare -A TASKS

# ===== 读取已有任务 =====
if [ -f "$CONFIG_FILE" ]; then
    current_task=""
    while IFS= read -r line; do
        line="${line%%#*}"
        line="${line%%$'\r'}"
        if [[ "$line" =~ \[task([0-9]+)\] ]]; then
            current_task="${BASH_REMATCH[1]}"
        elif [[ "$line" =~ ^([^=]+)=(.*)$ ]] && [ -n "$current_task" ]; then
            key="${BASH_REMATCH[1]}"
            value="${BASH_REMATCH[2]}"
            TASKS["$current_task-$key"]="$value"
        fi
    done < "$CONFIG_FILE"
fi

while true; do
echo
echo "===== zjsync 批量管理 ====="
echo "1) 添加新同步任务"
echo "2) 查看已有任务"
echo "3) 删除任务"
echo "4) 执行所有任务一次同步"
echo "0) 退出"
read -p "请选择操作 [0-4]: " CHOICE

case "$CHOICE" in
1)
    # 添加新任务
    TASK_NUM=1
    while [[ -n "${TASKS[$TASK_NUM-URL]}" ]]; do ((TASK_NUM++)); done
    echo "添加任务编号: $TASK_NUM"

    while true; do
        read -p "请输入 GitHub 文件 URL: " URL
        [ -n "$URL" ] && break
        echo "❌ URL 不能为空"
    done

    read -p "保存目录 (默认 /var/www/zj): " DEST
    DEST=${DEST:-/var/www/zj}
    mkdir -p "$DEST"

    FILE=$(basename "$URL")
    read -p "保存文件名 (默认 ${FILE}.txt): " NAME
    NAME=${NAME:-${FILE}.txt}

    read -p "同步间隔(分钟, 默认 5): " MINUTES
    MINUTES=${MINUTES:-5}

    read -p "访问方式 (1=Token, 2=SSH) [1]: " MODE
    MODE=${MODE:-1}

    if [ "$MODE" = "1" ]; then
        read -p "请输入 GitHub Token: " TOKEN
        # Token 验证
        if [[ "$URL" =~ github\.com/([^/]+)/([^/]+)/blob/([^/]+)/(.+) ]]; then
            USER="${BASH_REMATCH[1]}"
            REPO="${BASH_REMATCH[2]}"
            BRANCH="${BASH_REMATCH[3]}"
            FILE_PATH="${BASH_REMATCH[4]}"
        else
            echo "❌ URL 格式错误"
            continue
        fi
        API_URL="https://api.github.com/repos/$USER/$REPO/contents/$FILE_PATH?ref=$BRANCH"
        STATUS=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: token $TOKEN" -H "Accept: application/vnd.github.v3.raw" "$API_URL")
        if [ "$STATUS" -ne 200 ]; then
            echo "❌ Token 无效或无权限访问仓库，HTTP 状态码: $STATUS"
            continue
        else
            echo "✅ Token 验证成功"
        fi
    fi

    SCRIPT="/usr/local/bin/zjsync-${NAME}.sh"
    if [ "$MODE" = "1" ]; then
cat > "$SCRIPT" <<EOF
#!/bin/bash
curl -H "Authorization: token $TOKEN" -H "Accept: application/vnd.github.v3.raw" -fsSL "$API_URL" -o "${DEST}/${NAME}"
EOF
    else
cat > "$SCRIPT" <<EOF
#!/bin/bash
cd "$DEST"
if [ ! -d ".git" ]; then git clone git@github.com:$USER/$REPO.git .; fi
git fetch --all
git checkout $BRANCH
git reset --hard origin/$BRANCH
cp "$FILE_PATH" "$NAME"
EOF
    fi
    chmod +x "$SCRIPT"

    # 添加 cron
    CRON="*/${MINUTES} * * * *"
    (crontab -l 2>/dev/null | grep -v "$SCRIPT"; echo "${CRON} ${SCRIPT} >> ${LOG_DIR}/zjsync-${NAME}.log 2>&1") | crontab -

    # 保存配置
    {
        echo "[task$TASK_NUM]"
        echo "NAME=$NAME"
        echo "URL=$URL"
        echo "DEST=$DEST"
        echo "MINUTES=$MINUTES"
        echo "MODE=$MODE"
        [ "$MODE" = "1" ] && echo "TOKEN=$TOKEN"
    } >> "$CONFIG_FILE"

    # 更新内存 TASKS
    TASKS["$TASK_NUM-NAME"]="$NAME"
    TASKS["$TASK_NUM-URL"]="$URL"
    TASKS["$TASK_NUM-DEST"]="$DEST"
    TASKS["$TASK_NUM-MINUTES"]="$MINUTES"
    TASKS["$TASK_NUM-MODE"]="$MODE"
    [ "$MODE" = "1" ] && TASKS["$TASK_NUM-TOKEN"]="$TOKEN"

    echo "✅ 任务 $TASK_NUM 添加完成, 脚本: $SCRIPT"
    read -n1 -rsp "按任意键返回主菜单..."
    ;;
2)
    echo "===== 当前任务列表 ====="
    if [ ${#TASKS[@]} -eq 0 ]; then echo "暂无任务"; fi
    for t in $(printf "%s\n" "${!TASKS[@]}" | cut -d'-' -f1 | sort -u); do
        name="${TASKS[$t-NAME]}"
        url="${TASKS[$t-URL]}"
        echo "$t) $name   URL: $url"
    done
    read -n1 -rsp "按任意键返回主菜单..."
    ;;
3)
    echo "===== 删除任务 ====="
    if [ ${#TASKS[@]} -eq 0 ]; then echo "暂无任务可删除"; read -n1 -rsp "按任意键返回主菜单..."; continue; fi
    for t in $(printf "%s\n" "${!TASKS[@]}" | cut -d'-' -f1 | sort -u); do
        name="${TASKS[$t-NAME]}"
        url="${TASKS[$t-URL]}"
        echo "$t) $name   URL: $url"
    done
    read -p "请输入要删除的任务编号: " DEL
    SCRIPT="/usr/local/bin/zjsync-${TASKS[$DEL-NAME]}.sh"
    crontab -l | grep -v "$SCRIPT" | crontab -
    [ -f "$SCRIPT" ] && rm -f "$SCRIPT"
    sed -i "/\[task${DEL}\]/,+6d" "$CONFIG_FILE"
    unset TASKS[$DEL-NAME] TASKS[$DEL-URL] TASKS[$DEL-DEST] TASKS[$DEL-MINUTES] TASKS[$DEL-MODE] TASKS[$DEL-TOKEN]
    echo "✅ 任务 $DEL 已删除"
    read -n1 -rsp "按任意键返回主菜单..."
    ;;
4)
    if [ ${#TASKS[@]} -eq 0 ]; then echo "暂无任务可执行"; read -n1 -rsp "按任意键返回主菜单..."; continue; fi
    for t in $(printf "%s\n" "${!TASKS[@]}" | cut -d'-' -f1 | sort -u); do
        name="${TASKS[$t-NAME]}"
        SCRIPT="/usr/local/bin/zjsync-${name}.sh"
        LOG_FILE="${LOG_DIR}/zjsync-${name}.log"
        echo "📌 执行 $SCRIPT"
        if [ -f "$SCRIPT" ]; then
            if $SCRIPT >> "$LOG_FILE" 2>&1; then echo "✅ 执行成功"; else echo "❌ 执行失败，请检查日志: $LOG_FILE"; fi
            [ -s "$LOG_FILE" ] && echo "最近日志（最后 10 行）：" && tail -n 10 "$LOG_FILE"
        else
            echo "❌ 脚本 $SCRIPT 不存在"
        fi
        echo
    done
    read -n1 -rsp "按任意键返回主菜单..."
    ;;
0)
    exit 0
    ;;
*)
    echo "❌ 请选择 0-4"
    ;;
esac
done
