########################  Stage 0: base  ########################
FROM nvidia/cuda:12.4.1-cudnn-runtime-ubuntu22.04 AS base
ENV DEBIAN_FRONTEND=noninteractive \
    PIP_PREFER_BINARY=1 \
    PYTHONUNBUFFERED=1 \
    CMAKE_BUILD_PARALLEL_LEVEL=8
# --- system deps ---
RUN apt-get update && apt-get install -y --no-install-recommends \
      python3 python3-pip python3-distutils python3-dev \
      build-essential git wget libgl1 libglib2.0-0 libsm6 libxrender1 \
      google-perftools && \
    ln -sf /usr/bin/python3 /usr/bin/python && \
    ln -sf /usr/bin/pip3 /usr/bin/pip && \
    rm -rf /var/lib/apt/lists/*
# --- ComfyUI CLI ---
RUN python3 -m pip install --no-cache-dir comfy-cli==1.3.8 runpod requests && \
    yes | comfy --workspace /comfyui install --cuda-version 12.4 --nvidia
# --- helper files ---
ADD src/extra_model_paths.yaml /
WORKDIR /
ADD src/start.sh src/restore_snapshot.sh src/rp_handler.py test_input.json /
RUN chmod +x /start.sh /restore_snapshot.sh

###############################################################################
# Diffusion model (dev_bf16)
###############################################################################
ARG HF_TOKEN
ARG CIVI_TOKEN

# --- Civitai modeli (özellikle önemli olanı önce indirelim) ---
RUN mkdir -p /comfyui/models/diffusion_models /comfyui/models/checkpoints && \
    echo "Downloading fluxFillFP8_v10.safetensors from Civitai..." && \
    curl -L --fail --retry 5 --retry-delay 5 \
      -H "Authorization: Bearer ${CIVI_TOKEN}" \
      -o /comfyui/models/diffusion_models/fluxFillFP8_v10.safetensors \
      "https://civitai.com/api/download/models/1085456?type=Model&format=SafeTensor&size=full&fp=fp8" && \
    [ -f "/comfyui/models/diffusion_models/fluxFillFP8_v10.safetensors" ] && \
    echo "Successfully downloaded fluxFillFP8_v10.safetensors" && \
    echo "Downloading flux1-dev-fp8.safetensors from HuggingFace..." && \
    wget -c --retry-connrefused --waitretry=5 -t 5 \
      --header="Authorization: Bearer ${HF_TOKEN}" \
      -O /comfyui/models/checkpoints/flux1-dev-fp8.safetensors \
      "https://huggingface.co/Comfy-Org/flux1-dev/resolve/main/flux1-dev-fp8.safetensors?download=true" && \
    [ -f "/comfyui/models/checkpoints/flux1-dev-fp8.safetensors" ] && \
    echo "Successfully downloaded flux1-dev-fp8.safetensors"

###############################################################################
# Text encoders
###############################################################################
RUN --mount=type=cache,target=/tmp/wget-cache \
    wget -c --retry-connrefused --waitretry=5 -t 5 \
      --header="Authorization: Bearer ${HF_TOKEN}" \
      -O /comfyui/models/text_encoders/clip_l.safetensors \
      "https://huggingface.co/Comfy-Org/stable-diffusion-3.5-fp8/resolve/main/text_encoders/clip_l.safetensors?download=true" && \
    wget -c --retry-connrefused --waitretry=5 -t 5 \
      --header="Authorization: Bearer ${HF_TOKEN}" \
      -O /comfyui/models/text_encoders/t5xxl_fp8_e4m3fn.safetensors \
      "https://huggingface.co/Comfy-Org/stable-diffusion-3.5-fp8/resolve/main/text_encoders/t5xxl_fp8_e4m3fn.safetensors?download=true"

###############################################################################
# VAE
###############################################################################
RUN --mount=type=cache,target=/tmp/wget-cache \
    mkdir -p /comfyui/models/vae/FLUX1 && \
    wget -c --retry-connrefused --waitretry=5 -t 5 \
      --header="Authorization: Bearer ${HF_TOKEN}" \
      -O /comfyui/models/vae/ae.safetensors \
      "https://huggingface.co/black-forest-labs/FLUX.1-schnell/resolve/main/ae.safetensors?download=true"

###############################################################################
# Custom nodes 
###############################################################################
COPY requirements.txt /requirements.txt
RUN pip install --no-cache-dir -r /requirements.txt

# Clone all custom nodes WITHOUT installing their requirements
RUN mkdir -p /comfyui/custom_nodes && cd /comfyui/custom_nodes && \
    git clone --depth 1 https://github.com/ltdrdata/ComfyUI-Impact-Pack.git && \
    git clone --depth 1 https://github.com/rgthree/rgthree-comfy.git && \
    git clone --depth 1 https://github.com/kijai/ComfyUI-KJNodes.git && \
    git clone --depth 1 https://github.com/kijai/ComfyUI-Florence2.git && \
    git clone --depth 1 https://github.com/cubiq/ComfyUI_essentials.git && \
    git clone --depth 1 https://github.com/welltop-cn/ComfyUI-TeaCache.git && \
    git clone --depth 1 https://github.com/lquesada/ComfyUI-Inpaint-CropAndStitch.git && \
    git clone --depth 1 https://github.com/aria1th/ComfyUI-LogicUtils.git

# Force reinstall of potentially conflicting packages
RUN pip install --no-cache-dir --force-reinstall opencv-python-headless

# ---------- Default model ----------
# build-time default
ENV MODEL_TYPE=dev-fp8

########################  Stage 1: final  ########################
FROM base AS final
CMD ["/start.sh"]
