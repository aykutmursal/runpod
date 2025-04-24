########################  Stage 0: base  ########################
FROM nvidia/cuda:12.4.1-cudnn-runtime-ubuntu22.04 AS base

ENV DEBIAN_FRONTEND=noninteractive \
    PIP_PREFER_BINARY=1 \
    PYTHONUNBUFFERED=1 \
    CMAKE_BUILD_PARALLEL_LEVEL=8

# ---------- System deps ----------
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        python3 python3-pip python3-distutils python3-dev \
        build-essential git wget libgl1 libglib2.0-0 libsm6 libxrender1 \
        google-perftools && \
    ln -sf /usr/bin/python3 /usr/bin/python && \
    ln -sf /usr/bin/pip3 /usr/bin/pip && \
    rm -rf /var/lib/apt/lists/*

# ---------- ComfyUI CLI ----------
RUN python3 -m pip install --no-cache-dir comfy-cli==1.3.8 runpod requests && \
    yes | comfy --workspace /comfyui install --cuda-version 12.4 --nvidia

# ---------- Helper configs & scripts ----------
ADD src/extra_model_paths.yaml /
WORKDIR /
ADD src/start.sh src/restore_snapshot.sh src/rp_handler.py test_input.json /
RUN chmod +x /start.sh /restore_snapshot.sh

# ---------- Download required weights (ONLY dev-fp8 + encoders + vae) ----------
RUN --mount=type=cache,target=/tmp/wget-cache \
    mkdir -p /comfyui/models/{diffusion_models,text_encoders,vae} && \
    \
###############################################################################
# Diffusion model (dev-fp8)
###############################################################################
RUN --mount=type=cache,target=/tmp/wget-cache \
    mkdir -p /comfyui/models/diffusion_models && \
    wget --continue --retry-connrefused --waitretry=5 -t 5 \
      -O /comfyui/models/diffusion_models/hidream_i1_dev_fp8.safetensors \
      "https://huggingface.co/Comfy-Org/HiDream-I1_ComfyUI/resolve/main/split_files/diffusion_models/hidream_i1_dev_fp8.safetensors"

###############################################################################
# Text encoders
###############################################################################
RUN --mount=type=cache,target=/tmp/wget-cache \
    mkdir -p /comfyui/models/text_encoders && \
    wget --continue --retry-connrefused --waitretry=5 -t 5 \
      -O /comfyui/models/text_encoders/clip_l_hidream.safetensors \
      "https://huggingface.co/Comfy-Org/HiDream-I1_ComfyUI/resolve/main/split_files/text_encoders/clip_l_hidream.safetensors" && \
    wget --continue --retry-connrefused --waitretry=5 -t 5 \
      -O /comfyui/models/text_encoders/clip_g_hidream.safetensors \
      "https://huggingface.co/Comfy-Org/HiDream-I1_ComfyUI/resolve/main/split_files/text_encoders/clip_g_hidream.safetensors" && \
    wget --continue --retry-connrefused --waitretry=5 -t 5 \
      -O /comfyui/models/text_encoders/t5xxl_fp8_e4m3fn_scaled.safetensors \
      "https://huggingface.co/Comfy-Org/HiDream-I1_ComfyUI/resolve/main/split_files/text_encoders/t5xxl_fp8_e4m3fn_scaled.safetensors" && \
    wget --continue --retry-connrefused --waitretry=5 -t 5 \
      -O /comfyui/models/text_encoders/llama_3.1_8b_instruct_fp8_scaled.safetensors \
      "https://huggingface.co/Comfy-Org/HiDream-I1_ComfyUI/resolve/main/split_files/text_encoders/llama_3.1_8b_instruct_fp8_scaled.safetensors"

###############################################################################
# VAE
###############################################################################
RUN --mount=type=cache,target=/tmp/wget-cache \
    mkdir -p /comfyui/models/vae && \
    wget --continue --retry-connrefused --waitretry=5 -t 5 \
      -O /comfyui/models/vae/ae.safetensors \
      "https://huggingface.co/Comfy-Org/HiDream-I1_ComfyUI/resolve/main/split_files/vae/ae.safetensors"

# ---------- Default model type ----------
ENV MODEL_TYPE=dev-fp8   
# build-time default

########################  Stage 1: final  ########################
FROM base AS final
CMD ["/start.sh"]
