FROM nvidia/cuda:12.4.1-runtime-debian11

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1

WORKDIR /app

# Sistem ve Python kurulumu
RUN apt-get update && \
    apt-get install -y python3 python3-pip git && \
    rm -rf /var/lib/apt/lists/*

# pip & wheel güncelle
RUN pip3 install --no-cache-dir --upgrade pip wheel

# PyTorch (CUDA 12.4) ve diğer bağımlılıklar
COPY requirements.txt /app/requirements.txt
RUN pip3 install --no-cache-dir \
    --index-url https://download.pytorch.org/whl/cu124 \
    torch>=2.5.1 torchvision>=0.20.1 && \
    pip3 install --no-cache-dir -r /app/requirements.txt

# Uygulama kodunu kopyala
COPY inference.py /app/inference.py

# Entry point
ENTRYPOINT ["python3", "/app/inference.py"]
