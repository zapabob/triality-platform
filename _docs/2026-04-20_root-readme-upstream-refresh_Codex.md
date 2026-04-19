# 2026-04-20 Root README Upstream Refresh

## Goal

Refresh the root `main` branch so the parent repo reflects the latest tracked
upstream state for:

- `zapabob/Turboquant-CUDA`
- `zapabob/llama.cpp`
- `zapabob/hypura`

Then rewrite the root `README.md` in English with a more star-friendly landing
page structure while keeping the branch and verification story honest.

## Upstream Snapshot

Checked on 2026-04-20 (JST):

- `Turboquant-CUDA main`: `f3a44c378c00d19eb7429b26a4fdb0a7e11a71e9`
- `hypura main`: `e5d1191a2c094d6accb33ddc6149687327be16f6`
- `llama.cpp master`: `1da7f961034f55bef96676f2cd14a9641bfe7dbf`
- `llama.cpp main`: `6d701037568da4808d2e26bb19560799a1ae739b`

Operational choice kept in the parent lock:

- track `llama.cpp master`, not `main`, because the parent repo still treats
  `master` as the validated compatibility anchor

## Changes Made

- advanced root submodule gitlinks to:
  - `repos/Turboquant-CUDA -> f3a44c3`
  - `repos/hypura -> e5d1191`
  - `repos/llama.cpp -> 1da7f96`
- updated `stack/stack.lock.json` to the same commits
- rewrote the root `README.md` to:
  - lead with the integration value proposition
  - present current upstream freshness with explicit dates and commits
  - keep the verification order visible
  - explain why `llama.cpp main` is not yet the parent lock

## Verification Plan

Executed after edit:

- `git submodule status`
- `pwsh -File .\ci\verify-stack.ps1`
- `git diff --check`

## Verification Results

- `git submodule status`: confirmed root gitlinks now point to:
  - `Turboquant-CUDA -> f3a44c3`
  - `hypura -> e5d1191`
  - `llama.cpp -> 1da7f96`
- `powershell -ExecutionPolicy Bypass -File .\ci\verify-stack.ps1`: passed
  after updating the parent verify lane for the newer Hypura fail-closed
  behavior around contract-only weight metadata
- `git diff --check`: clean apart from expected Windows LF/CRLF warnings

Not run in this change:

- `ci/verify-stack-cuda.ps1`
  - updated for the newer developer fallback flag
  - not executed here because it still requires a local CUDA smoke GGUF path
