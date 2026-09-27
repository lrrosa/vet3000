# Patch para o driver vet3000 do MAME

- `vet3000.cpp.orig`: driver original (`src/mame/tms/vet3000.cpp`, mamedev/mame commit `774a180`, 2026-08-02)
- `vet3000.cpp`: driver modificado
- `vet3000-cart-and-vdp-clock.patch`: diferença entre os dois (`git apply` na raiz do MAME)

Mudanças: clock do TMS9128 em 10,738635 MHz (60 Hz em vez de 20 Hz) e slot de cartucho em
`$4000-$7FFF` (`mame vet3000 -cart arquivo.bin`). **Não compilado**: ver [../docs/mame.md](../docs/mame.md).
O código do MAME é licenciado como GPL-2.0+.
