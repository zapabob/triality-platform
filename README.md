# Triality Platform

## TL;DR

Triality Platform is an integrated stack for turning Triality/TurboQuant
research into a shippable GGUF runtime.

It combines:

- `Turboquant-CUDA` for research, evaluation, packaging, and fixture generation
- `llama.cpp` for the inference-core runtime and embedded GGUF execution
- `Hypura` for inspection, serving, scheduling, and operational integration

The point of this repo is not just to pin three submodules. It is to keep one
shared contract, one verification story, and one release surface across all
three.

## Why This Repo Exists

Most quantization work stops at "the exporter runs" or "the model loads on one
machine." Triality Platform is the layer that keeps the whole path intact:

- research and profiling in CUDA-native code
- GGUF packaging with embedded `hypura.turboquant.*` metadata
- runtime interpretation in `llama.cpp`
- serving and inspection in `Hypura`
- stack-level fast verify and CUDA smoke from a single parent repo

If you want a repo that answers "what can this quantization method actually do
in production?" rather than just "can I generate an artifact?", this is the
stack.

## Integrated Stack

| Repo | Current integrated pin | Role in the stack | What this integrated pin carries |
| --- | --- | --- | --- |
| `Turboquant-CUDA` | `codex/m1-real-model-closeout@5980f4b` | Research, eval, export, fixtures | Triality packaging plus paired multimodal manifest export |
| `llama.cpp` | `codex/m1-real-model-closeout@fe66971` | Inference core | Embedded real-model Triality metadata and weight-plan coverage |
| `Hypura` | `codex/m1-real-model-closeout@8e346b5` | Operational runtime | Inspect/serve multimodal bridge, `mmproj` support, and compatibility-surface routing |

The parent repo keeps these pins synchronized in `stack/stack.lock.json` and
exposes the stack-level verification entrypoints.

## End-To-End Flow

```mermaid
flowchart LR
    A["Turboquant-CUDA<br/>research, capture, eval, export"] --> B["GGUF embedded contract<br/>hypura.turboquant.* metadata<br/>+ inline payload"]
    B --> C["llama.cpp<br/>runtime load, KV wiring,<br/>inference-core execution"]
    B --> D["Hypura<br/>inspect, serve, bench,<br/>scheduler + runtime integration"]
    C --> E["Fast verify / CUDA smoke<br/>parent repo CI entrypoints"]
    D --> E
    E --> F["Release evidence<br/>stack.lock.json + artifacts"]
```

## What You Can Do With It

- Capture and evaluate Triality/TurboQuant variants in `Turboquant-CUDA`
- Package those variants into a GGUF contract that does not require a runtime
  sidecar
- Run the same embedded contract in `llama.cpp` and `Hypura`
- Audit runtime behavior from one parent repo instead of juggling three
  disconnected integrations
- Keep upstream pinning, validation, and release evidence under version control

## Current Target Models

- `huihui-ai/Huihui-Qwen3.5-9B-Claude-4.6-Opus-abliterated`
  - text-only fast lane
  - KV TurboQuant targets full-attention layers
  - embedded weight policy defaults to `qwen35-full-attention-ffn`
- `Jiunsong/supergemma4-e4b-abliterated`
  - treated as the Gemma 4 E4B multimodal family
  - modality towers stay protected while shared decoder / FFN / owner-KV layers carry the TurboQuant plan
  - embedded weight policy defaults to `gemma4-e4b-shared-decoder-hybrid`
  - ships as a paired artifact set: `text GGUF + mmproj GGUF`

The public contract now covers both KV and weight-plan metadata under
`hypura.turboquant.*`, while keeping GGUF-embedded delivery as the only runtime
source of truth.

## Repository Layout

- `repos/Turboquant-CUDA`: training, capture, evaluation, export, fixtures
- `repos/llama.cpp`: inference core, GGUF runtime, backend execution
- `repos/hypura`: operations runtime, inspect/serve/bench, scheduler
- `stack/`: lock file, schema, and stack contract metadata
- `docs/`: integration and release-facing documentation
- `ci/`: stack-level verification entrypoints

## Verification Paths

Fast verify on Windows:

```powershell
pwsh -File .\ci\verify-stack.ps1
```

Fast verify on POSIX:

```bash
./ci/verify-stack.sh
```

CUDA verify on Windows:

```powershell
pwsh -File .\ci\verify-stack-cuda.ps1
```

For full two-model CUDA acceptance, provide:

- `TRIALITY_QWEN_SMOKE_MODEL`
- `TRIALITY_GEMMA_SMOKE_MODEL`
- `TRIALITY_GEMMA_MMPROJ_MODEL`
- `TRIALITY_GEMMA_IMAGE_SAMPLE`
- `TRIALITY_GEMMA_AUDIO_SAMPLE`

The fast verify lane checks pin consistency, fixture export, manifest
validation, and basic `Hypura` CPU smoke. The CUDA lane uses the Python
research environment from `repos/Turboquant-CUDA`, then builds `llama.cpp` and
`Hypura` against CUDA for short runtime smoke on a practical local machine
class. The fast verify lane also exercises the canonical public mode
`triality-proxy-so8-pareto` plus its weight-plan summary on both targeted model
families. For SuperGemma4-E4B, the CUDA lane now verifies a formal paired
`text GGUF + mmproj GGUF` artifact contract, with Ollama-compatible image
requests and OpenAI-compatible image+audio requests.

## CUDA Snapshot

Latest full Windows CUDA evidence:
`artifacts/cuda-smoke/20260417-011313`

This is a smoke snapshot, not a leaderboard benchmark. It exists to prove that
the embedded contract survives export, runtime load, and short generation on a
real local deployment class such as Windows 11 + RTX 3060.

Current upstream normalizes the pareto public mode to
`triality-proxy-so8-pareto` while retaining `triality-so8-pareto` as a legacy
alias for older artifacts and logs.

| Check | Evidence | Snapshot |
| --- | --- | --- |
| `llama-completion` runtime | `TurboQuant enabled via gguf` | embedded mode `triality-proxy-so8-pareto` (legacy alias `triality-so8-pareto`), seed `70367`, minimal offload `-ngl 1`, `1/33` layers on GPU |
| `llama-completion` throughput | `common_perf_print` | prompt eval `8.25 tok/s`, generation `3.76 tok/s` on `RTX 3060 12 GB` |
| `Hypura inspect` | `Source: gguf-embedded` | public mode `triality-proxy-so8-pareto` (legacy alias `triality-so8-pareto`), runtime mode `research-kv-split`, rotation `triality_vector`, payload `format=none bytes=0` |
| `Hypura run` | `TurboQuant blocking session complete` | `33/33` layers offloaded to GPU, generated `4` tokens, same GGUF contract and metadata source |

## Public Contract

The production contract is GGUF-embedded Triality/TurboQuant metadata and
payload.

- Public metadata stays under `hypura.turboquant.*`
- That namespace now includes the embedded weight-plan keys under
  `hypura.turboquant.weight.*`
- For paired multimodal models, the text GGUF remains the only owner of the
  public TurboQuant namespace
- `mmproj-*.gguf` is a required multimodal companion artifact for Gemma-family
  serving, but it is not a TurboQuant sidecar
- Runtime consumers are expected to work from GGUF plus embedded payload alone
- Sidecars may exist for research and reproducibility, but they are not the
  runtime source of truth
- The parent repo lock file updates the pinned upstream state without changing
  the meaning of the public GGUF contract

## Current Parent Lock

- `repos/Turboquant-CUDA`: `codex/m1-real-model-closeout@5980f4b2087cb8598230daf9fdb612fb53945c53`
- `repos/llama.cpp`: `codex/m1-real-model-closeout@fe66971d2097c993f5535f15cc23c051cea3f595`
- `repos/hypura`: `codex/m1-real-model-closeout@8e346b5640d3e0231b39377b2983a7272cd794c6`

This repository is the source of truth for how those three upstreams are wired
together today.
