#!/bin/bash
# 实例内一键部署。所有路径和端口均可由 config.sh 的环境变量覆盖。
set -u
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/config.sh"

# Python 探测: 优先镜像自带 venv（含 torch ROCm）
PY="$H3_PYTHON"
if [ ! -x "$PY" ]; then PY="${H3_PYTHON_FALLBACK:-python3}"; fi
if [ -x /opt/venv/bin/pip ]; then PIP=/opt/venv/bin/pip; else PIP="$PY -m pip"; fi
echo "[h3] Python: $PY"

# 1) 定位/克隆 ComfyUI（优先 /workspace 持久盘）
WS_OK=0
WS_FREE=$(df --output=avail -BG /workspace 2>/dev/null | tail -1 | tr -dc 0-9)
[ -d /workspace ] && [ "${WS_FREE:-0}" -ge 8 ] && WS_OK=1
COMFY_DIR=""
for d in "$H3_COMFYUI_DIR" /root/ComfyUI; do
  [ -f "$d/main.py" ] && COMFY_DIR="$d" && break
done
if [ -z "$COMFY_DIR" ]; then
  if [ "$WS_OK" = "1" ]; then COMFY_DIR="$H3_COMFYUI_DIR"; else COMFY_DIR=/root/ComfyUI; fi
  echo "[h3] 克隆 ComfyUI 到 $COMFY_DIR ..."
  GIT_SSL_NO_VERIFY=1 git clone --depth 1 https://github.com/comfyanonymous/ComfyUI.git "$COMFY_DIR" \
    || git clone --depth 1 https://gh-proxy.com/https://github.com/comfyanonymous/ComfyUI.git "$COMFY_DIR" \
    || git clone --depth 1 https://gitee.com/mirrors/ComfyUI.git "$COMFY_DIR"
fi
echo "[h3] ComfyUI: $COMFY_DIR"

# 1.5) ComfyUI 依赖
if ! "$PY" -c "import safetensors, einops, yaml" >/dev/null 2>&1; then
  $PIP install --no-cache-dir -r "$COMFY_DIR/requirements.txt" || true
fi

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
"$PY" "$ACC/tools/install_into_comfyui.py" --comfyui "$COMFY_DIR" --force || true

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
echo "[h3] ComfyUI: $COMFY_DIR"
echo "[h3] 模型目录: $MODELS_DIR"
echo "[h3] setup 完成；由 bootstrap.sh 启动服务和后台模型下载"
