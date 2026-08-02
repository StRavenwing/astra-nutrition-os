FROM node:22-bookworm-slim AS ui-build

WORKDIR /app/ui
COPY ui/package*.json ./
RUN npm ci
COPY ui ./
RUN npm run build

FROM python:3.13-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    ASTRA_HOST=0.0.0.0 \
    ASTRA_PORT=8787 \
    ASTRA_DB_PATH=.data/Astra_Nutrition_OS_v7.sqlite \
    ASTRA_BACKUP_DIR=.data/backups

WORKDIR /app

RUN groupadd --system astra \
    && useradd --system --gid astra --home-dir /app astra \
    && mkdir -p /app/.data \
    && chown astra:astra /app/.data

COPY --chown=astra:astra . .
COPY --from=ui-build --chown=astra:astra /app/ui/dist /app/ui/dist

USER astra
VOLUME ["/app/.data"]
EXPOSE 8787

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8787/api/health', timeout=3)" || exit 1

CMD ["python", "server.py"]
