# Copyright (C) 2026 Leonardo Roman da Rosa
# SPDX-License-Identifier: CERN-OHL-S-2.0
# Hardware aberto sob a CERN-OHL-S v2 (ver hardware/cartucho/LICENSE).
# Source location: https://github.com/lrrosa/vet3000
#
"""Monta a placa (sem trilhas) a partir do netlist do esquemático. Rodar com o Python do KiCad:

    kicad-cli sch export netlist --format kicadsexpr -o vet3000_cartucho.net vet3000_cartucho.kicad_sch
    "C:/Program Files/KiCad/10.0/bin/python.exe" gen/gen_pcb.py

Faz o papel do "Atualizar placa a partir do esquemático": footprints com o mesmo UUID dos
símbolos, redes, posicionamento, contorno, serigrafia e zonas de GND (preenchidas depois do
roteamento, ver gen/route.py).
"""
import os
import sys

import pcbnew

HERE = os.path.dirname(os.path.abspath(__file__))
PRJ_DIR = os.path.abspath(os.path.join(HERE, ".."))
NET = os.path.join(PRJ_DIR, "vet3000_cartucho.net")
PCB = os.path.join(PRJ_DIR, "vet3000_cartucho.kicad_pcb")
KFP = os.environ.get("KICAD_FP", r"C:/Program Files/KiCad/10.0/share/kicad/footprints")
LIBS = {"vet3000": os.path.join(PRJ_DIR, "vet3000.pretty")}

# contorno da placa (mm)
X0, Y0, W, H, R = 100.0, 100.0, 72.0, 60.0, 3.0

# posicionamento: ref -> (x, y, rotação em graus)
PLACE = {
    "J1": (136.0, 153.0, 0),       # soquete de borda: fileira a em y=150,46, b em y=155,54
    "U1": (119.5, 142.0, 90),      # EPROM: pino 1 embaixo à esquerda, pinos 1-14 na fileira de baixo
    "U2": (135.0, 121.0, 90),      # 74HCT00
    "C1": (158.5, 136.0, 90),      # desacoplamento da EPROM
    "C2": (135.0, 108.0, 0),       # desacoplamento do 74HCT00
    "C3": (105.0, 145.0, 0),       # eletrolítico de entrada
    "JP1": (105.0, 131.0, 0),      # pino 1 da EPROM (VPP/A15)
    "JP2": (105.0, 118.0, 0),      # pino 27 da EPROM (PGM/A14/WE)
    "JP3": (158.0, 116.0, 0),      # ATIVO
    "R1": (165.0, 124.0, 90),      # pull-up do /CE
    "J2": (112.0, 104.5, 90),      # expansão
    "H1": (104.5, 104.5, 0),
    "H2": (167.5, 104.5, 0),
}


# ---------------------------------------------------------------------------
def parse_sexpr(text):
    tokens, i, n = [], 0, len(text)
    while i < n:
        c = text[i]
        if c in "()":
            tokens.append(c)
            i += 1
        elif c.isspace():
            i += 1
        elif c == '"':
            j = i + 1
            buf = []
            while text[j] != '"':
                if text[j] == "\\":
                    j += 1
                buf.append(text[j])
                j += 1
            tokens.append(("str", "".join(buf)))
            i = j + 1
        else:
            j = i
            while j < n and not text[j].isspace() and text[j] not in "()":
                j += 1
            tokens.append(text[i:j])
            i = j

    def build(k):
        lst = []
        while k < len(tokens):
            t = tokens[k]
            if t == "(":
                sub, k = build(k + 1)
                lst.append(sub)
            elif t == ")":
                return lst, k + 1
            else:
                lst.append(t[1] if isinstance(t, tuple) else t)
                k += 1
        return lst, k

    return build(0)[0][0]


def find(node, key):
    return [x for x in node if isinstance(x, list) and x and x[0] == key]


def val(node, key):
    f = find(node, key)
    return f[0][1] if f and len(f[0]) > 1 else None


net = parse_sexpr(open(NET, encoding="utf-8").read())
comps = []
for c in find(find(net, "components")[0], "comp"):
    comps.append({"ref": val(c, "ref"), "value": val(c, "value"), "footprint": val(c, "footprint"),
                  "tstamp": val(c, "tstamps")})
nets = {}
for n in find(find(net, "nets")[0], "net"):
    name = val(n, "name")
    nets[name] = [(val(nd, "ref"), val(nd, "pin")) for nd in find(n, "node")]

# ---------------------------------------------------------------------------
mm = pcbnew.FromMM


def P(x, y):
    return pcbnew.VECTOR2I(mm(x), mm(y))


board = pcbnew.NewBoard(PCB)
board.SetCopperLayerCount(2)
ds = board.GetDesignSettings()
ds.SetBoardThickness(mm(1.6))

netinfo = {}
for name in sorted(nets):
    ni = pcbnew.NETINFO_ITEM(board, name)
    board.Add(ni)
    netinfo[name] = ni

fps = {}
for c in comps:
    lib, name = c["footprint"].split(":")
    path = LIBS.get(lib, os.path.join(KFP, lib + ".pretty"))
    fp = pcbnew.FootprintLoad(path, name)
    if fp is None:
        sys.exit("footprint não encontrado: " + c["footprint"])
    fp.SetFPID(pcbnew.LIB_ID(lib, name))
    fp.SetReference(c["ref"])
    fp.SetValue(c["value"])
    fp.SetPath(pcbnew.KIID_PATH("/" + c["tstamp"]))
    x, y, rot = PLACE[c["ref"]]
    board.Add(fp)
    fp.SetPosition(P(x, y))
    fp.SetOrientationDegrees(rot)
    fp.Value().SetVisible(False)
    if c["ref"].startswith("H"):
        fp.Reference().SetVisible(False)
    fps[c["ref"]] = fp

for name, nodes in nets.items():
    for ref, pin in nodes:
        pad = fps[ref].FindPadByNumber(pin)
        if pad is None:
            sys.exit("pad %s de %s não existe" % (pin, ref))
        pad.SetNet(netinfo[name])

# contorno com cantos arredondados
def seg(x1, y1, x2, y2, layer=pcbnew.Edge_Cuts, width=0.1):
    s = pcbnew.PCB_SHAPE(board)
    s.SetShape(pcbnew.SHAPE_T_SEGMENT)
    s.SetStart(P(x1, y1))
    s.SetEnd(P(x2, y2))
    s.SetLayer(layer)
    s.SetWidth(mm(width))
    board.Add(s)


def arc(cx, cy, sx, sy, ex, ey):
    import math
    a1 = math.atan2(sy - cy, sx - cx)
    a2 = math.atan2(ey - cy, ex - cx)
    d = a2 - a1
    while d > math.pi:
        d -= 2 * math.pi
    while d < -math.pi:
        d += 2 * math.pi
    am = a1 + d / 2
    s = pcbnew.PCB_SHAPE(board)
    s.SetShape(pcbnew.SHAPE_T_ARC)
    s.SetArcGeometry(P(sx, sy), P(cx + R * math.cos(am), cy + R * math.sin(am)), P(ex, ey))
    s.SetLayer(pcbnew.Edge_Cuts)
    s.SetWidth(mm(0.1))
    board.Add(s)


x1, y1, x2, y2 = X0, Y0, X0 + W, Y0 + H
seg(x1 + R, y1, x2 - R, y1)
seg(x2, y1 + R, x2, y2 - R)
seg(x2 - R, y2, x1 + R, y2)
seg(x1, y2 - R, x1, y1 + R)
arc(x2 - R, y1 + R, x2 - R, y1, x2, y1 + R)
arc(x2 - R, y2 - R, x2, y2 - R, x2 - R, y2)
arc(x1 + R, y2 - R, x1 + R, y2, x1, y2 - R)
arc(x1 + R, y1 + R, x1, y1 + R, x1 + R, y1)


# serigrafia
def text(t, x, y, size=1.0, layer=pcbnew.F_SilkS, bold=False, rot=0, just="center"):
    tx = pcbnew.PCB_TEXT(board)
    tx.SetText(t)
    tx.SetPosition(P(x, y))
    tx.SetLayer(layer)
    tx.SetTextSize(pcbnew.VECTOR2I(mm(size), mm(size)))
    tx.SetTextThickness(mm(size * (0.2 if bold else 0.15)))
    tx.SetBold(bold)
    if rot:
        tx.SetTextAngleDegrees(rot)
    tx.SetHorizJustify({"center": pcbnew.GR_TEXT_H_ALIGN_CENTER, "left": pcbnew.GR_TEXT_H_ALIGN_LEFT,
                        "right": pcbnew.GR_TEXT_H_ALIGN_RIGHT}[just])
    if layer == pcbnew.B_SilkS:
        tx.SetMirrored(True)
    board.Add(tx)


text("VET 3000", 163.5, 140.0, 1.5, bold=True)
text("CARTUCHO", 163.5, 142.3, 1.0)
text("v1.0", 163.5, 144.3, 1.0)
text("JP2: pino 27", 108.0, 115.5, 0.8, just="left")
text("JP1: pino 1", 108.0, 128.5, 0.8, just="left")
for ytop in (118.0, 131.0):                   # rótulos dos pinos 1 (GND) e 3 (+5V) dos jumpers
    text("GND", 108.0, ytop + 0.35, 0.8, just="left")
    text("+5V", 108.0, ytop + 5.43, 0.8, just="left")
text("ATIVO", 156.4, 117.3, 0.8, just="right")
text("+5V IRQ HLT RW Y2 ROM 1G GND", 120.9, 107.0, 0.8)
text("COMPONENTES VOLTADOS PARA O VET", 136.0, 158.7, 0.8)
# verso: é o lado que fica à vista com o cartucho encaixado (textos nas faixas sem pads)
text("VET 3000", 136.0, 132.0, 2.6, layer=pcbnew.B_SilkS, bold=True)
text("cartucho de ROM - conector CN1", 136.0, 135.7, 1.2, layer=pcbnew.B_SilkS)
text("ESTE LADO PARA FORA", 136.0, 139.0, 1.2, layer=pcbnew.B_SilkS, bold=True)
text("27C128: JP1 2-3, JP2 2-3; JP3 fechado = ativo", 136.0, 123.9, 1.0, layer=pcbnew.B_SilkS)
text("(c) 2026 Leonardo Roman da Rosa - CERN-OHL-S-2.0", 136.0, 146.3, 0.8, layer=pcbnew.B_SilkS)
text("github.com/lrrosa/vet3000", 136.0, 128.7, 0.8, layer=pcbnew.B_SilkS)   # source location
text("pino 1 do CN1", 152.0, 158.6, 0.8, layer=pcbnew.B_SilkS)

# zonas de GND nas duas faces (preenchidas depois do roteamento)
for layer in (pcbnew.F_Cu, pcbnew.B_Cu):
    z = pcbnew.ZONE(board)
    z.SetLayer(layer)
    z.SetNet(netinfo["GND"])
    ol = z.Outline()
    ol.NewOutline()
    for (x, y) in ((x1, y1), (x2, y1), (x2, y2), (x1, y2)):
        ol.Append(mm(x), mm(y))
    z.SetLocalClearance(mm(0.3))
    z.SetMinThickness(mm(0.25))
    z.SetPadConnection(pcbnew.ZONE_CONNECTION_THERMAL)
    z.SetThermalReliefGap(mm(0.4))
    z.SetThermalReliefSpokeWidth(mm(0.5))
    z.SetIsFilled(False)
    board.Add(z)

pcbnew.SaveBoard(PCB, board)
print("placa:", PCB, "componentes:", len(fps), "redes:", len(nets))
