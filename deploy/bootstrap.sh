#!/bin/bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/config.sh"
source "$SCRIPT_DIR/status.sh"
mkdir -p "$H3_LOG_DIR" "$H3_RUNTIME_DIR"
exec > >(tee -a "$H3_LOG_DIR/bootstrap.log") 2>&1
exec 8>"$H3_RUNTIME_DIR/bootstrap.lock"
if ! flock -n 8; then
  write_h3_status "bootstrap" "running" "启动任务已经在运行"
  echo "[h3] bootstrap 已在运行，本次不重复启动"
  exit 0
fi

on_error() {
  local exit_code="$?" line_no="$1"
  write_h3_status "bootstrap" "failed" "启动在第 ${line_no} 行失败，退出码 ${exit_code}"
  echo "[h3] bootstrap 失败: line=$line_no exit=$exit_code" >&2
  exit "$exit_code"
}
trap 'on_error $LINENO' ERR
trap 'rm -f "$H3_RUNTIME_DIR/bootstrap.pid"' EXIT
write_h3_status "bootstrap" "starting" "正在初始化实例"
echo "[h3] bootstrap 开始: $(date -Is)"

ssh_ready=1
if ! bash "$SCRIPT_DIR/enable_ssh.sh"; then
  ssh_ready=0
  echo "[h3] SSH 初始化失败，继续检查 ComfyUI"
fi
bash "$SCRIPT_DIR/setup_instance.sh"
comfy_ready=1
if ! bash "$SCRIPT_DIR/start_comfyui.sh"; then
  comfy_ready=0
  echo "[h3] ComfyUI 启动失败: $H3_LOG_DIR/comfyui-process.log"
fi

if [ "$ssh_ready" = "1" ] && [ "$comfy_ready" = "1" ]; then
  MODEL_PID_FILE="$H3_RUNTIME_DIR/model-worker.pid"
  if [ -f "$MODEL_PID_FILE" ] && kill -0 "$(cat "$MODEL_PID_FILE" 2>/dev/null)" 2>/dev/null; then
    echo "[h3] 模型下载已在运行"
  elif [ -f "$H3_MODELS_DIR/.core.complete" ]; then
    echo "[h3] 核心模型已就绪"
  else
    nohup bash "$SCRIPT_DIR/model_worker.sh" \
      >> "$H3_LOG_DIR/models.log" 2>&1 < /dev/null &
    printf '%s\n' "$!" > "$MODEL_PID_FILE"
    echo "[h3] 模型下载已后台启动，日志: $H3_LOG_DIR/models.log"
  fi
  if [ -f "$H3_MODELS_DIR/.core.complete" ]; then
    write_h3_status "models" "ready" "SSH、ComfyUI 与核心 H3 模型均已就绪"
  else
    write_h3_status "models" "downloading" "SSH 与 ComfyUI 已就绪，核心 H3 模型正在下载"
  fi
  echo "[h3] bootstrap 成功: $(date -Is)"
  exit 0
fi

failure_message=""
if [ "$ssh_ready" != "1" ]; then failure_message="SSH 未就绪"; fi
if [ "$comfy_ready" != "1" ]; then
  if [ -n "$failure_message" ]; then failure_message="$failure_message；"; fi
  failure_message="${failure_message}ComfyUI 未就绪"
fi
write_h3_status "services" "failed" "$failure_message"
echo "[h3] bootstrap 未通过完整健康检查" >&2
exit 1
