# Date
2026-04-18

# Task
Reflect latest `zapabob/llama.cpp`, `zapabob/Turboquant-CUDA`, and `zapabob/hypura`

# Author
Codex

## Overview

This update moves the parent `triality-platform` repo from the previously pinned
integration-branch commits to the latest merged default-branch heads of the
three child repositories.

## Background And Requirements

The user asked to reflect the latest state of:

- `zapabob/llama.cpp`
- `zapabob/Turboquant-CUDA`
- `zapabob/hypura`

Because "latest" is time-sensitive, the current default-branch heads were
verified against the live GitHub commit pages before changing the parent repo.

## Decisions

- Use the merged default branches now that the Triality Platform child PRs have
  landed:
  - `Turboquant-CUDA`: `main`
  - `llama.cpp`: `master`
  - `hypura`: `main`
- Update only the parent-repo pin surfaces:
  - submodule pointers
  - `stack/stack.lock.json`
  - README pin display
- Leave prior implementation logs untouched, because they are historical
  records of earlier branch-based coordination.

## Latest Verified Upstream Heads

- `zapabob/Turboquant-CUDA` `main`: `9c0df98b820a9264cff1a13245e4b1b9dc74c0df`
- `zapabob/llama.cpp` `master`: `0357e9be3066c6b27dcc82e6404d7fd4a190d924`
- `zapabob/hypura` `main`: `9fceb2d54f359a6f256f63919f6960d026c4e869`

## Changed Files

- `C:\Users\downl\Desktop\triality-platform\README.md`
- `C:\Users\downl\Desktop\triality-platform\stack\stack.lock.json`
- `C:\Users\downl\Desktop\triality-platform\_docs\2026-04-18_latest-upstream-sync_Codex.md`

## Implementation Details

- Fast-forwarded each child submodule worktree to the current default branch:
  - `repos/Turboquant-CUDA` -> `main`
  - `repos/llama.cpp` -> `master`
  - `repos/hypura` -> `main`
- Updated the parent lock file so branch names and commit SHAs now match the
  merged upstream state rather than the previously used
  `codex/triality-platform-sync` branch.
- Updated the README pin section so the public repo front page matches the
  actual submodule state.
- Updated the parent fast-verify scripts and contract files to follow the
  latest upstream canonical pareto mode name `triality-proxy-so8-pareto` while
  keeping `triality-so8-pareto` documented as a legacy alias.

## Commands Run

```text
git -C C:\Users\downl\Desktop\triality-platform status --short --branch
git -C C:\Users\downl\Desktop\triality-platform submodule status
Get-Content C:\Users\downl\Desktop\triality-platform\stack\stack.lock.json
gh repo view zapabob/Turboquant-CUDA --json defaultBranchRef,url,nameWithOwner
gh repo view zapabob/llama.cpp --json defaultBranchRef,url,nameWithOwner
gh repo view zapabob/hypura --json defaultBranchRef,url,nameWithOwner
git -C C:\Users\downl\Desktop\triality-platform\repos\Turboquant-CUDA fetch origin
git -C C:\Users\downl\Desktop\triality-platform\repos\Turboquant-CUDA switch main
git -C C:\Users\downl\Desktop\triality-platform\repos\Turboquant-CUDA pull --ff-only origin main
git -C C:\Users\downl\Desktop\triality-platform\repos\llama.cpp fetch origin
git -C C:\Users\downl\Desktop\triality-platform\repos\llama.cpp switch master
git -C C:\Users\downl\Desktop\triality-platform\repos\llama.cpp pull --ff-only origin master
git -C C:\Users\downl\Desktop\triality-platform\repos\hypura fetch origin
git -C C:\Users\downl\Desktop\triality-platform\repos\hypura switch main
git -C C:\Users\downl\Desktop\triality-platform\repos\hypura pull --ff-only origin main
git -C C:\Users\downl\Desktop\triality-platform grep -n -E "codex/triality-platform-sync|7601de3|df30ff9|618d4d4" -- . ":(exclude)repos/*"
powershell -ExecutionPolicy Bypass -File C:\Users\downl\Desktop\triality-platform\ci\verify-stack.ps1
```

## Verification Results

- Parent repo correctly shows updated submodule pointers after the fast-forward.
- `git submodule status` resolves to:
  - `repos/Turboquant-CUDA`: `9c0df98`
  - `repos/llama.cpp`: `0357e9b`
  - `repos/hypura`: `9fceb2d`
- README and `stack.lock.json` were updated to match those exact commits.
- The first post-sync verify run exposed a legacy-alias mismatch between
  `triality-so8-pareto` and the latest canonical mode
  `triality-proxy-so8-pareto`, so the parent fast-verify and contract docs were
  updated accordingly.
- A fresh rerun of `ci/verify-stack.ps1` completed successfully after the mode
  normalization fix:
  - fixture export passed for `paper-faithful` and `triality-proxy-so8-pareto`
  - manifest validation passed for both exported bundles
  - `hypura inspect` resolved embedded metadata for the paper-faithful fixture
  - `hypura serve --dry-run` and `hypura bench --dry-run` completed without
    terminating the stack verify pipeline

## Residual Risks

- This change updates pins and parent fast-verify wiring. Full CUDA verification
  still needs to be rerun separately if release evidence must be refreshed.
- In the current fast-verify output, the synthetic pareto fixture still logs a
  `Hypura serve` warning and falls back to `mode=exact` during dry-run. The
  stack verify exits successfully, but that warning should be revisited before
  treating synthetic-fixture serve behavior as a release-grade proof point.
- If a future sync depends on non-fast-forward reconciliation, that should be
  handled as a separate integration task rather than a simple pin refresh.

## Recommended Next Actions

- Run `ci/verify-stack.ps1` to reconfirm the parent repo against the new merged
  upstream pins.
- If CUDA runtime behavior changed upstream, run `ci/verify-stack-cuda.ps1`
  before treating this pin set as release-ready.
