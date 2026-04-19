$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
if (Get-Variable -Name PSNativeCommandUseErrorActionPreference -ErrorAction SilentlyContinue) {
  $global:PSNativeCommandUseErrorActionPreference = $false
}

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
$serveFailClosedLog = Join-Path $fixtureRoot "hypura-serve-fail-closed.log"

Write-Host "[triality] inspecting paper-faithful fixture"
& $hypuraBin inspect $paperFixture
Assert-LastExitCode "hypura inspect"

Write-Host "[triality] verifying Hypura fail-closed guard against contract-only weight runtime"
$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
  & $hypuraBin serve $paperFixture --dry-run --port 18080 *> $serveFailClosedLog
} finally {
  $ErrorActionPreference = $previousErrorActionPreference
}
if ($LASTEXITCODE -eq 0) {
  throw "hypura serve --dry-run unexpectedly succeeded without --tq-allow-exact-fallback"
}
if (-not (Select-String -Path $serveFailClosedLog -Pattern "allow-exact-fallback" -Quiet)) {
  throw "hypura serve --dry-run fail-closed log did not mention allow-exact-fallback"
}

Write-Host "[triality] serve dry-run against paper-faithful fixture with developer fallback"
& $hypuraBin serve $paperFixture --dry-run --port 18080 --tq-allow-exact-fallback
Assert-LastExitCode "hypura serve --dry-run"

Write-Host "[triality] benchmark dry-run against paper-faithful fixture with developer fallback"
& $hypuraBin bench $paperFixture --dry-run --context 512 --max-tokens 16 --tq-allow-exact-fallback
Assert-LastExitCode "hypura bench --dry-run"

Write-Host "[triality] stack verification complete"
