$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = Split-Path -Parent $PSScriptRoot
$fixtureRoot = Join-Path $env:TEMP "triality-platform-fixtures"
$lockPath = Join-Path $repoRoot "stack\stack.lock.json"
$turboquantRoot = Join-Path $repoRoot "repos\Turboquant-CUDA"
$paretoMode = "triality-proxy-so8-pareto"

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
if ($LASTEXITCODE -ne 0) {
  throw "Turboquant-CUDA uv bootstrap failed with exit code $LASTEXITCODE"
}

Write-Host "[triality] exporting fixtures"
Invoke-TurboquantUvPython @(
  "scripts\export_triality_fixture.py",
  "--output-dir",
  $fixtureRoot,
  "--mode",
  "paper-faithful"
)
Invoke-TurboquantUvPython @(
  "scripts\export_triality_fixture.py",
  "--output-dir",
  $fixtureRoot,
  "--mode",
  $paretoMode
)

Write-Host "[triality] validating exported manifests"
Invoke-TurboquantUvPython @(
  "scripts\verify_triality_export.py",
  "--manifest",
  (Join-Path $fixtureRoot "paper-faithful\triality-fixture-manifest.json")
)
Invoke-TurboquantUvPython @(
  "scripts\verify_triality_export.py",
  "--manifest",
  (Join-Path $fixtureRoot "$paretoMode\triality-fixture-manifest.json")
)

Write-Host "[triality] building hypura against external llama.cpp (CPU-only smoke)"
$env:HYPURA_LLAMA_CPP_PATH = Join-Path $repoRoot "repos\llama.cpp"
$env:HYPURA_NO_CUDA = "1"
cmd /c "cargo build --manifest-path ""$(Join-Path $repoRoot "repos\hypura\Cargo.toml")"" --bin hypura"

$hypuraBin = Join-Path $repoRoot "repos\hypura\target\debug\hypura.exe"
$paperFixture = Join-Path $fixtureRoot "paper-faithful\triality-fixture.gguf"
$paretoFixture = Join-Path $fixtureRoot "$paretoMode\triality-fixture.gguf"

Write-Host "[triality] inspecting paper-faithful fixture"
& $hypuraBin inspect $paperFixture

Write-Host "[triality] serve dry-run against $paretoMode fixture"
& $hypuraBin serve $paretoFixture --dry-run --port 18080

Write-Host "[triality] benchmark dry-run against paper-faithful fixture"
& $hypuraBin bench $paperFixture --dry-run --context 512 --max-tokens 16

Write-Host "[triality] stack verification complete"
