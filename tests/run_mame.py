"""Run deterministic cartridge regressions with an existing MAME installation."""
import argparse
import os
import re
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "cartridge/demo"))
import gen_assets


def main():
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument("mame", type=Path)
    parser.add_argument("--native-cart", action="store_true",
                        help="load via patched MAME's -cart slot instead of a Lua read tap")
    parser.add_argument("--breakout", action="store_true", help="also test powerups and SRAM top ten")
    parser.add_argument("--cart", type=Path, default=ROOT / "cartridge/demo/build/vet3000_demo.bin")
    parser.add_argument("--symbols", type=Path, default=ROOT / "cartridge/demo/build/vet3000_demo.sym")
    args = parser.parse_args()
    build = ROOT / "cartridge/demo/build"
    romdir = build / "roms/vet3000"
    romdir.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(ROOT / "rom/VET2.1-TMS_VET3000_27128A.BIN",
                    romdir / "vet2.1-tms_vet3000_27128a.bin")
    bars = build / "test_bars.bin"
    bars.write_bytes(bytes(c for phase in range(256) for c in gen_assets.build_bars(phase)))
    levels = build / "test_levels.bin"
    levels.write_bytes(b"".join(gen_assets.level_bits(rows, chars)
                                for rows in gen_assets.LEVELS for chars in ("S", "G", "#SG")))
    scroll = build / "test_scroll.bin"
    chars = gen_assets.text_index(gen_assets.SCROLL_TEXT)
    scroll.write_bytes(bytes(((gen_assets.FONT[chars[c]][y] << shift) |
                              (gen_assets.FONT[chars[c+1]][y] >> (8-shift))) & 255
                             for shift in (0,2,4,6) for c in range(32) for y in range(8)))
    env = dict(os.environ, VET_CART=str(args.cart.resolve()),
               VET_TEST_SYM=str(args.symbols.resolve()), VET_TEST_BARS=str(bars),
               VET_TEST_NATIVE="1" if args.native_cart else "0",
               VET_TEST_BREAKOUT="1" if args.breakout else "0", VET_TEST_LEVELS=str(levels),
               VET_TEST_SCROLL=str(scroll))
    result = subprocess.run([
        str(args.mame.resolve()), "vet3000", "-rompath", str(romdir.parent),
        "-video", "none", "-sound", "none", "-nothrottle", "-skip_gameinfo",
        "-autoboot_delay", "0", "-autoboot_script", str(ROOT / "tests/demo_regression.lua"),
        "-seconds_to_run", "60", "-nvram_directory", str(build / "nvram"),
        "-cfg_directory", str(build / "cfg"),
    ] + (["-cart", str(args.cart.resolve())] if args.native_cart else []),
        cwd=ROOT, env=env, capture_output=True, text=True, timeout=120)
    print(result.stdout, end="")
    print(result.stderr, end="", file=sys.stderr)
    if result.returncode or not re.search(r"PASS: \d+ MAME regression cases", result.stdout) or "FAIL:" in result.stdout:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
