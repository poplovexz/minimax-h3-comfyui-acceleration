#!/bin/bash
set -u

IMAGE_ROOT="${H3_IMAGE_ROOT:-/opt/minimax-h3-comfyui-acceleration}"
DEPLOY_DIR="$IMAGE_ROOT/deploy"

mkdir -p "${H3_WORKSPACE_ROOT:-/workspace}"
for _ in $(seq 1 "${H3_SSH_WAIT_SEC:-30}"); do
  [ -f "${H3_SSH_DIR:-/workspace/ssh}/authorized_keys" ] && break
  sleep 1
done

bash "$DEPLOY_DIR/enable_ssh.sh" || echo "[h3] SSH key not available; continuing without sshd"
bash "$DEPLOY_DIR/setup_instance.sh"
bash "$DEPLOY_DIR/start_comfyui.sh"

if [ "${H3_START_JUPYTER:-1}" = "1" ]; then
  JUPYTER_ARGS=( \
    --ip=0.0.0.0 \
    --port="${JUPYTER_PORT:-8888}" \
    --allow-root \
    --no-browser \
    --ServerApp.root_dir="${JUPYTER_ROOT_DIR:-/workspace}"
  )
  if [ -n "${JUPYTER_TOKEN:-}" ]; then
    JUPYTER_ARGS+=("--ServerApp.token=$JUPYTER_TOKEN")
  fi
  exec python3 -m jupyter lab "${JUPYTER_ARGS[@]}"
fi

exec "$@"
