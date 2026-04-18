# 2026-04-18 Qwen + Gemma Weight Contract Integration

## Goal

Implement the parent-repo slice of the Qwen3.5-9B + SuperGemma4-E4B TurboQuant
plan with:

- dual-family synthetic export in `Turboquant-CUDA`
- embedded weight-plan metadata under `hypura.turboquant.weight.*`
- canonical public mode support for `triality-proxy-so8-pareto`
- `Hypura` inspect/serve surfacing of the weight plan
- parent fast verify updated to exercise both model families and the canonical pareto mode
- `llama.cpp` GGUF metadata unit coverage extended to weight-plan parsing

## Files Changed

- `repos/Turboquant-CUDA/turboquant/triality_contract.py`
- `repos/Turboquant-CUDA/scripts/export_triality_fixture.py`
- `repos/Turboquant-CUDA/scripts/verify_triality_export.py`
- `repos/llama.cpp/convert_hf_to_gguf.py`
- `repos/llama.cpp/src/llama-turboquant.h`
- `repos/llama.cpp/src/llama-turboquant.cpp`
- `repos/llama.cpp/tests/test-turboquant-gguf-metadata.cpp`
- `repos/llama.cpp/tests/CMakeLists.txt`
- `repos/hypura/src/model/turboquant_sidecar.rs`
- `repos/hypura/src/cli/inspect.rs`
- `repos/hypura/src/cli/serve.rs`
- `stack/schemas/turboquant-gguf.schema.json`
- `stack/stack.toml`
- `docs/integration-contract.md`
- `docs/release-playbook.md`
- `README.md`
- `ci/verify-stack.ps1`
- `ci/verify-stack.sh`
- `ci/verify-stack-cuda.ps1`

## Key Decisions

- Keep the public runtime namespace at `hypura.turboquant.*`.
- Treat `triality-proxy-so8-pareto` as the canonical public mode.
- Keep `triality-so8-pareto` as a read-only legacy alias.
- Treat weight planning as a GGUF-embedded contract first, not a sidecar-first runtime feature.
- Restrict canonical weight-plan source formats to `bf16`, `f16`, and `q8_0`.
- Use text-only Qwen and multimodal-scoped Gemma policy defaults, but keep modality towers protected.

## Verification Run

### Passed

- `powershell -ExecutionPolicy Bypass -File C:\Users\downl\Desktop\triality-platform\ci\verify-stack.ps1`
- `C:\Program Files\Git\bin\bash.exe -lc 'cd /c/Users/downl/Desktop/triality-platform && ./ci/verify-stack.sh'`
- `cargo test --manifest-path C:\Users\downl\Desktop\triality-platform\repos\hypura\Cargo.toml gguf_triality_metadata_resolves_without_sidecar`
- `cargo test --manifest-path C:\Users\downl\Desktop\triality-platform\repos\hypura\Cargo.toml gguf_triality_legacy_alias_still_resolves`
- `cargo test --manifest-path C:\Users\downl\Desktop\triality-platform\repos\hypura\Cargo.toml strict_gguf_turboquant_metadata_resolves_with_layer_arrays`
- `python -m py_compile ...triality_contract.py ...export_triality_fixture.py ...verify_triality_export.py ...convert_hf_to_gguf.py`
- PowerShell parse check for `ci/verify-stack-cuda.ps1`
- `cmake` configure/build of `repos/llama.cpp/build-test-turboquant`
- `build-test-turboquant/bin/Release/test-turboquant-gguf-metadata.exe`

### Important Evidence

- Fast verify now exports and validates both:
  - `huihui-ai/Huihui-Qwen3.5-9B-Claude-4.6-Opus-abliterated`
  - `Jiunsong/supergemma4-e4b-abliterated`
- `Hypura inspect` and `serve --dry-run` now show:
  - canonical public mode `triality-proxy-so8-pareto`
  - weight policy
  - protected roles/layers
  - modality scope
- `llama.cpp` GGUF metadata unit test now checks weight metadata ingestion.

## Remaining Gap

- Full real-model CUDA smoke for both Qwen and Gemma was not executed in this run because a confirmed local Gemma GGUF path was not established here.
- `ci/verify-stack-cuda.ps1` now supports two-model acceptance via:
  - `TRIALITY_QWEN_SMOKE_MODEL`
  - `TRIALITY_GEMMA_SMOKE_MODEL`
- The script keeps backward compatibility with the legacy single `-ModelPath` entry for the Qwen lane.

## Notes

- This run implements the embedded weight-plan contract, parsing, surfacing, and verification path.
- It does not add a new low-level weight-compressed execution kernel in `llama.cpp`; the current slice is contract/runtime-resolution work plus stack acceptance hardening.
