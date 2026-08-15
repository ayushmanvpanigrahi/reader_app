@echo off
setlocal
set "PROJECT_ROOT=%~dp0.."

echo [1/4] Checking Qdrant (needed for RAG)...
powershell -NoProfile -Command "$c = New-Object Net.Sockets.TcpClient; try { $c.Connect('localhost',6333); exit 0 } catch { exit 1 } finally { $c.Dispose() }" >nul
if errorlevel 1 (
  if exist "%PROJECT_ROOT%\backend\tools\qdrant\qdrant.exe" (
    echo  Starting local Qdrant binary...
    start "ReaderApp Qdrant" "%PROJECT_ROOT%\backend\tools\qdrant\qdrant.exe"
  ) else (
    where docker >nul 2>nul
    if errorlevel 1 (
      echo  ! Qdrant is not running and no local binary or Docker found.
      echo  ! RAG will not work until you start Qdrant on port 6333.
    ) else (
      echo  Starting Qdrant container...
      docker run -d --name reader-qdrant -p 6333:6333 -p 6334:6334 qdrant/qdrant >nul 2>nul
    )
  )
) else (
  echo  Qdrant already running on port 6333.
)

echo [2/4] Starting FastAPI Backend...
start "ReaderApp Backend" cmd /k "cd /d ""%PROJECT_ROOT%\backend"" && .venv\Scripts\python -m uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload"

echo [3/4] Waiting for backend to start...
timeout /t 3 /nobreak >nul

echo [4/4] Starting Flutter App...
cd /d "%PROJECT_ROOT%"
flutter run
