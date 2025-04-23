# Base image: RunPod'un PyTorch+CUDA şablonu
FROM runpod/pytorch:2.4.0-py3.11-cuda12.4.1-devel-ubuntu22.04

ENV PYTHONUNBUFFERED=1
WORKDIR /app

# Temel gereksinimleri yükleyin
COPY requirements.txt /app/
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir diffusers>=0.32.1 transformers>=4.47.1 einops>=0.8.1 accelerate>=1.6.0 Pillow>=9.0.0

# HiDream-I1 reposunu klonlayın ve kurun
RUN git clone https://github.com/HiDream-ai/HiDream-I1.git /app/HiDream-I1 && \
    cd /app/HiDream-I1 && \
    pip install -e .

# Uygulama kodunu kopyalayın
COPY inference.py /app/

# Çalıştırma noktası
ENTRYPOINT ["python3", "inference.py"]