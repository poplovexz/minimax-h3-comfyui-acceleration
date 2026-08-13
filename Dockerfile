# ACR can override BASE_IMAGE when a compatible private base is available.
ARG BASE_IMAGE=rocm/pytorch:rocm7.2.1_ubuntu24.04_py3.12_pytorch_release_2.9.1
FROM ${BASE_IMAGE}

ARG H3_INCLUDE_REF2VA=0
ARG H3_COMFYUI_REPO_URL=https://github.com/comfyanonymous/ComfyUI.git
ARG H3_MODEL_BASE_URL=https://modelscope.cn/models/Comfy-Org/MiniMax-H3/resolve/master
ARG H3_TURBO_BASE_URL=https://modelscope.cn/models/larryvrh/MiniMax-H3-Turbo-Lora/resolve/master
ENV DEBIAN_FRONTEND=noninteractive \
    H3_WORKSPACE_ROOT=/workspace \
    H3_COMFYUI_DIR=/opt/ComfyUI \
    H3_ACCEL_DIR=/opt/minimax-h3-comfyui-acceleration \
    H3_MODELS_DIR=/opt/h3_models \
    H3_SSH_DIR=/workspace/ssh \
    H3_LOG_DIR=/workspace/h3-runtime/logs \
    H3_RUNTIME_DIR=/workspace/h3-runtime/run \
    H3_COMFYUI_PORT=8188 \
    H3_PYTHON=python3 \
    H3_START_JUPYTER=1 \
    H3_IMAGE_ROOT=/opt/minimax-h3-comfyui-acceleration \
    H3_MODEL_BASE_URL=${H3_MODEL_BASE_URL} \
    H3_TURBO_BASE_URL=${H3_TURBO_BASE_URL}

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       aria2 ca-certificates curl git openssh-server tini \
    && rm -rf /var/lib/apt/lists/*

RUN python3 -m pip install --no-cache-dir jupyterlab

WORKDIR /opt
COPY . /opt/minimax-h3-comfyui-acceleration
RUN git clone --depth 1 "$H3_COMFYUI_REPO_URL" /opt/ComfyUI \
    && python3 /opt/minimax-h3-comfyui-acceleration/tools/install_into_comfyui.py \
       --comfyui /opt/ComfyUI --copy --force \
    && grep -Ev '^(torch|torchvision|torchaudio)$' /opt/ComfyUI/requirements.txt \
       > /tmp/comfyui-requirements-rocm.txt \
    && python3 -m pip install --no-cache-dir -r /tmp/comfyui-requirements-rocm.txt \
    && rm -f /tmp/comfyui-requirements-rocm.txt

RUN if [ "$H3_INCLUDE_REF2VA" = "1" ]; then \
      REF2VA=1 bash /opt/minimax-h3-comfyui-acceleration/deploy/download_models_modelscope.sh /opt/h3_models; \
    else \
      bash /opt/minimax-h3-comfyui-acceleration/deploy/download_models_modelscope.sh /opt/h3_models; \
    fi \
    && rm -rf /opt/ComfyUI/models \
    && ln -s /opt/h3_models /opt/ComfyUI/models \
    && mkdir -p /workspace

COPY docker/image-entrypoint.sh /usr/local/bin/h3-image-entrypoint
RUN chmod 755 /usr/local/bin/h3-image-entrypoint \
    && mkdir -p /run/sshd /workspace/ssh /workspace/h3-runtime/logs /workspace/h3-runtime/run

EXPOSE 22 8188 8888
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/h3-image-entrypoint"]
CMD ["bash"]
