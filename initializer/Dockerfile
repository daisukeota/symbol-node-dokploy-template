FROM python:3.10-slim

# 必要なミドルウェアのインストール（C拡張コンパイル用の build-essential を追加）
RUN apt-get update && apt-get install -y \
    build-essential \
    libssl-dev \
    gettext \
    curl \
    && rm -rf /var/lib/apt/lists/*

# 最新の symbol-shoestring をインストール
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir symbol-shoestring

WORKDIR /app
COPY entrypoint.sh .
RUN chmod +x entrypoint.sh

ENTRYPOINT ["./entrypoint.sh"]