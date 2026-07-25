#!/bin/bash
set -e

echo "🚀 Starting AIBA POS service..."

# Schemas are created idempotently on app/worker startup
# (Tortoise generate_schemas safe=True). Aerich config is present in
# pyproject.toml so migrations can take over later without code changes.

if [ $# -gt 0 ]; then
    echo "📡 Custom command: $@"
    exec "$@"
else
    echo "📡 Starting Uvicorn on :8000"
    exec python -m uvicorn main:app --host 0.0.0.0 --port 8000 --workers 1
fi
