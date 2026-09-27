# Copyright (C) 2026 Leonardo Roman da Rosa
# SPDX-License-Identifier: GPL-3.0-or-later
# Software livre sob a GNU GPL versão 3 ou (a seu critério) posterior; veja LICENSE.
#
# Monta o cartucho de demonstração do VET 3000 (Windows / PowerShell).
#   .\build.ps1                 -> build\vet3000_demo.bin (16 KB, EPROM 27128)
#   .\build.ps1 -Debug          -> build\vet3000_demo_debug.bin (marcas de profiling em $8003)
#   .\build.ps1 -Asm C:\caminho\asm6809.exe
param(
    [switch]$Debug,
    [string]$Asm = $(if ($env:ASM6809) { $env:ASM6809 } else { "asm6809" })
)
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot
New-Item -ItemType Directory -Force build | Out-Null
python gen_assets.py
if ($LASTEXITCODE) { throw "gen_assets.py falhou" }
if ($Debug) {
    & $Asm -d DEBUG=1 -B -o build\vet3000_demo_debug.raw -l build\vet3000_demo_debug.lst demo.asm
    $raw = "build\vet3000_demo_debug.raw"; $out = "build\vet3000_demo_debug.bin"
} else {
    & $Asm -B -o build\vet3000_demo.raw -l build\vet3000_demo.lst -s build\vet3000_demo.sym demo.asm
    $raw = "build\vet3000_demo.raw"; $out = "build\vet3000_demo.bin"
}
if ($LASTEXITCODE) { throw "asm6809 falhou" }
python pad.py $raw $out; if ($LASTEXITCODE) { throw "pad.py falhou" }
