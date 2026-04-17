#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fixture_root="${TMPDIR:-/tmp}/triality-platform-fixtures"
lock_path="$repo_root/stack/stack.lock.json"
turboquant_root="$repo_root/repos/Turboquant-CUDA"

uv_run_python() {
  (
    cd "$turboquant_root"
    uv run python "$@"
  )
}

echo "[triality] verifying submodule status"
git -C "$repo_root" submodule status --recursive

echo "[triality] checking pinned revisions from stack.lock.json"
uv_run_python - "$repo_root" "$lock_path" <<'PY'
import json
import pathlib
import subprocess
import sys

repo_root = pathlib.Path(sys.argv[1])
lock_path = pathlib.Path(sys.argv[2])
lock = json.loads(lock_path.read_text(encoding="utf-8"))

for repo_name in ("hypura", "Turboquant-CUDA", "llama.cpp"):
    expected = lock["repos"][repo_name]["commit"]
    actual = subprocess.check_output(
        ["git", "-C", str(repo_root / "repos" / repo_name), "rev-parse", "HEAD"],
        text=True,
    ).strip()
    if actual != expected:
        raise SystemExit(
            f"Submodule revision mismatch for {repo_name}: expected={expected} actual={actual}"
        )
PY

echo "[triality] bootstrapping Turboquant-CUDA uv environment (CPU fast verify)"
bash "$turboquant_root/scripts/bootstrap_uv.sh" --torch-extra cpu --skip-hf-qwen

echo "[triality] exporting fixtures"
uv_run_python scripts/export_triality_fixture.py \
  --output-dir "$fixture_root" \
  --mode paper-faithful
uv_run_python scripts/export_triality_fixture.py \
  --output-dir "$fixture_root" \
  --mode triality-so8-pareto

echo "[triality] validating exported manifests"
uv_run_python scripts/verify_triality_export.py \
  --manifest "$fixture_root/paper-faithful/triality-fixture-manifest.json"
uv_run_python scripts/verify_triality_export.py \
  --manifest "$fixture_root/triality-so8-pareto/triality-fixture-manifest.json"

echo "[triality] building hypura against external llama.cpp (CPU-only smoke)"
export HYPURA_LLAMA_CPP_PATH="$repo_root/repos/llama.cpp"
export HYPURA_NO_CUDA=1
cargo build --manifest-path "$repo_root/repos/hypura/Cargo.toml" --bin hypura

hypura_bin="$repo_root/repos/hypura/target/debug/hypura"
paper_fixture="$fixture_root/paper-faithful/triality-fixture.gguf"
pareto_fixture="$fixture_root/triality-so8-pareto/triality-fixture.gguf"

echo "[triality] inspecting paper-faithful fixture"
"$hypura_bin" inspect "$paper_fixture"

echo "[triality] serve dry-run against triality-so8-pareto fixture"
"$hypura_bin" serve "$pareto_fixture" --dry-run --port 18080

echo "[triality] benchmark dry-run against paper-faithful fixture"
"$hypura_bin" bench "$paper_fixture" --dry-run --context 512 --max-tokens 16

echo "[triality] stack verification complete"
