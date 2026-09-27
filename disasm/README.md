# Disassembly do firmware v2.1

| Arquivo | Conteúdo |
|---|---|
| `vet3000_v2.1.asm` | Disassembly comentado (sintaxe asm6809), **gerado**. Cada linha traz endereço e bytes originais no comentário |
| `hints.py` | Anotações: nomes de rotinas/variáveis, blocos de dados, textos, comentários |
| `coverage.txt` | Endereços executados no MAME (trace com todas as teclas), usados como pontos de entrada extras |
| `verify.sh` | Regenera o `.asm` e confere que ele remonta idêntico à EPROM |

Para melhorar o disassembly, edite `hints.py` (e não o `.asm`) e rode:

```bash
ASM6809=/caminho/asm6809 ./disasm/verify.sh
```

O disassembler ([../tools/dis6809.py](../tools/dis6809.py)) rastreia o código a partir dos vetores,
das tabelas de salto (inclusive auto-relativas, `fdb ROTINA-*`) e da cobertura. Ele marca como dados
tudo o que não foi alcançado e força os modos de endereçamento não mínimos (`<<`, `<`, `>`), para que
a remontagem seja exata.

Direitos: o código e os dados da ROM são © 1988, 1989 TMS – Tecnologia em Micro Sistemas. Os nomes,
comentários e ferramentas são © 2026 Leonardo Roman da Rosa, GPL-3.0-or-later.
