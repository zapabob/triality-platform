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
- `hypura.turboquant.weight.enabled`
- `hypura.turboquant.weight.source_ftype`
- `hypura.turboquant.weight.policy`
- `hypura.turboquant.weight.protected_roles`
- `hypura.turboquant.weight.protected_layers`
- `hypura.turboquant.weight.modality_scope`
- `hypura.turboquant.weight.payload_format`
- `hypura.turboquant.weight.payload_bytes`

## Allowed Modes

- `paper-faithful`
- `triality-proxy-so8-pareto`
- `triality-so8-pareto` as a legacy alias retained for backward compatibility

## Weight Plan Policy

- weight-plan metadata is embedded under the same `hypura.turboquant.*` namespace
- the public contract only permits `bf16`, `f16`, and `q8_0` as weight-plan source formats
- `Q4_K_M` and other already-low-bit sources are not accepted for the canonical weight-plan export lane
- embedded weight plans describe policy, protected roles, protected layers, modality scope, and payload sizing
- runtime consumers must surface the embedded weight-plan summary without requiring a sidecar

## Paired Multimodal Artifact Policy

- multimodal Gemma-family releases ship as a paired artifact set:
  - `<model>.gguf`
  - `mmproj-<model>.gguf`
- the text GGUF remains the only owner of the public `hypura.turboquant.*` namespace
- the `mmproj` companion stays exact/protected and must not become a TurboQuant metadata carrier
- exporter manifests must describe:
  - `text_model_path`
  - `mmproj_model_path`
  - `mmproj_required`
  - `modalities`
  - `sample_env`
- runtime consumers must fail explicitly when multimodal inputs are requested without the required `mmproj` companion

## Targeted Model Families

- `huihui-ai/Huihui-Qwen3.5-9B-Claude-4.6-Opus-abliterated`
  - text-only fast lane
  - KV TurboQuant applies to full-attention layers only
  - weight policy defaults to `qwen35-full-attention-ffn`
- `Jiunsong/supergemma4-e4b-abliterated`
  - Gemma 4 E4B multimodal family semantics
  - shared decoder, FFN, and owner/global KV layers are the main TurboQuant lane
  - modality-specific towers stay in the protected lane
  - weight policy defaults to `gemma4-e4b-shared-decoder-hybrid`

## Payload Policy

- production runtime must work from GGUF metadata and embedded payload alone
- sidecar artifacts are allowed for research and reproducibility
- payload format is versioned and declared explicitly by metadata
- upstream pin changes in `stack/stack.lock.json` do not change this public runtime contract

## Cross-Repo Expectations

- `Turboquant-CUDA` emits metadata and payload in a schema-compliant form
- `Turboquant-CUDA` emits paired Gemma manifests for multimodal checkpoints
- `llama.cpp` resolves runtime behavior from that metadata and payload
- `llama.cpp` uses the paired `text GGUF + mmproj GGUF` contract for Gemma-family multimodal runtime
- `llama.cpp` and `Hypura` both accept the canonical public mode `triality-proxy-so8-pareto`
- `Hypura` surfaces the same KV, weight-plan, and `mmproj` requirement profile through inspect and serve output

## Python Tooling Contract

- the Python research environment is sourced from `repos/Turboquant-CUDA`
- stack-level Python entrypoints should execute through that repo's `uv` project
- Python tooling may assist export, validation, and CUDA preflight checks
- the public runtime contract remains GGUF metadata plus embedded payload only
- stack-level CUDA smoke may use a non-chat `llama.cpp` front-end for stability, but that does not change the public GGUF contract
- full two-model CUDA acceptance uses:
  - `TRIALITY_QWEN_SMOKE_MODEL`
  - `TRIALITY_GEMMA_SMOKE_MODEL`
  - `TRIALITY_GEMMA_MMPROJ_MODEL`
  - `TRIALITY_GEMMA_IMAGE_SAMPLE`
  - `TRIALITY_GEMMA_AUDIO_SAMPLE`
