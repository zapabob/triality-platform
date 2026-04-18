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
- fixture export succeeds for both supported modes across the Qwen and Gemma target families
- `llama.cpp` metadata and payload read checks pass
- `Hypura inspect` and `Hypura serve --dry-run` show the same KV and weight-plan profile
- `llama-completion` and `hypura run` complete short CUDA generation smoke for Qwen text-only
- `mtmd-cli` and `hypura run --mmproj --image --audio` complete short CUDA generation smoke for SuperGemma4-E4B
- `Hypura` server passes:
  - Qwen text requests on Ollama-compatible and OpenAI-compatible routes
  - Gemma text+image requests on Ollama-compatible routes
  - Gemma text+image+audio requests on OpenAI-compatible routes
- bench smoke passes on the preferred validation host
- full two-model CUDA acceptance requires:
  - `TRIALITY_QWEN_SMOKE_MODEL`
  - `TRIALITY_GEMMA_SMOKE_MODEL`
  - `TRIALITY_GEMMA_MMPROJ_MODEL`
  - `TRIALITY_GEMMA_IMAGE_SAMPLE`
  - `TRIALITY_GEMMA_AUDIO_SAMPLE`

## Notes

- the current integrated M1 closeout pin is `repos/llama.cpp` `codex/m1-real-model-closeout@fe66971`
- the CUDA release smoke uses minimal non-zero GPU offload (`-ngl 1`) as the acceptance default
- the current upstream smoke front-ends are `llama-completion` for Qwen text and `mtmd-cli` for Gemma multimodal
- public mode should be emitted as `triality-proxy-so8-pareto`; `triality-so8-pareto` is legacy read compatibility only
- do not release a stack tag with mismatched submodule revisions
- do not ship a contract change without updating `stack/schemas`
- do not rely on sidecar-only runtime behavior for release validation
- do not move `hypura.turboquant.*` metadata into `mmproj`; the text GGUF remains the contract owner
