# Base image: RunPod'un PyTorch+CUDA şablonu (torch zaten kurulu)
FROM runpod/pytorch:2.4.0-py3.11-cuda12.4.1-devel-ubuntu22.04

ENV PYTHONUNBUFFERED=1
WORKDIR /app

# 1) Yalnızca ihtiyaç duyduğunuz kütüphaneleri yükleyin
COPY requirements.txt /app/
RUN pip install --no-cache-dir -r requirements.txt

# 2) Uygulama kodunu kopyalayın
COPY inference.py /app/

# 3) Çalıştırma noktası
ENTRYPOINT ["python3", "inference.py"]