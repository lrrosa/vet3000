# VET 3000 patch validation

Built on September 27, 2026; final tests completed on September 28, 2026.

Submitted as [MAME PR #16276](https://github.com/mamedev/mame/pull/16276),
commit `60da436390bbd96b523c4d25550f64a1f2176b81`.

- Base: `mamedev/mame` commit `02342fb0547a9a9934d63b5e8708126b7b644007` (0.289).
- Environment: Windows x64, MSYS2 UCRT64, GCC 16.2.0, Make 4.4.1, Python 3.14.7.
- The original patch applied without changes or conflicts.

## Build

```sh
make SUBTARGET=vet SOURCES=src/mame/tms/vet3000.cpp REGENIE=1 -j6
```

The VET 3000 target built successfully. This was a targeted build, not a full
all-drivers build. Existing MAME/library warnings were present; no compiler
diagnostics were reported for `vet3000.cpp`. The shallow clone had no tags,
so the executable reports revision `unknown`; the exact base is recorded above.

## Validation

```sh
../mame-build/vet.exe -validate
python -m unittest discover -s tests -v
python tests/run_native_mame.py ../mame-build/vet.exe
python tests/run_mame.py ../mame-build/vet.exe --native-cart
```

All commands returned exit code 0.

| Check | Result |
|---|---|
| MAME internal validation | Passed |
| Python tests | 6 passed |
| Native cartridge slot | All 16,384 bytes matched the image |
| Empty slot | All 16,384 bytes read as `0xff` |
| Boot with and without cartridge | Passed, 240 frames per scenario |
| Demo execution | Cartridge PC and advancing frame counter verified |
| Screen refresh | 59.922738 Hz, verified through Lua and `-listxml` |
| Native-slot regressions | 515 passed |
| Negative control, unpatched MAME | Rejected at 19.974242 Hz; no `-cart` option |
| Legacy Lua-based runner | 515 passed on unpatched MAME |

Native boot tests use temporary NVRAM/configuration and no cartridge read taps.
The regression suite only overrides instructions needed to isolate level transitions.
WMI/XInput access warnings in the restricted environment did not affect the results.

## Artifacts and limits

Local artifacts are in `../mame-build` relative to the VET 3000 repository:
`vet.exe`, `build-vet.log`, `build-vet-verify.log`, and `validation-results.log`.

- Executable SHA-256: `7FA12C67EA202707098BE84C7B16274DB5CAAE482D4F9031B3D2E669F49DF192`.
- Patch SHA-256: `A8C3CCE2A6D27B98279165B3625191538D0AEACC696BD610A5D79437819A6E8D`.

Physical hardware clock measurements, FONT cartridges, interactive visual testing,
and external video input were not tested.

## Second commit: VDP /INT and CPU clock

Commit `05ba7890` (September 29, 2026) on the same PR branch removes the VDP
`/INT` to MC6809 `/IRQ` connection: on the board, TMS9128 pin 16 has no
continuity to 6809 pin 3, as in the Radio-Electronics design the VET 3000
derives from. It also clocks the MC6809 from `VDP_CLOCK / 3`, the VDP CPUCLK
output. The MC6809 device divides its input clock by 4, like the real chip.

Incremental build in the same environment, with `OS=Windows_NT` exported in the
MSYS2 shell:

```sh
make SUBTARGET=vet SOURCES=src/mame/tms/vet3000.cpp -j6
```

No diagnostics were reported for `vet3000.cpp`.

| Check | Result |
|---|---|
| `vet.exe -validate` | Passed |
| `-listxml` | MC6809 clock 3579545 Hz (E = 894886 Hz), refresh 59.922738 Hz |
| Native slot boot, with and without cartridge | Passed |
| Native-slot regressions with `--breakout` | 675 passed |
| SRAM top-ten persistence | Passed |
| Attract cycle, CPU and ranking takeover | Passed |
| Negative control: previous demo image (`SYNC` with VDP IE set) | Stops at PC `$4111` on its first frame, as on the hardware |

The demo cartridge used for these tests waits for the frame by polling the VDP
status register.

- Executable SHA-256: `45BFAEA2ECE2A17AFF3101EFEEC121ED828FDA6351F1B3922EBA7A6AEBCC9665`.
- Patch SHA-256: `8F992A3EC0675C5F823862D1C1EB0F0ADC90B02AF038CB96E72BF32F3CB72513`.
