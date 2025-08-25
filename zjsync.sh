#!/bin/bash
set -e

CONF="/etc/zjsync.conf"
LOG_DIR="$HOME/zjsync_logs"
mkdir -p "$LOG_DIR" /etc

# =========================
# 读取配置
# =========================
declare -A TASKS
if [ -f "$CONF" ]; then
    while IFS='|' read -r idx url dest name minutes mode token; do
        TASKS["$idx"]="$url|$dest|$name|$minutes|$mode|$token"
    done < "$CONF"
fi

# =========================
# 工具函数
# =========================
pause(){ read -n1 -r -p "按任意键返回主菜单..."; echo; }
validate_token(){
    local url="$1"
    local token="$2"
    status=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: token $token" \
        -H "Accept: application/vnd.github.v3.raw" \
        "$url")
    if [[ "$status" == "200" ]]; then return 0; else return 1; fi
}
generate_script(){
    local idx="$1"
    local url="$2"
    local dest="$3"
    local name="$4"
    local mode="$5"
    local token="$6"

    mkdir -p "$dest"
    local script="/usr/local/bin/zjsync-${name}.sh"
    if [ "$mode" = "1" ]; then
cat > "$script" <<EOF
#!/bin/bash
curl -H "Authorization: token $token" -H "Accept: application/vnd.github.v3.raw" -fsSL "$url" -o "$dest/$name"
EOF
    else
cat > "$script" <<EOF
#!/bin/bash
cd "$dest"
if [ ! -d ".git" ]; then
    git clone "$url" .
else
    git fetch --all
    git checkout main
    git reset --hard origin/main
fi
EOF
    fi
    chmod +x "$script"
    echo "$script"
}
add_cron(){
    local script="$1"
    local minutes="$2"
    (crontab -l 2>/dev/null; echo "*/$minutes * * * * $script >> $LOG_DIR/$(basename $script).log 2>&1") | crontab -
}

# =========================
# 主菜单
# =========================
while true; do
clear
echo "===== zjsync 批量管理 ====="
echo "1) 添加新同步任务"
echo "2) 查看已有任务"
echo "3) 删除任务"
echo "4) 执行所有任务一次同步"
echo "0) 退出"
read -p "请选择操作 [0-4]: " choice

case "$choice" in
0) exit 0;;

1)
    read -p "添加任务编号: " idx
    if [[ -n "${TASKS[$idx]}" ]]; then
        echo "❌ 任务编号已存在"; pause; continue
    fi
    read -p "GitHub 文件 URL (不可留空): " url
    [[ -z "$url" ]] && echo "❌ URL 不能为空" && pause && continue
    read -p "保存目录 (默认 /var/www/zj): " dest
    dest=${dest:-/var/www/zj}
    fname=$(basename "$url")
    read -p "保存文件名 (默认 $fname.txt): " name
    name=${name:-$fname.txt}
    read -p "同步间隔(分钟, 默认 5): " minutes
    minutes=${minutes:-5}
    read -p "访问方式 (1=Token, 2=SSH) [1]: " mode
    mode=${mode:-1}
    token=""
    if [[ "$mode" == "1" ]]; then
        read -p "请输入 GitHub Token: " token
        api_url=$(echo "$url" | sed -E 's|https://github.com/([^/]+)/([^/]+)/blob/([^/]+)/(.+)|https://api.github.com/repos/\1/\2/contents/\4?ref=\3|')
        echo "🔍 正在验证 Token 是否有效..."
        if ! validate_token "$api_url" "$token"; then
            echo "❌ Token 无效或无权限访问仓库，HTTP 状态码 != 200"; pause; continue
        fi
        echo "✅ Token 验证成功"
        url="$api_url"
    fi
    script=$(generate_script "$idx" "$url" "$dest" "$name" "$mode" "$token")
    add_cron "$script" "$minutes"
    TASKS["$idx"]="$url|$dest|$name|$minutes|$mode|$token"
    # 保存配置
    > "$CONF"
    for k in "${!TASKS[@]}"; do echo "$k|${TASKS[$k]}" >> "$CONF"; done
    # 立即执行一次
    echo "⏳ 正在执行任务一次同步..."
    bash "$script"
    echo "✅ 文件已生成: $dest/$name"
    head -n 10 "$dest/$name"
    pause
    ;;

2)
    if [ ${#TASKS[@]} -eq 0 ]; then echo "暂无任务"; pause; continue; fi
    echo "===== 当前任务列表 ====="
    for k in "${!TASKS[@]}"; do
        IFS='|' read -r url dest name minutes mode token <<< "${TASKS[$k]}"
        echo "$k) $name   URL: $url"
    done
    pause
    ;;

3)
    if [ ${#TASKS[@]} -eq 0 ]; then echo "暂无任务"; pause; continue; fi
    echo "===== 当前任务列表 ====="
    for k in "${!TASKS[@]}"; do
        IFS='|' read -r url dest name minutes mode token <<< "${TASKS[$k]}"
        echo "$k) $name   URL: $url"
    done
    read -p "请输入要删除的任务序号: " delidx
    if [[ -z "${TASKS[$delidx]}" ]]; then echo "❌ 无此任务"; pause; continue; fi
    IFS='|' read -r url dest name minutes mode token <<< "${TASKS[$delidx]}"
    # 移除 crontab
    crontab -l 2>/dev/null | grep -v "/usr/local/bin/zjsync-$name.sh" | crontab -
    # 删除脚本
    rm -f "/usr/local/bin/zjsync-$name.sh"
    unset TASKS["$delidx"]
    # 保存配置
    > "$CONF"
    for k in "${!TASKS[@]}"; do echo "$k|${TASKS[$k]}" >> "$CONF"; done
    echo "✅ 任务 $delidx 已删除"
    pause
    ;;

4)
    if [ ${#TASKS[@]} -eq 0 ]; then echo "暂无任务可执行"; pause; continue; fi
    for k in "${!TASKS[@]}"; do
        IFS='|' read -r url dest name minutes mode token <<< "${TASKS[$k]}"
        script="/usr/local/bin/zjsync-$name.sh"
        if [ ! -f "$script" ]; then
            script=$(generate_script "$k" "$url" "$dest" "$name" "$mode" "$token")
        fi
        echo "📌 执行 $script"
        bash "$script"
        echo "✅ 文件已生成: $dest/$name"
        head -n 10 "$dest/$name"
    done
    pause
    ;;

*)
    echo "❌ 无效选项"; pause
    ;;
esac
done
