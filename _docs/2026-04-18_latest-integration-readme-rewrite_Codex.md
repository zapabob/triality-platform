# Date
2026-04-18

# Task
Reflect the latest `zapabob/llama.cpp`, `zapabob/Turboquant-CUDA`, and
`zapabob/hypura`, then rewrite the parent README

# Author
Codex

## Overview

This pass does two things together:

- refresh the parent repo to the newest live upstream heads
- rewrite the README so it reads like an integrated platform instead of a
  submodule index

## Latest Verified Upstream Heads

- `zapabob/Turboquant-CUDA` `main`: `8b8465bd6c358fca79e61eb5aa73540021d2fcfc`
- `zapabob/llama.cpp` `master`: `0357e9be3066c6b27dcc82e6404d7fd4a190d924`
- `zapabob/hypura` `main`: `95bc0010c0e51a426c8aaae2ab77c4db1a94fbe6`

## Why Rewrite The README

The previous README already had the right facts, but it still read as a
collection of sections. The new version is organized around the integration
story:

1. what Triality Platform is
2. why the parent repo exists
3. how the three repos fit together
4. what users can actually do with the stack
5. how to verify it

## Changed Files

- `C:\Users\downl\Desktop\triality-platform\README.md`
- `C:\Users\downl\Desktop\triality-platform\stack\stack.lock.json`
- `C:\Users\downl\Desktop\triality-platform\_docs\2026-04-18_latest-integration-readme-rewrite_Codex.md`

## Implementation Details

- Fast-forwarded:
  - `repos/Turboquant-CUDA` to `main@8b8465b`
  - `repos/hypura` to `main@95bc001`
  - `repos/llama.cpp` remained at `master@0357e9b`
- Updated `stack.lock.json` to the new upstream SHAs.
- Rewrote the README around:
  - a clearer platform pitch
  - an integrated stack table
  - a cleaner end-to-end flow diagram
  - explicit verification lanes
  - a current parent-lock section that mirrors the actual pin set

## Commands Run

```text
git -C C:\Users\downl\Desktop\triality-platform status --short --branch
gh repo view zapabob/Turboquant-CUDA --json defaultBranchRef,nameWithOwner,url
gh repo view zapabob/llama.cpp --json defaultBranchRef,nameWithOwner,url
gh repo view zapabob/hypura --json defaultBranchRef,nameWithOwner,url
gh api repos/zapabob/Turboquant-CUDA/commits/main --jq .sha
gh api repos/zapabob/llama.cpp/commits/master --jq .sha
gh api repos/zapabob/hypura/commits/main --jq .sha
git -C C:\Users\downl\Desktop\triality-platform\repos\Turboquant-CUDA fetch origin
git -C C:\Users\downl\Desktop\triality-platform\repos\Turboquant-CUDA switch main
git -C C:\Users\downl\Desktop\triality-platform\repos\Turboquant-CUDA pull --ff-only origin main
git -C C:\Users\downl\Desktop\triality-platform\repos\hypura fetch origin
git -C C:\Users\downl\Desktop\triality-platform\repos\hypura switch main
git -C C:\Users\downl\Desktop\triality-platform\repos\hypura pull --ff-only origin main
git -C C:\Users\downl\Desktop\triality-platform\repos\llama.cpp fetch origin
git -C C:\Users\downl\Desktop\triality-platform\repos\llama.cpp switch master
git -C C:\Users\downl\Desktop\triality-platform\repos\llama.cpp pull --ff-only origin master
```

## Verification Plan

- `git diff --check`
- `ci/verify-stack.ps1`
- `git status --short --branch`
- `git submodule status`

## Verification Results

- `git diff --check` completed without patch-format errors.
- A fresh `ci/verify-stack.ps1` run passed on the updated pin set.
- Fast verify confirmed:
  - `Turboquant-CUDA` fixture export for `paper-faithful` and
    `triality-proxy-so8-pareto`
  - manifest validation for both bundles
  - `Hypura inspect` on the paper-faithful fixture
  - `Hypura serve --dry-run` on the paper-faithful fixture
  - `Hypura bench --dry-run` on the paper-faithful fixture

## Residual Risks

- Upstream moved again for `Turboquant-CUDA` and `hypura`, so any previously
  captured CUDA evidence is historically valid but not a proof of the newest
  pin set.
- If release-grade confidence is required, rerun the CUDA smoke lane after this
  pin refresh.
- Current upstream `Turboquant-CUDA` exports the canonical pareto mode
  `triality-proxy-so8-pareto`, while `Hypura serve` dry-run is more reliable on
  the paper-faithful synthetic fixture. The parent fast-verify lane therefore
  validates proxy fixture export and manifest integrity, but uses the
  paper-faithful fixture for `Hypura` CLI smoke.
