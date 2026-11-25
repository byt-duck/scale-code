# scale-code

A minimal coding-agent harness backed by NVIDIA Nemotron 3 Nano and served locally with vLLM's Anthropic-compatible Messages API.

## Layout

```text
scale-code/
├── harness/
│   ├── agent_loop.py
│   └── chat_with_nemotron.sh
├── vllm/
│   ├── .env.vllm
│   ├── start_vllm.sh
│   ├── stop_vllm.sh
│   ├── smoke_test_vllm.py
│   └── VLLM_SETUP_LOG.md
└── requirements.txt
```

The model checkpoint and Python virtual environment are intentionally not stored in Git.

## Prerequisites

- Linux with Docker and the NVIDIA Container Toolkit
- An NVIDIA GPU with enough memory for the selected checkpoint
- The `nvidia/NVIDIA-Nemotron-3-Nano-30B-A3B-BF16` checkpoint downloaded locally
- Python 3.10 or newer

The included server configuration expects the checkpoint at:

```text
/mnt/scratch/ckpt/NVIDIA-Nemotron-3-Nano-30B-A3B-BF16
```

Change `MODEL_DIR` in `vllm/start_vllm.sh` if your checkpoint is elsewhere.

## Create the client environment

From the repository root:

```bash
python -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements.txt
```

The virtual environment is only for the lightweight Anthropic client and dotenv support. vLLM itself runs in Docker.

## Start vLLM

```bash
cd vllm
./start_vllm.sh
```

The server uses GPU 0, exposes the API only at `http://127.0.0.1:8000`, and serves the checkpoint under the model alias `model`.

Check startup progress with:

```bash
docker logs --follow nemotron-vllm
```

## Validate the API

From the repository root:

```bash
./.venv/bin/python ./vllm/smoke_test_vllm.py
```

This checks ordinary chat and a complete structured tool-call round trip through the Anthropic-compatible endpoint.

## Chat with the coding agent

```bash
./harness/chat_with_nemotron.sh
```

The launcher selects `.venv/bin/python` and loads `vllm/.env.vllm` automatically. Manual virtual-environment activation is not required.

## Stop vLLM

```bash
cd vllm
./stop_vllm.sh
```

The Docker image, checkpoint, and compilation-cache volume are preserved.

## Security warning

The harness executes model-generated shell commands with `shell=True`. Its small string denylist is not a security boundary. Run it only inside a disposable directory, container, VM, or other environment where unintended commands cannot damage important data or expose credentials.

## Detailed setup record

See [`vllm/VLLM_SETUP_LOG.md`](vllm/VLLM_SETUP_LOG.md) for the exact machine configuration, Docker image digest, launch decisions, commands, and validation results from the original setup.
