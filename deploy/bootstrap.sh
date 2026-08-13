#!/bin/bash
set -u
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/config.sh"
mkdir -p "$H3_LOG_DIR" "$H3_RUNTIME_DIR"
exec > >(tee -a "$H3_LOG_DIR/bootstrap.log") 2>&1
echo "[h3] bootstrap 开始: $(date -Is)"

bash "$SCRIPT_DIR/enable_ssh.sh"
bash "$SCRIPT_DIR/setup_instance.sh"
bash "$SCRIPT_DIR/start_comfyui.sh"

if ! pgrep -af "download_models_modelscope.sh" >/dev/null 2>&1; then
  nohup bash "$SCRIPT_DIR/download_models_modelscope.sh" "$H3_MODELS_DIR" \
    >> "$H3_LOG_DIR/models.log" 2>&1 < /dev/null &
  echo "[h3] 模型下载已后台启动，日志: $H3_LOG_DIR/models.log"
else
  echo "[h3] 模型下载已在运行"
fi
echo "[h3] bootstrap 完成: $(date -Is)"
