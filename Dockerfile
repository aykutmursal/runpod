# Stage 1: Base image with common dependencies
FROM nvidia/cuda:12.4.1-cudnn-runtime-ubuntu22.04 as base

# Prevent prompts during apt installs
ENV DEBIAN_FRONTEND=noninteractive
# Prefer binary wheels
ENV PIP_PREFER_BINARY=1
# Disable Python output buffering
ENV PYTHONUNBUFFERED=1
# Speed up some cmake builds
ENV CMAKE_BUILD_PARALLEL_LEVEL=8

# Install system dependencies
RUN apt-get update && \
    apt-get install -y \
        python3 python3-pip python3-distutils python3-dev \
        build-essential git wget \
        libgl1 libglib2.0-0 libsm6 libxrender1 \
        google-perftools \
    && ln -sf /usr/bin/python3 /usr/bin/python \
    && ln -sf /usr/bin/pip3 /usr/bin/pip \
    && rm -rf /var/lib/apt/lists/*

# Install CLI and ComfyUI
RUN python3 -m pip install --no-cache-dir comfy-cli==1.3.8 runpod requests && \
    /usr/bin/yes | comfy --workspace /comfyui install \
          --cuda-version 12.4 \
          --nvidia

# Copy helper configs and scripts
ADD src/extra_model_paths.yaml ./
WORKDIR /
ADD src/start.sh src/restore_snapshot.sh src/rp_handler.py test_input.json ./
RUN chmod +x /start.sh /restore_snapshot.sh
ADD *snapshot*.json /
RUN /restore_snapshot.sh

# Default command
CMD ["/start.sh"]

# Stage 2: Download models (select via MODEL_TYPE)
FROM base as downloader

ARG MODEL_TYPE
WORKDIR /comfyui
RUN mkdir -p models/diffusion_models models/text_encoders models/vae && \
    if [ "$MODEL_TYPE" = "fast-fp8" ]; then \
      wget -O models/diffusion_models/hidream_i1_fast_fp8.safetensors \
        "https://huggingface.co/Comfy-Org/HiDream-I1_ComfyUI/resolve/main/split_files/diffusion_models/hidream_i1_fast_fp8.safetensors"; \
    elif [ "$MODEL_TYPE" = "fast-bf16" ]; then \
      wget -O models/diffusion_models/hidream_i1_fast_bf16.safetensors \
        "https://huggingface.co/Comfy-Org/HiDream-I1_ComfyUI/resolve/main/split_files/diffusion_models/hidream_i1_fast_bf16.safetensors"; \
    elif [ "$MODEL_TYPE" = "dev-fp8" ]; then \
      wget -O models/diffusion_models/hidream_i1_dev_fp8.safetensors \
        "https://huggingface.co/Comfy-Org/HiDream-I1_ComfyUI/resolve/main/split_files/diffusion_models/hidream_i1_dev_fp8.safetensors"; \
    elif [ "$MODEL_TYPE" = "dev-bf16" ]; then \
      wget -O models/diffusion_models/hidream_i1_dev_bf16.safetensors \
        "https://huggingface.co/Comfy-Org/HiDream-I1_ComfyUI/resolve/main/split_files/diffusion_models/hidream_i1_dev_bf16.safetensors"; \
    else \
      echo "Unknown MODEL_TYPE: $MODEL_TYPE" && exit 1; \
    fi && \
    wget -O models/text_encoders/clip_l_hidream.safetensors \
      "https://huggingface.co/Comfy-Org/HiDream-I1_ComfyUI/resolve/main/split_files/text_encoders/clip_l_hidream.safetensors" && \
    wget -O models/text_encoders/clip_g_hidream.safetensors \
      "https://huggingface.co/Comfy-Org/HiDream-I1_ComfyUI/resolve/main/split_files/text_encoders/clip_g_hidream.safetensors" && \
    wget -O models/text_encoders/t5xxl_fp8_e4m3fn_scaled.safetensors \
      "https://huggingface.co/Comfy-Org/HiDream-I1_ComfyUI/resolve/main/split_files/text_encoders/t5xxl_fp8_e4m3fn_scaled.safetensors" && \
    wget -O models/text_encoders/llama_3.1_8b_instruct_fp8_scaled.safetensors \
      "https://huggingface.co/Comfy-Org/HiDream-I1_ComfyUI/resolve/main/split_files/text_encoders/llama_3.1_8b_instruct_fp8_scaled.safetensors" && \
    wget -O models/vae/ae.safetensors \
      "https://huggingface.co/Comfy-Org/HiDream-I1_ComfyUI/resolve/main/split_files/vae/ae.safetensors"

# Stage 3: Final image
FROM base as final
COPY --from=downloader /comfyui/models /comfyui/models
CMD ["/start.sh"]
