#!/usr/bin/env python3
# Copyright (C) 2026 Leonardo Roman da Rosa
# SPDX-License-Identifier: GPL-3.0-or-later
# Software livre sob a GNU GPL versão 3 ou (a seu critério) posterior; veja LICENSE.
#
"""Gera o footprint do soquete fêmea de borda 2x18 que encaixa nos dedos do CN1 do VET 3000.

    python gen_footprint.py [passo_mm] [distancia_entre_fileiras_mm]

Padrão: passo 2,54 mm (0,1"), fileiras a 5,08 mm (0,2"), o comum em soquetes de borda
de 0,1" com terminais para PCI (ex.: Sullins EBC18DCxN, TE 5530843). CONFIRA no datasheet
do soquete comprado e meça o passo dos dedos do VET (43,18 mm entre os centros do 1o e do
18o dedo = 2,54 mm).

Orientação: o cartucho fica em pé atrás do VET com os componentes voltados para o
aparelho. Visto pela frente da placa (como no KiCad), o pino 1 fica à DIREITA.
Pads "a1".."a18" = fileira de cima (contatos da face de componentes do VET, sinais de
dados); "b1".."b18" = fileira de baixo (endereços).
"""
import os
import sys

pitch = float(sys.argv[1]) if len(sys.argv) > 1 else 2.54
row = float(sys.argv[2]) if len(sys.argv) > 2 else 5.08
N = 18
name = "CardEdge_Socket_2x18_P%.2fmm_Row%.2fmm" % (pitch, row)
here = os.path.dirname(os.path.abspath(__file__))
out_dir = os.path.join(here, "..", "vet3000.pretty")
os.makedirs(out_dir, exist_ok=True)

half_len = (N - 1) / 2 * pitch
body_x = half_len + 3.4          # corpo plástico ~3,4 mm além do último contato
body_y = row / 2 + 1.5


def fmt(v):
    s = "%.4f" % v
    s = s.rstrip("0").rstrip(".")
    return "0" if s in ("-0", "") else s


lines = []
w = lines.append
w('(footprint "%s"' % name)
w('\t(version 20260206)')
w('\t(generator "vet3000_gen_footprint")')
w('\t(layer "F.Cu")')
w('\t(descr "Soquete femea de borda de placa 2x%d, passo %.2fmm, fileiras a %.2fmm, para o '
  'conector CN1 do VET 3000 (pino 1 a direita, fileira a em cima)")' % (N, pitch, row))
w('\t(tags "card edge socket 2x%d %.2fmm VET3000 CN1")' % (N, pitch))


def prop(key, val, x, y, layer, hide=False, size=1.0):
    w('\t(property "%s" "%s"' % (key, val))
    w('\t\t(at %s %s 0)' % (fmt(x), fmt(y)))
    w('\t\t(layer "%s")' % layer)
    if hide:
        w('\t\t(hide yes)')
    w('\t\t(effects\n\t\t\t(font\n\t\t\t\t(size %s %s)\n\t\t\t\t(thickness 0.15)\n\t\t\t)\n\t\t)' % (fmt(size), fmt(size)))
    w('\t)')


prop("Reference", "REF**", 0, -body_y - 1.6, "F.SilkS")
prop("Value", name, 0, body_y + 1.6, "F.Fab")
w('\t(attr through_hole)')
w('\t(duplicate_pad_numbers_are_jumpers no)')


def line(x1, y1, x2, y2, layer, width):
    w('\t(fp_line\n\t\t(start %s %s)\n\t\t(end %s %s)\n\t\t(stroke\n\t\t\t(width %s)\n\t\t\t(type solid)\n\t\t)\n'
      '\t\t(layer "%s")\n\t)' % (fmt(x1), fmt(y1), fmt(x2), fmt(y2), fmt(width), layer))


def rect(x1, y1, x2, y2, layer, width):
    w('\t(fp_rect\n\t\t(start %s %s)\n\t\t(end %s %s)\n\t\t(stroke\n\t\t\t(width %s)\n\t\t\t(type solid)\n\t\t)\n'
      '\t\t(fill no)\n\t\t(layer "%s")\n\t)' % (fmt(x1), fmt(y1), fmt(x2), fmt(y2), fmt(width), layer))


def text(t, x, y, layer, size=0.9):
    w('\t(fp_text user "%s"\n\t\t(at %s %s 0)\n\t\t(layer "%s")\n\t\t(effects\n\t\t\t(font\n'
      '\t\t\t\t(size %s %s)\n\t\t\t\t(thickness 0.15)\n\t\t\t)\n\t\t)\n\t)'
      % (t, fmt(x), fmt(y), layer, fmt(size), fmt(size)))


# corpo (silk/fab), fenda central e pátio
rect(-body_x, -body_y, body_x, body_y, "F.SilkS", 0.12)
rect(-body_x + 0.1, -body_y + 0.1, body_x - 0.1, body_y - 0.1, "F.Fab", 0.1)
line(-half_len - 1.0, 0, half_len + 1.0, 0, "F.Fab", 0.1)            # fenda
rect(-body_x - 0.5, -body_y - 0.5, body_x + 0.5, body_y + 0.5, "F.CrtYd", 0.05)
# marcas de pino 1 (direita) e 18 (esquerda), fileiras a/b
text("a1", half_len + 2.0, -row / 2, "F.SilkS", 0.8)
text("b1", half_len + 2.0, row / 2, "F.SilkS", 0.8)
text("a18", -half_len - 2.2, -row / 2, "F.SilkS", 0.8)
text("b18", -half_len - 2.2, row / 2, "F.SilkS", 0.8)
text("${REFERENCE}", 0, 0, "F.Fab")

for r, y in (("a", -row / 2), ("b", row / 2)):
    for n in range(1, N + 1):
        x = (N + 1 - 2 * n) / 2 * pitch      # n=1 -> direita
        shape = "rect" if n == 1 else "circle"
        w('\t(pad "%s%d" thru_hole %s\n\t\t(at %s %s)\n\t\t(size 1.7 1.7)\n\t\t(drill 1)\n'
          '\t\t(layers "*.Cu" "*.Mask")\n\t\t(remove_unused_layers no)\n\t)' % (r, n, shape, fmt(x), fmt(y)))
w('\t(embedded_fonts no)')
w(')')
path = os.path.join(out_dir, name + ".kicad_mod")
open(path, "w", encoding="utf-8", newline="\n").write("\n".join(lines) + "\n")
print(path)
