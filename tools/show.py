#!/usr/bin/env python3
# Copyright (C) 2026 Leonardo Roman da Rosa
# SPDX-License-Identifier: GPL-3.0-or-later
# Software livre sob a GNU GPL versão 3 ou (a seu critério) posterior; veja LICENSE.
#
"""Print the lines of a dis6809 listing whose address lies in [start, end)."""
import re, sys
path, start, end = sys.argv[1], int(sys.argv[2], 16), int(sys.argv[3], 16)
pat = re.compile(r";\s([0-9A-F]{4})\s\s")
on = False
for line in open(path, encoding="utf-8"):
    m = pat.search(line)
    if m:
        a = int(m.group(1), 16)
        on = start <= a < end
    if on:
        sys.stdout.write(line)
