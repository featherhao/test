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
        STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
            -H "Authorization: token $TOKEN" \
            -H "Accept: application/vnd.github.v3.raw" \
            "$API_URL")
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
curl -H "Authorization: token $TOKEN" -H "Accept: application/vnd.github.v3.raw" -fsSL "$API_URL" -o "${DEST}/${NAME}"
EOF
    else
cat > "$SCRIPT" <<EOF
#!/bin/bash
cd "$DEST"
if [ ! -d ".git" ]; then
    git clone git@github.com:$USER/$REPO.git .
fi
git fetch --all
git checkout $BRANCH
git reset --hard origin/$BRANCH
cp "$FILE_PATH" "$NAME"
EOF
    fi
    chmod +x "$SCRIPT"

    # ===== 添加 cron =====
    CRON="*/${MINUTES} * * * *"
    (crontab -l 2>/dev/null; echo "${CRON} ${SCRIPT} >> ${LOG_DIR}/zjsync-${NAME}.log 2>&1") | crontab -

    # ===== 保存到配置文件 =====
    {
        echo "[task$TASK_NUM]"
        echo "NAME=$NAME"
        echo "URL=$URL"
        echo "DEST=$DEST"
        echo "MINUTES=$MINUTES"
        echo "MODE=$MODE"
        [ "$MODE" = "1" ] && echo "TOKEN=$TOKEN"
    } >> "$CONFIG_FILE"

    echo "✅ 任务 $TASK_NUM 添加完成, 脚本: $SCRIPT"
    read -n1 -rsp "按任意键返回主菜单..."
    ;;
2)
    # 查看任务
    echo "===== 当前任务列表 ====="
    grep "^\[task" "$CONFIG_FILE" | while read -r line; do
        num=${line#*[task}
        num=${num%]*}
        name=$(grep -A5 "\[task${num}\]" "$CONFIG_FILE" | grep "^NAME=" | awk -F= '{print $2}')
        url=$(grep -A5 "\[task${num}\]" "$CONFIG_FILE" | grep "^URL=" | awk -F= '{print $2}')
        echo "$num) $name   URL: $url"
    done
    read -n1 -rsp "按任意键返回主菜单..."
    ;;
3)
    # 删除任务
    echo "===== 删除任务 ====="
    grep "^\[task" "$CONFIG_FILE" | while read -r line; do
        num=${line#*[task}
        num=${num%]*}
        name=$(grep -A5 "\[task${num}\]" "$CONFIG_FILE" | grep "^NAME=" | awk -F= '{print $2}')
        echo "$num) $name"
    done
    read -p "请输入要删除的任务编号: " DEL
    sed -i "/\[task${DEL}\]/,+6d" "$CONFIG_FILE"
    echo "✅ 任务 $DEL 已删除"
    read -n1 -rsp "按任意键返回主菜单..."
    ;;
4)
    # 执行所有任务
    grep "^\[task" "$CONFIG_FILE" | while read -r line; do
        num=${line#*[task}
        num=${num%]*}
        name=$(grep -A5 "\[task${num}\]" "$CONFIG_FILE" | grep "^NAME=" | awk -F= '{print $2}')
        SCRIPT="/usr/local/bin/zjsync-${name}.sh"
        LOG_FILE="${LOG_DIR}/zjsync-${name}.log"
        if [ -f "$SCRIPT" ]; then
            echo "📌 执行 $SCRIPT"
            if $SCRIPT >> "$LOG_FILE" 2>&1; then
                echo "✅ 执行成功"
            else
                echo "❌ 执行失败，请检查日志: $LOG_FILE"
            fi
            if [ -f "$LOG_FILE" ]; then
                echo "最近日志（最后 10 行）："
                tail -n 10 "$LOG_FILE"
            fi
            echo
        fi
    done
    read -n1 -rsp "按任意键返回主菜单..."
    ;;
5)
    exit 0
    ;;
*)
    echo "❌ 请选择 1-5"
    ;;
esac
done
