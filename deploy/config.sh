#!/bin/bash
set -u

H3_WORKSPACE_ROOT="${H3_WORKSPACE_ROOT:-/workspace}"
H3_COMFYUI_DIR="${H3_COMFYUI_DIR:-$H3_WORKSPACE_ROOT/ComfyUI}"
H3_ACCEL_DIR="${H3_ACCEL_DIR:-$H3_WORKSPACE_ROOT/minimax-h3-comfyui-acceleration}"
H3_MODELS_DIR="${H3_MODELS_DIR:-/root/h3_models}"
H3_SSH_DIR="${H3_SSH_DIR:-$H3_WORKSPACE_ROOT/ssh}"
H3_LOG_DIR="${H3_LOG_DIR:-$H3_WORKSPACE_ROOT/h3-runtime/logs}"
H3_RUNTIME_DIR="${H3_RUNTIME_DIR:-$H3_WORKSPACE_ROOT/h3-runtime/run}"
H3_STATUS_FILE="${H3_STATUS_FILE:-$H3_RUNTIME_DIR/status.env}"
H3_COMFYUI_PORT="${H3_COMFYUI_PORT:-8188}"
H3_CORE_MODELS_MIN_FREE_GB="${H3_CORE_MODELS_MIN_FREE_GB:-48}"
H3_COMFYUI_REPO_URL="${H3_COMFYUI_REPO_URL:-https://github.com/comfyanonymous/ComfyUI.git}"
H3_COMFYUI_PROXY_URL="${H3_COMFYUI_PROXY_URL:-https://gh-proxy.com/https://github.com/comfyanonymous/ComfyUI.git}"
H3_COMFYUI_MIRROR_URL="${H3_COMFYUI_MIRROR_URL:-https://gitee.com/mirrors/ComfyUI.git}"
H3_MODEL_BASE_URL="${H3_MODEL_BASE_URL:-https://modelscope.cn/models/Comfy-Org/MiniMax-H3/resolve/master}"
H3_TURBO_BASE_URL="${H3_TURBO_BASE_URL:-https://modelscope.cn/models/larryvrh/MiniMax-H3-Turbo-Lora/resolve/master}"
H3_PYTHON="${H3_PYTHON:-/opt/venv/bin/python}"
H3_REPO_URL="${H3_REPO_URL:-https://github.com/poplovexz/minimax-h3-comfyui-acceleration.git}"
H3_GIT_PROXY_URL="${H3_GIT_PROXY_URL:-https://gh-proxy.com/https://github.com/poplovexz/minimax-h3-comfyui-acceleration.git}"

if [ ! -x "$H3_PYTHON" ]; then
  H3_PYTHON="${H3_PYTHON_FALLBACK:-python3}"
fi

H3_RESOLVED_ENV="${H3_RESOLVED_ENV:-$H3_RUNTIME_DIR/resolved.env}"
if [ -f "$H3_RESOLVED_ENV" ]; then
  source "$H3_RESOLVED_ENV"
fi

export H3_WORKSPACE_ROOT H3_COMFYUI_DIR H3_ACCEL_DIR H3_MODELS_DIR H3_SSH_DIR
export H3_LOG_DIR H3_RUNTIME_DIR H3_STATUS_FILE H3_COMFYUI_PORT H3_MODEL_BASE_URL
export H3_TURBO_BASE_URL H3_PYTHON H3_CORE_MODELS_MIN_FREE_GB
export H3_REPO_URL H3_GIT_PROXY_URL H3_RESOLVED_ENV
export H3_COMFYUI_REPO_URL H3_COMFYUI_PROXY_URL H3_COMFYUI_MIRROR_URL
