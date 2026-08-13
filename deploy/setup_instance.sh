#!/bin/bash
# 实例内一键部署。所有路径和端口均可由 config.sh 的环境变量覆盖。
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/config.sh"
mkdir -p "$H3_RUNTIME_DIR"

# Python 探测: 优先镜像自带 venv（含 torch ROCm）
PY="$H3_PYTHON"
if [ ! -x "$PY" ]; then PY="${H3_PYTHON_FALLBACK:-python3}"; fi
if [ -x /opt/venv/bin/pip ]; then PIP=/opt/venv/bin/pip; else PIP="$PY -m pip"; fi
echo "[h3] Python: $PY"

# 1) 定位/克隆 ComfyUI（优先 /workspace 持久盘）
WS_OK=0
WS_FREE=$(df --output=avail -BG "$H3_WORKSPACE_ROOT" 2>/dev/null | tail -1 | tr -dc 0-9)
[ -d "$H3_WORKSPACE_ROOT" ] && [ "${WS_FREE:-0}" -ge 8 ] && WS_OK=1
COMFY_DIR=""
for d in "$H3_COMFYUI_DIR" /root/ComfyUI; do
  [ -f "$d/main.py" ] && COMFY_DIR="$d" && break
done
if [ -z "$COMFY_DIR" ]; then
  if [ "$WS_OK" = "1" ]; then COMFY_DIR="$H3_COMFYUI_DIR"; else COMFY_DIR=/root/ComfyUI; fi
  if [ -e "$COMFY_DIR" ]; then
    INCOMPLETE_DIR="${COMFY_DIR}.incomplete.$(date +%Y%m%d%H%M%S)"
    echo "[h3] 保留不完整目录: $INCOMPLETE_DIR"
    mv "$COMFY_DIR" "$INCOMPLETE_DIR"
  fi
  echo "[h3] 克隆 ComfyUI 到 $COMFY_DIR ..."
  clone_ok=0
  clone_index=0
  for repo_url in "$H3_COMFYUI_REPO_URL" "$H3_COMFYUI_PROXY_URL" "$H3_COMFYUI_MIRROR_URL"; do
    clone_index=$((clone_index + 1))
    staging_dir="${COMFY_DIR}.clone.${clone_index}.$$"
    if timeout "${H3_GIT_TIMEOUT_SEC:-300}" \
      git clone --depth 1 "$repo_url" "$staging_dir"; then
      mv "$staging_dir" "$COMFY_DIR"
      clone_ok=1
      break
    fi
    if [ -e "$staging_dir" ]; then
      mv "$staging_dir" "${staging_dir}.failed"
    fi
  done
  if [ "$clone_ok" != "1" ]; then
    echo "[h3] 所有 ComfyUI 镜像源均克隆失败" >&2
    exit 1
  fi
fi
echo "[h3] ComfyUI: $COMFY_DIR"

# 1.5) 补齐 ComfyUI 依赖，但保留镜像自带的 ROCm PyTorch。
REQ_FILE="$H3_RUNTIME_DIR/comfyui-requirements.txt"
grep -Ev '^(torch|torchvision|torchaudio)([<=>].*)?$' \
  "$COMFY_DIR/requirements.txt" > "$REQ_FILE"
timeout "${H3_PIP_TIMEOUT_SEC:-900}" $PIP install --no-cache-dir -r "$REQ_FILE"

# 2) 定位加速包
ACC=""
SELF_DIR="$(cd "$(dirname "$0")/.." 2>/dev/null && pwd)"
for d in "$SELF_DIR" "$H3_ACCEL_DIR" "$H3_WORKSPACE_ROOT"/template-repos/*/repo /root/minimax-h3-comfyui-acceleration; do
  if [ -f "$d/tools/install_into_comfyui.py" ]; then ACC="$d"; break; fi
done
if [ -z "$ACC" ]; then
  ACC="$H3_ACCEL_DIR"
  GIT_SSL_NO_VERIFY=1 git clone "$H3_REPO_URL" "$ACC" \
    || git clone "$H3_GIT_PROXY_URL" "$ACC"
fi
echo "[h3] 加速包: $ACC"

# 3) 安装加速节点（Turbo / FBC / Spectrum）
"$PY" "$ACC/tools/install_into_comfyui.py" --comfyui "$COMFY_DIR" --force

# 4) 模型目录可由 H3_MODELS_DIR 切换，软链进 ComfyUI。
MODELS_DIR="$H3_MODELS_DIR"
mkdir -p "$MODELS_DIR"
if [ -d "$COMFY_DIR/models" ] && [ ! -L "$COMFY_DIR/models" ]; then
  echo "[h3] 迁移已有模型到 $MODELS_DIR ..."
  mv "$COMFY_DIR/models"/* "$MODELS_DIR"/ 2>/dev/null || true
  mv "$COMFY_DIR/models"/.[!.]* "$MODELS_DIR"/ 2>/dev/null || true
  rmdir "$COMFY_DIR/models" 2>/dev/null || true
fi
ln -sfn "$MODELS_DIR" "$COMFY_DIR/models"
{
  printf 'H3_COMFYUI_DIR=%q\n' "$COMFY_DIR"
  printf 'H3_ACCEL_DIR=%q\n' "$ACC"
  printf 'H3_MODELS_DIR=%q\n' "$MODELS_DIR"
} > "$H3_RESOLVED_ENV"
echo "[h3] ComfyUI: $COMFY_DIR"
echo "[h3] 模型目录: $MODELS_DIR"
echo "[h3] setup 完成；由 bootstrap.sh 启动服务和后台模型下载"
