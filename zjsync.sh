#!/bin/bash
set -e

CONF="/etc/zjsync.conf"
LOG_DIR="$HOME/zjsync_logs"
mkdir -p /etc "$LOG_DIR"

pause(){ read -n1 -r -p "按任意键返回主菜单..." key; echo; }
clear_screen(){ clear; }

declare -A TASKS
if [ -f "$CONF" ]; then
    while IFS='|' read -r task_name url dest name minutes mode token; do
        TASKS["$task_name"]="$url|$dest|$name|$minutes|$mode|$token"
    done < "$CONF"
fi

while true; do
clear_screen
echo "===== zjsync 批量管理 ====="
echo "1) 添加新同步任务"
echo "2) 查看已有任务"
echo "3) 删除任务"
echo "4) 执行所有任务一次同步"
echo "0) 退出"
read -p "请选择操作 [0-4]: " op
op=${op:-0}

case "$op" in
1)
    read -p "任务编号（唯一）: " task_id
    [[ -z "$task_id" ]] && echo "任务编号不能为空" && pause && continue
    read -p "GitHub 文件 URL (不可留空): " URL
    [[ -z "$URL" ]] && echo "URL不能为空" && pause && continue
    read -p "保存目录 (默认 /var/www/zj): " DEST
    DEST=${DEST:-/var/www/zj}
    read -p "保存文件名 (默认 根据 URL 文件名加 .txt): " NAME
    NAME=${NAME:-$(basename "$URL").txt}
    read -p "同步间隔(分钟, 默认 5): " MINUTES
    MINUTES=${MINUTES:-5}
    read -p "访问方式 (1=Token, 2=SSH) [1]: " MODE
    MODE=${MODE:-1}
    TOKEN=""
    [[ "$MODE" == "1" ]] && read -p "请输入 GitHub Token: " TOKEN

    mkdir -p "$DEST"
    [[ ! -w "$DEST" ]] && echo "❌ 目录不可写: $DEST" && pause && continue

    SCRIPT="/usr/local/bin/zjsync-${NAME}.sh"

    if [[ "$URL" =~ github\.com/([^/]+)/([^/]+)/blob/([^/]+)/(.+) ]]; then
        REPO="${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
        BRANCH="${BASH_REMATCH[3]}"
        FILE="${BASH_REMATCH[4]}"
        API_URL="https://api.github.com/repos/${REPO}/contents/${FILE}?ref=${BRANCH}"
    else
        echo "❌ URL 格式错误"
        pause
        continue
    fi

    if [[ "$MODE" == "1" ]]; then
        cat > "$SCRIPT" <<EOF
#!/bin/bash
set -x
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
echo "开始同步任务: \$(date)"
/usr/bin/curl -H "Authorization: token $TOKEN" -H "Accept: application/vnd.github.v3.raw" -fsSL "$API_URL" -o "${DEST}/${NAME}"
if [ \$? -ne 0 ] || [ ! -f "${DEST}/${NAME}" ]; then
    echo "❌ 文件生成失败: ${DEST}/${NAME}"
else
    echo "✅ 文件已生成: ${DEST}/${NAME}"
fi
EOF
    else
        cat > "$SCRIPT" <<EOF
#!/bin/bash
set -x
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
cd "$DEST"
if [ ! -d ".git" ]; then
    git clone git@github.com:${REPO}.git .
fi
git fetch --all
git checkout $BRANCH
git reset --hard origin/$BRANCH
cp "$FILE" "$NAME"
[ -f "$NAME" ] && echo "✅ 文件已生成: ${DEST}/${NAME}" || echo "❌ 文件生成失败: ${DEST}/${NAME}"
EOF
    fi
    chmod +x "$SCRIPT"

    CRON="*/${MINUTES} * * * * /bin/bash $SCRIPT >> $LOG_DIR/zjsync-${NAME}.log 2>&1"
    (crontab -l 2>/dev/null; echo "$CRON") | crontab -

    echo "$task_id|$URL|$DEST|$NAME|$MINUTES|$MODE|$TOKEN" >> "$CONF"
    echo "✅ 任务 $task_id 添加完成, 脚本: $SCRIPT"
    # 立即执行一次
    /bin/bash "$SCRIPT"
    pause
    ;;
2)
    clear_screen
    if [ ${#TASKS[@]} -eq 0 ]; then echo "暂无任务"; else
        for task_id in "${!TASKS[@]}"; do
            IFS='|' read -r url dest name minutes mode token <<< "${TASKS[$task_id]}"
            echo "$task_id) $name   URL: $url   目录: $dest   间隔: ${minutes}min"
        done
    fi
    pause
    ;;
3)
    read -p "输入要删除的任务编号: " del_id
    [[ -z "${TASKS[$del_id]}" ]] && echo "任务不存在" && pause && continue
    IFS='|' read -r url dest name minutes mode token <<< "${TASKS[$del_id]}"
    rm -f "/usr/local/bin/zjsync-$name.sh"
    sed -i "/^$del_id|/d" "$CONF"
    crontab -l | grep -v "zjsync-$name.sh" | crontab -
    unset TASKS["$del_id"]
    echo "✅ 任务 $del_id 已删除"
    pause
    ;;
4)
    [[ ${#TASKS[@]} -eq 0 ]] && echo "暂无任务可执行" && pause && continue
    for task_id in "${!TASKS[@]}"; do
        IFS='|' read -r url dest name minutes mode token <<< "${TASKS[$task_id]}"
        SCRIPT="/usr/local/bin/zjsync-$name.sh"
        if [ -f "$SCRIPT" ]; then
            echo "📌 执行 $SCRIPT"
            /bin/bash "$SCRIPT" >> "$LOG_DIR/zjsync-$name.log" 2>&1
        fi
    done
    pause
    ;;
0)
    echo "退出"
    exit 0
    ;;
*)
    echo "无效选择"
    pause
    ;;
esac
done
