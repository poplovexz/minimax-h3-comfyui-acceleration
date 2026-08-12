#!/bin/bash
# Radeon Cloud（developer.amd.com.cn）ComfyUI 模板启动脚本
# 功能: 安装加速包 -> 启动 ComfyUI -> 后台下载魔搭模型（断点续传）
# 幂等设计: 实例重启时自动跳过已完成的步骤
# 设计要点: ComfyUI 先行启动让平台尽快判定就绪；模型后台下载，
#           进度见 /root/h3_models_download.log
set -u
REPO="https://github.com/poplovexz/minimax-h3-comfyui-acceleration.git"
ACC="/root/minimax-h3-comfyui-acceleration"

# 1) 定位 ComfyUI 目录
COMFY_DIR="$(dirname "$(find /root /workspace /opt /home -maxdepth 4 -type f -name main.py -path "*ComfyUI*" 2>/dev/null | head -1)")"
[ -z "$COMFY_DIR" ] && COMFY_DIR="/root/ComfyUI"
echo "[h3] ComfyUI 目录: $COMFY_DIR"

# 2) 克隆加速包（GitHub 直连失败时走 gh-proxy 镜像）
if [ ! -d "$ACC/.git" ]; then
  git clone "$REPO" "$ACC" \
    || git clone "https://gh-proxy.com/$REPO" "$ACC" \
    || echo "[h3] 警告: 加速包克隆失败，将启动原生 ComfyUI"
fi

# 3) 安装加速节点；模型放后台下载
if [ -d "$ACC" ] && [ -d "$COMFY_DIR" ]; then
  python "$ACC/tools/install_into_comfyui.py" --comfyui "$COMFY_DIR" --force || true
  if ! pgrep -f download_models_modelscope.sh >/dev/null 2>&1; then
    nohup bash "$ACC/deploy/download_models_modelscope.sh" "$COMFY_DIR" \
      >> /root/h3_models_download.log 2>&1 &
    echo "[h3] 模型后台下载已启动，日志: /root/h3_models_download.log"
  fi
fi

# 4) 立即启动 ComfyUI
cd "$COMFY_DIR" && exec python main.py --listen 0.0.0.0 --port 8188
