# Build context: nanobot root (..)
# Extends the nanobot base image with mx-skill Python dependencies

ARG NPM_REGISTRY=https://registry.npmmirror.com
ARG PY_INDEX=https://pypi.tuna.tsinghua.edu.cn/simple
ARG NODE_IMAGE=node:20-slim
ARG UV_IMAGE=ghcr.io/astral-sh/uv:python3.12-bookworm-slim

# ---- Stage 1: WebUI build ----
FROM ${NODE_IMAGE} AS webui-builder
ARG NPM_REGISTRY
WORKDIR /app
COPY webui/ webui/
RUN cd webui && npm ci --registry=${NPM_REGISTRY} && npm run build

# ---- Stage 2: nanobot + mx-skill runtime ----
FROM ${UV_IMAGE}
RUN apt-get update && \
    apt-get install -y --no-install-recommends curl ca-certificates git bubblewrap openssh-client && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app
ARG PY_INDEX

COPY pyproject.toml README.md LICENSE THIRD_PARTY_NOTICES.md hatch_build.py ./
RUN mkdir -p bridge nanobot/web/dist && touch nanobot/__init__.py && \
    NANOBOT_SKIP_WEBUI_BUILD=1 uv pip install --system --no-cache --index-url ${PY_INDEX} . && \
    rm -rf nanobot bridge

COPY nanobot/ nanobot/
COPY --from=webui-builder /app/nanobot/web/dist/ nanobot/web/dist/
RUN mkdir -p bridge
RUN uv pip install --system --no-cache --index-url ${PY_INDEX} .

# mx-skill 额外依赖（mx-data 需要 pandas/openpyxl）
RUN uv pip install --system --no-cache --index-url ${PY_INDEX} pandas requests openpyxl

RUN useradd -m -u 1000 -s /bin/bash nanobot && \
    mkdir -p /home/nanobot/.nanobot /stock-bot/workspace && \
    chown -R nanobot:nanobot /home/nanobot /app /stock-bot

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN sed -i 's/\r$//' /usr/local/bin/entrypoint.sh && chmod +x /usr/local/bin/entrypoint.sh

USER nanobot
ENV HOME=/home/nanobot

EXPOSE 18791 8766

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["gateway", "--config", "/stock-bot/config.json"]
