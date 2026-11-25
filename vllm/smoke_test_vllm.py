#!/usr/bin/env python3
"""Validate normal chat and a complete tool-call round trip through vLLM."""

import os

from anthropic import Anthropic
from dotenv import load_dotenv


SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
load_dotenv(os.path.join(SCRIPT_DIR, ".env.vllm"), override=True)

client = Anthropic(base_url=os.environ["ANTHROPIC_BASE_URL"])
model = os.environ["MODEL_ID"]

print("[1/2] Normal chat")
chat = client.messages.create(
    model=model,
    max_tokens=1024,
    messages=[
        {
            "role": "user",
            "content": "Reply with exactly NEMOTRON_READY and nothing else.",
        }
    ],
)
chat_text = "".join(
    block.text for block in chat.content if block.type == "text"
).strip()
print(f"response={chat_text!r}")
if "NEMOTRON_READY" not in chat_text:
    raise RuntimeError("Normal chat did not return the expected marker")

print("[2/2] Tool-call round trip")
tools = [
    {
        "name": "get_magic_number",
        "description": "Return the test magic number.",
        "input_schema": {
            "type": "object",
            "properties": {"label": {"type": "string"}},
            "required": ["label"],
        },
    }
]
messages = [
    {
        "role": "user",
        "content": (
            "Call get_magic_number with label smoke-test. "
            "Do not guess the result and do not answer before calling the tool."
        ),
    }
]
tool_request = client.messages.create(
    model=model,
    max_tokens=2048,
    tools=tools,
    messages=messages,
)
tool_calls = [block for block in tool_request.content if block.type == "tool_use"]
if not tool_calls:
    raise RuntimeError("The model did not produce a structured tool_use block")

tool_call = tool_calls[0]
print(f"tool={tool_call.name!r} input={tool_call.input!r}")
messages.append({"role": "assistant", "content": tool_request.content})
messages.append(
    {
        "role": "user",
        "content": [
            {
                "type": "tool_result",
                "tool_use_id": tool_call.id,
                "content": "42",
            }
        ],
    }
)
tool_answer = client.messages.create(
    model=model,
    max_tokens=2048,
    tools=tools,
    messages=messages,
)
answer_text = "".join(
    block.text for block in tool_answer.content if block.type == "text"
).strip()
print(f"final_response={answer_text!r}")
if "42" not in answer_text:
    raise RuntimeError("Tool result was not incorporated into the final response")

print("PASS: normal chat and structured tool calling both work")
