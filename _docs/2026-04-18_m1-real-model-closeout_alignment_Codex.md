# 2026-04-18 M1 Real-Model Closeout Alignment

## Scope

Aligned the parent repo with the already-landed M1 real-model closeout slices
across `Turboquant-CUDA`, `llama.cpp`, and `Hypura`, then re-verified the
parts that are executable on this host without the real local model assets.

## What Was Already Present

- Parent contract/schema/docs already described:
  - paired Gemma `text GGUF + mmproj GGUF`
  - embedded `hypura.turboquant.weight.*`
  - real-model CUDA env inputs
- `Turboquant-CUDA` already exported:
  - paired multimodal fixture manifests
  - `text_model_path`
  - `mmproj_model_path`
  - `mmproj_required`
  - `modalities`
  - `sample_env`
- `llama.cpp` already carried:
  - mixed weight-plan metadata export flags
  - mmproj-aware model split support
  - weight selection regression coverage
- `Hypura` already carried:
  - `--mmproj`, `--image`, `--audio`
  - multimodal bridge
  - inspect / serve surfacing for weight-plan and mmproj requirements

## Alignment Work Done

- Updated `README.md` so the documented integrated `Hypura` pin matches the
  current `stack.lock.json` and submodule pointer:
  - `71ecaebf656020866f77356097d08aeef2734d15`
- Kept the rest of the public README wording intact because the M1 contract,
  verification paths, and paired-artifact story were already consistent with
  the current code.

## Verification Run

Focused verification run on 2026-04-18:

- `python C:\Users\downl\Desktop\triality-platform\repos\llama.cpp\tests\test_turboquant_weight_selection.py`
  - pass
- `python -m py_compile C:\Users\downl\Desktop\triality-platform\repos\llama.cpp\convert_hf_to_gguf.py C:\Users\downl\Desktop\triality-platform\repos\Turboquant-CUDA\turboquant\triality_contract.py C:\Users\downl\Desktop\triality-platform\repos\Turboquant-CUDA\scripts\export_triality_fixture.py`
  - pass
- `powershell -ExecutionPolicy Bypass -File C:\Users\downl\Desktop\triality-platform\ci\verify-stack.ps1`
  - pass

The fast verify run confirmed:

- Qwen and Gemma synthetic fixtures export and validate
- paired Gemma `mmproj` fixture semantics survive manifest validation
- `Hypura inspect` surfaces embedded weight-plan and multimodal requirements
- `Hypura serve --dry-run` accepts paired Gemma artifact wiring

## Remaining Gap

The only unresolved M1 gate is still the same real-asset CUDA acceptance
dependency. Full end-to-end CUDA smoke requires local values for:

- `TRIALITY_QWEN_SMOKE_MODEL`
- `TRIALITY_GEMMA_SMOKE_MODEL`
- `TRIALITY_GEMMA_MMPROJ_MODEL`
- `TRIALITY_GEMMA_IMAGE_SAMPLE`
- `TRIALITY_GEMMA_AUDIO_SAMPLE`

Those paths were not provided in this run, so the stack is aligned and
synthetic/CPU verified, but not yet closed on real-model CUDA evidence.
