@echo off
setlocal EnableExtensions
cd /d "%~dp0"
title LastCircle - teste LOCAL do cliente Survev em Lua
echo.
echo =========================================================
echo LASTCIRCLE - TESTE VISUAL LOCAL SEM SERVIDOR
echo =========================================================
echo.
echo Este programa abre o cliente Lua REAL no LÖVE 2D.
echo Nao inicia Moo-Quest e NAO necessita de token ou internet.
echo.
if not exist "%~dp0LastCircle-Lua.love" (
  echo [ERRO] LastCircle-Lua.love nao encontrado ao lado deste BAT.
  echo Extraia TODOS os arquivos do ZIP na mesma pasta.
  pause
  exit /b 1
)
set "LOVEEXE="
if exist "%~dp0love.exe" set "LOVEEXE=%~dp0love.exe"
if not defined LOVEEXE if exist "%ProgramFiles%\LOVE\love.exe" set "LOVEEXE=%ProgramFiles%\LOVE\love.exe"
if not defined LOVEEXE if exist "%ProgramFiles(x86)%\LOVE\love.exe" set "LOVEEXE=%ProgramFiles(x86)%\LOVE\love.exe"
if not defined LOVEEXE for %%L in (love.exe) do if not "%%~$PATH:L"=="" set "LOVEEXE=%%~$PATH:L"
if not defined LOVEEXE (
  echo [ERRO] LÖVE2D nao encontrado.
  echo Instale LÖVE2D 11.5 em https://love2d.org/
  echo Depois execute novamente TESTAR-LASTCIRCLE-WINDOWS.bat.
  pause
  exit /b 1
)
echo [OK] Abrindo TESTE OFFLINE do Survev Lua...
echo [CONTROLES] WASD andar - mouse mirar - F porta.
echo [CONTROLES] F5 reiniciar - F6 rede real - F7 artes - ESC sair.
echo.
"%LOVEEXE%" "%~dp0LastCircle-Lua.love"
set "CODE=%ERRORLEVEL%"
if not "%CODE%"=="0" (
  echo.
  echo [ERRO] O cliente fechou com erro %CODE%.
  echo Copie a mensagem exibida no LÖVE2D e envie para diagnostico.
  pause
)
exit /b %CODE%
