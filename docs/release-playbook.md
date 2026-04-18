# Triality Release Playbook

## Release Order

1. Tag `Turboquant-CUDA`
2. Tag `llama.cpp`
3. Tag `Hypura`
4. Update `stack/stack.lock.json`
5. Tag `triality-platform`

## Required Checks

- stack verification passes on Windows 11
- `stack/stack.lock.json` matches the latest validated submodule revisions before tagging
- Windows CUDA verification passes via `ci/verify-stack-cuda.ps1`
- `ci/verify-stack-cuda.ps1` bootstraps `repos/Turboquant-CUDA` through `uv` with PyTorch `cu128`
- fixture export succeeds for both supported modes across the Qwen and Gemma target families
- `llama.cpp` metadata and payload read checks pass
- `Hypura inspect` and `Hypura serve --dry-run` show the same profile
- `llama-completion` and `hypura run` complete short CUDA generation smoke with an embedded-TurboQuant GGUF and no sidecar
- bench smoke passes on the preferred validation host

## Notes

- the current validated latest upstream pin is `repos/llama.cpp` `master@745e347`
- the CUDA release smoke uses minimal non-zero GPU offload (`-ngl 1`) as the acceptance default
- the canonical CUDA Python environment is `repos/Turboquant-CUDA` `uv` with PyTorch `cu128`
- the current upstream smoke front-ends are `llama-completion` for Qwen text and `mtmd-cli` for Gemma multimodal
- public mode should be emitted as `triality-proxy-so8-pareto`; `triality-so8-pareto` is legacy read compatibility only
- do not release a stack tag with mismatched submodule revisions
- do not ship a contract change without updating `stack/schemas`
- do not rely on sidecar-only runtime behavior for release validation
