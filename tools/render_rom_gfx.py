#!/usr/bin/env python3
# Copyright (C) 2026 Leonardo Roman da Rosa
# SPDX-License-Identifier: GPL-3.0-or-later
# Software livre sob a GNU GPL versão 3 ou (a seu critério) posterior; veja LICENSE.
#
"""Extrai da ROM do VET 3000 v2.1 imagens das fontes, sprites e logotipo.

    python tools/render_rom_gfx.py rom/VET2.1-TMS_VET3000_27128A.BIN docs/img
"""
import os
import sys

from PIL import Image

BASE = 0xC000
FG, BG, GRID = (255, 255, 255), (0, 0, 0), (70, 70, 90)


def load(path):
    rom = open(path, "rb").read()
    return lambda a: rom[a - BASE]


def glyph_sheet(byte, start, count, wtiles, cols, first_code, scale=3):
    """Fontes de 3 linhas de tiles (8x24 ou 16x24)."""
    per = wtiles * 24
    gw, gh = wtiles * 8 + 1, 24 + 1
    rows = (count + cols - 1) // cols
    im = Image.new("RGB", (cols * gw + 1, rows * gh + 1), GRID)
    for g in range(count):
        base = start + g * per
        ox, oy = 1 + (g % cols) * gw, 1 + (g // cols) * gh
        for tr in range(3):
            for tc in range(wtiles):
                for y in range(8):
                    b = byte(base + tr * wtiles * 8 + tc * 8 + y)
                    for x in range(8):
                        im.putpixel((ox + tc * 8 + x, oy + tr * 8 + y), FG if b & (0x80 >> x) else BG)
    return im.resize((im.width * scale, im.height * scale), Image.NEAREST)


def font8_sheet(byte, start, count, cols, scale=3):
    rows = (count + cols - 1) // cols
    im = Image.new("RGB", (cols * 9 + 1, rows * 9 + 1), GRID)
    for g in range(count):
        ox, oy = 1 + (g % cols) * 9, 1 + (g // cols) * 9
        for y in range(8):
            b = byte(start + g * 8 + y)
            for x in range(8):
                im.putpixel((ox + x, oy + y), FG if b & (0x80 >> x) else BG)
    return im.resize((im.width * scale, im.height * scale), Image.NEAREST)


def sprite_sheet(byte, start, count, scale=3):
    im = Image.new("RGB", (count * 17 + 1, 18), GRID)
    for s in range(count):
        for q in range(4):
            for y in range(8):
                b = byte(start + s * 32 + q * 8 + y)
                for x in range(8):
                    px, py = (q // 2) * 8 + x, (q % 2) * 8 + y
                    im.putpixel((1 + s * 17 + px, 1 + py), FG if b & (0x80 >> x) else BG)
    return im.resize((im.width * scale, im.height * scale), Image.NEAREST)


def logo(byte, scale=4):
    """Logotipo 'tms' da tela de abertura: 3 linhas x 6 tiles em $F013."""
    im = Image.new("RGB", (48, 24), BG)
    for row in range(3):
        for t in range(6):
            for y in range(8):
                b = byte(0xF013 + row * 48 + t * 8 + y)
                for x in range(8):
                    if b & (0x80 >> x):
                        im.putpixel((t * 8 + x, row * 8 + y), (84, 85, 237))
                    else:
                        im.putpixel((t * 8 + x, row * 8 + y), (212, 193, 84))
    return im.resize((im.width * scale, im.height * scale), Image.NEAREST)


def main():
    rom, out = sys.argv[1], sys.argv[2]
    os.makedirs(out, exist_ok=True)
    byte = load(rom)
    glyph_sheet(byte, 0xC000, 104, 2, 16, 0x13).save(os.path.join(out, "rom_fonte_grande.png"))
    glyph_sheet(byte, 0xD380, 108, 1, 27, 0x13).save(os.path.join(out, "rom_fonte_normal.png"))
    font8_sheet(byte, 0xDDA0, 76, 19).save(os.path.join(out, "rom_fonte_8x8.png"))
    sprite_sheet(byte, 0xF0A3, 16).save(os.path.join(out, "rom_sprites.png"))
    logo(byte).save(os.path.join(out, "rom_logo_tms.png"))
    print("imagens em", out)


if __name__ == "__main__":
    main()
