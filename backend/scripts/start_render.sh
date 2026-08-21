#!/bin/sh
set -eu

echo "[snakecare] Applying database migrations"
alembic upgrade head

echo "[snakecare] Loading review/demo data"
python scripts/seed_review_data.py

echo "[snakecare] Starting API on 0.0.0.0:${PORT:-10000}"
exec uvicorn app.main:app \
  --host 0.0.0.0 \
  --port "${PORT:-10000}" \
  --proxy-headers
