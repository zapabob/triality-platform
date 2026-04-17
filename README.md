# Triality Platform

Triality Platform is the umbrella repository for the integrated `Hypura`,
`Turboquant-CUDA`, and `llama.cpp` stack.

This repository is the source of truth for:

- stack composition and pinned revisions
- the GGUF-embedded Triality/TurboQuant contract
- cross-repo verification and release procedure

Current validated stack pins:

- `repos/hypura`: `codex/triality-platform-sync@df30ff9`
- `repos/Turboquant-CUDA`: `codex/triality-platform-sync@7601de3`
- `repos/llama.cpp`: `codex/triality-platform-sync@618d4d4`

## Layout

- `repos/hypura`: operational runtime, serving, scheduling, and inspection
- `repos/Turboquant-CUDA`: training, evaluation, fixture generation, and export
- `repos/llama.cpp`: inference-core runtime and GGUF packaging
- `stack/`: stack contract, lock file, and schema
- `docs/`: architecture and release documentation
- `ci/`: stack-level verification entrypoints

## Verification

Use the stack-level verification scripts from this repository root.

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

The CUDA verify script bootstraps the Python research environment from
`repos/Turboquant-CUDA` via `uv`, runs `uv run python scripts\env_check.py`,
builds `llama.cpp` and `Hypura` against CUDA, and performs short generation
smoke checks with a sidecar-free embedded-TurboQuant GGUF model. The validated
CUDA smoke path uses the latest pinned `llama.cpp` build with minimal GPU
offload (`-ngl 1`) to prove embedded runtime wiring without requiring full
model offload. On the current upstream pin, the non-chat `llama-completion`
front-end is used for the release smoke because it gives a stable short-run
CUDA exit path while `llama-cli` remains chat-first.

## Contract

The production contract is GGUF-embedded Triality/TurboQuant metadata and
payload. Sidecar artifacts may exist for research and reproducibility, but the
runtime path must not require them. The Python research toolchain is sourced
from the existing `repos/Turboquant-CUDA` `uv` project; runtime compatibility
remains defined by the GGUF-embedded contract.
