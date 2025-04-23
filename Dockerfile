# -----------------------------
# Tek aşamalı (single-stage) basit yapı
# -----------------------------
FROM nvidia/cuda:12.4.1-runtime-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1

# Python, pip ve sistem bağımlılıkları
RUN apt-get update && \
    apt-get install -y python3 python3-pip git && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

# requirements ve kodu kopyala
COPY requirements.txt /app/requirements.txt
RUN pip3 install --no-cache-dir -r /app/requirements.txt

COPY inference.py /app/inference.py

# (Opsiyonel) model ağırlıklarını da burada kopyalayabilirsiniz
# COPY model_weights/ /app/model_weights/

# Container başlangıç komutu (RunPod handler olarak kalacak)
ENTRYPOINT ["python3", "inference.py"]
CMD ["--prompt", "A sample prompt", "--model_type", "full", "--resolution", "1024 × 1024 (Square)", "--seed", "-1", "--output", "/app/output.png"]
