# Roteiro de continuidade da placa principal e da fonte

Gerado por `gen/gen_esquema.py`. Cada rede lista os pinos ligados a ela no esquema. **✓** = ligação
medida no aparelho; **·** = tirada da revista, ainda a medir. Na fonte (situação `fotos`), **·** =
ligação levantada das fotos da placa, ainda a medir. Pinos de U101-U104 (6809, EPROM, RAM e VDP)
usam a numeração do CI; as referências provisórias estão explicadas no [README](README.md).

| Rede | Situação | Pinos |
|---|---|---|
| `A0` | medido | ✓ CN1.b2, ✓ U101.8 (A0), ✓ U102.10 (A0), ✓ U103.10 (A0), ✓ U104.13 (MODE) |
| `A2` | medido | ✓ CN1.b4, ✓ U101.10 (A2), ✓ U102.8 (A2), ✓ U103.8 (A2) |
| `A3` | medido | ✓ CN1.b5, ✓ U101.11 (A3), ✓ U102.7 (A3), ✓ U103.7 (A3) |
| `A4` | medido | ✓ CN1.b6, ✓ U101.12 (A4), ✓ U102.6 (A4), ✓ U103.6 (A4) |
| `A5` | medido | ✓ CN1.b7, ✓ U101.13 (A5), ✓ U102.5 (A5), ✓ U103.5 (A5) |
| `A6` | medido | ✓ CN1.b8, ✓ U101.14 (A6), ✓ U102.4 (A6), ✓ U103.4 (A6) |
| `A7` | medido | ✓ CN1.b9, ✓ U101.15 (A7), ✓ U102.3 (A7), ✓ U103.3 (A7) |
| `A8` | medido | ✓ CN1.b10, ✓ U101.16 (A8), ✓ U102.25 (A8), ✓ U103.25 (A8) |
| `A9` | medido | ✓ CN1.b11, ✓ U101.17 (A9), ✓ U102.24 (A9), ✓ U103.24 (A9) |
| `A10` | medido | ✓ CN1.b12, ✓ U101.18 (A10), ✓ U102.21 (A10), ✓ U103.21 (A10) |
| `A11` | medido | ✓ CN1.b13, ✓ U101.19 (A11), ✓ U102.23 (A11), ✓ U103.23 (A11) |
| `A12` | medido | ✓ CN1.b14, ✓ U101.20 (A12), ✓ U102.2 (A12), ✓ U103.2 (A12) |
| `A13` | medido | ✓ CN1.b15, ✓ U101.21 (A13), ✓ U102.26 (A13) |
| `D0` | medido | ✓ CN1.a2, ✓ U16.3 (D0), ✓ U22.18 (O0a), ✓ U101.31 (D0), ✓ U102.11 (D0), ✓ U103.11 (I/O0), ✓ U104.17 (CD7) |
| `D1` | medido | ✓ CN1.a3, ✓ U16.18 (D7), ✓ U22.16 (O1a), ✓ U101.30 (D1), ✓ U102.12 (D1), ✓ U103.12 (I/O1), ✓ U104.18 (CD6) |
| `D2` | medido | ✓ CN1.a4, ✓ U16.4 (D1), ✓ U22.3 (O3b), ✓ U101.29 (D2), ✓ U102.13 (D2), ✓ U103.13 (I/O2), ✓ U104.19 (CD5) |
| `D3` | medido | ✓ CN1.a5, ✓ U16.17 (D6), ✓ U22.5 (O2b), ✓ U101.28 (D3), ✓ U102.15 (D3), ✓ U103.15 (I/O3), ✓ U104.20 (CD4) |
| `D4` | medido | ✓ CN1.a6, ✓ U16.7 (D2), ✓ U22.14 (O2a), ✓ U101.27 (D4), ✓ U102.16 (D4), ✓ U103.16 (I/O4), ✓ U104.21 (CD3) |
| `D5` | medido | ✓ CN1.a7, ✓ U16.14 (D5), ✓ U22.7 (O1b), ✓ U101.26 (D5), ✓ U102.17 (D5), ✓ U103.17 (I/O5), ✓ U104.22 (CD2) |
| `D6` | medido | ✓ CN1.a8, ✓ U16.8 (D3), ✓ U22.12 (O3a), ✓ U101.25 (D6), ✓ U102.18 (D6), ✓ U103.18 (I/O6), ✓ U104.23 (CD1) |
| `D7` | medido | ✓ CN1.a9, ✓ U16.13 (D4), ✓ U22.9 (O0b), ✓ U101.24 (D7), ✓ U102.19 (D7), ✓ U103.19 (I/O7), ✓ U104.24 (CD0) |
| `IRQ_N` | medido | ✓ CN1.a1, ✓ R29.2, ✓ U101.3 (/IRQ) |
| `KB_C1` | medido | ✓ CN3.2, ✓ R52.2, ✓ U22.2 (I0a) |
| `KB_C2` | medido | ✓ CN3.4, ✓ R53.2, ✓ U22.4 (I1a) |
| `KB_C3` | medido | ✓ CN3.6, ✓ R54.2, ✓ U22.17 (I3b) |
| `KB_C4` | medido | ✓ CN3.8, ✓ R55.2, ✓ U22.15 (I2b) |
| `KB_C5` | medido | ✓ CN3.10, ✓ R56.2, ✓ U22.6 (I2a) |
| `KB_C6` | medido | ✓ CN3.12, ✓ R57.2, ✓ U22.13 (I1b) |
| `KB_C7` | medido | ✓ CN3.14, ✓ R58.2, ✓ U22.8 (I3a) |
| `KB_C8` | medido | ✓ CN3.16, ✓ R59.2, ✓ U22.11 (I0b) |
| `KB_L1` | medido | ✓ CN3.1, ✓ U16.2 (Q0) |
| `KB_L2` | medido | ✓ CN3.3, ✓ U16.19 (Q7) |
| `KB_L3` | medido | ✓ CN3.5, ✓ U16.5 (Q1) |
| `KB_L4` | medido | ✓ CN3.7, ✓ U16.16 (Q6) |
| `KB_L5` | medido | ✓ CN3.9, ✓ U16.6 (Q2) |
| `KB_L6` | medido | ✓ CN3.11, ✓ U16.15 (Q5) |
| `KB_L7` | medido | ✓ CN3.13, ✓ U16.9 (Q3) |
| `XROM_N` | medido | ✓ CN1.a14, ✓ U15.5 (O1) |
| `A1` | parcial | ✓ CN1.b3, · U15.13 (A1), ✓ U101.9 (A1), ✓ U102.9 (A1), ✓ U103.9 (A1) |
| `E_CLK_N` | parcial | ✓ CN1.a16, ✓ U15.1 (E), · U23.11 |
| `HALT_N` | parcial | ✓ CN1.a13, ✓ R30.2, · U23.1, · U23.12, ✓ U101.40 (/HALT) |
| `IO_SEL_N` | parcial | ✓ CN1.a11, · D11.1 (K), ✓ U15.6 (O2) |
| `ROM_SEL_N` | parcial | ✓ CN1.a10, · D10.2 (A), · R48.2, ✓ U102.20 (/CE) |
| `R_W` | parcial | ✓ CN1.a12, · U15.14 (A0), · U23.2, ✓ U101.32 (R/W), ✓ U103.27 (/WE) |
| `A14` | revista | · U15.2 (A0), · U101.22 (A14) |
| `A15` | revista | · U15.3 (A1), · U101.23 (A15) |
| `CPUCLK` | revista | · #BLK1.3 (CPUCLK), · U101.38 (EXTAL), · U104.37 (CPUCLK) |
| `CSR_N` | revista | · U15.11 (O1), · U104.15 (/CSR) |
| `CSW_N` | revista | · U15.12 (O0), · U104.14 (/CSW) |
| `E` | revista | · U23.13, · U101.34 (E) |
| `IO_EN_N` | revista | · D11.2 (A), · R49.2, · U15.15 (E) |
| `KB_RD_N` | revista | · U15.9 (O3), · U22.1 (OEa), · U22.19 (OEb) |
| `KB_WR_N` | revista | · U15.10 (O2), · U16.11 (Cp) |
| `RAM_CS_N` | revista | · U15.4 (O0), · U103.20 (/CS1) |
| `RD_N` | revista | · U23.3, · U103.22 (/OE) |
| `RESET_N` | revista | · C102.1, · D8.1 (K), · R27.2, · R28.2, · U101.37 (/RESET) |
| `ROM_Y3_N` | revista | · D10.1 (K), · U15.7 (O3) |
| `VAD0` | revista | · U14.10 (A7), · U21.10 (A7), · U104.10 (AD0) |
| `VAD1` | revista | · U14.6 (A6), · U21.6 (A6), · U104.9 (AD1) |
| `VAD2` | revista | · U14.7 (A5), · U21.7 (A5), · U104.8 (AD2) |
| `VAD3` | revista | · U14.8 (A4), · U21.8 (A4), · U104.7 (AD3) |
| `VAD4` | revista | · U14.11 (A3), · U21.11 (A3), · U104.6 (AD4) |
| `VAD5` | revista | · U14.12 (A2), · U21.12 (A2), · U104.5 (AD5) |
| `VAD6` | revista | · U14.13 (A1), · U21.13 (A1), · U104.4 (AD6) |
| `VAD7` | revista | · U14.14 (A0), · U21.14 (A0), · U104.3 (AD7) |
| `VCAS_N` | revista | · U14.16 (/CAS), · U21.16 (/CAS), · U104.2 (/CAS) |
| `VDP_BY` | revista | · #BLK1.6 (VDP_BY), · C105.1, · R105.1, · U104.35 (B-Y) |
| `VDP_CLK` | revista | · #BLK1.1 (VDP_CLK), · U104.40 (XTAL1) |
| `VDP_RESET_N` | revista | · R27.1, · T101.3 (C), · U104.34 (/RESET/SYNC) |
| `VDP_RST_B` | revista | · C101.1, · R26.2, · T101.2 (B) |
| `VDP_RY` | revista | · #BLK1.5 (VDP_RY), · C104.1, · R104.1, · U104.38 (R-Y) |
| `VDP_Y` | revista | · #BLK1.4 (VDP_Y), · C103.1, · R103.1, · U104.36 (Y) |
| `VRAS_N` | revista | · U14.5 (/RAS), · U21.5 (/RAS), · U104.1 (/RAS) |
| `VRD0` | revista | · U14.17 (I/O4), · U104.32 (RD0) |
| `VRD1` | revista | · U14.15 (I/O3), · U104.31 (RD1) |
| `VRD2` | revista | · U14.3 (I/O2), · U104.30 (RD2) |
| `VRD3` | revista | · U14.2 (I/O1), · U104.29 (RD3) |
| `VRD4` | revista | · U21.17 (I/O4), · U104.28 (RD4) |
| `VRD5` | revista | · U21.15 (I/O3), · U104.27 (RD5) |
| `VRD6` | revista | · U21.3 (I/O2), · U104.26 (RD6) |
| `VRD7` | revista | · U21.2 (I/O1), · U104.25 (RD7) |
| `VRESET_HIB` | revista | · #BLK1.2 (VRESET_HIB), · C101.2 |
| `VR_W` | revista | · U14.4 (/WE), · U21.4 (/WE), · U104.11 (R/W) |
| `BAT_POS` | fotos | · BT201.1 (+), · D208.2 (A) |
| `BKP_ALIM` | fotos | · C213.1, · D207.2 (A), · D210.2 (A), · R201.2 |
| `BOMBA` | fotos | · C204.2, · D205.2 (A), · D206.1 (K) |
| `BRUTO_12V` | fotos | · C201.1, · C202.1, · R201.1, · T201.4 (SC), · U201.1 (IN) |
| `BRUTO_24V` | fotos | · C203.1, · D202.1 (K), · D203.1 (K), · D209.2 (A), · U202.1 (IN) |
| `BRUTO_NEG` | fotos | · C205.2, · D206.2 (A), · U203.2 (VI) |
| `CA1` | fotos | · C204.1, · D201.1 (K), · D202.2 (A), · T201.5 (SB) |
| `CA2` | fotos | · D203.2 (A), · D204.1 (K), · T201.3 (SA) |
| `LED_K` | fotos | · D209.1 (K), · R203.1 |

## Alimentação

| Rede | Pinos medidos | Pinos segundo a revista | Pinos segundo as fotos (fonte) |
|---|---|---|---|
| `+5V` | CN1.a15, R29.1, R30.1, U16.1, U16.20, U22.20, U101.2, U101.4, U101.7, U101.33, U101.36, U102.1, U102.27, U102.28, U104.33 | C106.1, C107.1, C108.1, C109.1, C110.1, C111.1, C112.1, C113.1, C114.1, CN2.2, R28.1, R48.1, R49.1, R52.1, R53.1, R54.1, R55.1, R56.1, R57.1, R58.1, R59.1, U14.9, U15.16, U21.9, U23.14, U103.26 | C210.1, C211.1, C212.1, CN201.2, D210.1, U201.3 |
| `GND` | CN1.a17, CN1.b17, U14.1, U16.10, U21.1, U22.10, U102.22 | C102.2, C103.2, C104.2, C105.2, C106.2, C107.2, C108.2, C109.2, C110.2, C111.2, C112.2, C113.2, C114.2, CN2.5, D8.2, R103.2, R104.2, R105.2, U14.18, U15.8, U21.18, U23.7, U101.1, U101.39, U102.14, U103.14, U104.12 | BT201.2, C201.2, C202.2, C203.2, C205.1, C206.2, C207.2, C208.1, C209.1, C210.2, C211.2, C212.2, C213.2, C214.2, CN201.5, D201.2, D204.2, D205.1, R203.2, U201.2, U202.2, U203.1 |
| `+12V` | — | CN2.4, R26.1, T101.1 | C206.1, C207.1, CN201.4, U202.3 |
| `-5V` | CN1.b16 | CN2.1 | C208.2, C209.2, CN201.1, U203.3 |
| `+3V_BAT` | CN1.b1, U103.28 | CN2.3 | C214.1, CN201.3, D207.1, D208.1 |

## Ausência de ligação medida

- U104.16 × U101.3: /INT do VDP e /IRQ do 6809: sem continuidade.

## Peças

| Ref. | Valor | Revista | Referência | Folha |
|---|---|---|---|---|
| #BLK1 | Parte analógica (a desenhar) | Figs. 7, 8, 11 e 13 | provisória | Parte analógica (a desenhar) |
| C101 | 100nF | C16 | provisória | Vídeo |
| C102 | 22uF | C45 | provisória | CPU e memória |
| C103 | 220pF | C19 | provisória | Vídeo |
| C104 | 220pF | C18 | provisória | Vídeo |
| C105 | 220pF | C17 | provisória | Vídeo |
| C106 | 47uF | C46 (6809) | provisória | CN1 e alimentação |
| C107 | 100nF | C47 (139) | provisória | CN1 e alimentação |
| C108 | 100nF | C48 (EPROM) | provisória | CN1 e alimentação |
| C109 | 100nF | C49 (273) | provisória | CN1 e alimentação |
| C110 | 100nF | C50 (74LS00) | provisória | CN1 e alimentação |
| C111 | 100nF | C51 (244) | provisória | CN1 e alimentação |
| C112 | 100uF | C59 (VDP) | provisória | CN1 e alimentação |
| C113 | 100nF | C60 (VRAM) | provisória | CN1 e alimentação |
| C114 | 100nF | C61 (VRAM) | provisória | CN1 e alimentação |
| CN1 | CN1 interface (borda 2x18) | porta de expansão (Fig. 19) | lida na placa | CN1 e alimentação |
| CN2 | Alimentação (da fonte) | fonte na placa (Fig. 6) | lida na placa | CN1 e alimentação |
| CN3 | Membranas do teclado | J (16 vias) | lida na placa | Teclado |
| D8 | 1N751 (5,1 V) | D2 | lida na placa | Vídeo |
| D10 | 1N914 | D5 | lida na placa | CPU e memória |
| D11 | 1N914 | D6 | lida na placa | CPU e memória |
| R26 | 120k | R17 | lida na placa | Vídeo |
| R27 | 2k2 | R18 | lida na placa | Vídeo |
| R28 | 5k1 | R38 | lida na placa | CPU e memória |
| R29 | 4k7 | R8 | lida na placa | CPU e memória |
| R30 | 4k7 | R39 | lida na placa | CPU e memória |
| R48 | 3k3 | R41 | lida na placa | CPU e memória |
| R49 | 3k3 | R42 | lida na placa | CPU e memória |
| R52 | 10k | RN1 | lida na placa | Teclado |
| R53 | 10k | RN1 | lida na placa | Teclado |
| R54 | 10k | RN1 | lida na placa | Teclado |
| R55 | 10k | RN1 | lida na placa | Teclado |
| R56 | 10k | RN1 | lida na placa | Teclado |
| R57 | 10k | RN1 | lida na placa | Teclado |
| R58 | 10k | RN1 | lida na placa | Teclado |
| R59 | 10k | RN1 | lida na placa | Teclado |
| R103 | 470 | R21 | provisória | Vídeo |
| R104 | 470 | R20 | provisória | Vídeo |
| R105 | 470 | R19 | provisória | Vídeo |
| T101 | 2N3906 | Q2 | provisória | Vídeo |
| U14 | uPD41416C-15 | IC11 (4416) | lida na placa | Vídeo |
| U15 | 74LS139 | IC18 | lida na placa | CPU e memória |
| U16 | 74LS273 | IC21 | lida na placa | Teclado |
| U21 | uPD41416C-15 | IC12 (4416) | lida na placa | Vídeo |
| U22 | 74LS244 | IC22 | lida na placa | Teclado |
| U23 | 74LS00 | IC15 | lida na placa | CPU e memória |
| U101 | MC6809 | IC23 | provisória | CPU e memória |
| U102 | M27128A (VET 2.1) | IC19 (2764) | provisória | CPU e memória |
| U103 | HY6264LP-10 | IC20 (HM6264LP) | provisória | CPU e memória |
| U104 | TMS9128NL | IC10 | provisória | Vídeo |

## Peças da fonte

A placa da fonte não tem serigrafia de componentes: as referências são todas provisórias.

| Ref. | Valor | Onde fica |
|---|---|---|
| BT201 | 2x AA (3V) | suporte fora da placa (fios vermelho e preto) |
| C201 | 3300uF 25V | fora da placa, à esquerda (terminais com espaguete vermelho) |
| C202 | 2200uF 16V | preto, embaixo à esquerda |
| C203 | 2200uF 25V | laranja Siemens, em cima |
| C204 | 100uF 40V | laranja pequeno, no alto |
| C205 | 470uF 25V | azul médio, perto do 7905 |
| C206 | 100uF 50V | preto, abaixo do 7812 |
| C207 | 100nF | cerâmico, abaixo do C206 |
| C208 | 22uF 50V | azul pequeno, abaixo do 7905 |
| C209 | 100nF | cerâmico, logo abaixo do 7905 |
| C210 | 100uF 50V | preto, perto dos fios da bateria |
| C211 | 100nF | cerâmico, à esquerda do C210 |
| C212 | 1uF 50V | azul pequeno, abaixo do conector |
| C213 | 1000uF 25V | azul grande, central |
| C214 | 22uF 50V | azul pequeno, acima do azul grande |
| CN201 | Saída para a placa principal | barra de 5 pinos, fio preto = GND |
| D201 | 1N400x | ponte, 1º de cima |
| D202 | 1N400x | ponte, 2º de cima |
| D203 | 1N400x | ponte, 3º de cima |
| D204 | 1N400x | ponte, 4º de cima |
| D205 | 1N400x | deitado, no centro |
| D206 | 1N400x | em pé, ao lado do azul grande da direita |
| D207 | 1N4148 | vidro, o da esquerda do par |
| D208 | 1N4148 | vidro, o da direita do par |
| D209 | LED | painel (fios vermelho e creme) |
| D210 | 1N? (vidro) | vidro vermelho, em pé ao lado do cerâmico C211 |
| R201 | 100 | deitado, ao lado do 2200uF 16V |
| R203 | 2k4 | em pé, junto aos fios do LED |
| T201 | LIDER, 19,75 VAC com CT (medido) | fora da placa |
| U201 | LM340T-5 (7805) | fora da placa, no dissipador (fios amarelo, azul e laranja) |
| U202 | 7812 | TO-220 em pé, em cima à direita |
| U203 | 7905 | TO-220 em pé, ao lado do conector |
