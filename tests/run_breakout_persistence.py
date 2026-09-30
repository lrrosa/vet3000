"""Test real demo input plus battery SRAM across two fresh MAME processes."""
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def main():
    p = argparse.ArgumentParser(__doc__)
    p.add_argument("mame", type=Path)
    args = p.parse_args()
    build = ROOT / "cartridge/demo/build"
    snaps = build / "breakout-snapshots"
    snaps.mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="breakout-", dir=build) as directory:
        work = Path(directory)
        roms = work / "roms/vet3000"
        roms.mkdir(parents=True)
        shutil.copyfile(ROOT / "rom/VET2.1-TMS_VET3000_27128A.BIN", roms / "vet2.1-tms_vet3000_27128a.bin")
        for readback in (False, True):
            env = dict(os.environ, VET_READBACK=str(int(readback)),
                       VET_TEST_SYM=str(build / "vet3000_demo.sym"), VET_SNAP_DIR=str(snaps))
            result = subprocess.run([
                str(args.mame.resolve()), "vet3000", "-noreadconfig", "-cart", str(build / "vet3000_demo.bin"),
                "-rompath", str(roms.parent), "-nvram_directory", str(work / "nvram"),
                "-cfg_directory", str(work / "cfg"), "-video", "none", "-sound", "none",
                "-nothrottle", "-skip_gameinfo", "-autoboot_delay", "0", "-autoboot_script",
                str(ROOT / "tests/breakout_persistence.lua"), "-seconds_to_run", "40",
            ], env=env, cwd=work, capture_output=True, text=True, timeout=90)
            print(result.stdout, end="")
            print(result.stderr, end="")
            if result.returncode or "PASS:" not in result.stdout or "FAIL:" in result.stdout or "LUA ERROR" in result.stdout+result.stderr:
                raise SystemExit(1)


if __name__ == "__main__":
    main()
