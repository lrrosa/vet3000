#!/usr/bin/env python3
# Copyright (C) 2026 Leonardo Roman da Rosa
# SPDX-License-Identifier: CERN-OHL-S-2.0
# Hardware aberto sob a CERN-OHL-S v2 (ver hardware/cartucho/LICENSE).
# Source location: https://github.com/lrrosa/vet3000
#
"""Gera o diagrama de fiação (SVG) do cartucho montado em placa protótipo de uma face.

    python gen/gen_fiacao.py

As ligações vêm da tabela NETS abaixo e são conferidas contra o netlist do KiCad
(vet3000_cartucho.net): se o esquemático mudar e o diagrama não, o script para com erro.

Os barramentos de endereço e dados têm traçado fixo (FIXED): A0-A7 sobem retos do J1 ao U1,
D0-D7 e A8-A13 correm em faixas paralelas. O resto é roteado por um A* numa grade de 10 px,
que só deixa fios se cruzarem em ângulo reto (desenhado com arco). No fim o script confere,
pelo desenho, que cada rede é um traço contínuo e que nenhuma encosta em outra.
"""
import heapq
import html
import os
import re

HERE = os.path.dirname(os.path.abspath(__file__))
PRJ = os.path.abspath(os.path.join(HERE, ".."))
NETFILE = os.path.join(PRJ, "vet3000_cartucho.net")
OUT = os.path.join(PRJ, "fiacao-prototipo.svg")

W, H = 1800, 1860
FONT = "DejaVu Sans, Verdana, Arial, sans-serif"
MONO = "DejaVu Sans Mono, Consolas, monospace"
BG, INK, GRAY, BOX, WARN, NCRED = "#f6f6f2", "#1a1a1a", "#6b6b6b", "#3a3a3a", "#8a3b00", "#b03030"
RED, BLACK = "#cc2222", "#1a1a1a"
C_ADDR, C_DATA, C_CTRL, C_JMP, C_EXP = "#1f6fd0", "#218c4f", "#d97706", "#7a4fbf", "#008b8b"

# ---------------------------------------------------------------------------
# ligações (iguais às do esquemático; conferidas contra o netlist)
# ---------------------------------------------------------------------------
NETS = {}       # rede -> (cor, [(ref, pino)])


def net(name, color, *pins):
    NETS[name] = (color, list(pins))


EP_A = ["10", "9", "8", "7", "6", "5", "4", "3", "25", "24", "21", "23", "2", "26"]
EP_D = ["11", "12", "13", "15", "16", "17", "18", "19"]
for i in range(8):
    net("D%d" % i, C_DATA, ("J1", "a%d" % (i + 2)), ("U1", EP_D[i]))
for i in range(14):
    net("A%d" % i, C_ADDR, ("J1", "b%d" % (i + 2)), ("U1", EP_A[i]))
net("R_W", C_CTRL, ("J1", "a12"), ("U2", "1"), ("U2", "2"), ("J2", "4"))
net("OE_N", C_CTRL, ("U2", "3"), ("U1", "22"))
net("CART_SEL", C_CTRL, ("J1", "a14"), ("JP3", "1"))
net("CE_N", C_CTRL, ("JP3", "2"), ("U1", "20"), ("R1", "2"))
net("EP_PIN1", C_JMP, ("JP1", "2"), ("U1", "1"))
net("EP_PIN27", C_JMP, ("JP2", "2"), ("U1", "27"))
net("IRQ", C_EXP, ("J1", "a1"), ("J2", "2"))
net("HALT", C_EXP, ("J1", "a13"), ("J2", "3"))
net("IO_SEL", C_EXP, ("J1", "a11"), ("J2", "5"))
net("ROM_E", C_EXP, ("J1", "a10"), ("J2", "6"))
net("DEC_EN", C_EXP, ("J1", "a16"), ("J2", "7"))
net("+5V", RED, ("J1", "a15"), ("U1", "28"), ("U2", "14"), ("JP1", "3"), ("JP2", "3"), ("R1", "1"),
    ("J2", "1"), ("C1", "1"), ("C2", "1"), ("C3", "1"))
net("GND", BLACK, ("J1", "a17"), ("J1", "b17"), ("U1", "14"), ("U2", "7"), ("U2", "4"), ("U2", "5"),
    ("U2", "9"), ("U2", "10"), ("U2", "12"), ("U2", "13"), ("JP1", "1"), ("JP2", "1"), ("J2", "8"),
    ("C1", "2"), ("C2", "2"), ("C3", "2"))
NOT_CONNECTED = [("J1", "a18"), ("J1", "b1"), ("J1", "b16"), ("J1", "b18"),
                 ("U2", "6"), ("U2", "8"), ("U2", "11")]
# o J2 (opcional) é indicado por rótulos, sem fio desenhado; os contatos do J1 que só vão
# para ele também ficam sem fio
LABEL_ONLY = {k for n in NETS for k in NETS[n][1] if k[0] == "J2"} | {
    ("J1", "a1"), ("J1", "a10"), ("J1", "a11"), ("J1", "a13"), ("J1", "a16")}

# nomes curtos (como no conector-cn1.md e na serigrafia da PCI)
SHORT = {"R_W": "R/W", "OE_N": "/OE", "CE_N": "/CE", "CART_SEL": "Y1", "IO_SEL": "Y2", "ROM_E": "E",
         "DEC_EN": "1G", "EP_PIN1": "VPP", "EP_PIN27": "/PGM"}


def short(n):
    return SHORT.get(n, n)


def check_against_kicad():
    txt = open(NETFILE, encoding="utf-8").read()
    kicad = {}
    for m in re.finditer(r'\(net\s+\(code "?\d+"?\)\s+\(name "([^"]*)"\)(.*?)\n\t\t\)', txt, re.S):
        name = m.group(1).lstrip("/")
        if name.startswith("unconnected-"):
            continue
        kicad[name] = set(re.findall(r'\(node\s+\(ref "([^"]+)"\)\s+\(pin "([^"]+)"\)', m.group(2)))
    mine = {n: set(p) for n, (_c, p) in NETS.items()}
    bad = ["%s: KiCad %s / diagrama %s" % (n, sorted(kicad.get(n, ())), sorted(mine.get(n, ())))
           for n in sorted(set(kicad) | set(mine)) if kicad.get(n) != mine.get(n)]
    if bad:
        raise SystemExit("diagrama diferente do esquemático:\n  " + "\n  ".join(bad))
    print("netlist: %d redes conferem com o KiCad" % len(mine))


def net_of(key):
    for n, (_c, pins) in NETS.items():
        if key in pins:
            return n
    return None


def color_of(key):
    n = net_of(key)
    return NETS[n][0] if n else GRAY


# ---------------------------------------------------------------------------
# peças, vistas pelo lado dos componentes: pino -> (x, y, direção de saída do fio)
# ---------------------------------------------------------------------------
G, STUB = 10, 20
PINS, STUBS, BOXES = {}, {}, []
DIRV = {"U": (0, -1), "D": (0, 1), "L": (-1, 0), "R": (1, 0)}

# J1: coluna 0 = a18/b18 (esquerda) ... coluna 17 = a1/b1 (direita)
J1X = lambda c: 400 + 40 * c
J1_A, J1_B, J1_BOT = 1140, 1200, 1220
J1_DOWN = ["b%d" % n for n in range(10, 16)]     # A8-A13 saem por baixo e contornam pela esquerda
for n in range(1, 19):
    x = J1X(18 - n)
    PINS[("J1", "a%d" % n)] = (x, J1_A, "U")
    if "b%d" % n in J1_DOWN:
        PINS[("J1", "b%d" % n)] = (x, J1_BOT, "D")
        STUBS[("J1", "b%d" % n)] = [(x, J1_B), (x, J1_BOT)]
    else:
        # sobe entre dois pinos da fileira a
        PINS[("J1", "b%d" % n)] = (x + 20, J1_A, "U")
        STUBS[("J1", "b%d" % n)] = [(x, J1_B), (x + 20, J1_B), (x + 20, J1_A)]
BOXES.append((375, J1_A, 1105, J1_BOT))

# U1 27C128, chanfro à esquerda: 1-14 embaixo (esq->dir), 15-28 em cima (dir->esq)
U1X0, U1_TOP, U1_BOT = 700, 760, 880
for p in range(1, 15):
    PINS[("U1", str(p))] = (U1X0 + 40 * (p - 1), U1_BOT, "D")
for p in range(15, 29):
    PINS[("U1", str(p))] = (U1X0 + 40 * (28 - p), U1_TOP, "U")
BOXES.append((U1X0 - 20, U1_TOP, U1X0 + 13 * 40 + 20, U1_BOT))

# U2 74HCT00
U2X0, U2_TOP, U2_BOT = 760, 440, 540
for p in range(1, 8):
    PINS[("U2", str(p))] = (U2X0 + 40 * (p - 1), U2_BOT, "D")
for p in range(8, 15):
    PINS[("U2", str(p))] = (U2X0 + 40 * (14 - p), U2_TOP, "U")
BOXES.append((U2X0 - 20, U2_TOP, U2X0 + 6 * 40 + 20, U2_BOT))

# JP3 (ATIVO)
PINS[("JP3", "1")] = (440, 590, "D")
PINS[("JP3", "2")] = (480, 590, "D")
BOXES.append((415, 545, 505, 590))

# R1 em pé
PINS[("R1", "1")] = (1120, 500, "U")
PINS[("R1", "2")] = (1120, 600, "D")
BOXES.append((1108, 500, 1132, 600))

# JP1 / JP2: pino 1 em cima = GND, pino 3 embaixo = +5V
JP_Y = {"JP2": 440, "JP1": 960}
for ref, y0 in JP_Y.items():
    for k in range(3):
        PINS[(ref, str(k + 1))] = (380, y0 + 40 * k, "R")
    BOXES.append((340, y0 - 22, 380, y0 + 102))

# J2 (EXP), só rótulos
J2X = lambda k: 360 + 40 * k
for k in range(8):
    PINS[("J2", str(k + 1))] = (J2X(k), 330, None)
BOXES.append((335, 290, 665, 380))

# barramentos de alimentação (desenhados, não roteados) e capacitores entre eles
R5_X, RG_X, R5_Y, RG_Y = 250, 290, 170, 230
RAIL_END_X, RAIL_END_Y = 1370, 1200
RAILS = {"+5V": [((R5_X, RAIL_END_Y), (R5_X, R5_Y)), ((R5_X, R5_Y), (RAIL_END_X, R5_Y))],
         "GND": [((RG_X, RAIL_END_Y), (RG_X, RG_Y)), ((RG_X, RG_Y), (RAIL_END_X, RG_Y))]}
CAPS = [("C3", 1150, "10 µF", True), ("C1", 1210, "100 nF", False), ("C2", 1270, "100 nF", False)]
for ref, x, _v, _pol in CAPS:
    PINS[(ref, "1")] = (x, R5_Y, None)
    PINS[(ref, "2")] = (x, RG_Y, None)
    BOXES.append((x - 12, R5_Y + 1, x + 12, RG_Y - 1))
NC_LABELS = {"a18": "NC", "b1": "+3V", "b16": "-5V", "b18": "NC"}

# ---------------------------------------------------------------------------
# traçados fixos dos barramentos
# ---------------------------------------------------------------------------
FIXED = {}
for i in range(8):                                   # A0-A7: retos
    x = PINS[("U1", EP_A[i])][0]
    FIXED["A%d" % i] = [(x, J1_A - STUB), (x, U1_BOT + STUB)]
for i, lane in zip(range(3), (1080, 1060, 1040)):    # D0-D2: pinos 11-13, embaixo do U1
    xa, xu = PINS[("J1", "a%d" % (i + 2))][0], PINS[("U1", EP_D[i])][0]
    FIXED["D%d" % i] = [(xa, J1_A - STUB), (xa, lane), (xu, lane), (xu, U1_BOT + STUB)]
for i in range(3, 8):                                # D3-D7: contornam o U1 pela direita
    k = i - 3
    xa, xu = PINS[("J1", "a%d" % (i + 2))][0], PINS[("U1", EP_D[i])][0]
    yb, xr, yt = 920 + 20 * k, 1270 + 20 * k, 720 - 20 * k
    FIXED["D%d" % i] = [(xa, J1_A - STUB), (xa, yb), (xr, yb), (xr, yt), (xu, yt), (xu, U1_TOP - STUB)]
# A8-A13: descem do J1, contornam pela esquerda e sobem (A12 entra por baixo no pino 2)
LEFT = {"A13": (1260, 210, 720), "A12": (1280, 190, 920), "A11": (1300, 170, 660),
        "A10": (1320, 150, 640), "A9": (1340, 130, 680), "A8": (1360, 110, 700)}
for name, (yb, xv, yt) in LEFT.items():
    i = int(name[1:])
    xa = PINS[("J1", "b%d" % (i + 2))][0]
    xu, yu, d = PINS[("U1", EP_A[i])]
    yu += STUB if d == "D" else -STUB
    FIXED[name] = [(xa, J1_BOT + STUB), (xa, yb), (xv, yb), (xv, yt), (xu, yt), (xu, yu)]

# ---------------------------------------------------------------------------
# roteador
# ---------------------------------------------------------------------------
GX0, GY0, GX1, GY1 = 100, 140, 1370, 1370


class Grid:
    def __init__(self):
        self.occ = {}       # nó -> {rede: set('H'/'V'/'E')}  (E = ponta, curva ou junção)
        self.blocked = set()

    def mark_seg(self, netn, a, b):
        o = "V" if a[0] == b[0] else "H"
        for p in seg_nodes(a, b):
            self.occ.setdefault(p, {}).setdefault(netn, set()).add(o)

    def mark_end(self, netn, p):
        self.occ.setdefault(p, {}).setdefault(netn, set()).add("E")


def seg_nodes(a, b):
    if a[0] == b[0]:
        return [(a[0], y) for y in range(min(a[1], b[1]), max(a[1], b[1]) + 1, G)]
    assert a[1] == b[1], (a, b)
    return [(x, a[1]) for x in range(min(a[0], b[0]), max(a[0], b[0]) + 1, G)]


grid = Grid()
for (x0, y0, x1, y1) in BOXES:
    for x in range((x0 // G) * G - G, x1 + 2 * G, G):
        for y in range((y0 // G) * G - G, y1 + 2 * G, G):
            if x0 - 10 <= x <= x1 + 10 and y0 - 10 <= y <= y1 + 10:
                grid.blocked.add((x, y))
for x in range(740, 1200, G):            # nome do J1, embaixo da caixa
    for y in range(1230, 1291, G):
        grid.blocked.add((x, y))
for x in (1250, 1260):                   # vão estreito entre o U1 e a volta do D3
    for y in range(700, 921, G):
        grid.blocked.add((x, y))

WIRES = {n: [] for n in NETS}
TERM = {}


def pin_terminal(key):
    x, y, d = PINS[key]
    if d is None:
        return (x, y)
    dx, dy = DIRV[d]
    return (x + dx * STUB, y + dy * STUB)


def commit(netn, pts):
    for a, b in zip(pts, pts[1:]):
        grid.mark_seg(netn, a, b)
    for p in pts:
        grid.mark_end(netn, p)
    WIRES[netn].append(pts)


for n in NETS:
    for key in NETS[n][1]:
        if key in LABEL_ONLY or PINS[key][2] is None:
            TERM[key] = pin_terminal(key)
            continue
        x, y, d = PINS[key]
        t = pin_terminal(key)
        TERM[key] = t
        poly = STUBS.get(key, [(x, y)]) + [t]
        WIRES[n].append(poly)
        grid.mark_seg(n, poly[-2], t)
        grid.mark_end(n, t)
        grid.blocked.discard(t)
for key in NOT_CONNECTED + sorted(k for k in LABEL_ONLY if k[0] == "J1"):
    if PINS[key][2] is not None:
        grid.blocked.add(pin_terminal(key))
for n, segs in RAILS.items():
    for a, b in segs:
        grid.mark_seg(n, a, b)
        WIRES[n].append([a, b])
    grid.mark_end(n, segs[0][1])
for n, pts in FIXED.items():
    commit(n, pts)

ALL_TERMS = {t for k, t in TERM.items() if k not in LABEL_ONLY}
STEP, BEND, CROSS, NEAR, INLINE = 1.0, 8.0, 7.0, 6.0, 40.0
DIRS = [(0, -G), (0, G), (-G, 0), (G, 0)]


def others(p, netn):
    return {k: v for k, v in grid.occ.get(p, {}).items() if k != netn}


def route(netn, src, targets):
    """A* de src até qualquer nó de targets; devolve a lista de nós."""
    tset = set(targets)

    def h(p):
        return min(abs(p[0] - t[0]) + abs(p[1] - t[1]) for t in tset) / G

    best = {(src, None): 0.0}
    prev = {}
    pq = [(h(src), 0.0, src, None)]
    while pq:
        _f, g, p, d = heapq.heappop(pq)
        if best.get((p, d), 1e18) < g - 1e-9:
            continue
        if p in tset and p != src:
            path = [p]
            s = (p, d)
            while s in prev:
                s = prev[s]
                path.append(s[0])
            return path[::-1]
        oth = others(p, netn) if p != src else {}
        for nd in DIRS:
            if d is not None and nd == (-d[0], -d[1]):
                continue
            if oth and nd != d:
                continue                       # não vira em cima de fio alheio
            q = (p[0] + nd[0], p[1] + nd[1])
            if not (GX0 <= q[0] <= GX1 and GY0 <= q[1] <= GY1) or q in grid.blocked:
                continue
            if q in ALL_TERMS and q not in tset:
                continue
            if q not in tset and netn in grid.occ.get(q, {}):
                continue                       # não anda sobre o próprio fio fora dos alvos
            o = "V" if nd[0] == 0 else "H"
            cost = STEP + (BEND if d is not None and nd != d else 0)
            qo = others(q, netn)
            if qo:
                if q in tset:
                    continue                   # não emenda em cima de um cruzamento
                if not all(v == {"H" if o == "V" else "V"} for v in qo.values()):
                    continue
                cost += CROSS * len(qo)
            for side in ((nd[1], nd[0]), (-nd[1], -nd[0])):
                r = (q[0] + side[0], q[1] + side[1])
                if any(o in v for v in others(r, netn).values()):
                    cost += NEAR
            # fio alheio continuando na mesma linha logo adiante parece emenda
            for k in (1, 2):
                r = (q[0] + nd[0] * k, q[1] + nd[1] * k)
                v = others(r, netn)
                if any(o in s or ("E" in s and o in s) for s in v.values()):
                    cost += INLINE
            ng = g + cost
            s = (q, nd)
            if ng < best.get(s, 1e18) - 1e-9:
                best[s] = ng
                prev[s] = (p, d)
                heapq.heappush(pq, (ng + h(q), ng, q, nd))
    return None


def simplify(path):
    out = [path[0]]
    for i in range(1, len(path) - 1):
        a, b, c = out[-1], path[i], path[i + 1]
        if (a[0] == b[0] == c[0]) or (a[1] == b[1] == c[1]):
            continue
        out.append(b)
    out.append(path[-1])
    return out


ORDER = ["OE_N", "R_W", "CE_N", "CART_SEL", "EP_PIN1", "EP_PIN27", "GND", "+5V"]
for n in ORDER:
    pins = [k for k in NETS[n][1] if PINS[k][2] is not None and k not in LABEL_ONLY]
    if n in RAILS:
        done = {q for a, b in RAILS[n] for q in seg_nodes(a, b)}
        todo = pins
    else:
        done = {TERM[pins[0]]}
        todo = pins[1:]
    for key in todo:
        path = route(n, TERM[key], sorted(done))
        if path is None:
            raise SystemExit("não consegui rotear %s até %s" % (n, key))
        pts = simplify(path)
        commit(n, pts)
        for a, b in zip(pts, pts[1:]):
            done.update(seg_nodes(a, b))


# ---------------------------------------------------------------------------
# conferência pelo desenho
# ---------------------------------------------------------------------------
def verify():
    parent = {}

    def find(a):
        parent.setdefault(a, a)
        while parent[a] != a:
            parent[a] = parent[parent[a]]
            a = parent[a]
        return a

    for n, polys in WIRES.items():
        for poly in polys:
            for a, b in zip(poly, poly[1:]):
                for q in seg_nodes(a, b):
                    parent[find((n, q))] = find((n, a))
                parent[find((n, b))] = find((n, a))
    for p, v in grid.occ.items():
        if len(v) > 1:
            kinds = sorted(tuple(sorted(s)) for s in v.values())
            if kinds != [("H",), ("V",)]:
                raise SystemExit("nó %s compartilhado de forma inválida: %s" % (p, v))
    for n, (_c, pins) in NETS.items():
        drawn = [k for k in pins if k not in LABEL_ONLY]
        roots = {find((n, TERM[k])) for k in drawn}
        if len(roots) > 1:
            raise SystemExit("rede %s desenhada em %d pedaços" % (n, len(roots)))
    n_cross = sum(1 for v in grid.occ.values() if len(v) == 2)
    print("desenho: redes contínuas, %d cruzamentos, todos em ângulo reto" % n_cross)


# ---------------------------------------------------------------------------
# SVG
# ---------------------------------------------------------------------------
svg = []
add = svg.append


def text(x, y, s, size=12, fill=INK, anchor="start", bold=False, family=FONT, rot=None):
    tr = ' transform="rotate(%d %s %s)"' % (rot, x, y) if rot else ""
    add('<text x="%s" y="%s" font-family="%s" font-size="%s" fill="%s" text-anchor="%s" font-weight="%s"%s>%s</text>'
        % (x, y, family, size, fill, anchor, "bold" if bold else "normal", tr, html.escape(s, quote=False)))


def rect(x, y, w, h, fill="#ffffff", stroke=BOX, sw=1.6, rx=6, dash=None):
    add('<rect x="%s" y="%s" width="%s" height="%s" rx="%s" fill="%s" stroke="%s" stroke-width="%s"%s/>'
        % (x, y, w, h, rx, fill, stroke, sw, ' stroke-dasharray="%s"' % dash if dash else ""))


def path(d, color, sw=2.4):
    add('<path d="%s" fill="none" stroke="%s" stroke-width="%s" stroke-linecap="round" stroke-linejoin="round"/>'
        % (d, color, sw))


def dot(x, y, color, r=4.2):
    add('<circle cx="%s" cy="%s" r="%s" fill="%s"/>' % (x, y, r, color))


def pin_square(x, y, stroke=BOX):
    add('<rect x="%s" y="%s" width="9" height="9" rx="1.5" fill="#ffffff" stroke="%s" stroke-width="1.6"/>'
        % (x - 4.5, y - 4.5, stroke))


def cross_mark(x, y, s=4):
    add('<path d="M%s,%s l%s,%s M%s,%s l-%s,%s" stroke="%s" stroke-width="1.6"/>'
        % (x - s, y - s, 2 * s, 2 * s, x + s, y - s, 2 * s, 2 * s, NCRED))


def label_of(key):
    n = net_of(key)
    return {"+5V": "VCC", "GND": "GND"}.get(n, short(n) if n else "")


HOP = 5
DRAW_ORDER = ["+5V", "GND"] + [n for n in NETS if n not in ("+5V", "GND")]


def draw_wires():
    cross = {}
    for p, v in grid.occ.items():
        if len(v) == 2:
            for n, s in v.items():
                if s == {"H"}:
                    cross.setdefault(n, set()).add(p)
    for n in DRAW_ORDER:
        color = NETS[n][0]
        for poly in WIRES[n]:
            rail = n in RAILS and poly in [list(s) for s in RAILS[n]]
            d = "M%s,%s" % poly[0]
            for a, b in zip(poly, poly[1:]):
                if a[1] == b[1] and a[0] != b[0]:
                    sgn = 1 if b[0] > a[0] else -1
                    hops = sorted((p for p in cross.get(n, ()) if p[1] == a[1]
                                   and min(a[0], b[0]) < p[0] < max(a[0], b[0])), key=lambda p: sgn * p[0])
                    for p in hops:
                        d += " L%s,%s A%s,%s 0 0 %d %s,%s" % (p[0] - sgn * HOP, p[1], HOP, HOP,
                                                              1 if sgn > 0 else 0, p[0] + sgn * HOP, p[1])
                d += " L%s,%s" % b
            path(d, color, 4.5 if rail else 2.4)
    for n in DRAW_ORDER:                     # junções: 3 ou mais ramos da mesma rede
        deg = {}
        segs = [(a, b) for poly in WIRES[n] for a, b in zip(poly, poly[1:])]
        pts = {p for s in segs for p in s}
        for a, b in segs:
            for p in pts:
                if p == a or p == b:
                    q = b if p == a else a
                    deg.setdefault(p, set()).add(((q[0] > p[0]) - (q[0] < p[0]), (q[1] > p[1]) - (q[1] < p[1])))
                elif a[0] == b[0] == p[0] and min(a[1], b[1]) < p[1] < max(a[1], b[1]):
                    deg.setdefault(p, set()).update({(0, 1), (0, -1)})
                elif a[1] == b[1] == p[1] and min(a[0], b[0]) < p[0] < max(a[0], b[0]):
                    deg.setdefault(p, set()).update({(1, 0), (-1, 0)})
        for p, s in deg.items():
            if len(s) >= 3:
                dot(p[0], p[1], NETS[n][0], 5.4 if n in RAILS else 4.2)


def draw_parts():
    # J1 (a caixa é desenhada antes dos fios, que passam por dentro dela)
    for n in range(1, 19):
        x = J1X(18 - n)
        ka, kb = ("J1", "a%d" % n), ("J1", "b%d" % n)
        pin_square(x, J1_A)
        pin_square(x, J1_B)
        na, nb = net_of(ka), net_of(kb)
        text(x, J1_A + 17, short(na) if na else NC_LABELS.get("a%d" % n, "NC"), 10,
             color_of(ka) if na else "#9a9a9a", "middle", True)
        text(x, J1_A + 32, str(n), 9, GRAY, "middle")
        text(x, J1_B - 9, short(nb) if nb else NC_LABELS.get("b%d" % n, "NC"), 10,
             color_of(kb) if nb else "#9a9a9a", "middle", True)
        if not na:
            cross_mark(x, J1_A)
        if not nb:
            cross_mark(x, J1_B)
        if ka in LABEL_ONLY:
            text(x, J1_A - 8, "J2", 8.5, C_EXP, "middle", True)
    text(366, J1_A + 4, "a", 13, INK, "end", True)
    text(366, J1_B + 4, "b", 13, INK, "end", True)
    text(1114, J1_A + 4, "a", 13, INK, "start", True)
    text(1114, J1_B + 4, "b", 13, INK, "start", True)
    text(750, 1250, "J1  -  soquete fêmea de borda 2x18 (encaixa no CN1)", 15, INK, "start", True)
    text(750, 1268, "fileira a = contatos de cima do CN1  ·  fileira b = de baixo", 11.5, GRAY, "start")
    text(750, 1284, "pino 1 à DIREITA nesta vista  ·  J2 = contato que só vai ao J2", 11.5, GRAY, "start")

    # U1
    x0, x1 = U1X0 - 20, U1X0 + 13 * 40 + 20
    rect(x0, U1_TOP, x1 - x0, U1_BOT - U1_TOP)
    ym = (U1_TOP + U1_BOT) / 2
    add('<path d="M%s,%s A12,12 0 0 1 %s,%s" fill="#ececec" stroke="%s" stroke-width="1.6"/>'
        % (x0, ym - 12, x0, ym + 12, BOX))
    text((x0 + x1) / 2, ym + 2, "U1  27C128", 17, INK, "middle", True)
    text((x0 + x1) / 2, ym + 19, "EPROM no soquete DIP-28 (600 mil)", 11.5, GRAY, "middle")
    for p in range(1, 29):
        key = ("U1", str(p))
        x, y, d = PINS[key]
        pin_square(x, y)
        top = d == "U"
        text(x, y + (15 if top else -8), str(p), 9.5, GRAY, "middle")
        text(x, y + (28 if top else -20), label_of(key), 10, color_of(key), "middle", True)

    # U2
    x0, x1 = U2X0 - 20, U2X0 + 6 * 40 + 20
    rect(x0, U2_TOP, x1 - x0, U2_BOT - U2_TOP)
    ym = (U2_TOP + U2_BOT) / 2
    add('<path d="M%s,%s A10,10 0 0 1 %s,%s" fill="#ececec" stroke="%s" stroke-width="1.6"/>'
        % (x0, ym - 10, x0, ym + 10, BOX))
    text((x0 + x1) / 2, ym + 2, "U2  74HCT00", 15, INK, "middle", True)
    text((x0 + x1) / 2, ym + 16, "/OE = NÃO(R/W)", 10.5, GRAY, "middle")
    u2n = {"1": "1A", "2": "1B", "3": "1Y", "4": "2A", "5": "2B", "6": "2Y", "7": "GND", "8": "3Y",
           "9": "3A", "10": "3B", "11": "4Y", "12": "4A", "13": "4B", "14": "VCC"}
    for p in range(1, 15):
        key = ("U2", str(p))
        x, y, d = PINS[key]
        pin_square(x, y)
        top = d == "U"
        nn = net_of(key)
        text(x, y + (15 if top else -8), str(p), 9.5, GRAY, "middle")
        text(x, y + (27 if top else -19), u2n[str(p)], 9.5, color_of(key) if nn else "#9a9a9a", "middle", True)
        if nn is None:
            cross_mark(x, y)

    # JP3 / R1
    rect(415, 545, 90, 45)
    text(460, 562, "JP3  ATIVO", 11.5, INK, "middle", True)
    text(460, 577, "jumper fechado", 9.5, GRAY, "middle")
    add('<rect x="1110" y="518" width="20" height="64" rx="6" fill="#f3e2b8" stroke="%s" stroke-width="1.6"/>' % BOX)
    path("M1120,500 L1120,518", BOX, 1.6)
    path("M1120,582 L1120,600", BOX, 1.6)
    for k in "12":
        for ref in ("JP3", "R1"):
            pin_square(*PINS[(ref, k)][:2])
    text(1140, 546, "R1", 13, INK, "start", True)
    text(1140, 562, "10 kΩ", 11, GRAY, "start")
    text(1140, 577, "pull-up do /CE", 10, GRAY, "start")

    # JP1 / JP2
    for ref, sub in (("JP2", "pino 27 do U1"), ("JP1", "pino 1 do U1")):
        y0 = JP_Y[ref]
        rect(340, y0 - 22, 40, 124, rx=4)
        text(360, y0 - 30, ref, 13, INK, "middle", True)
        text(332, y0 + 40, sub, 10, GRAY, "middle", rot=-90)
        for k in range(3):
            x, y, _ = PINS[(ref, str(k + 1))]
            pin_square(x, y)
            text(366, y + 4, str(k + 1), 9.5, GRAY, "middle")

    # J2: só rótulos
    rect(335, 300, 330, 32, rx=4)
    text(500, 292, "J2  EXP (opcional) - fios não desenhados", 12, INK, "middle", True)
    for k in range(8):
        key = ("J2", str(k + 1))
        x, y, _ = PINS[key]
        pin_square(x, y)
        text(x, y - 13, str(k + 1), 9, GRAY, "middle")
        n = net_of(key)
        src = [p for p in NETS[n][1] if p[0] == "J1"]
        text(x, y + 20, "+5V" if n == "+5V" else ("GND" if n == "GND" else short(n)), 10, color_of(key),
             "middle", True)
        if src and n not in ("+5V", "GND"):
            text(x, y + 33, src[0][1], 9.5, GRAY, "middle")

    # capacitores entre os barramentos
    for ref, x, val, pol in CAPS:
        ym = (R5_Y + RG_Y) / 2
        path("M%s,%s L%s,%s" % (x, R5_Y, x, ym - 5), BOX, 2)
        path("M%s,%s L%s,%s" % (x, ym + 5, x, RG_Y), BOX, 2)
        path("M%s,%s L%s,%s" % (x - 11, ym - 5, x + 11, ym - 5), BOX, 2.6)
        if pol:
            add('<path d="M%s,%s Q%s,%s %s,%s" fill="none" stroke="%s" stroke-width="2.6"/>'
                % (x - 11, ym + 9, x, ym + 2, x + 11, ym + 9, BOX))
            text(x - 15, ym - 8, "+", 12, RED, "middle", True)
        else:
            path("M%s,%s L%s,%s" % (x - 11, ym + 5, x + 11, ym + 5), BOX, 2.6)
        text(x + 14, ym - 2, ref, 11, INK, "start", True)
        text(x + 14, ym + 11, val, 9.5, GRAY, "start")
        dot(x, R5_Y, RED, 5.4)
        dot(x, RG_Y, BLACK, 5.4)
    text(R5_X + 12, R5_Y - 8, "+5V", 13, RED, "start", True)
    text(RG_X + 12, RG_Y - 8, "GND", 13, BLACK, "start", True)
    text(R5_X, RAIL_END_Y + 22, "+5V", 12, RED, "middle", True)
    text(RG_X, RAIL_END_Y + 22, "GND", 12, BLACK, "middle", True)
    text(1320, 154, "C1 junto do U1, C2 junto do U2", 10.5, GRAY, "end")


def draw_solder_side(px, py):
    rect(px, py, 375, 1150, fill="#ffffff", stroke=GRAY, sw=1.2, rx=8)
    text(px + 18, py + 30, "VISTO PELO LADO DA SOLDA", 14, INK, "start", True)
    text(px + 18, py + 50, "placa virada como página de livro: esquerda", 11.5, WARN)
    text(px + 18, py + 66, "e direita trocam de lugar, cima e baixo não", 11.5, WARN)

    def pad(x, y, used=True):
        add('<circle cx="%s" cy="%s" r="5" fill="%s" stroke="%s" stroke-width="1.2"/>'
            % (x, y, "#e9c46a" if used else "#dddddd", BOX))
        if not used:
            cross_mark(x, y, 3.5)

    def dip(ref, title, npins, y0, sx, h):
        half = npins // 2
        text(px + 187, y0 - 14, title, 12.5, INK, "middle", True)
        bx0, bx1 = px + 187 - half / 2 * sx, px + 187 + half / 2 * sx
        rect(bx0, y0, bx1 - bx0, h, fill="#fbfbfb", rx=4)
        add('<path d="M%s,%s A10,10 0 0 0 %s,%s" fill="#ececec" stroke="%s" stroke-width="1.4"/>'
            % (bx1, y0 + h / 2 - 10, bx1, y0 + h / 2 + 10, BOX))
        for p in range(1, npins + 1):
            if p <= half:
                x, y, top = bx1 - sx / 2 - (p - 1) * sx, y0 + h, False
            else:
                x, y, top = bx0 + sx / 2 + (npins - p) * sx, y0, True
            key = (ref, str(p))
            nn = net_of(key)
            pad(x, y, nn is not None)
            text(x, y + (18 if top else -10), str(p), 8.5, GRAY, "middle")
            text(x, y + (30 if top else -22), label_of(key) if nn else "solto", 8.5,
                 color_of(key) if nn else "#9a9a9a", "middle", True)

    dip("U1", "U1  27C128 (chanfro à direita)", 28, py + 110, 25, 100)
    dip("U2", "U2  74HCT00", 14, py + 270, 26, 90)

    y0 = py + 430
    text(px + 187, y0 - 14, "J1  (pino 1 à ESQUERDA)", 12.5, INK, "middle", True)
    sxj = 19
    bx0 = px + 187 - 9 * sxj
    rect(bx0 - 6, y0, 18 * sxj + 12, 70, fill="#fbfaf3", rx=4)
    for n in range(1, 19):
        x = bx0 + sxj / 2 + (n - 1) * sxj
        for row, yy in (("a", y0 + 18), ("b", y0 + 52)):
            pad(x, yy, net_of(("J1", "%s%d" % (row, n))) is not None)
        if n in (1, 5, 9, 13, 18):
            text(x, y0 + 86, str(n), 9, GRAY, "middle")
    text(bx0 - 12, y0 + 22, "a", 12, INK, "end", True)
    text(bx0 - 12, y0 + 56, "b", 12, INK, "end", True)
    ty = y0 + 122
    text(px + 18, ty, "pino", 10.5, GRAY, "start", True)
    text(px + 70, ty, "fileira a (de cima)", 10.5, GRAY, "start", True)
    text(px + 205, ty, "fileira b (de baixo)", 10.5, GRAY, "start", True)
    for n in range(1, 19):
        yy = ty + 18 + (n - 1) * 16
        text(px + 40, yy, str(n), 10.5, GRAY, "end", family=MONO)
        for row, cx in (("a", px + 70), ("b", px + 205)):
            key = ("J1", "%s%d" % (row, n))
            nn = net_of(key)
            if nn:
                s = short(nn) + ("  (só J2)" if key in LABEL_ONLY else "")
                text(cx, yy, s, 10.5, color_of(key), "start", True)
            else:
                text(cx, yy, {"a18": "NC", "b1": "+3 V bateria: NÃO", "b16": "-5 V: NÃO LIGAR",
                              "b18": "NC"}["%s%d" % (row, n)], 10.5, NCRED, "start")
    yy = ty + 18 + 18 * 16 + 14
    for s in ("Os contatos a e b do mesmo número ficam",
              "frente a frente; o soquete tem as fileiras",
              "a 5,08 mm (um furo vago entre elas)."):
        text(px + 18, yy, s, 11, GRAY)
        yy += 16


def draw_bottom(py):
    rect(40, py, 1720, H - py - 30, fill="#ffffff", stroke=GRAY, sw=1.2, rx=8)
    x = 62
    text(x, py + 30, "COMO LER", 14, INK, "start", True)
    rows = [(RED, 4.5, "+5V - barramento de alimentação"), (BLACK, 4.5, "GND - barramento de terra"),
            (C_ADDR, 2.4, "endereços A0-A13 (fileira b do J1)"), (C_DATA, 2.4, "dados D0-D7 (fileira a do J1)"),
            (C_CTRL, 2.4, "controle: R/W, /OE, Y1, /CE"), (C_JMP, 2.4, "pinos 1 e 27 da EPROM (jumpers)")]
    yy = py + 58
    for c, sw, s in rows:
        path("M%s,%s L%s,%s" % (x, yy, x + 42, yy), c, sw)
        text(x + 54, yy + 5, s, 12.5)
        yy += 25
    text(x + 21, yy + 5, "J2", 11, C_EXP, "middle", True)
    text(x + 54, yy + 5, "sinal que só vai ao J2 (opcional)", 12.5)
    yy += 25
    dot(x + 21, yy, INK)
    text(x + 54, yy + 5, "bolinha = fios ligados", 12.5)
    yy += 25
    path("M%s,%s L%s,%s" % (x + 21, yy - 11, x + 21, yy + 11), INK)
    path("M%s,%s L%s,%s A5,5 0 0 1 %s,%s L%s,%s" % (x, yy, x + 16, yy, x + 26, yy, x + 42, yy), C_CTRL)
    text(x + 54, yy + 5, "arco = cruzamento sem ligação", 12.5)
    yy += 25
    cross_mark(x + 21, yy, 4.5)
    text(x + 54, yy + 5, "X = pino que fica sem ligação", 12.5)

    lx = 470
    text(lx, py + 30, "LISTA DE LIGAÇÕES (marque cada fio ao soldar)", 14, INK, "start", True)
    items = []
    for i in range(14):
        items.append((C_ADDR, "A%d" % i, "J1-b%d  →  U1-%s" % (i + 2, EP_A[i])))
    for i in range(8):
        items.append((C_DATA, "D%d" % i, "J1-a%d  →  U1-%s" % (i + 2, EP_D[i])))
    items += [
        (C_CTRL, "R/W", "J1-a12 → U2-1 → U2-2"),
        (C_CTRL, "/OE", "U2-3  →  U1-22"),
        (C_CTRL, "Y1", "J1-a14  →  JP3-1"),
        (C_CTRL, "/CE", "JP3-2 → U1-20 → R1"),
        (C_JMP, "VPP", "U1-1  →  JP1-2 (centro)"),
        (C_JMP, "/PGM", "U1-27  →  JP2-2 (centro)"),
        (RED, "+5V", "J1-a15, U1-28, U2-14, JP1-3, JP2-3, R1, C1, C2, C3 (+)"),
        (BLACK, "GND", "J1-a17, J1-b17, U1-14, U2-7, JP1-1, JP2-1, C1, C2, C3 (-)"),
        (BLACK, "GND", "entradas livres do U2: pinos 4, 5, 9, 10, 12, 13"),
        (C_EXP, "J2", "1 +5V, 2 a1, 3 a13, 4 a12, 5 a11, 6 a10, 7 a16, 8 GND"),
    ]
    per_col, col_w, row_h = 13, 300, 19.5
    for i, (c, n, s) in enumerate(items):
        if i < 2 * per_col:
            cx, cy = lx + (i // per_col) * col_w, py + 56 + (i % per_col) * row_h
        else:
            cx, cy = lx, py + 64 + (per_col + i - 2 * per_col) * row_h
        add('<rect x="%s" y="%s" width="11" height="11" rx="2" fill="none" stroke="%s" stroke-width="1.3"/>'
            % (cx, cy - 10, GRAY))
        text(cx + 18, cy, n, 12, c, "start", True)
        text(cx + 62, cy, s, 12)

    ox = 1090
    text(ox, py + 30, "OBSERVAÇÕES", 14, INK, "start", True)
    notes = [
        ("Desenho visto pelo lado dos COMPONENTES (a PCI vista de", INK),
        ("frente). Para soldar, use as pinagens espelhadas à direita.", INK),
        ("A disposição é só sugestão; o que vale são as ligações.", INK),
        ("", INK),
        ("J1: deixe um furo vago entre as duas fileiras do soquete.", INK),
        ("NÃO ligue b1 (+3 V da bateria da RAM) nem b16 (-5 V).", NCRED),
        ("", INK),
        ("Só com 27C128: JP1 e JP2 podem virar dois fios, dos pinos", INK),
        ("1 e 27 da EPROM ao +5V. Outras memórias: ver README.", INK),
        ("JP3 aberto = o VET ignora o cartucho e abre o titulador.", INK),
        ("", INK),
        ("Antes de pôr os CIs: confira cada fio com o multímetro e", WARN),
        ("que não há curto entre +5V e GND. Com o VET ligado e sem", WARN),
        ("os CIs, meça 5 V no pino 28 do U1 e no 14 do U2.", WARN),
        ("", INK),
        ("Montagem: placa em pé atrás do VET, componentes voltados", INK),
        ("para o aparelho (pino 1 à esquerda, olhando por trás).", INK),
    ]
    for i, (s, c) in enumerate(notes):
        text(ox, py + 56 + i * 17.5, s, 11.8, c)


def main():
    check_against_kicad()
    verify()
    add('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d">' % (W, H, W, H))
    add("<!-- SPDX-License-Identifier: CERN-OHL-S-2.0 -->")
    add("<!-- Copyright (C) 2026 Leonardo Roman da Rosa -->")
    add("<!-- Gerado por hardware/cartucho/gen/gen_fiacao.py; não editar à mão. -->")
    rect(0, 0, W, H, fill=BG, stroke=BG, sw=0, rx=0)
    text(40, 52, "VET 3000 - CARTUCHO DE ROM EM PLACA PROTÓTIPO", 27, INK, "start", True)
    text(40, 80, "Ligações ponto a ponto  ·  27C128 + 74HCT00  ·  mesmo circuito do esquemático KiCad", 16, GRAY)
    text(1740, 52, "diagrama de fiação", 15, GRAY, "end")
    text(1740, 74, "gerado por hardware/cartucho/gen/gen_fiacao.py", 12, GRAY, "end")
    text(1740, 94, "desenho sob CERN-OHL-S-2.0", 12, GRAY, "end")
    text(R5_X, 128, "vista pelo lado dos componentes", 13, WARN, "start", True)
    rect(375, J1_A, 730, J1_BOT - J1_A, fill="#fbfaf3")
    draw_wires()
    draw_parts()
    draw_solder_side(1390, 130)
    draw_bottom(1400)
    add("</svg>")
    open(OUT, "w", encoding="utf-8", newline="\n").write("\n".join(svg) + "\n")
    print("svg:", OUT)


main()
