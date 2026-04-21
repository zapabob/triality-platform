# 2026-04-22 Root Stack Upstream Refresh

## Goal

Refresh the parent `triality-platform` main line so it reflects the latest
tracked upstream state from:

- `zapabob/Turboquant-CUDA`
- `zapabob/llama.cpp`
- `zapabob/hypura`

## Upstream Snapshot

Checked on 2026-04-22 (JST):

- `Turboquant-CUDA main`: `59d5acf039b89582d68feab8c736039f9ea5289a`
- `hypura main`: `94bb8556dda78be04f29b51b0b79c5adfb8b75dd`
- `llama.cpp master`: `f62f191123772652a7d45ff8d37628a9e55ee7c3`
- `llama.cpp main`: `00459dd29fe9e981c8ce902706b7585e03bbf02d`

## Changes Made

- advanced root submodule gitlinks to:
  - `repos/Turboquant-CUDA -> 59d5acf`
  - `repos/hypura -> 94bb855`
  - `repos/llama.cpp -> f62f191`
- updated `stack/stack.lock.json`
- refreshed the root README snapshot date, commit table, and "What is fresh"
  section so the landing page matches the newer upstream state

## Current Branch Policy

The parent repo still keeps `zapabob/llama.cpp master` as the operational lock
anchor, even though upstream `main` remains ahead. This run did not change that
policy; it only refreshed the current tracked tips.

## Verification Plan

- `git submodule status`
- `powershell -ExecutionPolicy Bypass -File .\ci\verify-stack.ps1`
- `git diff --check`

## Verification Results

- `git submodule status`: confirmed root gitlinks now point to:
  - `Turboquant-CUDA -> 59d5acf`
  - `hypura -> 94bb855`
  - `llama.cpp -> f62f191`
- `powershell -ExecutionPolicy Bypass -File .\ci\verify-stack.ps1`: passed on
  the refreshed stack
- `git diff --check`: pending at log-write time; expected next before commit
