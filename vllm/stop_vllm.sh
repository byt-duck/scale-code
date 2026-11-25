#!/usr/bin/env bash
set -euo pipefail

CONTAINER_NAME="nemotron-vllm"

if ! docker container inspect "$CONTAINER_NAME" >/dev/null 2>&1; then
    echo "Container $CONTAINER_NAME does not exist."
    exit 0
fi

docker rm --force "$CONTAINER_NAME"
echo "Stopped and removed $CONTAINER_NAME. The image, model, and compilation cache remain available."
