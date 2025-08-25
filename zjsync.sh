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
while true; do
    read -p "请输入 GitHub 文件 URL (不可留空): " URL
    if [ -n "$URL" ]; then
        break
    fi
    echo "❌ URL 不能为空，请重新输入"
done

read -p "保存目录 (默认 /var/www/zj): " DEST
DEST=${DEST:-/var/www/zj}

# ====== 自动解析 URL ======
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
    echo "❌ URL 格式错误，请确保是 GitHub 网页 URL 或 raw URL"
    exit 1
fi

read -p "保存文件名 (默认 ${FILE}.txt): " NAME
NAME=${NAME:-${FILE}.txt}

read -p "同步间隔 (分钟, 默认 5): " MINUTES
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

# ====== 生成同步脚本 ======
if [ "$MODE" = "1" ]; then
cat > "$SCRIPT" <<EOF
#!/bin/bash
curl -H "Authorization: token $TOKEN" -fsSL "$RAW_URL" -o "${DEST}/${NAME}"
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

# ====== 立即执行一次同步 ======
$SCRIPT
