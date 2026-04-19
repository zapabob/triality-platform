# 2026-04-19 README rewrite for main (Codex)

## Overview

Rewrote the root `README.md` on `main` to read like a product-facing landing
page instead of an internal integration memo.

## Background / requirements

- The README needed to reflect the stack as implemented today.
- The copy needed to be English only.
- The top-level pitch needed to be clearer and more attractive to first-time
  GitHub visitors without overstating unfinished runtime work.

## Assumptions / decisions

- Kept the README aligned to the current `main` branch state, not the dirty
  development worktree.
- Removed PC-local launcher guidance from the top-level README because it is
  useful for operators on this machine but not strong landing-page material for
  the public repo.
- Kept the CUDA claims conservative because the current CUDA script is a smoke
  path that still expects a local model path.

## Changed files

- `C:\Users\downl\Desktop\wt-triality-main-direct\README.md`
- `C:\Users\downl\Desktop\wt-triality-main-direct\_docs\2026-04-19_readme-rewrite-main_Codex.md`

## Implementation details

- Replaced the old README structure with a stronger opening pitch, a concise
  explanation of the three-repo stack, and a quick-start-first reading flow.
- Added a clearer verification story that distinguishes the self-contained fast
  lane from the current Windows CUDA smoke lane.
- Retained the public contract language around `hypura.turboquant.*` while
  moving low-signal local-machine details out of the landing page.
- Updated the pin table and lock section to match the current `main` lock file.

## Commands run

- `git fetch origin main`
- `git status --short --branch`
- `Get-Content README.md`
- `Get-Content stack/stack.lock.json`
- `Select-String ci/verify-stack.ps1 ...`
- `Select-String ci/verify-stack-cuda.ps1 ...`
- `git diff -- README.md`

## Test / verification results

- Verified the rewritten README content against the current `main` branch lock
  file and current verification scripts.
- No build or runtime tests were required for this documentation-only change.

## Residual risks

- If the verification scripts or pinned child repos move again, the README pin
  table and verification summary will need another refresh.
- The README intentionally keeps the CUDA description conservative; future
  self-contained CUDA artifact flow should be documented once it is actually on
  `main`.

## Recommended next actions

- Push this README rewrite to `origin/main`.
- Refresh the screenshots or add a minimal architecture image later if the repo
  needs a stronger visual first impression.
