param(
  [string]$ModelPath = "",
  [string]$QwenModelPath = $env:TRIALITY_QWEN_SMOKE_MODEL,
  [string]$GemmaModelPath = $env:TRIALITY_GEMMA_SMOKE_MODEL,
  [string]$GemmaMmprojPath = $env:TRIALITY_GEMMA_MMPROJ_MODEL,
  [string]$GemmaImageSample = $env:TRIALITY_GEMMA_IMAGE_SAMPLE,
  [string]$GemmaAudioSample = $env:TRIALITY_GEMMA_AUDIO_SAMPLE,
  [string]$CudaArch = "86",
  [string]$Prompt = "Reply with exactly: Triality CUDA smoke ready.",
  [string]$QwenPrompt = "Reply with exactly: Triality Qwen CUDA smoke ready.",
  [string]$GemmaPrompt = "Reply with exactly: Triality Gemma CUDA smoke ready.",
  [int]$MaxTokens = 4,
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
$hypuraTargetDir = Join-Path $hypuraRoot "target-cuda"
$fixtureRoot = Join-Path $env:TEMP "triality-platform-fixtures"
$turboquantVenv = Join-Path $turboquantRoot ".venv"
$turboquantPythonScripts = Join-Path $turboquantVenv "Scripts"
$turboquantPython = Join-Path $turboquantPythonScripts "python.exe"

New-Item -ItemType Directory -Force -Path $logDir | Out-Null

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

function Assert-ValidSmokeModel {
  param(
    [Parameter(Mandatory = $true)][string]$Label,
    [Parameter(Mandatory = $true)][string]$Path
  )

  if (-not (Test-Path $Path)) {
    throw "$Label smoke model not found: $Path"
  }

  if (-not $Path.ToLowerInvariant().EndsWith(".gguf")) {
    throw "$Label smoke model must be a GGUF file: $Path"
  }
}

function Assert-ValidExistingFile {
  param(
    [Parameter(Mandatory = $true)][string]$Label,
    [Parameter(Mandatory = $true)][string]$Path
  )

  if (-not (Test-Path $Path)) {
    throw "$Label file not found: $Path"
  }
}

function Get-MimeType {
  param(
    [Parameter(Mandatory = $true)][string]$Path
  )

  switch ([System.IO.Path]::GetExtension($Path).ToLowerInvariant()) {
    ".png" { return "image/png" }
    ".jpg" { return "image/jpeg" }
    ".jpeg" { return "image/jpeg" }
    ".webp" { return "image/webp" }
    ".wav" { return "audio/wav" }
    ".mp3" { return "audio/mpeg" }
    ".flac" { return "audio/flac" }
    default { return "application/octet-stream" }
  }
}

function Get-DataUrl {
  param(
    [Parameter(Mandatory = $true)][string]$Path
  )

  $bytes = [System.IO.File]::ReadAllBytes($Path)
  $base64 = [System.Convert]::ToBase64String($bytes)
  $mime = Get-MimeType -Path $Path
  return "data:$mime;base64,$base64"
}

function Invoke-LlamaCudaSmoke {
  param(
    [Parameter(Mandatory = $true)][string]$Label,
    [Parameter(Mandatory = $true)][string]$ModelPath,
    [Parameter(Mandatory = $true)][string]$PromptText,
    [Parameter(Mandatory = $true)][string]$CompletionExe,
    [Parameter(Mandatory = $true)][string]$LogRoot,
    [Parameter(Mandatory = $true)][int]$ContextSize,
    [Parameter(Mandatory = $true)][int]$Tokens,
    [string]$MmprojPath,
    [string]$ImageSample,
    [string]$AudioSample,
    [string]$MtmdCliExe
  )

  $runtimeLog = Join-Path $LogRoot "llama-$Label-runtime.log"
  $smokeLog = Join-Path $LogRoot "llama-$Label-smoke.log"
  if ([string]::IsNullOrWhiteSpace($MmprojPath)) {
    Invoke-LoggedNative -Name "running llama.cpp CUDA smoke ($Label)" -LogPath $smokeLog -Script {
      & $CompletionExe `
        -m $ModelPath `
        -p $PromptText `
        -n $Tokens `
        -c $ContextSize `
        -ngl 1 `
        --simple-io `
        --no-warmup `
        --no-conversation `
        --no-display-prompt `
        -rea off `
        --log-file $runtimeLog `
        --log-verbosity 4
    }
  } else {
    Invoke-LoggedNative -Name "running llama.cpp multimodal CUDA smoke ($Label)" -LogPath $smokeLog -Script {
      & $MtmdCliExe `
        -m $ModelPath `
        --mmproj $MmprojPath `
        -p $PromptText `
        -n $Tokens `
        -c $ContextSize `
        -ngl 1 `
        --simple-io `
        --no-warmup `
        --no-conversation `
        --no-display-prompt `
        --reasoning-format none `
        --log-file $runtimeLog `
        --log-verbosity 4 `
        --image $ImageSample `
        --audio $AudioSample
    }
  }

  Assert-LogContains -LogPath $runtimeLog -Pattern "TurboQuant enabled via gguf" -Description "llama.cpp GGUF-embedded TurboQuant enable log ($Label)"
  Assert-LogContains -LogPath $runtimeLog -Pattern "Triality payload format=" -Description "llama.cpp Triality payload log ($Label)"
  Assert-LogContains -LogPath $runtimeLog -Pattern "offloaded [1-9][0-9]*/" -Description "llama.cpp non-zero GPU offload ($Label)"
  if ([string]::IsNullOrWhiteSpace($MmprojPath)) {
    Assert-LogContains -LogPath $smokeLog -Pattern "common_perf_print:" -Description "llama.cpp generation completion marker ($Label)"
  } else {
    Assert-LogContains -LogPath $smokeLog -Pattern "." -Description "llama.cpp multimodal generation output ($Label)"
  }
}

function Invoke-HypuraCudaSmoke {
  param(
    [Parameter(Mandatory = $true)][string]$Label,
    [Parameter(Mandatory = $true)][string]$ModelPath,
    [Parameter(Mandatory = $true)][string]$PromptText,
    [Parameter(Mandatory = $true)][string]$HypuraExe,
    [Parameter(Mandatory = $true)][string]$LogRoot,
    [Parameter(Mandatory = $true)][int]$ContextSize,
    [Parameter(Mandatory = $true)][int]$Tokens,
    [Parameter(Mandatory = $true)][string]$ExpectedWeightPolicy,
    [Parameter(Mandatory = $true)][string]$ExpectedModalityScope,
    [string]$MmprojPath,
    [string]$ImageSample,
    [string]$AudioSample
  )

  $inspectLog = Join-Path $LogRoot "hypura-$Label-inspect.log"
  $runLog = Join-Path $LogRoot "hypura-$Label-run.log"

  Invoke-LoggedNative -Name "running Hypura inspect ($Label)" -LogPath $inspectLog -Script {
    $args = @("inspect", $ModelPath)
    if (-not [string]::IsNullOrWhiteSpace($MmprojPath)) {
      $args += @("--mmproj", $MmprojPath)
    }
    & $HypuraExe @args
  }
  Assert-LogContains -LogPath $inspectLog -Pattern "Source: gguf-embedded" -Description "Hypura embedded GGUF source ($Label)"
  Assert-LogContains -LogPath $inspectLog -Pattern "Public mode:" -Description "Hypura Triality public mode ($Label)"
  Assert-LogContains -LogPath $inspectLog -Pattern [regex]::Escape($ExpectedWeightPolicy) -Description "Hypura weight policy summary ($Label)"
  Assert-LogContains -LogPath $inspectLog -Pattern [regex]::Escape("modality_scope=$ExpectedModalityScope") -Description "Hypura modality scope summary ($Label)"
  if (-not [string]::IsNullOrWhiteSpace($MmprojPath)) {
    Assert-LogContains -LogPath $inspectLog -Pattern "mmproj required: True|mmproj required: true" -Description "Hypura mmproj requirement summary ($Label)"
  }

  Invoke-LoggedNative -Name "running Hypura CUDA smoke ($Label)" -LogPath $runLog -Script {
    $args = @("run", $ModelPath, "--context", $ContextSize, "--prompt", $PromptText, "--max-tokens", $Tokens)
    if (-not [string]::IsNullOrWhiteSpace($MmprojPath)) {
      $args += @("--mmproj", $MmprojPath)
    }
    if (-not [string]::IsNullOrWhiteSpace($ImageSample)) {
      $args += @("--image", $ImageSample)
    }
    if (-not [string]::IsNullOrWhiteSpace($AudioSample)) {
      $args += @("--audio", $AudioSample)
    }
    & $HypuraExe @args
  }
  Assert-LogContains -LogPath $runLog -Pattern "TurboQuant:\s+mode=" -Description "Hypura TurboQuant runtime summary ($Label)"
  Assert-LogContains -LogPath $runLog -Pattern "Generation complete:" -Description "Hypura generation completion marker ($Label)"
  Assert-LogNotContains -LogPath $runLog -Pattern "TurboQuant runtime callback failed" -Description "Hypura TurboQuant runtime callback failure ($Label)"
}

function Start-HypuraServer {
  param(
    [Parameter(Mandatory = $true)][string]$Label,
    [Parameter(Mandatory = $true)][string]$HypuraExe,
    [Parameter(Mandatory = $true)][string]$ModelPath,
    [Parameter(Mandatory = $true)][int]$Port,
    [Parameter(Mandatory = $true)][int]$ContextSize,
    [Parameter(Mandatory = $true)][string]$LogRoot,
    [string]$MmprojPath
  )

  $stdoutLog = Join-Path $LogRoot "hypura-$Label-server.stdout.log"
  $stderrLog = Join-Path $LogRoot "hypura-$Label-server.stderr.log"
  $args = @("serve", $ModelPath, "--host", "127.0.0.1", "--port", $Port, "--context", $ContextSize)
  if (-not [string]::IsNullOrWhiteSpace($MmprojPath)) {
    $args += @("--mmproj", $MmprojPath)
  }

  Write-TrialityStep "starting Hypura server ($Label) on :$Port"
  $process = Start-Process -FilePath $HypuraExe -ArgumentList $args -PassThru -NoNewWindow -RedirectStandardOutput $stdoutLog -RedirectStandardError $stderrLog

  for ($attempt = 0; $attempt -lt 60; $attempt++) {
    if ($process.HasExited) {
      throw "Hypura server ($Label) exited early with code $($process.ExitCode). See $stdoutLog and $stderrLog"
    }
    try {
      Invoke-WebRequest -UseBasicParsing -Uri "http://127.0.0.1:$Port/api/tags" -TimeoutSec 2 | Out-Null
      return [pscustomobject]@{
        Process = $process
        StdoutLog = $stdoutLog
        StderrLog = $stderrLog
        Port = $Port
      }
    } catch {
      Start-Sleep -Seconds 1
    }
  }

  try {
    Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
  } catch {}
  throw "Timed out waiting for Hypura server ($Label) on port $Port"
}

function Stop-HypuraServer {
  param(
    [Parameter(Mandatory = $true)]$ServerHandle
  )

  if ($null -ne $ServerHandle.Process -and -not $ServerHandle.Process.HasExited) {
    try {
      Stop-Process -Id $ServerHandle.Process.Id -Force -ErrorAction SilentlyContinue
      Wait-Process -Id $ServerHandle.Process.Id -Timeout 10 -ErrorAction SilentlyContinue
    } catch {}
  }
}

function Invoke-OllamaChatServerSmoke {
  param(
    [Parameter(Mandatory = $true)][int]$Port,
    [Parameter(Mandatory = $true)][string]$PromptText,
    [Parameter(Mandatory = $true)][string]$LogPath,
    [string]$ImageSample
  )

  $message = @{
    role = "user"
    content = $PromptText
  }
  if (-not [string]::IsNullOrWhiteSpace($ImageSample)) {
    $message.images = @([System.Convert]::ToBase64String([System.IO.File]::ReadAllBytes($ImageSample)))
  }

  $body = @{
    model = "triality"
    stream = $false
    messages = @($message)
  } | ConvertTo-Json -Depth 8

  $response = Invoke-RestMethod -Method Post -Uri "http://127.0.0.1:$Port/api/chat" -ContentType "application/json" -Body $body
  $response | ConvertTo-Json -Depth 10 | Set-Content -Path $LogPath
  if ([string]::IsNullOrWhiteSpace($response.message.content)) {
    throw "Ollama-compatible chat smoke returned empty content. See $LogPath"
  }
}

function Invoke-OpenAiChatServerSmoke {
  param(
    [Parameter(Mandatory = $true)][int]$Port,
    [Parameter(Mandatory = $true)][string]$PromptText,
    [Parameter(Mandatory = $true)][string]$LogPath,
    [string]$ImageSample,
    [string]$AudioSample
  )

  if ([string]::IsNullOrWhiteSpace($ImageSample) -and [string]::IsNullOrWhiteSpace($AudioSample)) {
    $content = $PromptText
  } else {
    $content = @(@{
        type = "text"
        text = $PromptText
      })
    if (-not [string]::IsNullOrWhiteSpace($ImageSample)) {
      $content += @{
        type = "image_url"
        image_url = @{
          url = Get-DataUrl -Path $ImageSample
        }
      }
    }
    if (-not [string]::IsNullOrWhiteSpace($AudioSample)) {
      $content += @{
        type = "input_audio"
        input_audio = @{
          data = [System.Convert]::ToBase64String([System.IO.File]::ReadAllBytes($AudioSample))
          format = [System.IO.Path]::GetExtension($AudioSample).TrimStart('.').ToLowerInvariant()
        }
      }
    }
  }

  $body = @{
    model = "triality"
    stream = $false
    messages = @(@{
        role = "user"
        content = $content
      })
  } | ConvertTo-Json -Depth 12

  $response = Invoke-RestMethod -Method Post -Uri "http://127.0.0.1:$Port/v1/chat/completions" -ContentType "application/json" -Body $body
  $response | ConvertTo-Json -Depth 12 | Set-Content -Path $LogPath
  $text = $response.choices[0].message.content
  if ([string]::IsNullOrWhiteSpace($text)) {
    throw "OpenAI-compatible chat smoke returned empty content. See $LogPath"
  }
}

if ([string]::IsNullOrWhiteSpace($QwenModelPath)) {
  $QwenModelPath = $ModelPath
}
if ([string]::IsNullOrWhiteSpace($QwenModelPath)) {
  throw "Qwen model path is required. Set TRIALITY_QWEN_SMOKE_MODEL or pass -QwenModelPath."
}
if ($PSBoundParameters.ContainsKey("Prompt")) {
  $QwenPrompt = $Prompt
}

Require-Command uv
Require-Command cargo
Require-Command cmake
Require-Command nvidia-smi
Require-Command nvcc

$modelSpecs = @()
Assert-ValidSmokeModel -Label "Qwen" -Path $QwenModelPath
$modelSpecs += [pscustomobject]@{
  Label = "qwen"
  ModelPath = $QwenModelPath
  MmprojPath = $null
  ImageSample = $null
  AudioSample = $null
  PromptText = $QwenPrompt
  WeightPolicy = "qwen35-full-attention-ffn"
  ModalityScope = "text-only"
}

if (-not [string]::IsNullOrWhiteSpace($GemmaModelPath)) {
  Assert-ValidSmokeModel -Label "Gemma" -Path $GemmaModelPath
  if ([string]::IsNullOrWhiteSpace($GemmaMmprojPath)) {
    throw "Gemma mmproj path is required when Gemma smoke is enabled. Set TRIALITY_GEMMA_MMPROJ_MODEL or pass -GemmaMmprojPath."
  }
  if ([string]::IsNullOrWhiteSpace($GemmaImageSample)) {
    throw "Gemma image sample is required when Gemma smoke is enabled. Set TRIALITY_GEMMA_IMAGE_SAMPLE or pass -GemmaImageSample."
  }
  if ([string]::IsNullOrWhiteSpace($GemmaAudioSample)) {
    throw "Gemma audio sample is required when Gemma smoke is enabled. Set TRIALITY_GEMMA_AUDIO_SAMPLE or pass -GemmaAudioSample."
  }
  Assert-ValidSmokeModel -Label "Gemma mmproj" -Path $GemmaMmprojPath
  Assert-ValidExistingFile -Label "Gemma image sample" -Path $GemmaImageSample
  Assert-ValidExistingFile -Label "Gemma audio sample" -Path $GemmaAudioSample
  $modelSpecs += [pscustomobject]@{
    Label = "gemma"
    ModelPath = $GemmaModelPath
    MmprojPath = $GemmaMmprojPath
    ImageSample = $GemmaImageSample
    AudioSample = $GemmaAudioSample
    PromptText = $GemmaPrompt
    WeightPolicy = "gemma4-e4b-shared-decoder-hybrid"
    ModalityScope = "full-multimodal"
  }
} else {
  Write-TrialityStep "Gemma model path not provided; set TRIALITY_GEMMA_SMOKE_MODEL or pass -GemmaModelPath for full two-model CUDA acceptance."
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
  powershell -ExecutionPolicy Bypass -File (Join-Path $turboquantRoot "scripts\bootstrap_uv.ps1") -SkipSyncIfCudaReady
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
  cmake --build $llamaBuildDir --config Release --target llama-cli llama-completion llama-server llama-turboquant llama-mtmd-cli --parallel
}

$llamaCli = Get-BuiltExecutable -Root $llamaBuildDir -Name "llama-cli.exe"
$llamaCompletion = Get-BuiltExecutable -Root $llamaBuildDir -Name "llama-completion.exe"
$llamaServer = Get-BuiltExecutable -Root $llamaBuildDir -Name "llama-server.exe"
$llamaTurboquant = Get-BuiltExecutable -Root $llamaBuildDir -Name "llama-turboquant.exe"
$mtmdCli = Get-BuiltExecutable -Root $llamaBuildDir -Name "llama-mtmd-cli.exe"
$smokeContext = 512

Set-Content -Path (Join-Path $logDir "llama-binaries.txt") -Value @(
  "llama-cli=$llamaCli"
  "llama-completion=$llamaCompletion"
  "llama-server=$llamaServer"
  "llama-turboquant=$llamaTurboquant"
  "llama-mtmd-cli=$mtmdCli"
)

foreach ($spec in $modelSpecs) {
  Invoke-LlamaCudaSmoke `
    -Label $spec.Label `
    -ModelPath $spec.ModelPath `
    -PromptText $spec.PromptText `
    -CompletionExe $llamaCompletion `
    -LogRoot $logDir `
    -ContextSize $smokeContext `
    -Tokens $MaxTokens `
    -MmprojPath $spec.MmprojPath `
    -ImageSample $spec.ImageSample `
    -AudioSample $spec.AudioSample `
    -MtmdCliExe $mtmdCli
}

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

foreach ($spec in $modelSpecs) {
  Invoke-HypuraCudaSmoke `
    -Label $spec.Label `
    -ModelPath $spec.ModelPath `
    -PromptText $spec.PromptText `
    -HypuraExe $hypuraBin `
    -LogRoot $logDir `
    -ContextSize $smokeContext `
    -Tokens $MaxTokens `
    -ExpectedWeightPolicy $spec.WeightPolicy `
    -ExpectedModalityScope $spec.ModalityScope `
    -MmprojPath $spec.MmprojPath `
    -ImageSample $spec.ImageSample `
    -AudioSample $spec.AudioSample
}

$qwenServer = $null
$gemmaServer = $null
try {
  $qwenServer = Start-HypuraServer `
    -Label "qwen" `
    -HypuraExe $hypuraBin `
    -ModelPath $QwenModelPath `
    -Port 18100 `
    -ContextSize $smokeContext `
    -LogRoot $logDir

  Invoke-OllamaChatServerSmoke `
    -Port 18100 `
    -PromptText $QwenPrompt `
    -LogPath (Join-Path $logDir "hypura-qwen-ollama-chat.json")

  Invoke-OpenAiChatServerSmoke `
    -Port 18100 `
    -PromptText $QwenPrompt `
    -LogPath (Join-Path $logDir "hypura-qwen-openai-chat.json")

  $gemmaSpec = $modelSpecs | Where-Object { $_.Label -eq "gemma" } | Select-Object -First 1
  if ($null -ne $gemmaSpec) {
    $gemmaServer = Start-HypuraServer `
      -Label "gemma" `
      -HypuraExe $hypuraBin `
      -ModelPath $gemmaSpec.ModelPath `
      -MmprojPath $gemmaSpec.MmprojPath `
      -Port 18101 `
      -ContextSize $smokeContext `
      -LogRoot $logDir

    Invoke-OllamaChatServerSmoke `
      -Port 18101 `
      -PromptText $gemmaSpec.PromptText `
      -ImageSample $gemmaSpec.ImageSample `
      -LogPath (Join-Path $logDir "hypura-gemma-ollama-chat.json")

    Invoke-OpenAiChatServerSmoke `
      -Port 18101 `
      -PromptText $gemmaSpec.PromptText `
      -ImageSample $gemmaSpec.ImageSample `
      -AudioSample $gemmaSpec.AudioSample `
      -LogPath (Join-Path $logDir "hypura-gemma-openai-chat.json")
  }
} finally {
  if ($null -ne $qwenServer) {
    Stop-HypuraServer -ServerHandle $qwenServer
  }
  if ($null -ne $gemmaServer) {
    Stop-HypuraServer -ServerHandle $gemmaServer
  }
}

Write-TrialityStep "CUDA stack verification complete"
Write-TrialityStep "logs: $logDir"
