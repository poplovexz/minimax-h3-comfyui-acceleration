#!/bin/bash
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/config.sh"

if [ -f "$H3_STATUS_FILE" ]; then
  source "$H3_STATUS_FILE"
  echo "状态: ${H3_RESULT:-unknown}"
  echo "阶段: ${H3_PHASE:-unknown}"
  echo "说明: ${H3_MESSAGE:-无}"
  echo "更新: ${H3_UPDATED_AT:-unknown}"
else
  echo "状态: not-started"
fi

if pgrep -x sshd >/dev/null 2>&1; then
  echo "SSH: ready"
else
  echo "SSH: unavailable"
fi

if curl -fsS --max-time 3 -o /dev/null \
  "http://127.0.0.1:${H3_COMFYUI_PORT}/" 2>/dev/null; then
  echo "ComfyUI: ready"
else
  echo "ComfyUI: unavailable"
fi

echo "模型目录: $H3_MODELS_DIR"
du -sh "$H3_MODELS_DIR" 2>/dev/null || true
find "$H3_MODELS_DIR" -name '*.safetensors.complete' -printf '%P\n' 2>/dev/null || true

echo "最近日志:"
tail -n "${H3_STATUS_LOG_LINES:-12}" "$H3_LOG_DIR/bootstrap.log" 2>/dev/null || true
