#!/bin/bash
set -e

CONF="/etc/zjsync.conf"
mkdir -p /etc

# 读取已有配置
declare -A CONFIG
if [ -f "$CONF" ]; then
    while IFS='=' read -r key value; do
        CONFIG[$key]="$value"
    done < "$CONF"
fi

# ====== 用户交互 ======
read -p "请输入 GitHub 文件 URL (例如 https://github.com/featherhao/zijian/blob/main/zj): " URL
read -p "保存目录 (默认 /var/www/zj): " DEST
DEST=${DEST:-/var/www/zj}

# 自动解析 URL
if [[ "$URL" =~ github\.com/([^/]+)/([^/]+)/blob/([^/]+)/(.+) ]]; then
    REPO="${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
    BRANCH="${BASH_REMATCH[3]}"
    FILE="${BASH_REMATCH[4]}"
else
    echo "❌ URL 格式错误"
    exit 1
fi

read -p "保存文件名 (默认 ${FILE}.txt): " NAME
NAME=${NAME:-${FILE}.txt}

read -p "同步间隔 (分钟, 默认 5): " MINUTES
MINUTES=${MINUTES:-5}

read -p "访问方式 (1=Token, 2=SSH) [1]: " MODE
MODE=${MODE:-1}

if [ "$MODE" = "1" ]; then
    read -p "请输入 GitHub Token: " TOKEN
fi

mkdir -p "$DEST"
SCRIPT="/usr/local/bin/zjsync-${NAME}.sh"

# ====== 生成同步脚本 ======
if [ "$MODE" = "1" ]; then
cat > "$SCRIPT" <<EOF
#!/bin/bash
curl -H "Authorization: token $TOKEN" -fsSL "https://raw.githubusercontent.com/${REPO}/${BRANCH}/${FILE}" -o "${DEST}/${NAME}"
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

# ====== 添加 cron ======
CRON="*/${MINUTES} * * * *"
(crontab -l 2>/dev/null; echo "${CRON} ${SCRIPT} >> /var/log/zjsync-${NAME}.log 2>&1") | crontab -

# ====== 保存配置 ======
echo "URL=$URL" >> "$CONF"
echo "DEST=$DEST" >> "$CONF"
echo "NAME=$NAME" >> "$CONF"
echo "MINUTES=$MINUTES" >> "$CONF"
echo "MODE=$MODE" >> "$CONF"

echo "✅ 同步脚本已创建：$SCRIPT"
echo "⏰ 已添加定时任务: 每 ${MINUTES} 分钟同步一次"
$SCRIPT
