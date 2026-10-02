# Roteiro de continuidade da placa principal

Gerado por `gen/gen_esquema.py`. Cada rede lista os pinos ligados a ela no esquema. **✓** = ligação
medida no aparelho; **·** = tirada da revista, ainda a medir. Pinos de U101-U104 (6809, EPROM,
RAM e VDP) usam a numeração do CI; as referências provisórias estão explicadas no
[README](README.md).

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
| `XROM_N` | medido | ✓ CN1.a14, ✓ U15.5 (O1) |
| `A1` | parcial | ✓ CN1.b3, · U15.13 (A1), ✓ U101.9 (A1), ✓ U102.9 (A1), ✓ U103.9 (A1) |
| `D0` | parcial | ✓ CN1.a2, · U16.3 (D0), · U22.18 (O0a), ✓ U101.31 (D0), ✓ U102.11 (D0), ✓ U103.11 (I/O0), ✓ U104.17 (CD7) |
| `D1` | parcial | ✓ CN1.a3, · U16.18 (D7), · U22.16 (O1a), ✓ U101.30 (D1), ✓ U102.12 (D1), ✓ U103.12 (I/O1), ✓ U104.18 (CD6) |
| `D2` | parcial | ✓ CN1.a4, · U16.4 (D1), · U22.3 (O3b), ✓ U101.29 (D2), ✓ U102.13 (D2), ✓ U103.13 (I/O2), ✓ U104.19 (CD5) |
| `D3` | parcial | ✓ CN1.a5, · U16.17 (D6), · U22.5 (O2b), ✓ U101.28 (D3), ✓ U102.15 (D3), ✓ U103.15 (I/O3), ✓ U104.20 (CD4) |
| `D4` | parcial | ✓ CN1.a6, · U16.7 (D2), · U22.14 (O2a), ✓ U101.27 (D4), ✓ U102.16 (D4), ✓ U103.16 (I/O4), ✓ U104.21 (CD3) |
| `D5` | parcial | ✓ CN1.a7, · U16.14 (D5), · U22.7 (O1b), ✓ U101.26 (D5), ✓ U102.17 (D5), ✓ U103.17 (I/O5), ✓ U104.22 (CD2) |
| `D6` | parcial | ✓ CN1.a8, · U16.8 (D3), · U22.12 (O3a), ✓ U101.25 (D6), ✓ U102.18 (D6), ✓ U103.18 (I/O6), ✓ U104.23 (CD1) |
| `D7` | parcial | ✓ CN1.a9, · U16.13 (D4), · U22.9 (O0b), ✓ U101.24 (D7), ✓ U102.19 (D7), ✓ U103.19 (I/O7), ✓ U104.24 (CD0) |
| `E_CLK_N` | parcial | ✓ CN1.a16, ✓ U15.1 (E), · U23.11 |
| `HALT_N` | parcial | ✓ CN1.a13, · R29.2, · U23.1, · U23.12, ✓ U101.40 (/HALT) |
| `IO_SEL_N` | parcial | ✓ CN1.a11, · D11.1 (K), ✓ U15.6 (O2) |
| `IRQ_N` | parcial | ✓ CN1.a1, · R30.2, ✓ U101.3 (/IRQ) |
| `ROM_SEL_N` | parcial | ✓ CN1.a10, · D10.2 (A), · R48.2, ✓ U102.20 (/CE) |
| `R_W` | parcial | ✓ CN1.a12, · U15.14 (A0), · U23.2, ✓ U101.32 (R/W), ✓ U103.27 (/WE) |
| `A14` | revista | · U15.2 (A0), · U101.22 (A14) |
| `A15` | revista | · U15.3 (A1), · U101.23 (A15) |
| `CPUCLK` | revista | · #BLK1.3 (CPUCLK), · U101.38 (EXTAL), · U104.37 (CPUCLK) |
| `CSR_N` | revista | · U15.11 (O1), · U104.15 (/CSR) |
| `CSW_N` | revista | · U15.12 (O0), · U104.14 (/CSW) |
| `E` | revista | · U23.13, · U101.34 (E) |
| `IO_EN_N` | revista | · D11.2 (A), · R49.2, · U15.15 (E) |
| `KB_C1` | revista | · CN2.1, · R52.2, · U22.2 (I0a) |
| `KB_C2` | revista | · CN2.2, · R53.2, · U22.4 (I1a) |
| `KB_C3` | revista | · CN2.3, · R54.2, · U22.17 (I3b) |
| `KB_C4` | revista | · CN2.4, · R55.2, · U22.15 (I2b) |
| `KB_C5` | revista | · CN2.5, · R56.2, · U22.6 (I2a) |
| `KB_C6` | revista | · CN2.6, · R57.2, · U22.13 (I1b) |
| `KB_C7` | revista | · CN2.7, · R58.2, · U22.8 (I3a) |
| `KB_C8` | revista | · CN2.8, · R59.2, · U22.11 (I0b) |
| `KB_L1` | revista | · CN2.9, · U16.2 (Q0) |
| `KB_L2` | revista | · CN2.10, · U16.19 (Q7) |
| `KB_L3` | revista | · CN2.11, · U16.5 (Q1) |
| `KB_L4` | revista | · CN2.12, · U16.16 (Q6) |
| `KB_L5` | revista | · CN2.13, · U16.6 (Q2) |
| `KB_L6` | revista | · CN2.14, · U16.15 (Q5) |
| `KB_L7` | revista | · CN2.15, · U16.9 (Q3) |
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

## Alimentação

| Rede | Pinos medidos | Pinos segundo a revista |
|---|---|---|
| `+5V` | CN1.a15, U101.2, U101.4, U101.7, U101.33, U101.36, U102.1, U102.27, U102.28, U104.33 | C106.1, C107.1, C108.1, C109.1, C110.1, C111.1, C112.1, C113.1, C114.1, R28.1, R29.1, R30.1, R48.1, R49.1, R52.1, R53.1, R54.1, R55.1, R56.1, R57.1, R58.1, R59.1, U14.9, U15.16, U16.1, U16.20, U21.9, U22.20, U23.14, U103.26 |
| `GND` | CN1.a17, CN1.b17 | C102.2, C103.2, C104.2, C105.2, C106.2, C107.2, C108.2, C109.2, C110.2, C111.2, C112.2, C113.2, C114.2, D8.2, R103.2, R104.2, R105.2, U14.1, U14.18, U15.8, U16.10, U21.1, U21.18, U22.10, U23.7, U101.1, U101.39, U102.14, U102.22, U103.14, U104.12 |
| `+12V` | — | R26.1, T101.1 |
| `-5V` | CN1.b16 | — |
| `+3V_BAT` | CN1.b1, U103.28 | — |

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
| CN2 | Membranas do teclado | J (16 vias) | provisória | Teclado |
| D8 | 1N751 (5,1 V) | D2 | lida na placa | Vídeo |
| D10 | 1N914 | D5 | lida na placa | CPU e memória |
| D11 | 1N914 | D6 | lida na placa | CPU e memória |
| R26 | 120k | R17 | lida na placa | Vídeo |
| R27 | 2k2 | R18 | lida na placa | Vídeo |
| R28 | 5k1 | R38 | lida na placa | CPU e memória |
| R29 | 4k7 | R39 | lida na placa | CPU e memória |
| R30 | 4k7 | R8 | lida na placa | CPU e memória |
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
