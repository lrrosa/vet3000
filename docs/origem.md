# Origem: o Video Titler da *Radio-Electronics* e o MFJ-1480B

O VET 3000 descende do **"Build This Video Titler"**, de **Jack Flack**. O projeto foi publicado em
quatro partes na revista americana *Radio-Electronics*, entre novembro de 1985 e março de 1986, e
virou produto comercial como **MFJ-1480B "Video Effects Titler (VET)"**, da MFJ Enterprises.

A semelhança vai muito além do uso do TMS9128. Coincidem o conjunto inteiro de CIs, o mapa de
memória e de E/S, a decodificação de endereços, a **ordem dos pinos do conector de expansão**, a
matriz do teclado, os valores iniciais dos registradores do VDP, a sequência das 16 cores, os
comandos do editor, a tela de abertura e a fonte dos caracteres. Até o nome é o mesmo: VET é a sigla
de *Video Effects Titler*.

Não se sabe como a TMS obteve o projeto: licença, compra, cópia ou adaptação a partir da revista.
A relação técnica está provada. A histórica, ainda não.

## Linha do tempo

| Data | Fato |
|---|---|
| 11/1985 | *Radio-Electronics*, parte 1 (p. 45-49): teoria, diagrama de blocos, fonte e lista de peças. A mesma edição já oferece placa, EPROM programada e kit parcial (Micro-Video-Technology, Chattanooga, TN). A **MFJ** vende o titulador montado por US$ 599,95 |
| 12/1985 | Parte 2 (p. 65-70): sincronismo externo, gerador de clock, VDP, croma e *mixer* (Figs. 7-13). **Lista de peças corrigida**: SN75108 no lugar do LM361, 2764 no lugar da 2732 e HM6264LP no lugar da 6116 |
| 01/1986 | Parte 3 (p. 57-62): microcomputador (Fig. 14), mapa de memória (Fig. 15), montagem, ajustes e operação |
| 03/1986 | Parte 4 (p. 62-66 e 78): software, pinagem da porta de expansão (Fig. 19), interfaces para Apple II, C64, TRS-80 Color Computer e IBM PC, e programação do VDP. EPROM vendida já na **V2.0**. A listagem da **V1.0** custava US$ 4 |
| 1986 | **MFJ-1480B**, com manual do usuário. Na tela de abertura: *"VET OPERATING SYSTEM (3.0) — Copyright 1986 MFJ ENTERPRISES, INC."* |
| 04/1987 | Anúncio na *Video Magazine*: MFJ-1480B *Video Effects Titler (VET)*, US$ 599,95, *genlock*, porta de expansão, cartuchos futuros de fontes, efeitos, logotipos e idiomas, e interface RS-232 MFJ-1481 |
| 1988-1989 | **TMS VET 3000**: *"Sistema Operacional Vr 2.1 — TMS MICROSISTEMAS — Copyright 1988,1989"* |

## Fontes

- *Radio-Electronics*, no worldradiohistory.com (o servidor recusa downloads sem *User-Agent* de
  navegador):
  [11/1985](https://www.worldradiohistory.com/Archive-Radio-Electronics/80s/1985/Radio_Electronics_November_1985.CV01.pdf),
  [12/1985](https://www.worldradiohistory.com/Archive-Radio-Electronics/80s/1985/Radio-Electronics-1985-12.pdf)
  (também no [Datassette](https://datassette.org/pt-br/revistas/eletronica/us-estados-unidos/radio-electronics/radio-electronics-1985-12)),
  [01/1986](https://www.worldradiohistory.com/Archive-Radio-Electronics/80s/1986/Radio-Electronics-1986-01.pdf),
  [03/1986](https://www.worldradiohistory.com/Archive-Radio-Electronics/80s/1986/Radio-Electronics-1986-03.pdf).
- [Manual do MFJ-1480B](https://archive.org/details/mfj-1480b/) (archive.org, 6 páginas).
- Vídeo [*Weird Thing: MFJ-1480B Video Title-r*](https://www.youtube.com/watch?v=CXMPhwOAQ1A), de
  Cathode Ray Dude: [abertura em 11:15](https://www.youtube.com/watch?v=CXMPhwOAQ1A&t=675s) e texto
  digitado em [12:30](https://www.youtube.com/watch?v=CXMPhwOAQ1A&t=750s) e
  [13:50](https://www.youtube.com/watch?v=CXMPhwOAQ1A&t=830s).
- Anúncio do MFJ-1480B na [*Video Magazine* de abril de 1987](https://pubhtml5.com/mmike/lvkc/basic/).
- Placa do VET: [fotos](../photos/), [hardware.md](hardware.md), [conector-cn1.md](conector-cn1.md),
  [teclado.md](teclado.md). Firmware: [firmware.md](firmware.md) e o
  [disassembly](../disasm/vet3000_v2.1.asm).

Abaixo, "revista" é o projeto da *Radio-Electronics*, com os números de CI da lista corrigida de
12/1985 (`IC1`-`IC26`). "VET" é a placa `VET 30 VS1 REV. 2`.

## 1. Componentes

| Função | Revista | VET 3000 | |
|---|---|---|---|
| CPU | IC23 MC6809 | MC6809 | igual |
| EPROM | IC19 2764 (8 KB) | M27128AF1 (16 KB) | ampliada |
| RAM com bateria | IC20 HM6264LP | HY6264LP-10 | equivalente |
| VDP | IC10 TMS9128 | TMS9128NL | igual |
| VRAM | IC11, IC12 4416 | U14, U21 µPD41416C-15 | equivalente |
| Decodificador | IC18 74LS139 | U15 74LS139 | igual |
| NAND | IC15 74LS00 | U23 74LS00 | igual |
| Teclado: latch | IC21 74LS273 | U16 74LS273 | igual |
| Teclado: buffer | IC22 74LS244 + RN1 (10 kΩ × 9) | U22 74LS244 + R52-R59 | igual |
| Comparadores | IC1 LM339 | U3 CA339E | equivalente |
| Monoestáveis | IC2 74LS221 | U4 SN74LS221N | igual |
| Inversores coletor aberto | IC3 74LS05 | U9 SN74LS05N | igual |
| Detector de fase | IC4 MC4044 | MC4044P | igual |
| VCO | IC5 MC4024 | MC4024P | igual |
| Contadores | IC6, IC7 74LS191 | U13, U20 74LS191 | igual |
| Chaves analógicas | IC8, IC9, IC13 4066 | U2, U10, U17 4066 | igual |
| Processador de croma | IC14 **CA3126** (16 pinos) | **U19**, 16 pinos, marcação raspada | confirmado pelas ligações (seção 8) |
| Modulador de croma | IC16 LM1889 | LM1889N | igual |
| Comparador rápido | IC17 SN75108 | U8 SN75108AN | igual |
| Cristal | **XTAL1** 3,579545 MHz | **XTAL1** 3,579545 MHz | igual, mesmo nome |
| Bobina | **L1** 56 µH | **L1** | mesmo nome |
| Trimmers capacitivos | C12 (VCO), C27 (croma) | **CV1** junto ao MC4024, **CV2** junto ao XTAL1 | mesmas posições |
| Trimpots | R29, R32, R46 | RV1, RV2, RV3 | três em ambos |
| Fonte | 7812, 7805, 79L05, bateria de lítio de 3 V | placa separada: 7805, saídas +12 V, −5 V e +3 V BAT | mesmas tensões |

Os designadores dos componentes passivos não seguem a revista: o resistor de 680 Ω do oscilador de
croma, R23 na revista, é o **R51** no VET. Um capacitor ao lado do cristal se chama C65 nas duas
placas, mas deve ser coincidência.

A PCB do VET é outra: disposição, designadores dos CIs (`U` em vez de `IC`) e conector são
diferentes. A divisão da placa é a mesma, com o bloco digital de um lado e sincronismo, PLL, croma e
*mixer* do outro.

## 2. Mapa de memória, E/S e decodificação

| Faixa | Revista (Fig. 15) | VET 3000 |
|---|---|---|
| `$0000-$1FFF` | RAM do sistema, 8 KB | RAM, 8 KB |
| `$4000-$7FFF` | *External ROM (font/program)* | cartucho `"OBJECT"`/`"FONT"` |
| `$8000` | VRAM (dados), leitura e escrita | igual |
| `$8001` | endereço/registrador (escrita), status (leitura) | igual |
| `$8002` | porta de saída do teclado (escrita), entrada (leitura) | igual |
| `$C000-$FFFF` | ROM de 8 KB em `$E000` (espelhada em `$C000`) | ROM de 16 KB |

A decodificação da Fig. 14 é a que o VET usa:

- **IC15-c** (NAND) combina o clock **E** do 6809 (pino 34) com **/HALT** (pino 40). A saída habilita a
  metade A do **74LS139** (pino 1, `/G`). Assim, as seleções só ficam ativas com E alto, e ficam
  desligadas quando a CPU é parada.
- Metade A: `A15` no pino 3 e `A14` no pino 2. `Y0` = RAM (`/CS1`), `Y1` = **XROM** (`$4000-$7FFF`),
  `Y2` = E/S, `Y3` = ROM.
- `Y2` passa por um diodo (D6, com R42 de 3,3 kΩ) até o `/G` da metade B, e `Y3` passa por outro
  diodo (D5, com R41) até o `/CE` da ROM. Os dois nós vão também ao conector, com os nomes
  **I/O SEL** e **ROM SEL**. Um computador externo pode selecionar a E/S e a ROM com a CPU parada.
- Metade B: `R/W` no pino 14 e `A1` no pino 13. `Y0` = `/CSW` do VDP, `Y1` = `/CSR`, `Y2` = clock do
  74LS273 (escrita no teclado), `Y3` = `/E` do 74LS244 (leitura do teclado). O `MODE` do VDP é `A0`.

Na placa do VET há dois diodos (**D10**, **D11**) e dois resistores (**R48**, **R49**) logo ao lado do
74LS139. Devem ser os D5/D6 e R41/R42 da revista.

## 3. O CN1 é a porta de expansão da revista

A Fig. 19 da parte 4 dá a pinagem da porta de expansão: borda de placa de 2 × 17 contatos, com os
pinos 1-17 em cima e 34-18 embaixo (o 1 fica em frente ao 34). O CN1 do VET tem 2 × 18 contatos e
foi medido **por fora**, da esquerda para a direita (ver [conector-cn1.md](conector-cn1.md)). Lido
do pino 17 para o 1, o CN1 repete a porta da revista **na mesma ordem**, com uma posição a mais na
ponta do GND:

| Revista, em cima | Sinal (revista) | VET, em cima | Sinal medido no VET |
|---|---|---|---|
| 1 | GND | 17 | GND |
| 2 | **/E CLK** | 16 | 74LS139 (U15) pino 1, `1/G` |
| 3 | +5 V | 15 | +5 V |
| 4 | **XROM** | 14 | U15 pino 5, `1Y1` |
| 5 | **CPU DISABLE** | 13 | /HALT (6809 pino 40) |
| 6 | R/W | 12 | R/W |
| 7 | **I/O SEL** | 11 | U15 pino 6, `1Y2` |
| 8 | **ROM SEL** | 10 | `/CE` da EPROM (pino 20) |
| 9-16 | D7 … D0 | 9-2 | D7 … D0 |
| 17 | /NMI | 1 | **/IRQ** (6809 pino 3) |
| — | — | 18 | sem conexão |

| Revista, embaixo | Sinal (revista) | VET, embaixo | Sinal medido no VET |
|---|---|---|---|
| 34 | GND | 17 | GND |
| 33 | sem conexão | 16 | **−5 V** |
| 32-19 | A13 … A0 | 15-2 | A13 … A0 |
| 18 | sem conexão | 1 | **+3 V BAT** |
| — | — | 18 | sem conexão |

Isso resolve os pinos que estavam em aberto: o **16 de cima** é o E qualificado por /HALT, ativo em 0
(a habilitação do decodificador), o **14** é a seleção do cartucho, o **11** é a seleção de E/S e o
**10** é a seleção da ROM interna. As diferenças do VET são:

- **/IRQ no lugar de /NMI.** Na revista, o /NMI vai à porta (com R8 de 4,7 kΩ) e o /IRQ fica em +5 V.
  No VET, o /NMI fica em +5 V e o /IRQ vai à porta. O `/INT` do VDP continua sem ligação, como na
  revista, onde o pino 16 do TMS9128 nem aparece no Fig. 10: não há continuidade entre ele e o
  pino 3 do 6809 (medido). A interrupção de quadro não chega à CPU, ao contrário do que supõe o
  driver do MAME 0.289 (o patch deste repositório corrige). O firmware da revista e o do VET esperam o quadro lendo o status do VDP.
- Duas posições livres da revista passaram a levar **−5 V** e **+3 V BAT**, e há uma 18ª posição
  vazia. Uma placa de interface da revista ou da MFJ, se aparecer, deve ser conferida antes de ser
  ligada.
- No VET, o pino 11 foi medido no **pino 6** do 74LS139 (`1Y2`). Na revista, **I/O SEL** fica do
  outro lado do diodo, no `/G` da metade B (pino 15). Vale conferir se o diodo existe nesse caminho.

## 4. Clocks: PLL, VDP e CPU

Segundo a parte 2 (Fig. 8), o XTAL1 de 3,579545 MHz **não** vai ao VDP. Ele é o cristal do
oscilador de croma (CA3126), que fornece um *CHROMA CLOCK* TTL de 3,58 MHz. O clock mestre do VDP
é gerado por um PLL:

```text
             interno: CHROMA CLOCK (3,579545 MHz, do CA3126)
referência ─┤                                                   (chaves 4066 IC8-a/b)
             externo: pulso horizontal do vídeo de entrada

referência ─► MC4044 ─► MC4024 (VCO) ─► ≈10,7 MHz ─► TMS9128 pino 40 (clock mestre)
                ▲                                          │
                │                                          ▼
                │                               TMS9128 pino 37: CPUCLK = mestre ÷ 3 ─► 6809 EXTAL
                │                                          │
                ├── interno: CPUCLK ◄──────────────────────┤
                └── externo: CPUCLK ÷ 228 (2 × 74LS191) ◄──┘   (chaves 4066 IC8-c/d)
```

| Modo | Referência do PLL | Clock mestre do VDP |
|---|---|---|
| Interno | *CHROMA CLOCK*, comparado com o CPUCLK | 3 × 3,579545 = **10,738635 MHz** |
| Externo (*genlock*) | pulso horizontal do vídeo de entrada, comparado com CPUCLK ÷ 228 | (3,579545 / 227,5) × 684 ≈ **10,762235 MHz** |

- **O 6809 recebe o CPUCLK do VDP.** Na Fig. 14, o `EXTAL` (pino 38) do 6809 vem do *CPU CLOCK*
  (pino 37 do TMS9128) e o `XTAL` (pino 39) vai ao terra. Então E = 3,579545 ÷ 4 = **894,886 kHz** no
  modo interno e ≈ **896,85 kHz** no externo. O clock da CPU acompanha o PLL.
- No TMS9928A o pino 37 é o GROMCLK (mestre ÷ 24). No **TMS9128** a revista usa o pino 37 como CPUCLK
  (mestre ÷ 3), e o circuito só funciona assim: o 6809 e o divisor por 228 dependem desse sinal.
- O texto de teste da parte 3 manda medir *"the master clock (pin 6)"*. É erro de digitação: a Fig. 10
  mostra os 10,7 MHz no **pino 40** e os 3,58 MHz no **pino 37**.
- Isso confirma o clock de **10,738635 MHz** usado no patch do MAME
  ([../mame/](../mame/), [PR 16276](https://github.com/mamedev/mame/pull/16276)). O driver não emula o
  *genlock*, então o valor do modo interno é o correto. Com 3,579545 MHz no VDP, a tela roda a
  19,97 Hz. Com 10,738635 MHz, a 59,92 Hz. O patch também tira o clock do 6809 do VDP
  (`VDP_CLOCK / 3`), como na placa. No MAME, o `MC6809` recebe o clock de entrada e divide por 4,
  como o chip real, então o `-listxml` mostra 3.579.545 Hz e a CPU executa a 894.886 ciclos/s.

## 5. VDP: mesmos registradores, mesma VRAM

A Tabela 5 da parte 4 é um programa em BASIC que inicializa o VDP como o firmware do titulador:
`DATA 2,0,130,1,14,2,255,3,3,4,120,5,3,6,0,7`. Os valores são **idênticos** à `VDP_INIT_TAB` do VET
v2.1:

| Reg. | Revista | VET 2.1 | Significado |
|---|---|---|---|
| R0 | 2 | `$02` | Graphics II. Bit 0 = vídeo externo |
| R1 | 130 | `$82` | VRAM de 16K, sprites 16×16, imagem desligada |
| R2 | 14 | `$0E` | nomes em `$3800` |
| R3 | 255 | `$FF` | cores em `$2000` |
| R4 | 3 | `$03` | padrões em `$0000` |
| R5 | 120 | `$78` | atributos de sprites em `$3C00` |
| R6 | 3 | `$03` | padrões de sprites em `$1800` |
| R7 | 0 | `$00` | borda transparente |

A revista diz que, depois da inicialização, o titulador só mexe em três coisas: bit 0 do R0 (vídeo
externo), bit 6 do R1 (apagar a tela) e R7 (cor da borda). São exatamente as teclas EXT MODE,
BORDER BLK e SHIFT+BORDER BLK do VET.

## 6. Teclado

Na revista, o 74LS273 aciona 6 colunas e o 74LS244 lê 8 linhas (49 teclas, com dois SHIFTs no mesmo
ponto). Na mesma orientação da [tabela do VET](teclado.md) (linha escrita × bit lido), só 10 das 48
posições da revista mudaram. Onde há seta, está "revista → VET":

| Linha | bit 0 | bit 1 | bit 2 | bit 3 | bit 4 | bit 5 | bit 6 | bit 7 |
|---|---|---|---|---|---|---|---|---|
| 1 (`$FE`) | 1 | Q | A | SHIFT | 7 | U | J | N |
| 2 (`$FD`) | 2 | W | S | Z → CONTROL | 8 | I | K | M |
| 3 (`$FB`) | 3 | E | D | X → EXT MODE | 9 | O | L | ESPAÇO |
| 4 (`$F7`) | 4 | R | F | C → — | 0 | P | EXT MODE → RETURN | BORDER BLK |
| 5 (`$EF`) | 5 | T | G | V → — | ←→ → `:` | CURSOR | OBJ → AUTO CENTER | COLOR |
| 6 (`$DF`) | 6 | Y | H | B → **C amarelo** | ↑↓ | RETURN → OBJ | CLEAR → (sem tecla) | PAGE |
| 7 (`$BF`) | não existe na revista (saída do 74LS273 sem ligação) | | | | | | | |

O VET usa a 7ª saída do 74LS273 para Z, X, C, V, B, ←→ e CLEAR. Com isso, a coluna do bit 3 fica
livre para os modificadores. O teclado do MFJ-1480B (foto na capa do manual) já tem as teclas
**A**, **B** e **C** à direita e **CNTL** à esquerda do A. O manual diz que A é o AUTO CENTER e
que **B, C e CNTL** ficaram *"intended for use with future expansion cartridges"*. O VET manteve o
**C** (o "C" amarelo, que o firmware v2.1 não lê), chamou o A de AUTO CENTER e eliminou o B. A posição
sem tecla da linha 6, bit 6 (código `$1F`) pode ser a do antigo B.

## 7. Firmware e operação

| Recurso | Revista (V1.0, 01/1986) | MFJ-1480B (manual, OS 3.0) | VET 3000 (v2.1) |
|---|---|---|---|
| Páginas | 30 | 30 | 30 |
| Linhas por página | 8 | 8 | 8 |
| Colunas | 16 | 14 grandes ou 28 pequenas (CONTROL+CURSOR) | 16 grandes ou 32 normais (CONTROL+CURSOR) |
| Caracteres | 47, só maiúsculas | maiúsculas e minúsculas; trava com SHIFT+CURSOR | idem, mais acentuados e blocos (CONTROL) |
| Cor | por caractere (frente e fundo) | por linha; COLOR com objeto muda o objeto | por linha; idem |
| Ordem das 16 cores | — | transparente, preto, azul escuro, azul claro, ciano, magenta, vermelhos escuro, médio e claro, verdes escuro, médio e claro, amarelos escuro e claro, branco, branco intenso | `COLORMAP` = `0 1 4 5 7 D 6 8 9 C 2 3 A B E F`: **a mesma sequência** |
| Cursor | liga/desliga | Font-1 → Font-2 → desligado | bloco (fonte A) → sublinhado (fonte B) → desligado |
| Objetos (4) | moldura oval, X, moldura retangular, seta | seta, moldura oval, moldura quadrada, X | seta, moldura retangular, moldura oval, X (sprites em `$F0A3`) |
| BORDER BLK / com SHIFT | apaga a tela / cor da borda | idem | idem |
| CLEAR / com SHIFT | apaga a página | apaga a linha / a página | idem |
| AUTO CENTER / com SHIFT | — | tecla A: linha / página | linha / página |
| Página direta | — | cursor desligado, número 1-30 e PAGE | idem (`page_entry`) |
| Rolagem lenta | — | CONTROL+PAGE, ESPAÇO para | idem (`CMD_ROLL`) |
| Cartuchos | *External ROM (font/program)* em `$4000` | *Font Cartridges* (simples ou duplo) e *Program Cartridges* | `"FONT"` (fonte A em `$4000`, B em `$6000`) e `"OBJECT"` |
| Abertura | — | THE / VIDEO EFFECTS / TITLER / FROM / logotipo MFJ / VET OPERATING SYSTEM (3.0) / Press any key for page 1 | THE / VIDEO EFFECTS / TITLER / logotipo tms / Sistema Operacional Vr 2.1 / Pressione qualquer tecla |

- O cartucho de fonte duplo do MFJ troca as duas fontes do editor (Font-1 e Font-2), como o `"FONT"`
  do VET troca a fonte A (em `$4000`) e a B (em `$6000`). O formato exato dos cabeçalhos do MFJ não
  é conhecido.
- No vídeo do Cathode Ray Dude, a fonte pequena do MFJ é **a mesma fonte normal 8×24 do VET**. Os
  glifos coincidem, com o `w` arredondado, o `f`, o `j` e os descendentes do `g` e do `y`. As linhas
  quebram em 28 colunas, e o VET usa as 32.
- A tela de abertura tem a mesma composição, com o logotipo do fabricante num retângulo amarelo no
  mesmo lugar.
- Os recursos que o VET tem e a V1.0 da revista não tinha (minúsculas, trava de maiúsculas, dois
  tamanhos, AUTO CENTER, página direta, rolagem, cartuchos de fonte) **estão todos no MFJ-1480B**.
  O firmware da TMS parece derivar do ramo MFJ, e não só do artigo. Só um dump da EPROM do MFJ
  permitiria comparar o código.

## 8. O CI raspado (U19): é um CA3126

U19 fica entre o LM1889 e o 74LS191 U20, no bloco de croma, perto do XTAL1 e do CV2. Ele tem
**16 pinos** e não 20, como dizia a primeira versão de [hardware.md](hardware.md). A marcação foi
raspada. No mesmo bloco, a revista usa o **CA3126** (RCA), de 16 pinos, que:

- regenera a subportadora de 3,58 MHz, travada no *burst* do vídeo externo, para o LM1889;
- oscila livre com o **XTAL1** no modo interno;
- fornece o **CHROMA CLOCK**, a referência do PLL do VDP no modo interno.

As ligações medidas no U19 (29/09/2026) são as do CA3126 na Fig. 11 e no datasheet da Harris,
cuja pinagem é: 1 entrada de croma, 2-3 filtro do AFPC, 4 desacoplamento de RF, 5 terra, 6 saída do
VCO, 7 entrada do VCO, 8 saída da portadora, 9 pulso horizontal de chaveamento, 10-11 filtro do
ACC, 12 V+, 13 detector de sobrecarga, 14 referência Zener, 15 saída de croma e 16 controle de ganho.
O bloco de croma da revista é o circuito de aplicação do datasheet: 680 Ω, cristal e capacitor em
série entre os pinos 6 e 7, 33 pF do pino 7 ao terra (o C65), resistor no pino 9 (2 kΩ no
datasheet, 2,2 kΩ na revista) e 0,01 µF no pino 4.

| Pino | Ligação na revista | Medido no VET | |
|---|---|---|---|
| 12 | +12 V | +12 V | igual |
| 5 | terra | terra | igual |
| 6 | R23 (680 Ω) até o XTAL1 | ligado direto ao **R51** (680 Ω), que vai ao XTAL1 | igual |
| 9 | *BURST GATE*: R24 (2,2 kΩ) até o pino 5 do 74LS221 | exatamente 2,2 kΩ até o pino 5 do U4 (74LS221) | igual |
| 6-7 | só o cristal e capacitores (C27, C28) entre os dois | 10 kΩ entre os pinos | caminho interno do CI: o datasheet não tem resistor externo aí |

Uma alimentação de 12 V no pino 12, o oscilador a cristal no pino 6 com o mesmo resistor e a janela
de *burst* do 74LS221 no pino 9, pelo mesmo resistor, não coincidem por acaso: **U19 é um CA3126**,
ou um equivalente pino a pino. Sem ele, o VET não tem referência de clock para o VDP no modo
interno. Raspar a marcação era prática comum para dificultar cópias.

Ligações que faltam conferir, só por completude: pino 4 (capacitor ao terra na revista), pino 7
(outro lado do cristal, C27, C28 e C65), pino 8 (saída de 3,58 MHz, senoide com o aparelho ligado)
e pino 1 (entrada de croma, pelo filtro com L1).

## 9. O que a TMS mudou

- EPROM de 16 KB (27128) em `$C000-$FFFF`, com as três fontes, os acentos e o logotipo.
- Fonte normal de 32 colunas (o MFJ usa 28) e caracteres acentuados com CONTROL.
- Conector de 2 × 18, com /IRQ no lugar de /NMI e −5 V e +3 V BAT nos pinos livres.
- Teclado de membrana com uma 7ª linha, sem a tecla B.
- Fonte de alimentação em placa separada.
- PCB própria (`VET 30 VS1 REV. 2`), com outros designadores e outra disposição.
- Firmware "Vr 2.1" em português, com o logotipo da TMS, a tabela `ROM_API` e a tabela de comandos
  em RAM para cartuchos.

## 10. Grau de confiança

**Confirmado** (documentos e comparação direta):

- o conjunto de CIs, o cristal de 3,579545 MHz e os ajustes (2 trimmers e 3 trimpots) correspondem aos da revista;
- o mapa de memória e de E/S e o esquema de decodificação são os mesmos;
- o CN1 repete a ordem dos pinos da porta de expansão;
- a matriz do teclado é a da revista, ampliada;
- registradores do VDP, sequência de cores, comandos, abertura e fonte coincidem com os do MFJ-1480B;
- a revista especifica 10,738635 MHz no modo interno e o 6809 alimentado pelo CPUCLK do VDP;
- U19 é um CA3126 (ligações dos pinos 5, 6, 9 e 12 medidas);
- o `/INT` do VDP não vai ao `/IRQ` do 6809 (medido).

**Muito provável:**

- o firmware da TMS deriva do firmware da MFJ;
- D10/D11 e R48/R49 são os diodos e resistores de I/O SEL e ROM SEL.

**Não confirmado:**

- as ligações da parte analógica do VET, pino a pino;
- as frequências no aparelho (pino 40 e pino 37 do TMS9128, E do 6809) e a mudança no *genlock*;
- o formato dos cartuchos da MFJ;
- como a TMS obteve o projeto.

## 11. Medições sugeridas

1. **Clocks.** TMS9128 pino 40 ≈ 10,738635 MHz e pino 37 ≈ 3,579545 MHz; 6809 pino 34 (E)
   ≈ 894,9 kHz. Com EXT MODE e vídeo NTSC na entrada, o pino 40 deve ir para ≈ 10,762 MHz.
2. **Origem do clock da CPU.** Continuidade entre o pino 37 do TMS9128 e o pino 38 (EXTAL) do
   6809, e entre o pino 39 (XTAL) do 6809 e o terra.
3. **PLL.** Saída do MC4024 (pino 6 na Fig. 8) no pino 40 do TMS9128. Pino 37 do TMS9128 no clock de
   U13/U20.
4. **U19.** Feito em 29/09/2026: é um CA3126 (seção 8).
5. **CN1.** Pino 16 de cima até a saída de uma porta do 74LS00 (U23), cujas entradas vão ao E
   (pino 34) e ao /HALT (pino 40) do 6809. Pino 11: pino 6 ou 15 do 74LS139 (há diodo no meio?).
   Pino 10: diodo até o pino 7 do 74LS139.
6. **/INT do VDP.** Feito em 29/09/2026: **sem continuidade** entre o pino 16 do TMS9128 e o pino 3
   (/IRQ) do 6809, como na revista (no Fig. 10 o pino 16 nem aparece, e no Fig. 14 o /IRQ vai
   direto ao +5 V). O driver do MAME 0.289 supõe essa ligação, e o patch a remove. A demo, que esperava o quadro com `SYNC`, passou a
   ler o status (ver [programando-cartuchos.md](programando-cartuchos.md#4-sincronismo-com-o-quadro-sem-vetores)).

## 12. Um esquema do VET 3000 a partir da revista

A revista publica o esquema completo: fonte (Fig. 6), sincronismo externo (Fig. 7), clock (Fig. 8),
VDP (Fig. 10), croma (Fig. 11), *mixer* (Fig. 13) e microcomputador com teclado e porta (Fig. 14).
Todos têm números de pino e valores de componentes. Como a lista de CIs do VET corresponde quase
1:1 à da revista, dá para montar um **esquema aproximado do VET 3000 em KiCad**:

- a topologia vem da revista, com as diferenças já medidas (27128, CN1 de 36 pinos com /IRQ,
  teclado de 7 linhas, U19 = CA3126 com R51, `/INT` do VDP sem ligação);
- os designadores são os do VET (`U13`, `CV1`, `RV2`, …) onde a serigrafia é legível, e os da
  revista onde não é;
- cada folha distingue ligações **medidas** de ligações **tiradas da revista**, e serve como roteiro
  de continuidade para validar a placa aos poucos;
- a parte digital (CPU, memórias, decodificação, VDP, teclado, CN1) já está quase toda confirmada.
  As partes analógicas começariam como "segundo a revista".

A parte digital já está desenhada em
[hardware/placa-principal](../hardware/placa-principal/README.md), com as redes coloridas pelo grau
de confirmação e um [roteiro de continuidade](../hardware/placa-principal/continuidade.md).
