#!/usr/bin/env python3
# Copyright (C) 2026 Leonardo Roman da Rosa
# SPDX-License-Identifier: GPL-3.0-or-later
# Software livre sob a GNU GPL versão 3 ou (a seu critério) posterior; veja LICENSE.
#
"""GUARDIÃO, o chefão da fase 33: rosto de 64x64 pixels (8x8 tiles).

Só a metade esquerda é desenhada; a direita é o espelho dela. Cores (paleta
do TMS9128): `.` transparente, `b` azul-escuro, `B` azul-claro, `g` cinza,
`w` branco, `y`/`Y` amarelo escuro/claro, `m`/`R` vermelho médio/claro,
`c` ciano. No modo Graphics II cada tira de 8x1 pixels de um tile tem só 2
cores, por isso os detalhes seguem a grade de 8 pixels na horizontal
(na vertical a cor pode mudar a cada linha). gen_assets.py confere a regra.
"""

LEFT = [
    "...............................Y",  #  0
    "...............................Y",  #  1
    "..............................YY",  #  2
    "..................YY..........YY",  #  3
    "..................YY.........yyy",  #  4
    ".................YYYY........yyy",  #  5
    "..............bbgyyyygggggggyyyy",  #  6
    "...........bbbbbyyyyyywwwwwwyyyy",  #  7
    ".........bbbbbbbyyyyyywwwwwyyyyy",  #  8
    ".......bggggggggyyyyyyggggyyyyyy",  #  9
    "......YYYYYYYYYYYYYYYYYYYYYYYYYY",  # 10
    ".....yyyyyyyyyyyyyyyyyyyyyyyyyRR",  # 11
    "....yyyyymmyyyyyymmyyyyyyyyyymmm",  # 12
    "....YYYYYYYYYYYYYYYYYYYYYYYYYYmm",  # 13
    "...bbbbbbbbbbbbbbbbbbbbbbbbbbbbb",  # 14
    "...bbbbbBgggggggggggggggbbbbbbbc",  # 15
    "..bbbbbbBgggggggggggggggbbbbbbcc",  # 16
    "..bbbbbbBgggggggggggggggbbbbbccc",  # 17
    ".bbbbbbbBgggggggggggggggbbbbcccc",  # 18
    ".bbbbbbb...gggggggggggggbbbbbccc",  # 19
    ".bbbbbbb......ggggggggggbbbbbbcc",  # 20
    ".................gggggggbbbbbbbc",  # 21
    ".bbbbbbb............gggggggggggg",  # 22
    ".bbbbbbb...............ggggggggg",  # 23
    ".bbbbbbb................ggggggww",  # 24
    ".bbbbbbb...........mmmm.ggggggww",  # 25
    ".bbbbbbb.......RRRRRRRR.ggggggww",  # 26
    ".bbbbbbb...YYYYYYYYYYYY.ggggggww",  # 27
    ".bbbbbbb..YYYYYYYYYYYY..ggggggww",  # 28
    "...........RRRRRRRRR....ggggggww",  # 29
    ".bbbbbbb.....mmmm.......ggggggww",  # 30
    ".bbbbbbb................ggggggww",  # 31
    ".bbbbbbbBgggggggggggggggggggggww",  # 32
    ".bbbbbbbbbbbbbbgggggggggggggggww",  # 33
    ".bbbbbbbBgggggggggggggggggggggww",  # 34
    ".bbbbbbbbbbbbbbgggggggggggggggww",  # 35
    ".bbbbbbbBgggggggggggggggggggggww",  # 36
    "........bbbbbbbgggggggggggggbbgg",  # 37
    ".bbbbbbbBgggggggggggggggggggbbgg",  # 38
    ".bbbbbbbBggggggggggggggggggggggg",  # 39
    ".bbbbbbbBggggggggggggggggggggggg",  # 40
    ".bbbbbbbBggggggggggggggggggggggg",  # 41
    "..bbbbbbBggggggg.ww..ww..ww..ww.",  # 42
    "..bbbbbbBggggggg.ww..ww..ww..ww.",  # 43
    "...bbbbbBggggggg.ww..ww..ww..ww.",  # 44
    "........Bggggggg.ww..ww..ww..ww.",  # 45
    "....bbbbBggggggg.ww..ww..ww..ww.",  # 46
    "....bbbbBgggggggwwww............",  # 47
    ".....bbbBggggggg.www............",  # 48
    "......bbBggggggg.ww..ww..ww..ww.",  # 49
    ".......bBggggggg.ww..ww..ww..ww.",  # 50
    "........bbbbbbbb.ww..ww..ww..ww.",  # 51
    ".........bbbbbbb.ww..ww..ww..ww.",  # 52
    "..........bbbbbb.ww..ww..ww..ww.",  # 53
    "...........bbbbbBggggggggggggggg",  # 54
    "............bbbbBggggggggYYggggg",  # 55
    ".............bbbBgggggggggYYgggg",  # 56
    "..............bbBggggggggggyyggg",  # 57
    "................bbbbbbbbggggyygg",  # 58
    "..................bbbbbbgggggyyg",  # 59
    "....................bbbbgggggyyy",  # 60
    "......................bbgggggggg",  # 61
    "........................bbbbbbbb",  # 62
    "..........................bbbbbb",  # 63
]

# boca aberta, quando ele atira (linhas que mudam)
MOUTH_OPEN = {
    45: "........Bggggggg......mmmmmmmmmm",
    46: "....bbbbBggggggg...RRRRRRRRRRRRR",
    47: "....bbbbBggggggg.YYYYYYYYYYYYYYY",
    48: ".....bbbBggggggg.YYYYYYYYYYYYYYY",
    49: "......bbBggggggg...RRRRRRRRRRRRR",
    50: ".......bBggggggg......mmmmmmmmmm",
}

# olhos brancos por um instante ao levar dano
EYES_HIT = {
    25: ".bbbbbbb...........YYYY.ggggggww",
    26: ".bbbbbbb.......wwwwwwww.ggggggww",
    27: ".bbbbbbb...wwwwwwwwwwww.ggggggww",
    28: ".bbbbbbb..wwwwwwwwwwww..ggggggww",
    29: "...........wwwwwwwww....ggggggww",
    30: ".bbbbbbb.....YYYY.......ggggggww",
}


def face(*overlays):
    """64 linhas de 64 pixels: a metade esquerda com as trocas pedidas, espelhada."""
    rows = list(LEFT)
    for overlay in overlays:
        for y, row in overlay.items():
            rows[y] = row
    return [row + row[::-1] for row in rows]
