@echo off
setlocal
cd /d "%~dp0"
title MECHA OVERDRIVE - Circuit Zero
set "PORT=8080"

echo.
echo ================================================
echo   MECHA OVERDRIVE - CIRCUIT ZERO 1.0.0
echo ================================================
echo Le lanceur choisit un port local disponible et ouvre le jeu.
echo Conservez cette fenetre ouverte pendant la partie.
echo.

where node >nul 2>nul
if not errorlevel 1 goto :node

where py >nul 2>nul
if not errorlevel 1 goto :py

where python >nul 2>nul
if not errorlevel 1 goto :python

echo Node.js et Python 3 sont absents.
echo Ouverture directe de index.html ; le cache PWA sera indisponible.
start "" "%~dp0index.html"
pause
goto :end

:node
set "PORT=%PORT%"
node tools\server.mjs --open
goto :end

:py
py -3 tools\serve.py --port %PORT%
goto :end

:python
python tools\serve.py --port %PORT%

:end
endlocal
