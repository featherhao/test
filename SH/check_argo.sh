#!/bin/bash
set -Eeuo pipefail

# 简短用途说明：
# Usage: ./check_argo.sh [--port PORT] [--domain DOMAIN]
# 如果不传 port/domain，脚本会尝试从 agsbx list 里解析（若 agsbx 脚本可用）。

SCRIPT_URL="https://raw.githubusercontent.com/yonggekkk/argosbx/refs/heads/main/argosbx.sh"
MAIN_SCRIPT_CMD="bash <(curl -Ls ${SCRIPT_URL})"

# parse args
VMPT_ARG=""
AGN_ARG=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --port) VMPT_ARG="$2"; shift 2;;
    --domain) AGN_ARG="$2"; shift 2;;
    *) echo "忽略未知参数: $1"; shift;;
  esac
done

echo "===================== Argo 快速诊断开始 ====================="
echo "时间: $(date)"
echo

### 1) 从 agsbx list 尝试读取配置（可选）
echo "-> 从 agsbx list 尝试读取 vmpt / argo / agn / agk ..."
LIST_OUT=$($MAIN_SCRIPT_CMD list 2>/dev/null || true)
if [[ -z "${LIST_OUT}" ]]; then
  echo "  (未能从 agsbx list 读取到内容 — 可能 agsbx 无法执行或需要交互)"
else
  echo "  (显示 agsbx list 的前 30 行，完整输出保存在 /tmp/agsbx_list.txt)"
  echo "$LIST_OUT" | sed -n '1,30p'
  echo "$LIST_OUT" > /tmp/agsbx_list.txt
fi

# 尝试解析 vmpt / argo / agn / agk（能解析到就用）
VMPT="$(echo "$LIST_OUT" | grep -Eo 'vmpt[[:space:]]*[:=][[:space:]]*\"?[0-9]+' | grep -Eo '[0-9]+' | head -n1 || true)"
ARGO_FLAG="$(echo "$LIST_OUT" | grep -Eo 'argo[[:space:]]*[:=][[:space:]]*\"?y\"?' || true)"
AGN="$(echo "$LIST_OUT" | grep -Eo 'agn[[:space:]]*[:=][[:space:]]*\"[^\"]+\"' | sed -E 's/.*\"([^\"]+)\".*/\1/' || true)"
AGK="$(echo "$LIST_OUT" | grep -Eo 'agk[[:space:]]*[:=][[:space:]]*\"[^\"]+\"' | sed -E 's/.*\"([^\"]+)\".*/\1/' || true)"

# 用命令行参数覆盖解析到的值（如果有）
[[ -n "$VMPT_ARG" ]] && VMPT="$VMPT_ARG"
[[ -n "$AGN_ARG" ]] && AGN="$AGN_ARG"

echo
echo "检测到的配置摘要："
echo "  vmpt (端口)  = ${VMPT:-<unknown>}"
echo "  argo 标志     = ${ARGO_FLAG:-<not set>}"
echo "  agn (域名)   = ${AGN:-<unknown>}"
echo "  agk (token)  = $( [[ -n "$AGK" ]] && echo '<present>' || echo '<unknown/not parsed>' )"
echo

### 2) cloudflared 进程 / service 检查
echo "-> 检查 cloudflared 进程..."
if pgrep -a cloudflared >/dev/null 2>&1; then
  pgrep -a cloudflared
  PIDS="$(pgrep cloudflared | tr '\n' ' ')"
else
  echo "  未发现 cloudflared 进程 (pgrep 未命中)。尝试 ps 检查："
  ps -ef | grep -i '[c]loudflared' || true
fi
echo

echo "-> 检查 systemd 服务 (若存在 cloudflared service)..."
if command -v systemctl &>/dev/null; then
  systemctl status cloudflared.service --no-pager 2>/dev/null || systemctl status cloudflared 2>/dev/null || echo "  systemd 中未找到 cloudflared.service"
else
  echo "  systemctl 不存在，跳过 systemd 检查"
fi
echo

### 3) cloudflared 日志（journalctl）
echo "-> 尝试获取 cloudflared 最近日志（journalctl -u cloudflared -n 200）"
if command -v journalctl &>/dev/null; then
  journalctl -u cloudflared -n 200 --no-pager 2>/dev/null || echo "  无 journal 日志或服务名不同"
else
  echo "  本机无 journalctl 可用"
fi
echo

### 4) cloudflared 启动命令行（查看 cmdline）
if [[ -n "${PIDS:-}" ]]; then
  for pid in $PIDS; do
    echo "-> cloudflared (PID $pid) cmdline:"
    tr '\0' ' ' < /proc/"$pid"/cmdline 2>/dev/null || echo "  无法读取 /proc/$pid/cmdline"
    echo
    echo "  打开文件描述符 (tail)："
    ls -l /proc/"$pid"/fd 2>/dev/null | sed -n '1,20p' || true
    echo
  done
fi

### 5) 本地 vmess 端口监听检查（如果知道 vmpt）
if [[ -n "${VMPT:-}" ]]; then
  echo "-> 检查本地是否在监听 vmpt 端口 ${VMPT} ..."
  if command -v ss &>/dev/null; then
    ss -tuln | grep -E "[:.]${VMPT}(\s|$)" || echo "  未发现监听（ss 未匹配到端口 ${VMPT}）"
  else
    netstat -tuln 2>/dev/null | grep -E "[:.]${VMPT}(\s|$)" || echo "  未发现监听（netstat 未匹配到端口 ${VMPT}）"
  fi
  echo
else
  echo "-> 未提供 vmpt，跳过本地端口监听检查（若你知道端口，可用 --port 指定）"
  echo
fi

### 6) 外部访问 Argo 域名测试（如果知道 agn）
if [[ -n "${AGN:-}" ]]; then
  echo "-> 测试 Argo 域名 https://${AGN} ..."
  if command -v curl &>/dev/null; then
    curl -vk --max-time 12 "https://${AGN}" 2>&1 | sed -n '1,120p'
    echo "  (curl 返回输出只显示前 120 行)"
  else
    echo "  未安装 curl，无法测试域名连通性"
  fi

  echo
  echo "-> DNS 解析检查："
  if command -v getent &>/dev/null; then
    getent hosts "${AGN}" || true
  fi
  if command -v dig &>/dev/null; then
    dig +short "${AGN}" || true
  elif command -v host &>/dev/null; then
    host "${AGN}" || true
  else
    echo "  未安装 dig/host，可手动检查 DNS"
  fi
else
  echo "-> 未提供 agn（域名），跳过域名连通性与 DNS 检查（可用 --domain 提供）"
fi
echo

### 7) 外网出口简单测试（确认服务器能与 Cloudflare 联通）
echo "-> 测试服务器与外网的基本连通性（cloudflare）..."
if command -v curl &>/dev/null; then
  curl -I --connect-timeout 6 https://www.cloudflare.com 2>&1 | sed -n '1,20p' || echo "  无法连通 cloudflare"
else
  echo "  无 curl，跳过"
fi
echo

### 8) 查看 cloudflared 与远端连接（ESTABLISHED）
echo "-> 查看 cloudflared 的 TCP 连接（若有进程存在）"
if command -v ss &>/dev/null; then
  ss -tnp | grep -i cloudflared || echo "  未发现 cloudflared 的 TCP 连接"
else
  netstat -ntp 2>/dev/null | grep -i cloudflared || echo "  未发现 cloudflared 的 TCP 连接"
fi
echo

### 9) firewall / iptables 检查提示
echo "-> 防火墙可能会阻止监听或出站，请检查 (ufw/iptables/firewalld)。示例检查命令："
echo "   sudo ufw status || sudo iptables -L -n --line-numbers || sudo firewall-cmd --list-all"
echo

### 10) 推荐下一步（自动化修复/重装示例）
echo "===================== 诊断结束 — 建议下一步 ====================="
echo "请按下面提示逐项排查："
echo "1) 若 cloudflared 未运行："
echo "   - 检查 systemd 日志： sudo journalctl -u cloudflared -n 200"
echo "   - 启动服务： sudo systemctl start cloudflared 或用上游脚本一次性安装："
echo "     eval \"vmpt=你的端口 argo=y agn=你的域名 agk=你的token ${MAIN_SCRIPT_CMD} rep\""
echo
echo "2) 若 cloudflared 运行但域名 curl 连接失败："
echo "   - 检查 agn/ agk 是否正确（token 是否过期/权限不足）"
echo "   - 在 Cloudflare 仪表盘确认 tunnel 已存在且 token 有效"
echo
echo "3) 若本地 vmpt 端口没有监听："
echo "   - 确认你的代理服务/程序（vmess）是否已成功启动并监听该端口"
echo "   - 如果没有，请检查上游脚本是否正确把 vmpt 绑定到本地服务"
echo
echo "4) 改动流程建议：一次性把 vmpt + argo=y (+ agn/agk) 放到同一次 rep 中应用（否则会被后续 rep 覆盖）"
echo
echo "如果你愿意，我可以："
echo " - 帮你把这个诊断函数集成到原脚本的菜单（安装后自动跑一次检测）；"
echo " - 或者根据你把上面检查的关键输出（cloudflared 日志错误片段、ss/list 输出、agsbx list 输出）贴上来，我帮你逐条分析并给出具体修复命令。"
echo
echo "----------------------------------------------------------------"
