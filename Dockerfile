FROM python:3.13-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    ASTRA_HOST=0.0.0.0 \
    ASTRA_PORT=8787 \
    ASTRA_DB_PATH=/data/Astra_Nutrition_OS_v7.sqlite \
    ASTRA_BACKUP_DIR=/data/backups

WORKDIR /app

RUN groupadd --system astra \
    && useradd --system --gid astra --home-dir /app astra \
    && mkdir -p /data \
    && chown astra:astra /data

COPY --chown=astra:astra . .

USER astra
VOLUME ["/data"]
EXPOSE 8787

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8787/api/health', timeout=3)" || exit 1

CMD ["python", "server.py"]

