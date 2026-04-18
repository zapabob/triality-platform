# 2026-04-18 Real-Model Closeout Multimodal Wiring

## Goal

Close the M1 real-model integration slice for:

- `huihui-ai/Huihui-Qwen3.5-9B-Claude-4.6-Opus-abliterated`
- `Jiunsong/supergemma4-e4b-abliterated`

with these boundaries:

- keep low-level new weight kernels out of scope
- complete paired-artifact semantics for Gemma (`text GGUF + mmproj GGUF`)
- add Hypura CLI/server multimodal ingress
- align fast verify and CUDA verify scripts with the new contract
- update public docs/release notes to describe the paired multimodal path

## Files Changed

- `repos/hypura/src/compute/multimodal_bridge.rs`
- `repos/hypura/src/server/multimodal.rs`
- `repos/hypura/src/server/ollama_types.rs`
- `repos/hypura/src/server/routes.rs`
- `repos/hypura/src/server/streaming.rs`
- `repos/hypura/src/cli/run.rs`
- `repos/hypura/src/cli/inspect.rs`
- `repos/hypura/src/cli/serve.rs`
- `repos/hypura/src/main.rs`
- `repos/hypura/src/model/turboquant_sidecar.rs`
- `repos/hypura/Cargo.toml`
- `repos/Turboquant-CUDA/turboquant/triality_contract.py`
- `repos/Turboquant-CUDA/scripts/export_triality_fixture.py`
- `repos/Turboquant-CUDA/scripts/verify_triality_export.py`
- `ci/verify-stack.ps1`
- `ci/verify-stack.sh`
- `ci/verify-stack-cuda.ps1`
- `README.md`
- `docs/integration-contract.md`
- `docs/release-playbook.md`
- `stack/stack.toml`

## Key Decisions

- Keep `hypura.turboquant.*` only on the text GGUF.
- Treat `mmproj-*.gguf` as a required multimodal companion artifact, not a TurboQuant sidecar.
- Route multimodal M1 execution in Hypura through the current upstream `mtmd-cli` bridge instead of inventing a new low-level kernel path.
- Keep Ollama-compatible serving to text+image.
- Keep OpenAI-compatible serving as the text+image+audio surface.
- Require explicit failure when multimodal inputs arrive without `--mmproj`.

## What Was Implemented

- `Turboquant-CUDA` synthetic Gemma fixtures now emit paired manifests and a sibling `mmproj-triality-fixture.gguf`.
- `Hypura run` now accepts:
  - `--mmproj`
  - `--image`
  - `--audio`
- `Hypura inspect` and `Hypura serve --dry-run` now surface:
  - source
  - public/runtime mode
  - weight policy
  - protected roles/layers
  - modality scope
  - `mmproj required`
  - multimodal capabilities
- `Hypura` server routes now branch multimodal chat requests into the `mtmd-cli` bridge:
  - `/api/chat`: image only
  - `/v1/chat/completions`: image + audio
- `ci/verify-stack.ps1` and `ci/verify-stack.sh` now pass Gemma `--mmproj` for inspect/serve dry-run and validate paired manifests.
- `ci/verify-stack-cuda.ps1` now accepts:
  - `TRIALITY_QWEN_SMOKE_MODEL`
  - `TRIALITY_GEMMA_SMOKE_MODEL`
  - `TRIALITY_GEMMA_MMPROJ_MODEL`
  - `TRIALITY_GEMMA_IMAGE_SAMPLE`
  - `TRIALITY_GEMMA_AUDIO_SAMPLE`
- CUDA verify now knows how to:
  - build `mtmd-cli`
  - run Gemma multimodal smoke in `llama.cpp`
  - run Gemma multimodal smoke in `Hypura`
  - exercise Qwen text server routes on both compatibility surfaces
  - exercise Gemma Ollama image and OpenAI image+audio server routes

## Verification Run

### Passed

- `cargo build --manifest-path C:\Users\downl\Desktop\triality-platform\repos\hypura\Cargo.toml --bin hypura`
  - with `HYPURA_LLAMA_CPP_PATH=C:\Users\downl\Desktop\triality-platform\repos\llama.cpp`
  - with `HYPURA_NO_CUDA=1`
- `powershell -ExecutionPolicy Bypass -File C:\Users\downl\Desktop\triality-platform\ci\verify-stack.ps1`
- `C:\Program Files\Git\bin\bash.exe -lc 'cd /c/Users/downl/Desktop/triality-platform && ./ci/verify-stack.sh'`
- PowerShell parse check for:
  - `ci/verify-stack.ps1`
  - `ci/verify-stack-cuda.ps1`
- `bash -n C:\Users\downl\Desktop\triality-platform\ci\verify-stack.sh`

### Attempted And Learned

- `powershell -ExecutionPolicy Bypass -File C:\Users\downl\Desktop\triality-platform\ci\verify-stack-cuda.ps1 -SkipBaseVerify`
  - after aligning the build target to current upstream `llama-mtmd-cli`, the run reached CUDA smoke
  - the old local default Qwen artifact failed to load on current-main `llama.cpp` with:
    - `gguf_init_from_file_ptr: tensor name 427 is too long: 65 >= 64`
  - action taken:
    - removed the stale hardcoded default model path
    - made `TRIALITY_QWEN_SMOKE_MODEL` / `-QwenModelPath` the required real-model input for the Qwen lane

### Evidence Highlights

- Fast verify now proves Gemma synthetic manifests are paired and `mmproj`-aware.
- `Hypura inspect` now prints `mmproj required: true` and `Multimodal capabilities: text,image,audio` for the Gemma fixture family.
- `Hypura serve --dry-run` now shows the same multimodal summary and echoes the provided `mmproj` path.

## Remaining Gap

- Full real-model CUDA acceptance was not executed in this run because a confirmed local SuperGemma `text GGUF + mmproj GGUF` pair plus image/audio samples were not all provided to the script at execution time.
- The implementation is ready for that run through `ci/verify-stack-cuda.ps1`.
- The Qwen lane also now expects an explicit real-model path instead of the old KoboldCpp-local default artifact.
- The low-level new weight-compressed execution kernel remains intentionally deferred to M2.
