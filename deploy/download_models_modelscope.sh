#!/bin/bash
# 从魔搭下载 MiniMax H3 模型，支持断点续传、锁和完成标记。
set -u
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/config.sh"
MODELS="${1:-$H3_MODELS_DIR}"
case "$MODELS" in
  */ComfyUI) MODELS="$MODELS/models" ;;
esac
UA="Mozilla/5.0"
MS="$H3_MODEL_BASE_URL"
TURBO="$H3_TURBO_BASE_URL"

mkdir -p "$MODELS/diffusion_models" "$MODELS/text_encoders" "$MODELS/vae" "$MODELS/loras"
exec 9>"$MODELS/.download.lock"
flock -n 9 || { echo "模型下载已在其他进程运行"; exit 0; }

dl() {
  local url="$1" dest="$2" marker="${2}.complete"
  if [ -f "$marker" ] && [ -s "$dest" ]; then
    echo "已完成，跳过: $dest"
    return 0
  fi
  echo "下载: $dest"
  if command -v aria2c >/dev/null 2>&1; then
    aria2c -x "${H3_ARIA2_CONNECTIONS:-8}" -s "${H3_ARIA2_SPLITS:-8}" \
      -k "${H3_ARIA2_BLOCK_SIZE:-1M}" --max-tries "${H3_DOWNLOAD_RETRIES:-10}" \
      --retry-wait "${H3_RETRY_WAIT_SEC:-3}" --continue=true \
      --user-agent="$UA" --auto-file-renaming=false --console-log-level=warn \
      -d "$(dirname "$dest")" -o "$(basename "$dest")" "$url" || return 1
  else
    until curl -fL -C - --retry "${H3_DOWNLOAD_RETRIES:-10}" \
      --retry-delay "${H3_RETRY_WAIT_SEC:-5}" -A "$UA" -o "$dest" "$url"; do
      echo "重试中..."
      sleep "${H3_RETRY_WAIT_SEC:-5}"
    done
  fi
  [ -s "$dest" ] || return 1
  touch "$marker"
}

dl "$MS/diffusion_models/minimax_h3_fl2va_pruned_int8_convrot.safetensors" \
  "$MODELS/diffusion_models/minimax_h3_fl2va_pruned_int8_convrot.safetensors"
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
echo "全部模型下载完成"
