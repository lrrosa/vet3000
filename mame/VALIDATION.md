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
