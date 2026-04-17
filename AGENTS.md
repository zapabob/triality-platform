# Triality Platform Agent Notes

## Roles

- `repos/Turboquant-CUDA` owns Triality/TurboQuant research artifacts, offline
  metrics, and GGUF payload export.
- `repos/llama.cpp` owns the inference-core interpretation of the embedded
  Triality/TurboQuant contract.
- `repos/hypura` owns orchestration, serving, inspection, and operational
  observability on top of `llama.cpp`.

## Integration Rules

- Keep the public metadata namespace as `hypura.turboquant.*`.
- Treat GGUF-embedded metadata and payload as the production contract.
- Prefer embedded metadata over runtime environment overrides.
- Keep `koboldcpp` out of scope for this repository.

## Verification Order

1. Submodule revision alignment
2. Fixture export from `Turboquant-CUDA`
3. Metadata and payload read checks in `llama.cpp`
4. `Hypura inspect` profile verification
5. `Hypura serve --dry-run` wiring verification
6. `Hypura bench` smoke verification
