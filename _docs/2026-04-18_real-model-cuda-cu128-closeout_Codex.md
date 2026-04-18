# 2026-04-18 M1 Real-Model CUDA Acceptance `cu128` Alignment

## Summary

Aligned the remaining M1 real-model CUDA acceptance wording and runner behavior
to the latest `Turboquant-CUDA` `uv` environment with PyTorch `cu128`.

## What Changed

- made `ci/verify-stack-cuda.ps1` pass `-TorchExtra cu128` explicitly to
  `repos/Turboquant-CUDA/scripts/bootstrap_uv.ps1`
- updated README wording so the CUDA lane is described as `Turboquant-CUDA`
  `uv` plus canonical PyTorch `cu128`
- updated the public integration contract and release playbook to treat
  `cu128` as the standardized real-model CUDA lane

## Why

The code path already matched the latest `Turboquant-CUDA` default, but the
contract was still partly implicit. This change makes the release-facing
environment requirement explicit and removes ambiguity about which CUDA Python
lane is authoritative for M1 acceptance.

## Verification

- `python C:\Users\downl\Desktop\triality-platform\repos\llama.cpp\tests\test_turboquant_weight_selection.py`
- `python -m py_compile C:\Users\downl\Desktop\triality-platform\repos\llama.cpp\convert_hf_to_gguf.py C:\Users\downl\Desktop\triality-platform\repos\Turboquant-CUDA\turboquant\triality_contract.py C:\Users\downl\Desktop\triality-platform\repos\Turboquant-CUDA\scripts\export_triality_fixture.py`
- `powershell -ExecutionPolicy Bypass -File C:\Users\downl\Desktop\triality-platform\ci\verify-stack.ps1`

## Remaining Blocker

Full real-model CUDA acceptance still requires concrete local values for:

- `TRIALITY_QWEN_SMOKE_MODEL`
- `TRIALITY_GEMMA_SMOKE_MODEL`
- `TRIALITY_GEMMA_MMPROJ_MODEL`
- `TRIALITY_GEMMA_IMAGE_SAMPLE`
- `TRIALITY_GEMMA_AUDIO_SAMPLE`
