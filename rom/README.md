# Dump do firmware do VET 3000 (v2.1)

| Arquivo | Tamanho | CRC32 | SHA1 |
|---|---|---|---|
| `VET2.1-TMS_VET3000_27128A.BIN` | 16384 | `bfdef5fa` | `cd4da3cbda7fa12c9413d052bf69ee758cfe68b3` |

- **Origem:** EPROM ST **M27128AF1** com etiqueta "VET 2.1", lida de um VET 3000 real (placa
  `VET 30 VS1 REV. 2`) por Leonardo Roman da Rosa.
- **Endereço:** mapeada em `$C000-$FFFF`, com os vetores do 6809 no fim da imagem.
- **MAME:** é o mesmo dump do driver `vet3000`, que espera o arquivo como
  `vet3000/vet2.1-tms_vet3000_27128a.bin`.
- **Direitos:** © 1988, 1989 TMS – Tecnologia em Micro Sistemas. A empresa não existe mais; o dump
  está aqui como material histórico, para preservação e estudo, e não é coberto pela GPL.

O disassembly comentado está em [../disasm/vet3000_v2.1.asm](../disasm/vet3000_v2.1.asm).
