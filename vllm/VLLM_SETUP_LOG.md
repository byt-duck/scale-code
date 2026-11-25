# Nemotron vLLM setup log

Date: 2026-11-25 UTC

This is the reproducible record of setting up `NVIDIA-Nemotron-3-Nano-30B-A3B-BF16` with vLLM on one H100.

## Starting state

- Host: 8 x NVIDIA H100 80 GB HBM3.
- Selected GPU: GPU 0.
- Driver: 550.90.07 (reports CUDA 12.4 capability).
- Docker: client and server 27.5.1.
- Checkpoint: `/mnt/scratch/ckpt/NVIDIA-Nemotron-3-Nano-30B-A3B-BF16`.
- Checkpoint size: 59 GB, with all 13 BF16 `safetensors` shards present.
- Free space at start: 293 GB on `/mnt/scratch`; 59 GB on the root filesystem where Docker stores images.
- vLLM image selected: `vllm/vllm-openai:v0.30.0`.

## Container cleanup

The user explicitly authorized cleaning up all existing Docker containers. Ten containers were found and removed with `docker rm -f`; three had been running and seven were stopped. Docker images and project files were not deleted. `docker ps -a` was empty afterward.

Removed container names:

1. `a3-skills`
2. `andrei-a3`
3. `andrei-branch`
4. `nemotron-nano-v3-week`
5. `mbridge-dev`
6. `olmes-nemotron-eval`
7. `andrei-mbridge`
8. `nemotron-nano-v3-8e-gpu2`
9. `nemotron-nano-v3-8e-gpu2-cachefail-20261013-0439`
10. `nemotron-nano-v3-48e-ep3-collision-20261013-0032`

## Configuration decisions

- The model card requires vLLM 0.12.0 or newer. Version 0.30.0 is pinned for reproducibility and provides the Anthropic Messages API used by `agent_loop.py`.
- The official Docker image is used to isolate the large CUDA/Python dependency stack from the host.
- `VLLM_ENABLE_CUDA_COMPATIBILITY=1` enables the compatibility libraries shipped in the image because the host driver predates the image's CUDA toolkit.
- Only GPU 0 is exposed to the container.
- The checkpoint is mounted read-only at `/model`.
- Port 8000 is bound to `127.0.0.1`, not all network interfaces.
- A named Docker volume, `nemotron-vllm-cache`, preserves compiled artifacts across container recreation.
- Initial context is 32,768 tokens with one simultaneous sequence. This is deliberately below the model's maximum context so the 59 GB BF16 weights and KV/state cache fit reliably on one 80 GB H100.
- The served model name is the short, stable name `model`.
- Tool parsing uses `qwen3_coder`, as required by the checkpoint's chat template.
- Reasoning parsing uses the checkpoint-bundled `/model/nano_v3_reasoning_parser.py` plugin and parser name `nano_v3`.

## Step-by-step setup procedure

1. **Inspected the machine.** Confirmed eight free H100 80 GB GPUs, driver 550.90.07, Docker 27.5.1, and enough disk space.
2. **Verified the checkpoint.** Confirmed the 59 GB checkpoint directory and all 13 BF16 `safetensors` shards under `/mnt/scratch/ckpt/NVIDIA-Nemotron-3-Nano-30B-A3B-BF16`.
3. **Inspected the checkpoint instructions.** Read its local `README.md`, which requires vLLM 0.12.0 or newer, `qwen3_coder` tool parsing, and the bundled `nano_v3_reasoning_parser.py` plugin.
4. **Inspected the existing agent.** Confirmed that `agent_loop.py` uses Anthropic's `messages.create()` interface and Anthropic-style `tool_use`/`tool_result` blocks.
5. **Removed old containers.** Listed all Docker containers, then removed the ten containers authorized by the user. Images, model files, and project files were preserved.
6. **Selected a pinned runtime.** Chose the official `vllm/vllm-openai:v0.30.0` image because it satisfies the model requirement and exposes a native Anthropic Messages API.
7. **Downloaded the runtime.** Pulled the image and recorded its immutable digest and expanded size.
8. **Created a reproducible server launcher.** `vllm/start_vllm.sh` exposes only GPU 0, mounts the model read-only, enables CUDA compatibility for the R550 host driver, persists the compilation cache, and binds port 8000 only to localhost.
9. **Applied conservative initial limits.** Configured a 32,768-token context, one simultaneous sequence, and 90% GPU-memory utilization for a reliable first deployment of the 59 GB BF16 checkpoint on one 80 GB GPU.
10. **Enabled model-specific parsing.** Added `--enable-auto-tool-choice`, `--tool-call-parser qwen3_coder`, and the checkpoint's `nano_v3` reasoning parser plugin.
11. **Started and monitored the service.** Waited for all weight shards, compilation, Mamba warmup, CUDA graph capture, and API startup to finish. Confirmed an HTTP 200 health response.
12. **Created the client environment.** Built the isolated environment now located at the project root as `.venv`, with pinned `anthropic==2.14.0` and `python-dotenv==1.2.4` packages.
13. **Configured the client.** Created `vllm/.env.vllm` with the localhost API address, local placeholder key, and served model name `model`.
14. **Connected the existing harness.** Made `agent_loop.py` accept an optional `DOTENV_PATH`, then created `harness/chat_with_nemotron.sh` to load the vLLM settings and invoke the correct virtual-environment Python automatically.
15. **Validated ordinary chat.** Sent an Anthropic-format message and received the exact expected marker `NEMOTRON_READY`.
16. **Validated structured tools.** Confirmed a structured `tool_use` response, submitted a matching `tool_result`, and verified that the model incorporated the result into its final response.
17. **Validated the real coding loop.** Ran the actual harness, allowed it to call the harmless `pwd` command, and confirmed that it processed the result correctly.
18. **Organized the project.** Moved the agent and chat launcher into `harness/`; moved the server scripts, settings, tests, and runbook into `vllm/`; and placed the shared client environment at the project root as `.venv`. The running Docker service was not interrupted.

## Files created

- `harness/agent_loop.py`: the coding-agent loop.
- `harness/chat_with_nemotron.sh`: starts the agent with the local vLLM configuration, while preserving the caller's current directory as the agent workspace.
- `vllm/start_vllm.sh`: reproducible one-GPU server launcher.
- `vllm/stop_vllm.sh`: removes only the `nemotron-vllm` service container.
- `vllm/.env.vllm`: local client settings for the Anthropic-compatible API.
- `.venv`: project-level isolated client environment containing `anthropic==2.14.0` and `python-dotenv==1.2.4`.
- `vllm/smoke_test_vllm.py`: checks a normal Anthropic-format message and a complete structured tool-call/result round trip.
- `vllm/VLLM_SETUP_LOG.md`: this record.

`agent_loop.py` received one configuration-only change: it now honors an optional `DOTENV_PATH` environment variable. With no `DOTENV_PATH`, it retains its prior behavior of finding the default `.env` file.

## Commands and validation results

### Image installation

The official image was downloaded with:

```bash
docker pull vllm/vllm-openai:v0.30.0
```

- Image digest: `sha256:8a69ffad015f138d7170c4ddc429e230a3bc1c1719f67e14324749df200a4b90`.
- Expanded image size: 21,635,976,151 bytes (about 20.2 GiB).
- The image contains vLLM 0.30.0 and CUDA 13.0.2.
- The host's R550 driver is explicitly accepted by the image. CUDA forward compatibility was enabled with `VLLM_ENABLE_CUDA_COMPATIBILITY=1` and worked successfully.

### Client environment

The isolated environment was created and populated with:

```bash
/home/palshraya/.local/bin/uv venv /home/palshraya/scale-code/.venv
/home/palshraya/.local/bin/uv pip install --python /home/palshraya/scale-code/.venv/bin/python anthropic==2.14.0 python-dotenv==1.2.4
```

Installed client versions include `anthropic==2.14.0` and `python-dotenv==1.2.4`.

### Server startup

The server was started by running `./start_vllm.sh`. The resulting container is named `nemotron-vllm`, uses image `vllm/vllm-openai:v0.30.0`, and has restart policy `unless-stopped`.

Observed startup results:

- vLLM resolved the architecture as `NemotronHForCausalLM` and dtype as BF16.
- All 13 checkpoint shards loaded successfully.
- Weight loading consumed 58.92 GiB of GPU memory.
- Compilation and warmup completed successfully.
- vLLM allocated 10.24 GiB for KV/state cache.
- The server registered both `/v1/messages` and `/v1/messages/count_tokens` for Anthropic compatibility.
- It also registered the OpenAI-compatible endpoints, including `/v1/chat/completions` and `/v1/responses`.
- The container is restricted to GPU 0. GPU 1 and the remaining GPUs are not exposed to it.
- Docker maps container port 8000 only to host address `127.0.0.1:8000`.

The original live container was launched with the deprecated `--model /model` spelling, which worked but emitted a warning. `start_vllm.sh` was then corrected to use the positional `/model` spelling for future recreations. This does not change the current running server's behavior.

### API validation

The following checks were completed:

1. `GET http://127.0.0.1:8000/health` returned HTTP 200.
2. `GET http://127.0.0.1:8000/v1/models` returned served model `model` with a maximum length of 32,768 tokens.
3. A normal request through the Anthropic Python client returned exactly `NEMOTRON_READY`.
4. A tool-use request through the Anthropic client returned a structured `tool_use` block for `get_magic_number` with input `{"label": "smoke-test"}`.
5. The tool result `42` was sent back in an Anthropic `tool_result` block. The model incorporated it into its final answer.
6. `smoke_test_vllm.py` reported: `PASS: normal chat and structured tool calling both work`.
7. The actual `harness/agent_loop.py` was launched through `harness/chat_with_nemotron.sh`. It was asked to invoke its bash tool with `pwd`; it produced the structured bash call, executed it, received the result, and answered `/home/palshraya/scale-code`.
8. Shell syntax checks passed for all three shell scripts, and Python compilation checks passed for `agent_loop.py` and `smoke_test_vllm.py`.
9. Recent server logs contained successful HTTP 200 requests and no `ERROR` or traceback entries.
10. After the folder reorganization, all tests were repeated: ordinary chat passed, structured tool calling passed, the relocated harness called `pwd` successfully, and the Docker service remained online.
11. During the initial reorganization, the environment was temporarily rebuilt under `vllm/.venv`. At the user's later request, a fresh environment was built at the project root as `.venv`, the harness was updated and retested, and the temporary `vllm/.venv` was removed.

Final observed resource state:

- GPU 0 memory: approximately 72,854 MiB of 81,559 MiB.
- GPU 1 memory: 1 MiB; it was not used.
- Root filesystem after installing the image: 39 GB free.
- `/mnt/scratch`: 293 GB free.

## How to use it

The server is already running. To chat with the coding agent:

```bash
cd /home/palshraya/scale-code
./harness/chat_with_nemotron.sh
```

Type `q` or `exit` to leave the chat.

Useful checks:

```bash
curl http://127.0.0.1:8000/health
docker logs --follow nemotron-vllm
./.venv/bin/python ./vllm/smoke_test_vllm.py
```

## Do I need to activate `.venv`?

No activation is needed for normal use. `harness/chat_with_nemotron.sh` directly selects `.venv/bin/python` and loads `vllm/.env.vllm`. The Docker start and stop scripts also do not use the Python environment.

Activation is useful only when you want to run Python commands interactively or install/inspect client packages yourself:

```bash
cd /home/palshraya/scale-code
source .venv/bin/activate
```

After activation, `python` and package commands refer to this environment. Activation alone does not load the API settings. To run the agent manually rather than through its launcher, export those settings too:

```bash
set -a
source vllm/.env.vllm
set +a
python harness/agent_loop.py
```

Leave the environment with:

```bash
deactivate
```

To stop and remove only this service container:

```bash
cd /home/palshraya/scale-code/vllm
./stop_vllm.sh
```

To recreate it later using the same pinned configuration:

```bash
cd /home/palshraya/scale-code/vllm
./start_vllm.sh
```

The model files, Docker image, and named compilation-cache volume remain after `stop_vllm.sh`, so they do not need to be downloaded again.

## Incidental workspace repair

The file-editing helper initially could not start because three expected empty metadata directories were missing from the separate Codex visualization workspace. Empty `.git`, `.agents`, and `.codex` directories were created under `/home/palshraya/.codex/visualizations/2026/11/25/01a21090-8e3d-7952-bba4-095b88c92bbf`. No project files or repository history were changed by this repair.
