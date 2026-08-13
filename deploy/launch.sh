#!/bin/bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/config.sh"
source "$SCRIPT_DIR/status.sh"
mkdir -p "$H3_LOG_DIR" "$H3_RUNTIME_DIR"

PID_FILE="$H3_RUNTIME_DIR/bootstrap.pid"
if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE" 2>/dev/null)" 2>/dev/null; then
  echo "[h3] 启动任务已在后台运行，PID=$(cat "$PID_FILE")"
  exit 0
fi
if [ -f "$PID_FILE" ]; then
  mv "$PID_FILE" "${PID_FILE}.stale.$(date +%Y%m%d%H%M%S)"
fi

write_h3_status "bootstrap" "queued" "启动任务已提交"
nohup bash "$SCRIPT_DIR/bootstrap.sh" \
  >> "$H3_LOG_DIR/notebook-bootstrap.log" 2>&1 < /dev/null &
bootstrap_pid=$!
printf '%s\n' "$bootstrap_pid" > "$PID_FILE"
echo "[h3] 启动任务已提交，PID=$bootstrap_pid"
echo "[h3] 运行下方状态检查单元查看结果"
