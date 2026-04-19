# 2026-04-19 llama.cpp pin refresh on main (Codex)

## Overview

Updated the root repository to point `repos/llama.cpp` at the latest upstream
`master` commit and refreshed the public README plus lock file to match.

## Background / requirements

- The root README was still advertising an older `llama.cpp` pin.
- The parent lock file also referenced the older commit.
- The requested change was to make the README use the latest `llama.cpp`, but
  keeping only the README updated would have made the parent repo internally
  inconsistent.

## Assumptions / decisions

- Used the upstream `zapabob/llama.cpp` `master` head available on
  2026-04-19.
- Kept the rest of the stack unchanged.
- Limited the docs update to the pin references rather than rewriting any
  broader positioning text.

## Changed files

- `C:\Users\downl\Desktop\wt-triality-main-direct\README.md`
- `C:\Users\downl\Desktop\wt-triality-main-direct\stack\stack.lock.json`
- `C:\Users\downl\Desktop\wt-triality-main-direct\_docs\2026-04-19_llama-cpp-pin-refresh-main_Codex.md`
- submodule pointer: `C:\Users\downl\Desktop\wt-triality-main-direct\repos\llama.cpp`

## Implementation details

- Confirmed the upstream `master` head for `zapabob/llama.cpp` was
  `9276d42f45b152acfeead86d624cb43e062b5a5a`.
- Initialized the `repos/llama.cpp` submodule in the clean `main` worktree.
- Checked out the latest upstream `master` commit in the submodule.
- Updated the README short and full hash references to the new pin.
- Updated `stack/stack.lock.json` so the lock file stayed aligned with the
  README and submodule pointer.

## Commands run

- `git ls-remote https://github.com/zapabob/llama.cpp.git refs/heads/master`
- `git submodule update --init repos/llama.cpp`
- `git -C repos/llama.cpp fetch origin master`
- `git -C repos/llama.cpp log --oneline --max-count 3 origin/master`
- `git -C repos/llama.cpp checkout 9276d42f45b152acfeead86d624cb43e062b5a5a`

## Test / verification results

- Verified the upstream `master` head hash before changing the pin.
- Verified the root README and `stack.lock.json` now reference the same commit.
- No runtime or build tests were run because this change only updates the
  parent pin and documentation.

## Residual risks

- The parent repo now points to a newer `llama.cpp`, but the fast and CUDA
  verification lanes were not rerun in this turn.
- If downstream integration assumptions changed in the latest `llama.cpp`, that
  would only be caught by rerunning the stack verification scripts.

## Recommended next actions

- Run `ci/verify-stack.ps1` before making further pin updates.
- Rerun the Windows CUDA smoke lane if this new `llama.cpp` pin is intended to
  be the published operational baseline.
