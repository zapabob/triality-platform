# Date
2026-04-17

# Task
README architecture flow, CUDA snapshot, and child-repo PR cross-links

# Author
Codex

## Overview

This change set makes the public repository pitch stronger and easier to scan:

- add an architecture/flow diagram to `README.md`
- add a compact CUDA smoke snapshot with real evidence from the latest passing run
- open child-repository PRs and wire them together with cross-reference links

## Background And Requirements

The user asked for three follow-up actions after the public Triality Platform
repo was already live:

1. add an architecture or flow diagram to the README
2. add a CUDA verify log summary or benchmark snapshot to the README
3. open PRs for the child repositories and add mutual reference links

## Decisions

- Keep the README pitch concise and public-facing.
- Use Mermaid in the parent README so the repo front page explains the
  research-to-runtime handoff without requiring extra images.
- Treat CUDA numbers as a smoke snapshot, not a synthetic benchmark claim.
- Use the existing pushed child-repo branches `codex/triality-platform-sync`
  and open PRs against the remote default branch of each repository.
- Put cross-links in PR bodies instead of hard-coding unstable PR URLs into the
  repository documentation.

## Files Changed

- `C:\Users\downl\Desktop\triality-platform\README.md`
- `C:\Users\downl\Desktop\triality-platform\_docs\2026-04-17_readme-architecture-cuda-pr-links_Codex.md`

## Evidence Sources

- `C:\Users\downl\Desktop\triality-platform\artifacts\cuda-smoke\20260417-011313\llama-completion-runtime.log`
- `C:\Users\downl\Desktop\triality-platform\artifacts\cuda-smoke\20260417-011313\llama-completion-smoke.log`
- `C:\Users\downl\Desktop\triality-platform\artifacts\cuda-smoke\20260417-011313\hypura-inspect.log`
- `C:\Users\downl\Desktop\triality-platform\artifacts\cuda-smoke\20260417-011313\hypura-run.log`

## Implementation Notes

- The architecture diagram shows the single GGUF embedded contract crossing all
  layers of the stack: research/export, inference-core, operations/runtime, and
  release verification.
- The CUDA snapshot keeps only operationally meaningful facts:
  - embedded GGUF metadata is detected
  - CUDA device selection succeeds
  - `llama.cpp` minimal-offload smoke completes
  - `Hypura` consumes the same GGUF and completes its runtime path
- Child-repo PR bodies will point at:
  - the public parent repository
  - the sibling child-repo PRs
  - the role each repo plays in the Triality Platform stack

## Child PR URLs

- `zapabob/Turboquant-CUDA`: https://github.com/zapabob/Turboquant-CUDA/pull/3
- `zapabob/llama.cpp`: https://github.com/zapabob/llama.cpp/pull/7
- `zapabob/hypura`: https://github.com/zapabob/hypura/pull/2

## Commands Run

```text
git -C C:\Users\downl\Desktop\triality-platform status --short --branch
Get-ChildItem C:\Users\downl\Desktop\triality-platform\artifacts\cuda-smoke
Select-String -Path ...\llama-completion-smoke.log -Pattern ...
Select-String -Path ...\llama-completion-runtime.log -Pattern ...
Select-String -Path ...\hypura-inspect.log -Pattern ...
Select-String -Path ...\hypura-run.log -Pattern ...
gh auth status
gh pr list --repo <repo> --head codex/triality-platform-sync --json ...
gh pr create --repo zapabob/Turboquant-CUDA --base main --head codex/triality-platform-sync ...
gh pr create --repo zapabob/llama.cpp --base master --head codex/triality-platform-sync ...
gh pr create --repo zapabob/hypura --base main --head codex/triality-platform-sync ...
gh pr edit <number> --repo <repo> --body-file <temp file>
```

## Verification Plan

- `git diff --check`
- inspect staged README content with line numbers
- confirm child PR creation via `gh pr view`
- confirm parent push via `git status --short --branch` and `git log --oneline -1`

## Remaining Risks

- README performance figures are intentionally a smoke snapshot; they should not
  be presented externally as a benchmark suite.
- PR cross-links depend on the PR numbers assigned at creation time, so the
  implementation log should be updated with final URLs before commit.

## Recommended Next Actions

- If the public repo needs a more visual front page later, add an architecture
  image or benchmark chart generated from structured artifacts.
- If the child PRs get reviewed independently, mirror the accepted PR URLs into
  release-facing notes or a tracking issue instead of the README itself.
