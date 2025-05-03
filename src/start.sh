#!/usr/bin/env bash
set -e

###############################################################################
# 1)   MODELE ÖN-KOŞUL KONTROLÜ
###############################################################################
MODEL_PATHS=(
  "/comfyui/models/diffusion_models/fluxFillFP8_v10.safetensors"
  "/comfyui/models/checkpoints/flux1-dev-fp8.safetensors"
)

# Check if at least one of the models exists
MODEL_FOUND=false
for MODEL_PATH in "${MODEL_PATHS[@]}"; do
  if [[ -f "$MODEL_PATH" ]]; then
    MODEL_FOUND=true
    echo "✅ Found model: $MODEL_PATH"
  else
    echo "⚠️ Model not found: $MODEL_PATH"
  fi
done

# Exit if no models are found
if [[ "$MODEL_FOUND" != "true" ]]; then
  echo "❌ No valid models found! Docker imajına dahil edilmemiş."
  exit 1
fi

###############################################################################
# 2)   BELLEK OPTİMİZASYONU
###############################################################################
TCMALLOC="$(ldconfig -p | grep -Po 'libtcmalloc.so.\d' | head -n 1 || true)"
[[ -n "$TCMALLOC" ]] && export LD_PRELOAD="$TCMALLOC"

###############################################################################
# 3)   COMFYUI + RUNPOD HANDLER BAŞLAT
###############################################################################
python3 /comfyui/main.py --disable-auto-launch --disable-metadata --listen &
echo "✅ ComfyUI running on :8188"

if [[ "$SERVE_API_LOCALLY" == "true" ]]; then
  echo "🔌 Starting RunPod Handler (local API)"
  python3 -u /rp_handler.py --rp_serve_api --rp_api_host=0.0.0.0
else
  python3 -u /rp_handler.py
fi
