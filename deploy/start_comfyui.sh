#!/bin/bash
set -u
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/config.sh"
mkdir -p "$H3_LOG_DIR" "$H3_RUNTIME_DIR"
PID_FILE="$H3_RUNTIME_DIR/comfyui-supervisor.pid"

if [ ! -f "$H3_COMFYUI_DIR/main.py" ]; then
  echo "[h3] ComfyUI 不存在: $H3_COMFYUI_DIR" >&2
  exit 1
fi
if curl -fsS --max-time 2 -o /dev/null "http://127.0.0.1:${H3_COMFYUI_PORT}/" 2>/dev/null; then
  echo "[h3] 已有 ComfyUI 服务就绪"
  exit 0
fi
if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE" 2>/dev/null)" 2>/dev/null; then
  echo "[h3] ComfyUI 守护进程已运行"
else
  rm -f "$PID_FILE"
  nohup bash "$SCRIPT_DIR/comfyui_supervisor.sh" >> "$H3_LOG_DIR/comfyui.log" 2>&1 < /dev/null &
  echo $! > "$PID_FILE"
fi

URL="http://127.0.0.1:${H3_COMFYUI_PORT}/"
for _ in $(seq 1 "${H3_READY_TIMEOUT_SEC:-180}"); do
  if curl -fsS --max-time 2 -o /dev/null "$URL" 2>/dev/null; then
    echo "[h3] ComfyUI 已就绪: $URL"
    exit 0
  fi
  sleep 1
done
echo "[h3] ComfyUI 尚未响应，进程日志如下:" >&2
tail -n "${H3_ERROR_LOG_LINES:-40}" "$H3_LOG_DIR/comfyui-process.log" 2>/dev/null >&2 || true
exit 1
