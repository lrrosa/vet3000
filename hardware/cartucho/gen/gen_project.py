#!/usr/bin/env python3
# Copyright (C) 2026 Leonardo Roman da Rosa
# SPDX-License-Identifier: GPL-3.0-or-later
# Software livre sob a GNU GPL versão 3 ou (a seu critério) posterior; veja LICENSE.
#
"""Cria vet3000_cartucho.kicad_pro (a partir do modelo do KiCad) e a fp-lib-table do projeto.

Classes de rede (espelhadas no DSN do Freerouting):
  Default: trilha 0,25 mm, isolação 0,20 mm, via 0,8/0,4 mm
  Power (+5V, GND): trilha 0,60 mm
"""
import json
import os
import sys

TEMPLATE = sys.argv[1] if len(sys.argv) > 1 else \
    r"C:/Program Files/KiCad/10.0/share/kicad/template/kicad.kicad_pro"
HERE = os.path.dirname(os.path.abspath(__file__))
PRJ = os.path.join(HERE, "..", "vet3000_cartucho.kicad_pro")

d = json.load(open(TEMPLATE, encoding="utf-8"))
d.setdefault("net_settings", {}).setdefault("meta", {"version": 5})
base = {"bus_width": 12, "clearance": 0.2, "diff_pair_gap": 0.25, "diff_pair_via_gap": 0.25,
        "diff_pair_width": 0.2, "line_style": 0, "microvia_diameter": 0.3, "microvia_drill": 0.1,
        "name": "Default", "pcb_color": "rgba(0, 0, 0, 0.000)", "priority": 2147483647,
        "schematic_color": "rgba(0, 0, 0, 0.000)", "track_width": 0.3, "tuning_profile": "",
        "via_diameter": 0.8, "via_drill": 0.4, "wire_width": 6}


def netclass(name, track, clearance, prio):
    c = dict(base)
    c.update({"name": name, "track_width": track, "clearance": clearance, "via_diameter": 0.8,
              "via_drill": 0.4, "priority": prio})
    return c


d["net_settings"]["classes"] = [netclass("Default", 0.25, 0.2, 2147483647), netclass("Power", 0.6, 0.2, 0)]
d["net_settings"]["netclass_patterns"] = [{"netclass": "Power", "pattern": "+5V"},
                                          {"netclass": "Power", "pattern": "GND"}]
d["meta"]["filename"] = "vet3000_cartucho.kicad_pro"
rules = d.setdefault("board", {}).setdefault("design_settings", {}).setdefault("rules", {})
rules.update({"min_clearance": 0.2, "min_track_width": 0.25, "min_copper_edge_clearance": 0.5,
              "min_via_diameter": 0.6, "min_through_hole_diameter": 0.3, "min_hole_to_hole": 0.25})
sev = d["board"]["design_settings"].setdefault("rule_severities", {})
sev["starved_thermal"] = "warning"
sev["lib_footprint_mismatch"] = "ignore"
d["board"]["design_settings"].setdefault("defaults", {})["zones"] = {"min_clearance": 0.3}
json.dump(d, open(PRJ, "w", encoding="utf-8", newline="\n"), indent=2)
open(os.path.join(HERE, "..", "fp-lib-table"), "w", encoding="utf-8", newline="\n").write(
    '(fp_lib_table\n  (version 7)\n  (lib (name "vet3000")(type "KiCad")(uri "${KIPRJMOD}/vet3000.pretty")'
    '(options "")(descr "Footprints do cartucho do VET 3000"))\n)\n')
print("projeto:", os.path.abspath(PRJ))
