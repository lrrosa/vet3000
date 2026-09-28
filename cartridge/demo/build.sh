#!/bin/sh
# Copyright (C) 2026 Leonardo Roman da Rosa
# SPDX-License-Identifier: GPL-3.0-or-later
# Software livre sob a GNU GPL versão 3 ou (a seu critério) posterior; veja LICENSE.
#
# Monta o cartucho de demonstração do VET 3000.
#   ./build.sh            -> build/vet3000_demo.bin (imagem de 16 KB para EPROM 27128)
#   ./build.sh debug      -> build/vet3000_demo_debug.bin (profiling em RAM: $009A/$009C)
# Requer python3 e asm6809 (https://www.6809.org.uk/asm6809/) no PATH ou em $ASM6809.
set -e
cd "$(dirname "$0")"
ASM6809=${ASM6809:-asm6809}
PYTHON=${PYTHON:-$(command -v python3 || command -v python)}
mkdir -p build
"$PYTHON" gen_assets.py
if [ "$1" = "debug" ]; then
    "$ASM6809" -d DEBUG=1 -B -o build/vet3000_demo_debug.raw -l build/vet3000_demo_debug.lst demo.asm
    "$PYTHON" pad.py build/vet3000_demo_debug.raw build/vet3000_demo_debug.bin
else
    "$ASM6809" -B -o build/vet3000_demo.raw -l build/vet3000_demo.lst -s build/vet3000_demo.sym demo.asm
    "$PYTHON" pad.py build/vet3000_demo.raw build/vet3000_demo.bin
fi
