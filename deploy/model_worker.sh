#!/bin/bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/config.sh"
source "$SCRIPT_DIR/status.sh"
mkdir -p "$H3_LOG_DIR" "$H3_RUNTIME_DIR"

on_exit() {
  local exit_code="$?"
  if [ "$exit_code" -ne 0 ]; then
    write_h3_status "models" "failed" "H3 模型下载失败，退出码 ${exit_code}"
  fi
  rm -f "$H3_RUNTIME_DIR/model-worker.pid"
}
trap on_exit EXIT

write_h3_status "models" "downloading" "SSH 与 ComfyUI 已就绪，正在下载核心 H3 模型"
free_gb="$(df --output=avail -BG "$H3_MODELS_DIR" | tail -1 | tr -dc '0-9')"
if [ "${free_gb:-0}" -lt "$H3_CORE_MODELS_MIN_FREE_GB" ]; then
  echo "[h3] 模型目录空间不足: ${free_gb:-0}GB 可用，至少需要 ${H3_CORE_MODELS_MIN_FREE_GB}GB" >&2
  exit 1
fi
bash "$SCRIPT_DIR/download_models_modelscope.sh" "$H3_MODELS_DIR"
if [ ! -f "$H3_MODELS_DIR/.core.complete" ]; then
  echo "[h3] 核心模型完成标记缺失" >&2
  exit 1
fi
write_h3_status "models" "ready" "SSH、ComfyUI 与核心 H3 模型均已就绪"
