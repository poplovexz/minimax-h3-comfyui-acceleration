#!/bin/bash
set -u

H3_WORKSPACE_ROOT="${H3_WORKSPACE_ROOT:-/workspace}"
H3_COMFYUI_DIR="${H3_COMFYUI_DIR:-$H3_WORKSPACE_ROOT/ComfyUI}"
H3_ACCEL_DIR="${H3_ACCEL_DIR:-$H3_WORKSPACE_ROOT/minimax-h3-comfyui-acceleration}"
H3_MODELS_DIR="${H3_MODELS_DIR:-/root/h3_models}"
H3_LOG_DIR="${H3_LOG_DIR:-$H3_WORKSPACE_ROOT/h3-runtime/logs}"
H3_RUNTIME_DIR="${H3_RUNTIME_DIR:-$H3_WORKSPACE_ROOT/h3-runtime/run}"
H3_COMFYUI_PORT="${H3_COMFYUI_PORT:-8188}"
H3_PYTHON="${H3_PYTHON:-/opt/venv/bin/python}"
H3_REPO_URL="${H3_REPO_URL:-https://github.com/poplovexz/minimax-h3-comfyui-acceleration.git}"
H3_GIT_PROXY_URL="${H3_GIT_PROXY_URL:-https://gh-proxy.com/https://github.com/poplovexz/minimax-h3-comfyui-acceleration.git}"

if [ ! -x "$H3_PYTHON" ]; then
  H3_PYTHON="${H3_PYTHON_FALLBACK:-python3}"
fi

export H3_WORKSPACE_ROOT H3_COMFYUI_DIR H3_ACCEL_DIR H3_MODELS_DIR
export H3_LOG_DIR H3_RUNTIME_DIR H3_COMFYUI_PORT H3_PYTHON
export H3_REPO_URL H3_GIT_PROXY_URL
