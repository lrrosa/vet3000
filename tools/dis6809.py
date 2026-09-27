#!/usr/bin/env python3
# Copyright (C) 2026 Leonardo Roman da Rosa
# SPDX-License-Identifier: GPL-3.0-or-later
# Software livre sob a GNU GPL versão 3 ou (a seu critério) posterior; veja LICENSE.
#
"""Tracing 6809 disassembler that emits asm6809-compatible, re-assemblable source.

Usage:
    python dis6809.py ROM.BIN --base 0xC000 --hints hints.py -o out.asm

The hints file is a Python module that may define:
    ENTRY      list of extra code entry points
    LABELS     {addr: "name"}              names for code/data/RAM/IO addresses
    COMMENTS   {addr: "text"}              end-of-line comments
    BLOCK_COMMENTS {addr: "text"}          comment block printed before the line
    DATA       [(addr, length, kind), ...] kind: "fcb", "fdb", "fcc", "ptr" (fdb w/ labels),
                                           "jmptab" (fdb code pointers, traced),
                                           "selfrel" (fdb offsets relative to the entry, traced)
    INLINE     {routine: kind}             bytes that follow a JSR/BSR to routine:
                                           "asciz" (0-terminated), "ptr" (2-byte ptr), int n
    NORETURN   set of routines that never return to the caller
    COVERAGE   path to a file with executed PCs (one hex addr per line) from an emulator trace
"""
import argparse
import importlib.util
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from m6809 import (PAGES, INH, IMM8, IMM16, DIR, EXT, IDX, REL8, REL16, REGS, PAIR,  # noqa: E402
                   IDX_REGS, PAIR_REGS, STACK_BITS_S, STACK_BITS_U)


def s8(v):
    return v - 0x100 if v & 0x80 else v


def s16(v):
    return v - 0x10000 if v & 0x8000 else v


def hexs(v, digits=2):
    return "$%0*X" % (digits, v)


class Insn:
    __slots__ = ("addr", "size", "mn", "mode", "ops", "target", "ref", "flow", "idx")

    def __init__(self):
        self.addr = 0
        self.size = 0
        self.mn = ""
        self.mode = INH
        self.ops = ""        # operand text with {REF} placeholder for symbolic address
        self.target = None   # branch/jump/call target (code)
        self.ref = None      # data address referenced (for labelling)
        self.flow = "next"   # next | stop | branch | call | jump
        self.idx = None      # indexed-mode info dict


class Disassembler:
    def __init__(self, rom, base, hints=None):
        self.rom = rom
        self.base = base
        self.end = base + len(rom)
        self.hints = hints
        self.kind = {}        # addr -> "code" | "codecont" | "data"
        self.insns = {}       # addr -> Insn
        self.data = {}        # addr -> (length, kind)
        self.labels = dict(getattr(hints, "LABELS", {}) or {})
        self.comments = dict(getattr(hints, "COMMENTS", {}) or {})
        self.block_comments = dict(getattr(hints, "BLOCK_COMMENTS", {}) or {})
        self.inline = dict(getattr(hints, "INLINE", {}) or {})
        self.noreturn = set(getattr(hints, "NORETURN", set()) or set())
        self.code_refs = set()    # addresses that need a code label
        self.data_refs = set()    # addresses referenced as data
        self.xrefs = {}           # target -> set(from)
        self.conflicts = []

    # ------------------------------------------------------------------ helpers
    def inrom(self, a):
        return self.base <= a < self.end

    def byte(self, a):
        return self.rom[a - self.base]

    def word(self, a):
        return (self.byte(a) << 8) | self.byte(a + 1)

    # ------------------------------------------------------------------ decoding
    def decode(self, addr):
        if not self.inrom(addr):
            return None
        ins = Insn()
        ins.addr = addr
        p = addr
        op = self.byte(p)
        p += 1
        prefix = None
        if op in (0x10, 0x11):
            prefix = op
            if not self.inrom(p):
                return None
            op = self.byte(p)
            p += 1
        table = PAGES[prefix]
        if op not in table:
            return None
        mn, mode, _cyc = table[op]
        ins.mn, ins.mode = mn, mode
        try:
            if mode == INH:
                pass
            elif mode == IMM8:
                ins.ops = "#" + hexs(self.byte(p))
                p += 1
            elif mode == IMM16:
                v = self.word(p)
                p += 2
                ins.ops = "#{REF}"
                ins.ref = v
            elif mode == DIR:
                v = self.byte(p)
                p += 1
                ins.ops = "<{REF}"
                ins.ref = v  # DP assumed 0 (checked in hints)
                if mn == "JMP":
                    ins.flow, ins.target = "jump", v
                elif mn == "JSR":
                    ins.flow, ins.target = "call", v
            elif mode == EXT:
                v = self.word(p)
                p += 2
                ins.ref = v
                ins.ops = ">{REF}" if v < 0x100 else "{REF}"
                if mn == "JMP":
                    ins.flow, ins.target = "jump", v
                elif mn == "JSR":
                    ins.flow, ins.target = "call", v
            elif mode in (REL8, REL16):
                if mode == REL8:
                    off = s8(self.byte(p))
                    p += 1
                else:
                    off = s16(self.word(p))
                    p += 2
                t = (p + off) & 0xFFFF
                ins.ops = "{REF}"
                ins.ref = t
                ins.target = t
                if mn in ("BRA", "LBRA"):
                    ins.flow = "jump"
                elif mn in ("BSR", "LBSR"):
                    ins.flow = "call"
                elif mn in ("BRN", "LBRN"):
                    ins.flow = "next"
                else:
                    ins.flow = "branch"
            elif mode == REGS:
                m = self.byte(p)
                p += 1
                names = STACK_BITS_U if mn in ("PSHU", "PULU") else STACK_BITS_S
                regs = [names[i] for i in range(8) if m & (1 << i)]
                if not regs:
                    return None
                ins.ops = ",".join(regs)
                if mn in ("PULS", "PULU") and m & 0x80:
                    ins.flow = "stop"
            elif mode == PAIR:
                m = self.byte(p)
                p += 1
                r1, r2 = PAIR_REGS.get(m >> 4), PAIR_REGS.get(m & 15)
                if r1 is None or r2 is None:
                    return None
                ins.ops = "%s,%s" % (r1, r2)
                if r2 == "PC" or (mn == "EXG" and r1 == "PC"):
                    ins.flow = "stop"
            elif mode == IDX:
                p = self.decode_idx(ins, p)
                if p is None:
                    return None
                if mn == "JMP":
                    ins.flow = "stop"
                elif mn == "JSR":
                    ins.flow = "next"
        except IndexError:
            return None
        if mn in ("RTS", "RTI"):
            ins.flow = "stop"
        if p > self.end:
            return None
        ins.size = p - addr
        return ins

    def decode_idx(self, ins, p):
        pb = self.byte(p)
        p += 1
        reg = IDX_REGS[(pb >> 5) & 3]
        if not pb & 0x80:
            off = pb & 0x1F
            if off & 0x10:
                off -= 0x20
            # 5-bit form; a zero offset would normally be encoded as ,R so force it
            ins.ops = ("<<%d,%s" if off == 0 else "%d,%s") % (off, reg)
            return p
        ind = bool(pb & 0x10)
        t = pb & 0x0F
        body = None
        if t == 0x0 and not ind:
            body = ",%s+" % reg
        elif t == 0x1:
            body = ",%s++" % reg
        elif t == 0x2 and not ind:
            body = ",-%s" % reg
        elif t == 0x3:
            body = ",--%s" % reg
        elif t == 0x4:
            body = ",%s" % reg
        elif t == 0x5:
            body = "B,%s" % reg
        elif t == 0x6:
            body = "A,%s" % reg
        elif t == 0xB:
            body = "D,%s" % reg
        elif t == 0x8:
            off = s8(self.byte(p))
            p += 1
            # 8-bit form: force with '<' when a 5-bit form (or none) would fit
            force = "<" if (-16 <= off <= 15 and not ind) or (off == 0) else ""
            body = "%s%d,%s" % (force, off, reg)
        elif t == 0x9:
            off = s16(self.word(p))
            p += 2
            force = ">" if -128 <= off <= 127 or (not ind and -16 <= off <= 15) else ""
            body = "%s%d,%s" % (force, off, reg)
            if off >= 0x100 or off < -0x100:
                # likely a table base address: make it symbolic when unsigned >= $C000
                u = off & 0xFFFF
                ins.ref = u
                body = "%s{REF},%s" % (force, reg)
        elif t == 0xC:
            off = s8(self.byte(p))
            p += 1
            tgt = (p + off) & 0xFFFF
            ins.ref = tgt
            body = "<{REF},PCR"
        elif t == 0xD:
            off = s16(self.word(p))
            p += 2
            tgt = (p + off) & 0xFFFF
            ins.ref = tgt
            force = ">" if -128 <= off <= 127 else ""
            body = "%s{REF},PCR" % force
        elif t == 0xF and ind and reg == "X":
            v = self.word(p)
            p += 2
            ins.ref = v
            body = "{REF}"
            if v < 0x100:
                body = ">{REF}"
        else:
            return None
        ins.ops = "[%s]" % body if ind else body
        return p

    # ------------------------------------------------------------------ tracing
    def mark_data(self, addr, length, kind):
        self.data[addr] = (length, kind)
        for a in range(addr, addr + length):
            if self.kind.get(a) in ("code", "codecont"):
                self.conflicts.append((a, "data over code"))
            self.kind[a] = "data"
        if kind == "selfrel":
            for a in range(addr, addr + length, 2):
                v = self.word(a)
                if v:
                    t = (a + v) & 0xFFFF
                    self.pending.append(t)
                    self.code_refs.add(t)
        if kind in ("ptr", "jmptab"):
            for a in range(addr, addr + length, 2):
                v = self.word(a)
                if kind == "jmptab":
                    self.pending.append(v)
                    self.code_refs.add(v)
                elif self.inrom(v):
                    self.data_refs.add(v)

    def trace(self, entries):
        self.pending = list(entries)
        for addr, length, kind in getattr(self.hints, "DATA", []) or []:
            self.mark_data(addr, length, kind)
        while self.pending:
            a = self.pending.pop()
            while self.inrom(a):
                k = self.kind.get(a)
                if k == "code":
                    break
                if k in ("codecont", "data"):
                    self.conflicts.append((a, "jump into %s" % k))
                    break
                ins = self.decode(a)
                if ins is None:
                    self.conflicts.append((a, "invalid opcode"))
                    break
                # overlapping check
                if any(self.kind.get(a + i) for i in range(1, ins.size)):
                    self.conflicts.append((a, "overlap"))
                    break
                self.insns[a] = ins
                self.kind[a] = "code"
                for i in range(1, ins.size):
                    self.kind[a + i] = "codecont"
                if ins.target is not None:
                    self.xrefs.setdefault(ins.target, set()).add(a)
                    if self.inrom(ins.target):
                        self.code_refs.add(ins.target)
                        self.pending.append(ins.target)
                if ins.ref is not None and ins.target is None and self.inrom(ins.ref):
                    self.data_refs.add(ins.ref)
                nxt = a + ins.size
                if ins.flow == "call" and ins.target in self.inline:
                    spec = self.inline[ins.target]
                    n = self.inline_len(nxt, spec)
                    kind = "fcc" if spec == "asciz" else ("ptr" if spec == "ptr" else "fcb")
                    self.mark_data(nxt, n, kind)
                    nxt += n
                if ins.flow in ("stop", "jump"):
                    break
                if ins.flow == "call" and ins.target in self.noreturn:
                    break
                a = nxt

    def inline_len(self, a, spec):
        if spec == "asciz":
            n = 0
            while self.byte(a + n) != 0:
                n += 1
            return n + 1
        if spec == "ptr":
            return 2
        return int(spec)

    # ------------------------------------------------------------------ segments / naming
    def build_segments(self):
        """Split the ROM into output lines: instructions and data spans."""
        self.segs = []            # (addr, length, kind, dk)
        self.seg_at = {}          # any addr -> segment start
        a = self.base
        while a < self.end:
            k = self.kind.get(a)
            if k == "code":
                ins = self.insns[a]
                seg = (a, ins.size, "code", None)
            elif a in self.data:
                length, dk = self.data[a]
                seg = (a, length, "data", dk)
            else:
                length, dk = self.auto_span(a)
                seg = (a, length, "data", dk)
            self.segs.append(seg)
            for i in range(seg[1]):
                self.seg_at[a + i] = a
            a += seg[1]
        self.need_label = set()

    def base_name(self, s):
        if s in self.labels:
            return self.labels[s]
        return ("L%04X" if self.kind.get(s) == "code" else "D%04X") % s

    def name(self, v):
        """Symbolic name for ROM address v (marks the needed label)."""
        if v in self.labels and not self.inrom(v):
            return self.labels[v]
        if not self.inrom(v):
            return None
        s = self.seg_at.get(v, v)
        self.need_label.add(s)
        if s == v:
            return self.base_name(s)
        return "%s+%d" % (self.base_name(s), v - s)

    def sym_ref(self, ins):
        v = ins.ref
        if self.inrom(v):
            return self.name(v)
        if v in self.labels:
            return self.labels[v]
        if ins.mode == DIR:
            return hexs(v, 2)
        return hexs(v, 4)

    # ------------------------------------------------------------------ output
    def emit(self, out):
        self.build_segments()
        # dry run to find every label that is needed, then the real run
        import io
        self.emit_body(io.StringIO())
        body = io.StringIO()
        self.emit_body(body)
        w = out.write
        header = getattr(self.hints, "HEADER", None)
        if header:
            for line in header.strip("\n").split("\n"):
                w(("* " + line).rstrip() + "\n")
            w("\n")
        ext = sorted(a for a in self.labels if not self.inrom(a))
        if ext:
            w("* ---------------------------------------------------------------------------\n")
            w("* Hardware registers and RAM variables\n")
            w("* ---------------------------------------------------------------------------\n")
            for a in ext:
                c = self.comments.get(a)
                line = "%-24s equ   %s" % (self.labels[a], hexs(a, 4))
                if c:
                    line = "%-44s ; %s" % (line, c)
                w(line + "\n")
            w("\n")
        w("\t\torg\t%s\n" % hexs(self.base, 4))
        w(body.getvalue())
        w("\n\t\tend\n")

    def emit_body(self, out):
        w = out.write
        for (a, length, k, dk) in self.segs:
            if a in self.block_comments:
                w("\n")
                for line in self.block_comments[a].strip("\n").split("\n"):
                    w(("* " + line).rstrip() + "\n")
            label = self.base_name(a) if (a in self.need_label or a in self.labels) else None
            if k == "code":
                ins = self.insns[a]
                ops = ins.ops
                if "{REF}" in ops:
                    ops = ops.replace("{REF}", self.sym_ref(ins))
                raw = " ".join("%02X" % self.byte(a + i) for i in range(ins.size))
                self.line(w, label, ins.mn.lower(), ops, a, raw)
            else:
                self.emit_data(w, a, length, dk, label)

    def line(self, w, label, mn, ops, addr, raw):
        c = self.comments.get(addr, "")
        text = "%-15s %-7s %s" % ((label + ":") if label else "", mn, ops)
        text = "%-44s ; %04X  %-14s %s" % (text.rstrip(), addr, raw, c)
        w(text.rstrip() + "\n")

    def boundary(self, a):
        return (a in self.code_refs or a in self.data_refs or a in self.labels
                or a in self.data or a in self.block_comments)

    def auto_span(self, a):
        n = 1
        while (a + n < self.end and self.kind.get(a + n) is None
               and not self.boundary(a + n)):
            n += 1
        return n, "auto"

    def emit_data(self, w, a, length, dk, label):
        if dk == "selfrel":
            for i in range(0, length, 2):
                v = self.word(a + i)
                text = "%s-*" % self.name((a + i + v) & 0xFFFF) if v else "0"
                self.line(w, label if i == 0 else None, "fdb", text, a + i,
                          "%02X %02X" % (self.byte(a + i), self.byte(a + i + 1)))
            return
        if dk in ("fdb", "ptr", "jmptab"):
            for i in range(0, length, 2):
                v = self.word(a + i)
                n = self.name(v) if dk in ("ptr", "jmptab") and self.inrom(v) else None
                self.line(w, label if i == 0 else None, "fdb", n or hexs(v, 4), a + i,
                          "%02X %02X" % (self.byte(a + i), self.byte(a + i + 1)))
            return
        if dk == "fcc":
            self.emit_text(w, a, length, label)
            return
        if dk == "auto":
            b0 = self.byte(a)
            if length >= 8 and all(self.byte(a + i) == b0 for i in range(length)):
                self.line(w, label, "fill", "%s,%d" % (hexs(b0), length), a, "%02X x%d" % (b0, length))
                return
            if self.looks_text(a, length):
                self.emit_text(w, a, length, label)
                return
        for i in range(0, length, 8):
            chunk = [self.byte(a + j) for j in range(i, min(i + 8, length))]
            self.line(w, label if i == 0 else None, "fcb", ",".join(hexs(b) for b in chunk),
                      a + i, " ".join("%02X" % b for b in chunk))

    def looks_text(self, a, length):
        if length < 4:
            return False
        good = sum(1 for i in range(length) if 0x20 <= self.byte(a + i) < 0x7F)
        return good >= length * 0.85

    def emit_text(self, w, a, length, label):
        i = 0
        first = True
        while i < length:
            parts = []
            start = i
            cur = ""
            while i < length and len(cur) + sum(len(p) + 1 for p in parts) < 40:
                b = self.byte(a + i)
                if 0x20 <= b < 0x7F and b not in (0x22, 0x3B):
                    cur += chr(b)
                else:
                    if cur:
                        parts.append('"%s"' % cur)
                        cur = ""
                    parts.append(hexs(b))
                i += 1
            if cur:
                parts.append('"%s"' % cur)
            self.line(w, label if first else None, "fcc", ",".join(parts), a + start,
                      " ".join("%02X" % self.byte(a + j) for j in range(start, min(start + 4, i)))
                      + (" .." if i - start > 4 else ""))
            first = False


def load_hints(path):
    if not path:
        return None
    spec = importlib.util.spec_from_file_location("hints", path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("rom")
    ap.add_argument("--base", type=lambda s: int(s, 0), default=0xC000)
    ap.add_argument("--hints")
    ap.add_argument("-o", "--output")
    ap.add_argument("--report", action="store_true", help="print coverage/conflicts")
    args = ap.parse_args()
    rom = open(args.rom, "rb").read()
    hints = load_hints(args.hints)
    d = Disassembler(rom, args.base, hints)
    end = args.base + len(rom)
    entries = []
    for v in range(0xFFF2, 0x10000, 2):
        if args.base <= v < end:
            t = d.word(v)
            if d.inrom(t):
                entries.append(t)
    entries += list(getattr(hints, "ENTRY", []) or [])
    cov = getattr(hints, "COVERAGE", None)
    if cov and os.path.exists(cov):
        with open(cov) as f:
            entries += [int(x, 16) for x in f.read().split()]
    if end == 0x10000 and args.base <= 0xFFF0:
        d.mark_data(0xFFF0, 16, "ptr")
        d.labels.setdefault(0xFFF0, "VECTORS")
    d.trace(entries)
    out = open(args.output, "w", newline="\n", encoding="utf-8") if args.output else sys.stdout
    d.emit(out)
    if args.report:
        code = sum(1 for k in d.kind.values() if k in ("code", "codecont"))
        data = sum(1 for k in d.kind.values() if k == "data")
        print("code bytes: %d  data bytes: %d  unknown: %d" % (code, data, len(rom) - code - data),
              file=sys.stderr)
        for a, why in sorted(set(d.conflicts)):
            print("conflict %04X: %s" % (a, why), file=sys.stderr)


if __name__ == "__main__":
    main()
