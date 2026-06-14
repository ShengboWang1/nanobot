# ---- Build args for local development with domestic mirrors ----
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
# output lands at /app/nanobot/web/dist (vite outDir: ../nanobot/web/dist)


# ---- Stage 2: Python runtime ----
FROM ${UV_IMAGE}

RUN apt-get update && \
    apt-get install -y --no-install-recommends curl ca-certificates git bubblewrap openssh-client && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

ARG PY_INDEX
# Install Python dependencies first for layer caching.
# bridge/ and webui/ are absent at this point; stub them out so hatch
# force-include and the webui build hook don't fail.
COPY pyproject.toml README.md LICENSE THIRD_PARTY_NOTICES.md hatch_build.py ./
RUN mkdir -p bridge nanobot/web/dist && touch nanobot/__init__.py && \
    NANOBOT_SKIP_WEBUI_BUILD=1 uv pip install --system --no-cache --index-url ${PY_INDEX} . && \
    rm -rf nanobot bridge

# Copy Python source
COPY nanobot/ nanobot/

# Copy pre-built WebUI from Stage 1 (index.html present → hatch skips rebuild)
COPY --from=webui-builder /app/nanobot/web/dist/ nanobot/web/dist/

# bridge/ was removed in the dep-cache layer; recreate empty stub so hatch
# force-include doesn't error (we don't ship the WhatsApp bridge)
RUN mkdir -p bridge

# Final install picks up the actual Python source; webui already built so skips
RUN uv pip install --system --no-cache --index-url ${PY_INDEX} .

# Create non-root user
RUN useradd -m -u 1000 -s /bin/bash nanobot && \
    mkdir -p /home/nanobot/.nanobot && \
    chown -R nanobot:nanobot /home/nanobot /app

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN sed -i 's/\r$//' /usr/local/bin/entrypoint.sh && chmod +x /usr/local/bin/entrypoint.sh

USER nanobot
ENV HOME=/home/nanobot

# 18790: gateway HTTP (health + API)
# 8765:  WebUI / WebSocket channel
# 8900:  OpenAI-compatible API server
EXPOSE 18790 8765 8900

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["status"]
