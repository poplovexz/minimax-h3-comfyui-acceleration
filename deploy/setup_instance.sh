#!/bin/bash
# 实例内一键部署 v3（持久盘优先布局）
# 布局:
#   /workspace/ComfyUI   ComfyUI 代码+节点+工作流（持久盘，重启保留）
#   /root/h3_models      模型权重（overlay，重启后自动断点续传重新下载）
#   /workspace/ssh       SSH authorized_keys（持久盘）
set -u

# Python 探测: 优先镜像自带 venv（含 torch ROCm）
PY=python3
if [ -x /opt/venv/bin/python ] && /opt/venv/bin/python -c "import torch" >/dev/null 2>&1; then
  PY=/opt/venv/bin/python
fi
if [ -x /opt/venv/bin/pip ]; then PIP=/opt/venv/bin/pip; else PIP="$PY -m pip"; fi
echo "[h3] Python: $PY"

# 1) 定位/克隆 ComfyUI（优先 /workspace 持久盘）
WS_OK=0
WS_FREE=$(df --output=avail -BG /workspace 2>/dev/null | tail -1 | tr -dc 0-9)
[ -d /workspace ] && [ "${WS_FREE:-0}" -ge 8 ] && WS_OK=1
COMFY_DIR=""
for d in /workspace/ComfyUI /root/ComfyUI; do
  [ -f "$d/main.py" ] && COMFY_DIR="$d" && break
done
if [ -z "$COMFY_DIR" ]; then
  if [ "$WS_OK" = "1" ]; then COMFY_DIR=/workspace/ComfyUI; else COMFY_DIR=/root/ComfyUI; fi
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
for d in "$SELF_DIR" /workspace/template-repos/*/repo /workspace/minimax-h3-comfyui-acceleration /root/minimax-h3-comfyui-acceleration; do
  if [ -f "$d/tools/install_into_comfyui.py" ]; then ACC="$d"; break; fi
done
if [ -z "$ACC" ]; then
  ACC=/root/minimax-h3-comfyui-acceleration
  GIT_SSL_NO_VERIFY=1 git clone https://github.com/poplovexz/minimax-h3-comfyui-acceleration.git "$ACC" \
    || git clone https://gh-proxy.com/https://github.com/poplovexz/minimax-h3-comfyui-acceleration.git "$ACC"
fi
echo "[h3] 加速包: $ACC"

# 3) 安装加速节点（Turbo / FBC / Spectrum）
"$PY" "$ACC/tools/install_into_comfyui.py" --comfyui "$COMFY_DIR" --force || true

# 4) 模型: 放 overlay（/root/h3_models），软链进 ComfyUI；重启后断点续传
MODELS_DIR=/root/h3_models
mkdir -p "$MODELS_DIR"
if [ -d "$COMFY_DIR/models" ] && [ ! -L "$COMFY_DIR/models" ]; then
  echo "[h3] 迁移已有模型到 $MODELS_DIR ..."
  mv "$COMFY_DIR/models"/* "$MODELS_DIR"/ 2>/dev/null || true
  mv "$COMFY_DIR/models"/.[!.]* "$MODELS_DIR"/ 2>/dev/null || true
  rmdir "$COMFY_DIR/models" 2>/dev/null || true
fi
REF2VA="${REF2VA:-0}" bash "$ACC/deploy/download_models_modelscope.sh" "$MODELS_DIR"
ln -sfn "$MODELS_DIR" "$COMFY_DIR/models"

# 5) 启动 ComfyUI（后台）
if ! pgrep -f "main.py --listen" >/dev/null 2>&1; then
  cd "$COMFY_DIR" && nohup "$PY" main.py --listen 0.0.0.0 --port 8188 > /root/comfyui.log 2>&1 &
  sleep 20
  curl -s -o /dev/null -w "[h3] ComfyUI HTTP 状态: %{http_code}\n" --max-time 5 http://127.0.0.1:8188/
else
  echo "[h3] ComfyUI 已在运行"
fi
echo "[h3] 完成。日志: /root/comfyui.log"
