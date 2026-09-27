# Copyright (C) 2026 Leonardo Roman da Rosa
# SPDX-License-Identifier: GPL-3.0-or-later
# Software livre sob a GNU GPL versão 3 ou (a seu critério) posterior; veja LICENSE.
#
"""Etapas KiCad <-> Freerouting (rodar com o Python do KiCad; caminhos SEM espaços para o Freerouting).

    python route.py decoy  REAL.kicad_pcb  ISCA.kicad_pcb   placa-isca: sem zonas, contorno recuado 0,35 mm
    python route.py export ISCA.kicad_pcb  rota.dsn
    python route.py tweak  rota.dsn 250 600 200       larguras (sinal, +5V/GND) e isolação em um
    freerouting.exe -de rota.dsn -do rota.ses -mp 300
    python route.py import REAL.kicad_pcb  rota.ses         aplica as trilhas, preenche as zonas e salva

Sem zonas o Freerouting não trata o GND como plano (que o faria desistir de redes), e com o
contorno recuado o cobre fica a >= 0,5 mm da borda real.
"""
import math
import os
import shutil
import sys

import pcbnew

INSET = 0.35
step, src = sys.argv[1], sys.argv[2]

if step == "decoy":
    dst = sys.argv[3]
    b = pcbnew.LoadBoard(src)
    # coleta tudo antes de remover (remoções invalidam os proxies SWIG)
    zones = list(b.Zones())
    edges = [d for d in b.GetDrawings() if d.GetLayer() == pcbnew.Edge_Cuts]
    bb = b.GetBoardEdgesBoundingBox()
    x1, y1 = pcbnew.ToMM(bb.GetLeft()) + INSET, pcbnew.ToMM(bb.GetTop()) + INSET
    x2, y2 = pcbnew.ToMM(bb.GetRight()) - INSET, pcbnew.ToMM(bb.GetBottom()) - INSET
    for item in zones + edges:
        b.Remove(item)
    r = 3.0 - INSET

    def P(x, y):
        return pcbnew.VECTOR2I(pcbnew.FromMM(x), pcbnew.FromMM(y))

    def seg(a, c):
        s = pcbnew.PCB_SHAPE(b)
        s.SetShape(pcbnew.SHAPE_T_SEGMENT)
        s.SetStart(P(*a))
        s.SetEnd(P(*c))
        s.SetLayer(pcbnew.Edge_Cuts)
        s.SetWidth(pcbnew.FromMM(0.1))
        b.Add(s)

    def arc(cx, cy, a0):
        s = pcbnew.PCB_SHAPE(b)
        s.SetShape(pcbnew.SHAPE_T_ARC)
        pts = [(cx + r * math.cos(math.radians(a0 + k * 45)), cy + r * math.sin(math.radians(a0 + k * 45)))
               for k in range(3)]
        s.SetArcGeometry(P(*pts[0]), P(*pts[1]), P(*pts[2]))
        s.SetLayer(pcbnew.Edge_Cuts)
        s.SetWidth(pcbnew.FromMM(0.1))
        b.Add(s)

    seg((x1 + r, y1), (x2 - r, y1))
    seg((x2, y1 + r), (x2, y2 - r))
    seg((x2 - r, y2), (x1 + r, y2))
    seg((x1, y2 - r), (x1, y1 + r))
    arc(x2 - r, y1 + r, 270)
    arc(x2 - r, y2 - r, 0)
    arc(x1 + r, y2 - r, 90)
    arc(x1 + r, y1 + r, 180)
    pcbnew.SaveBoard(dst, b)
    # o exportador lê as classes de rede do .kicad_pro de mesmo nome
    shutil.copy(os.path.splitext(src)[0] + ".kicad_pro", os.path.splitext(dst)[0] + ".kicad_pro")
    print("isca:", dst)

elif step == "export":
    ok = pcbnew.ExportSpecctraDSN(pcbnew.LoadBoard(src), sys.argv[3])
    print("DSN:", ok)
    sys.exit(0 if ok else 1)

elif step == "tweak":
    # larguras/isolação no DSN e +5V/GND numa classe "power" mais larga
    import re
    w_sig, w_pow, clr = (sys.argv[3:6] + ["250", "600", "200"][len(sys.argv[3:6]):])
    text = open(src, encoding="utf-8").read()
    text = re.sub(r"\(width \d+\)", "(width %s)" % w_sig, text)
    text = re.sub(r"\(clearance \d+\)", "(clearance %s)" % clr, text)
    i = text.find("(class kicad_default")
    d, j = 0, i
    while True:
        d += {"(": 1, ")": -1}.get(text[j], 0)
        if d == 0 and text[j] == ")":
            break
        j += 1
    block = text[i:j + 1]
    hend = block.find("(", 1)
    header = block[:hend]
    pnets = [n for n in (" +5V", " GND") if n in header]
    for n in pnets:
        header = header.replace(n, "", 1)
    power = re.sub(r"\(class\s+kicad_default[^(]*", "(class power%s\n      " % "".join(pnets), block, count=1)
    power = power.replace("(width %s)" % w_sig, "(width %s)" % w_pow)
    text = text[:i] + header + block[hend:] + "\n    " + power + text[j + 1:]
    open(src, "w", encoding="utf-8").write(text)
    print("DSN: sinais %s um, power %s um (%s), isolação %s um" % (w_sig, w_pow, "".join(pnets).strip(), clr))

elif step == "import":
    ses = sys.argv[3]
    b = pcbnew.LoadBoard(src)
    if not pcbnew.ImportSpecctraSES(b, ses):
        sys.exit("falha ao importar o SES; placa intocada")
    pcbnew.ZONE_FILLER(b).Fill(b.Zones())
    pcbnew.SaveBoard(src, b)
    tracks = list(b.GetTracks())
    print("importado: %d segmentos, %d vias" % (sum(t.GetClass() == "PCB_TRACK" for t in tracks),
                                               sum(t.GetClass() == "PCB_VIA" for t in tracks)))
