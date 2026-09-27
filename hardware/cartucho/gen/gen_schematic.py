#!/usr/bin/env python3
# Copyright (C) 2026 Leonardo Roman da Rosa
# SPDX-License-Identifier: GPL-3.0-or-later
# Software livre sob a GNU GPL versão 3 ou (a seu critério) posterior; veja LICENSE.
#
"""Gera o esquemático (KiCad 10) do cartucho de ROM do VET 3000.

    python gen_schematic.py [pasta_das_bibliotecas_de_simbolos_do_KiCad]

Os símbolos vêm das bibliotecas padrão do KiCad e são embutidos no arquivo. Cada pino é
ligado por um pequeno fio a um rótulo de rede (ou a um símbolo +5V/GND); por isso o
circuito é descrito aqui como uma tabela de ligações.
"""
import math
import os
import re
import sys
import uuid

KLIB = sys.argv[1] if len(sys.argv) > 1 else r"C:/Program Files/KiCad/10.0/share/kicad/symbols"
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "vet3000_cartucho.kicad_sch")
PROJECT = "vet3000_cartucho"
ROOT_UUID = "5e7a3000-0c4a-4e0c-9a11-000000003000"

# uuids estáveis (derivados de nomes) para o arquivo não mudar a cada geração
NS = uuid.UUID("7e7a3000-1988-4d6a-8a09-c0ffee003000")


def uid(*parts):
    return str(uuid.uuid5(NS, "/".join(str(p) for p in parts)))


# ---------------------------------------------------------------------------
# leitura das bibliotecas
# ---------------------------------------------------------------------------
_lib_cache = {}


def lib_text(lib):
    if lib not in _lib_cache:
        _lib_cache[lib] = open(os.path.join(KLIB, lib + ".kicad_sym"), encoding="utf-8").read()
    return _lib_cache[lib]


def balanced(s, i):
    d = 0
    j = i
    in_str = False
    while True:
        c = s[j]
        if in_str:
            if c == "\\":
                j += 1
            elif c == '"':
                in_str = False
        elif c == '"':
            in_str = True
        elif c == "(":
            d += 1
        elif c == ")":
            d -= 1
            if d == 0:
                return j + 1
        j += 1


def raw_symbol(lib, name):
    s = lib_text(lib)
    i = s.index('(symbol "%s"' % name)
    return s[i:balanced(s, i)]


def props_of(block):
    """{chave: bloco da propriedade} das propriedades de primeiro nível."""
    out = {}
    for m in re.finditer(r'\(property "([^"]+)"', block):
        i = m.start()
        out[m.group(1)] = block[i:balanced(block, i)]
    return out


def flatten(lib, name):
    """Símbolo pronto para lib_symbols: 'lib:name', herança resolvida."""
    blk = raw_symbol(lib, name)
    m = re.match(r'\(symbol "[^"]+"\s*\(extends "([^"]+)"\)', blk)
    if m:
        parent = m.group(1)
        pblk = raw_symbol(lib, parent)
        child_props = props_of(blk)
        for key, pb in props_of(pblk).items():
            if key in child_props:
                pblk = pblk.replace(pb, child_props[key], 1)
        pblk = pblk.replace('(symbol "%s_' % parent, '(symbol "%s_' % name)
        blk = pblk.replace('(symbol "%s"' % parent, '(symbol "%s"' % name, 1)
    return blk.replace('(symbol "%s"' % name, '(symbol "%s:%s"' % (lib, name), 1)


def pins_of(lib, name):
    """Lista de pinos (unidade, nome, número, x, y, ângulo) do símbolo achatado."""
    blk = flatten(lib, name)
    pins = []
    for m in re.finditer(r'\(symbol "%s_(\d+)_(\d+)"' % re.escape(name), blk):
        unit, style = int(m.group(1)), int(m.group(2))
        if style == 2:
            continue                              # forma De Morgan
        sub = blk[m.start():balanced(blk, m.start())]
        for p in re.finditer(r'\(pin \w+ \w+\s*\(at ([-\d.]+) ([-\d.]+) ([-\d.]+)\)', sub):
            pb = sub[p.start():balanced(sub, p.start())]
            pname = re.search(r'\(name "([^"]*)"', pb).group(1)
            pnum = re.search(r'\(number "([^"]*)"', pb).group(1)
            pins.append((unit, pname, pnum, float(p.group(1)), float(p.group(2)), float(p.group(3))))
    return pins


# ---------------------------------------------------------------------------
# peças e ligações
# ---------------------------------------------------------------------------
FP_SOCKET = "vet3000:CardEdge_Socket_2x18_P2.54mm_Row5.08mm"

# (ref, lib, símbolo, valor, footprint, [(unidade, x, y)], {pino: rede ou None})
#   rede "+5V"/"GND" = símbolo de alimentação; None = sem conexão (X)
CN1 = {
    "a1": "IRQ", "a2": "D0", "a3": "D1", "a4": "D2", "a5": "D3", "a6": "D4", "a7": "D5",
    "a8": "D6", "a9": "D7", "a10": "ROM_E", "a11": "IO_SEL", "a12": "R_W", "a13": "HALT",
    "a14": "CART_SEL", "a15": "+5V", "a16": "DEC_EN", "a17": "GND", "a18": None,
    "b1": None, "b16": None, "b17": "GND", "b18": None,
}
for i in range(14):
    CN1["b%d" % (i + 2)] = "A%d" % i

EPROM = {"1": "EP_PIN1", "14": "GND", "20": "CE_N", "22": "OE_N", "27": "EP_PIN27", "28": "+5V"}
for i, p in enumerate(["10", "9", "8", "7", "6", "5", "4", "3", "25", "24", "21", "23", "2", "26"]):
    EPROM[p] = "A%d" % i
for i, p in enumerate(["11", "12", "13", "15", "16", "17", "18", "19"]):
    EPROM[p] = "D%d" % i

PARTS = [
    ("J1", "Connector_Generic", "Conn_02x18_Row_Letter_First", "CN1 VET 3000 (soquete de borda 2x18)",
     FP_SOCKET, [(1, 63.5, 101.6)], CN1),
    ("U1", "Memory_EPROM", "27C128", "27C128", "Package_DIP:DIP-28_W15.24mm_Socket",
     [(1, 152.4, 101.6)], EPROM),
    ("U2", "74xx", "74HCT00", "74HCT00", "Package_DIP:DIP-14_W7.62mm_Socket",
     [(1, 238.76, 55.88), (2, 238.76, 78.74), (3, 238.76, 101.6), (4, 238.76, 124.46), (5, 279.4, 78.74)],
     {"1": "R_W", "2": "R_W", "3": "OE_N", "4": "GND", "5": "GND", "6": None, "9": "GND", "10": "GND",
      "8": None, "12": "GND", "13": "GND", "11": None, "14": "+5V", "7": "GND"}),
    ("JP1", "Jumper", "Jumper_3_Open", "VPP/A15 (pino 1)",
     "Connector_PinHeader_2.54mm:PinHeader_1x03_P2.54mm_Vertical", [(1, 213.36, 152.4)],
     {"1": "GND", "2": "EP_PIN1", "3": "+5V"}),
    ("JP2", "Jumper", "Jumper_3_Open", "PGM/A14/WE (pino 27)",
     "Connector_PinHeader_2.54mm:PinHeader_1x03_P2.54mm_Vertical", [(1, 213.36, 172.72)],
     {"1": "GND", "2": "EP_PIN27", "3": "+5V"}),
    ("JP3", "Jumper", "Jumper_2_Open", "ATIVO",
     "Connector_PinHeader_2.54mm:PinHeader_1x02_P2.54mm_Vertical", [(1, 256.54, 152.4)],
     {"1": "CART_SEL", "2": "CE_N"}),
    ("R1", "Device", "R", "10k", "Resistor_THT:R_Axial_DIN0207_L6.3mm_D2.5mm_P7.62mm_Horizontal",
     [(1, 302.26, 152.4)], {"1": "+5V", "2": "CE_N"}),
    ("C1", "Device", "C", "100nF", "Capacitor_THT:C_Disc_D5.0mm_W2.5mm_P5.00mm",
     [(1, 256.54, 175.26)], {"1": "+5V", "2": "GND"}),
    ("C2", "Device", "C", "100nF", "Capacitor_THT:C_Disc_D5.0mm_W2.5mm_P5.00mm",
     [(1, 271.78, 175.26)], {"1": "+5V", "2": "GND"}),
    ("C3", "Device", "C_Polarized", "10uF", "Capacitor_THT:CP_Radial_D5.0mm_P2.00mm",
     [(1, 287.02, 175.26)], {"1": "+5V", "2": "GND"}),
    ("J2", "Connector_Generic", "Conn_01x08", "EXP", "Connector_PinHeader_2.54mm:PinHeader_1x08_P2.54mm_Vertical",
     [(1, 63.5, 162.56)],
     {"1": "+5V", "2": "IRQ", "3": "HALT", "4": "R_W", "5": "IO_SEL", "6": "ROM_E", "7": "DEC_EN", "8": "GND"}),
    ("H1", "Mechanical", "MountingHole", "M3", "MountingHole:MountingHole_3.2mm_M3", [(1, 101.6, 175.26)], {}),
    ("H2", "Mechanical", "MountingHole", "M3", "MountingHole:MountingHole_3.2mm_M3", [(1, 116.84, 175.26)], {}),
]
PWR_FLAGS = [("+5V", 294.64, 55.88), ("GND", 309.88, 55.88)]

# posição (em coordenadas da biblioteca) de campos que colidiriam com fios
FIELD_OVERRIDE = {
    "Jumper_3_Open": {"Reference": (-6.35, -2.54)},
    "27C128": {"Value": (6.35, -26.67)},
}
# fios mais longos até os símbolos de alimentação nos conectores (afasta dos rótulos vizinhos)
POWER_STUB = {"J1": 15.24, "J2": 12.7}

NOTES = [
    (38.1, 22.86, 2.0, "VET 3000 - cartucho de ROM para o conector traseiro CN1"),
    (38.1, 29.21, 1.27,
     "J1: soquete fêmea de borda 2x18 (passo 2,54 mm) que encaixa nos dedos do CN1.\\n"
     "Fileira a = contatos de CIMA do CN1 (face de componentes do VET); fileira b = de BAIXO.\\n"
     "Pino 1 à esquerda olhando o VET por trás. O cartucho fica em pé, componentes voltados para o VET.\\n"
     "Não ligar b1 (+3 V da bateria da RAM) nem b16 (-5 V)."),
    (177.8, 22.86, 1.27,
     "A ROM do VET 3000 procura \\\"OBJECT\\\" e \\\"FONT\\\" em $4000 e $6000.\\n"
     "CART_SEL (a14) = saída Y1 do 74LS139 do VET: ativa em $4000-$7FFF.\\n"
     "/OE = NÃO(R/W): a EPROM só dirige o barramento em leituras.\\n"
     "JP3 aberto = cartucho desligado (R1 mantém /CE em 1): o VET liga no titulador."),
    (177.8, 190.5, 1.27,
     "Configuração dos jumpers (1-2 = nível 0, 2-3 = nível 1):\\n"
     "27C128: JP1 2-3 (VPP=+5V), JP2 2-3 (/PGM=+5V)\\n"
     "27C256: JP1 2-3 (VPP=+5V), JP2 = A14 (escolhe a metade de 16 KB)\\n"
     "27C512: JP1 = A15, JP2 = A14 (escolhem um dos 4 bancos de 16 KB)\\n"
     "28C256: JP1 = A14 (escolhe a metade), JP2 2-3 (/WE=+5V, sem escrita)\\n"
     "JP3: fechado = cartucho ativo; aberto = desligado (liga direto no titulador)"),
]

# ---------------------------------------------------------------------------
# geração
# ---------------------------------------------------------------------------
out = []
w = out.append


def fnum(v):
    s = "%.4f" % v
    s = s.rstrip("0").rstrip(".")
    return "0" if s in ("-0", "") else s


def effects(size=1.27, justify=None, hide=False, indent="\t\t\t"):
    j = ("\n%s\t(justify %s)" % (indent, justify)) if justify else ""
    h = ("\n%s\t(hide yes)" % indent) if hide else ""
    return ("%s(effects\n%s\t(font\n%s\t\t(size %s %s)\n%s\t)%s%s\n%s)"
            % (indent, indent, indent, fnum(size), fnum(size), indent, j, h, indent))


def property_block(key, value, x, y, hide=False, justify=None, rot=0):
    rot = int(round(rot))
    return ('\t\t(property "%s" "%s"\n\t\t\t(at %s %s %s)\n\t\t\t(show_name no)\n\t\t\t(do_not_autoplace no)\n%s\n\t\t)'
            % (key, value, fnum(x), fnum(y), rot, effects(justify=justify, hide=hide), ))


used_syms = []


def need(lib, name):
    if (lib, name) not in used_syms:
        used_syms.append((lib, name))


wires, labels, extra_syms, noconns = [], [], [], []
pwr_count = [0]


def wire(x1, y1, x2, y2, key):
    wires.append('\t(wire\n\t\t(pts\n\t\t\t(xy %s %s) (xy %s %s)\n\t\t)\n\t\t(stroke\n\t\t\t(width 0)\n'
                 '\t\t\t(type default)\n\t\t)\n\t\t(uuid "%s")\n\t)' % (fnum(x1), fnum(y1), fnum(x2), fnum(y2), uid("w", key)))


def label(name, x, y, rot, key):
    just = {0: "left bottom", 180: "right bottom", 90: "left bottom", 270: "right bottom"}[rot]
    labels.append('\t(label "%s"\n\t\t(at %s %s %d)\n%s\n\t\t(uuid "%s")\n\t)'
                  % (name, fnum(x), fnum(y), rot, effects(justify=just, indent="\t\t"), uid("l", key)))


def placed_symbol(lib, name, ref, value, footprint, unit, x, y, rot=0, pin_numbers=(), key=None,
                  ref_at=None, val_at=None, hide_ref=False, hide_val=False, power=False,
                  ref_fx=(0, None), val_fx=(0, None)):
    key = key or ref
    u = uid("s", key, unit)
    # furos de fixação ficam fora da lista de materiais (como os footprints); jumpers entram
    bom = "no" if power or lib == "Mechanical" else "yes"
    s = ['\t(symbol\n\t\t(lib_id "%s:%s")\n\t\t(at %s %s %d)\n\t\t(unit %d)\n\t\t(body_style 1)\n'
         '\t\t(exclude_from_sim no)\n\t\t(in_bom %s)\n\t\t(on_board %s)\n\t\t(in_pos_files %s)\n\t\t(dnp no)\n'
         '\t\t(uuid "%s")' % (lib, name, fnum(x), fnum(y), rot, unit, bom,
                              "no" if power else "yes", bom, u)]
    rx, ry = ref_at or (x, y - 2.54)
    vx, vy = val_at or (x, y + 2.54)
    s.append(property_block("Reference", ref, rx, ry, hide=hide_ref, rot=ref_fx[0], justify=ref_fx[1]))
    s.append(property_block("Value", value, vx, vy, hide=hide_val, rot=val_fx[0], justify=val_fx[1]))
    s.append(property_block("Footprint", footprint, x, y, hide=True))
    s.append(property_block("Datasheet", "", x, y, hide=True))
    s.append(property_block("Description", "", x, y, hide=True))
    for pn in pin_numbers:
        s.append('\t\t(pin "%s"\n\t\t\t(uuid "%s")\n\t\t)' % (pn, uid("p", key, unit, pn)))
    s.append('\t\t(instances\n\t\t\t(project "%s"\n\t\t\t\t(path "/%s"\n\t\t\t\t\t(reference "%s")\n'
             '\t\t\t\t\t(unit %d)\n\t\t\t\t)\n\t\t\t)\n\t\t)' % (PROJECT, ROOT_UUID, ref, unit))
    s.append('\t)')
    return "\n".join(s)


def power_symbol(net, x, y, outward, key):
    """+5V aponta para fora (para cima quando o fio sobe); GND para fora também."""
    pwr_count[0] += 1
    name = "+5V" if net == "+5V" else "GND"
    need("power", name)
    if name == "+5V":
        rot = {(0, -1): 0, (-1, 0): 90, (0, 1): 180, (1, 0): 270}[outward]
    else:
        rot = {(0, 1): 0, (1, 0): 90, (0, -1): 180, (-1, 0): 270}[outward]
    dx, dy = outward
    tx, ty = x + dx * 5.08, y + dy * 5.08
    extra_syms.append(placed_symbol("power", name, "#PWR%02d" % pwr_count[0], name, "", 1, x, y, rot,
                                    pin_numbers=("1",), key="pwr%d" % pwr_count[0],
                                    ref_at=(x, y), val_at=(tx, ty), hide_ref=True, power=True))


symbols_out = []
netlist_check = {}
for ref, lib, name, value, fp, units, conns in PARTS:
    need(lib, name)
    pins = pins_of(lib, name)
    for unit, x, y in units:
        upins = [p for p in pins if p[0] in (unit, 0)]
        # referência acima do corpo, valor abaixo: usa os campos da biblioteca
        blk = flatten(lib, name)
        fields = {}
        for key in ("Reference", "Value"):
            m = re.search(r'\(property "%s" "[^"]*"\s*\(at ([-\d.]+) ([-\d.]+) ([-\d.]+)\)(.*?)\n\t\t\)'
                          % key, blk, re.S)
            fx, fy = FIELD_OVERRIDE.get(name, {}).get(key, (float(m.group(1)), float(m.group(2))))
            j = re.search(r'\(justify ([^)]*)\)', m.group(4))
            fields[key] = ((x + fx, y - fy), (float(m.group(3)), j.group(1) if j else None))
        symbols_out.append(placed_symbol(lib, name, ref, value, fp, unit, x, y, 0,
                                         pin_numbers=[p[2] for p in upins],
                                         ref_at=fields["Reference"][0], val_at=fields["Value"][0],
                                         ref_fx=fields["Reference"][1], val_fx=fields["Value"][1]))
        for (_u, pname, pnum, px, py, ang) in upins:
            sx, sy = x + px, y - py                         # ponto de ligação (Y invertido)
            a = math.radians(ang)
            d = (round(math.cos(a)), -round(math.sin(a)))   # sentido pino -> corpo (esquemático)
            outward = (-d[0], -d[1])
            if pnum not in conns:
                raise SystemExit("pino sem ligação definida: %s.%s (%s)" % (ref, pnum, pname))
            net = conns[pnum]
            if net is None:
                noconns.append('\t(no_connect\n\t\t(at %s %s)\n\t\t(uuid "%s")\n\t)'
                               % (fnum(sx), fnum(sy), uid("nc", ref, pnum)))
                continue
            netlist_check.setdefault(net, []).append("%s.%s" % (ref, pnum))
            stub = POWER_STUB.get(ref, 2.54) if net in ("+5V", "GND") else 2.54
            ex, ey = sx + outward[0] * stub, sy + outward[1] * stub
            wire(sx, sy, ex, ey, "%s.%s" % (ref, pnum))
            if net in ("+5V", "GND"):
                power_symbol(net, ex, ey, outward, "%s.%s" % (ref, pnum))
            else:
                rot = {(1, 0): 0, (-1, 0): 180, (0, -1): 90, (0, 1): 270}[outward]
                label(net, ex, ey, rot, "%s.%s" % (ref, pnum))
    for pnum in conns:
        if pnum not in [p[2] for p in pins]:
            raise SystemExit("pino inexistente em %s: %s" % (ref, pnum))

for net, x, y in PWR_FLAGS:
    need("power", "PWR_FLAG")
    k = "flag_" + net
    extra_syms.append(placed_symbol("power", "PWR_FLAG", "#FLG0%d" % (1 if net == "+5V" else 2), "PWR_FLAG",
                                    "", 1, x, y, 0, pin_numbers=("1",), key=k, ref_at=(x, y - 2.54),
                                    val_at=(x, y - 3.81), hide_ref=True, power=True))
    wire(x, y, x, y + 5.08, k)
    power_symbol(net, x, y + 5.08, (0, 1) if net == "GND" else (0, -1), k)

# ---------------------------------------------------------------------------
w('(kicad_sch')
w('\t(version 20260101)')
w('\t(generator "eeschema")')
w('\t(generator_version "10.0")')
w('\t(uuid "%s")' % ROOT_UUID)
w('\t(paper "A3")')
w('\t(title_block\n\t\t(title "VET 3000 - Cartucho de ROM (CN1)")\n\t\t(date "2026-09-27")\n\t\t(rev "1.0")\n'
  '\t\t(company "Leonardo Roman da Rosa")\n\t\t(comment 1 "Copyright (C) 2026 Leonardo Roman da Rosa - GPL-3.0-or-later")\n'
  '\t\t(comment 2 "Gerado por hardware/cartucho/gen/gen_schematic.py")\n\t)')
w('\t(lib_symbols')
for lib, name in used_syms:
    blk = flatten(lib, name)
    w("\n".join("\t\t" + ln if ln.strip() else ln for ln in blk.split("\n")))
w('\t)')
for x, y, size, t in NOTES:
    w('\t(text "%s"\n\t\t(exclude_from_sim no)\n\t\t(at %s %s 0)\n%s\n\t\t(uuid "%s")\n\t)'
      % (t, fnum(x), fnum(y), effects(size=size, justify="left top", indent="\t\t"), uid("t", x, y)))
out.extend(wires)
out.extend(labels)
out.extend(noconns)
out.extend(symbols_out)
out.extend(extra_syms)
w('\t(sheet_instances\n\t\t(path "/"\n\t\t\t(page "1")\n\t\t)\n\t)')
w('\t(embedded_fonts no)')
w(')')
open(OUT, "w", encoding="utf-8", newline="\n").write("\n".join(out) + "\n")
print("esquemático:", os.path.abspath(OUT))
for net in sorted(netlist_check):
    if len(netlist_check[net]) < 2 and net not in ("+5V", "GND"):
        print("AVISO: rede com um só pino:", net, netlist_check[net])
