#!/bin/bash
# 实例内一键部署（路线 B：notebook/opencode 实例，SSH 可用）
# 用法: bash deploy/setup_instance.sh
# 功能: 定位 ComfyUI -> 安装加速节点 -> 魔搭下载模型(断点续传) -> 后台启动 ComfyUI
set -u

# Python 探测: 优先用镜像自带 venv（含 torch ROCm）
PY=python3
if [ -x /opt/venv/bin/python ] && /opt/venv/bin/python -c "import torch" >/dev/null 2>&1; then
  PY=/opt/venv/bin/python
fi
if [ -x /opt/venv/bin/pip ]; then PIP=/opt/venv/bin/pip; else PIP="$PY -m pip"; fi
echo "[h3] Python: $PY"

# 1) 定位 ComfyUI
COMFY_DIR="$(dirname "$(find /root /workspace /opt /home -maxdepth 4 -type f -name main.py -path "*ComfyUI*" 2>/dev/null | head -1)")"
if [ -z "$COMFY_DIR" ] || [ ! -f "$COMFY_DIR/main.py" ]; then
  echo "[h3] 未找到 ComfyUI，正在克隆..."
  COMFY_DIR=/root/ComfyUI
  # 平台内网 GitHub 代理（TLS 中间人，需跳过证书校验）优先，公网镜像兜底
  GIT_SSL_NO_VERIFY=1 git clone --depth 1 https://github.com/comfyanonymous/ComfyUI.git "$COMFY_DIR" \
    || git clone --depth 1 https://gh-proxy.com/https://github.com/comfyanonymous/ComfyUI.git "$COMFY_DIR" \
    || git clone --depth 1 https://gitee.com/mirrors/ComfyUI.git "$COMFY_DIR"
fi
echo "[h3] ComfyUI: $COMFY_DIR"

# 1.5) 安装 ComfyUI 依赖（torch 已就绪则只补其余小包）
if ! "$PY" -c "import safetensors, einops, yaml" >/dev/null 2>&1; then
  $PIP install --no-cache-dir -r "$COMFY_DIR/requirements.txt" || true
fi

# 2) 定位加速包（平台可能已把 repo_url 克隆到 /workspace 下）
ACC=""
SELF_DIR="$(cd "$(dirname "$0")/.." 2>/dev/null && pwd)"
for d in "$SELF_DIR" /root/minimax-h3-comfyui-acceleration \
         /workspace/minimax-h3-comfyui-acceleration /workspace/*/minimax-h3-comfyui-acceleration; do
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

# 4) 下载模型（前台显示进度，断点续传；约 85GB）
REF2VA="${REF2VA:-0}" bash "$ACC/deploy/download_models_modelscope.sh" "$COMFY_DIR"

# 5) 后台启动 ComfyUI
if ! pgrep -f "main.py --listen" >/dev/null 2>&1; then
  cd "$COMFY_DIR" && nohup "$PY" main.py --listen 0.0.0.0 --port 8188 > /root/comfyui.log 2>&1 &
  sleep 20
  curl -s -o /dev/null -w "[h3] ComfyUI HTTP 状态: %{http_code}\n" --max-time 5 http://127.0.0.1:8188/
else
  echo "[h3] ComfyUI 已在运行"
fi
echo "[h3] 完成。日志: /root/comfyui.log"
