FROM python:3.10-slim

# 必要なミドルウェアのインストール
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

# 👇【ここを追加！】この行以降のキャッシュを強制的にゴミ箱へポイします
ENV REBUILD_MARK=2026_06_26_v1

COPY entrypoint.sh .
RUN chmod +x entrypoint.sh

ENTRYPOINT ["./entrypoint.sh"]