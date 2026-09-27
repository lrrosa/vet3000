#!/usr/bin/env python3
# Copyright (C) 2026 Leonardo Roman da Rosa
# SPDX-License-Identifier: GPL-3.0-or-later
# Software livre sob a GNU GPL versão 3 ou (a seu critério) posterior; veja LICENSE.
#
"""Gera os dados (assets.inc) do cartucho de demonstração do VET 3000.

Tudo é desenhado aqui (fonte 8x8 original, logotipo, telas) e convertido para o
formato do TMS9128 em modo Graphics II. As telas estáticas vão comprimidas em RLE.
Também grava prévias em PNG (preview_*.png) para conferir a arte sem emulador.

    python gen_assets.py            -> assets.inc (+ previews em build/)
"""
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
BUILD = os.path.join(HERE, "build")

# ---------------------------------------------------------------------------
# Paleta TMS9918/9128 (aprox. a do MAME) - só para as prévias
# ---------------------------------------------------------------------------
PALETTE = [(0, 0, 0), (0, 0, 0), (33, 200, 66), (94, 220, 120), (84, 85, 237),
           (125, 118, 252), (212, 82, 77), (66, 235, 245), (252, 85, 84),
           (255, 121, 120), (212, 193, 84), (230, 206, 128), (33, 176, 59),
           (201, 91, 186), (204, 204, 204), (255, 255, 255)]
TRANSPARENT, BLACK, MGREEN, LGREEN, DBLUE, LBLUE, DRED, CYAN, MRED, LRED, \
    DYELLOW, LYELLOW, DGREEN, MAGENTA, GRAY, WHITE = range(16)

# ---------------------------------------------------------------------------
# Fonte 8x8 original (6 colunas úteis, traços verticais de 2 pixels)
# ---------------------------------------------------------------------------
_GLYPHS = {
    " ": [""] * 7,
    "!": ["..##", "..##", "..##", "..##", "..##", "", "..##"],
    '"': [".##.##", ".##.##", ".#..#"],
    "'": ["..##", "..##", ".##"],
    "(": ["...##", "..##", ".##", ".##", ".##", "..##", "...##"],
    ")": [".##", "..##", "...##", "...##", "...##", "..##", ".##"],
    "*": ["", ".#..#.", "..##", "######", "..##", ".#..#."],
    "+": ["", "..##", "..##", "######", "..##", "..##"],
    ",": ["", "", "", "", "", "..##", "..##", ".##"],
    "-": ["", "", "", "######"],
    ".": ["", "", "", "", "", "..##", "..##"],
    "/": [".....#", "....##", "...##", "..##", ".##", "##", "#"],
    "0": [".####", "##..##", "##.###", "######", "###.##", "##..##", ".####"],
    "1": ["..##", ".###", "..##", "..##", "..##", "..##", ".####"],
    "2": [".####", "##..##", "....##", "..###", ".##", "##", "######"],
    "3": [".####", "##..##", "....##", "..###", "....##", "##..##", ".####"],
    "4": ["...##", "..###", ".####", "##.##", "######", "...##", "...##"],
    "5": ["######", "##", "#####", "....##", "....##", "##..##", ".####"],
    "6": [".####", "##", "##", "#####", "##..##", "##..##", ".####"],
    "7": ["######", "....##", "...##", "..##", "..##", "..##", "..##"],
    "8": [".####", "##..##", "##..##", ".####", "##..##", "##..##", ".####"],
    "9": [".####", "##..##", "##..##", ".#####", "....##", "...##", ".###"],
    ":": ["", "..##", "..##", "", "..##", "..##"],
    ";": ["", "..##", "..##", "", "..##", "..##", ".##"],
    "<": [".##.##", "#######", "#######", ".#####", "..###", "...#"],   # coração
    "=": ["", "", "######", "", "######"],
    ">": ["", "..##", "...##", "######", "...##", "..##"],               # seta
    "?": [".####", "##..##", "....##", "...##", "..##", "", "..##"],
    "@": [".####", "#....#", "#.##.#", "#.#..#", "#.##.#", "#....#", ".####"],  # (c)
    "A": [".####", "##..##", "##..##", "######", "##..##", "##..##", "##..##"],
    "B": ["#####", "##..##", "##..##", "#####", "##..##", "##..##", "#####"],
    "C": [".####", "##..##", "##", "##", "##", "##..##", ".####"],
    "D": ["####", "##.##", "##..##", "##..##", "##..##", "##.##", "####"],
    "E": ["######", "##", "##", "#####", "##", "##", "######"],
    "F": ["######", "##", "##", "#####", "##", "##", "##"],
    "G": [".####", "##..##", "##", "##.###", "##..##", "##..##", ".#####"],
    "H": ["##..##", "##..##", "##..##", "######", "##..##", "##..##", "##..##"],
    "I": [".####", "..##", "..##", "..##", "..##", "..##", ".####"],
    "J": ["...###", "....##", "....##", "....##", "##..##", "##..##", ".####"],
    "K": ["##..##", "##.##", "####", "###", "####", "##.##", "##..##"],
    "L": ["##", "##", "##", "##", "##", "##", "######"],
    "M": ["##...##", "###.###", "#######", "##.#.##", "##...##", "##...##", "##...##"],
    "N": ["##..##", "###.##", "######", "##.###", "##..##", "##..##", "##..##"],
    "O": [".####", "##..##", "##..##", "##..##", "##..##", "##..##", ".####"],
    "P": ["#####", "##..##", "##..##", "#####", "##", "##", "##"],
    "Q": [".####", "##..##", "##..##", "##..##", "##.###", "##.##", ".##.##"],
    "R": ["#####", "##..##", "##..##", "#####", "####", "##.##", "##..##"],
    "S": [".####", "##..##", "##", ".####", "....##", "##..##", ".####"],
    "T": ["######", "..##", "..##", "..##", "..##", "..##", "..##"],
    "U": ["##..##", "##..##", "##..##", "##..##", "##..##", "##..##", ".####"],
    "V": ["##..##", "##..##", "##..##", "##..##", "##..##", ".####", "..##"],
    "W": ["##...##", "##...##", "##...##", "##.#.##", "#######", "###.###", "##...##"],
    "X": ["##..##", "##..##", ".####", "..##", ".####", "##..##", "##..##"],
    "Y": ["##..##", "##..##", "##..##", ".####", "..##", "..##", "..##"],
    "Z": ["######", "....##", "...##", "..##", ".##", "##", "######"],
    "[": [".####", ".##", ".##", ".##", ".##", ".##", ".####"],
    "]": [".####", "...##", "...##", "...##", "...##", "...##", ".####"],
    "_": ["", "", "", "", "", "", "", "########"],
}
FONT_FIRST = 0x20  # glifos para ASCII $20-$5F (64 glifos)


def glyph(ch):
    rows = _GLYPHS.get(ch, [""] * 7)
    out = []
    for y in range(8):
        r = rows[y] if y < len(rows) else ""
        b = 0
        for x, c in enumerate(r[:8]):
            if c == "#":
                b |= 0x80 >> x
        out.append(b)
    return out


FONT = [glyph(chr(c)) for c in range(FONT_FIRST, FONT_FIRST + 64)]


def text_index(s):
    """Converte texto em índices de glifo (0-63)."""
    out = []
    for ch in s.upper():
        c = ord(ch)
        if not FONT_FIRST <= c < FONT_FIRST + 64:
            c = 0x20
        out.append(c - FONT_FIRST)
    return out


# ---------------------------------------------------------------------------
# Bitmap Graphics II: cada "banco" = 256x64 pixels, 2 cores por segmento 8x1
# ---------------------------------------------------------------------------
class Bank:
    """Um terço da tela (8 linhas de tiles) em layout bitmap (nomes 0..255)."""

    def __init__(self, fg=WHITE, bg=BLACK):
        self.pix = [[0] * 256 for _ in range(64)]      # 1 = frente
        self.fg = [[fg] * 32 for _ in range(64)]         # cor de frente por segmento
        self.bg = [[bg] * 32 for _ in range(64)]

    def plot(self, x, y, on=1):
        if 0 <= x < 256 and 0 <= y < 64:
            self.pix[y][x] = on

    def text(self, x, y, s, color=None, scale_x=1, scale_y=1, italic=0):
        """Escreve com a fonte 8x8 (ampliação e itálico opcionais)."""
        h = 8 * scale_y
        for i, g in enumerate(text_index(s)):
            rows = FONT[g]
            for gy in range(8):
                for sy in range(scale_y):
                    py = gy * scale_y + sy
                    shear = ((h - 1 - py) * italic) // h if italic else 0
                    for gx in range(8):
                        if rows[gy] & (0x80 >> gx):
                            for sx in range(scale_x):
                                self.plot(x + (i * 8 + gx) * scale_x + sx + shear, y + py)
            if color is not None:
                for py in range(y, min(y + h, 64)):
                    for cx in range((x + i * 8 * scale_x) // 8,
                                    min(32, (x + (i + 1) * 8 * scale_x + 7 + italic) // 8)):
                        self.fg[py][cx] = color

    def hline(self, x0, x1, y, color):
        for x in range(x0, x1):
            self.plot(x, y)
        for cx in range(x0 // 8, (x1 + 7) // 8):
            self.fg[y][cx] = color

    def color_rows(self, y0, y1, colors, x0=0, x1=256):
        """Pinta a cor de frente das linhas y0..y1-1 com a lista (degradê)."""
        for y in range(y0, y1):
            c = colors[(y - y0) * len(colors) // (y1 - y0)]
            for cx in range(x0 // 8, x1 // 8):
                self.fg[y][cx] = c

    def patterns(self):
        out = bytearray()
        for tile in range(256):
            ty, tx = divmod(tile, 32)
            for line in range(8):
                y = ty * 8 + line
                b = 0
                for x in range(8):
                    if self.pix[y][tx * 8 + x]:
                        b |= 0x80 >> x
                out.append(b)
        return out

    def colors(self):
        out = bytearray()
        for tile in range(256):
            ty, tx = divmod(tile, 32)
            for line in range(8):
                y = ty * 8 + line
                out.append((self.fg[y][tx] << 4) | self.bg[y][tx])
        return out

    def render(self, img, oy):
        for y in range(64):
            for x in range(256):
                cx = x // 8
                c = self.fg[y][cx] if self.pix[y][x] else self.bg[y][cx]
                img.putpixel((x, oy + y), PALETTE[c])


def rle(data):
    """RLE simples: n<$80 -> n bytes literais; n>=$80 -> repete o próximo
    byte (n-$7E) vezes (2..129); 0 termina."""
    out = bytearray()
    i = 0
    lit = bytearray()

    def flush():
        nonlocal lit
        while lit:
            chunk = lit[:127]
            out.append(len(chunk))
            out.extend(chunk)
            lit = lit[127:]

    while i < len(data):
        j = i
        while j < len(data) and data[j] == data[i] and j - i < 129:
            j += 1
        run = j - i
        if run >= 3:
            flush()
            out.append(0x7E + run)
            out.append(data[i])
            i = j
        else:
            lit.append(data[i])
            i += 1
    flush()
    out.append(0)
    return bytes(out)


def unrle(data):
    out = bytearray()
    i = 0
    while data[i]:
        n = data[i]
        if n < 0x80:
            out.extend(data[i + 1:i + 1 + n])
            i += 1 + n
        else:
            out.extend(bytes([data[i + 1]]) * (n - 0x7E))
            i += 2
    return bytes(out)


# ---------------------------------------------------------------------------
# Tela de abertura
# ---------------------------------------------------------------------------
LOGO_GRADIENT = [WHITE, WHITE, CYAN, CYAN, CYAN, LBLUE, LBLUE, LBLUE, LBLUE,
                 LBLUE, DBLUE, DBLUE, LBLUE, CYAN]


def title_top():
    b = Bank()
    # logotipo "VET 3000" em itálico, 4x (28 px de altura)
    lx, ly = 30, 4
    b.text(lx, ly, "VET", scale_x=3, scale_y=4, italic=7)
    b.text(lx + 88, ly, "3OOO", scale_x=3, scale_y=4, italic=7)   # 'O' sem o corte do '0'
    b.color_rows(ly, ly + 32, LOGO_GRADIENT)
    # duas faixas como na arte do teclado
    for x0, x1 in ((8, 248),):
        b.hline(x0, x1, 38, LBLUE)
        b.hline(x0, x1, 41, DBLUE)
        b.hline(x0, x1, 42, DBLUE)
    b.text(128, 47, "VIDEO TITLER", color=LBLUE)
    b.text(16, 47, "TMS 1988", color=GRAY)
    b.text(40, 56, "DEMO DE CARTUCHO", color=LYELLOW)
    b.color_rows(56, 64, [LYELLOW, LYELLOW, DYELLOW, DYELLOW, LYELLOW, WHITE, DYELLOW, DYELLOW], 0, 256)
    return b


SCROLL_ROW = 3        # linha de tiles do scroller dentro do banco 2 (tela: linha 19)
BLINK_ROW = 0         # linha piscante "ESPACO: JOGAR" (tela: linha 16)


def title_bottom():
    b = Bank()
    b.text(16, BLINK_ROW * 8, "ESPACO: JOGAR   V: SOBREPOR", color=WHITE)
    # gradiente do scroller (tiles da linha SCROLL_ROW)
    grad = [LYELLOW, LYELLOW, DYELLOW, LRED, LRED, MRED, DRED, DRED]
    for i in range(8):
        for cx in range(32):
            b.fg[SCROLL_ROW * 8 + i][cx] = grad[i]
    b.text(8, 40, "EXT MODE: VOLTA AO TITULADOR", color=GRAY)
    b.text(12, 56, "@ 2026 LEONARDO ROMAN DA ROSA", color=MAGENTA)
    return b


SCROLL_TEXT = (
    "      *** VET 3000 - THE VIDEO EFFECTS TITLER ***     "
    "O TITULADOR DE VIDEO DA TMS (1988) TAMBEM E UM MICROCOMPUTADOR:  "
    "CPU MOTOROLA MC6809 A 0,89 MHZ  -  VDP TEXAS TMS9128 (O MESMO DO MSX)  -  "
    "16 KB DE VRAM  -  8 KB DE RAM COM BATERIA  -  ROM DE 16 KB.     "
    "ESTE CARTUCHO RODA PELO CONECTOR TRASEIRO CN1, DETECTADO PELA ASSINATURA "
    "'OBJECT' EM $4000.     BARRAS DE COR SEM INTERRUPCAO DE LINHA, SCROLLER "
    "COM FONTES PRE-DESLOCADAS E SPRITES 16X16...     "
    "APERTE ESPACO PARA JOGAR QUEBRA-TIJOLO!     "
    "OS SEUS TITULOS NA RAM FICAM INTACTOS.     "
    "DEMO E JOGO POR LEONARDO ROMAN DA ROSA - SOFTWARE LIVRE (GPL-3).     <<<    ")

# ---------------------------------------------------------------------------
# Barras de cor (degradês de 7 linhas) e seno
# ---------------------------------------------------------------------------
BARS = [
    [DRED, MRED, LRED, LYELLOW, WHITE, LYELLOW, LRED, MRED, DRED],
    [DBLUE, DBLUE, LBLUE, CYAN, WHITE, CYAN, LBLUE, DBLUE, DBLUE],
    [DGREEN, MGREEN, LGREEN, LGREEN, WHITE, LGREEN, LGREEN, MGREEN, DGREEN],
    [MAGENTA, MAGENTA, LRED, LRED, WHITE, LRED, LRED, MAGENTA, MAGENTA],
    [DYELLOW, DYELLOW, LYELLOW, LYELLOW, WHITE, LYELLOW, LYELLOW, DYELLOW, DYELLOW],
]
SINE = [int(round(127 * math.sin(2 * math.pi * i / 256))) & 0xFF for i in range(256)]

# ---------------------------------------------------------------------------
# Sprites (16x16: quadrantes em ordem sup-esq, inf-esq, sup-dir, inf-dir)
# ---------------------------------------------------------------------------


def sprite(rows):
    rows = [(r + "." * 16)[:16] for r in rows] + ["." * 16] * (16 - len(rows))
    out = bytearray()
    for qx, qy in ((0, 0), (0, 8), (8, 0), (8, 8)):
        for y in range(8):
            b = 0
            for x in range(8):
                if rows[qy + y][qx + x] == "#":
                    b |= 0x80 >> x
            out.append(b)
    return bytes(out)


SPR_BALL16 = sprite([
    ".....######.....",
    "...##########...",
    "..############..",
    ".#####..#######.",
    ".####...#######.",
    "#####..#########",
    "################",
    "################",
    "################",
    "################",
    "################",
    ".##############.",
    ".##############.",
    "..############..",
    "...##########...",
    ".....######....."])
SPR_BALL = sprite([
    ".####.",
    "######",
    "######",
    "######",
    "######",
    ".####."])
SPR_PADDLE_L = sprite([
    "",
    ".###############",
    "################",
    "################",
    "################",
    ".###############"])
SPR_PADDLE_R = sprite([
    "",
    "###############.",
    "################",
    "################",
    "################",
    "###############."])
SPR_PADDLE_HI = sprite([
    "",
    "",
    ".#.############",
    "",
    "",
    ""])

SPRITES = [SPR_BALL16, SPR_BALL, SPR_PADDLE_L, SPR_PADDLE_R]

# ---------------------------------------------------------------------------
# Jogo: conjunto de tiles (fonte 0-63 + tijolos/paredes 64..), mesmo nos 3 bancos
# ---------------------------------------------------------------------------
T_WALL, T_WALL_TOP, T_CORNER_L, T_CORNER_R = 64, 65, 66, 67
T_BRICK = 72          # 6 linhas de tijolo x (esq, dir) = 72..83
BRICK_ROWS = 6
BRICK_COLORS = [      # (clara, média, escura) por linha de tijolos
    (LRED, MRED, DRED), (LYELLOW, DYELLOW, DRED), (LGREEN, MGREEN, DGREEN),
    (CYAN, LBLUE, DBLUE), (LRED, MAGENTA, DBLUE), (WHITE, GRAY, DBLUE)]


def game_tiles():
    pats = bytearray(96 * 8)
    cols = bytearray(96 * 8)
    for g in range(64):
        pats[g * 8:g * 8 + 8] = bytes(FONT[g])
        for y in range(8):
            cols[g * 8 + y] = (WHITE << 4) | BLACK
    # parede lateral: cano vertical (claro no meio, escuro nas bordas)
    for y in range(8):
        pats[T_WALL * 8 + y] = 0x7E
        cols[T_WALL * 8 + y] = (LBLUE << 4) | DBLUE
    # teto e cantos: cano horizontal com degradê
    top = [DBLUE, LBLUE, CYAN, WHITE, CYAN, LBLUE, DBLUE]
    for t in (T_WALL_TOP, T_CORNER_L, T_CORNER_R):
        for y in range(8):
            pats[t * 8 + y] = 0xFF if y < 7 else 0x00
            cols[t * 8 + y] = ((top[y] if y < 7 else BLACK) << 4) | BLACK
    # tijolos 16x8 com relevo: brilho em cima/à esquerda, sombra embaixo/à direita
    for r, (hi, mid, lo) in enumerate(BRICK_COLORS):
        tl, tr = T_BRICK + r * 2, T_BRICK + r * 2 + 1
        for y in range(8):
            if y == 0:
                pl, cl, pr, cr = 0xFF, (hi << 4) | lo, 0xFE, (hi << 4) | lo
            elif y < 6:
                pl, cl, pr, cr = 0x7F, (mid << 4) | hi, 0xFE, (mid << 4) | lo
            elif y == 6:
                pl, cl, pr, cr = 0xFF, (lo << 4) | lo, 0xFF, (lo << 4) | lo
            else:
                pl, cl, pr, cr = 0x00, (BLACK << 4) | BLACK, 0x00, (BLACK << 4) | BLACK
            pats[tl * 8 + y], cols[tl * 8 + y] = pl, cl
            pats[tr * 8 + y], cols[tr * 8 + y] = pr, cr
    return bytes(pats), bytes(cols)


# layouts das fases: 6 linhas x 15 tijolos ('#' = tijolo)
LEVELS = [
    ["###############"] * 6,
    ["#.#.#.#.#.#.#.#", ".#.#.#.#.#.#.#.", "#.#.#.#.#.#.#.#",
     ".#.#.#.#.#.#.#.", "#.#.#.#.#.#.#.#", ".#.#.#.#.#.#.#."],
    ["......###......", "....#######....", "..###########..",
     "###############", "..###########..", "....#######...."],
    ["###.##...##.###", "###.##...##.###", "...............",
     "###############", "#.#.#.#.#.#.#.#", "###############"],
]


def level_bits(rows):
    out = bytearray()
    for r in rows:
        v = 0
        for i, c in enumerate(r):
            if c == "#":
                v |= 0x8000 >> i
        out += bytes([v >> 8, v & 0xFF])
    return bytes(out)


# ---------------------------------------------------------------------------
# Saída assembly
# ---------------------------------------------------------------------------
def fcb_lines(data, per=16):
    lines = []
    for i in range(0, len(data), per):
        lines.append("\t\tfcb\t" + ",".join("$%02X" % b for b in data[i:i + per]))
    return lines


def main():
    os.makedirs(BUILD, exist_ok=True)
    out = []
    w = out.append
    w("* Gerado por gen_assets.py - não editar à mão")
    w("")
    w("FONT_FIRST\tequ\t$%02X" % FONT_FIRST)
    w("SCROLL_ROW\tequ\t%d" % SCROLL_ROW)
    w("BLINK_ROW\tequ\t%d" % BLINK_ROW)
    w("T_WALL\t\tequ\t%d" % T_WALL)
    w("T_BRICK\t\tequ\t%d" % T_BRICK)
    w("BRICK_ROWS\tequ\t%d" % BRICK_ROWS)
    w("NUM_LEVELS\tequ\t%d" % len(LEVELS))
    w("NUM_BARS\tequ\t%d" % len(BARS))
    w("BAR_H\t\tequ\t%d" % len(BARS[0]))
    w("T_WALL_TOP\tequ\t%d" % T_WALL_TOP)
    w("")
    w("FONT")
    out.extend(fcb_lines(bytes(b for g in FONT for b in g), 8))
    # fontes pré-deslocadas para o scroller: SHL_s = glifo<<s, SHR_s = glifo>>(8-s)
    for s in (0, 2, 4, 6):
        w("SHL%d" % s)
        out.extend(fcb_lines(bytes(((b << s) & 0xFF) for g in FONT for b in g)))
        w("SHR%d" % s)
        out.extend(fcb_lines(bytes(((b >> (8 - s)) if s else 0) for g in FONT for b in g)))
    w("SCROLL_TABS\tfdb\tSHL0,SHR0,SHL2,SHR2,SHL4,SHR4,SHL6,SHR6")
    # texto do scroller como deslocamentos de glifo (índice*8), repetindo o
    # início no fim para a janela de 33 colunas nunca passar do final
    txt = text_index(SCROLL_TEXT)
    ext = txt + txt[:34]
    w("SCROLL_TEXT")
    for i in range(0, len(ext), 16):
        w("\t\tfdb\t" + ",".join("%d" % (g * 8) for g in ext[i:i + 16]))
    w("SCROLL_WRAP\tequ\tSCROLL_TEXT+%d" % (2 * len(txt)))
    w("")
    w("SINE")
    out.extend(fcb_lines(bytes(SINE)))
    w("SINE_C	equ	SINE+128	; use com índice XOR $80 (deslocamento com sinal)")
    w("BAR_GRAD")
    for bar in BARS:
        out.extend(fcb_lines(bytes((c << 4) | c for c in bar), 8))
    w("")
    top, bottom = title_top(), title_bottom()
    for name, data in (("TITLE0_PAT", top.patterns()), ("TITLE0_COL", top.colors()),
                       ("TITLE2_PAT", bottom.patterns()), ("TITLE2_COL", bottom.colors())):
        packed = rle(data)
        assert unrle(packed) == data
        w("%s\t\t; %d -> %d bytes (RLE)" % (name, len(data), len(packed)))
        out.extend(fcb_lines(packed))
    w("")
    w("SPRITE_PATS\t; %d sprites 16x16" % len(SPRITES))
    out.extend(fcb_lines(b"".join(SPRITES)))
    w("SPRITE_PATS_END")
    gp, gc = game_tiles()
    w("GAME_PAT\t; %d bytes" % len(gp))
    out.extend(fcb_lines(rle(gp)))
    w("GAME_COL")
    out.extend(fcb_lines(rle(gc)))
    w("LEVELS\t\t; %d fases x 6 linhas x 16 bits" % len(LEVELS))
    for lv in LEVELS:
        out.extend(fcb_lines(level_bits(lv)))
    with open(os.path.join(HERE, "assets.inc"), "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(out) + "\n")

    # prévias
    try:
        from PIL import Image
    except ImportError:
        return
    img = Image.new("RGB", (256, 192), PALETTE[BLACK])
    top.render(img, 0)
    for y in range(64, 128):          # barras (quadro 0)
        pass
    bottom.render(img, 128)
    img.resize((768, 576), Image.NEAREST).save(os.path.join(BUILD, "preview_title.png"))
    fnt = Image.new("RGB", (8 * 16 * 3, 8 * 4 * 3))
    for g in range(64):
        for y in range(8):
            for x in range(8):
                if FONT[g][y] & (0x80 >> x):
                    for dy in range(3):
                        for dx in range(3):
                            fnt.putpixel(((g % 16) * 24 + x * 3 + dx, (g // 16) * 24 + y * 3 + dy),
                                         (255, 255, 255))
    fnt.save(os.path.join(BUILD, "preview_font.png"))
    print("assets.inc gerado; prévias em", BUILD)


if __name__ == "__main__":
    sys.exit(main())
