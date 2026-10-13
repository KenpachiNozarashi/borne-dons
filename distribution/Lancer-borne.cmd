@echo off
setlocal
set "BORNE_DIR=%~dp0"
if not exist "%BORNE_DIR%app\borne_dons.exe" (
  echo Application introuvable. Extraire toute l'archive avant de lancer la borne.
  echo Dossier attendu : %BORNE_DIR%app
  pause
  exit /b 1
)
if exist "%BORNE_DIR%logo-service\logo-service.exe" (
  start "Detourage local" /min /D "%BORNE_DIR%logo-service" "%BORNE_DIR%logo-service\logo-service.exe"
) else (
  echo Service de detourage introuvable. L'application peut fonctionner sans detourage.
)
start "Borne de dons" /D "%BORNE_DIR%app" "%BORNE_DIR%app\borne_dons.exe"
if errorlevel 1 (
  echo Le lancement a echoue. Essayez app\borne_dons.exe et transmettez ce message.
  pause
)
endlocal
