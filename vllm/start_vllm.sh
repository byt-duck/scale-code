#!/usr/bin/env bash
set -euo pipefail

CONTAINER_NAME="nemotron-vllm"
IMAGE="vllm/vllm-openai:v0.30.0"
MODEL_DIR="/mnt/scratch/ckpt/NVIDIA-Nemotron-3-Nano-30B-A3B-BF16"
GPU_ID="${VLLM_GPU_ID:-0}"
HOST_PORT="${VLLM_PORT:-8000}"

if docker container inspect "$CONTAINER_NAME" >/dev/null 2>&1; then
    echo "Container $CONTAINER_NAME already exists. Run ./stop_vllm.sh before recreating it."
    exit 1
fi

docker run --detach \
    --name "$CONTAINER_NAME" \
    --restart unless-stopped \
    --gpus "device=$GPU_ID" \
    --ipc host \
    --publish "127.0.0.1:$HOST_PORT:8000" \
    --volume "$MODEL_DIR:/model:ro" \
    --volume nemotron-vllm-cache:/root/.cache/vllm \
    --env VLLM_ENABLE_CUDA_COMPATIBILITY=1 \
    "$IMAGE" \
    /model \
    --served-model-name model \
    --host 0.0.0.0 \
    --port 8000 \
    --tensor-parallel-size 1 \
    --max-model-len 32768 \
    --max-num-seqs 1 \
    --gpu-memory-utilization 0.90 \
    --trust-remote-code \
    --enable-auto-tool-choice \
    --tool-call-parser qwen3_coder \
    --reasoning-parser-plugin /model/nano_v3_reasoning_parser.py \
    --reasoning-parser nano_v3

echo "Started $CONTAINER_NAME on GPU $GPU_ID."
echo "Follow startup with: docker logs --follow $CONTAINER_NAME"
echo "The local API will be available at http://127.0.0.1:$HOST_PORT"
