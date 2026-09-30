"""Full idle cycles at normal emulated timing, with CPU/ranking SPACE takeover."""
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT=Path(__file__).resolve().parents[1]

def main():
    parser=argparse.ArgumentParser(__doc__)
    parser.add_argument("mame",type=Path)
    args=parser.parse_args()
    build=ROOT/"cartridge/demo/build"
    for ranking in (False,True):
        with tempfile.TemporaryDirectory(prefix="attract-",dir=build) as directory:
            work=Path(directory)
            roms=work/"roms/vet3000"
            roms.mkdir(parents=True)
            shutil.copyfile(ROOT/"rom/VET2.1-TMS_VET3000_27128A.BIN",roms/"vet2.1-tms_vet3000_27128a.bin")
            env=dict(os.environ,VET_TEST_SYM=str(build/"vet3000_demo.sym"),VET_ATTRACT_RANKING=str(int(ranking)))
            result=subprocess.run([str(args.mame.resolve()),"vet3000","-noreadconfig","-cart",str(build/"vet3000_demo.bin"),
                "-rompath",str(roms.parent),"-nvram_directory",str(work/"nvram"),"-cfg_directory",str(work/"cfg"),
                "-video","none","-sound","none","-nothrottle","-skip_gameinfo","-autoboot_delay","0",
                "-autoboot_script",str(ROOT/"tests/attract_cycle.lua"),"-seconds_to_run","180"],
                env=env,cwd=work,capture_output=True,text=True,timeout=90)
            print(result.stdout,end=""); print(result.stderr,end="")
            if result.returncode or "PASS:" not in result.stdout or "FAIL:" in result.stdout or "LUA ERROR" in result.stdout+result.stderr:
                raise SystemExit(1)

if __name__=="__main__":
    main()
