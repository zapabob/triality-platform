$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = Split-Path -Parent $PSScriptRoot
$fixtureRoot = Join-Path $env:TEMP "triality-platform-fixtures"
$qwenFixtureRoot = Join-Path $fixtureRoot "qwen35"
$gemmaFixtureRoot = Join-Path $fixtureRoot "gemma4-e4b"
$lockPath = Join-Path $repoRoot "stack\stack.lock.json"
$turboquantRoot = Join-Path $repoRoot "repos\Turboquant-CUDA"
$paretoMode = "triality-proxy-so8-pareto"
$qwenModelFamily = "huihui-ai/Huihui-Qwen3.5-9B-Claude-4.6-Opus-abliterated"
$gemmaModelFamily = "Jiunsong/supergemma4-e4b-abliterated"

function Invoke-TurboquantUvPython {
  param(
    [Parameter(Mandatory = $true)]
    [string[]]$Arguments
  )

  Push-Location $turboquantRoot
  try {
    & uv run python @Arguments
    if ($LASTEXITCODE -ne 0) {
      throw "uv run python failed with exit code $LASTEXITCODE"
    }
  } finally {
    Pop-Location
  }
}

function Assert-LastExitCode {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Context
  )

  if ($LASTEXITCODE -ne 0) {
    throw "$Context failed with exit code $LASTEXITCODE"
  }
}

Write-Host "[triality] verifying submodule status"
git -C $repoRoot submodule status --recursive

Write-Host "[triality] checking pinned revisions from stack.lock.json"
$lock = Get-Content $lockPath -Raw | ConvertFrom-Json
foreach ($repoName in @("hypura", "Turboquant-CUDA", "llama.cpp")) {
  $expected = $lock.repos.$repoName.commit
  $actual = (git -C (Join-Path $repoRoot "repos\$repoName") rev-parse HEAD).Trim()
  if ($actual -ne $expected) {
    throw "Submodule revision mismatch for $repoName. expected=$expected actual=$actual"
  }
}

Write-Host "[triality] bootstrapping Turboquant-CUDA uv environment (CPU fast verify)"
& powershell -ExecutionPolicy Bypass -File (Join-Path $turboquantRoot "scripts\bootstrap_uv.ps1") `
  -TorchExtra cpu `
  -SkipHfQwen
Assert-LastExitCode "Turboquant-CUDA uv bootstrap"

Write-Host "[triality] exporting fixtures"
Invoke-TurboquantUvPython @(
  "scripts\export_triality_fixture.py",
  "--output-dir",
  $qwenFixtureRoot,
  "--mode",
  "paper-faithful",
  "--model-family",
  $qwenModelFamily
)
Invoke-TurboquantUvPython @(
  "scripts\export_triality_fixture.py",
  "--output-dir",
  $qwenFixtureRoot,
  "--mode",
  $paretoMode,
  "--model-family",
  $qwenModelFamily
)
Invoke-TurboquantUvPython @(
  "scripts\export_triality_fixture.py",
  "--output-dir",
  $gemmaFixtureRoot,
  "--mode",
  "paper-faithful",
  "--model-family",
  $gemmaModelFamily,
  "--modality-scope",
  "full-multimodal"
)
Invoke-TurboquantUvPython @(
  "scripts\export_triality_fixture.py",
  "--output-dir",
  $gemmaFixtureRoot,
  "--mode",
  $paretoMode,
  "--model-family",
  $gemmaModelFamily,
  "--modality-scope",
  "full-multimodal"
)

Write-Host "[triality] validating exported manifests"
Invoke-TurboquantUvPython @(
  "scripts\verify_triality_export.py",
  "--manifest",
  (Join-Path $qwenFixtureRoot "paper-faithful\triality-fixture-manifest.json")
)
Invoke-TurboquantUvPython @(
  "scripts\verify_triality_export.py",
  "--manifest",
  (Join-Path $qwenFixtureRoot "$paretoMode\triality-fixture-manifest.json")
)
Invoke-TurboquantUvPython @(
  "scripts\verify_triality_export.py",
  "--manifest",
  (Join-Path $gemmaFixtureRoot "paper-faithful\triality-fixture-manifest.json")
)
Invoke-TurboquantUvPython @(
  "scripts\verify_triality_export.py",
  "--manifest",
  (Join-Path $gemmaFixtureRoot "$paretoMode\triality-fixture-manifest.json")
)

Write-Host "[triality] building hypura against external llama.cpp (CPU-only smoke)"
$env:HYPURA_LLAMA_CPP_PATH = Join-Path $repoRoot "repos\llama.cpp"
$env:HYPURA_NO_CUDA = "1"
cmd /c "cargo build --manifest-path ""$(Join-Path $repoRoot "repos\hypura\Cargo.toml")"" --bin hypura"

$hypuraBin = Join-Path $repoRoot "repos\hypura\target\debug\hypura.exe"
$qwenPaperFixture = Join-Path $qwenFixtureRoot "paper-faithful\triality-fixture.gguf"
$qwenParetoFixture = Join-Path $qwenFixtureRoot "$paretoMode\triality-fixture.gguf"
$gemmaPaperFixture = Join-Path $gemmaFixtureRoot "paper-faithful\triality-fixture.gguf"
$gemmaParetoFixture = Join-Path $gemmaFixtureRoot "$paretoMode\triality-fixture.gguf"
$gemmaPaperMmproj = Join-Path $gemmaFixtureRoot "paper-faithful\mmproj-triality-fixture.gguf"
$gemmaParetoMmproj = Join-Path $gemmaFixtureRoot "$paretoMode\mmproj-triality-fixture.gguf"

Write-Host "[triality] inspecting qwen paper-faithful fixture"
& $hypuraBin inspect $qwenPaperFixture
Assert-LastExitCode "hypura inspect (qwen)"

Write-Host "[triality] inspecting gemma paper-faithful fixture"
& $hypuraBin inspect $gemmaPaperFixture --mmproj $gemmaPaperMmproj
Assert-LastExitCode "hypura inspect (gemma)"

Write-Host "[triality] inspecting qwen $paretoMode fixture"
& $hypuraBin inspect $qwenParetoFixture
Assert-LastExitCode "hypura inspect (qwen pareto)"

Write-Host "[triality] inspecting gemma $paretoMode fixture"
& $hypuraBin inspect $gemmaParetoFixture --mmproj $gemmaParetoMmproj
Assert-LastExitCode "hypura inspect (gemma pareto)"

Write-Host "[triality] serve dry-run against qwen paper-faithful fixture"
& $hypuraBin serve $qwenPaperFixture --dry-run --port 18080
Assert-LastExitCode "hypura serve --dry-run (qwen)"

Write-Host "[triality] serve dry-run against gemma paper-faithful fixture"
& $hypuraBin serve $gemmaPaperFixture --mmproj $gemmaPaperMmproj --dry-run --port 18081
Assert-LastExitCode "hypura serve --dry-run (gemma)"

Write-Host "[triality] serve dry-run against qwen $paretoMode fixture"
& $hypuraBin serve $qwenParetoFixture --dry-run --port 18082
Assert-LastExitCode "hypura serve --dry-run (qwen pareto)"

Write-Host "[triality] serve dry-run against gemma $paretoMode fixture"
& $hypuraBin serve $gemmaParetoFixture --mmproj $gemmaParetoMmproj --dry-run --port 18083
Assert-LastExitCode "hypura serve --dry-run (gemma pareto)"

Write-Host "[triality] benchmark dry-run against qwen paper-faithful fixture"
& $hypuraBin bench $qwenPaperFixture --dry-run --context 512 --max-tokens 16
Assert-LastExitCode "hypura bench --dry-run (qwen)"

Write-Host "[triality] stack verification complete"
