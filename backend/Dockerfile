FROM python:3.11-slim AS builder
WORKDIR /build
COPY backend/pyproject.toml ./
COPY backend/app ./app
RUN pip wheel --no-cache-dir --wheel-dir /wheels .

FROM python:3.11-slim AS runtime
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1
RUN apt-get update && apt-get install --no-install-recommends -y tesseract-ocr && rm -rf /var/lib/apt/lists/*
RUN addgroup --system snakecare && adduser --system --ingroup snakecare snakecare
RUN mkdir -p /var/lib/snakecare/reports /var/lib/snakecare/snakebite-photos && chown -R snakecare:snakecare /var/lib/snakecare
WORKDIR /app
COPY --from=builder /wheels /wheels
RUN pip install --no-cache-dir /wheels/* && rm -rf /wheels
COPY backend/alembic.ini ./alembic.ini
COPY backend/alembic ./alembic
COPY backend/scripts ./scripts
USER snakecare
EXPOSE 10000
CMD ["sh", "scripts/start_render.sh"]
