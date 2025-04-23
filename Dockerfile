# -----------------------------
# 1. Build aşaması: bağımlılıkları yükle
# -----------------------------
FROM nvidia/cuda:12.4.1-runtime-ubuntu22.04 AS builder

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1

RUN apt-get update && \
    apt-get install -y python3 python3-pip git && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

# requirements ve kodu kopyala
COPY requirements.txt /app/requirements.txt
RUN pip3 install --no-cache-dir -r /app/requirements.txt

COPY inference.py /app/inference.py

# -----------------------------
# 2. Final aşaması: minimal runtime
# -----------------------------
FROM nvidia/cuda:12.4.1-runtime-ubuntu22.04

ENV PYTHONUNBUFFERED=1

WORKDIR /app

# Builder aşamasından Python ve kurulu paketleri al
COPY --from=builder /usr/local/lib/python3.*/ /usr/local/lib/python3.*/
COPY --from=builder /usr/bin/python3 /usr/bin/python3
COPY --from=builder /usr/lib/x86_64-linux-gnu/ /usr/lib/x86_64-linux-gnu/

# Uygulama kodunu kopyala
COPY --from=builder /app /app

# Port ayarı (gerekiyorsa)
# EXPOSE 8080

# Container başlangıç komutu
CMD ["python3", "inference.py", \
     "--prompt", "A sample prompt", \
     "--model_type", "full", \
     "--resolution", "1024 × 1024 (Square)", \
     "--seed", "-1", \
     "--output", "/app/output.png"]
