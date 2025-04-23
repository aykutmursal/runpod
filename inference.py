import os
import sys
import json
import argparse
import torch

from hi_diffusers import HiDreamImagePipeline, HiDreamImageTransformer2DModel
from hi_diffusers.schedulers.fm_solvers_unipc import FlowUniPCMultistepScheduler
from hi_diffusers.schedulers.flash_flow_match import FlashFlowMatchEulerDiscreteScheduler
from transformers import LlamaForCausalLM, PreTrainedTokenizerFast

# --- Model ve çözünürlük ayarları ---
MODEL_PREFIX = "HiDream-ai"
LLAMA_MODEL_NAME = "meta-llama/Meta-Llama-3.1-8B-Instruct"

MODEL_CONFIGS = {
    "dev": {
        "path": f"{MODEL_PREFIX}/HiDream-I1-Dev",
        "guidance_scale": 0.0,
        "num_inference_steps": 28,
        "shift": 6.0,
        "scheduler": FlashFlowMatchEulerDiscreteScheduler
    },
    "full": {
        "path": f"{MODEL_PREFIX}/HiDream-I1-Full",
        "guidance_scale": 5.0,
        "num_inference_steps": 50,
        "shift": 3.0,
        "scheduler": FlowUniPCMultistepScheduler
    },
    "fast": {
        "path": f"{MODEL_PREFIX}/HiDream-I1-Fast",
        "guidance_scale": 0.0,
        "num_inference_steps": 16,
        "shift": 3.0,
        "scheduler": FlashFlowMatchEulerDiscreteScheduler
    }
}

RESOLUTION_OPTIONS = [
    "1024 × 1024 (Square)",
    "768 × 1360 (Portrait)",
    "1360 × 768 (Landscape)",
    "880 × 1168 (Portrait)",
    "1168 × 880 (Landscape)",
    "1248 × 832 (Landscape)",
    "832 × 1248 (Portrait)"
]

# --- Yardımcı fonksiyonlar ---
def load_models(model_type: str):
    """Model ve tokenizer/text-encoder yüklemesini yapar."""
    cfg = MODEL_CONFIGS[model_type]
    scheduler = cfg["scheduler"](
        num_train_timesteps=1000,
        shift=cfg["shift"],
        use_dynamic_shifting=False
    )
    # Llama için tokenizer & model
    tokenizer = PreTrainedTokenizerFast.from_pretrained(LLAMA_MODEL_NAME, use_fast=False)
    text_encoder = LlamaForCausalLM.from_pretrained(
        LLAMA_MODEL_NAME,
        output_hidden_states=True,
        output_attentions=True,
        torch_dtype=torch.bfloat16
    ).to("cuda")

    # Transformer ve pipeline
    transformer = HiDreamImageTransformer2DModel.from_pretrained(
        cfg["path"],
        subfolder="transformer",
        torch_dtype=torch.bfloat16
    ).to("cuda")

    pipe = HiDreamImagePipeline.from_pretrained(
        cfg["path"],
        scheduler=scheduler,
        tokenizer_4=tokenizer,
        text_encoder_4=text_encoder,
        torch_dtype=torch.bfloat16
    ).to("cuda", torch.bfloat16)
    pipe.transformer = transformer

    return pipe, cfg

def parse_resolution(res: str):
    """Çözünürlük seçeneğinden (string) (height, width) döner."""
    mapping = {
        "1024 × 1024": (1024, 1024),
        "768 × 1360": (768, 1360),
        "1360 × 768": (1360, 768),
        "880 × 1168": (880, 1168),
        "1168 × 880": (1168, 880),
        "1248 × 832": (1248, 832),
        "832 × 1248": (832, 1248),
    }
    for key, val in mapping.items():
        if key in res:
            return val
    return (1024, 1024)

def generate_image(pipe, cfg, prompt: str, resolution: str, seed: int):
    """Pipeline ile görsel üretir ve (PIL Image, kullanılan_seed) döner."""
    height, width = parse_resolution(resolution)
    if seed == -1:
        seed = torch.randint(0, 1_000_000, (1,)).item()
    gen = torch.Generator("cuda").manual_seed(seed)

    imgs = pipe(
        prompt,
        height=height,
        width=width,
        guidance_scale=cfg["guidance_scale"],
        num_inference_steps=cfg["num_inference_steps"],
        num_images_per_prompt=1,
        generator=gen
    ).images
    return imgs[0], seed

# --- Ana fonksiyon ---
def main():
    parser = argparse.ArgumentParser(description="HiDream CLI Inference")
    parser.add_argument("--prompt",     type=str, required=True, help="Üretilecek görselin açıklaması")
    parser.add_argument("--model_type", type=str, default="full", choices=list(MODEL_CONFIGS.keys()),
                        help="Kullanılacak model varyantı")
    parser.add_argument("--resolution", type=str, default=RESOLUTION_OPTIONS[0], choices=RESOLUTION_OPTIONS,
                        help="Görsel çözünürlüğü")
    parser.add_argument("--seed",       type=int, default=-1, help="Rastgelelik tohumu (-1 ise rastgele)")
    parser.add_argument("--output",     type=str, default="/app/output.png", help="Kaydedilecek dosya yolu")
    args = parser.parse_args()

    # 1) Modeli yükle
    print(f"Loading model '{args.model_type}'...", flush=True)
    pipe, cfg = load_models(args.model_type)
    print("Model loaded.", flush=True)

    # 2) Görseli üret
    image, used_seed = generate_image(pipe, cfg, args.prompt, args.resolution, args.seed)

    # 3) Kaydet
    os.makedirs(os.path.dirname(args.output), exist_ok=True)
    image.save(args.output)
    print(f"Image saved to {args.output}", flush=True)

    # 4) JSON çıktısı
    result = {
        "output_path": args.output,
        "seed": used_seed
    }
    print(json.dumps(result), flush=True)

if __name__ == "__main__":
    main()
