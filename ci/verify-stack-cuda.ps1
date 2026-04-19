param(
  [string]$ModelPath = "C:\Users\downl\Desktop\EasyNovelAssistant\EasyNovelAssistant\KoboldCpp\Qwen3.5-9B-Uncensored-HauhauCS-Aggressive-Q8_0.turboquant.gguf",
  [string]$CudaArch = "86",
  [string]$Prompt = "Reply with exactly: Triality CUDA smoke ready.",
  [int]$MaxTokens = 4,
  [string]$HypuraTargetDir,
  [switch]$SkipBaseVerify
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
if (Get-Variable -Name PSNativeCommandUseErrorActionPreference -ErrorAction SilentlyContinue) {
  $global:PSNativeCommandUseErrorActionPreference = $false
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$lockPath = Join-Path $repoRoot "stack\stack.lock.json"
$turboquantRoot = Join-Path $repoRoot "repos\Turboquant-CUDA"
$llamaRoot = Join-Path $repoRoot "repos\llama.cpp"
$hypuraRoot = Join-Path $repoRoot "repos\hypura"
$artifactRoot = Join-Path $repoRoot "artifacts\cuda-smoke"
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$logDir = Join-Path $artifactRoot $timestamp
$llamaBuildDir = Join-Path $llamaRoot "build-triality-cuda"
$defaultHypuraTargetDir = Join-Path $hypuraRoot "target-cuda"
$fixtureRoot = Join-Path $env:TEMP "triality-platform-fixtures"
$turboquantVenv = Join-Path $turboquantRoot ".venv"
$turboquantPythonScripts = Join-Path $turboquantVenv "Scripts"
$turboquantPython = Join-Path $turboquantPythonScripts "python.exe"

New-Item -ItemType Directory -Force -Path $logDir | Out-Null

function Resolve-HypuraTargetDir {
  param(
    [Parameter(Mandatory = $true)][string]$DefaultPath,
    [string]$RequestedPath
  )

  if (-not [string]::IsNullOrWhiteSpace($RequestedPath)) {
    return $RequestedPath
  }

  if (-not [string]::IsNullOrWhiteSpace($env:TRIALITY_HYPURA_TARGET_DIR)) {
    return $env:TRIALITY_HYPURA_TARGET_DIR
  }

  $cDrive = Get-PSDrive -Name C -ErrorAction SilentlyContinue
  $fDrive = Get-PSDrive -Name F -ErrorAction SilentlyContinue
  if ($cDrive -and $cDrive.Free -lt 10GB -and $fDrive -and $fDrive.Free -gt 8GB) {
    return "F:\triality-targets\hypura-cuda"
  }

  return $DefaultPath
}

$hypuraTargetDir = Resolve-HypuraTargetDir -DefaultPath $defaultHypuraTargetDir -RequestedPath $HypuraTargetDir
New-Item -ItemType Directory -Force -Path $hypuraTargetDir | Out-Null

function Write-TrialityStep {
  param([Parameter(Mandatory = $true)][string]$Message)
  Write-Host "[triality-cuda] $Message"
}

function Invoke-LoggedNative {
  param(
    [Parameter(Mandatory = $true)][string]$Name,
    [Parameter(Mandatory = $true)][string]$LogPath,
    [Parameter(Mandatory = $true)][scriptblock]$Script
  )

  Write-TrialityStep $Name
  $previousErrorActionPreference = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  try {
    & $Script 2>&1 | Tee-Object -FilePath $LogPath
    if ($LASTEXITCODE -ne 0) {
      throw "$Name failed with exit code $LASTEXITCODE. See $LogPath"
    }
  } finally {
    $ErrorActionPreference = $previousErrorActionPreference
  }
}

function Require-Command {
  param([Parameter(Mandatory = $true)][string]$Name)
  if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
    throw "Required command not found: $Name"
  }
}

function Get-VcVars64Path {
  $candidates = @(
    "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat",
    "C:\Program Files\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat",
    "C:\Program Files (x86)\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat",
    "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat"
  )

  foreach ($candidate in $candidates) {
    if (Test-Path $candidate) {
      return $candidate
    }
  }

  throw "vcvars64.bat not found. Install Visual Studio 2022 Build Tools with MSVC."
}

function Import-VcVarsEnvironment {
  param([Parameter(Mandatory = $true)][string]$LogPath)

  $vcvarsPath = Get-VcVars64Path
  Write-TrialityStep "importing MSVC environment from $vcvarsPath"
  $dump = & cmd /d /s /c "call `"$vcvarsPath`" >nul && set" 2>&1
  if ($LASTEXITCODE -ne 0) {
    $dump | Tee-Object -FilePath $LogPath | Out-Null
    throw "Failed to import MSVC environment. See $LogPath"
  }
  $dump | Tee-Object -FilePath $LogPath | Out-Null
  foreach ($line in $dump) {
    if ($line -match "^([^=]+)=(.*)$") {
      [System.Environment]::SetEnvironmentVariable($matches[1], $matches[2], "Process")
    }
  }
}

function Get-BuiltExecutable {
  param(
    [Parameter(Mandatory = $true)][string]$Root,
    [Parameter(Mandatory = $true)][string]$Name
  )

  $candidate = Get-ChildItem -Path $Root -Recurse -File -Filter $Name -ErrorAction SilentlyContinue |
    Sort-Object FullName |
    Select-Object -First 1
  if ($null -eq $candidate) {
    throw "Could not find built executable '$Name' under $Root"
  }
  return $candidate.FullName
}

function Assert-LogContains {
  param(
    [Parameter(Mandatory = $true)][string]$LogPath,
    [Parameter(Mandatory = $true)][string]$Pattern,
    [Parameter(Mandatory = $true)][string]$Description
  )

  if (-not (Select-String -Path $LogPath -Pattern $Pattern -Quiet)) {
    throw "Expected $Description in $LogPath"
  }
}

function Assert-LogNotContains {
  param(
    [Parameter(Mandatory = $true)][string]$LogPath,
    [Parameter(Mandatory = $true)][string]$Pattern,
    [Parameter(Mandatory = $true)][string]$Description
  )

  if (Select-String -Path $LogPath -Pattern $Pattern -Quiet) {
    throw "Unexpected $Description in $LogPath"
  }
}

Require-Command uv
Require-Command cargo
Require-Command cmake
Require-Command nvidia-smi
Require-Command nvcc

if (-not (Test-Path $ModelPath)) {
  throw "Smoke model not found: $ModelPath"
}

if (-not $ModelPath.ToLowerInvariant().EndsWith(".gguf")) {
  throw "Smoke model must be a GGUF file: $ModelPath"
}

Write-TrialityStep "verifying submodule status"
git -C $repoRoot submodule status --recursive | Tee-Object -FilePath (Join-Path $logDir "submodules.log") | Out-Null

Write-TrialityStep "checking pinned revisions from stack.lock.json"
$lock = Get-Content $lockPath -Raw | ConvertFrom-Json
foreach ($repoName in @("hypura", "Turboquant-CUDA", "llama.cpp")) {
  $expected = $lock.repos.$repoName.commit
  $actual = (git -C (Join-Path $repoRoot "repos\$repoName") rev-parse HEAD).Trim()
  if ($actual -ne $expected) {
    throw "Submodule revision mismatch for $repoName. expected=$expected actual=$actual"
  }
}

Invoke-LoggedNative -Name "capturing CUDA toolchain info" -LogPath (Join-Path $logDir "toolchain.log") -Script {
  nvidia-smi
  nvcc --version
}

if (-not $SkipBaseVerify) {
  Invoke-LoggedNative -Name "running fast stack verify" -LogPath (Join-Path $logDir "verify-stack.log") -Script {
    powershell -ExecutionPolicy Bypass -File (Join-Path $repoRoot "ci\verify-stack.ps1")
  }
}

Invoke-LoggedNative -Name "bootstrapping Turboquant-CUDA uv environment" -LogPath (Join-Path $logDir "bootstrap-uv.log") -Script {
  powershell -ExecutionPolicy Bypass -File (Join-Path $turboquantRoot "scripts\bootstrap_uv.ps1") -TorchExtra cu128 -SkipSyncIfCudaReady
}

Invoke-LoggedNative -Name "running Turboquant-CUDA env_check" -LogPath (Join-Path $logDir "env-check.log") -Script {
  $env:TURBOQUANT_ENV_CHECK_PATH = Join-Path $logDir "turboquant-env-check.txt"
  Push-Location $turboquantRoot
  try {
    uv run python scripts\env_check.py
  } finally {
    Pop-Location
    Remove-Item Env:TURBOQUANT_ENV_CHECK_PATH -ErrorAction SilentlyContinue
  }
}

$env:PYTHONPATH = $turboquantRoot
$env:PYTHONNOUSERSITE = "1"
$env:HYPURA_TURBOQUANT_RUNTIME = "rust"
if (Test-Path $turboquantPython) {
  $env:VIRTUAL_ENV = $turboquantVenv
  if (-not $env:PATH.StartsWith("$turboquantPythonScripts;")) {
    $env:PATH = "$turboquantPythonScripts;$env:PATH"
  }
}

Invoke-LoggedNative -Name "verifying Turboquant runtime python import path" -LogPath (Join-Path $logDir "turboquant-python-import.log") -Script {
  python -c "import turboquant.rotation as r; print(r.__file__)"
}
Assert-LogContains -LogPath (Join-Path $logDir "turboquant-python-import.log") -Pattern "Turboquant-CUDA" -Description "Turboquant runtime python import path"

Import-VcVarsEnvironment -LogPath (Join-Path $logDir "vcvars.log")
Require-Command cl

Invoke-LoggedNative -Name "configuring llama.cpp CUDA build" -LogPath (Join-Path $logDir "llama-cmake-configure.log") -Script {
  & cmake -S $llamaRoot -B $llamaBuildDir -G "Visual Studio 17 2022" -A x64 `
    "-DBUILD_SHARED_LIBS=OFF" `
    "-DGGML_BLAS=OFF" `
    "-DGGML_CUDA=ON" `
    "-DGGML_METAL=OFF" `
    "-DGGML_OPENMP=ON" `
    "-DLLAMA_BUILD_SERVER=ON" `
    "-DLLAMA_BUILD_TESTS=OFF" `
    "-DLLAMA_BUILD_EXAMPLES=OFF" `
    "-DCMAKE_CUDA_ARCHITECTURES=$($CudaArch)"
}

Invoke-LoggedNative -Name "building llama.cpp CUDA targets" -LogPath (Join-Path $logDir "llama-cmake-build.log") -Script {
  cmake --build $llamaBuildDir --config Release --target llama-cli llama-completion llama-server llama-turboquant --parallel
}

$llamaCli = Get-BuiltExecutable -Root $llamaBuildDir -Name "llama-cli.exe"
$llamaCompletion = Get-BuiltExecutable -Root $llamaBuildDir -Name "llama-completion.exe"
$llamaServer = Get-BuiltExecutable -Root $llamaBuildDir -Name "llama-server.exe"
$llamaTurboquant = Get-BuiltExecutable -Root $llamaBuildDir -Name "llama-turboquant.exe"
$llamaCompletionRuntimeLog = Join-Path $logDir "llama-completion-runtime.log"
$smokeContext = 512

Set-Content -Path (Join-Path $logDir "llama-binaries.txt") -Value @(
  "llama-cli=$llamaCli"
  "llama-completion=$llamaCompletion"
  "llama-server=$llamaServer"
  "llama-turboquant=$llamaTurboquant"
)

Invoke-LoggedNative -Name "running llama.cpp CUDA smoke" -LogPath (Join-Path $logDir "llama-completion-smoke.log") -Script {
  & $llamaCompletion `
    -m $ModelPath `
    -p $Prompt `
    -n $MaxTokens `
    -c $smokeContext `
    -ngl 1 `
    --simple-io `
    --no-warmup `
    --no-conversation `
    --no-display-prompt `
    -rea off `
    --log-file $llamaCompletionRuntimeLog `
    --log-verbosity 4
}

Assert-LogContains -LogPath $llamaCompletionRuntimeLog -Pattern "hypura\.turboquant\.enabled bool\s+= true" -Description "llama.cpp GGUF-embedded TurboQuant enable metadata"
Assert-LogContains -LogPath $llamaCompletionRuntimeLog -Pattern "hypura\.turboquant\.payload_format str\s+= json-inline-v1" -Description "llama.cpp Triality payload metadata"
Assert-LogContains -LogPath $llamaCompletionRuntimeLog -Pattern "offloaded [1-9][0-9]*/" -Description "llama.cpp non-zero GPU offload"
Assert-LogContains -LogPath (Join-Path $logDir "llama-completion-smoke.log") -Pattern "common_perf_print:" -Description "llama.cpp generation completion marker"

Remove-Item Env:HYPURA_NO_CUDA -ErrorAction SilentlyContinue
$env:HYPURA_LLAMA_CPP_PATH = $llamaRoot
$env:HYPURA_CUDA_ARCHITECTURES = $CudaArch
$env:CARGO_TARGET_DIR = $hypuraTargetDir

Invoke-LoggedNative -Name "building Hypura CUDA binary" -LogPath (Join-Path $logDir "hypura-cargo-build.log") -Script {
  cargo build --manifest-path (Join-Path $hypuraRoot "Cargo.toml") --bin hypura
}

$hypuraBin = Join-Path $hypuraTargetDir "debug\hypura.exe"
if (-not (Test-Path $hypuraBin)) {
  throw "Expected Hypura binary not found: $hypuraBin"
}

Invoke-LoggedNative -Name "running Hypura inspect" -LogPath (Join-Path $logDir "hypura-inspect.log") -Script {
  & $hypuraBin inspect $ModelPath
}

Assert-LogContains -LogPath (Join-Path $logDir "hypura-inspect.log") -Pattern "Source: gguf-embedded" -Description "Hypura embedded GGUF source"
Assert-LogContains -LogPath (Join-Path $logDir "hypura-inspect.log") -Pattern "Public mode:" -Description "Hypura Triality public mode"

Invoke-LoggedNative -Name "running Hypura CUDA smoke" -LogPath (Join-Path $logDir "hypura-run.log") -Script {
  & $hypuraBin run $ModelPath --context $smokeContext --prompt $Prompt --max-tokens $MaxTokens --tq-allow-exact-fallback
}

Assert-LogContains -LogPath (Join-Path $logDir "hypura-run.log") -Pattern "TurboQuant:\s+mode=" -Description "Hypura TurboQuant runtime summary"
Assert-LogContains -LogPath (Join-Path $logDir "hypura-run.log") -Pattern "Generation complete:" -Description "Hypura generation completion marker"
Assert-LogNotContains -LogPath (Join-Path $logDir "hypura-run.log") -Pattern "TurboQuant runtime callback failed" -Description "Hypura TurboQuant runtime callback failure"

Write-TrialityStep "CUDA stack verification complete"
Write-TrialityStep "logs: $logDir"
