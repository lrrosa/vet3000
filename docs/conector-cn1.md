# Conector traseiro CN1 ("interface") e cartucho

CN1 é um conector de borda de placa com **2 × 18 contatos**, na traseira do aparelho. Ele leva o
barramento da CPU e as seleções do decodificador de endereços. O firmware v2.1 procura programas
(`"OBJECT"`) e fontes (`"FONT"`) em `$4000-$7FFF` durante o boot: é uma porta de cartucho.

Todas as ligações abaixo vêm das medidas de continuidade originais, em
[medidas-originais/conector CN1 VET3000.txt](medidas-originais/conector%20CN1%20VET3000.txt).
As faixas de endereço de cada seleção foram deduzidas do firmware.

## Pinagem

Contagem da esquerda para a direita, **vista por fora** do aparelho:

```
         1  2  3  4  5  6  7  8  9 10 11 12 13 14 15 16 17 18
cima   [IRQ D0 D1 D2 D3 D4 D5 D6 D7 ROM Y2 RW HLT Y1 +5 1G GND NC]
baixo  [BAT A0 A1 A2 A3 A4 A5 A6 A7 A8 A9 A10 A11 A12 A13 -5 GND NC]
```

### Fileira superior

| Pino | Sinal | Ligação medida | Interpretação |
|---|---|---|---|
| 1 | **/IRQ** | 6809 pino 3 | Interrupção (compartilhada com o `/INT` do VDP) |
| 2-9 | **D0-D7** | ROM, RAM, 6809, TMS9128 | Barramento de dados |
| 10 | **E da ROM** | ROM pino 20 | *Chip Enable* da EPROM interna, ativo em 0. No datasheet da ST M27128A (a EPROM da placa) o pino 20 se chama **E**. É a seleção de `$C000-$FFFF`, provavelmente a saída `Y3` do decodificador |
| 11 | **Y2** | 74LS139 (U15) pino 6 (`1Y2`) | Seleção provável de `$8000-$BFFF` (E/S), ativa em 0 |
| 12 | **R/W** | RAM pino 27, 6809 pino 32 | Leitura (1) / escrita (0) |
| 13 | **/HALT** | 6809 pino 40 | Permite parar a CPU (DMA externo) |
| 14 | **Y1** | 74LS139 (U15) pino 5 (`1Y1`) | **Seleção do cartucho, `$4000-$7FFF`**, ativa em 0 |
| 15 | **+5 V** | ROM 1/27/28, 6809 2/4/7/33/36, VDP 33 | Alimentação. NMI, FIRQ, DMA e MRDY do 6809 vão ao +5 V |
| 16 | **1G** | 74LS139 (U15) pino 1 | Habilitação do decodificador. Função exata **a confirmar** |
| 17 | **GND** | | Terra |
| 18 | — | | Sem conexão |

### Fileira inferior

| Pino | Sinal | Ligação medida | Observação |
|---|---|---|---|
| 1 | **+3 V BAT** | RAM pino 28 | Alimentação da RAM com bateria. **Não usar** no cartucho |
| 2-15 | **A0-A13** | ROM, RAM, 6809 | Barramento de endereços (A13 não vai à RAM de 8 KB) |
| 16 | **−5 V** | | Não usar em projetos TTL/CMOS |
| 17 | **GND** | | Terra |
| 18 | — | | Sem conexão |

**A14 e A15 não estão no conector.** Por isso o cartucho depende da seleção `Y1` para saber que o
acesso é na sua janela. Com A0-A13 ele enxerga 16 KB, e o firmware procura assinaturas nas duas
metades de 8 KB (`$4000` e `$6000`).

## O que o firmware faz com o cartucho

1. Depois de inicializar o VDP e apagar a VRAM, compara `"OBJECT"` com `$4000`. Se bate, executa
   `LDX [$4006]` e `JSR $4000,X`. Senão, tenta o mesmo em `$6000`.
2. Depois (se o programa voltar com `RTS`), procura `"FONT"` em `$4000` e `$6000` e troca as fontes.
3. Segue para a verificação de `"POWER"`, a tela de abertura e o editor.

O formato exato dos cabeçalhos está em [programando-cartuchos.md](programando-cartuchos.md).

## Circuito de um cartucho com EPROM 27C128

O projeto completo em KiCad, com placa roteada e Gerbers, está em
[hardware/cartucho](../hardware/cartucho/README.md). Ele segue o circuito abaixo e acrescenta a
proteção de `/OE` com um 74HCT00, os jumpers para outras memórias e uma chave de ativação.

O cartucho mais simples é uma única EPROM de 16 KB (27128 / 27C128) ligada direto ao conector:

```
 CN1 (baixo)         27C128                CN1 (cima)
 ----------         --------               ---------
 2  A0  ----------- 10 A0      D0 11 ----- 2  D0
 3  A1  -----------  9 A1      D1 12 ----- 3  D1
 4  A2  -----------  8 A2      D2 13 ----- 4  D2
 5  A3  -----------  7 A3      D3 15 ----- 5  D3
 6  A4  -----------  6 A4      D4 16 ----- 6  D4
 7  A5  -----------  5 A5      D5 17 ----- 7  D5
 8  A6  -----------  4 A6      D6 18 ----- 8  D6
 9  A7  -----------  3 A7      D7 19 ----- 9  D7
 10 A8  ----------- 25 A8
 11 A9  ----------- 24 A9     /CE 20 --+-- 14 Y1 (seleção $4000-$7FFF)
 12 A10 ----------- 21 A10    /OE 22 --+
 13 A11 ----------- 23 A11
 14 A12 -----------  2 A12    VCC 28 --+-- 15 +5V
 15 A13 ----------- 26 A13    VPP  1 --+
                              /PGM 27 -+
 17 GND ----------- 14 GND                17 GND
                   100 nF entre os pinos 28 e 14
```

Observações:

- **Proteção contra conflito no barramento (opcional, recomendada):** a seleção `Y1` provavelmente
  fica ativa também em escritas. Se um programa escrever em `$4000-$7FFF`, a EPROM e a CPU
  disputariam o barramento. Para evitar, ligue o `/OE` ao inverso de R/W (pino 12 de cima) com uma
  porta de um 74HC00 ou 74HC04, e deixe `/CE` em `Y1`.
- **Regravável:** uma **W27C512** ou **27C256** serve no lugar da 27C128 (confira a pinagem: na 27C256
  o pino 27 é A14; na 27C512 o pino 1 é A15). Amarrar A14/A15 com *jumpers* permite guardar
  2 ou 4 imagens de 16 KB e escolher qual vai rodar. Uma EEPROM **28C256** permite regravar no
  próprio gravador sem apagar com UV. Nela o pino 1 é A14 (amarrar em GND ou +5 V) e o pino 27
  é `/WE`, que deve ir ao **+5 V** para a memória não ser escrita.
- **Contatos:** use conector fêmea de borda 2×18. O passo é provavelmente 2,54 mm e deve ser
  **medido** antes de comprar. Também dá para fazer uma placa que encaixe na borda.
- **Não ligar** +3 V BAT (baixo 1) nem −5 V (baixo 16).
- A imagem da demo ([cartridge/demo](../cartridge/demo/)) tem exatamente 16 KB e vai direto numa 27C128.

## A confirmar no aparelho

- que o pino 14 de cima fica em nível baixo só nos acessos a `$4000-$7FFF`: basta observar com
  osciloscópio ou ponta lógica enquanto um programa lê essa faixa;
- a função do pino 16 de cima (entrada `1G` do 74LS139): se for a habilitação ligada a E ou a /E,
  as seleções já saem qualificadas pelo clock. Se tiver só um resistor, um cartucho poderia desligar
  a decodificação interna (RAM, E/S e ROM) e assumir o barramento.
