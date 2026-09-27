# Copyright (C) 2026 Leonardo Roman da Rosa
# SPDX-License-Identifier: GPL-3.0-or-later
# Software livre sob a GNU GPL versão 3 ou (a seu critério) posterior; veja LICENSE.
#
"""Motorola 6809 opcode tables shared by the disassembler, assembler and emulator.

Addressing modes:
    INH   inherent                  IMM8  immediate 8-bit     IMM16 immediate 16-bit
    DIR   direct page               EXT   extended            IDX   indexed (postbyte)
    REL8  8-bit relative branch     REL16 16-bit relative     REGS  PSH/PUL register mask
    PAIR  TFR/EXG register pair

Cycle counts are the MC6809 base counts (indexed modes add the postbyte cost,
long conditional branches add 1 when taken, PSH/PUL add 1 per byte moved).
"""

INH, IMM8, IMM16, DIR, EXT, IDX, REL8, REL16, REGS, PAIR = (
    "INH", "IMM8", "IMM16", "DIR", "EXT", "IDX", "REL8", "REL16", "REGS", "PAIR")

PAGE0 = {}  # opcode -> (mnemonic, mode, cycles)
PAGE1 = {}  # prefix $10
PAGE2 = {}  # prefix $11


def _add(table, op, mn, mode, cyc):
    assert op not in table, hex(op)
    table[op] = (mn, mode, cyc)


# --- read-modify-write group: $00 direct, $40 A, $50 B, $60 indexed, $70 extended
_rmw = {0x0: "NEG", 0x3: "COM", 0x4: "LSR", 0x6: "ROR", 0x7: "ASR", 0x8: "ASL",
        0x9: "ROL", 0xA: "DEC", 0xC: "INC", 0xD: "TST", 0xE: "JMP", 0xF: "CLR"}
for lo, mn in _rmw.items():
    if mn == "JMP":
        _add(PAGE0, 0x00 | lo, mn, DIR, 3)
        _add(PAGE0, 0x60 | lo, mn, IDX, 3)
        _add(PAGE0, 0x70 | lo, mn, EXT, 4)
        continue
    _add(PAGE0, 0x00 | lo, mn, DIR, 6)
    _add(PAGE0, 0x60 | lo, mn, IDX, 6)
    _add(PAGE0, 0x70 | lo, mn, EXT, 7)
    _add(PAGE0, 0x40 | lo, mn + "A", INH, 2)
    _add(PAGE0, 0x50 | lo, mn + "B", INH, 2)

for op, mn, mode, cyc in [
        (0x12, "NOP", INH, 2), (0x13, "SYNC", INH, 4), (0x16, "LBRA", REL16, 5),
        (0x17, "LBSR", REL16, 9), (0x19, "DAA", INH, 2), (0x1A, "ORCC", IMM8, 3),
        (0x1C, "ANDCC", IMM8, 3), (0x1D, "SEX", INH, 2), (0x1E, "EXG", PAIR, 8),
        (0x1F, "TFR", PAIR, 6),
        (0x30, "LEAX", IDX, 4), (0x31, "LEAY", IDX, 4), (0x32, "LEAS", IDX, 4),
        (0x33, "LEAU", IDX, 4), (0x34, "PSHS", REGS, 5), (0x35, "PULS", REGS, 5),
        (0x36, "PSHU", REGS, 5), (0x37, "PULU", REGS, 5), (0x39, "RTS", INH, 5),
        (0x3A, "ABX", INH, 3), (0x3B, "RTI", INH, 6), (0x3C, "CWAI", IMM8, 20),
        (0x3D, "MUL", INH, 11), (0x3F, "SWI", INH, 19),
        (0x8D, "BSR", REL8, 7)]:
    _add(PAGE0, op, mn, mode, cyc)

BRANCHES = ["BRA", "BRN", "BHI", "BLS", "BCC", "BCS", "BNE", "BEQ",
            "BVC", "BVS", "BPL", "BMI", "BGE", "BLT", "BGT", "BLE"]
for i, mn in enumerate(BRANCHES):
    _add(PAGE0, 0x20 + i, mn, REL8, 3)
    if i:
        _add(PAGE1, 0x20 + i, "L" + mn, REL16, 5)

# --- accumulator/register groups.  Columns: imm, dir, idx, ext  (None = no such mode)
_acc = {
    # A side ($80-$BF)
    0x80: ("SUBA", 2, 4, 4, 5), 0x81: ("CMPA", 2, 4, 4, 5), 0x82: ("SBCA", 2, 4, 4, 5),
    0x83: ("SUBD", 4, 6, 6, 7), 0x84: ("ANDA", 2, 4, 4, 5), 0x85: ("BITA", 2, 4, 4, 5),
    0x86: ("LDA", 2, 4, 4, 5), 0x87: ("STA", None, 4, 4, 5), 0x88: ("EORA", 2, 4, 4, 5),
    0x89: ("ADCA", 2, 4, 4, 5), 0x8A: ("ORA", 2, 4, 4, 5), 0x8B: ("ADDA", 2, 4, 4, 5),
    0x8C: ("CMPX", 4, 6, 6, 7), 0x8D: ("JSR", None, 7, 7, 8), 0x8E: ("LDX", 3, 5, 5, 6),
    0x8F: ("STX", None, 5, 5, 6),
    # B side ($C0-$FF)
    0xC0: ("SUBB", 2, 4, 4, 5), 0xC1: ("CMPB", 2, 4, 4, 5), 0xC2: ("SBCB", 2, 4, 4, 5),
    0xC3: ("ADDD", 4, 6, 6, 7), 0xC4: ("ANDB", 2, 4, 4, 5), 0xC5: ("BITB", 2, 4, 4, 5),
    0xC6: ("LDB", 2, 4, 4, 5), 0xC7: ("STB", None, 4, 4, 5), 0xC8: ("EORB", 2, 4, 4, 5),
    0xC9: ("ADCB", 2, 4, 4, 5), 0xCA: ("ORB", 2, 4, 4, 5), 0xCB: ("ADDB", 2, 4, 4, 5),
    0xCC: ("LDD", 3, 5, 5, 6), 0xCD: ("STD", None, 5, 5, 6), 0xCE: ("LDU", 3, 5, 5, 6),
    0xCF: ("STU", None, 5, 5, 6),
}
WIDE = {"SUBD", "CMPX", "LDX", "ADDD", "LDD", "LDU", "CMPD", "CMPY", "LDY", "LDS",
        "CMPU", "CMPS"}
for base, (mn, ci, cd, cx, ce) in _acc.items():
    if ci is not None and mn != "JSR":  # $8D is BSR
        _add(PAGE0, base, mn, IMM16 if mn in WIDE else IMM8, ci)
    _add(PAGE0, base + 0x10, mn, DIR, cd)
    _add(PAGE0, base + 0x20, mn, IDX, cx)
    _add(PAGE0, base + 0x30, mn, EXT, ce)

# --- page 1 ($10 prefix)
for op, mn, mode, cyc in [
        (0x3F, "SWI2", INH, 20),
        (0x83, "CMPD", IMM16, 5), (0x8C, "CMPY", IMM16, 5), (0x8E, "LDY", IMM16, 4),
        (0x93, "CMPD", DIR, 7), (0x9C, "CMPY", DIR, 7), (0x9E, "LDY", DIR, 6), (0x9F, "STY", DIR, 6),
        (0xA3, "CMPD", IDX, 7), (0xAC, "CMPY", IDX, 7), (0xAE, "LDY", IDX, 6), (0xAF, "STY", IDX, 6),
        (0xB3, "CMPD", EXT, 8), (0xBC, "CMPY", EXT, 8), (0xBE, "LDY", EXT, 7), (0xBF, "STY", EXT, 7),
        (0xCE, "LDS", IMM16, 4), (0xDE, "LDS", DIR, 6), (0xDF, "STS", DIR, 6),
        (0xEE, "LDS", IDX, 6), (0xEF, "STS", IDX, 6), (0xFE, "LDS", EXT, 7), (0xFF, "STS", EXT, 7)]:
    _add(PAGE1, op, mn, mode, cyc)

# --- page 2 ($11 prefix)
for op, mn, mode, cyc in [
        (0x3F, "SWI3", INH, 20),
        (0x83, "CMPU", IMM16, 5), (0x8C, "CMPS", IMM16, 5),
        (0x93, "CMPU", DIR, 7), (0x9C, "CMPS", DIR, 7),
        (0xA3, "CMPU", IDX, 7), (0xAC, "CMPS", IDX, 7),
        (0xB3, "CMPU", EXT, 8), (0xBC, "CMPS", EXT, 8)]:
    _add(PAGE2, op, mn, mode, cyc)

PAGES = {None: PAGE0, 0x10: PAGE1, 0x11: PAGE2}

IDX_REGS = ["X", "Y", "U", "S"]
PAIR_REGS = {0: "D", 1: "X", 2: "Y", 3: "U", 4: "S", 5: "PC", 8: "A", 9: "B", 0xA: "CC", 0xB: "DP"}
PAIR_CODES = {v: k for k, v in PAIR_REGS.items()}
STACK_BITS_S = ["CC", "A", "B", "DP", "X", "Y", "U", "PC"]   # PSHS/PULS
STACK_BITS_U = ["CC", "A", "B", "DP", "X", "Y", "S", "PC"]   # PSHU/PULU

# extra cycles of each indexed postbyte form (non-indirect, indirect)
IDX_CYCLES = {"5bit": (1, None), "R+": (2, None), "R++": (3, 6), "-R": (2, None),
              "--R": (3, 6), ",R": (0, 3), "B,R": (1, 4), "A,R": (1, 4), "D,R": (4, 7),
              "8,R": (1, 4), "16,R": (4, 7), "8,PCR": (1, 4), "16,PCR": (5, 8),
              "[16]": (None, 5)}

# reverse table for the assembler: (mnemonic, mode) -> opcode bytes
ENCODE = {}
for prefix, table in PAGES.items():
    for op, (mn, mode, _cyc) in table.items():
        ENCODE[(mn, mode)] = bytes([op]) if prefix is None else bytes([prefix, op])

MNEMONICS = {mn for (mn, _mode) in ENCODE}

ALIASES = {"LSL": "ASL", "LSLA": "ASLA", "LSLB": "ASLB", "BHS": "BCC", "BLO": "BCS",
           "LBHS": "LBCC", "LBLO": "LBCS"}
