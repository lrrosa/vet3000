# Hardware do VET 3000

![Placa principal e fonte](img/placa_e_fonte.jpg)

O aparelho tem duas placas: a **fonte de alimentação** (à esquerda na foto) e a **placa principal**
(serigrafia `VET 30 VS1 REV. 2` no lado da solda). A placa principal se divide em duas metades:

- **digital** (direita): CPU, ROM, RAM, VDP, VRAM, decodificação, teclado e o conector traseiro CN1;
- **analógica** (esquerda): entrada e saída de vídeo, *genlock*/sincronismo, chaveamento do vídeo
  externo e codificação de cor.

Fotos em alta resolução em [../photos/](../photos/).

| Componentes | Lado da solda |
|---|---|
| ![](img/placa_componentes.jpg) | ![](img/placa_solda.jpg) |

## Componentes identificados

### Parte digital

| Ref. | Componente | Função |
|---|---|---|
| — | **MC6809** (etiqueta escrita à mão) | CPU. O MAME usa 3,579545 MHz de entrada, ou E = 894,886 kHz, como no TRS Color |
| — | **M27128AF1** (ST), etiqueta "VET 2.1", código 9240 | EPROM de 16 KB com o firmware, em `$C000-$FFFF` |
| — | **HY6264LP-10** (Hyundai, 8946) | RAM estática 8K×8 (**64 Kbit = 8 KB**), com bateria, em `$0000-$1FFF` |
| — | **TMS9128NL** (TI, 8910, Filipinas) | VDP. Saídas Y, R-Y e B-Y, com modos e sprites iguais aos do TMS9918A |
| U14, U21 | **µPD41416C-15** (NEC Irlanda) | 2 DRAMs 16K×4 = **16 KB de VRAM** |
| U15 | **74LS139** (ST) | Decodificador de endereços (duplo 2→4) |
| U16 | **74LS273** | Latch de escrita da linha do teclado (`$8002`) |
| U22 | **74LS244** + R52-R59 | Buffer de leitura das colunas do teclado (`$8002`), com *pull-ups* |
| — | Conector 2×8 | Membrana do teclado: 8 trilhas em cada camada |
| CN1 | Borda de placa 2×18 | Conector traseiro "interface": barramento da CPU. Ver [conector-cn1.md](conector-cn1.md) |

### Parte analógica e de vídeo

| Ref. | Componente | Função provável |
|---|---|---|
| XTAL1 | Cristal **3,579545 MHz** + trimmer CV2 | Subportadora de cor NTSC |
| — | **LM1889N** (National) | Modulador de croma e RF: monta o vídeo composto a partir de Y, R-Y e B-Y |
| — | **MC4044P** + **MC4024P** (Motorola) | Detector de fase/frequência + VCO: PLL do *genlock* (clock do VDP travado no vídeo de entrada) |
| U13, U20 | **74LS191** ×2 | Contadores/divisores do PLL e da temporização de linha |
| U4 | **74LS221** | Monoestáveis (janelas de sincronismo) |
| U3 | **CA339E** | Comparadores (separação de sincronismo, *keying*) |
| U8 | **SN75108AN** | Receptor de linha rápido, usado como comparador de vídeo |
| U2, U10, U17 | **4066** ×3 | Chaves analógicas: mistura do vídeo externo com a imagem do VDP |
| U9 | **74LS05** | Inversores com coletor aberto |
| U23 | **74LS00** | Portas NAND |
| U19 | CI de 20 pinos **sem marcação** | Lógica desconhecida (PAL ou identificação removida) |
| RV1-RV3 | Trimpots | Ajustes de vídeo |

### Fonte

Transformador LIDER, regulador **7805** (LM340T-5), filtros de 3300 µF e 2200 µF. O conector da fonte,
conforme a etiqueta no gabinete, tem **−5 V, +5 V, +3 V BAT, +12 V e GND**. A linha **+3 V BAT** alimenta
a RAM (pino 28 da HY6264) e mantém os títulos com o aparelho desligado.

## Clocks

| Sinal | Valor | Observação |
|---|---|---|
| Entrada do TMS9128 | **10,738635 MHz** (nominal) | Necessário para 15.734 Hz de linha e 59,94 Hz de quadro. Provavelmente vem do VCO do PLL de *genlock* |
| Pixel | 5,369 MHz | 342 pixels por linha, 262 linhas |
| CPU (E) | 894,886 kHz | 3,579545 MHz ÷ 4, conforme o MAME. **Confirmar** com frequencímetro no pino 34 (E) do 6809 |
| Quadro | cerca de **14.930 ciclos de CPU** | Orçamento de processamento por quadro a 60 Hz |

Não há cristal perto do 6809 nem do TMS9128: os dois recebem clock de fora. O driver do MAME 0.289
declara o VDP a 3,58 MHz, o que dá 19,97 Hz de quadro (ver [mame.md](mame.md)).

## Caminho do vídeo

O TMS9128 gera luminância e diferenças de cor (Y, R-Y, B-Y) e o LM1889 as codifica em vídeo composto.
A imagem do VDP é sobreposta ao vídeo da entrada traseira quando o bit **EXTVID** (registrador 0, bit 0)
está ligado. Nesse modo a cor 0 (transparente) e o fundo transparente deixam ver o vídeo externo.
A tecla **EXT MODE** do firmware liga e desliga esse bit. As chaves 4066 e o PLL (MC4044/MC4024)
fazem a mistura e o travamento do sincronismo.

O cristal de 3,579545 MHz indica codificação de cor **NTSC**. A compatibilidade com PAL-M (padrão
brasileiro, também de 525 linhas e 60 Hz) não foi verificada.

## Temporização de acesso à VRAM

Conforme o *TMS9918A Data Manual* (tabela 2-2), na área ativa dos modos Graphics I/II o VDP pode
levar **até 8 µs** para aceitar um novo acesso à VRAM. Durante o apagamento vertical (~4,3 ms após a
interrupção), ou com a imagem desligada, bastam **2 µs**.

Com o 6809 a 0,895 MHz, 8 µs são **7,2 ciclos**. Regra prática: manter **pelo menos 8 ciclos** entre
dois acessos à porta de dados (`$8000`). Um `STA $8000` leva 5 ciclos, então dois seguidos (5,6 µs)
podem falhar no meio da imagem, mas `LDA ,X+` / `STA $8000` (11 ciclos) é sempre seguro. O próprio
firmware chama uma sub-rotina vazia (`VDP_DELAY`, só `RTS`) entre escritas para garantir esse
intervalo.

## Pontos a confirmar no aparelho real

- clock real do 6809 (pino 34, E) e do TMS9128 (pinos 39/40, entrada de cristal);
- função exata dos pinos 10, 11 e 16 da fileira superior do CN1 (ver [conector-cn1.md](conector-cn1.md));
- função do CI U19, que está sem marcação;
- padrão de cor da saída (NTSC ou PAL-M).
