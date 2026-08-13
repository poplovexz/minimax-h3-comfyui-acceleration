#!/bin/bash
set -u
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/config.sh"
mkdir -p "$H3_LOG_DIR" "$H3_RUNTIME_DIR"

while true; do
  if [ ! -f "$H3_COMFYUI_DIR/main.py" ]; then
    echo "[h3] 等待 ComfyUI: $H3_COMFYUI_DIR/main.py" >&2
    sleep "${H3_RESTART_DELAY_SEC:-5}"
    continue
  fi
  cd "$H3_COMFYUI_DIR" || exit 1
  "$H3_PYTHON" main.py --listen "${H3_COMFYUI_BIND:-0.0.0.0}" \
    --port "$H3_COMFYUI_PORT" >> "$H3_LOG_DIR/comfyui-process.log" 2>&1 &
  child=$!
  echo "$child" > "$H3_RUNTIME_DIR/comfyui.pid"
  wait "$child" || true
  rm -f "$H3_RUNTIME_DIR/comfyui.pid"
  echo "[h3] ComfyUI 进程退出，${H3_RESTART_DELAY_SEC:-5} 秒后重启" >&2
  sleep "${H3_RESTART_DELAY_SEC:-5}"
done
