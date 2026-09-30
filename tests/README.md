# Regression tests

From the repository root:

```sh
python -m unittest discover -s tests -v
```

Checks truncated hints, data boundaries, incomplete words, and relative references
outside the ROM. Full firmware verification is in `disasm/verify.sh` (requires asm6809).

After assembling the cartridge with `cartridge/demo/build.sh` or `build.ps1`:

```sh
python tests/run_mame.py /path/to/mame
```

Runs 515 cases in headless MAME: HUD digits across 256 levels, brick collisions at
both walls, the level-complete score, and 256 animation states compared with the
Python preview. Tests isolate routines by overriding the level transition's wait
and next-screen jump in emulator memory. The cartridge file is unchanged.

Use `--cart` and `--symbols` for another build, with matching asm6809 symbols.
Lua failures, timeouts, or a missing success marker cause a nonzero exit status.

## Arcade campaign and persistent top ten (demo 1.4)

```sh
python tests/run_mame.py /path/to/vet.exe --native-cart --breakout
python tests/run_breakout_persistence.py /path/to/vet.exe
python tests/run_attract.py /path/to/vet.exe
```

The first command includes 160 additional cases (675 total): all 32 compressed maps and
their rendered tiles, silver/gold collisions, six powerups, laser, catch, exit gate,
final boss damage/cooldown/attacks, campaign completion, score limits, top-ten storage
all four shifts of the compact scroller font, all 26 physical letter keys,
alternating launches and left/right paddle rebounds.
The second uses the actual keyboard UI to enter ABC, returns through the titler,
checks every text/attribute byte against nonuniform sentinel data, monitors stack use,
then exercises phase transitions, laser input, boss entry and victory before restarting
MAME with the same NVRAM and checking the record again. It uses isolated
temporary NVRAM; snapshots remain in `cartridge/demo/build/breakout-snapshots`.
The Python suite also checks that all 32 maps are distinct and that gold does not
seal any destructible cell away from the paddle side of the field.
The attract test runs complete scroller/CPU/ranking/title cycles without shortening
timers, verifies that CPU scores do not change NVRAM, and starts a fresh game with
SPACE from both CPU gameplay and the timed ranking.

## Patched MAME driver

```sh
python tests/run_native_mame.py /path/to/vet.exe
python tests/run_mame.py /path/to/vet.exe --native-cart
```

The first test boots with and without a cartridge using temporary configuration
and NVRAM. It checks all 16,384 slot bytes, approximately 59.923 Hz refresh, and
240 frames of execution without cartridge read taps.

The second runs all 515 cases through `-cart`, overriding only the instructions
needed to isolate the level transition.
