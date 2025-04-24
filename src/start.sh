#!/usr/bin/env bash
set -e

###############################################################################
# 1)  MODEL URL HARİTASI – istediğin ek modeli buraya ekleyebilirsin
###############################################################################
declare -A MODEL_URLS=(
  [fast-fp8]="https://huggingface.co/Comfy-Org/HiDream-I1_ComfyUI/resolve/main/split_files/diffusion_models/hidream_i1_fast_fp8.safetensors"
  [fast-bf16]="https://huggingface.co/Comfy-Org/HiDream-I1_ComfyUI/resolve/main/split_files/diffusion_models/hidream_i1_fast_bf16.safetensors"
  [dev-fp8]="https://huggingface.co/Comfy-Org/HiDream-I1_ComfyUI/resolve/main/split_files/diffusion_models/hidream_i1_dev_fp8.safetensors"
  [dev-bf16]="https://huggingface.co/Comfy-Org/HiDream-I1_ComfyUI/resolve/main/split_files/diffusion_models/hidream_i1_dev_bf16.safetensors"
)

###############################################################################
# 2)  MODELİ İNDİR – eğer dosya yoksa
###############################################################################
MODEL_TYPE="${MODEL_TYPE:-fast-fp8}"
MODEL_DIR="/comfyui/models/diffusion_models"
MODEL_FILE="${MODEL_DIR}/hidream_${MODEL_TYPE}.safetensors"

echo "Selected MODEL_TYPE=${MODEL_TYPE}"
mkdir -p "$MODEL_DIR"

if [[ -f "$MODEL_FILE" ]]; then
  echo "Model already exists: $(du -h "$MODEL_FILE")"
else
  echo "Downloading model ..."
  wget -q --show-progress -O "$MODEL_FILE" "${MODEL_URLS[$MODEL_TYPE]}"
  echo "Download complete."
fi

###############################################################################
# 3)  VAR OLAN BAŞLATMA KOMUTLARI (ComfyUI + RunPod handler)
###############################################################################
# Use libtcmalloc for better memory management
TCMALLOC="$(ldconfig -p | grep -Po 'libtcmalloc.so.\d' | head -n 1 || true)"
[[ -n "$TCMALLOC" ]] && export LD_PRELOAD="${TCMALLOC}"

if [[ "$SERVE_API_LOCALLY" == "true" ]]; then
  echo "Starting ComfyUI (local API mode)"
  python3 /comfyui/main.py --disable-auto-launch --disable-metadata --listen &
  echo "Starting RunPod Handler (local API)"
  python3 -u /rp_handler.py --rp_serve_api --rp_api_host=0.0.0.0
else
  echo "Starting ComfyUI"
  python3 /comfyui/main.py --disable-auto-launch --disable-metadata &
  echo "Starting RunPod Handler"
  python3 -u /rp_handler.py
fi
