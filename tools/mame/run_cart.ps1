# Copyright (C) 2026 Leonardo Roman da Rosa
# SPDX-License-Identifier: GPL-3.0-or-later
# Software livre sob a GNU GPL versão 3 ou (a seu critério) posterior; veja LICENSE.
#
# Roda um cartucho no VET 3000 do MAME, sem recompilar o MAME.
#   .\run_cart.ps1 -Mame F:\jogos\emuladores\mame\mame.exe -Cart ..\..\cartridge\demo\build\vet3000_demo.bin
# A ROM do VET 3000 é procurada em ..\..\rom (copiada para uma pasta temporária
# com o nome que o driver espera: vet3000\vet2.1-tms_vet3000_27128a.bin).
param(
    [Parameter(Mandatory = $true)][string]$Mame,
    [Parameter(Mandatory = $true)][string]$Cart,
    [string]$Keys = "",
    [string]$Peek = "",
    [string[]]$Extra = @()
)
$ErrorActionPreference = "Stop"
$repo = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$tmp = Join-Path $env:TEMP "vet3000_mame"
New-Item -ItemType Directory -Force (Join-Path $tmp "roms\vet3000") | Out-Null
Copy-Item (Join-Path $repo "rom\VET2.1-TMS_VET3000_27128A.BIN") (Join-Path $tmp "roms\vet3000\vet2.1-tms_vet3000_27128a.bin") -Force
$env:VET_CART = (Resolve-Path $Cart).Path
$env:VET_KEYS = $Keys
$env:VET_PEEK = $Peek
& $Mame vet3000 -rompath (Join-Path $tmp "roms") -nvram_directory (Join-Path $tmp "nvram") `
    -cfg_directory (Join-Path $tmp "cfg") -skip_gameinfo `
    -autoboot_script (Join-Path $PSScriptRoot "vet3000_cart.lua") @Extra
