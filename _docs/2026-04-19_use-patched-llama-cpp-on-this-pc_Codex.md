# Use Patched llama.cpp on This PC

## Overview

This note captures the easiest way to use the patched Gemma 4 `llama.cpp` build produced during this thread on this Windows PC.

## Proven Runtime

Patched binaries:

- `F:\triality-targets\llama-gemma-mtmd\bin\Release\llama-server.exe`
- `F:\triality-targets\llama-gemma-mtmd\bin\Release\llama-mtmd-cli.exe`

Verified working path:

- `llama-server.exe` with Gemma 4 text GGUF + mmproj GGUF
- `--no-warmup`
- server startup reaches `loaded multimodal model` and `server is listening`

## Model Paths

- Text GGUF:
  - `C:\Users\downl\Desktop\SO8T\gguf_models\HauhauCS\Gemma-4-E4B-Uncensored-HauhauCS-Aggressive\Gemma-4-E4B-Uncensored-HauhauCS-Aggressive-Q8_K_P.gguf`
- mmproj GGUF:
  - `C:\Users\downl\Desktop\SO8T\gguf_models\HauhauCS\Gemma-4-E4B-Uncensored-HauhauCS-Aggressive\mmproj-Gemma-4-E4B-Uncensored-HauhauCS-Aggressive-f16.gguf`

## Launcher

Repo launcher:

- `C:\Users\downl\Desktop\wt-triality-main-direct\run-gemma4-patched-llama-server.cmd`

It starts:

- host: `127.0.0.1`
- port: `8094`
- ctx: `2048`
- `--no-warmup`

## Notes About LM Studio

- LM Studio officially documents itself as an OpenAI-compatible local server.
- The official docs do not document using LM Studio as a client UI for an arbitrary external `llama.cpp` server.
- So the supported and low-risk path is:
  - use this patched `llama-server` directly on the PC
  - point other OpenAI-compatible tools at `http://127.0.0.1:8094`
- Replacing LM Studio's internal backend/runtime with custom binaries is not treated here as a supported workflow.

## Residual

- `llama-mtmd-cli.exe` still has a later crash on this local Gemma pair; use `llama-server.exe` for now.
