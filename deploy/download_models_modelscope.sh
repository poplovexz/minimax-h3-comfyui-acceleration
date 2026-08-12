#!/bin/bash
# 从魔搭（ModelScope）下载 MiniMax H3 全套模型（国内网络适配，支持断点续传）
# 用法: bash deploy/download_models_modelscope.sh /path/to/ComfyUI
set -u
COMFY_DIR="${1:-$(dirname "$(find /root /workspace /opt /home -maxdepth 4 -type f -name main.py -path "*ComfyUI*" 2>/dev/null | head -1)")}"
if [ -z "$COMFY_DIR" ] || [ ! -d "$COMFY_DIR" ]; then
  echo "错误: 找不到 ComfyUI 目录，请传入路径作为第一个参数" >&2
  exit 1
fi
case "$COMFY_DIR" in
  */models) MODELS="$COMFY_DIR" ;;
  *) MODELS="$COMFY_DIR/models" ;;
esac

UA="Mozilla/5.0"
MS="https://modelscope.cn/models/Comfy-Org/MiniMax-H3/resolve/master"
TURBO="https://modelscope.cn/models/larryvrh/MiniMax-H3-Turbo-Lora/resolve/master"

mkdir -p "$MODELS/diffusion_models" "$MODELS/text_encoders" \
         "$MODELS/vae" "$MODELS/loras"

dl() {
  local url="$1" dest="$2"
  if [ -f "$dest" ]; then
    echo "已存在，跳过: $dest"
    return 0
  fi
  echo "下载: $dest"
  if command -v aria2c >/dev/null 2>&1; then
    aria2c -x 8 -s 8 -k 1M --max-tries=10 --retry-wait=3 --continue=true \
      --user-agent="$UA" --auto-file-renaming=false --console-log-level=warn \
      -d "$(dirname "$dest")" -o "$(basename "$dest")" "$url" || return 1
  else
    until curl -L -C - --retry 10 --retry-delay 5 -A "$UA" -o "$dest" "$url"; do
      echo "重试中..."; sleep 5
    done
  fi
}

dl "$MS/diffusion_models/minimax_h3_fl2va_pruned_int8_convrot.safetensors" \
   "$MODELS/diffusion_models/minimax_h3_fl2va_pruned_int8_convrot.safetensors"
# ref2va（参考图生视频）体积大且吃磁盘配额，默认跳过；REF2VA=1 时下载
if [ "${REF2VA:-0}" = "1" ]; then
  dl "$MS/diffusion_models/minimax_h3_ref2va_pruned_int8_convrot.safetensors" \
     "$MODELS/diffusion_models/minimax_h3_ref2va_pruned_int8_convrot.safetensors"
fi
dl "$MS/text_encoders/qwen3vl_32b_minimax_h3_nvfp4_awq.safetensors" \
   "$MODELS/text_encoders/qwen3vl_32b_minimax_h3_nvfp4_awq.safetensors"
dl "$MS/vae/minimax_h3_video_vae_fp16.safetensors" \
   "$MODELS/vae/minimax_h3_video_vae_fp16.safetensors"
dl "$MS/vae/minimax_h3_audio_vae_fp32.safetensors" \
   "$MODELS/vae/minimax_h3_audio_vae_fp32.safetensors"
dl "$TURBO/minimax_h3_turbo_v4_step600_ema.safetensors" \
   "$MODELS/loras/minimax_h3_turbo_v4_step600_ema.safetensors"
echo "全部模型下载完成（约 85 GB）"
