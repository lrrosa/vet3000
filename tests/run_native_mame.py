"""Test patched MAME's native slot and NTSC timing, with and without the demo."""
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument("mame", type=Path)
    parser.add_argument("--cart", type=Path,
                        default=ROOT / "cartridge/demo/build/vet3000_demo.bin")
    args = parser.parse_args()
    cart = args.cart.resolve()
    if cart.stat().st_size != 16384:
        parser.error("expected a 16 KiB demo cartridge")
    build = ROOT / "cartridge/demo/build"
    build.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="native-mame-", dir=build) as tmp:
        work = Path(tmp)
        roms = work / "roms/vet3000"
        roms.mkdir(parents=True)
        shutil.copyfile(ROOT / "rom/VET2.1-TMS_VET3000_27128A.BIN",
                        roms / "vet2.1-tms_vet3000_27128a.bin")
        for loaded in (False, True):
            mode = "cartridge" if loaded else "empty"
            env = dict(os.environ, VET_NATIVE_CART=str(cart) if loaded else "")
            command = [str(args.mame.resolve()), "vet3000", "-noreadconfig",
                       "-rompath", str(roms.parent), "-video", "none", "-sound", "none",
                       "-nothrottle", "-skip_gameinfo", "-autoboot_delay", "0",
                       "-autoboot_script", str(ROOT / "tests/native_cart.lua"),
                       "-seconds_to_run", "12", "-nvram_directory", str(work / mode / "nvram"),
                       "-cfg_directory", str(work / mode / "cfg")]
            if loaded:
                command += ["-cart", str(cart)]
            result = subprocess.run(command, cwd=work, env=env, capture_output=True,
                                    text=True, timeout=120)
            print(result.stdout, end="")
            print(result.stderr, end="")
            expected = "PASS: native slot " + ("cartridge boot" if loaded else "empty slot boot")
            if (result.returncode or expected not in result.stdout
                    or "FAIL:" in result.stdout or "[LUA ERROR]" in result.stderr + result.stdout):
                raise SystemExit(1)


if __name__ == "__main__":
    main()
