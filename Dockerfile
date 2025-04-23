################################################################################
# 1) Builder aşaması: bağımlılıkları yükle ve kodu derle
################################################################################
FROM nvidia/cuda:12.4.1-runtime-ubuntu22.04 AS builder

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1

RUN apt-get update && \
    apt-get install -y python3 python3-pip git && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

# pip ve wheel güncelle
RUN pip3 install --no-cache-dir --upgrade pip wheel

# PyTorch + torchvision (CUDA 12.4) yükle
RUN pip3 install --no-cache-dir \
    --index-url https://download.pytorch.org/whl/cu124 \
    torch>=2.5.1 torchvision>=0.20.1

# Geri kalan bağımlılıklar
COPY requirements.txt /app/requirements.txt
RUN pip3 install --no-cache-dir -r /app/requirements.txt

# Kodumuzu kopyala
COPY inference.py /app/inference.py

################################################################################
# 2) Final aşaması: Distroless ile minimal runtime
################################################################################
FROM gcr.io/distroless/python3-debian11

# Python yorumlayıcısı
COPY --from=builder /usr/bin/python3 /usr/bin/python3

# Kurulu Python paketleri
COPY --from=builder /usr/local/lib/python3.*/ /usr/local/lib/python3.*/

# CUDA runtime kütüphaneleri (cuDNN, cuBLAS vb.)  
COPY --from=builder /usr/local/cuda/lib64 /usr/local/cuda/lib64  
COPY --from=builder /usr/lib/x86_64-linux-gnu/libcudart.so.* /usr/lib/x86_64-linux-gnu/  
COPY --from=builder /usr/lib/x86_64-linux-gnu/libcudnn.so.* /usr/lib/x86_64-linux-gnu/  

# Uygulama kodu
COPY --from=builder /app /app
WORKDIR /app

# CUDA runtime dizinini tanıt
ENV LD_LIBRARY_PATH=/usr/local/cuda/lib64:/usr/lib/x86_64-linux-gnu

# Entry point olarak inference.py
ENTRYPOINT ["python3","inference.py"]
