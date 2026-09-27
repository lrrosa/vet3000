@echo off
rem Copyright (C) 2026 Leonardo Roman da Rosa
rem SPDX-License-Identifier: GPL-3.0-or-later
rem
rem Roda o cartucho de demonstracao (abertura + jogo QUEBRA-TIJOLO) no VET 3000 do MAME,
rem sem recompilar o MAME (usa tools\mame\run_cart.ps1 e o script Lua do cartucho).
rem
rem Uso:  jogar_no_mame.bat [caminho\mame.exe]
rem O caminho do MAME vem do argumento, da variavel de ambiente MAME ou da linha abaixo.
rem Parametros extras do MAME: variavel VET_MAME_EXTRA (ex.: "-window -nomaximize").
setlocal
if not defined MAME set "MAME=F:\jogos\emuladores\mame\mame.exe"
if not "%~1"=="" set "MAME=%~1"
if not exist "%MAME%" for /f "delims=" %%i in ('where mame.exe 2^>nul') do set "MAME=%%i"
if not exist "%MAME%" (
    echo MAME nao encontrado: "%MAME%"
    echo Use: jogar_no_mame.bat C:\caminho\mame.exe   ^(ou defina a variavel MAME^)
    pause
    exit /b 1
)
echo Controles: ESPACO joga/lanca, Z/X movem, RETURN pausa, V sobrepoe, EXT MODE ^(TAB^) sai.
echo No editor do titulador, SHIFT+TAB ^(SHIFT+EXT MODE^) volta a demo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\mame\run_cart.ps1" -Mame "%MAME%" -Cart "%~dp0cartridge\demo\vet3000_demo.bin"
if errorlevel 1 pause
endlocal
