# 1. 写入通用清理脚本
#cat << 'EOF' > /root/vps_clean_universal.sh
#!/bin/bash

# 检查是否为 Root 用户运行
if [ "$EUID" -ne 0 ]; then
  echo "请以 root 用户身份运行此脚本！"
  exit 1
fi

echo "================================================="
echo "       Linux VPS 通用深度清理脚本 (自动化版)"
echo "================================================="

# 1. 动态清理所有 Docker 容器日志与无用镜像
if command -v docker &> /dev/null; then
    echo "-> [Docker] 检测到 Docker 已安装，开始清理..."
    
    # 清空所有正在运行的容器日志
    echo "-> [Docker] 正在清空所有容器的运行时日志..."
    find /var/lib/docker/containers/ -name *-json.log -exec truncate -s 0 {} \; 2>/dev/null
    
    # 清理未使用的镜像、容器、网络和卷
    echo "-> [Docker] 正在深度裁剪无用镜像与缓存..."
    docker system prune -a --volumes -f
else
    echo "-> [Docker] 未检测到 Docker 环境，跳过。"
fi

# 2. 系统软件包缓存清理（自动识别系统家族）
echo "-> [系统] 开始清理软件包管理器缓存..."
if [ -f /usr/bin/apt-get ]; then
    # Debian / Ubuntu 系列
    dpkg --configure -a
    apt-get autoremove -y
    apt-get autoclean -y
    apt-get clean -y
elif [ -f /usr/bin/yum ]; then
    # CentOS / RHEL / 旧版 Fedora 系列
    yum autoremove -y
    yum clean all
elif [ -f /usr/bin/dnf ]; then
    # 新版 Fedora / AlmaLinux / Rocky 系列
    dnf autoremove -y
    dnf clean all
fi

# 3. 系统日志与爆破残余清理
echo "-> [日志] 正在限制并截断系统 journal 日志..."
if command -v journalctl &> /dev/null; then
    journalctl --rotate
    journalctl --vacuum-time=3d
    journalctl --vacuum-size=50M
fi

echo "-> [日志] 正在清理常见的系统历史爆破与大日志文件..."
# 清理防爆破历史日志
[ -f /var/log/btmp ] && truncate -s 0 /var/log/btmp
[ -f /var/log/btmp.1 ] && rm -f /var/log/btmp.1
[ -f /var/log/auth.log ] && truncate -s 0 /var/log/auth.log
[ -f /var/log/secure ] && truncate -s 0 /var/log/secure

# 4. 清理全盘所有 .log 后缀文件（保留文件，体积归零）
echo "-> [全盘] 正在检索并清空所有大于 50M 的 .log 文本日志..."
find / -type f -name "*.log" -size +50M -exec truncate -s 0 {} \; 2>/dev/null

# 5. 清理系统临时文件夹
echo "-> [临时] 正在清理 /tmp 目录下的过期临时文件..."
find /tmp -type f -atime +2 -delete 2>/dev/null

echo "================================================="
echo "        清理完成！当前根目录硬盘状态："
echo "================================================="
df -h /

EOF

# 2. 赋予脚本执行权限
chmod +x /root/vps_clean_universal.sh

# 3. 立即运行
bash /root/vps_clean_universal.sh
