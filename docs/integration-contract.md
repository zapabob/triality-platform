# Triality Integration Contract

## Namespace

All public GGUF keys remain under `hypura.turboquant.*`.

## Required Metadata

- `hypura.turboquant.schema_version`
- `hypura.turboquant.enabled`
- `hypura.turboquant.mode`
- `hypura.turboquant.rotation_policy`
- `hypura.turboquant.rotation_seed`
- `hypura.turboquant.triality_view`
- `hypura.turboquant.triality_mix`
- `hypura.turboquant.paper_fidelity`
- `hypura.turboquant.k_bits`
- `hypura.turboquant.v_bits`
- `hypura.turboquant.payload_format`
- `hypura.turboquant.payload_bytes`

## Allowed Modes

- `paper-faithful`
- `triality-so8-pareto`

## Payload Policy

- production runtime must work from GGUF metadata and embedded payload alone
- sidecar artifacts are allowed for research and reproducibility
- payload format is versioned and declared explicitly by metadata
- upstream pin changes in `stack/stack.lock.json` do not change this public runtime contract

## Cross-Repo Expectations

- `Turboquant-CUDA` emits metadata and payload in a schema-compliant form
- `llama.cpp` resolves runtime behavior from that metadata and payload
- `Hypura` surfaces the same profile through inspect and serve output

## Python Tooling Contract

- the Python research environment is sourced from `repos/Turboquant-CUDA`
- stack-level Python entrypoints should execute through that repo's `uv` project
- Python tooling may assist export, validation, and CUDA preflight checks
- the public runtime contract remains GGUF metadata plus embedded payload only
- stack-level CUDA smoke may use a non-chat `llama.cpp` front-end for stability, but that does not change the public GGUF contract
