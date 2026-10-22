@echo off
setlocal EnableExtensions
cd /d "%~dp0"
title LastCircle - cliente Survev em Lua (porte em desenvolvimento)
echo.
echo =========================================================
echo LASTCIRCLE - CLIENTE SURVEV LUA / BUSCA DE PARTIDAS ORIGINAL
echo =========================================================
echo.
echo Este programa abre o cliente Lua REAL no LÖVE 2D.
echo Nao inicia Moo-Quest. Para multiplayer, informe a URL real da API Survev.
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
echo [OK] Abrindo cliente Lua. Tela inicial: API /api/site_info e /api/find_game_v2.
echo [MENU] ENTER: encontrar partida real, F1/F2/F3: modo, SHIFT+ENTER: URL/token direto.
echo [MENU] F5: demonstracao local offline, F7: artes, F8: diagnostico, ESC: sair.
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
