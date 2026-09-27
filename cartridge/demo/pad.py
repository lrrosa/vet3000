#!/usr/bin/env python3
# Copyright (C) 2026 Leonardo Roman da Rosa
# SPDX-License-Identifier: GPL-3.0-or-later
# Software livre sob a GNU GPL versão 3 ou (a seu critério) posterior; veja LICENSE.
#
"""Completa a imagem montada com $FF até 16 KB (EPROM 27128)."""
import sys
data = open(sys.argv[1], "rb").read()
if len(data) > 0x4000:
    sys.exit("cartucho maior que 16 KB (%d bytes)" % len(data))
open(sys.argv[2], "wb").write(data + b"\xff" * (0x4000 - len(data)))
print("%s: %d bytes usados de 16384" % (sys.argv[2], len(data)))
