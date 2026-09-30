# MAME VET 3000 driver patch

- `vet3000.cpp.orig`: original driver from mamedev/mame commit `774a180` (2026-08-02).
- `vet3000.cpp`: patched driver.
- `vet3000-cart-and-vdp-clock.patch`: apply with `git apply` from the MAME root.

Fixes the TMS9128 clock to 10.738635 MHz and adds a cartridge slot at
`$4000-$7FFF` (`mame vet3000 -cart image.bin`). It also leaves the VDP `/INT`
output unconnected and clocks the MC6809 from the VDP CPUCLK output, as on the
board.

Built and tested on Windows x64 on September 27-28, 2026: native cartridge boot,
59.922738 Hz refresh, and 515 regression cases passed. The second commit (VDP `/INT`
and CPU clock) was built and tested on September 29, 2026. See [validation](VALIDATION.md).

The MAME driver is licensed under GPL-2.0+.
