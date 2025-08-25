#!/bin/bash
set -e
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

CONF="/etc/zjsync.conf"
LOG_DIR="$HOME/zjsync_logs"
mkdir -p /etc "$LOG_DIR"

declare -a TASKS

# ====== 加载任务 ======
load_tasks() {
    TASKS=()
    [ -f "$CONF" ] || return
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        TASKS+=("$line")
    done < "$CONF"
}

save_tasks() {
    printf "%s\n" "${TASKS[@]}" > "$CONF"
}

# ====== 显示任务 ======
show_tasks() {
    echo "===== 当前任务列表 ====="
    if [ ${#TASKS[@]} -eq 0 ]; then
        echo "暂无任务"
    else
        local i=1
        for task in "${TASKS[@]}"; do
            IFS='|' read -r NUM URL DEST NAME MINUTES MODE TOKEN <<< "$task"
            printf "%d) %-12s  URL: %s\n" "$i" "$NAME" "$URL"
            ((i++))
        done
    fi
}

# ====== 添加任务 ======
add_task() {
    load_tasks
    read -p "请输入任务编号: " NUM
    read -p "请输入 GitHub 文件 URL (不可留空): " URL
    [ -z "$URL" ] && { echo "URL不能为空"; return; }
    read -p "保存目录 (默认 /var/www/zj): " DEST
    DEST=${DEST:-/var/www/zj}
    read -p "保存文件名 (默认根据 URL 文件名加 .txt): " NAME
    [[ -z "$NAME" ]] && NAME="$(basename "$URL").txt"
    read -p "同步间隔(分钟, 默认 5): " MINUTES
    MINUTES=${MINUTES:-5}
    read -p "访问方式 (1=Token, 2=SSH) [1]: " MODE
    MODE=${MODE:-1}
    TOKEN=""
    if [ "$MODE" = "1" ]; then
        read -p "请输入 GitHub Token: " TOKEN
        # 测试 token 是否有效
        STATUS=$(curl -H "Authorization: token $TOKEN" -H "Accept: application/vnd.github.v3.raw" -o /dev/null -s -w "%{http_code}" "$URL")
        if [[ "$STATUS" != "200" ]]; then
            echo "❌ Token 无效或无权限访问仓库，HTTP 状态码: $STATUS"
            return
        fi
        echo "✅ Token 验证成功"
    fi

    # 防止重复 URL
    for task in "${TASKS[@]}"; do
        IFS='|' read -r _tasknum taskurl _ <<< "$task"
        [ "$taskurl" = "$URL" ] && { echo "⚠️ 该 URL 已存在任务中"; return; }
    done

    mkdir -p "$DEST"
    SCRIPT="/usr/local/bin/zjsync-${NAME}.sh"

    if [ "$MODE" = "1" ]; then
        cat > "$SCRIPT" <<EOF
#!/bin/bash
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
DEST="$DEST"
NAME="$NAME"
TOKEN="$TOKEN"
URL="$URL"
mkdir -p "\$DEST"
curl -H "Authorization: token \$TOKEN" -fsSL "\$URL" -o "\$DEST/\$NAME"
echo "✅ 文件已生成: \$DEST/\$NAME"
head -n 10 "\$DEST/\$NAME"
EOF
    else
        cat > "$SCRIPT" <<EOF
#!/bin/bash
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
DEST="$DEST"
NAME="$NAME"
URL="$URL"
mkdir -p "\$DEST"
cd "\$DEST"
if [ ! -d ".git" ]; then
    git clone "\$URL" .
else
    git fetch --all
    git reset --hard origin/main
fi
cp "$(basename "\$URL")" "\$NAME"
echo "✅ 文件已生成: \$DEST/\$NAME"
head -n 10 "\$DEST/\$NAME"
EOF
    fi

    chmod +x "$SCRIPT"
    (crontab -l 2>/dev/null; echo "*/$MINUTES * * * * $SCRIPT >> $LOG_DIR/zjsync-$NAME.log 2>&1") | crontab -

    TASKS+=("$NUM|$URL|$DEST|$NAME|$MINUTES|$MODE|$TOKEN")
    save_tasks
    echo "✅ 任务 $NUM 添加完成, 脚本: $SCRIPT"
}

# ====== 删除任务 ======
delete_task() {
    load_tasks
    show_tasks
    [ ${#TASKS[@]} -eq 0 ] && return
    read -p "请输入要删除的任务序号: " DEL_NUM
    if [[ "$DEL_NUM" -ge 1 && "$DEL_NUM" -le ${#TASKS[@]} ]]; then
        IFS='|' read -r NUM URL DEST NAME MINUTES MODE TOKEN <<< "${TASKS[DEL_NUM-1]}"
        SCRIPT="/usr/local/bin/zjsync-${NAME}.sh"
        crontab -l 2>/dev/null | grep -vF "$SCRIPT" | crontab -
        unset 'TASKS[DEL_NUM-1]'
        TASKS=("${TASKS[@]}")
        save_tasks
        echo "✅ 任务已删除"
    else
        echo "❌ 无效序号"
    fi
}

# ====== 执行所有任务一次 ======
run_all_tasks() {
    load_tasks
    [ ${#TASKS[@]} -eq 0 ] && { echo "暂无任务可执行"; return; }
    for task in "${TASKS[@]}"; do
        IFS='|' read -r NUM URL DEST NAME MINUTES MODE TOKEN <<< "$task"
        SCRIPT="/usr/local/bin/zjsync-${NAME}.sh"
        [ -x "$SCRIPT" ] && echo "📌 执行 $SCRIPT" && bash "$SCRIPT"
    done
}

# ====== 主菜单 ======
while true; do
    echo
    echo "===== zjsync 批量管理 ====="
    echo "1) 添加新同步任务"
    echo "2) 查看已有任务"
    echo "3) 删除任务"
    echo "4) 执行所有任务一次同步"
    echo "0) 退出"
    read -p "请选择操作 [0-4]: " OP
    case "$OP" in
        1) add_task ;;
        2) show_tasks ; read -n1 -rsp "按任意键返回主菜单..." ;;
        3) delete_task ;;
        4) run_all_tasks ; read -n1 -rsp "按任意键返回主菜单..." ;;
        0) exit 0 ;;
        *) echo "无效选项" ;;
    esac
done
