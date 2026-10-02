# VET 3000 no MAME

O MAME emula o VET 3000 desde o driver `src/mame/tms/vet3000.cpp` (Felipe Sanches e Datassette). Os
testes daqui foram feitos no **MAME 0.289**.

## Rodando o titulador

O driver espera a ROM com o nome `vet3000/vet2.1-tms_vet3000_27128a.bin` dentro do `rompath`:

```powershell
mkdir roms\vet3000
copy rom\VET2.1-TMS_VET3000_27128A.BIN roms\vet3000\vet2.1-tms_vet3000_27128a.bin
mame vet3000 -rompath roms
```

A RAM com bateria vai para `nvram/vet3000/`. O teclado do PC segue a posição das teclas. As teclas
amarelas estão mapeadas assim: CAPS LOCK ou TAB = EXT MODE, `[` = CURSOR, `]` = OBJ,
BACKSPACE = CLEAR, `'` = AUTO CENTER, `,` = BORDER BLK, `.` = COLOR, `/` = PAGE, `\` = C amarelo,
↓ = ↑↓, ← = ←→.

## Cartucho sem recompilar o MAME

O driver 0.289 não mapeia `$4000-$7FFF`. O script
[tools/mame/vet3000_cart.lua](../tools/mame/vet3000_cart.lua) instala um *read tap* nessa faixa e
devolve os bytes de um arquivo. A ROM original acha a assinatura no boot como no aparelho.

No Windows, o mais simples é o [../jogar_no_mame.bat](../jogar_no_mame.bat), que chama o
`run_cart.ps1` com a demo. A variável `VET_MAME_EXTRA` acrescenta parâmetros ao MAME, por exemplo
`-window -nomaximize`.

```powershell
# copia a ROM para uma pasta temporária e roda a partir da pasta do MAME
.\tools\mame\run_cart.ps1 -Mame F:\jogos\emuladores\mame\mame.exe -Cart cartridge\demo\vet3000_demo.bin

# manual
$env:VET_CART = "C:\caminho\vet3000_demo.bin"
mame vet3000 -rompath roms -autoboot_script tools\mame\vet3000_cart.lua
```

Variáveis de ambiente que o script aceita:

| Variável | Uso |
|---|---|
| `VET_CART` | Imagem do cartucho (até 16 KB, mapeada em `$4000`) |
| `VET_KEYS` | Roteiro de teclas: `SPACE w20 SHIFT+V snap quit` (`wN` espera N quadros, `snap` tira um snapshot, `+` aperta junto) |
| `VET_WAIT`, `VET_HOLD` | Quadros antes do roteiro (40) e duração de cada tecla (3) |
| `VET_PEEK` | Palavras de RAM (hexa) a imprimir ao sair. No build DEBUG da demo, `9A,9C` = voltas de 13 ciclos por quadro e menor sobra |
| `VET_TRACE` | Arquivo de trace de instruções (rodar com `-debug -debugger none`) |

Exemplo de teste automático, sem janela:

```powershell
$env:VET_CART="cartridge\demo\vet3000_demo.bin"; $env:VET_KEYS="w30 snap SPACE w20 snap quit"
mame vet3000 -rompath roms -video none -sound none -nothrottle -snapview native -autoboot_script tools\mame\vet3000_cart.lua
```

Um *write tap* do Lua numa posição não mapeada (`$8003`) travou o MAME 0.289. Por isso o profiling
da demo é feito pelo próprio programa, com o resultado lido na RAM.

## Problemas encontrados no driver 0.289

1. **Clock do VDP errado.** O driver usa `MAIN_CLOCK` (3,579545 MHz) no TMS9128. O TMS9918/9128
   precisa de 10,738635 MHz. Com 3,58 MHz, a tela fica a **19,97 Hz**: o script mostra `refresh=19,974`.
   A CPU está certa (894.886 Hz), então cada quadro tem 3 vezes mais ciclos do que no aparelho
   (cerca de 44.800 em vez de 14.930), e animações sincronizadas com o quadro ficam 3 vezes mais
   lentas. A demo mede isso e compensa (ver [programando-cartuchos.md](programando-cartuchos.md)).
2. **Conector CN1 ausente.** O comentário do driver diz que a função do conector "interface" é
   desconhecida. Na verdade ele é a porta de cartucho descrita aqui.
3. **Entrada de vídeo** (sobreposição EXTVID) não é emulada, como o próprio driver avisa.
4. **`/INT` do VDP ligado ao IRQ.** O driver faz `vdp.int_callback().set_inputline(m_maincpu,
   INPUT_LINE_IRQ0)`, mas no aparelho não há continuidade entre o pino 16 do TMS9128 e o pino 3 do
   6809 (medido). O firmware não percebe, porque nunca liga o bit IE. Já um cartucho que espere a
   interrupção do VDP (com `SYNC` ou IRQ) funciona no MAME e trava no aparelho. O patch **remove
   essa ligação**. A demo não depende dela: espera o quadro lendo o status. Ver
   [programando-cartuchos.md](programando-cartuchos.md#4-sincronismo-com-o-quadro-sem-vetores).

## Patch proposto

[../mame/vet3000-cart-and-vdp-clock.patch](../mame/vet3000-cart-and-vdp-clock.patch), como foi
enviado ao MAME. O [../mame/vet3000.cpp](../mame/vet3000.cpp) é o driver como ficou no master do MAME
(ver [Incorporação ao MAME](#incorporação-ao-mame)):

- VDP a **10,738635 MHz** (60 Hz), o cristal de 3,579545 MHz multiplicado por 3 pelo PLL;
- **slot de cartucho** genérico (`generic_plain_slot`, interface `vet3000_cart`, extensões
  `bin,rom`) mapeado em `$4000-$7FFF`, para usar `mame vet3000 -cart vet3000_demo.bin`;
- `/INT` do VDP **sem ligação**, como no aparelho, e o 6809 com clock tirado do VDP
  (`VDP_CLOCK / 3`, a saída CPUCLK). O `MC6809` do MAME divide esse clock por 4 internamente, como o
  chip real: E = 894,886 kHz;
- comentários do driver atualizados com a descrição do CN1, do protocolo `"OBJECT"`/`"FONT"` e da
  origem do projeto (*Radio-Electronics* e MFJ-1480B).

**Built and tested on September 27–28, 2026**, on Windows x64 with MSYS2 UCRT64
and GCC 16.2.0, based on MAME commit `02342fb0547a9a9934d63b5e8708126b7b644007`.
The unchanged patch passed internal validation, native cartridge boot, the
**59.922738 Hz** refresh check, and **515 regression cases**.
See the [validation report](../mame/VALIDATION.md) for commands and limitations.
Submitted as [MAME PR #16276](https://github.com/mamedev/mame/pull/16276).

**Segundo commit do PR (29/09/2026):** `/INT` sem ligação e clock da CPU tirado do VDP. Compilado e
testado da mesma forma: `-validate`, boot nativo, 675 casos, persistência do top 10 e ciclo de
demonstração, a 59,922738 Hz. Ver o [relatório](../mame/VALIDATION.md#second-commit-vdp-int-and-cpu-clock).

## Incorporação ao MAME

O PR foi incorporado em **30/09/2026** (commit
[f43d44e3](https://github.com/mamedev/mame/commit/f43d44e3b4d59a015ca333c50294f9c74b11da2a), merge de
R. Belmont) e deve sair no MAME 0.290. Até lá, no 0.289, o cartucho continua dependendo do script Lua.

Em **01/10/2026**, Vas Crabb (cuavas) ajustou a declaração do clock no commit
[272ed7c2](https://github.com/mamedev/mame/commit/272ed7c2767e74ecdb40b74b782e5764e3da8f4d). No MAME,
`XTAL` representa só cristais que existem na placa. O VET não tem cristal de 10,738635 MHz: essa
frequência sai do PLL. O patch declarava `10.738635_MHz_XTAL`, e o master agora declara:

```cpp
constexpr XTAL VDP_CLOCK = 3.579545_MHz_XTAL * 3; // chroma clock multiplied with a PLL
```

Ele também trocou os comentários novos de `/* */` para `//`. As frequências continuam idênticas
(VDP a 10.738.635 Hz, CPU a 3.579.545 Hz), então os testes acima continuam valendo.
