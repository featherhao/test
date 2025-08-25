#!/bin/bash
set -e

CONF="/etc/zjsync.conf"
LOG_DIR="$HOME/zjsync_logs"
mkdir -p /etc "$LOG_DIR"

# ====== 读取已有任务 ======
declare -a TASKS
if [ -f "$CONF" ]; then
    mapfile -t TASKS < "$CONF"
fi

save_tasks() {
    printf "%s\n" "${TASKS[@]}" > "$CONF"
}

# ====== 函数：显示任务列表 ======
show_tasks() {
    echo "===== 当前任务列表 ====="
    if [ ${#TASKS[@]} -eq 0 ]; then
        echo "暂无任务"
    else
        i=1
        for task in "${TASKS[@]}"; do
            IFS='|' read -r NUM URL DEST NAME MINUTES MODE TOKEN <<< "$task"
            echo "$i) $NAME   URL: $URL"
            ((i++))
        done
    fi
}

# ====== 函数：解析 GitHub URL ======
parse_github_url() {
    local URL="$1"
    if [[ "$URL" =~ github\.com/([^/]+)/([^/]+)/blob/([^/]+)/(.+) ]]; then
        OWNER="${BASH_REMATCH[1]}"
        REPO="${BASH_REMATCH[2]}"
        BRANCH="${BASH_REMATCH[3]}"
        FILEPATH="${BASH_REMATCH[4]}"
    else
        echo "❌ URL 格式错误"
        return 1
    fi
}

# ====== 函数：添加任务 ======
add_task() {
    read -p "添加任务编号: " NUM
    [ -z "$NUM" ] && NUM=$(( ${#TASKS[@]} + 1 ))
    read -p "GitHub 文件 URL (不可留空): " URL
    [ -z "$URL" ] && echo "URL 不能为空" && return
    parse_github_url "$URL" || return

    read -p "保存目录 (默认 /var/www/zj): " DEST
    DEST=${DEST:-/var/www/zj}

    FILENAME_DEFAULT=$(basename "$FILEPATH").txt
    read -p "保存文件名 (默认 $FILENAME_DEFAULT): " NAME
    NAME=${NAME:-$FILENAME_DEFAULT}

    read -p "同步间隔(分钟, 默认 5): " MINUTES
    MINUTES=${MINUTES:-5}

    read -p "访问方式 (1=Token, 2=SSH) [1]: " MODE
    MODE=${MODE:-1}

    TOKEN=""
    if [ "$MODE" = "1" ]; then
        read -p "请输入 GitHub Token: " TOKEN
        # 验证 Token 是否有效
        API_URL="https://api.github.com/repos/$OWNER/$REPO/contents/$FILEPATH?ref=$BRANCH"
        HTTP_CODE=$(curl -o /dev/null -s -w "%{http_code}" -H "Authorization: token $TOKEN" \
            -H "Accept: application/vnd.github.v3.raw" \
            "$API_URL")
        if [ "$HTTP_CODE" -ne 200 ]; then
            echo "❌ Token 无效或无权限访问仓库，HTTP 状态码: $HTTP_CODE"
            return
        fi
        echo "✅ Token 验证成功"
    fi

    mkdir -p "$DEST"
    SCRIPT="/usr/local/bin/zjsync-${NAME}.sh"

    # 生成同步脚本
    if [ "$MODE" = "1" ]; then
        cat > "$SCRIPT" <<EOF
#!/bin/bash
mkdir -p "$DEST"
curl -H "Authorization: token $TOKEN" \
     -H "Accept: application/vnd.github.v3.raw" \
     -fsSL "https://api.github.com/repos/$OWNER/$REPO/contents/$FILEPATH?ref=$BRANCH" \
     -o "$DEST/$NAME"
EOF
    else
        cat > "$SCRIPT" <<EOF
#!/bin/bash
cd "$DEST"
if [ ! -d ".git" ]; then
    git clone git@github.com:$OWNER/$REPO.git .
fi
git fetch --all
git checkout $BRANCH
git reset --hard origin/$BRANCH
cp "$FILEPATH" "$NAME"
EOF
    fi
    chmod +x "$SCRIPT"

    # 添加定时任务
    CRON="*/${MINUTES} * * * * $SCRIPT >> $LOG_DIR/zjsync-${NAME}.log 2>&1"
    (crontab -l 2>/dev/null; echo "$CRON") | crontab -

    # 保存任务
    TASKS+=("$NUM|$URL|$DEST|$NAME|$MINUTES|$MODE|$TOKEN")
    save_tasks
    echo "✅ 任务 $NUM 添加完成, 脚本: $SCRIPT"
}

# ====== 函数：删除任务 ======
delete_task() {
    show_tasks
    read -p "请输入要删除的任务序号: " DEL_NUM
    if [[ "$DEL_NUM" -ge 1 && "$DEL_NUM" -le ${#TASKS[@]} ]]; then
        unset 'TASKS[DEL_NUM-1]'
        TASKS=("${TASKS[@]}")
        save_tasks
        echo "✅ 任务已删除"
    else
        echo "❌ 无效序号"
    fi
}

# ====== 函数：执行所有任务 ======
run_all_tasks() {
    if [ ${#TASKS[@]} -eq 0 ]; then
        echo "暂无任务可执行"
        return
    fi
    for task in "${TASKS[@]}"; do
        IFS='|' read -r NUM URL DEST NAME MINUTES MODE TOKEN <<< "$task"
        SCRIPT="/usr/local/bin/zjsync-${NAME}.sh"
        if [ ! -f "$SCRIPT" ]; then
            echo "⚠️ 脚本不存在: $SCRIPT"
            continue
        fi
        echo "📌 执行 $SCRIPT"
        bash "$SCRIPT" >> "$LOG_DIR/zjsync-${NAME}.log" 2>&1
        if [ -f "$DEST/$NAME" ]; then
            echo "✅ 文件已生成: $DEST/$NAME"
        else
            echo "❌ 文件未生成: $DEST/$NAME"
        fi
    done
}

# ====== 主菜单 ======
while true; do
    echo "===== zjsync 批量管理 ====="
    echo "1) 添加新同步任务"
    echo "2) 查看已有任务"
    echo "3) 删除任务"
    echo "4) 执行所有任务一次同步"
    echo "0) 退出"
    read -p "请选择操作 [0-4]: " CHOICE
    case "$CHOICE" in
        1) add_task ;;
        2) show_tasks; read -n1 -r -p "按任意键返回主菜单..." ;;
        3) delete_task ;;
        4) run_all_tasks; read -n1 -r -p "按任意键返回主菜单..." ;;
        0) exit 0 ;;
        *) echo "❌ 无效选择" ;;
    esac
done
