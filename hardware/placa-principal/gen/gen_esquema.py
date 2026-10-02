#!/usr/bin/env python3
# Copyright (C) 2026 Leonardo Roman da Rosa
# SPDX-License-Identifier: CERN-OHL-S-2.0
# Hardware aberto sob a CERN-OHL-S v2 (ver hardware/placa-principal/LICENSE).
# Source location: https://github.com/lrrosa/vet3000
#
"""Gera o esquema aproximado (KiCad 10) da placa principal do VET 3000: parte digital.

    python gen_esquema.py [pasta_das_bibliotecas_de_simbolos_do_KiCad]

O circuito vem de duas fontes, marcadas ligação a ligação:
  - medidas de continuidade no aparelho (docs/medidas-originais e docs/origem.md);
  - o "Build This Video Titler" da Radio-Electronics (12/1985 e 01/1986), de onde o VET deriva.

Cada pino é ligado por um fio curto a um rótulo de rede (ou a um símbolo de alimentação), então o
circuito fica descrito aqui como tabelas de ligação. O script também gera a biblioteca de símbolos
do projeto (TMS9128, µPD41416, +3V_BAT, bloco da parte analógica), o arquivo de projeto com as
classes de rede coloridas pela confiança e o roteiro de continuidade (continuidade.md).
"""
import json
import math
import os
import re
import sys
import uuid

KLIB = sys.argv[1] if len(sys.argv) > 1 else r"C:/Program Files/KiCad/10.0/share/kicad/symbols"
TEMPLATE = os.path.join(os.path.dirname(KLIB.rstrip("/\\")), "template", "kicad.kicad_pro")
HERE = os.path.dirname(os.path.abspath(__file__))
OUTDIR = os.path.normpath(os.path.join(HERE, ".."))
PROJECT = "vet3000_placa"
MYLIB = "vet3000_placa"
ROOT_UUID = "5e7a3000-0c4a-4e0c-9a11-00000000b0a1"
NS = uuid.UUID("7e7a3000-1988-4d6a-8a09-c0ffee00b0a1")
DATE = "2026-09-30"


def uid(*parts):
    return str(uuid.uuid5(NS, "/".join(str(p) for p in parts)))


def fnum(v):
    s = ("%.4f" % v).rstrip("0").rstrip(".")
    return "0" if s in ("-0", "") else s


# ---------------------------------------------------------------------------
# símbolos próprios
# ---------------------------------------------------------------------------
def _font(size=1.27):
    return "(effects (font (size %s %s)))" % (fnum(size), fnum(size))


def _prop(key, value, x, y, hide=False, rot=0):
    h = " (hide yes)" if hide else ""
    return ('\t\t(property "%s" "%s" (at %s %s %d) (show_name no) (do_not_autoplace no)%s %s)'
            % (key, value, fnum(x), fnum(y), rot, h, _font()))


def _pin(num, name, ptype, x, y, ang, length=5.08):
    return ('\t\t\t(pin %s line (at %s %s %d) (length %s) (name "%s" %s) (number "%s" %s))'
            % (ptype, fnum(x), fnum(y), ang, fnum(length), name, _font(), num, _font()))


def ic_symbol(name, left, right, top, bottom, half_w, desc, fp, ref="U", keywords=""):
    """Caixa com pinos à esquerda/direita (listas de (número, nome, tipo) ou None = espaço)."""
    rows = max(len(left), len(right))
    y0 = (rows - 1) * 2.54 / 2
    y0 = math.ceil(y0 / 2.54) * 2.54
    body_top = y0 + 2.54
    body_bot = y0 - rows * 2.54
    px = half_w + 5.08
    pins = []
    for i, p in enumerate(left):
        if p:
            pins.append(_pin(p[0], p[1], p[2], -px, y0 - i * 2.54, 0))
    for i, p in enumerate(right):
        if p:
            pins.append(_pin(p[0], p[1], p[2], px, y0 - i * 2.54, 180))
    for i, p in enumerate(top):
        pins.append(_pin(p[0], p[1], p[2], (i - (len(top) - 1) / 2) * 5.08, body_top + 5.08, 270))
    for i, p in enumerate(bottom):
        pins.append(_pin(p[0], p[1], p[2], (i - (len(bottom) - 1) / 2) * 5.08, body_bot - 5.08, 90))
    out = ['\t(symbol "%s"' % name,
           '\t\t(pin_names (offset 1.016))',
           '\t\t(exclude_from_sim no) (in_bom yes) (on_board yes) (in_pos_files yes)'
           ' (duplicate_pin_numbers_are_jumpers no)',
           _prop("Reference", ref, -half_w, body_top + 1.27),
           _prop("Value", name, -half_w, body_bot - 1.27),
           _prop("Footprint", fp, 0, 0, hide=True),
           _prop("Datasheet", "", 0, 0, hide=True),
           _prop("Description", desc, 0, 0, hide=True),
           _prop("ki_keywords", keywords, 0, 0, hide=True),
           '\t\t(symbol "%s_0_1" (rectangle (start %s %s) (end %s %s) (stroke (width 0.254) (type default))'
           ' (fill (type background))))' % (name, fnum(-half_w), fnum(body_top), fnum(half_w), fnum(body_bot)),
           '\t\t(symbol "%s_1_1"' % name]
    out += pins
    out += ['\t\t)', '\t\t(embedded_fonts no)', '\t)']
    return "\n".join(out)


G = None  # espaço vazio numa coluna de pinos
TMS9128 = ic_symbol(
    "TMS9128",
    [("40", "XTAL1", "input"), ("39", "XTAL2", "passive"), G, ("37", "CPUCLK", "output"), G,
     ("34", "~{RESET}/SYNC", "input"), G, ("13", "MODE", "input"), ("14", "~{CSW}", "input"),
     ("15", "~{CSR}", "input"), ("16", "~{INT}", "open_collector"), G]
    + [(str(24 - i), "CD%d" % i, "bidirectional") for i in range(8)],
    [(str(32 - i), "RD%d" % i, "bidirectional") for i in range(8)] + [G]
    + [(str(10 - i), "AD%d" % i, "output") for i in range(8)] + [G]
    + [("1", "~{RAS}", "output"), ("2", "~{CAS}", "output"), ("11", "R/~{W}", "output"), G,
       ("36", "Y", "output"), ("38", "R-Y", "output"), ("35", "B-Y", "output")],
    [("33", "VCC", "power_in")], [("12", "VSS", "power_in")], 12.7,
    "Video Display Processor, saídas Y/R-Y/B-Y, VRAM 16K x 4 (TMS9118/9128/9129)",
    "Package_DIP:DIP-40_W15.24mm", keywords="VDP TMS9918 TMS9928 video")
UPD41416 = ic_symbol(
    "uPD41416",
    [("14", "A0", "input"), ("13", "A1", "input"), ("12", "A2", "input"), ("11", "A3", "input"),
     ("8", "A4", "input"), ("7", "A5", "input"), ("6", "A6", "input"), ("10", "A7", "input"), G,
     ("5", "~{RAS}", "input"), ("16", "~{CAS}", "input"), ("4", "~{WE}", "input"), ("1", "~{OE}", "input")],
    [("2", "I/O1", "bidirectional"), ("3", "I/O2", "bidirectional"), ("15", "I/O3", "bidirectional"),
     ("17", "I/O4", "bidirectional")],
    [("9", "VCC", "power_in")], [("18", "GND", "power_in")], 10.16,
    "DRAM 16K x 4 (NEC µPD41416, equivalente à TMS4416)", "Package_DIP:DIP-18_W7.62mm",
    keywords="DRAM 4416")
BLOCO = ic_symbol(
    "PARTE_ANALOGICA",
    [], [("1", "VDP_CLK", "output"), ("2", "VRESET_HIB", "output"), G, ("3", "CPUCLK", "input"), G,
         ("4", "VDP_Y", "input"), ("5", "VDP_RY", "input"), ("6", "VDP_BY", "input")],
    [], [], 22.86, "Parte analógica ainda não desenhada (PLL, sincronismo, croma, mixer)", "",
    ref="#BLK")
BLOCO = BLOCO.replace("(in_bom yes) (on_board yes)", "(in_bom no) (on_board no)")


def power_from_5v(newname):
    s = open(os.path.join(KLIB, "power.kicad_sym"), encoding="utf-8").read()
    i = s.index('(symbol "+5V"')
    blk = s[i:balanced(s, i)]
    blk = blk.replace('"+5V"', '"%s"' % newname).replace('(symbol "+5V_', '(symbol "%s_' % newname)
    return "\t" + blk.replace('\\"+5V\\"', '\\"%s\\"' % newname)


def balanced(s, i):
    d, j, in_str = 0, i, False
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


MYLIB_TEXT = ("(kicad_symbol_lib\n\t(version 20251024)\n\t(generator \"gen_esquema.py\")\n"
              "\t(generator_version \"10.0\")\n" + "\n".join([TMS9128, UPD41416, BLOCO, power_from_5v("+3V_BAT")])
              + "\n)\n")

# ---------------------------------------------------------------------------
# leitura das bibliotecas
# ---------------------------------------------------------------------------
_lib_cache = {MYLIB: MYLIB_TEXT}


def lib_text(lib):
    if lib not in _lib_cache:
        _lib_cache[lib] = open(os.path.join(KLIB, lib + ".kicad_sym"), encoding="utf-8").read()
    return _lib_cache[lib]


def raw_symbol(lib, name):
    s = lib_text(lib)
    i = s.index('(symbol "%s"' % name)
    return s[i:balanced(s, i)]


def props_of(block):
    out = {}
    for m in re.finditer(r'\(property "([^"]+)"', block):
        out[m.group(1)] = block[m.start():balanced(block, m.start())]
    return out


def flatten(lib, name):
    blk = raw_symbol(lib, name)
    m = re.match(r'\(symbol "[^"]+"\s*\(extends "([^"]+)"\)', blk)
    if m:
        parent = m.group(1)
        pblk = raw_symbol(lib, parent)
        child = props_of(blk)
        for key, pb in props_of(pblk).items():
            if key in child:
                pblk = pblk.replace(pb, child[key], 1)
        pblk = pblk.replace('(symbol "%s_' % parent, '(symbol "%s_' % name)
        blk = pblk.replace('(symbol "%s"' % parent, '(symbol "%s"' % name, 1)
    return blk.replace('(symbol "%s"' % name, '(symbol "%s:%s"' % (lib, name), 1)


def pins_of(lib, name):
    blk = flatten(lib, name)
    pins = []
    for m in re.finditer(r'\(symbol "%s_(\d+)_(\d+)"' % re.escape(name), blk):
        unit, style = int(m.group(1)), int(m.group(2))
        if style == 2:
            continue
        sub = blk[m.start():balanced(blk, m.start())]
        for p in re.finditer(r'\(pin \w+ \w+\s*\(at ([-\d.]+) ([-\d.]+) ([-\d.]+)\)', sub):
            pb = sub[p.start():balanced(sub, p.start())]
            pname = re.search(r'\(name "([^"]*)"', pb).group(1)
            pnum = re.search(r'\(number "([^"]*)"', pb).group(1)
            pins.append((unit, pname, pnum, float(p.group(1)), float(p.group(2)), float(p.group(3))))
    return pins


def field_pos(lib, name, key):
    blk = flatten(lib, name)
    m = re.search(r'\(property "%s" "[^"]*"\s*\(at ([-\d.]+) ([-\d.]+) ([-\d.]+)\)(.*?)\n?\t*\)' % key, blk, re.S)
    j = re.search(r'\(justify ([^)]*)\)', m.group(4) or "")
    return float(m.group(1)), float(m.group(2)), float(m.group(3)), (j.group(1) if j else None)


# ---------------------------------------------------------------------------
# o circuito
# ---------------------------------------------------------------------------
POWER_NETS = {"+5V": ("power", "+5V"), "GND": ("power", "GND"), "+12V": ("power", "+12V"),
              "-5V": ("power", "-5V"), "+3V_BAT": (MYLIB, "+3V_BAT")}
FP = {"DIP14": "Package_DIP:DIP-14_W7.62mm", "DIP16": "Package_DIP:DIP-16_W7.62mm",
      "DIP20": "Package_DIP:DIP-20_W7.62mm", "DIP28": "Package_DIP:DIP-28_W15.24mm",
      "DIP40": "Package_DIP:DIP-40_W15.24mm", "R": "Resistor_THT:R_Axial_DIN0207_L6.3mm_D2.5mm_P7.62mm_Horizontal",
      "C": "Capacitor_THT:C_Disc_D5.0mm_W2.5mm_P5.00mm", "CP": "Capacitor_THT:CP_Radial_D5.0mm_P2.00mm",
      "D": "Diode_THT:D_DO-35_SOD27_P7.62mm_Horizontal", "TO92": "Package_TO_SOT_THT:TO-92_Inline",
      "EDGE": "", "HDR16": "Connector_PinHeader_2.54mm:PinHeader_2x08_P2.54mm_Vertical"}


# campos que colidiriam com pinos (x, y, rotação, alinhamento em coordenadas da biblioteca)
FIELD_OVERRIDE = {
    "HY6264AxP": {"Reference": (-2.54, 24.13, 0, "right"), "Value": (-2.54, 21.59, 0, "right")},
    "27128": {"Value": (-1.27, -31.75, 0, "right")},
}


def bus(prefix, pins, start=0):
    return {p: "%s%d" % (prefix, start + i) for i, p in enumerate(pins)}


EPROM_A = ["10", "9", "8", "7", "6", "5", "4", "3", "25", "24", "21", "23", "2", "26"]   # A0..A13
MEM_D = ["11", "12", "13", "15", "16", "17", "18", "19"]                                 # D0..D7

CPU = {"1": "GND", "2": "+5V", "3": "IRQ_N", "4": "+5V", "5": None, "6": None, "7": "+5V",
       "32": "R_W", "33": "+5V", "34": "E", "35": None, "36": "+5V", "37": "RESET_N",
       "38": "CPUCLK", "39": "GND", "40": "HALT_N"}
CPU.update(bus("A", [str(8 + i) for i in range(16)]))
CPU.update({str(31 - i): "D%d" % i for i in range(8)})

ROM = {"1": "+5V", "14": "GND", "20": "ROM_SEL_N", "22": "GND", "27": "+5V", "28": "+5V"}
ROM.update(bus("A", EPROM_A))
ROM.update(bus("D", MEM_D))

RAM = {"1": None, "14": "GND", "20": "RAM_CS_N", "22": "RD_N", "26": "+5V", "27": "R_W", "28": "+3V_BAT"}
RAM.update(bus("A", EPROM_A[:13]))
RAM.update(bus("D", MEM_D))

VDP = {"1": "VRAS_N", "2": "VCAS_N", "11": "VR_W", "12": "GND", "13": "A0", "14": "CSW_N",
       "15": "CSR_N", "16": None, "33": "+5V", "34": "VDP_RESET_N", "35": "VDP_BY", "36": "VDP_Y",
       "37": "CPUCLK", "38": "VDP_RY", "39": None, "40": "VDP_CLK"}
VDP.update({str(10 - i): "VAD%d" % i for i in range(8)})
VDP.update({str(32 - i): "VRD%d" % i for i in range(8)})
VDP.update({str(24 - i): "D%d" % (7 - i) for i in range(8)})     # CD0 (24) = D7 ... CD7 (17) = D0


def dram(first_rd):
    d = {"1": "GND", "4": "VR_W", "5": "VRAS_N", "9": "+5V", "16": "VCAS_N", "18": "GND",
         "17": "VRD%d" % first_rd, "15": "VRD%d" % (first_rd + 1), "3": "VRD%d" % (first_rd + 2),
         "2": "VRD%d" % (first_rd + 3)}
    # AD0 do VDP vai ao A7 da DRAM, AD7 ao A0 (Fig. 10 da revista)
    for i, p in enumerate(["10", "6", "7", "8", "11", "12", "13", "14"]):
        d[p] = "VAD%d" % i
    return d


# 74LS273: bit k do barramento -> entrada/saída (pinagem da Fig. 14 da revista)
L273_D = ["3", "18", "4", "17", "7", "14", "8", "13"]
L273_Q = ["2", "19", "5", "16", "6", "15", "9", "12"]
KB_W = {"1": "+5V", "10": "GND", "11": "KB_WR_N", "20": "+5V"}
for k in range(8):
    KB_W[L273_D[k]] = "D%d" % k
    KB_W[L273_Q[k]] = "KB_L%d" % (k + 1) if k < 7 else None
# 74LS244: entrada Ik -> saída para o bit k (Fig. 14)
L244_I = ["2", "4", "17", "15", "6", "13", "8", "11"]
L244_O = ["18", "16", "3", "5", "14", "7", "12", "9"]
KB_R = {"1": "KB_RD_N", "19": "KB_RD_N", "10": "GND", "20": "+5V"}
for k in range(8):
    KB_R[L244_I[k]] = "KB_C%d" % (k + 1)
    KB_R[L244_O[k]] = "D%d" % k

CN1 = {"a1": "IRQ_N", "a10": "ROM_SEL_N", "a11": "IO_SEL_N", "a12": "R_W", "a13": "HALT_N",
       "a14": "XROM_N", "a15": "+5V", "a16": "E_CLK_N", "a17": "GND", "a18": None,
       "b1": "+3V_BAT", "b16": "-5V", "b17": "GND", "b18": None}
CN1.update({"a%d" % (i + 2): "D%d" % i for i in range(8)})
CN1.update({"b%d" % (i + 2): "A%d" % i for i in range(14)})

CN2 = {str(i + 1): "KB_C%d" % (i + 1) for i in range(8)}          # membrana superior (colunas)
CN2.update({str(i + 9): "KB_L%d" % (i + 1) for i in range(7)})    # membrana inferior (linhas)
CN2["16"] = None                                                  # trilha 8 inferior: sem ligação


def two(a, b):
    return {"1": a, "2": b}


# Peças: (ref, lib, símbolo, valor, footprint, [(unidade, x, y)], ligações, revista, origem)
#   origem: "foto" = referência e valor lidos na placa; "prov" = referência provisória
SHEETS = [
    {"file": "cpu.kicad_sch", "name": "CPU e memória", "page": "2",
     "title": "CPU, memórias e decodificação",
     "parts": [
         ("U101", "CPU_NXP_6800", "MC6809", "MC6809", FP["DIP40"], [(1, 76.2, 111.76)], CPU, "IC23", "prov"),
         ("U102", "Memory_EPROM", "27128", "M27128A (VET 2.1)", FP["DIP28"], [(1, 177.8, 104.14)], ROM,
          "IC19 (2764)", "prov"),
         ("U103", "Memory_RAM", "HY6264AxP", "HY6264LP-10", FP["DIP28"], [(1, 276.86, 104.14)], RAM,
          "IC20 (HM6264LP)", "prov"),
         ("U15", "74xx", "74LS139", "74LS139", FP["DIP16"],
          [(1, 177.8, 187.96), (2, 276.86, 187.96), (3, 330.2, 187.96)],
          {"1": "E_CLK_N", "2": "A14", "3": "A15", "4": "RAM_CS_N", "5": "XROM_N", "6": "IO_SEL_N",
           "7": "ROM_Y3_N", "15": "IO_EN_N", "14": "R_W", "13": "A1", "12": "CSW_N", "11": "CSR_N",
           "10": "KB_WR_N", "9": "KB_RD_N", "8": "GND", "16": "+5V"}, "IC18", "foto"),
         ("U23", "74xx", "74LS00", "74LS00", FP["DIP14"],
          [(4, 76.2, 185.42), (1, 76.2, 208.28), (5, 111.76, 198.12)],
          {"12": "HALT_N", "13": "E", "11": "E_CLK_N", "1": "HALT_N", "2": "R_W", "3": "RD_N",
           "7": "GND", "14": "+5V"}, "IC15", "foto"),
         ("D10", "Diode", "1N914", "1N914", FP["D"], [(1, 350.52, 96.52)], two("ROM_Y3_N", "ROM_SEL_N"),
          "D5", "foto"),
         ("R48", "Device", "R", "3k3", FP["R"], [(1, 375.92, 96.52)], two("+5V", "ROM_SEL_N"), "R41", "foto"),
         ("D11", "Diode", "1N914", "1N914", FP["D"], [(1, 350.52, 129.54)], two("IO_SEL_N", "IO_EN_N"),
          "D6", "foto"),
         ("R49", "Device", "R", "3k3", FP["R"], [(1, 375.92, 129.54)], two("+5V", "IO_EN_N"), "R42", "foto"),
         ("R28", "Device", "R", "5k1", FP["R"], [(1, 167.64, 233.68)], two("+5V", "RESET_N"), "R38", "foto"),
         ("C102", "Device", "C_Polarized", "22uF", FP["CP"], [(1, 185.42, 233.68)], two("RESET_N", "GND"),
          "C45", "prov"),
         ("R29", "Device", "R", "4k7", FP["R"], [(1, 210.82, 233.68)], two("+5V", "HALT_N"), "R39", "foto"),
         ("R30", "Device", "R", "4k7", FP["R"], [(1, 228.6, 233.68)], two("+5V", "IRQ_N"), "R8", "foto"),
     ],
     "notes": [
         (25.4, 20.32, 2.0, "CPU, memórias e decodificação de endereços"),
         (25.4, 26.67, 1.27,
          "RAM $0000-$1FFF (Y0), cartucho $4000-$7FFF (XROM, Y1), E/S $8000-$BFFF (Y2), ROM $C000-$FFFF (Y3).\\n"
          "U15 (1ª metade) só decodifica com E alto e /HALT alto (U23). A 2ª metade separa, com R/W e A1:\\n"
          "/CSW e /CSR do VDP ($8000/$8001) e escrita/leitura do teclado ($8002).\\n"
          "D10/R48 e D11/R49 formam um OU com diodos: um computador externo no CN1 pode selecionar a ROM\\n"
          "(ROM_SEL) e a E/S (IO_EN) com a CPU parada por /HALT (revista, parte 3)."),
         (290.83, 20.32, 1.27,
          "No VET, o /NMI (pino 2) vai direto ao +5 V e o /IRQ vai ao CN1 (medido).\\n"
          "Na revista era o contrário: /NMI na porta de expansão com R8, /IRQ em +5 V.\\n"
          "R29/R30 (4k7): qual deles é o do /HALT e qual o do /IRQ não foi verificado.\\n"
          "/OE da EPROM no GND e /OE da RAM em U23 (NÃO(/HALT·R/W)): revista, não medidos.\\n"
          "O CN1 a11 foi medido no pino 6 do U15 (antes do diodo D11); na revista\\n"
          "a porta usava o outro lado do diodo (pino 15)."),
         (25.4, 256.54, 1.27,
          "U101-U103, C102: referências provisórias (as da placa não aparecem nas fotos).\\n"
          "Portas b e c de U23 (pinos 4-6 e 8-10) ficam na parte analógica."),
     ]},
    {"file": "video.kicad_sch", "name": "Vídeo", "page": "3", "title": "VDP e VRAM",
     "parts": [
         ("U104", MYLIB, "TMS9128", "TMS9128NL", FP["DIP40"], [(1, 114.3, 116.84)], VDP, "IC10", "prov"),
         ("U14", MYLIB, "uPD41416", "uPD41416C-15", "Package_DIP:DIP-18_W7.62mm", [(1, 254.0, 86.36)],
          dram(0), "IC11 (4416)", "foto"),
         ("U21", MYLIB, "uPD41416", "uPD41416C-15", "Package_DIP:DIP-18_W7.62mm", [(1, 254.0, 160.02)],
          dram(4), "IC12 (4416)", "foto"),
         ("T101", "Transistor_BJT", "Q_PNP_EBC", "2N3906", FP["TO92"], [(1, 76.2, 228.6)],
          {"1": "+12V", "2": "VDP_RST_B", "3": "VDP_RESET_N"}, "Q2", "prov"),
         ("R26", "Device", "R", "120k", FP["R"], [(1, 50.8, 215.9)], two("+12V", "VDP_RST_B"), "R17", "foto"),
         ("C101", "Device", "C", "100nF", FP["C"], [(1, 35.56, 238.76)], two("VDP_RST_B", "VRESET_HIB"),
          "C16", "prov"),
         ("R27", "Device", "R", "2k2", FP["R"], [(1, 106.68, 238.76)], two("VDP_RESET_N", "RESET_N"),
          "R18", "foto"),
         ("D8", "Device", "D_Zener", "1N751 (5,1 V)", FP["D"], [(1, 132.08, 251.46)],
          {"1": "RESET_N", "2": "GND"}, "D2", "foto"),
         ("R103", "Device", "R", "470", FP["R"], [(1, 228.6, 233.68)], two("VDP_Y", "GND"), "R21", "prov"),
         ("C103", "Device", "C", "220pF", FP["C"], [(1, 243.84, 233.68)], two("VDP_Y", "GND"), "C19", "prov"),
         ("R104", "Device", "R", "470", FP["R"], [(1, 264.16, 233.68)], two("VDP_RY", "GND"), "R20", "prov"),
         ("C104", "Device", "C", "220pF", FP["C"], [(1, 279.4, 233.68)], two("VDP_RY", "GND"), "C18", "prov"),
         ("R105", "Device", "R", "470", FP["R"], [(1, 299.72, 233.68)], two("VDP_BY", "GND"), "R19", "prov"),
         ("C105", "Device", "C", "220pF", FP["C"], [(1, 314.96, 233.68)], two("VDP_BY", "GND"), "C17", "prov"),
     ],
     "flags": [("+12V", 25.4, 208.28)],
     "notes": [
         (25.4, 20.32, 2.0, "Vídeo: VDP TMS9128 e 16 KB de VRAM"),
         (25.4, 26.67, 1.27,
          "O clock mestre (VDP_CLK, 10,738635 MHz) vem do PLL (U7 MC4044 + U1 MC4024) da parte analógica.\\n"
          "CPUCLK (pino 37) = mestre / 3 = 3,579545 MHz: vai ao EXTAL do 6809 e aos divisores 74LS191.\\n"
          "/INT (pino 16) sem ligação: sem continuidade com o /IRQ do 6809 (medido). O firmware lê o status.\\n"
          "D0 do barramento vai ao CD7 (pino 17) e D7 ao CD0 (pino 24): a TI numera ao contrário (medido)."),
         (304.8, 20.32, 1.27,
          "VRAM (Fig. 10 da revista): AD0-AD7 do VDP vão a A7-A0 das DRAMs,\\n"
          "RD0-RD3 a uma e RD4-RD7 à outra; /OE das DRAMs no GND.\\n"
          "Qual das duas é U14 e qual é U21 não foi verificado."),
         (25.4, 185.42, 1.27,
          "RESET/SYNC (pino 34), 3 níveis: 0 V reseta o VDP (RESET_N no boot);\\n"
          "5 V normal; ~12 V por T101 com o pulso VRESET_HIB (genlock) zera os contadores.\\n"
          "D8 limita o RESET_N a 5,1 V. R26/R27/D8 lidos na placa; T101/C101 provisórios."),
         (213.36, 251.46, 1.27,
          "Cargas das saídas Y, R-Y e B-Y (revista: 470 Ω e 220 pF). Referências provisórias."),
     ]},
    {"file": "teclado.kicad_sch", "name": "Teclado", "page": "4", "title": "Teclado",
     "parts": [
         ("U16", "74xx", "74LS273", "74LS273", FP["DIP20"], [(1, 114.3, 91.44)], KB_W, "IC21", "foto"),
         ("U22", "74xx", "74LS244", "74LS244", FP["DIP20"], [(1, 114.3, 175.26)], KB_R, "IC22", "foto"),
         ("CN2", "Connector_Generic", "Conn_02x08_Top_Bottom", "Membranas do teclado", FP["HDR16"],
          [(1, 294.64, 132.08)], CN2, "J (16 vias)", "prov"),
     ] + [("R%d" % (52 + i), "Device", "R", "10k", FP["R"], [(1, 205.74 + i * 12.7, 208.28)],
           two("+5V", "KB_C%d" % (i + 1)), "RN1", "foto") for i in range(8)],
     "notes": [
         (25.4, 20.32, 2.0, "Teclado: matriz de 7 linhas x 8 colunas em $8002"),
         (25.4, 26.67, 1.27,
          "Escrita em $8002: U16 guarda o byte; a linha n recebe o bit n-1 (ativo em 0). Leitura: U22 põe as\\n"
          "8 colunas no barramento (bit m-1 = coluna m, ativo em 0), com os pull-ups R52-R59. Isso foi medido\\n"
          "pelo lado do teclado (docs/teclado.md). Os pinos de U16/U22 usados aqui são os da revista:\\n"
          "a placa do VET foi redesenhada e pode trocar a ordem dos bits nos pinos."),
         (254.0, 96.52, 1.27,
          "CN2: conector 2x8 das duas membranas (nome provisório).\\n"
          "1-8: membrana superior, trilhas 1-8 (colunas).\\n"
          "9-16: membrana inferior, trilhas 1-8 (linhas);\\n"
          "a trilha 8 não tem ligação física.\\n"
          "Qual fileira do conector é de qual membrana\\n"
          "e a ordem de R52-R59 não foram verificadas."),
     ]},
    {"file": "conectores.kicad_sch", "name": "CN1 e alimentação", "page": "5",
     "title": "Conector CN1 e alimentação",
     "parts": [
         ("CN1", "Connector_Generic", "Conn_02x18_Row_Letter_First", "CN1 interface (borda 2x18)", FP["EDGE"],
          [(1, 101.6, 124.46)], CN1, "porta de expansão (Fig. 19)", "foto"),
         ("C106", "Device", "C_Polarized", "47uF", FP["CP"], [(1, 203.2, 190.5)], two("+5V", "GND"),
          "C46 (6809)", "prov"),
         ("C112", "Device", "C_Polarized", "100uF", FP["CP"], [(1, 223.52, 190.5)], two("+5V", "GND"),
          "C59 (VDP)", "prov"),
     ] + [("C%d" % (107 + i), "Device", "C", "100nF", FP["C"], [(1, 243.84 + i * 20.32, 190.5)],
           two("+5V", "GND"), rv, "prov")
          for i, rv in enumerate(["C47 (139)", "C48 (EPROM)", "C49 (273)", "C50 (74LS00)", "C51 (244)"])]
       + [("C%d" % (113 + i), "Device", "C", "100nF", FP["C"], [(1, 345.44 + i * 20.32, 190.5)],
           two("+5V", "GND"), rv, "prov") for i, rv in enumerate(["C60 (VRAM)", "C61 (VRAM)"])],
     "flags": [("+5V", 223.52, 50.8), ("GND", 248.92, 50.8), ("-5V", 274.32, 50.8), ("+3V_BAT", 299.72, 50.8)],
     "notes": [
         (25.4, 20.32, 2.0, "Conector traseiro CN1 e alimentação"),
         (25.4, 26.67, 1.27,
          "CN1 medido por fora, da esquerda para a direita (docs/conector-cn1.md). Fileira a = cima, b = baixo.\\n"
          "Lido de a17 para a1 e de b17 para b1, repete a porta de expansão da revista (Fig. 19).\\n"
          "a16 = /E CLK (U23), a14 = XROM (Y1), a11 = I/O SEL (Y2), a10 = ROM SEL (/CE da EPROM)."),
         (203.2, 101.6, 1.27,
          "Alimentação: vem da placa da fonte (7805 e reguladores) por um conector\\n"
          "de pinagem não levantada: +5V, +12V, -5V, +3V_BAT e GND.\\n"
          "+3V_BAT alimenta a RAM (pino 28): +5 V com o aparelho ligado,\\n"
          "3 V da bateria desligado (OU com diodos na fonte, como na revista).\\n"
          "+12 V e -5 V servem sobretudo à parte analógica."),
         (203.2, 215.9, 1.27,
          "Desacoplamento: valores e posições da revista, referências provisórias."),
     ]},
    {"file": "analogico.kicad_sch", "name": "Parte analógica (a desenhar)", "page": "6",
     "title": "Parte analógica (a desenhar)",
     "parts": [
         ("#BLK1", MYLIB, "PARTE_ANALOGICA", "Parte analógica (a desenhar)", "", [(1, 165.1, 116.84)],
          {"1": "VDP_CLK", "2": "VRESET_HIB", "3": "CPUCLK", "4": "VDP_Y", "5": "VDP_RY", "6": "VDP_BY"},
          "Figs. 7, 8, 11 e 13", "prov"),
     ],
     "notes": [
         (25.4, 20.32, 2.0, "Parte analógica: ainda não desenhada"),
         (25.4, 26.67, 1.27,
          "Este bloco só marca os sinais que atravessam a fronteira com a parte digital.\\n"
          "Na placa: U1 MC4024 e U7 MC4044 (PLL do clock do VDP), U13/U20 74LS191 (CPUCLK / 228),\\n"
          "U2/U10/U17 4066, U3 CA339E, U4 74LS221, U8 SN75108, U9 74LS05, U19 CA3126 (raspado),\\n"
          "LM1889, portas b e c de U23, XTAL1, CV1, CV2, RV1-RV3 e L1.\\n"
          "Esquemas de referência: Radio-Electronics, dez./1985, Figs. 7, 8, 11 e 13."),
     ]},
]

# ligações medidas (continuidade no aparelho: docs/medidas-originais/conector CN1 VET3000.txt)
MEASURED = set()


def meas(*pins):
    MEASURED.update(pins)


meas("CN1.a1", "U101.3", "CN1.a10", "U102.20", "CN1.a11", "U15.6", "CN1.a12", "U103.27", "U101.32",
     "CN1.a13", "U101.40", "CN1.a14", "U15.5", "CN1.a16", "U15.1", "CN1.b1", "U103.28",
     "CN1.a15", "U102.1", "U102.27", "U102.28", "U101.2", "U101.4", "U101.7", "U101.33", "U101.36", "U104.33",
     "CN1.a17", "CN1.b17", "CN1.b16", "U104.13")
for i in range(8):
    meas("CN1.a%d" % (i + 2), "U102.%s" % MEM_D[i], "U103.%s" % MEM_D[i], "U101.%d" % (31 - i), "U104.%d" % (17 + i))
for i in range(14):
    meas("CN1.b%d" % (i + 2), "U102.%s" % EPROM_A[i], "U101.%d" % (8 + i))
    if i < 13:
        meas("U103.%s" % EPROM_A[i])
NOT_CONNECTED_MEASURED = [("U104.16", "U101.3", "/INT do VDP e /IRQ do 6809: sem continuidade")]

# ---------------------------------------------------------------------------
# geração
# ---------------------------------------------------------------------------


def effects(size=1.27, justify=None, hide=False, indent="\t\t\t"):
    j = ("\n%s\t(justify %s)" % (indent, justify)) if justify else ""
    h = ("\n%s\t(hide yes)" % indent) if hide else ""
    return ("%s(effects\n%s\t(font\n%s\t\t(size %s %s)\n%s\t)%s%s\n%s)"
            % (indent, indent, indent, fnum(size), fnum(size), indent, j, h, indent))


def property_block(key, value, x, y, hide=False, justify=None, rot=0, size=1.27):
    return ('\t\t(property "%s" "%s"\n\t\t\t(at %s %s %d)\n\t\t\t(show_name no)\n\t\t\t(do_not_autoplace no)\n%s\n\t\t)'
            % (key, value, fnum(x), fnum(y), int(round(rot)), effects(size=size, justify=justify, hide=hide)))


# quais redes aparecem em mais de uma folha: essas viram rótulos globais
net_sheets = {}
for sh in SHEETS:
    for part in sh["parts"]:
        for net in part[6].values():
            if net and net not in POWER_NETS:
                net_sheets.setdefault(net, set()).add(sh["file"])
GLOBAL = {n for n, s in net_sheets.items() if len(s) > 1}

pwr_count = [0]
flag_count = [0]
all_pins = {}          # rede -> [(ref.pino, nome do pino, folha)]
components = []        # para a lista de peças


def build_sheet(sh, sheet_uuid):
    used, wires, labels, noconns, syms, extra = [], [], [], [], [], []
    path = "/%s/%s" % (ROOT_UUID, sheet_uuid)

    def need(lib, name):
        if (lib, name) not in used:
            used.append((lib, name))

    def wire(x1, y1, x2, y2, key):
        wires.append('\t(wire\n\t\t(pts\n\t\t\t(xy %s %s) (xy %s %s)\n\t\t)\n\t\t(stroke\n\t\t\t(width 0)\n'
                     '\t\t\t(type default)\n\t\t)\n\t\t(uuid "%s")\n\t)'
                     % (fnum(x1), fnum(y1), fnum(x2), fnum(y2), uid(sh["file"], "w", key)))

    def label(name, x, y, rot, key):
        if True:                      # rótulos globais (caixas) em todas as redes: empilham sem colidir
            just = {0: "left", 180: "right", 90: "left", 270: "right"}[rot]
            labels.append('\t(global_label "%s"\n\t\t(shape passive)\n\t\t(at %s %s %d)\n\t\t(fields_autoplaced yes)\n'
                          '%s\n\t\t(uuid "%s")\n\t\t(property "Intersheetrefs" "${INTERSHEET_REFS}"\n'
                          '\t\t\t(at %s %s 0)\n%s\n\t\t)\n\t)'
                          % (name, fnum(x), fnum(y), rot, effects(justify=just, indent="\t\t"),
                             uid(sh["file"], "l", key), fnum(x), fnum(y),
                             effects(justify=just, hide=True, indent="\t\t\t")))
        else:
            just = {0: "left bottom", 180: "right bottom", 90: "left bottom", 270: "right bottom"}[rot]
            labels.append('\t(label "%s"\n\t\t(at %s %s %d)\n%s\n\t\t(uuid "%s")\n\t)'
                          % (name, fnum(x), fnum(y), rot, effects(justify=just, indent="\t\t"),
                             uid(sh["file"], "l", key)))

    def placed(lib, name, ref, value, fp, unit, x, y, pins=(), key=None, fields=None, power=False,
               extra_props=()):
        key = key or ref
        virtual = power or ref.startswith("#")
        bom = "no" if virtual else "yes"
        s = ['\t(symbol\n\t\t(lib_id "%s:%s")\n\t\t(at %s %s 0)\n\t\t(unit %d)\n\t\t(body_style 1)\n'
             '\t\t(exclude_from_sim no)\n\t\t(in_bom %s)\n\t\t(on_board %s)\n\t\t(in_pos_files %s)\n\t\t(dnp no)\n'
             '\t\t(uuid "%s")' % (lib, name, fnum(x), fnum(y), unit, bom, bom, bom, uid(sh["file"], "s", key, unit))]
        f = fields or {}
        (rx, ry), (rrot, rj), rhide = f.get("Reference", ((x, y - 2.54), (0, None), False))
        (vx, vy), (vrot, vj), vhide = f.get("Value", ((x, y + 2.54), (0, None), False))
        s.append(property_block("Reference", ref, rx, ry, hide=rhide, rot=rrot, justify=rj))
        s.append(property_block("Value", value, vx, vy, hide=vhide, rot=vrot, justify=vj))
        s.append(property_block("Footprint", fp, x, y, hide=True))
        s.append(property_block("Datasheet", "", x, y, hide=True))
        s.append(property_block("Description", "", x, y, hide=True))
        for pk, pv, px, py, prot, pj, phide, psize in extra_props:
            s.append(property_block(pk, pv, px, py, hide=phide, rot=prot, justify=pj, size=psize))
        for pn in pins:
            s.append('\t\t(pin "%s"\n\t\t\t(uuid "%s")\n\t\t)' % (pn, uid(sh["file"], "p", key, unit, pn)))
        s.append('\t\t(instances\n\t\t\t(project "%s"\n\t\t\t\t(path "%s"\n\t\t\t\t\t(reference "%s")\n'
                 '\t\t\t\t\t(unit %d)\n\t\t\t\t)\n\t\t\t)\n\t\t)' % (PROJECT, path, ref, unit))
        s.append('\t)')
        return "\n".join(s)

    def power_symbol(net, x, y, outward, key):
        pwr_count[0] += 1
        lib, name = POWER_NETS[net]
        need(lib, name)
        if net == "GND":
            rot = {(0, 1): 0, (1, 0): 90, (0, -1): 180, (-1, 0): 270}[outward]
        else:
            rot = {(0, -1): 0, (-1, 0): 90, (0, 1): 180, (1, 0): 270}[outward]
        tx, ty = x + outward[0] * 5.08, y + outward[1] * 5.08
        ref = "#PWR%03d" % pwr_count[0]
        blk = placed(lib, name, ref, net, "", 1, x, y, pins=("1",), key="pwr%d" % pwr_count[0],
                     fields={"Reference": ((x, y), (0, None), True), "Value": ((tx, ty), (0, None), False)},
                     power=True)
        extra.append(blk.replace("(at %s %s 0)\n\t\t(unit" % (fnum(x), fnum(y)),
                                 "(at %s %s %d)\n\t\t(unit" % (fnum(x), fnum(y), rot), 1))

    for ref, lib, name, value, fp, units, conns, revista, origem in sh["parts"]:
        need(lib, name)
        pins = pins_of(lib, name)
        pinnums = [p[2] for p in pins]
        for pnum in conns:
            if pnum not in pinnums:
                raise SystemExit("pino inexistente em %s: %s" % (ref, pnum))
        components.append((ref, value, revista, origem, sh["name"]))
        for unit, x, y in units:
            upins = [p for p in pins if p[0] in (unit, 0)]
            fields = {}
            vy_lib = 0
            for key in ("Reference", "Value"):
                fx, fy, frot, fj = field_pos(lib, name, key)
                fx, fy, frot, fj = FIELD_OVERRIDE.get(name, {}).get(key, (fx, fy, frot, fj))
                fields[key] = ((x + fx, y - fy), (frot, fj), False)
                if key == "Value":
                    vy_lib = fy
            small = len(pins) <= 3
            (vx, vy) = fields["Value"][0]
            if small and name == "R":
                rv = (x + 3.81, y + 3.81, 90, "left", False, 1.0)
            elif small and name in ("C", "C_Polarized"):
                fields["Reference"] = ((x + 2.54, y - 1.27), (0, "left"), False)
                fields["Value"] = ((x + 2.54, y + 1.27), (0, "left"), False)
                rv = (x + 2.54, y + 3.556, 0, "left", False, 1.0)
            elif small:
                rv = (vx, vy + 2.54, 0, fields["Value"][1][1], False, 1.0)
            elif len([p for p in pins if p[0] == unit]) == 3:          # porta lógica
                rv = (x, y + 5.08, 0, None, False, 1.0)
            else:                                                     # CI: do lado de fora dos campos
                ys = [fields["Reference"][0][1], vy]
                rv = (vx, min(ys) - 2.54 if vy_lib > 0 else max(ys) + 2.54, 0, fields["Value"][1][1], False, 1.0)
            extra_props = [("Revista", ("rev. " + revista) if unit == units[0][0] else "", rv[0], rv[1], rv[2],
                            rv[3], rv[4] or unit != units[0][0], rv[5])]
            syms.append(placed(lib, name, ref, value, fp, unit, x, y, pins=[p[2] for p in upins],
                               fields=fields, extra_props=extra_props))
            for (_u, pname, pnum, px, py, ang) in upins:
                sx, sy = x + px, y - py
                a = math.radians(ang)
                d = (round(math.cos(a)), -round(math.sin(a)))
                outward = (-d[0], -d[1])
                if pnum not in conns:
                    raise SystemExit("pino sem ligação definida: %s.%s (%s)" % (ref, pnum, pname))
                net = conns[pnum]
                if net is None:
                    noconns.append('\t(no_connect\n\t\t(at %s %s)\n\t\t(uuid "%s")\n\t)'
                                   % (fnum(sx), fnum(sy), uid(sh["file"], "nc", ref, pnum)))
                    continue
                all_pins.setdefault(net, []).append(("%s.%s" % (ref, pnum), pname, sh["name"]))
                stub = 2.54
                ex, ey = sx + outward[0] * stub, sy + outward[1] * stub
                wire(sx, sy, ex, ey, "%s.%s" % (ref, pnum))
                if net in POWER_NETS and outward[0] == 0:
                    power_symbol(net, ex, ey, outward, "%s.%s" % (ref, pnum))
                else:
                    rot = {(1, 0): 0, (-1, 0): 180, (0, -1): 90, (0, 1): 270}[outward]
                    label(net, ex, ey, rot, "%s.%s" % (ref, pnum))

    # PWR_FLAG na folha onde a rede tem pinos de verdade (senão o KiCad acusa pino solto)
    for net, x, y in sh.get("flags", []):
        if True:
            need("power", "PWR_FLAG")
            k = "flag_" + net
            flag_count[0] += 1
            blk = placed("power", "PWR_FLAG", "#FLG%02d" % flag_count[0], "PWR_FLAG", "", 1, x, y, pins=("1",), key=k,
                         fields={"Reference": ((x, y - 2.54), (0, None), True),
                                 "Value": ((x, y - 3.81), (0, None), False)}, power=True)
            extra.append(blk)
            wire(x, y, x, y + 5.08, k)
            power_symbol(net, x, y + 5.08, (0, 1), k)       # todos apontam para baixo, longe da bandeira

    out = ['(kicad_sch', '\t(version 20260101)', '\t(generator "eeschema")', '\t(generator_version "10.0")',
           '\t(uuid "%s")' % uid("file", sh["file"]), '\t(paper "A3")', title_block(sh["title"], sh["page"]),
           '\t(lib_symbols']
    for lib, name in used:
        blk = flatten(lib, name)
        out.append("\n".join("\t\t" + ln if ln.strip() else ln for ln in blk.split("\n")))
    out.append('\t)')
    out += text_blocks(sh["notes"], sh["file"])
    out += wires + labels + noconns + syms + extra
    out += ['\t(embedded_fonts no)', ')']
    return "\n".join(out) + "\n"


def title_block(title, page):
    return ('\t(title_block\n\t\t(title "VET 3000 - placa principal: %s")\n\t\t(date "%s")\n\t\t(rev "0.1")\n'
            '\t\t(company "Leonardo Roman da Rosa")\n'
            '\t\t(comment 1 "Copyright (C) 2026 Leonardo Roman da Rosa - CERN-OHL-S-2.0")\n'
            '\t\t(comment 2 "Source location: https://github.com/lrrosa/vet3000")\n'
            '\t\t(comment 3 "Esquema aproximado: medidas no aparelho + Radio-Electronics 1985-86")\n'
            '\t\t(comment 4 "Gerado por hardware/placa-principal/gen/gen_esquema.py")\n\t)' % (title, DATE))


def text_blocks(notes, key):
    return ['\t(text "%s"\n\t\t(exclude_from_sim no)\n\t\t(at %s %s 0)\n%s\n\t\t(uuid "%s")\n\t)'
            % (t, fnum(x), fnum(y), effects(size=size, justify="left top", indent="\t\t"), uid(key, "t", x, y))
            for x, y, size, t in notes]


def root_sheet(sheet_uuids):
    out = ['(kicad_sch', '\t(version 20260101)', '\t(generator "eeschema")', '\t(generator_version "10.0")',
           '\t(uuid "%s")' % ROOT_UUID, '\t(paper "A3")', title_block("visão geral", "1"), '\t(lib_symbols\n\t)']
    notes = [
        (25.4, 20.32, 2.5, "VET 3000 - placa principal (VET 30 VS1 REV. 2): esquema aproximado"),
        (25.4, 29.21, 1.27,
         "Primeira versão: parte digital. A parte analógica (PLL, sincronismo, croma, mixer) ainda é um bloco.\\n"
         "O circuito junta as medidas de continuidade feitas no aparelho com o \\\"Build This Video Titler\\\"\\n"
         "(Radio-Electronics, nov./1985 a mar./1986), de onde o VET deriva (docs/origem.md)."),
        (25.4, 45.72, 1.27,
         "Cores das redes (classes de rede do projeto, com fios mais grossos):\\n"
         "  azul = todas as ligações da rede foram medidas no aparelho;\\n"
         "  roxo = parte das ligações medida, o resto segue a revista;\\n"
         "  cor padrão (rótulo vermelho-escuro, fio fino) = segundo a revista, ainda a medir.\\n"
         "O roteiro ligação a ligação está em continuidade.md."),
        (25.4, 71.12, 1.27,
         "Referências: U14, U15, U16, U21, U22, U23, D8, D10, D11, R26-R30, R48, R49 e R52-R59 foram lidas na\\n"
         "placa (fotos). U101-U104, T101, C101-C114, R103-R105, CN2 e #BLK1 são provisórias: as da placa\\n"
         "não aparecem nas fotos. O campo \\\"rev.\\\" de cada peça dá o equivalente na revista."),
        (25.4, 91.44, 1.27,
         "Diferenças já conhecidas em relação à revista: EPROM 27128 (16 KB em $C000); /IRQ no CN1 e /NMI\\n"
         "em +5 V; CN1 de 2x18 com -5 V e +3 V BAT; teclado de membrana com 7 linhas; fonte em placa\\n"
         "separada; U19 = CA3126 com a marcação raspada; /INT do VDP sem ligação (como na revista)."),
    ]
    out += text_blocks(notes, "root")
    x0, y0, w_, h_ = 228.6, 40.64, 71.12, 22.86
    for i, sh in enumerate(SHEETS):
        x = x0 + (i % 2) * (w_ + 17.78)
        y = y0 + (i // 2) * (h_ + 20.32)
        u = sheet_uuids[sh["file"]]
        out.append('\t(sheet\n\t\t(at %s %s)\n\t\t(size %s %s)\n\t\t(exclude_from_sim no)\n\t\t(in_bom yes)\n'
                   '\t\t(on_board yes)\n\t\t(dnp no)\n\t\t(stroke\n\t\t\t(width 0)\n\t\t\t(type solid)\n\t\t)\n'
                   '\t\t(fill\n\t\t\t(color 0 0 0 0.0000)\n\t\t)\n\t\t(uuid "%s")\n'
                   '\t\t(property "Sheetname" "%s"\n\t\t\t(at %s %s 0)\n%s\n\t\t)\n'
                   '\t\t(property "Sheetfile" "%s"\n\t\t\t(at %s %s 0)\n%s\n\t\t)\n'
                   '\t\t(instances\n\t\t\t(project "%s"\n\t\t\t\t(path "/%s"\n\t\t\t\t\t(page "%s")\n'
                   '\t\t\t\t)\n\t\t\t)\n\t\t)\n\t)'
                   % (fnum(x), fnum(y), fnum(w_), fnum(h_), u, sh["name"], fnum(x), fnum(y - 0.76),
                      effects(size=1.524, justify="left bottom", indent="\t\t\t"), sh["file"], fnum(x),
                      fnum(y + h_ + 0.76), effects(size=1.27, justify="left top", indent="\t\t\t"),
                      PROJECT, ROOT_UUID, sh["page"]))
    out += ['\t(sheet_instances\n\t\t(path "/"\n\t\t\t(page "1")\n\t\t)\n\t)', '\t(embedded_fonts no)', ')']
    return "\n".join(out) + "\n"


def net_status(net):
    pins = [p for p, _n, _s in all_pins[net]]
    m = [p for p in pins if p in MEASURED]
    if not m:
        return "revista"
    return "medido" if len(m) == len(pins) else "parcial"


def write_project():
    d = json.load(open(TEMPLATE, encoding="utf-8"))
    d["meta"]["filename"] = PROJECT + ".kicad_pro"
    ns = d.setdefault("net_settings", {})
    ns["meta"] = {"version": 5}
    base = {"bus_width": 12, "clearance": 0.2, "diff_pair_gap": 0.25, "diff_pair_via_gap": 0.25,
            "diff_pair_width": 0.2, "line_style": 0, "microvia_diameter": 0.3, "microvia_drill": 0.1,
            "name": "Default", "pcb_color": "rgba(0, 0, 0, 0.000)", "priority": 2147483647,
            "schematic_color": "rgba(0, 0, 0, 0.000)", "track_width": 0.25, "tuning_profile": "",
            "via_diameter": 0.8, "via_drill": 0.4, "wire_width": 6}

    def cls(name, color, prio):
        c = dict(base)
        c.update({"name": name, "schematic_color": color, "priority": prio, "wire_width": 12})
        return c

    # azul = rede toda medida; roxo = parte medida; cor padrão do KiCad (fio verde fino) = segundo a revista
    ns["classes"] = [base, cls("Medido", "rgba(0, 80, 230, 1.000)", 0), cls("Parcial", "rgba(170, 0, 170, 1.000)", 1)]
    ns["net_colors"] = None
    ns["netclass_assignments"] = None
    pats = []
    for net in sorted(all_pins):
        if net in POWER_NETS:
            continue
        st = net_status(net)
        if st == "revista":
            continue
        pattern = net
        pats.append({"netclass": "Medido" if st == "medido" else "Parcial", "pattern": pattern})
    ns["netclass_patterns"] = pats
    sch = d.setdefault("schematic", {})
    erc = d.setdefault("erc", {}).setdefault("rule_severities", {})
    # portas b/c de U23 ficam na parte analógica, ainda não desenhada: reativar quando ela existir
    erc["missing_unit"] = "ignore"
    erc["missing_input_pin"] = "ignore"
    d["sheets"] = [[ROOT_UUID, "Root"]] + [[uid("sheet", sh["file"]), sh["name"]] for sh in SHEETS]
    json.dump(d, open(os.path.join(OUTDIR, PROJECT + ".kicad_pro"), "w", encoding="utf-8", newline="\n"), indent=2)


def pin_text(name):
    """~{CS} -> /CS e R/~{W} -> R/W, para o Markdown."""
    return re.sub(r"(/?)~\{([^}]*)\}", lambda m: (m.group(1) or "/") + m.group(2), name)


def write_checklist():
    L = ["# Roteiro de continuidade da placa principal", "",
         "Gerado por `gen/gen_esquema.py`. Cada rede lista os pinos ligados a ela no esquema. **✓** = ligação",
         "medida no aparelho; **·** = tirada da revista, ainda a medir. Pinos de U101-U104 (6809, EPROM,",
         "RAM e VDP) usam a numeração do CI; as referências provisórias estão explicadas no",
         "[README](README.md).", "",
         "| Rede | Situação | Pinos |", "|---|---|---|"]
    order = {"medido": 0, "parcial": 1, "revista": 2}

    def natkey(n):
        return [int(t) if t.isdigit() else t for t in re.split(r"(\d+)", n)]
    for net in sorted((n for n in all_pins if n not in POWER_NETS), key=lambda n: (order[net_status(n)], natkey(n))):
        pins = sorted(all_pins[net], key=lambda p: natkey(p[0]))
        cells = ", ".join("%s %s%s" % ("✓" if p in MEASURED else "·", p, " (%s)" % pin_text(pn)
                                        if pn and not pn.startswith("Pin_") else "") for p, pn, _s in pins)
        L.append("| `%s` | %s | %s |" % (net, net_status(net), cells))
    L += ["", "## Alimentação", "", "| Rede | Pinos medidos | Pinos segundo a revista |", "|---|---|---|"]
    for net in POWER_NETS:
        if net not in all_pins:
            continue
        pins = sorted(all_pins[net], key=lambda p: natkey(p[0]))
        m = [p for p, _n, _s in pins if p in MEASURED]
        r = [p for p, _n, _s in pins if p not in MEASURED]
        L.append("| `%s` | %s | %s |" % (net, ", ".join(m) or "—", ", ".join(r) or "—"))
    L += ["", "## Ausência de ligação medida", ""]
    for a, b, txt in NOT_CONNECTED_MEASURED:
        L.append("- %s × %s: %s." % (a, b, txt))
    L += ["", "## Peças", "", "| Ref. | Valor | Revista | Referência | Folha |", "|---|---|---|---|---|"]
    orig = {"foto": "lida na placa", "prov": "provisória"}
    for ref, value, revista, origem, sheet in sorted(components, key=lambda c: natkey(c[0])):
        L.append("| %s | %s | %s | %s | %s |" % (ref, value, revista, orig[origem], sheet))
    open(os.path.join(OUTDIR, "continuidade.md"), "w", encoding="utf-8", newline="\n").write("\n".join(L) + "\n")


def main():
    open(os.path.join(OUTDIR, MYLIB + ".kicad_sym"), "w", encoding="utf-8", newline="\n").write(MYLIB_TEXT)
    open(os.path.join(OUTDIR, "sym-lib-table"), "w", encoding="utf-8", newline="\n").write(
        '(sym_lib_table\n  (version 7)\n  (lib (name "%s")(type "KiCad")(uri "${KIPRJMOD}/%s.kicad_sym")'
        '(options "")(descr "Símbolos da placa principal do VET 3000"))\n)\n' % (MYLIB, MYLIB))
    sheet_uuids = {sh["file"]: uid("sheet", sh["file"]) for sh in SHEETS}
    for sh in SHEETS:
        txt = build_sheet(sh, sheet_uuids[sh["file"]])
        open(os.path.join(OUTDIR, sh["file"]), "w", encoding="utf-8", newline="\n").write(txt)
    open(os.path.join(OUTDIR, PROJECT + ".kicad_sch"), "w", encoding="utf-8", newline="\n").write(root_sheet(sheet_uuids))
    write_project()
    write_checklist()
    for net in sorted(all_pins):
        if len(all_pins[net]) < 2 and net not in POWER_NETS:
            print("AVISO: rede com um só pino:", net, all_pins[net])
    st = {}
    for net in all_pins:
        if net not in POWER_NETS:
            st[net_status(net)] = st.get(net_status(net), 0) + 1
    print("redes:", st, "| peças:", len(components), "| globais:", len(GLOBAL))


if __name__ == "__main__":
    main()
