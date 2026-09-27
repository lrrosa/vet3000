#!/bin/sh
# Copyright (C) 2026 Leonardo Roman da Rosa
# SPDX-License-Identifier: GPL-3.0-or-later
# Software livre sob a GNU GPL versão 3 ou (a seu critério) posterior; veja LICENSE.
#
# Regenera o disassembly a partir da ROM + anotações e confere se ele remonta idêntico.
#   ./disasm/verify.sh        (asm6809 no PATH ou em $ASM6809)
set -e
cd "$(dirname "$0")/.."
ASM6809=${ASM6809:-asm6809}
PYTHON=${PYTHON:-$(command -v python3 || command -v python)}
ROM=rom/VET2.1-TMS_VET3000_27128A.BIN
"$PYTHON" tools/dis6809.py "$ROM" --hints disasm/hints.py --report -o disasm/vet3000_v2.1.asm
"$ASM6809" -B -o disasm/rebuild.bin disasm/vet3000_v2.1.asm
if cmp -s disasm/rebuild.bin "$ROM"; then
    echo "OK: disasm/vet3000_v2.1.asm remonta byte a byte idêntico a $ROM"
    rm -f disasm/rebuild.bin
else
    echo "DIFERENTE: compare disasm/rebuild.bin com $ROM" >&2
    exit 1
fi
