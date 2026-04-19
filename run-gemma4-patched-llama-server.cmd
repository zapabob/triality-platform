@echo off
setlocal

set "LLAMA_SERVER=F:\triality-targets\llama-gemma-mtmd\bin\Release\llama-server.exe"
set "MODEL=C:\Users\downl\Desktop\SO8T\gguf_models\HauhauCS\Gemma-4-E4B-Uncensored-HauhauCS-Aggressive\Gemma-4-E4B-Uncensored-HauhauCS-Aggressive-Q8_K_P.gguf"
set "MMPROJ=C:\Users\downl\Desktop\SO8T\gguf_models\HauhauCS\Gemma-4-E4B-Uncensored-HauhauCS-Aggressive\mmproj-Gemma-4-E4B-Uncensored-HauhauCS-Aggressive-f16.gguf"
set "HOST=127.0.0.1"
set "PORT=8094"

if not exist "%LLAMA_SERVER%" (
  echo llama-server.exe not found:
  echo   %LLAMA_SERVER%
  exit /b 1
)

if not exist "%MODEL%" (
  echo model GGUF not found:
  echo   %MODEL%
  exit /b 1
)

if not exist "%MMPROJ%" (
  echo mmproj GGUF not found:
  echo   %MMPROJ%
  exit /b 1
)

echo Starting patched Gemma 4 server on http://%HOST%:%PORT%
"%LLAMA_SERVER%" ^
  -m "%MODEL%" ^
  --mmproj "%MMPROJ%" ^
  --host %HOST% ^
  --port %PORT% ^
  --ctx-size 2048 ^
  --no-warmup

endlocal
