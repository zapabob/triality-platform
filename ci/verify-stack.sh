#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fixture_root="${TMPDIR:-/tmp}/triality-platform-fixtures"
qwen_fixture_root="$fixture_root/qwen35"
gemma_fixture_root="$fixture_root/gemma4-e4b"
lock_path="$repo_root/stack/stack.lock.json"
turboquant_root="$repo_root/repos/Turboquant-CUDA"
pareto_mode="triality-proxy-so8-pareto"
qwen_model_family="huihui-ai/Huihui-Qwen3.5-9B-Claude-4.6-Opus-abliterated"
gemma_model_family="Jiunsong/supergemma4-e4b-abliterated"

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
  --output-dir "$qwen_fixture_root" \
  --mode paper-faithful \
  --model-family "$qwen_model_family"
uv_run_python scripts/export_triality_fixture.py \
  --output-dir "$qwen_fixture_root" \
  --mode "$pareto_mode" \
  --model-family "$qwen_model_family"
uv_run_python scripts/export_triality_fixture.py \
  --output-dir "$gemma_fixture_root" \
  --mode paper-faithful \
  --model-family "$gemma_model_family" \
  --modality-scope full-multimodal
uv_run_python scripts/export_triality_fixture.py \
  --output-dir "$gemma_fixture_root" \
  --mode "$pareto_mode" \
  --model-family "$gemma_model_family" \
  --modality-scope full-multimodal

echo "[triality] validating exported manifests"
uv_run_python scripts/verify_triality_export.py \
  --manifest "$qwen_fixture_root/paper-faithful/triality-fixture-manifest.json"
uv_run_python scripts/verify_triality_export.py \
  --manifest "$qwen_fixture_root/$pareto_mode/triality-fixture-manifest.json"
uv_run_python scripts/verify_triality_export.py \
  --manifest "$gemma_fixture_root/paper-faithful/triality-fixture-manifest.json"
uv_run_python scripts/verify_triality_export.py \
  --manifest "$gemma_fixture_root/$pareto_mode/triality-fixture-manifest.json"

echo "[triality] building hypura against external llama.cpp (CPU-only smoke)"
export HYPURA_LLAMA_CPP_PATH="$repo_root/repos/llama.cpp"
export HYPURA_NO_CUDA=1
cargo build --manifest-path "$repo_root/repos/hypura/Cargo.toml" --bin hypura

hypura_bin="$repo_root/repos/hypura/target/debug/hypura"
qwen_paper_fixture="$qwen_fixture_root/paper-faithful/triality-fixture.gguf"
qwen_pareto_fixture="$qwen_fixture_root/$pareto_mode/triality-fixture.gguf"
gemma_paper_fixture="$gemma_fixture_root/paper-faithful/triality-fixture.gguf"
gemma_pareto_fixture="$gemma_fixture_root/$pareto_mode/triality-fixture.gguf"
gemma_paper_mmproj="$gemma_fixture_root/paper-faithful/mmproj-triality-fixture.gguf"
gemma_pareto_mmproj="$gemma_fixture_root/$pareto_mode/mmproj-triality-fixture.gguf"

echo "[triality] inspecting qwen paper-faithful fixture"
"$hypura_bin" inspect "$qwen_paper_fixture"

echo "[triality] inspecting gemma paper-faithful fixture"
"$hypura_bin" inspect "$gemma_paper_fixture" --mmproj "$gemma_paper_mmproj"

echo "[triality] inspecting qwen $pareto_mode fixture"
"$hypura_bin" inspect "$qwen_pareto_fixture"

echo "[triality] inspecting gemma $pareto_mode fixture"
"$hypura_bin" inspect "$gemma_pareto_fixture" --mmproj "$gemma_pareto_mmproj"

echo "[triality] serve dry-run against qwen paper-faithful fixture"
"$hypura_bin" serve "$qwen_paper_fixture" --dry-run --port 18080

echo "[triality] serve dry-run against gemma paper-faithful fixture"
"$hypura_bin" serve "$gemma_paper_fixture" --mmproj "$gemma_paper_mmproj" --dry-run --port 18081

echo "[triality] serve dry-run against qwen $pareto_mode fixture"
"$hypura_bin" serve "$qwen_pareto_fixture" --dry-run --port 18082

echo "[triality] serve dry-run against gemma $pareto_mode fixture"
"$hypura_bin" serve "$gemma_pareto_fixture" --mmproj "$gemma_pareto_mmproj" --dry-run --port 18083

echo "[triality] benchmark dry-run against qwen paper-faithful fixture"
"$hypura_bin" bench "$qwen_paper_fixture" --dry-run --context 512 --max-tokens 16

echo "[triality] stack verification complete"
