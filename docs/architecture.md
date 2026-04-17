# Triality Platform Architecture

Triality Platform separates responsibilities across three repositories and one
stack-level control plane.

- `Turboquant-CUDA` is the research and export source of truth.
- `llama.cpp` is the inference-core source of truth.
- `Hypura` is the operational runtime and observability layer.
- `triality-platform` binds them together via a pinned stack contract.

## Data Flow

1. `Turboquant-CUDA` trains or selects a Triality/TurboQuant profile.
2. Export writes GGUF metadata plus an embedded payload.
3. `llama.cpp` reads the embedded contract and resolves runtime behavior.
4. `Hypura` reads the same contract for inspect, serve, and bench.

## Contract Priority

Embedded GGUF metadata and payload are authoritative.

- primary: embedded GGUF metadata and payload
- secondary: explicit developer overrides
- research-only: sidecar artifacts

## Operational Policy

`Hypura` must consume an external `llama.cpp` checkout via
`HYPURA_LLAMA_CPP_PATH` in integrated builds. Vendored fallbacks are allowed for
local compatibility only and should not be relied upon by stack CI.
