#!/usr/bin/env bash
set -euo pipefail

HARNESS_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd -- "$HARNESS_DIR/.." && pwd)"
VLLM_DIR="$PROJECT_DIR/vllm"

export DOTENV_PATH="$VLLM_DIR/.env.vllm"
exec "$PROJECT_DIR/.venv/bin/python" "$HARNESS_DIR/agent_loop.py"
