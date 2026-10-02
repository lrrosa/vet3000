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
from levels import COURTS, LEVELS
import boss_art

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
    "$": ["..##", ".#####", "##.#", ".####", "...#.##", "#####", "..##"],
    # acentuados (gravados em códigos ASCII sem uso nos textos; ver ACCENTS).
    # O agudo fica na linha 0, separado da letra por uma linha vazia.
    "Ç": [".####", "##..##", "##", "##", "##..##", ".####", "...##", "..##"],
    "Ã": [".##.#", "#.##.", "", ".####", "##..##", "######", "##..##"],   # til, linha vazia, A de 4 linhas
    "Á": ["...##", "", ".####", "##..##", "######", "##..##", "##..##"],
    "É": ["...##", "", "######", "##", "#####", "##", "######"],
    "Ê": ["..##", ".#..#", "######", "##", "#####", "##", "######"],
    "Í": ["...##", "", ".####", "..##", "..##", "..##", ".####"],
    "Ó": ["...##", "", ".####", "##..##", "##..##", "##..##", ".####"],
    "Ú": ["...##", "", "##..##", "##..##", "##..##", "##..##", ".####"],
}
# caractere acentuado -> código ASCII (sem uso nos textos) onde o glifo é gravado
ACCENTS = {"Ç": "#", "Ã": "%", "É": "&", "Í": "\\", "Ó": "^", "Á": "_", "Ê": "[", "Ú": "]"}
CODE_GLYPH = {v: k for k, v in ACCENTS.items()}
FONT_FIRST = 0x20  # glifos para ASCII $20-$5F (64 glifos)


def glyph(ch):
    rows = _GLYPHS.get(CODE_GLYPH.get(ch, ch), [""] * 7)
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
        c = ord(ACCENTS.get(ch, ch))
        if not FONT_FIRST <= c < FONT_FIRST + 64:
            c = 0x20
        out.append(c - FONT_FIRST)
    return out


def center_x(s):
    """X que centraliza na tela a parte desenhada do texto (sem a margem vazia
    à direita dos glifos, que têm 6 ou 7 colunas úteis de 8)."""
    cols = [i * 8 + x for i, g in enumerate(text_index(s))
            for x in range(8) if any(row & (0x80 >> x) for row in FONT[g])]
    return (256 - (max(cols) - min(cols) + 1)) // 2 - min(cols)


# ---------------------------------------------------------------------------
# Bitmap Graphics II: cada "banco" = 256x64 pixels, 2 cores por segmento 8x1
# ---------------------------------------------------------------------------
class Bank:
    """Um terço da tela (8 linhas de tiles) em layout bitmap (nomes 0..255).

    O fundo é transparente (cor 0), não preto: com o backdrop preto (R7 = 1) a
    tela fica igual, e com EXTVID (tecla V) o vídeo externo aparece atrás dos
    textos. Ele só passa onde a cor do padrão é transparente (manual do
    TMS9918A, p. 51); com fundo preto apareceria só na borda."""

    def __init__(self, fg=WHITE, bg=TRANSPARENT):
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

    def centered(self, y, s, color):
        """Escreve o texto centralizado na linha de pixels y."""
        self.text(center_x(s), y, s, color=color)

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
# Logotipo "VET 3000": cada linha de pixel tem um nível de brilho (3 = mais claro)
# e cada tema dá as cores dos 4 níveis. A demo passa de um tema ao seguinte
# trocando uma linha por vez, na ordem de LOGO_ORDER, e percorre os temas em
# ciclo. O primeiro tema é o que vai gravado na tela.
LOGO_X, LOGO_Y = 35, 4           # pixels visíveis em x=37..217: margens de 37/38 px
LOGO_LINES = 28                 # 7 linhas de glifo x 4 (a 8a linha da fonte é vazia)
LOGO_SHADE = [3] * 5 + [2] * 7 + [1] * 11 + [0] * 5
LOGO_THEMES = [                 # cores dos níveis 3, 2, 1 e 0
    (WHITE, CYAN, LBLUE, DBLUE),            # azul, como na arte do teclado
    (WHITE, LRED, MAGENTA, DBLUE),          # roxo
    (LYELLOW, LRED, MRED, DRED),            # vermelho
    (WHITE, LYELLOW, DYELLOW, DYELLOW),     # dourado
    (WHITE, LGREEN, MGREEN, DGREEN),        # verde
    (WHITE, CYAN, LGREEN, MGREEN),          # água
]
LOGO_ORDER = list(range(LOGO_LINES))    # de cima para baixo
FOOTER_GRADIENT = [WHITE, CYAN, CYAN, LBLUE, LBLUE, LBLUE, DBLUE, DBLUE]


def logo_colors(theme):
    """Cor de frente de cada linha do logotipo no tema dado."""
    return [LOGO_THEMES[theme][3 - s] for s in LOGO_SHADE]


def logo_columns(b):
    """Colunas de tiles ocupadas pelo logotipo: (primeira, última + 1)."""
    xs = [x for y in range(LOGO_Y, LOGO_Y + LOGO_LINES) for x in range(256) if b.pix[y][x]]
    return min(xs) // 8, max(xs) // 8 + 1


def title_top():
    b = Bank()
    # logotipo "VET 3000" em itálico, 4x (28 px de altura)
    b.text(LOGO_X, LOGO_Y, "VET", scale_x=3, scale_y=4, italic=7)
    b.text(LOGO_X + 88, LOGO_Y, "3OOO", scale_x=3, scale_y=4, italic=7)   # 'O' sem o corte do '0'
    b.color_rows(LOGO_Y, LOGO_Y + LOGO_LINES, logo_colors(0))
    # duas faixas como na arte do teclado
    for x0, x1 in ((8, 248),):
        b.hline(x0, x1, 38, LBLUE)
        b.hline(x0, x1, 41, DBLUE)
        b.hline(x0, x1, 42, DBLUE)
    b.text(146, 47, "VIDEO TITLER", color=LBLUE)  # termina em x=239: margem de 16 px
    b.text(16, 47, "TMS 1988", color=GRAY)
    b.centered(56, "DEMO DE CARTUCHO", LYELLOW)
    b.color_rows(56, 64, [LYELLOW, LYELLOW, DYELLOW, DYELLOW, LYELLOW, WHITE, DYELLOW, DYELLOW], 0, 256)
    return b


SCROLL_ROW = 3        # linha de tiles do scroller dentro do banco 2 (tela: linha 19)
BLINK_ROW = 1         # linha piscante "ESPACO: JOGAR" (tela: linha 17)


def title_bottom():
    b = Bank()
    b.centered(BLINK_ROW * 8, "ESPAÇO: JOGAR   V: SOBREPOR", WHITE)
    # gradiente do scroller (tiles da linha SCROLL_ROW)
    grad = [LYELLOW, LYELLOW, DYELLOW, LRED, LRED, MRED, DRED, DRED]
    for i in range(8):
        for cx in range(32):
            b.fg[SCROLL_ROW * 8 + i][cx] = grad[i]
    b.centered(40, "EXT MODE: VOLTA AO TITULADOR", GRAY)
    b.centered(56, "@ 2026 LEONARDO ROMAN DA ROSA", WHITE)
    b.color_rows(56, 64, FOOTER_GRADIENT)
    return b


SCROLL_TEXT = (
    "      *** VET 3000 - THE VIDEO EFFECTS TITLER ***     "
    "MC6809 + TMS9128: 32 FASES, TIJOLOS DE PRATA E OURO, CÁPSULAS E TOP 10!     "
    "ESPAÇO: JOGAR. V: VÍDEO EXTERNO.     "
    "EXT MODE: TITULADOR. SHIFT+EXT MODE NO EDITOR: VOLTA A DEMO.     "
    "TÍTULOS PRESERVADOS. RECORDES NA RAM COM BATERIA.     "
    "SOFTWARE LIVRE GPL-3.     <<<    ")

# mensagens do jogo e do ranking (ASCII + códigos dos acentuados, 0 no fim).
# As do meio da tela têm 16 caracteres para cobrir a anterior (msg_blank).
MESSAGES = [
    ("msg_level", " FASE COMPLETA! "),
    ("msg_over", "  FIM DE JOGO   "),
    ("msg_stage", "FASE "),
    ("msg_pause", "    PAUSA    "),
    ("msg_blank", "                "),
    ("msg_hud", "PONTOS         VIDAS    FASE"),
    ("power_help", "Z/X: MOVE   ESPAÇO: AÇÃO"),   # 24 (par): centrada entre as paredes
    ("attract_help", "DEMONSTRAÇÃO - ESPAÇO: JOGAR"),
    ("msg_victory", "CAMPANHA COMPLETA!"),
    ("msg_conquered", "32 FASES + GUARDIÃO"),
    ("hs_title", "QUEBRA-TIJOLO: TOP 10"),
    ("hs_header", "    NOME  PONTOS"),
    ("hs_edit_msg", "A-Z: DIGITE SUAS INICIAIS"),
    ("hs_clear_msg", "CLEAR: APAGA"),
    ("hs_confirm_msg", "RETURN: CONFIRMA O NOME"),
    ("hs_return_msg", "ESPAÇO: VOLTAR"),
    ("hs_play_msg", "ESPAÇO: JOGAR"),      # ranking no ciclo de demonstração
]

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


def build_bars(phase=0):
    """64 índices de cor, como build_bars no 6809 (atrás antes da frente)."""
    colors = [TRANSPARENT] * 64
    for behind in (True, False):
        for i, gradient in enumerate(BARS):
            angle = (phase + i * (256 // len(BARS))) & 0xFF
            if bool(SINE[(angle + 64) & 0xFF] & 0x80) != behind:
                continue
            y = (((SINE[angle] + 128) & 0xFF) * (65 - len(gradient))) >> 8
            colors[y:y + len(gradient)] = gradient
    return colors

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
# A bola do jogo fica nas últimas linhas do sprite: os 16 pixels de altura que
# o VDP conta no limite de 4 sprites por linha terminam na base da bola, e ela
# parada sobre o rebatedor não divide nenhuma linha com ele.
SPR_BALL = sprite([""] * 10 + [
    ".####.",
    "######",
    "######",
    "######",
    "######",
    ".####."])

# Rebatedor prateado (6 linhas): terminais vermelhos, anel escuro de 2 pixels e
# corpo com brilho branco nas 2 linhas de cima e cinza nas 4 de baixo. Cada
# sprite tem uma cor só, e o brilho fica num sprite que termina na linha 1 do
# rebatedor enquanto o cinza começa na linha 2: assim nenhuma linha passa de 4
# sprites, nem com o rebatedor grande (2 terminais + 2 segmentos de corpo).
PADDLE_TIP = ["..####", ".#####", "######", "######", ".#####", "..####"]
SPR_PADDLE_TIP_L = sprite(PADDLE_TIP)
SPR_PADDLE_TIP_R = sprite([row[::-1].rjust(16, ".") for row in PADDLE_TIP])
SPR_PADDLE_SHINE = sprite([""] * 14 + ["#" * 16] * 2)
SPR_PADDLE_BODY = sprite(["#" * 16] * 4)

SPRITES = [SPR_BALL16, SPR_BALL, SPR_PADDLE_TIP_L, SPR_PADDLE_TIP_R]
# cápsulas 1-7 com as letras do Arkanoid: E aumenta, S lenta, P vida (Player),
# C prende, B saída (Break), L laser, D três bolas (Disruption). Padrão =
# tipo*4+12; o tiro vem logo depois e serve também para o projétil (tipo 8).
for letter in "ESPCBLD":
    rows = [".########.", "#........#"]
    rows += ["#." + row.ljust(6, ".") + ".#" for row in _GLYPHS[letter]]
    rows += ["#........#", ".########."]
    SPRITES.append(sprite(rows))
SPR_SHOT = sprite(["..##.."] * 8)
SPRITES += [SPR_SHOT, SPR_PADDLE_SHINE, SPR_PADDLE_BODY]
# números de padrão (índice x 4 nos sprites 16x16) usados pelo demo.asm
SPRITE_EQUS = [("PAT_BALL", SPR_BALL), ("PAT_TIP_L", SPR_PADDLE_TIP_L),
               ("PAT_TIP_R", SPR_PADDLE_TIP_R), ("PAT_SHINE", SPR_PADDLE_SHINE), ("PAT_SHOT", SPR_SHOT),
               ("PAT_BODY", SPR_PADDLE_BODY)]

# ---------------------------------------------------------------------------
# Jogo: conjunto de tiles (fonte 0-63 + tijolos/paredes 64..), mesmo nos 3 bancos
# ---------------------------------------------------------------------------
T_WALL, T_WALL_TOP, T_CORNER_L, T_CORNER_R = 64, 65, 66, 67
T_CURSOR = 69
T_ENERGY, T_ENERGY_OFF = 70, 71     # barra de energia do chefão
T_BRICK = 72          # 6 linhas de tijolo x (esq, dir) = 72..83
BRICK_ROWS = 10
BRICK_COLORS = [      # (clara, média, escura) por linha de tijolos
    (LRED, MRED, DRED), (LYELLOW, DYELLOW, DRED), (LGREEN, MGREEN, DGREEN),
    (CYAN, LBLUE, DBLUE), (LRED, MAGENTA, DBLUE), (WHITE, GRAY, DBLUE)]


def game_tiles():
    """Fundos e vãos em cor 0 (transparente), como na abertura (ver Bank)."""
    pats = bytearray(96 * 8)
    cols = bytearray(96 * 8)
    for g in range(64):
        pats[g * 8:g * 8 + 8] = bytes(FONT[g])
        for y in range(8):
            cols[g * 8 + y] = (WHITE << 4) | TRANSPARENT
    # Segmented metal rails: white bevel, steel body, dark seams and bolts.
    for y in range(8):
        pats[T_WALL*8+y] = 0x60
        cols[T_WALL*8+y] = 0xFE
        pats[68*8+y] = [255,0,126,90,66,126,0,255][y]
        cols[68*8+y] = [0xE4,0xE4,0xFE,0x4E,0xFE,0xFE,0xE4,0xE4][y]
    # cursor da entrada de iniciais: bloco do tamanho de um glifo
    for y in range(8):
        pats[T_CURSOR*8+y] = 0xFC if y < 7 else 0
        cols[T_CURSOR*8+y] = (LYELLOW << 4) | TRANSPARENT
    for t in (T_WALL_TOP,T_CORNER_L,T_CORNER_R):
        for y in range(8):
            pats[t*8+y] = [0xFF,0xFF,0x81,0xBD,0x81,0xFF,0xFF,0x00][y]
            cols[t*8+y] = [0xF0,0xE0,0x4E,0x4E,0x4E,0xE0,0x40,0x00][y]
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
            else:           # vão entre as linhas de tijolos
                pl, cl, pr, cr = 0x00, TRANSPARENT, 0x00, TRANSPARENT
            pats[tl * 8 + y], cols[tl * 8 + y] = pl, cl
            pats[tr * 8 + y], cols[tr * 8 + y] = pr, cr
    # Silver armor: visually distinct from the colored one-hit bricks.
    for side in range(2):
        for y in range(8):
            pats[(84 + side) * 8 + y] = (0xFE if side else 0x7F) if y < 7 else 0
            cols[(84 + side) * 8 + y] = ([0xF0, 0xEF, 0xEF, 0x4E, 0x4E, 0xEF, 0xE0, 0][y])
    for side in range(2):
        pats[(86+side)*8:(87+side)*8] = pats[(84+side)*8:(85+side)*8]
        cols[(86+side)*8:(87+side)*8] = bytes([0xB0,0xAB,0xAB,0x6A,0x6A,0xAB,0xA0,0])
    # barra de energia do chefão: segmento aceso (degradê) e apagado
    lit = [None, LYELLOW, LRED, LRED, MRED, DRED, None, None]
    for y in range(8):
        pats[T_ENERGY*8+y] = 0xFE if lit[y] else 0
        cols[T_ENERGY*8+y] = (lit[y] << 4) if lit[y] else 0
        pats[T_ENERGY_OFF*8+y] = 0xFE if 2 <= y <= 4 else 0
        cols[T_ENERGY_OFF*8+y] = DBLUE << 4
    return bytes(pats), bytes(cols)


# ---------------------------------------------------------------------------
# Chefão: o rosto de boss_art.py vira tiles próprios (BOSS_T0 em diante), só
# carregados nos bancos 0 e 1 na fase 33. Os tiles dos olhos e da boca vêm
# primeiro, e as versões "dano" e "boca aberta" ficam BOSS_N tiles adiante,
# na mesma ordem: o 6809 troca uma pela outra somando BOSS_N.
# ---------------------------------------------------------------------------
BOSS_T0 = 96
BOSS_COLORS = {".": TRANSPARENT, "n": MGREEN, "G": LGREEN, "b": DBLUE, "B": LBLUE, "r": DRED,
               "c": CYAN, "m": MRED, "R": LRED, "y": DYELLOW, "Y": LYELLOW, "d": DGREEN,
               "M": MAGENTA, "g": GRAY, "w": WHITE}


def boss_tile(img, tx, ty):
    """Tile (tx, ty) da imagem: 8 pares (padrão, cor) em forma canônica."""
    rows = []
    for y in range(8):
        seg = [BOSS_COLORS[c] for c in img[ty * 8 + y][tx * 8:tx * 8 + 8]]
        colors = set(seg)
        assert len(colors) <= 2, "3 cores na tira %d,%d linha %d" % (tx, ty, y)
        if colors == {TRANSPARENT}:
            rows.append((0, 0))
            continue
        fg = max(colors)                       # a transparente (0) nunca é a frente
        bg = min(colors) if len(colors) == 2 else TRANSPARENT
        pattern = sum(0x80 >> x for x, c in enumerate(seg) if c == fg)
        rows.append((pattern, (fg << 4) | bg))
    return tuple(rows)


def boss_tiles():
    """(tiles, mapa 8x8, BOSS_N, nº de tiles dos olhos, nº de tiles da boca)"""
    cells = [(tx, ty) for ty in range(8) for tx in range(8)]
    base, hit, opened = (boss_art.face(), boss_art.face(boss_art.EYES_HIT),
                         boss_art.face(boss_art.MOUTH_OPEN))
    tile = {c: boss_tile(base, *c) for c in cells}
    empty = tuple([(0, 0)] * 8)
    # células que mudam: um índice por par (normal, alternativo); a grade de
    # dentes repete tiles normais que abrem de jeitos diferentes
    pairs = {}
    for variant, img in (("eye", hit), ("mouth", opened)):
        for c in cells:
            alt = boss_tile(img, *c)
            if alt != tile[c]:
                assert c not in pairs, "olho e boca na mesma célula"
                pairs[c] = (variant, tile[c], alt)
    eye_pairs, mouth_pairs = [], []
    for c, (variant, normal, alt) in pairs.items():
        lst = eye_pairs if variant == "eye" else mouth_pairs
        if (normal, alt) not in lst:
            lst.append((normal, alt))
    changed = eye_pairs + mouth_pairs
    order = [normal for normal, _ in changed]
    fixed = []                       # tiles que não mudam, sem repetição
    for c in cells:
        if c not in pairs and tile[c] != empty and tile[c] not in fixed:
            fixed.append(tile[c])
    n = len(order) + len(fixed)
    tiles = order + fixed + [alt for _, alt in changed]
    assert BOSS_T0 + len(tiles) <= 256

    def index(c):
        if c in pairs:
            _, normal, alt = pairs[c]
            return BOSS_T0 + changed.index((normal, alt))
        return 0 if tile[c] == empty else BOSS_T0 + len(order) + fixed.index(tile[c])
    return tiles, [index(c) for c in cells], n, len(eye_pairs), len(mouth_pairs)


def level_bits(rows, chars="#SG"):
    out = bytearray()
    for r in rows:
        v = 0
        for i, c in enumerate(r):
            if c in chars:
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
    top, bottom = title_top(), title_bottom()
    logo_c0, logo_c1 = logo_columns(top)
    logo_bg = {top.bg[y][cx] for y in range(LOGO_Y, LOGO_Y + LOGO_LINES) for cx in range(32)}
    assert len(logo_bg) == 1 and sorted(LOGO_ORDER) == list(range(LOGO_LINES))
    logo_bg = logo_bg.pop()
    # nada de preto opaco (cor 1): com EXTVID ele esconderia o vídeo externo, e
    # com o backdrop preto a cor 0 já aparece preta
    used = (top.colors() + bottom.colors() + game_tiles()[1] + bytes(sum(BARS, []))
            + bytes(c for t in boss_tiles()[0] for _, c in t)
            + bytes(sum((logo_colors(t) for t in range(len(LOGO_THEMES))), [])))
    assert all(BLACK not in (b >> 4, b & 15) for b in used), "cor preta (1) opaca nos dados"
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
    w("LOGO_Y\t\tequ\t%d" % LOGO_Y)
    w("LOGO_LINES\tequ\t%d" % LOGO_LINES)
    w("LOGO_COL0\tequ\t%d" % logo_c0)
    w("LOGO_COL1\tequ\t%d" % logo_c1)
    w("LOGO_THEMES\tequ\t%d" % len(LOGO_THEMES))
    w("T_CURSOR\tequ\t%d" % T_CURSOR)
    for name, spr in SPRITE_EQUS:
        w("%s\tequ\t%d" % (name, SPRITES.index(spr) * 4))
    assert SPRITES.index(SPR_SHOT) * 4 == 8 * 4 + 12, "projétil (tipo 8) usa o padrão do tiro"
    w("")
    # Only glyphs present in the scroller need eight pre-shifted copies in ROM.
    txt = text_index(SCROLL_TEXT)
    charset = sorted(set(txt))
    scroll_font = [FONT[g] for g in charset]
    txt = [charset.index(g) for g in txt]
    # fontes pré-deslocadas para o scroller: SHL_s = glifo<<s, SHR_s = glifo>>(8-s)
    for s in (0, 2, 4, 6):
        w("SHL%d" % s)
        out.extend(fcb_lines(bytes(((b << s) & 0xFF) for g in scroll_font for b in g)))
        w("SHR%d" % s)
        out.extend(fcb_lines(bytes(((b >> (8 - s)) if s else 0) for g in scroll_font for b in g)))
    w("SCROLL_TABS\tfdb\tSHL0,SHR0,SHL2,SHR2,SHL4,SHR4,SHL6,SHR6")
    # texto do scroller como deslocamentos de glifo (índice*8), repetindo o
    # início no fim para a janela de 33 colunas nunca passar do final
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
    w("LOGO_ORDER\t; linhas do logotipo na ordem da troca de tema")
    out.extend(fcb_lines(bytes(LOGO_ORDER), 14))
    w("LOGO_COLORS\t; %d temas x %d linhas (frente<<4 | fundo)" % (len(LOGO_THEMES), LOGO_LINES))
    for t in range(len(LOGO_THEMES)):
        out.extend(fcb_lines(bytes((c << 4) | logo_bg for c in logo_colors(t)), 14))
    w("")
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
    btiles, bmap, bn, beyes, bmouth = boss_tiles()
    bpat = bytes(p for t in btiles for p, _ in t)
    bcol = bytes(c for t in btiles for _, c in t)
    w("T_ENERGY\tequ\t%d" % T_ENERGY)
    w("T_ENERGY_OFF\tequ\t%d" % T_ENERGY_OFF)
    w("BOSS_T0\t\tequ\t%d\t; %d tiles do rosto + %d alternativos" % (BOSS_T0, bn, beyes + bmouth))
    w("BOSS_N\t\tequ\t%d" % bn)
    w("BOSS_EYE0\tequ\t%d" % BOSS_T0)
    w("BOSS_EYE_END\tequ\t%d" % (BOSS_T0 + beyes))
    w("BOSS_MOUTH0\tequ\t%d" % (BOSS_T0 + beyes))
    w("BOSS_MOUTH_END\tequ\t%d" % (BOSS_T0 + beyes + bmouth))
    for name, data in (("BOSS_PAT", bpat), ("BOSS_COL", bcol)):
        packed = rle(data)
        assert unrle(packed) == data
        w("%s\t\t; %d -> %d bytes (RLE)" % (name, len(data), len(packed)))
        out.extend(fcb_lines(packed))
    w("BOSS_MAP\t; 8x8 tiles do rosto (0 = vazio)")
    out.extend(fcb_lines(bytes(bmap), 8))
    for label, text in MESSAGES:
        codes = [ord(ACCENTS.get(ch, ch)) for ch in text.upper()]
        w(("%s\tfcb\t%s,0\t; %s" % (label, ",".join("$%02X" % c for c in codes), text)).rstrip())
    w("LEVELS")
    for i in range(len(LEVELS)):
        w("\t\tfdb LEVEL_%d" % i)
    for i, lv in enumerate(LEVELS):
        data = level_bits(lv, "S") + level_bits(lv, "G") + level_bits(lv)
        packed = rle(data)
        assert unrle(packed) == data
        w("LEVEL_%d" % i)
        out.extend(fcb_lines(packed))
    with open(os.path.join(HERE, "assets.inc"), "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(out) + "\n")

    # prévias
    try:
        from PIL import Image
    except ImportError:
        return
    img = Image.new("RGB", (256, 192), PALETTE[BLACK])
    top.render(img, 0)
    for y, color in enumerate(build_bars(0), 64):
        img.paste(PALETTE[color], (0, y, 256, y + 1))
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
    # Atlas from the same tile bytes and cell maps used by the cartridge; the
    # labels use the cartridge font (with accents), like the game screen.
    atlas = Image.new("RGB", (4*256, 8*120), (12, 16, 24))
    for index, (name, rows) in enumerate(COURTS):
        ox, oy = (index%4)*256, (index//4)*120
        for i, g in enumerate(text_index(f"FASE {index+1:02d}")):
            for py in range(8):
                for px in range(8):
                    if FONT[g][py] & (0x80 >> px):
                        atlas.putpixel((ox+8+i*8+px, oy+8+py), (230,230,240))
        for row, cells in enumerate(rows):
            for col, cell in enumerate(cells):
                if cell == ".":
                    continue
                tile = {"S":84, "G":86}.get(cell, T_BRICK+(row%6)*2)
                for side in range(2):
                    for py in range(8):
                        pattern = gp[(tile+side)*8+py]
                        color = gc[(tile+side)*8+py]
                        for px in range(8):
                            c = color>>4 if pattern & (0x80>>px) else color&15
                            atlas.putpixel((ox+8+col*16+side*8+px, oy+24+row*8+py),PALETTE[c])
    atlas.resize((2048,1920),Image.Resampling.NEAREST).save(os.path.join(BUILD,"preview_levels.png"))
    # chefão: normal, dano e boca aberta, em 4x
    faces = [boss_art.face(), boss_art.face(boss_art.EYES_HIT), boss_art.face(boss_art.MOUTH_OPEN)]
    boss = Image.new("RGB", (3 * 64 + 16, 64), PALETTE[BLACK])
    for i, rows in enumerate(faces):
        for y, row in enumerate(rows):
            for x, c in enumerate(row):
                boss.putpixel((i * 72 + x, y), PALETTE[BOSS_COLORS[c]])
    boss.resize((boss.width * 4, boss.height * 4), Image.NEAREST).save(os.path.join(BUILD, "preview_boss.png"))
    print("assets.inc gerado; prévias em", BUILD)


if __name__ == "__main__":
    sys.exit(main())
