* ===========================================================================
*  VET 3000 "The Video Effects Titler" - firmware v2.1 (EPROM 27128, $C000-$FFFF)
*  TMS - Tecnologia em Micro Sistemas (Brasil), (C) 1988,1989
* ===========================================================================
*  Disassembly comentado gerado por tools/dis6809.py + disasm/hints.py.
*  Anotações, nomes e comentários: Copyright (C) 2026 Leonardo Roman da Rosa,
*  GPL-3.0-or-later. O código e os dados da ROM são (C) 1988,1989 TMS -
*  Tecnologia em Micro Sistemas; publicados aqui para estudo e preservação.
*  Remonta byte a byte idêntico ao dump original com o asm6809:
*      asm6809 -B -o vet3000_v2.1.bin vet3000_v2.1.asm
*  CRC32 bfdef5fa  SHA1 cd4da3cbda7fa12c9413d052bf69ee758cfe68b3
*
*  Hardware (ver docs/hardware.md):
*    CPU  MC6809 (clock de entrada 3,579545 MHz -> E = 0,895 MHz)
*    VDP  TMS9128NL + 16 KB de VRAM (2x uPD41416), modo Graphics II
*    RAM  8 KB estática HY6264 com bateria ($0000-$1FFF)
*    ROM  16 KB 27128 ($C000-$FFFF)
*    I/O  $8000 VDP dados, $8001 VDP controle, $8002 teclado
*    CART $4000-$7FFF no conector traseiro CN1 (assinaturas "OBJECT" e "FONT")
*
*  Mapa da ROM:
*    $C000-$D37F  fonte grande 16x24 (48 bytes/glifo, códigos $13-$7A)
*    $D380-$DD3F  fonte normal 8x24  (24 bytes/glifo, códigos $13-$7A)
*    $DD40-$DD9F  glifos $7B-$7E da fonte normal = logotipo "tms"
*    $DDA0-$DFFF  fonte 8x8 da tela de abertura (códigos $30-$7B)
*    $E000-$F403  programa e tabelas
*    $F2A3-$F390, $F404-$FFEF  livres ($FF)
*    $FFF0-$FFFF  vetores do 6809
*
*  Conjunto de caracteres interno (quase ASCII):
*    $13-$1E á â ã à é ê í ó ô õ ú ç    $1F-$2A Á Â Ã À É Ê Í Ó Ô Õ Ú Ç
*    $2B-$2F blocos gráficos            $30-$39 0-9   $3A :  $3B ,  $3C !
*    $3D ?  $3E .  $3F $  $40 ESPAÇO     $41-$5A A-Z   $5B %  $5C -  $5D '
*    $5E (  $5F )  $60 /                 $61-$7A a-z   $7B-$7E logotipo tms
*    bit 7 = 1 seleciona a fonte "B" (cursor sublinhado; cartucho FONT em $6000)

* ---------------------------------------------------------------------------
* Hardware registers and RAM variables
* ---------------------------------------------------------------------------
vdp_r0                   equ   $0000         ; cópia do registrador 0 do VDP (bit0 = EXTVID)
vdp_r1                   equ   $0001         ; cópia do registrador 1 do VDP (bit6 = display ligado)
backdrop                 equ   $0002         ; índice (0-15) da cor de fundo/borda (R7)
key_delay                equ   $0003         ; atraso de debounce do teclado (16 bits, $0100)
kbd_scan                 equ   $0005         ; padrão de varredura da linha do teclado
kbd_rows                 equ   $0006         ; contador de linhas na varredura
tmp07                    equ   $0007
tmp08                    equ   $0008
cell_vaddr               equ   $0009         ; endereço VRAM (padrões) da célula do cursor (16 bits)
cur_line                 equ   $000B         ; linha de texto atual (0-7)
cur_col                  equ   $000C         ; coluna atual (0-31; em fonte grande conta de 2 em 2)
tmp0e                    equ   $000E
cursor_mode              equ   $000F         ; cursor: 0 desligado, 1 bloco (fonte A), 2 sublinhado (fonte B)
key_shift                equ   $0010         ; SHIFT pressionado (1)
extvid_on                equ   $0011         ; bit7 = sobreposição de vídeo externo ativa
display_on               equ   $0012         ; bit6 = imagem ligada (BORDER BLK alterna)
obj_mode                 equ   $0013         ; modo OBJ ativo (objeto de 4 sprites visível)
page                     equ   $0014         ; página atual (0-29)
tmp15                    equ   $0015
tmp16                    equ   $0016
obj_color                equ   $0017         ; cor do objeto (índice 0-15)
obj_y                    equ   $0018         ; objeto: posição Y
obj_x                    equ   $0019         ; objeto: posição X
obj_shape                equ   $001A         ; objeto: forma (0-3)
color_idx                equ   $001C         ; índice da cor da linha (tecla COLOR)
caps_lock                equ   $001D         ; bit7 = CAPS (SHIFT+CURSOR)
key_code                 equ   $001E         ; código da tecla já traduzido
key_raw                  equ   $001F         ; código cru da tecla (tabela KEYMAP)
key_last                 equ   $0020         ; última tecla (auto-repetição)
cursor_pat               equ   $0021         ; 3 bytes com o desenho do cursor
line_color               equ   $0024         ; cor da linha no formato do VDP (frente<<4 | fundo)
key_ctrl                 equ   $0025         ; CONTROL pressionado (1)
key_mod3                 equ   $0026         ; 3o modificador (linha 7, bit 3) - lido mas nunca usado
page_entry               equ   $0027         ; número de página digitado (BCD) antes de PAGE
big_font                 equ   $0028         ; 1 = linha atual usa a fonte grande
fonta_small              equ   $0029         ; ponteiro da fonte normal A ($D380 ou cartucho)
fontb_small              equ   $002B         ; ponteiro da fonte normal B (bit7 do caractere)
key_repeat               equ   $002D         ; contador de auto-repetição (16 bits)
tmp2f                    equ   $002F
power_sig                equ   $0030         ; "POWER": RAM válida (mantida pela bateria)
fonta_big                equ   $0035         ; ponteiro da fonte grande A ($C000 ou cartucho)
fontb_big                equ   $0037         ; ponteiro da fonte grande B
irq_vector               equ   $0039         ; vetor RAM de IRQ/FIRQ/NMI (não usado pela ROM)
swi_vector               equ   $003B         ; vetor RAM de SWI (não usado pela ROM)
swi23_vector             equ   $003D         ; vetor RAM de SWI2/SWI3 (não usado pela ROM)
roll_stop                equ   $003F         ; 1 = barra de espaço interrompeu a rolagem
cmd_table                equ   $0040         ; 32 ponteiros de comandos (copiados de SYSTAB)
line_attr                equ   $00A0         ; atributos: 30 páginas x 8 linhas (bit0 fonte grande, bits4-7 cor)
page_text                equ   $0200         ; texto: 30 páginas x 8 linhas x 32 caracteres ($1E00 bytes)
CART0                    equ   $4000         ; cartucho: janela $4000-$7FFF (CN1)
CART0_ID                 equ   $4004         ; cartucho FONT: byte de identificação
CART0_ENTRY              equ   $4006         ; cartucho OBJECT: ponteiro para a palavra com o deslocamento da entrada
CART1                    equ   $6000
CART1_ID                 equ   $6004
CART1_ENTRY              equ   $6006
VDP_DATA                 equ   $8000         ; porta de dados do TMS9128 (MODE=0)
VDP_CTRL                 equ   $8001         ; registradores/endereço/status do TMS9128 (MODE=1)
KEYBOARD                 equ   $8002         ; escrita: linha do teclado (ativa em 0); leitura: colunas (ativas em 0)

		org	$C000

* ===========================================================================
*  Fonte grande: 104 glifos 16x24 (códigos $13-$7A), 48 bytes cada:
*  3 linhas de tiles x (tile esquerdo 8 bytes + tile direito 8 bytes).
* ===========================================================================
BIG_FONT:       fcb     $00,$00,$00,$00,$00,$00,$01,$03 ; C000  00 00 00 00 00 00 01 03
                fcb     $00,$00,$00,$00,$00,$E0,$C0,$80 ; C008  00 00 00 00 00 E0 C0 80
                fcb     $00,$1F,$3F,$3F,$3F,$0E,$3C,$3E ; C010  00 1F 3F 3F 3F 0E 3C 3E
                fcb     $00,$F8,$FC,$FC,$FC,$3C,$3C,$3C ; C018  00 F8 FC FC FC 3C 3C 3C
                fcb     $3F,$1F,$0F,$07,$00,$00,$00,$00 ; C020  3F 1F 0F 07 00 00 00 00
                fcb     $FC,$FC,$FC,$BC,$00,$00,$00,$00 ; C028  FC FC FC BC 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$01,$03,$06 ; C030  00 00 00 00 00 01 03 06
                fcb     $00,$00,$00,$00,$00,$80,$C0,$60 ; C038  00 00 00 00 00 80 C0 60
                fcb     $00,$1F,$3F,$3F,$3F,$0E,$3C,$3E ; C040  00 1F 3F 3F 3F 0E 3C 3E
                fcb     $00,$F8,$FC,$FC,$FC,$3C,$3C,$3C ; C048  00 F8 FC FC FC 3C 3C 3C
                fcb     $3F,$1F,$0F,$07,$00,$00,$00,$00 ; C050  3F 1F 0F 07 00 00 00 00
                fcb     $FC,$FC,$FC,$BC,$00,$00,$00,$00 ; C058  FC FC FC BC 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$07,$0D,$18 ; C060  00 00 00 00 00 07 0D 18
                fcb     $00,$00,$00,$00,$00,$18,$B0,$E0 ; C068  00 00 00 00 00 18 B0 E0
                fcb     $00,$1F,$3F,$3F,$3F,$0E,$3C,$3E ; C070  00 1F 3F 3F 3F 0E 3C 3E
                fcb     $00,$F8,$FC,$FC,$FC,$3C,$3C,$3C ; C078  00 F8 FC FC FC 3C 3C 3C
                fcb     $3F,$1F,$0F,$07,$00,$00,$00,$00 ; C080  3F 1F 0F 07 00 00 00 00
                fcb     $FC,$FC,$FC,$BC,$00,$00,$00,$00 ; C088  FC FC FC BC 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$07,$03,$01 ; C090  00 00 00 00 00 07 03 01
                fcb     $00,$00,$00,$00,$00,$00,$80,$C0 ; C098  00 00 00 00 00 00 80 C0
                fcb     $00,$1F,$3F,$3F,$3F,$0E,$3C,$3E ; C0A0  00 1F 3F 3F 3F 0E 3C 3E
                fcb     $00,$F8,$FC,$FC,$FC,$3C,$3C,$3C ; C0A8  00 F8 FC FC FC 3C 3C 3C
                fcb     $3F,$1F,$0F,$07,$00,$00,$00,$00 ; C0B0  3F 1F 0F 07 00 00 00 00
                fcb     $FC,$FC,$FC,$BC,$00,$00,$00,$00 ; C0B8  FC FC FC BC 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$01,$03 ; C0C0  00 00 00 00 00 00 01 03
                fcb     $00,$00,$00,$00,$00,$E0,$C0,$80 ; C0C8  00 00 00 00 00 E0 C0 80
                fcb     $00,$07,$0F,$1F,$3E,$3F,$3C,$3E ; C0D0  00 07 0F 1F 3E 3F 3C 3E
                fcb     $00,$E0,$F0,$F8,$3C,$FC,$00,$3C ; C0D8  00 E0 F0 F8 3C FC 00 3C
                fcb     $3F,$1F,$0F,$07,$00,$00,$00,$00 ; C0E0  3F 1F 0F 07 00 00 00 00
                fcb     $FC,$F8,$F0,$E0,$00,$00,$00,$00 ; C0E8  FC F8 F0 E0 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$01,$03,$06 ; C0F0  00 00 00 00 00 01 03 06
                fcb     $00,$00,$00,$00,$00,$80,$C0,$60 ; C0F8  00 00 00 00 00 80 C0 60
                fcb     $00,$07,$0F,$1F,$3E,$3F,$3C,$3E ; C100  00 07 0F 1F 3E 3F 3C 3E
                fcb     $00,$E0,$F0,$F8,$3C,$FC,$00,$3C ; C108  00 E0 F0 F8 3C FC 00 3C
                fcb     $3F,$1F,$0F,$07,$00,$00,$00,$00 ; C110  3F 1F 0F 07 00 00 00 00
                fcb     $FC,$F8,$F0,$E0,$00,$00,$00,$00 ; C118  FC F8 F0 E0 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$01,$03 ; C120  00 00 00 00 00 00 01 03
                fcb     $00,$00,$00,$00,$00,$E0,$C0,$80 ; C128  00 00 00 00 00 E0 C0 80
                fcb     $00,$03,$03,$03,$03,$03,$03,$03 ; C130  00 03 03 03 03 03 03 03
                fcb     $00,$C0,$C0,$C0,$C0,$C0,$C0,$C0 ; C138  00 C0 C0 C0 C0 C0 C0 C0
                fcb     $03,$03,$03,$03,$00,$00,$00,$00 ; C140  03 03 03 03 00 00 00 00
                fcb     $C0,$C0,$C0,$C0,$00,$00,$00,$00 ; C148  C0 C0 C0 C0 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$01,$03 ; C150  00 00 00 00 00 00 01 03
                fcb     $00,$00,$00,$00,$00,$E0,$C0,$80 ; C158  00 00 00 00 00 E0 C0 80
                fcb     $00,$07,$0F,$1F,$3F,$3E,$3C,$3E ; C160  00 07 0F 1F 3F 3E 3C 3E
                fcb     $00,$E0,$F0,$F8,$FC,$7C,$3C,$7C ; C168  00 E0 F0 F8 FC 7C 3C 7C
                fcb     $3F,$1F,$0F,$07,$00,$00,$00,$00 ; C170  3F 1F 0F 07 00 00 00 00
                fcb     $FC,$F8,$F0,$E0,$00,$00,$00,$00 ; C178  FC F8 F0 E0 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$01,$03,$06 ; C180  00 00 00 00 00 01 03 06
                fcb     $00,$00,$00,$00,$00,$80,$C0,$60 ; C188  00 00 00 00 00 80 C0 60
                fcb     $00,$07,$0F,$1F,$3F,$3E,$3C,$3E ; C190  00 07 0F 1F 3F 3E 3C 3E
                fcb     $00,$E0,$F0,$F8,$FC,$7C,$3C,$7C ; C198  00 E0 F0 F8 FC 7C 3C 7C
                fcb     $3F,$1F,$0F,$07,$00,$00,$00,$00 ; C1A0  3F 1F 0F 07 00 00 00 00
                fcb     $FC,$F8,$F0,$E0,$00,$00,$00,$00 ; C1A8  FC F8 F0 E0 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$07,$0D,$18 ; C1B0  00 00 00 00 00 07 0D 18
                fcb     $00,$00,$00,$00,$00,$18,$B0,$E0 ; C1B8  00 00 00 00 00 18 B0 E0
                fcb     $00,$07,$0F,$1F,$3F,$3E,$3C,$3E ; C1C0  00 07 0F 1F 3F 3E 3C 3E
                fcb     $00,$E0,$F0,$F8,$FC,$7C,$3C,$7C ; C1C8  00 E0 F0 F8 FC 7C 3C 7C
                fcb     $3F,$1F,$0F,$07,$00,$00,$00,$00 ; C1D0  3F 1F 0F 07 00 00 00 00
                fcb     $FC,$F8,$F0,$E0,$00,$00,$00,$00 ; C1D8  FC F8 F0 E0 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$01,$03 ; C1E0  00 00 00 00 00 00 01 03
                fcb     $00,$00,$00,$00,$00,$E0,$C0,$80 ; C1E8  00 00 00 00 00 E0 C0 80
                fcb     $00,$3C,$3C,$3C,$3C,$3C,$3C,$3E ; C1F0  00 3C 3C 3C 3C 3C 3C 3E
                fcb     $00,$3C,$3C,$3C,$3C,$3C,$3C,$7C ; C1F8  00 3C 3C 3C 3C 3C 3C 7C
                fcb     $3F,$1F,$0F,$07,$00,$00,$00,$00 ; C200  3F 1F 0F 07 00 00 00 00
                fcb     $FC,$F8,$F0,$E0,$00,$00,$00,$00 ; C208  FC F8 F0 E0 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; C210  00 00 00 00 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; C218  00 00 00 00 00 00 00 00
                fcb     $00,$07,$0F,$1F,$3F,$3E,$3C,$3E ; C220  00 07 0F 1F 3F 3E 3C 3E
                fcb     $00,$E0,$F0,$F8,$FC,$3C,$00,$3C ; C228  00 E0 F0 F8 FC 3C 00 3C
                fcb     $3F,$1F,$0F,$07,$01,$03,$06,$00 ; C230  3F 1F 0F 07 01 03 06 00
                fcb     $FC,$F8,$F0,$E0,$80,$00,$00,$00 ; C238  FC F8 F0 E0 80 00 00 00
                fcb     $00,$00,$00,$01,$03,$03,$07,$0F ; C240  00 00 00 01 03 03 07 0F
                fcb     $00,$00,$E0,$C0,$80,$C0,$E0,$F0 ; C248  00 00 E0 C0 80 C0 E0 F0
                fcb     $1F,$3E,$3C,$3C,$3F,$3F,$3F,$3F ; C250  1F 3E 3C 3C 3F 3F 3F 3F
                fcb     $F8,$7C,$3C,$3C,$FC,$FC,$FC,$FC ; C258  F8 7C 3C 3C FC FC FC FC
                fcb     $3C,$3C,$3C,$3C,$00,$00,$00,$00 ; C260  3C 3C 3C 3C 00 00 00 00
                fcb     $3C,$3C,$3C,$3C,$00,$00,$00,$00 ; C268  3C 3C 3C 3C 00 00 00 00
                fcb     $00,$00,$01,$03,$06,$03,$07,$0F ; C270  00 00 01 03 06 03 07 0F
                fcb     $00,$00,$80,$C0,$60,$C0,$E0,$F0 ; C278  00 00 80 C0 60 C0 E0 F0
                fcb     $1F,$3E,$3C,$3C,$3F,$3F,$3F,$3F ; C280  1F 3E 3C 3C 3F 3F 3F 3F
                fcb     $F8,$7C,$3C,$3C,$FC,$FC,$FC,$FC ; C288  F8 7C 3C 3C FC FC FC FC
                fcb     $3C,$3C,$3C,$3C,$00,$00,$00,$00 ; C290  3C 3C 3C 3C 00 00 00 00
                fcb     $3C,$3C,$3C,$3C,$00,$00,$00,$00 ; C298  3C 3C 3C 3C 00 00 00 00
                fcb     $00,$00,$07,$0D,$18,$03,$07,$0F ; C2A0  00 00 07 0D 18 03 07 0F
                fcb     $00,$00,$18,$B0,$E0,$C0,$E0,$F0 ; C2A8  00 00 18 B0 E0 C0 E0 F0
                fcb     $1F,$3E,$3C,$3C,$3F,$3F,$3F,$3F ; C2B0  1F 3E 3C 3C 3F 3F 3F 3F
                fcb     $F8,$7C,$3C,$3C,$FC,$FC,$FC,$FC ; C2B8  F8 7C 3C 3C FC FC FC FC
                fcb     $3C,$3C,$3C,$3C,$00,$00,$00,$00 ; C2C0  3C 3C 3C 3C 00 00 00 00
                fcb     $3C,$3C,$3C,$3C,$00,$00,$00,$00 ; C2C8  3C 3C 3C 3C 00 00 00 00
                fcb     $00,$00,$07,$03,$01,$03,$07,$0F ; C2D0  00 00 07 03 01 03 07 0F
                fcb     $00,$00,$00,$80,$C0,$C0,$E0,$F0 ; C2D8  00 00 00 80 C0 C0 E0 F0
                fcb     $1F,$3E,$3C,$3C,$3F,$3F,$3F,$3F ; C2E0  1F 3E 3C 3C 3F 3F 3F 3F
                fcb     $F8,$7C,$3C,$3C,$FC,$FC,$FC,$FC ; C2E8  F8 7C 3C 3C FC FC FC FC
                fcb     $3C,$3C,$3C,$3C,$00,$00,$00,$00 ; C2F0  3C 3C 3C 3C 00 00 00 00
                fcb     $3C,$3C,$3C,$3C,$00,$00,$00,$00 ; C2F8  3C 3C 3C 3C 00 00 00 00
                fcb     $00,$00,$00,$01,$03,$3F,$3F,$3F ; C300  00 00 00 01 03 3F 3F 3F
                fcb     $00,$00,$E0,$C0,$80,$FC,$FC,$FC ; C308  00 00 E0 C0 80 FC FC FC
                fcb     $3C,$3C,$3F,$3F,$3F,$3F,$3C,$3C ; C310  3C 3C 3F 3F 3F 3F 3C 3C
                fcb     $00,$00,$C0,$C0,$C0,$C0,$00,$00 ; C318  00 00 C0 C0 C0 C0 00 00
                fcb     $3F,$3F,$3F,$3F,$00,$00,$00,$00 ; C320  3F 3F 3F 3F 00 00 00 00
                fcb     $FC,$FC,$FC,$FC,$00,$00,$00,$00 ; C328  FC FC FC FC 00 00 00 00
                fcb     $00,$00,$01,$03,$06,$3F,$3F,$3F ; C330  00 00 01 03 06 3F 3F 3F
                fcb     $00,$00,$80,$C0,$60,$FC,$FC,$FC ; C338  00 00 80 C0 60 FC FC FC
                fcb     $3C,$3C,$3F,$3F,$3F,$3F,$3C,$3C ; C340  3C 3C 3F 3F 3F 3F 3C 3C
                fcb     $00,$00,$C0,$C0,$C0,$C0,$00,$00 ; C348  00 00 C0 C0 C0 C0 00 00
                fcb     $3F,$3F,$3F,$3F,$00,$00,$00,$00 ; C350  3F 3F 3F 3F 00 00 00 00
                fcb     $FC,$FC,$FC,$FC,$00,$00,$00,$00 ; C358  FC FC FC FC 00 00 00 00
                fcb     $00,$00,$00,$01,$03,$0F,$0F,$0F ; C360  00 00 00 01 03 0F 0F 0F
                fcb     $00,$00,$E0,$C0,$80,$F0,$F0,$F0 ; C368  00 00 E0 C0 80 F0 F0 F0
                fcb     $03,$03,$03,$03,$03,$03,$03,$03 ; C370  03 03 03 03 03 03 03 03
                fcb     $C0,$C0,$C0,$C0,$C0,$C0,$C0,$C0 ; C378  C0 C0 C0 C0 C0 C0 C0 C0
                fcb     $0F,$0F,$0F,$0F,$00,$00,$00,$00 ; C380  0F 0F 0F 0F 00 00 00 00
                fcb     $F0,$F0,$F0,$F0,$00,$00,$00,$00 ; C388  F0 F0 F0 F0 00 00 00 00
                fcb     $00,$00,$00,$01,$03,$07,$0F,$1F ; C390  00 00 00 01 03 07 0F 1F
                fcb     $00,$00,$E0,$C0,$80,$E0,$F0,$F8 ; C398  00 00 E0 C0 80 E0 F0 F8
                fcb     $3E,$3C,$3C,$3C,$3C,$3C,$3C,$3E ; C3A0  3E 3C 3C 3C 3C 3C 3C 3E
                fcb     $7C,$3C,$3C,$3C,$3C,$3C,$3C,$7C ; C3A8  7C 3C 3C 3C 3C 3C 3C 7C
                fcb     $1F,$0F,$07,$03,$00,$00,$00,$00 ; C3B0  1F 0F 07 03 00 00 00 00
                fcb     $F8,$F0,$E0,$C0,$00,$00,$00,$00 ; C3B8  F8 F0 E0 C0 00 00 00 00
                fcb     $00,$00,$01,$03,$06,$07,$0F,$1F ; C3C0  00 00 01 03 06 07 0F 1F
                fcb     $00,$00,$80,$C0,$60,$E0,$F0,$F8 ; C3C8  00 00 80 C0 60 E0 F0 F8
                fcb     $3E,$3C,$3C,$3C,$3C,$3C,$3C,$3E ; C3D0  3E 3C 3C 3C 3C 3C 3C 3E
                fcb     $7C,$3C,$3C,$3C,$3C,$3C,$3C,$7C ; C3D8  7C 3C 3C 3C 3C 3C 3C 7C
                fcb     $1F,$0F,$07,$03,$00,$00,$00,$00 ; C3E0  1F 0F 07 03 00 00 00 00
                fcb     $F8,$F0,$E0,$C0,$00,$00,$00,$00 ; C3E8  F8 F0 E0 C0 00 00 00 00
                fcb     $00,$00,$00,$07,$0D,$1B,$0F,$1F ; C3F0  00 00 00 07 0D 1B 0F 1F
                fcb     $00,$00,$18,$B0,$E0,$E0,$F0,$F8 ; C3F8  00 00 18 B0 E0 E0 F0 F8
                fcb     $3E,$3C,$3C,$3C,$3C,$3C,$3C,$3E ; C400  3E 3C 3C 3C 3C 3C 3C 3E
                fcb     $7C,$3C,$3C,$3C,$3C,$3C,$3C,$7C ; C408  7C 3C 3C 3C 3C 3C 3C 7C
                fcb     $1F,$0F,$07,$03,$00,$00,$00,$00 ; C410  1F 0F 07 03 00 00 00 00
                fcb     $F8,$F0,$E0,$C0,$00,$00,$00,$00 ; C418  F8 F0 E0 C0 00 00 00 00
                fcb     $00,$00,$00,$01,$03,$3C,$3C,$3C ; C420  00 00 00 01 03 3C 3C 3C
                fcb     $00,$00,$E0,$C0,$80,$3C,$3C,$3C ; C428  00 00 E0 C0 80 3C 3C 3C
                fcb     $3C,$3C,$3C,$3C,$3C,$3C,$3C,$3E ; C430  3C 3C 3C 3C 3C 3C 3C 3E
                fcb     $3C,$3C,$3C,$3C,$3C,$3C,$3C,$7C ; C438  3C 3C 3C 3C 3C 3C 3C 7C
                fcb     $1F,$0F,$07,$03,$00,$00,$00,$00 ; C440  1F 0F 07 03 00 00 00 00
                fcb     $F8,$F0,$E0,$C0,$00,$00,$00,$00 ; C448  F8 F0 E0 C0 00 00 00 00
                fcb     $00,$00,$00,$00,$03,$07,$0F,$1F ; C450  00 00 00 00 03 07 0F 1F
                fcb     $00,$00,$00,$00,$C0,$E0,$F0,$F8 ; C458  00 00 00 00 C0 E0 F0 F8
                fcb     $3E,$3C,$3C,$3C,$3C,$3C,$3C,$3E ; C460  3E 3C 3C 3C 3C 3C 3C 3E
                fcb     $7C,$3C,$00,$00,$00,$00,$3C,$7C ; C468  7C 3C 00 00 00 00 3C 7C
                fcb     $1F,$0F,$07,$03,$01,$03,$06,$00 ; C470  1F 0F 07 03 01 03 06 00
                fcb     $F8,$F0,$E0,$C0,$80,$00,$00,$00 ; C478  F8 F0 E0 C0 80 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; C480  00 00 00 00 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; C488  00 00 00 00 00 00 00 00
                fcb     $00,$00,$00,$00,$FF,$FF,$FF,$FF ; C490  00 00 00 00 FF FF FF FF
                fcb     $00,$00,$00,$00,$FF,$FF,$FF,$FF ; C498  00 00 00 00 FF FF FF FF
                fcb     $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; C4A0  FF FF FF FF FF FF FF FF
                fcb     $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; C4A8  FF FF FF FF FF FF FF FF
                fcb     $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; C4B0  FF FF FF FF FF FF FF FF
                fcb     $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; C4B8  FF FF FF FF FF FF FF FF
                fcb     $FF,$FF,$FF,$FF,$00,$00,$00,$00 ; C4C0  FF FF FF FF 00 00 00 00
                fcb     $FF,$FF,$FF,$FF,$00,$00,$00,$00 ; C4C8  FF FF FF FF 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; C4D0  00 00 00 00 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; C4D8  00 00 00 00 00 00 00 00
                fcb     $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; C4E0  FF FF FF FF FF FF FF FF
                fcb     $C0,$C0,$C0,$C0,$C0,$C0,$C0,$C0 ; C4E8  C0 C0 C0 C0 C0 C0 C0 C0
                fcb     $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; C4F0  FF FF FF FF FF FF FF FF
                fcb     $C0,$C0,$C0,$C0,$C0,$C0,$C0,$C0 ; C4F8  C0 C0 C0 C0 C0 C0 C0 C0
                fcb     $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; C500  FF FF FF FF FF FF FF FF
                fcb     $C0,$C0,$C0,$C0,$C0,$C0,$C0,$C0 ; C508  C0 C0 C0 C0 C0 C0 C0 C0
                fcb     $03,$03,$03,$03,$03,$03,$03,$03 ; C510  03 03 03 03 03 03 03 03
                fcb     $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; C518  FF FF FF FF FF FF FF FF
                fcb     $03,$03,$03,$03,$03,$03,$03,$03 ; C520  03 03 03 03 03 03 03 03
                fcb     $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; C528  FF FF FF FF FF FF FF FF
                fcb     $03,$03,$03,$03,$03,$03,$03,$03 ; C530  03 03 03 03 03 03 03 03
                fcb     $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; C538  FF FF FF FF FF FF FF FF
                fcb     $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; C540  FF FF FF FF FF FF FF FF
                fcb     $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; C548  FF FF FF FF FF FF FF FF
                fcb     $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; C550  FF FF FF FF FF FF FF FF
                fcb     $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; C558  FF FF FF FF FF FF FF FF
                fcb     $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; C560  FF FF FF FF FF FF FF FF
                fcb     $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; C568  FF FF FF FF FF FF FF FF
                fcb     $00,$00,$00,$00,$01,$03,$07,$0F ; C570  00 00 00 00 01 03 07 0F
                fcb     $00,$00,$00,$00,$80,$C0,$E0,$F0 ; C578  00 00 00 00 80 C0 E0 F0
                fcb     $1F,$3E,$3C,$3C,$3C,$3C,$3E,$1F ; C580  1F 3E 3C 3C 3C 3C 3E 1F
                fcb     $F8,$7C,$3C,$3C,$3C,$3C,$7C,$F8 ; C588  F8 7C 3C 3C 3C 3C 7C F8
                fcb     $0F,$07,$03,$01,$00,$00,$00,$00 ; C590  0F 07 03 01 00 00 00 00
                fcb     $F0,$E0,$C0,$80,$00,$00,$00,$00 ; C598  F0 E0 C0 80 00 00 00 00
                fcb     $00,$00,$00,$00,$01,$03,$07,$0F ; C5A0  00 00 00 00 01 03 07 0F
                fcb     $00,$00,$00,$00,$C0,$C0,$C0,$C0 ; C5A8  00 00 00 00 C0 C0 C0 C0
                fcb     $03,$03,$03,$03,$03,$03,$03,$03 ; C5B0  03 03 03 03 03 03 03 03
                fcb     $C0,$C0,$C0,$C0,$C0,$C0,$C0,$C0 ; C5B8  C0 C0 C0 C0 C0 C0 C0 C0
                fcb     $0F,$0F,$0F,$0F,$00,$00,$00,$00 ; C5C0  0F 0F 0F 0F 00 00 00 00
                fcb     $F0,$F0,$F0,$F0,$00,$00,$00,$00 ; C5C8  F0 F0 F0 F0 00 00 00 00
                fcb     $00,$00,$00,$00,$03,$07,$0F,$1F ; C5D0  00 00 00 00 03 07 0F 1F
                fcb     $00,$00,$00,$00,$C0,$E0,$F0,$F8 ; C5D8  00 00 00 00 C0 E0 F0 F8
                fcb     $3E,$3C,$00,$00,$03,$0F,$3F,$3E ; C5E0  3E 3C 00 00 03 0F 3F 3E
                fcb     $7C,$3C,$3C,$FC,$F8,$E0,$80,$00 ; C5E8  7C 3C 3C FC F8 E0 80 00
                fcb     $3F,$3F,$3F,$3F,$00,$00,$00,$00 ; C5F0  3F 3F 3F 3F 00 00 00 00
                fcb     $FC,$FC,$FC,$FC,$00,$00,$00,$00 ; C5F8  FC FC FC FC 00 00 00 00
                fcb     $00,$00,$00,$00,$3F,$3F,$3F,$3F ; C600  00 00 00 00 3F 3F 3F 3F
                fcb     $00,$00,$00,$00,$FC,$FC,$FC,$FC ; C608  00 00 00 00 FC FC FC FC
                fcb     $00,$00,$00,$01,$01,$00,$3C,$3E ; C610  00 00 00 01 01 00 3C 3E
                fcb     $3C,$78,$F0,$F0,$F8,$3C,$3C,$7C ; C618  3C 78 F0 F0 F8 3C 3C 7C
                fcb     $1F,$1F,$07,$03,$00,$00,$00,$00 ; C620  1F 1F 07 03 00 00 00 00
                fcb     $F8,$F0,$E0,$C0,$00,$00,$00,$00 ; C628  F8 F0 E0 C0 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$01,$03,$07 ; C630  00 00 00 00 00 01 03 07
                fcb     $00,$00,$00,$00,$F0,$F0,$F0,$F0 ; C638  00 00 00 00 F0 F0 F0 F0
                fcb     $0F,$1F,$3E,$3C,$3F,$3F,$3F,$3F ; C640  0F 1F 3E 3C 3F 3F 3F 3F
                fcb     $F0,$F0,$F0,$F0,$FC,$FC,$FC,$FC ; C648  F0 F0 F0 F0 FC FC FC FC
                fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; C650  00 00 00 00 00 00 00 00
                fcb     $F0,$F0,$F0,$F0,$00,$00,$00,$00 ; C658  F0 F0 F0 F0 00 00 00 00
                fcb     $00,$00,$00,$00,$3F,$3F,$3F,$3F ; C660  00 00 00 00 3F 3F 3F 3F
                fcb     $00,$00,$00,$00,$FC,$FC,$FC,$FC ; C668  00 00 00 00 FC FC FC FC
                fcb     $3C,$3F,$3F,$3F,$00,$00,$3C,$3E ; C670  3C 3F 3F 3F 00 00 3C 3E
                fcb     $00,$C0,$F0,$FC,$FC,$3C,$3C,$7C ; C678  00 C0 F0 FC FC 3C 3C 7C
                fcb     $1F,$0F,$07,$03,$00,$00,$00,$00 ; C680  1F 0F 07 03 00 00 00 00
                fcb     $F8,$F0,$E0,$C0,$00,$00,$00,$00 ; C688  F8 F0 E0 C0 00 00 00 00
                fcb     $00,$00,$00,$00,$03,$07,$0F,$1F ; C690  00 00 00 00 03 07 0F 1F
                fcb     $00,$00,$00,$00,$C0,$E0,$F0,$F8 ; C698  00 00 00 00 C0 E0 F0 F8
                fcb     $3E,$3C,$3E,$3F,$3F,$3E,$3C,$3E ; C6A0  3E 3C 3E 3F 3F 3E 3C 3E
                fcb     $7C,$3C,$00,$E0,$F8,$7C,$3C,$7C ; C6A8  7C 3C 00 E0 F8 7C 3C 7C
                fcb     $1F,$0F,$07,$03,$00,$00,$00,$00 ; C6B0  1F 0F 07 03 00 00 00 00
                fcb     $F8,$F0,$E0,$C0,$00,$00,$00,$00 ; C6B8  F8 F0 E0 C0 00 00 00 00
                fcb     $00,$00,$00,$00,$3F,$3F,$3F,$3F ; C6C0  00 00 00 00 3F 3F 3F 3F
                fcb     $00,$00,$00,$00,$FC,$FC,$FC,$FC ; C6C8  00 00 00 00 FC FC FC FC
                fcb     $00,$00,$00,$01,$03,$07,$0F,$0F ; C6D0  00 00 00 01 03 07 0F 0F
                fcb     $3C,$7C,$F8,$F0,$E0,$C0,$80,$00 ; C6D8  3C 7C F8 F0 E0 C0 80 00
                fcb     $0F,$0F,$0F,$0F,$00,$00,$00,$00 ; C6E0  0F 0F 0F 0F 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; C6E8  00 00 00 00 00 00 00 00
                fcb     $00,$00,$00,$00,$03,$07,$0F,$1F ; C6F0  00 00 00 00 03 07 0F 1F
                fcb     $00,$00,$00,$00,$C0,$E0,$F0,$F8 ; C6F8  00 00 00 00 C0 E0 F0 F8
                fcb     $3E,$3C,$3E,$1F,$1F,$3E,$3C,$3E ; C700  3E 3C 3E 1F 1F 3E 3C 3E
                fcb     $7C,$3C,$7C,$F8,$F8,$7C,$3C,$7C ; C708  7C 3C 7C F8 F8 7C 3C 7C
                fcb     $1F,$0F,$07,$03,$00,$00,$00,$00 ; C710  1F 0F 07 03 00 00 00 00
                fcb     $F8,$F0,$E0,$C0,$00,$00,$00,$00 ; C718  F8 F0 E0 C0 00 00 00 00
                fcb     $00,$00,$00,$00,$03,$07,$0F,$1F ; C720  00 00 00 00 03 07 0F 1F
                fcb     $00,$00,$00,$00,$C0,$E0,$F0,$F8 ; C728  00 00 00 00 C0 E0 F0 F8
                fcb     $3E,$3C,$3E,$1F,$0F,$00,$3C,$3E ; C730  3E 3C 3E 1F 0F 00 3C 3E
                fcb     $7C,$3C,$7C,$FC,$FC,$7C,$3C,$7C ; C738  7C 3C 7C FC FC 7C 3C 7C
                fcb     $1F,$0F,$07,$03,$00,$00,$00,$00 ; C740  1F 0F 07 03 00 00 00 00
                fcb     $F8,$F0,$E0,$C0,$00,$00,$00,$00 ; C748  F8 F0 E0 C0 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; C750  00 00 00 00 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; C758  00 00 00 00 00 00 00 00
                fcb     $00,$01,$03,$03,$01,$00,$00,$01 ; C760  00 01 03 03 01 00 00 01
                fcb     $00,$80,$C0,$C0,$80,$00,$00,$80 ; C768  00 80 C0 C0 80 00 00 80
                fcb     $03,$03,$01,$00,$00,$00,$00,$00 ; C770  03 03 01 00 00 00 00 00
                fcb     $C0,$C0,$80,$00,$00,$00,$00,$00 ; C778  C0 C0 80 00 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; C780  00 00 00 00 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; C788  00 00 00 00 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; C790  00 00 00 00 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; C798  00 00 00 00 00 00 00 00
                fcb     $00,$00,$03,$03,$03,$07,$06,$00 ; C7A0  00 00 03 03 03 07 06 00
                fcb     $00,$00,$80,$80,$00,$00,$00,$00 ; C7A8  00 00 80 80 00 00 00 00
                fcb     $00,$00,$00,$00,$03,$03,$03,$03 ; C7B0  00 00 00 00 03 03 03 03
                fcb     $00,$00,$00,$00,$C0,$C0,$C0,$C0 ; C7B8  00 00 00 00 C0 C0 C0 C0
                fcb     $03,$03,$03,$03,$03,$03,$03,$00 ; C7C0  03 03 03 03 03 03 03 00
                fcb     $C0,$C0,$C0,$C0,$C0,$C0,$C0,$00 ; C7C8  C0 C0 C0 C0 C0 C0 C0 00
                fcb     $01,$03,$03,$01,$00,$00,$00,$00 ; C7D0  01 03 03 01 00 00 00 00
                fcb     $80,$C0,$C0,$80,$00,$00,$00,$00 ; C7D8  80 C0 C0 80 00 00 00 00
                fcb     $00,$00,$00,$00,$03,$07,$0F,$1F ; C7E0  00 00 00 00 03 07 0F 1F
                fcb     $00,$00,$00,$00,$C0,$E0,$F0,$F8 ; C7E8  00 00 00 00 C0 E0 F0 F8
                fcb     $1E,$1E,$00,$01,$03,$03,$03,$00 ; C7F0  1E 1E 00 01 03 03 03 00
                fcb     $78,$78,$F8,$F0,$E0,$C0,$C0,$00 ; C7F8  78 78 F8 F0 E0 C0 C0 00
                fcb     $01,$03,$03,$01,$00,$00,$00,$00 ; C800  01 03 03 01 00 00 00 00
                fcb     $80,$C0,$C0,$80,$00,$00,$00,$00 ; C808  80 C0 C0 80 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; C810  00 00 00 00 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; C818  00 00 00 00 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; C820  00 00 00 00 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; C828  00 00 00 00 00 00 00 00
                fcb     $01,$03,$03,$01,$00,$00,$00,$00 ; C830  01 03 03 01 00 00 00 00
                fcb     $80,$C0,$C0,$80,$00,$00,$00,$00 ; C838  80 C0 C0 80 00 00 00 00
                fcb     $00,$00,$00,$00,$03,$07,$0F,$1F ; C840  00 00 00 00 03 07 0F 1F
                fcb     $00,$00,$00,$00,$C0,$E0,$F0,$F8 ; C848  00 00 00 00 C0 E0 F0 F8
                fcb     $3F,$3D,$3F,$1F,$07,$01,$3D,$3F ; C850  3F 3D 3F 1F 07 01 3D 3F
                fcb     $FC,$BC,$80,$E0,$F8,$FC,$BC,$FC ; C858  FC BC 80 E0 F8 FC BC FC
                fcb     $1F,$0F,$07,$03,$00,$00,$00,$00 ; C860  1F 0F 07 03 00 00 00 00
                fcb     $F8,$F0,$E0,$C0,$00,$00,$00,$00 ; C868  F8 F0 E0 C0 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; C870  00 00 00 00 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; C878  00 00 00 00 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; C880  00 00 00 00 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; C888  00 00 00 00 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; C890  00 00 00 00 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; C898  00 00 00 00 00 00 00 00
                fcb     $00,$00,$00,$00,$01,$03,$07,$0F ; C8A0  00 00 00 00 01 03 07 0F
                fcb     $00,$00,$00,$00,$80,$C0,$E0,$F0 ; C8A8  00 00 00 00 80 C0 E0 F0
                fcb     $1F,$3E,$3C,$3C,$3F,$3F,$3F,$3F ; C8B0  1F 3E 3C 3C 3F 3F 3F 3F
                fcb     $F8,$7C,$3C,$3C,$FC,$FC,$FC,$FC ; C8B8  F8 7C 3C 3C FC FC FC FC
                fcb     $3C,$3C,$3C,$3C,$00,$00,$00,$00 ; C8C0  3C 3C 3C 3C 00 00 00 00
                fcb     $3C,$3C,$3C,$3C,$00,$00,$00,$00 ; C8C8  3C 3C 3C 3C 00 00 00 00
                fcb     $00,$00,$00,$00,$3F,$3F,$3F,$3F ; C8D0  00 00 00 00 3F 3F 3F 3F
                fcb     $00,$00,$00,$00,$C0,$E0,$F0,$F8 ; C8D8  00 00 00 00 C0 E0 F0 F8
                fcb     $3C,$3C,$3C,$3F,$3F,$3C,$3C,$3C ; C8E0  3C 3C 3C 3F 3F 3C 3C 3C
                fcb     $7C,$3C,$7C,$F0,$F0,$7C,$3C,$7C ; C8E8  7C 3C 7C F0 F0 7C 3C 7C
                fcb     $3F,$3F,$3F,$3F,$00,$00,$00,$00 ; C8F0  3F 3F 3F 3F 00 00 00 00
                fcb     $F8,$F0,$E0,$C0,$00,$00,$00,$00 ; C8F8  F8 F0 E0 C0 00 00 00 00
                fcb     $00,$00,$00,$00,$03,$07,$0F,$1F ; C900  00 00 00 00 03 07 0F 1F
                fcb     $00,$00,$00,$00,$C0,$E0,$F0,$F8 ; C908  00 00 00 00 C0 E0 F0 F8
                fcb     $3E,$3C,$3C,$3C,$3C,$3C,$3C,$3E ; C910  3E 3C 3C 3C 3C 3C 3C 3E
                fcb     $7C,$3C,$00,$00,$00,$00,$3C,$7C ; C918  7C 3C 00 00 00 00 3C 7C
                fcb     $1F,$0F,$07,$03,$00,$00,$00,$00 ; C920  1F 0F 07 03 00 00 00 00
                fcb     $F8,$F0,$E0,$C0,$00,$00,$00,$00 ; C928  F8 F0 E0 C0 00 00 00 00
                fcb     $00,$00,$00,$00,$3F,$3F,$3F,$3F ; C930  00 00 00 00 3F 3F 3F 3F
                fcb     $00,$00,$00,$00,$C0,$E0,$F0,$F8 ; C938  00 00 00 00 C0 E0 F0 F8
                fcb     $3C,$3C,$3C,$3C,$3C,$3C,$3C,$3C ; C940  3C 3C 3C 3C 3C 3C 3C 3C
                fcb     $FC,$7C,$3C,$3C,$3C,$3C,$7C,$FC ; C948  FC 7C 3C 3C 3C 3C 7C FC
                fcb     $3F,$3F,$3F,$3F,$00,$00,$00,$00 ; C950  3F 3F 3F 3F 00 00 00 00
                fcb     $F8,$F0,$E0,$C0,$00,$00,$00,$00 ; C958  F8 F0 E0 C0 00 00 00 00
                fcb     $00,$00,$00,$00,$3F,$3F,$3F,$3F ; C960  00 00 00 00 3F 3F 3F 3F
                fcb     $00,$00,$00,$00,$FC,$FC,$FC,$FC ; C968  00 00 00 00 FC FC FC FC
                fcb     $3C,$3C,$3F,$3F,$3F,$3F,$3C,$3C ; C970  3C 3C 3F 3F 3F 3F 3C 3C
                fcb     $00,$00,$C0,$C0,$C0,$C0,$00,$00 ; C978  00 00 C0 C0 C0 C0 00 00
                fcb     $3F,$3F,$3F,$3F,$00,$00,$00,$00 ; C980  3F 3F 3F 3F 00 00 00 00
                fcb     $FC,$FC,$FC,$FC,$00,$00,$00,$00 ; C988  FC FC FC FC 00 00 00 00
                fcb     $00,$00,$00,$00,$3F,$3F,$3F,$3F ; C990  00 00 00 00 3F 3F 3F 3F
                fcb     $00,$00,$00,$00,$FC,$FC,$FC,$FC ; C998  00 00 00 00 FC FC FC FC
                fcb     $3C,$3C,$3F,$3F,$3F,$3F,$3C,$3C ; C9A0  3C 3C 3F 3F 3F 3F 3C 3C
                fcb     $00,$00,$C0,$C0,$C0,$C0,$00,$00 ; C9A8  00 00 C0 C0 C0 C0 00 00
                fcb     $3C,$3C,$3C,$3C,$00,$00,$00,$00 ; C9B0  3C 3C 3C 3C 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; C9B8  00 00 00 00 00 00 00 00
                fcb     $00,$00,$00,$00,$03,$07,$0F,$1F ; C9C0  00 00 00 00 03 07 0F 1F
                fcb     $00,$00,$00,$00,$C0,$E0,$F0,$F8 ; C9C8  00 00 00 00 C0 E0 F0 F8
                fcb     $3E,$3C,$3C,$3C,$3C,$3C,$3C,$3E ; C9D0  3E 3C 3C 3C 3C 3C 3C 3E
                fcb     $7C,$3C,$00,$00,$00,$7C,$7C,$3C ; C9D8  7C 3C 00 00 00 7C 7C 3C
                fcb     $1F,$0F,$07,$03,$00,$00,$00,$00 ; C9E0  1F 0F 07 03 00 00 00 00
                fcb     $FC,$FC,$FC,$FC,$00,$00,$00,$00 ; C9E8  FC FC FC FC 00 00 00 00
                fcb     $00,$00,$00,$00,$3C,$3C,$3C,$3C ; C9F0  00 00 00 00 3C 3C 3C 3C
                fcb     $00,$00,$00,$00,$3C,$3C,$3C,$3C ; C9F8  00 00 00 00 3C 3C 3C 3C
                fcb     $3C,$3C,$3F,$3F,$3F,$3F,$3C,$3C ; CA00  3C 3C 3F 3F 3F 3F 3C 3C
                fcb     $3C,$3C,$FC,$FC,$FC,$FC,$3C,$3C ; CA08  3C 3C FC FC FC FC 3C 3C
                fcb     $3C,$3C,$3C,$3C,$00,$00,$00,$00 ; CA10  3C 3C 3C 3C 00 00 00 00
                fcb     $3C,$3C,$3C,$3C,$00,$00,$00,$00 ; CA18  3C 3C 3C 3C 00 00 00 00
                fcb     $00,$00,$00,$00,$0F,$0F,$0F,$0F ; CA20  00 00 00 00 0F 0F 0F 0F
                fcb     $00,$00,$00,$00,$F0,$F0,$F0,$F0 ; CA28  00 00 00 00 F0 F0 F0 F0
                fcb     $03,$03,$03,$03,$03,$03,$03,$03 ; CA30  03 03 03 03 03 03 03 03
                fcb     $C0,$C0,$C0,$C0,$C0,$C0,$C0,$C0 ; CA38  C0 C0 C0 C0 C0 C0 C0 C0
                fcb     $0F,$0F,$0F,$0F,$00,$00,$00,$00 ; CA40  0F 0F 0F 0F 00 00 00 00
                fcb     $F0,$F0,$F0,$F0,$00,$00,$00,$00 ; CA48  F0 F0 F0 F0 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; CA50  00 00 00 00 00 00 00 00
                fcb     $00,$00,$00,$00,$3C,$3C,$3C,$3C ; CA58  00 00 00 00 3C 3C 3C 3C
                fcb     $00,$00,$00,$00,$00,$00,$3C,$3E ; CA60  00 00 00 00 00 00 3C 3E
                fcb     $3C,$3C,$3C,$3C,$3C,$3C,$3C,$7C ; CA68  3C 3C 3C 3C 3C 3C 3C 7C
                fcb     $1F,$0F,$07,$03,$00,$00,$00,$00 ; CA70  1F 0F 07 03 00 00 00 00
                fcb     $F8,$F0,$E0,$C0,$00,$00,$00,$00 ; CA78  F8 F0 E0 C0 00 00 00 00
                fcb     $00,$00,$00,$00,$3C,$3C,$3C,$3D ; CA80  00 00 00 00 3C 3C 3C 3D
                fcb     $00,$00,$00,$00,$3C,$7C,$F8,$F0 ; CA88  00 00 00 00 3C 7C F8 F0
                fcb     $3F,$3F,$3F,$3F,$3F,$3F,$3F,$3D ; CA90  3F 3F 3F 3F 3F 3F 3F 3D
                fcb     $E0,$C0,$80,$00,$80,$C0,$E0,$F0 ; CA98  E0 C0 80 00 80 C0 E0 F0
                fcb     $3C,$3C,$3C,$3C,$00,$00,$00,$00 ; CAA0  3C 3C 3C 3C 00 00 00 00
                fcb     $F8,$7C,$3C,$3C,$00,$00,$00,$00 ; CAA8  F8 7C 3C 3C 00 00 00 00
                fcb     $00,$00,$00,$00,$3C,$3C,$3C,$3C ; CAB0  00 00 00 00 3C 3C 3C 3C
                fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; CAB8  00 00 00 00 00 00 00 00
                fcb     $3C,$3C,$3C,$3C,$3C,$3C,$3C,$3C ; CAC0  3C 3C 3C 3C 3C 3C 3C 3C
                fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; CAC8  00 00 00 00 00 00 00 00
                fcb     $3F,$3F,$3F,$3F,$00,$00,$00,$00 ; CAD0  3F 3F 3F 3F 00 00 00 00
                fcb     $FC,$FC,$FC,$FC,$00,$00,$00,$00 ; CAD8  FC FC FC FC 00 00 00 00
                fcb     $00,$00,$00,$00,$3C,$3E,$3F,$3F ; CAE0  00 00 00 00 3C 3E 3F 3F
                fcb     $00,$00,$00,$00,$3C,$7C,$FC,$FC ; CAE8  00 00 00 00 3C 7C FC FC
                fcb     $3F,$3F,$3D,$3D,$3D,$3D,$3C,$3C ; CAF0  3F 3F 3D 3D 3D 3D 3C 3C
                fcb     $FC,$FC,$BC,$BC,$BC,$BC,$3C,$3C ; CAF8  FC FC BC BC BC BC 3C 3C
                fcb     $3C,$3C,$3C,$3C,$00,$00,$00,$00 ; CB00  3C 3C 3C 3C 00 00 00 00
                fcb     $3C,$3C,$3C,$3C,$00,$00,$00,$00 ; CB08  3C 3C 3C 3C 00 00 00 00
                fcb     $00,$00,$00,$00,$3C,$3C,$3E,$3E ; CB10  00 00 00 00 3C 3C 3E 3E
                fcb     $00,$00,$00,$00,$3C,$3C,$3C,$3C ; CB18  00 00 00 00 3C 3C 3C 3C
                fcb     $3F,$3F,$3F,$3F,$3F,$3D,$3C,$3C ; CB20  3F 3F 3F 3F 3F 3D 3C 3C
                fcb     $3C,$3C,$BC,$FC,$FC,$FC,$FC,$FC ; CB28  3C 3C BC FC FC FC FC FC
                fcb     $3C,$3C,$3C,$3C,$00,$00,$00,$00 ; CB30  3C 3C 3C 3C 00 00 00 00
                fcb     $7C,$7C,$3C,$3C,$00,$00,$00,$00 ; CB38  7C 7C 3C 3C 00 00 00 00
                fcb     $00,$00,$00,$00,$03,$07,$0F,$1F ; CB40  00 00 00 00 03 07 0F 1F
                fcb     $00,$00,$00,$00,$C0,$E0,$F0,$F8 ; CB48  00 00 00 00 C0 E0 F0 F8
                fcb     $3E,$3C,$3C,$3C,$3C,$3C,$3C,$3E ; CB50  3E 3C 3C 3C 3C 3C 3C 3E
                fcb     $7C,$3C,$3C,$3C,$3C,$3C,$3C,$7C ; CB58  7C 3C 3C 3C 3C 3C 3C 7C
                fcb     $1F,$0F,$07,$03,$00,$00,$00,$00 ; CB60  1F 0F 07 03 00 00 00 00
                fcb     $F8,$F0,$E0,$C0,$00,$00,$00,$00 ; CB68  F8 F0 E0 C0 00 00 00 00
                fcb     $00,$00,$00,$00,$3F,$3F,$3F,$3F ; CB70  00 00 00 00 3F 3F 3F 3F
                fcb     $00,$00,$00,$00,$C0,$E0,$F0,$F8 ; CB78  00 00 00 00 C0 E0 F0 F8
                fcb     $3C,$3C,$3C,$3F,$3F,$3F,$3F,$3C ; CB80  3C 3C 3C 3F 3F 3F 3F 3C
                fcb     $7C,$3C,$7C,$F8,$F0,$E0,$C0,$00 ; CB88  7C 3C 7C F8 F0 E0 C0 00
                fcb     $3C,$3C,$3C,$3C,$00,$00,$00,$00 ; CB90  3C 3C 3C 3C 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; CB98  00 00 00 00 00 00 00 00
                fcb     $00,$00,$00,$00,$03,$07,$0F,$1F ; CBA0  00 00 00 00 03 07 0F 1F
                fcb     $00,$00,$00,$00,$C0,$E0,$F0,$F8 ; CBA8  00 00 00 00 C0 E0 F0 F8
                fcb     $3E,$3C,$3C,$3C,$3C,$3C,$3C,$3E ; CBB0  3E 3C 3C 3C 3C 3C 3C 3E
                fcb     $7C,$3C,$3C,$3C,$3C,$3C,$3C,$78 ; CBB8  7C 3C 3C 3C 3C 3C 3C 78
                fcb     $1F,$0F,$07,$03,$00,$00,$00,$00 ; CBC0  1F 0F 07 03 00 00 00 00
                fcb     $F0,$F8,$FC,$BC,$00,$00,$00,$00 ; CBC8  F0 F8 FC BC 00 00 00 00
                fcb     $00,$00,$00,$00,$3F,$3F,$3F,$3F ; CBD0  00 00 00 00 3F 3F 3F 3F
                fcb     $00,$00,$00,$00,$C0,$E0,$F0,$F8 ; CBD8  00 00 00 00 C0 E0 F0 F8
                fcb     $3C,$3C,$3C,$3F,$3F,$3F,$3F,$3D ; CBE0  3C 3C 3C 3F 3F 3F 3F 3D
                fcb     $7C,$3C,$FC,$F8,$F0,$E0,$E0,$F0 ; CBE8  7C 3C FC F8 F0 E0 E0 F0
                fcb     $3C,$3C,$3C,$3C,$00,$00,$00,$00 ; CBF0  3C 3C 3C 3C 00 00 00 00
                fcb     $F8,$7C,$3C,$3C,$00,$00,$00,$00 ; CBF8  F8 7C 3C 3C 00 00 00 00
                fcb     $00,$00,$00,$00,$03,$07,$0F,$1F ; CC00  00 00 00 00 03 07 0F 1F
                fcb     $00,$00,$00,$00,$C0,$E0,$F0,$F8 ; CC08  00 00 00 00 C0 E0 F0 F8
                fcb     $3E,$3C,$3F,$1F,$07,$00,$3C,$3E ; CC10  3E 3C 3F 1F 07 00 3C 3E
                fcb     $7C,$3C,$00,$E0,$F8,$FC,$3C,$7C ; CC18  7C 3C 00 E0 F8 FC 3C 7C
                fcb     $1F,$0F,$07,$03,$00,$00,$00,$00 ; CC20  1F 0F 07 03 00 00 00 00
                fcb     $F8,$F0,$E0,$C0,$00,$00,$00,$00 ; CC28  F8 F0 E0 C0 00 00 00 00
                fcb     $00,$00,$00,$00,$3F,$3F,$3F,$3F ; CC30  00 00 00 00 3F 3F 3F 3F
                fcb     $00,$00,$00,$00,$FC,$FC,$FC,$FC ; CC38  00 00 00 00 FC FC FC FC
                fcb     $03,$03,$03,$03,$03,$03,$03,$03 ; CC40  03 03 03 03 03 03 03 03
                fcb     $C0,$C0,$C0,$C0,$C0,$C0,$C0,$C0 ; CC48  C0 C0 C0 C0 C0 C0 C0 C0
                fcb     $03,$03,$03,$03,$00,$00,$00,$00 ; CC50  03 03 03 03 00 00 00 00
                fcb     $C0,$C0,$C0,$C0,$00,$00,$00,$00 ; CC58  C0 C0 C0 C0 00 00 00 00
                fcb     $00,$00,$00,$00,$3C,$3C,$3C,$3C ; CC60  00 00 00 00 3C 3C 3C 3C
                fcb     $00,$00,$00,$00,$3C,$3C,$3C,$3C ; CC68  00 00 00 00 3C 3C 3C 3C
                fcb     $3C,$3C,$3C,$3C,$3C,$3C,$3C,$3E ; CC70  3C 3C 3C 3C 3C 3C 3C 3E
                fcb     $3C,$3C,$3C,$3C,$3C,$3C,$3C,$7C ; CC78  3C 3C 3C 3C 3C 3C 3C 7C
                fcb     $1F,$0F,$07,$03,$00,$00,$00,$00 ; CC80  1F 0F 07 03 00 00 00 00
                fcb     $F8,$F0,$E0,$C0,$00,$00,$00,$00 ; CC88  F8 F0 E0 C0 00 00 00 00
                fcb     $00,$00,$00,$00,$3C,$3C,$3C,$3C ; CC90  00 00 00 00 3C 3C 3C 3C
                fcb     $00,$00,$00,$00,$3C,$3C,$3C,$3C ; CC98  00 00 00 00 3C 3C 3C 3C
                fcb     $3C,$3C,$1E,$1E,$0F,$0F,$07,$07 ; CCA0  3C 3C 1E 1E 0F 0F 07 07
                fcb     $3C,$3C,$78,$78,$F0,$F0,$E0,$E0 ; CCA8  3C 3C 78 78 F0 F0 E0 E0
                fcb     $03,$03,$01,$01,$00,$00,$00,$00 ; CCB0  03 03 01 01 00 00 00 00
                fcb     $C0,$C0,$80,$80,$00,$00,$00,$00 ; CCB8  C0 C0 80 80 00 00 00 00
                fcb     $00,$00,$00,$00,$3C,$3C,$3C,$3C ; CCC0  00 00 00 00 3C 3C 3C 3C
                fcb     $00,$00,$00,$00,$3C,$3C,$3C,$3C ; CCC8  00 00 00 00 3C 3C 3C 3C
                fcb     $3C,$3C,$3D,$3D,$3D,$3D,$3F,$3F ; CCD0  3C 3C 3D 3D 3D 3D 3F 3F
                fcb     $3C,$3C,$BC,$BC,$BC,$BC,$FC,$FC ; CCD8  3C 3C BC BC BC BC FC FC
                fcb     $3F,$3F,$3E,$3C,$00,$00,$00,$00 ; CCE0  3F 3F 3E 3C 00 00 00 00
                fcb     $FC,$FC,$7C,$3C,$00,$00,$00,$00 ; CCE8  FC FC 7C 3C 00 00 00 00
                fcb     $00,$00,$00,$00,$3C,$3C,$3E,$3E ; CCF0  00 00 00 00 3C 3C 3E 3E
                fcb     $00,$00,$00,$00,$3C,$3C,$7C,$7C ; CCF8  00 00 00 00 3C 3C 7C 7C
                fcb     $1F,$0F,$07,$03,$03,$07,$0F,$1F ; CD00  1F 0F 07 03 03 07 0F 1F
                fcb     $F8,$F0,$E0,$C0,$C0,$E0,$F0,$F8 ; CD08  F8 F0 E0 C0 C0 E0 F0 F8
                fcb     $3E,$3E,$3C,$3C,$00,$00,$00,$00 ; CD10  3E 3E 3C 3C 00 00 00 00
                fcb     $7C,$7C,$3C,$3C,$00,$00,$00,$00 ; CD18  7C 7C 3C 3C 00 00 00 00
                fcb     $00,$00,$00,$00,$3C,$3C,$3E,$3E ; CD20  00 00 00 00 3C 3C 3E 3E
                fcb     $00,$00,$00,$00,$3C,$3C,$7C,$7C ; CD28  00 00 00 00 3C 3C 7C 7C
                fcb     $1F,$0F,$07,$03,$03,$03,$03,$03 ; CD30  1F 0F 07 03 03 03 03 03
                fcb     $F8,$F0,$E0,$C0,$C0,$C0,$C0,$C0 ; CD38  F8 F0 E0 C0 C0 C0 C0 C0
                fcb     $03,$03,$03,$03,$00,$00,$00,$00 ; CD40  03 03 03 03 00 00 00 00
                fcb     $C0,$C0,$C0,$C0,$00,$00,$00,$00 ; CD48  C0 C0 C0 C0 00 00 00 00
                fcb     $00,$00,$00,$00,$3F,$3F,$3F,$3F ; CD50  00 00 00 00 3F 3F 3F 3F
                fcb     $00,$00,$00,$00,$FC,$FC,$FC,$FC ; CD58  00 00 00 00 FC FC FC FC
                fcb     $00,$00,$01,$03,$07,$0F,$1F,$3E ; CD60  00 00 01 03 07 0F 1F 3E
                fcb     $7C,$F8,$F0,$E0,$C0,$80,$00,$00 ; CD68  7C F8 F0 E0 C0 80 00 00
                fcb     $3F,$3F,$3F,$3F,$00,$00,$00,$00 ; CD70  3F 3F 3F 3F 00 00 00 00
                fcb     $FC,$FC,$FC,$FC,$00,$00,$00,$00 ; CD78  FC FC FC FC 00 00 00 00
                fcb     $00,$00,$00,$00,$0C,$1E,$1E,$0C ; CD80  00 00 00 00 0C 1E 1E 0C
                fcb     $00,$00,$00,$00,$00,$00,$1C,$3C ; CD88  00 00 00 00 00 00 1C 3C
                fcb     $00,$00,$01,$03,$07,$0F,$1F,$3E ; CD90  00 00 01 03 07 0F 1F 3E
                fcb     $7C,$F8,$F0,$E0,$C0,$80,$00,$00 ; CD98  7C F8 F0 E0 C0 80 00 00
                fcb     $3C,$38,$00,$00,$00,$00,$00,$00 ; CDA0  3C 38 00 00 00 00 00 00
                fcb     $30,$78,$78,$30,$00,$00,$00,$00 ; CDA8  30 78 78 30 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; CDB0  00 00 00 00 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; CDB8  00 00 00 00 00 00 00 00
                fcb     $00,$00,$3F,$3F,$3F,$3F,$00,$00 ; CDC0  00 00 3F 3F 3F 3F 00 00
                fcb     $00,$00,$FC,$FC,$FC,$FC,$00,$00 ; CDC8  00 00 FC FC FC FC 00 00
                fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; CDD0  00 00 00 00 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; CDD8  00 00 00 00 00 00 00 00
                fcb     $00,$00,$00,$00,$01,$01,$01,$01 ; CDE0  00 00 00 00 01 01 01 01
                fcb     $00,$00,$00,$00,$80,$80,$80,$80 ; CDE8  00 00 00 00 80 80 80 80
                fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; CDF0  00 00 00 00 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; CDF8  00 00 00 00 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; CE00  00 00 00 00 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; CE08  00 00 00 00 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$01,$03,$07 ; CE10  00 00 00 00 00 01 03 07
                fcb     $00,$00,$00,$00,$F0,$E0,$C0,$80 ; CE18  00 00 00 00 F0 E0 C0 80
                fcb     $07,$0F,$1F,$1E,$1E,$1F,$0F,$07 ; CE20  07 0F 1F 1E 1E 1F 0F 07
                fcb     $80,$00,$00,$00,$00,$00,$00,$80 ; CE28  80 00 00 00 00 00 00 80
                fcb     $07,$03,$01,$00,$00,$00,$00,$00 ; CE30  07 03 01 00 00 00 00 00
                fcb     $80,$C0,$E0,$F0,$00,$00,$00,$00 ; CE38  80 C0 E0 F0 00 00 00 00
                fcb     $00,$00,$00,$00,$0F,$07,$03,$01 ; CE40  00 00 00 00 0F 07 03 01
                fcb     $00,$00,$00,$00,$00,$80,$C0,$E0 ; CE48  00 00 00 00 00 80 C0 E0
                fcb     $01,$00,$00,$00,$00,$00,$00,$01 ; CE50  01 00 00 00 00 00 00 01
                fcb     $E0,$F0,$F8,$78,$78,$F8,$F0,$E0 ; CE58  E0 F0 F8 78 78 F8 F0 E0
                fcb     $01,$03,$07,$0F,$00,$00,$00,$00 ; CE60  01 03 07 0F 00 00 00 00
                fcb     $E0,$C0,$80,$00,$00,$00,$00,$00 ; CE68  E0 C0 80 00 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; CE70  00 00 00 00 00 00 00 00
                fcb     $00,$00,$00,$00,$1C,$3C,$3C,$78 ; CE78  00 00 00 00 1C 3C 3C 78
                fcb     $00,$00,$01,$03,$03,$07,$0F,$0F ; CE80  00 00 01 03 03 07 0F 0F
                fcb     $F0,$F0,$E0,$C0,$C0,$80,$00,$00 ; CE88  F0 F0 E0 C0 C0 80 00 00
                fcb     $1E,$3C,$3C,$38,$00,$00,$00,$00 ; CE90  1E 3C 3C 38 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; CE98  00 00 00 00 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; CEA0  00 00 00 00 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; CEA8  00 00 00 00 00 00 00 00
                fcb     $00,$1F,$3F,$3F,$3F,$0E,$3C,$3E ; CEB0  00 1F 3F 3F 3F 0E 3C 3E
                fcb     $00,$F8,$FC,$FC,$FC,$3C,$3C,$3C ; CEB8  00 F8 FC FC FC 3C 3C 3C
                fcb     $3F,$1F,$0F,$07,$00,$00,$00,$00 ; CEC0  3F 1F 0F 07 00 00 00 00
                fcb     $FC,$FC,$FC,$BC,$00,$00,$00,$00 ; CEC8  FC FC FC BC 00 00 00 00
                fcb     $00,$00,$00,$00,$3C,$3C,$3C,$3C ; CED0  00 00 00 00 3C 3C 3C 3C
                fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; CED8  00 00 00 00 00 00 00 00
                fcb     $3C,$3F,$3F,$3F,$3F,$3C,$3C,$3C ; CEE0  3C 3F 3F 3F 3F 3C 3C 3C
                fcb     $00,$E0,$F0,$F8,$FC,$7C,$3C,$7C ; CEE8  00 E0 F0 F8 FC 7C 3C 7C
                fcb     $3F,$3F,$3F,$3D,$00,$00,$00,$00 ; CEF0  3F 3F 3F 3D 00 00 00 00
                fcb     $FC,$F8,$F0,$E0,$00,$00,$00,$00 ; CEF8  FC F8 F0 E0 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; CF00  00 00 00 00 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; CF08  00 00 00 00 00 00 00 00
                fcb     $00,$07,$0F,$1F,$3F,$3E,$3C,$3E ; CF10  00 07 0F 1F 3F 3E 3C 3E
                fcb     $00,$E0,$F0,$F8,$FC,$3C,$00,$3C ; CF18  00 E0 F0 F8 FC 3C 00 3C
                fcb     $3F,$1F,$0F,$07,$00,$00,$00,$00 ; CF20  3F 1F 0F 07 00 00 00 00
                fcb     $FC,$F8,$F0,$E0,$00,$00,$00,$00 ; CF28  FC F8 F0 E0 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; CF30  00 00 00 00 00 00 00 00
                fcb     $00,$00,$00,$00,$3C,$3C,$3C,$3C ; CF38  00 00 00 00 3C 3C 3C 3C
                fcb     $00,$07,$0F,$1F,$3F,$3E,$3C,$3E ; CF40  00 07 0F 1F 3F 3E 3C 3E
                fcb     $3C,$FC,$FC,$FC,$FC,$3C,$3C,$3C ; CF48  3C FC FC FC FC 3C 3C 3C
                fcb     $3F,$1F,$0F,$07,$00,$00,$00,$00 ; CF50  3F 1F 0F 07 00 00 00 00
                fcb     $FC,$FC,$FC,$BC,$00,$00,$00,$00 ; CF58  FC FC FC BC 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; CF60  00 00 00 00 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; CF68  00 00 00 00 00 00 00 00
                fcb     $00,$07,$0F,$1F,$3E,$3F,$3C,$3E ; CF70  00 07 0F 1F 3E 3F 3C 3E
                fcb     $00,$E0,$F0,$F8,$3C,$FC,$00,$3C ; CF78  00 E0 F0 F8 3C FC 00 3C
                fcb     $3F,$1F,$0F,$07,$00,$00,$00,$00 ; CF80  3F 1F 0F 07 00 00 00 00
                fcb     $FC,$F8,$F0,$E0,$00,$00,$00,$00 ; CF88  FC F8 F0 E0 00 00 00 00
                fcb     $00,$00,$00,$00,$01,$03,$07,$0F ; CF90  00 00 00 00 01 03 07 0F
                fcb     $00,$00,$00,$00,$E0,$F0,$F8,$FC ; CF98  00 00 00 00 E0 F0 F8 FC
                fcb     $0F,$0F,$3F,$3F,$0F,$0F,$0F,$0F ; CFA0  0F 0F 3F 3F 0F 0F 0F 0F
                fcb     $7C,$00,$C0,$C0,$00,$00,$00,$00 ; CFA8  7C 00 C0 C0 00 00 00 00
                fcb     $0F,$0F,$0F,$0F,$00,$00,$00,$00 ; CFB0  0F 0F 0F 0F 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; CFB8  00 00 00 00 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; CFC0  00 00 00 00 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; CFC8  00 00 00 00 00 00 00 00
                fcb     $00,$07,$0F,$1F,$3F,$3E,$3C,$3E ; CFD0  00 07 0F 1F 3F 3E 3C 3E
                fcb     $00,$BC,$FC,$FC,$FC,$3C,$3C,$3C ; CFD8  00 BC FC FC FC 3C 3C 3C
                fcb     $3F,$1F,$0F,$00,$00,$01,$01,$01 ; CFE0  3F 1F 0F 00 00 01 01 01
                fcb     $FC,$FC,$FC,$7C,$F8,$F0,$E0,$C0 ; CFE8  FC FC FC 7C F8 F0 E0 C0
                fcb     $00,$00,$00,$00,$3C,$3C,$3C,$3C ; CFF0  00 00 00 00 3C 3C 3C 3C
                fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; CFF8  00 00 00 00 00 00 00 00
                fcb     $3C,$3F,$3F,$3F,$3F,$3C,$3C,$3C ; D000  3C 3F 3F 3F 3F 3C 3C 3C
                fcb     $00,$E0,$F0,$F8,$FC,$7C,$3C,$3C ; D008  00 E0 F0 F8 FC 7C 3C 3C
                fcb     $3C,$3C,$3C,$3C,$00,$00,$00,$00 ; D010  3C 3C 3C 3C 00 00 00 00
                fcb     $3C,$3C,$3C,$3C,$00,$00,$00,$00 ; D018  3C 3C 3C 3C 00 00 00 00
                fcb     $00,$00,$00,$00,$01,$03,$03,$01 ; D020  00 00 00 00 01 03 03 01
                fcb     $00,$00,$00,$00,$80,$C0,$C0,$80 ; D028  00 00 00 00 80 C0 C0 80
                fcb     $00,$03,$03,$03,$03,$03,$03,$03 ; D030  00 03 03 03 03 03 03 03
                fcb     $00,$C0,$C0,$C0,$C0,$C0,$C0,$C0 ; D038  00 C0 C0 C0 C0 C0 C0 C0
                fcb     $03,$03,$03,$03,$00,$00,$00,$00 ; D040  03 03 03 03 00 00 00 00
                fcb     $C0,$C0,$C0,$C0,$00,$00,$00,$00 ; D048  C0 C0 C0 C0 00 00 00 00
                fcb     $00,$00,$00,$00,$01,$03,$03,$01 ; D050  00 00 00 00 01 03 03 01
                fcb     $00,$00,$00,$00,$80,$C0,$C0,$80 ; D058  00 00 00 00 80 C0 C0 80
                fcb     $00,$03,$03,$03,$03,$03,$03,$03 ; D060  00 03 03 03 03 03 03 03
                fcb     $00,$C0,$C0,$C0,$C0,$C0,$C0,$C0 ; D068  00 C0 C0 C0 C0 C0 C0 C0
                fcb     $03,$03,$03,$73,$77,$7F,$3F,$1E ; D070  03 03 03 73 77 7F 3F 1E
                fcb     $C0,$C0,$C0,$C0,$C0,$80,$00,$00 ; D078  C0 C0 C0 C0 C0 80 00 00
                fcb     $00,$00,$00,$00,$3C,$3C,$3C,$3C ; D080  00 00 00 00 3C 3C 3C 3C
                fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; D088  00 00 00 00 00 00 00 00
                fcb     $3C,$3C,$3C,$3D,$3F,$3F,$3F,$3F ; D090  3C 3C 3C 3D 3F 3F 3F 3F
                fcb     $00,$78,$F8,$F0,$E0,$C0,$C0,$E0 ; D098  00 78 F8 F0 E0 C0 C0 E0
                fcb     $3D,$3C,$3C,$3C,$00,$00,$00,$00 ; D0A0  3D 3C 3C 3C 00 00 00 00
                fcb     $F0,$F8,$7C,$3C,$00,$00,$00,$00 ; D0A8  F0 F8 7C 3C 00 00 00 00
                fcb     $00,$00,$00,$00,$03,$03,$03,$03 ; D0B0  00 00 00 00 03 03 03 03
                fcb     $00,$00,$00,$00,$C0,$C0,$C0,$C0 ; D0B8  00 00 00 00 C0 C0 C0 C0
                fcb     $03,$03,$03,$03,$03,$03,$03,$03 ; D0C0  03 03 03 03 03 03 03 03
                fcb     $C0,$C0,$C0,$C0,$C0,$C0,$C0,$C0 ; D0C8  C0 C0 C0 C0 C0 C0 C0 C0
                fcb     $03,$03,$03,$03,$00,$00,$00,$00 ; D0D0  03 03 03 03 00 00 00 00
                fcb     $C0,$C0,$C0,$C0,$00,$00,$00,$00 ; D0D8  C0 C0 C0 C0 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; D0E0  00 00 00 00 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; D0E8  00 00 00 00 00 00 00 00
                fcb     $00,$1C,$3E,$3F,$3F,$3F,$3D,$3D ; D0F0  00 1C 3E 3F 3F 3F 3D 3D
                fcb     $00,$38,$7C,$FC,$FC,$FC,$BC,$BC ; D0F8  00 38 7C FC FC FC BC BC
                fcb     $3D,$3D,$3C,$3C,$00,$00,$00,$00 ; D100  3D 3D 3C 3C 00 00 00 00
                fcb     $BC,$BC,$3C,$3C,$00,$00,$00,$00 ; D108  BC BC 3C 3C 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; D110  00 00 00 00 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; D118  00 00 00 00 00 00 00 00
                fcb     $00,$3D,$3F,$3F,$3F,$3C,$3C,$3C ; D120  00 3D 3F 3F 3F 3C 3C 3C
                fcb     $00,$E0,$F0,$F8,$FC,$7C,$3C,$3C ; D128  00 E0 F0 F8 FC 7C 3C 3C
                fcb     $3C,$3C,$3C,$3C,$00,$00,$00,$00 ; D130  3C 3C 3C 3C 00 00 00 00
                fcb     $3C,$3C,$3C,$3C,$00,$00,$00,$00 ; D138  3C 3C 3C 3C 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; D140  00 00 00 00 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; D148  00 00 00 00 00 00 00 00
                fcb     $00,$07,$0F,$1F,$3F,$3E,$3C,$3E ; D150  00 07 0F 1F 3F 3E 3C 3E
                fcb     $00,$E0,$F0,$F8,$FC,$7C,$3C,$7C ; D158  00 E0 F0 F8 FC 7C 3C 7C
                fcb     $3F,$1F,$0F,$07,$00,$00,$00,$00 ; D160  3F 1F 0F 07 00 00 00 00
                fcb     $FC,$F8,$F0,$E0,$00,$00,$00,$00 ; D168  FC F8 F0 E0 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; D170  00 00 00 00 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; D178  00 00 00 00 00 00 00 00
                fcb     $00,$3D,$3F,$3F,$3F,$3C,$3C,$3C ; D180  00 3D 3F 3F 3F 3C 3C 3C
                fcb     $00,$E0,$F0,$F8,$FC,$7C,$3C,$7C ; D188  00 E0 F0 F8 FC 7C 3C 7C
                fcb     $3F,$3F,$3F,$3F,$3C,$3C,$3C,$3C ; D190  3F 3F 3F 3F 3C 3C 3C 3C
                fcb     $FC,$F8,$F0,$E0,$00,$00,$00,$00 ; D198  FC F8 F0 E0 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; D1A0  00 00 00 00 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; D1A8  00 00 00 00 00 00 00 00
                fcb     $00,$07,$0F,$1F,$3F,$3E,$3C,$3E ; D1B0  00 07 0F 1F 3F 3E 3C 3E
                fcb     $00,$BC,$FC,$FC,$FC,$3C,$3C,$3C ; D1B8  00 BC FC FC FC 3C 3C 3C
                fcb     $1F,$0F,$07,$00,$00,$00,$00,$00 ; D1C0  1F 0F 07 00 00 00 00 00
                fcb     $FC,$FC,$FC,$3C,$3C,$3C,$3C,$3C ; D1C8  FC FC FC 3C 3C 3C 3C 3C
                fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; D1D0  00 00 00 00 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; D1D8  00 00 00 00 00 00 00 00
                fcb     $00,$1E,$1F,$1F,$1F,$1F,$1E,$1E ; D1E0  00 1E 1F 1F 1F 1F 1E 1E
                fcb     $00,$F0,$F8,$F8,$F8,$00,$00,$00 ; D1E8  00 F0 F8 F8 F8 00 00 00
                fcb     $1E,$1E,$1E,$1E,$00,$00,$00,$00 ; D1F0  1E 1E 1E 1E 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; D1F8  00 00 00 00 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; D200  00 00 00 00 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; D208  00 00 00 00 00 00 00 00
                fcb     $00,$07,$0F,$1F,$3E,$3F,$03,$38 ; D210  00 07 0F 1F 3E 3F 03 38
                fcb     $00,$E0,$F0,$F8,$3C,$1C,$C0,$FC ; D218  00 E0 F0 F8 3C 1C C0 FC
                fcb     $3C,$1F,$0F,$07,$00,$00,$00,$00 ; D220  3C 1F 0F 07 00 00 00 00
                fcb     $7C,$F8,$F0,$E0,$00,$00,$00,$00 ; D228  7C F8 F0 E0 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$00,$03 ; D230  00 00 00 00 00 00 00 03
                fcb     $00,$00,$00,$00,$00,$00,$00,$C0 ; D238  00 00 00 00 00 00 00 C0
                fcb     $03,$03,$0F,$0F,$03,$03,$03,$03 ; D240  03 03 0F 0F 03 03 03 03
                fcb     $C0,$C0,$F0,$F0,$C0,$C0,$C0,$C0 ; D248  C0 C0 F0 F0 C0 C0 C0 C0
                fcb     $03,$03,$03,$01,$00,$00,$00,$00 ; D250  03 03 03 01 00 00 00 00
                fcb     $C0,$C0,$E0,$F0,$00,$00,$00,$00 ; D258  C0 C0 E0 F0 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; D260  00 00 00 00 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; D268  00 00 00 00 00 00 00 00
                fcb     $00,$3C,$3C,$3C,$3C,$3C,$3C,$3E ; D270  00 3C 3C 3C 3C 3C 3C 3E
                fcb     $00,$3C,$3C,$3C,$3C,$3C,$3C,$7C ; D278  00 3C 3C 3C 3C 3C 3C 7C
                fcb     $3F,$1F,$0F,$07,$00,$00,$00,$00 ; D280  3F 1F 0F 07 00 00 00 00
                fcb     $FC,$F8,$F0,$E0,$00,$00,$00,$00 ; D288  FC F8 F0 E0 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; D290  00 00 00 00 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; D298  00 00 00 00 00 00 00 00
                fcb     $00,$3C,$3C,$1E,$1E,$0E,$0E,$07 ; D2A0  00 3C 3C 1E 1E 0E 0E 07
                fcb     $00,$3C,$3C,$78,$78,$70,$70,$E0 ; D2A8  00 3C 3C 78 78 70 70 E0
                fcb     $07,$03,$03,$01,$00,$00,$00,$00 ; D2B0  07 03 03 01 00 00 00 00
                fcb     $E0,$C0,$C0,$80,$00,$00,$00,$00 ; D2B8  E0 C0 C0 80 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; D2C0  00 00 00 00 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; D2C8  00 00 00 00 00 00 00 00
                fcb     $00,$3C,$3C,$3D,$3D,$3D,$3D,$3F ; D2D0  00 3C 3C 3D 3D 3D 3D 3F
                fcb     $00,$3C,$3C,$BC,$BC,$BC,$BC,$FC ; D2D8  00 3C 3C BC BC BC BC FC
                fcb     $3F,$3F,$3E,$1C,$00,$00,$00,$00 ; D2E0  3F 3F 3E 1C 00 00 00 00
                fcb     $FC,$FC,$7C,$38,$00,$00,$00,$00 ; D2E8  FC FC 7C 38 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; D2F0  00 00 00 00 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; D2F8  00 00 00 00 00 00 00 00
                fcb     $00,$3C,$3C,$1E,$1E,$0F,$07,$0F ; D300  00 3C 3C 1E 1E 0F 07 0F
                fcb     $00,$3C,$3C,$78,$78,$F0,$E0,$F0 ; D308  00 3C 3C 78 78 F0 E0 F0
                fcb     $1E,$1E,$3C,$3C,$00,$00,$00,$00 ; D310  1E 1E 3C 3C 00 00 00 00
                fcb     $78,$78,$3C,$3C,$00,$00,$00,$00 ; D318  78 78 3C 3C 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; D320  00 00 00 00 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; D328  00 00 00 00 00 00 00 00
                fcb     $00,$3C,$3C,$3C,$3C,$3C,$3E,$3F ; D330  00 3C 3C 3C 3C 3C 3E 3F
                fcb     $00,$3C,$3C,$3C,$3C,$3C,$7C,$FC ; D338  00 3C 3C 3C 3C 3C 7C FC
                fcb     $3F,$1F,$00,$00,$00,$00,$00,$00 ; D340  3F 1F 00 00 00 00 00 00
                fcb     $FC,$FC,$1C,$1C,$1C,$F8,$F8,$F0 ; D348  FC FC 1C 1C 1C F8 F8 F0
                fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; D350  00 00 00 00 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; D358  00 00 00 00 00 00 00 00
                fcb     $00,$3F,$3F,$3F,$3F,$03,$0F,$3F ; D360  00 3F 3F 3F 3F 03 0F 3F
                fcb     $00,$FC,$FC,$FC,$FC,$F8,$E0,$C0 ; D368  00 FC FC FC FC F8 E0 C0
                fcb     $3F,$3F,$3F,$3F,$00,$00,$00,$00 ; D370  3F 3F 3F 3F 00 00 00 00
                fcb     $FC,$FC,$FC,$FC,$00,$00,$00,$00 ; D378  FC FC FC FC 00 00 00 00

* ===========================================================================
*  Fonte normal: 104 glifos 8x24 (códigos $13-$7A), 24 bytes cada.
* ===========================================================================
SMALL_FONT:     fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; D380  00 00 00 00 00 00 00 00
                fcb     $06,$0C,$18,$00,$3E,$7F,$7F,$37 ; D388  06 0C 18 00 3E 7F 7F 37
                fcb     $77,$7F,$3F,$17,$00,$00,$00,$00 ; D390  77 7F 3F 17 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; D398  00 00 00 00 00 00 00 00
                fcb     $08,$1C,$36,$00,$3E,$7F,$7F,$37 ; D3A0  08 1C 36 00 3E 7F 7F 37
                fcb     $77,$7F,$3F,$17,$00,$00,$00,$00 ; D3A8  77 7F 3F 17 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; D3B0  00 00 00 00 00 00 00 00
                fcb     $11,$2A,$44,$00,$3E,$7F,$7F,$37 ; D3B8  11 2A 44 00 3E 7F 7F 37
                fcb     $77,$7F,$3F,$17,$00,$00,$00,$00 ; D3C0  77 7F 3F 17 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; D3C8  00 00 00 00 00 00 00 00
                fcb     $30,$18,$0C,$00,$3E,$7F,$7F,$37 ; D3D0  30 18 0C 00 3E 7F 7F 37
                fcb     $77,$7F,$3F,$17,$00,$00,$00,$00 ; D3D8  77 7F 3F 17 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; D3E0  00 00 00 00 00 00 00 00
                fcb     $06,$0C,$18,$00,$1C,$3E,$77,$7F ; D3E8  06 0C 18 00 1C 3E 77 7F
                fcb     $70,$77,$3E,$1C,$00,$00,$00,$00 ; D3F0  70 77 3E 1C 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; D3F8  00 00 00 00 00 00 00 00
                fcb     $08,$1C,$36,$00,$1C,$3E,$77,$7F ; D400  08 1C 36 00 1C 3E 77 7F
                fcb     $70,$77,$3E,$1C,$00,$00,$00,$00 ; D408  70 77 3E 1C 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; D410  00 00 00 00 00 00 00 00
                fcb     $06,$0C,$18,$00,$1C,$1C,$1C,$1C ; D418  06 0C 18 00 1C 1C 1C 1C
                fcb     $1C,$1C,$1C,$1C,$00,$00,$00,$00 ; D420  1C 1C 1C 1C 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; D428  00 00 00 00 00 00 00 00
                fcb     $06,$0C,$18,$00,$1C,$3E,$7F,$77 ; D430  06 0C 18 00 1C 3E 7F 77
                fcb     $77,$7F,$3E,$1C,$00,$00,$00,$00 ; D438  77 7F 3E 1C 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; D440  00 00 00 00 00 00 00 00
                fcb     $08,$1C,$36,$00,$1C,$3E,$7F,$77 ; D448  08 1C 36 00 1C 3E 7F 77
                fcb     $77,$7F,$3E,$1C,$00,$00,$00,$00 ; D450  77 7F 3E 1C 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; D458  00 00 00 00 00 00 00 00
                fcb     $11,$2A,$44,$00,$1C,$3E,$7F,$77 ; D460  11 2A 44 00 1C 3E 7F 77
                fcb     $77,$7F,$3E,$1C,$00,$00,$00,$00 ; D468  77 7F 3E 1C 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; D470  00 00 00 00 00 00 00 00
                fcb     $06,$0C,$18,$00,$77,$77,$77,$77 ; D478  06 0C 18 00 77 77 77 77
                fcb     $77,$7F,$3E,$1C,$00,$00,$00,$00 ; D480  77 7F 3E 1C 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; D488  00 00 00 00 00 00 00 00
                fcb     $00,$00,$00,$00,$1C,$3E,$77,$70 ; D490  00 00 00 00 1C 3E 77 70
                fcb     $70,$77,$3E,$1C,$08,$10,$00,$00 ; D498  70 77 3E 1C 08 10 00 00
                fcb     $00,$00,$03,$06,$0C,$00,$08,$1C ; D4A0  00 00 03 06 0C 00 08 1C
                fcb     $3E,$3E,$7F,$77,$77,$7F,$7F,$7F ; D4A8  3E 3E 7F 77 77 7F 7F 7F
                fcb     $77,$77,$77,$77,$00,$00,$00,$00 ; D4B0  77 77 77 77 00 00 00 00
                fcb     $00,$00,$08,$1C,$36,$00,$08,$1C ; D4B8  00 00 08 1C 36 00 08 1C
                fcb     $3E,$3E,$7F,$77,$77,$7F,$7F,$7F ; D4C0  3E 3E 7F 77 77 7F 7F 7F
                fcb     $77,$77,$77,$77,$00,$00,$00,$00 ; D4C8  77 77 77 77 00 00 00 00
                fcb     $00,$00,$11,$2A,$44,$00,$08,$1C ; D4D0  00 00 11 2A 44 00 08 1C
                fcb     $3E,$3E,$7F,$77,$77,$7F,$7F,$7F ; D4D8  3E 3E 7F 77 77 7F 7F 7F
                fcb     $77,$77,$77,$77,$00,$00,$00,$00 ; D4E0  77 77 77 77 00 00 00 00
                fcb     $00,$00,$30,$18,$0C,$00,$08,$1C ; D4E8  00 00 30 18 0C 00 08 1C
                fcb     $3E,$3E,$7F,$77,$77,$7F,$7F,$7F ; D4F0  3E 3E 7F 77 77 7F 7F 7F
                fcb     $77,$77,$77,$77,$00,$00,$00,$00 ; D4F8  77 77 77 77 00 00 00 00
                fcb     $00,$00,$06,$0C,$18,$00,$7F,$7F ; D500  00 00 06 0C 18 00 7F 7F
                fcb     $7F,$70,$70,$7C,$7C,$7C,$70,$70 ; D508  7F 70 70 7C 7C 7C 70 70
                fcb     $70,$7F,$7F,$7F,$00,$00,$00,$00 ; D510  70 7F 7F 7F 00 00 00 00
                fcb     $00,$00,$08,$1C,$36,$00,$7F,$7F ; D518  00 00 08 1C 36 00 7F 7F
                fcb     $7F,$70,$70,$7C,$7C,$7C,$70,$70 ; D520  7F 70 70 7C 7C 7C 70 70
                fcb     $70,$7F,$7F,$7F,$00,$00,$00,$00 ; D528  70 7F 7F 7F 00 00 00 00
                fcb     $00,$00,$06,$0C,$18,$00,$3E,$3E ; D530  00 00 06 0C 18 00 3E 3E
                fcb     $3E,$1C,$1C,$1C,$1C,$1C,$1C,$1C ; D538  3E 1C 1C 1C 1C 1C 1C 1C
                fcb     $1C,$3E,$3E,$3E,$00,$00,$00,$00 ; D540  1C 3E 3E 3E 00 00 00 00
                fcb     $00,$00,$06,$0C,$18,$00,$1C,$3E ; D548  00 00 06 0C 18 00 1C 3E
                fcb     $7F,$77,$77,$77,$77,$77,$77,$77 ; D550  7F 77 77 77 77 77 77 77
                fcb     $77,$7F,$3E,$1C,$00,$00,$00,$00 ; D558  77 7F 3E 1C 00 00 00 00
                fcb     $00,$00,$08,$1C,$36,$00,$1C,$3E ; D560  00 00 08 1C 36 00 1C 3E
                fcb     $7F,$77,$77,$77,$77,$77,$77,$77 ; D568  7F 77 77 77 77 77 77 77
                fcb     $77,$7F,$3E,$1C,$00,$00,$00,$00 ; D570  77 7F 3E 1C 00 00 00 00
                fcb     $00,$00,$11,$2A,$44,$00,$1C,$3E ; D578  00 00 11 2A 44 00 1C 3E
                fcb     $7F,$77,$77,$77,$77,$77,$77,$77 ; D580  7F 77 77 77 77 77 77 77
                fcb     $77,$7F,$3E,$1C,$00,$00,$00,$00 ; D588  77 7F 3E 1C 00 00 00 00
                fcb     $00,$00,$06,$0C,$18,$00,$77,$77 ; D590  00 00 06 0C 18 00 77 77
                fcb     $77,$77,$77,$77,$77,$77,$77,$77 ; D598  77 77 77 77 77 77 77 77
                fcb     $77,$7F,$3E,$1C,$00,$00,$00,$00 ; D5A0  77 7F 3E 1C 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$1C,$3E ; D5A8  00 00 00 00 00 00 1C 3E
                fcb     $7F,$77,$77,$70,$70,$70,$70,$77 ; D5B0  7F 77 77 70 70 70 70 77
                fcb     $77,$7F,$3E,$1C,$08,$08,$10,$00 ; D5B8  77 7F 3E 1C 08 08 10 00
                fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; D5C0  00 00 00 00 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; D5C8  00 00 00 00 00 00 00 00
                fcb     $00,$00,$00,$00,$FF,$FF,$FF,$FF ; D5D0  00 00 00 00 FF FF FF FF
                fcb     $FF,$FF,$FF,$FF,$00,$00,$00,$00 ; D5D8  FF FF FF FF 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; D5E0  00 00 00 00 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; D5E8  00 00 00 00 00 00 00 00
                fcb     $F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0 ; D5F0  F0 F0 F0 F0 F0 F0 F0 F0
                fcb     $F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0 ; D5F8  F0 F0 F0 F0 F0 F0 F0 F0
                fcb     $F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0 ; D600  F0 F0 F0 F0 F0 F0 F0 F0
                fcb     $0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F ; D608  0F 0F 0F 0F 0F 0F 0F 0F
                fcb     $0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F ; D610  0F 0F 0F 0F 0F 0F 0F 0F
                fcb     $0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F ; D618  0F 0F 0F 0F 0F 0F 0F 0F
                fcb     $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; D620  FF FF FF FF FF FF FF FF
                fcb     $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; D628  FF FF FF FF FF FF FF FF
                fcb     $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; D630  FF FF FF FF FF FF FF FF
                fcb     $00,$00,$00,$00,$00,$00,$08,$1C ; D638  00 00 00 00 00 00 08 1C
                fcb     $3E,$7F,$77,$77,$77,$77,$77,$77 ; D640  3E 7F 77 77 77 77 77 77
                fcb     $7F,$3E,$1C,$08,$00,$00,$00,$00 ; D648  7F 3E 1C 08 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$04,$0C ; D650  00 00 00 00 00 00 04 0C
                fcb     $1C,$3C,$1C,$1C,$1C,$1C,$1C,$1C ; D658  1C 3C 1C 1C 1C 1C 1C 1C
                fcb     $1C,$7F,$7F,$7F,$00,$00,$00,$00 ; D660  1C 7F 7F 7F 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$1C,$3E ; D668  00 00 00 00 00 00 1C 3E
                fcb     $7F,$77,$77,$07,$0F,$1E,$3C,$78 ; D670  7F 77 77 07 0F 1E 3C 78
                fcb     $70,$7F,$7F,$7F,$00,$00,$00,$00 ; D678  70 7F 7F 7F 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$7F,$7F ; D680  00 00 00 00 00 00 7F 7F
                fcb     $7F,$07,$0F,$1E,$3C,$1E,$0F,$07 ; D688  7F 07 0F 1E 3C 1E 0F 07
                fcb     $77,$7F,$3E,$1C,$00,$00,$00,$00 ; D690  77 7F 3E 1C 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$06,$0E ; D698  00 00 00 00 00 00 06 0E
                fcb     $1E,$3E,$76,$66,$7F,$7F,$7F,$0E ; D6A0  1E 3E 76 66 7F 7F 7F 0E
                fcb     $0E,$0E,$0E,$0E,$00,$00,$00,$00 ; D6A8  0E 0E 0E 0E 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$7F,$7F ; D6B0  00 00 00 00 00 00 7F 7F
                fcb     $7F,$70,$7C,$7E,$7F,$0F,$07,$77 ; D6B8  7F 70 7C 7E 7F 0F 07 77
                fcb     $77,$7F,$3E,$1C,$00,$00,$00,$00 ; D6C0  77 7F 3E 1C 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$1C,$3E ; D6C8  00 00 00 00 00 00 1C 3E
                fcb     $7F,$77,$77,$70,$7C,$7E,$7F,$77 ; D6D0  7F 77 77 70 7C 7E 7F 77
                fcb     $77,$7F,$3E,$1C,$00,$00,$00,$00 ; D6D8  77 7F 3E 1C 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$7F,$7F ; D6E0  00 00 00 00 00 00 7F 7F
                fcb     $7F,$07,$0F,$1E,$3C,$38,$38,$38 ; D6E8  7F 07 0F 1E 3C 38 38 38
                fcb     $38,$38,$38,$38,$00,$00,$00,$00 ; D6F0  38 38 38 38 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$1C,$3E ; D6F8  00 00 00 00 00 00 1C 3E
                fcb     $7F,$77,$77,$7F,$3E,$3E,$7F,$77 ; D700  7F 77 77 7F 3E 3E 7F 77
                fcb     $77,$7F,$3E,$1C,$00,$00,$00,$00 ; D708  77 7F 3E 1C 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$1C,$3E ; D710  00 00 00 00 00 00 1C 3E
                fcb     $7F,$77,$77,$7F,$3F,$1F,$07,$77 ; D718  7F 77 77 7F 3F 1F 07 77
                fcb     $77,$7F,$3E,$1C,$00,$00,$00,$00 ; D720  77 7F 3E 1C 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; D728  00 00 00 00 00 00 00 00
                fcb     $00,$00,$00,$00,$18,$18,$00,$00 ; D730  00 00 00 00 18 18 00 00
                fcb     $00,$18,$18,$00,$00,$00,$00,$00 ; D738  00 18 18 00 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; D740  00 00 00 00 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; D748  00 00 00 00 00 00 00 00
                fcb     $00,$00,$18,$18,$18,$30,$00,$00 ; D750  00 00 18 18 18 30 00 00
                fcb     $00,$00,$00,$00,$00,$00,$1C,$1C ; D758  00 00 00 00 00 00 1C 1C
                fcb     $1C,$1C,$1C,$1C,$1C,$1C,$1C,$1C ; D760  1C 1C 1C 1C 1C 1C 1C 1C
                fcb     $1C,$00,$1C,$1C,$00,$00,$00,$00 ; D768  1C 00 1C 1C 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$1C,$3E ; D770  00 00 00 00 00 00 1C 3E
                fcb     $7F,$77,$77,$07,$0F,$1F,$1C,$1C ; D778  7F 77 77 07 0F 1F 1C 1C
                fcb     $1C,$00,$1C,$1C,$00,$00,$00,$00 ; D780  1C 00 1C 1C 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; D788  00 00 00 00 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; D790  00 00 00 00 00 00 00 00
                fcb     $00,$00,$18,$18,$00,$00,$00,$00 ; D798  00 00 18 18 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$1C,$3E ; D7A0  00 00 00 00 00 00 1C 3E
                fcb     $7F,$6B,$68,$78,$3C,$1E,$0F,$0B ; D7A8  7F 6B 68 78 3C 1E 0F 0B
                fcb     $6B,$7F,$3E,$1C,$00,$00,$00,$00 ; D7B0  6B 7F 3E 1C 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; D7B8  00 00 00 00 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; D7C0  00 00 00 00 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; D7C8  00 00 00 00 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$08,$1C ; D7D0  00 00 00 00 00 00 08 1C
                fcb     $3E,$3E,$7F,$77,$77,$7F,$7F,$7F ; D7D8  3E 3E 7F 77 77 7F 7F 7F
                fcb     $77,$77,$77,$77,$00,$00,$00,$00 ; D7E0  77 77 77 77 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$7C,$7E ; D7E8  00 00 00 00 00 00 7C 7E
                fcb     $7F,$77,$77,$7E,$7C,$7C,$7E,$77 ; D7F0  7F 77 77 7E 7C 7C 7E 77
                fcb     $77,$7F,$7E,$7C,$00,$00,$00,$00 ; D7F8  77 7F 7E 7C 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$1C,$3E ; D800  00 00 00 00 00 00 1C 3E
                fcb     $7F,$77,$77,$70,$70,$70,$70,$77 ; D808  7F 77 77 70 70 70 70 77
                fcb     $77,$7F,$3E,$1C,$00,$00,$00,$00 ; D810  77 7F 3E 1C 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$7C,$7E ; D818  00 00 00 00 00 00 7C 7E
                fcb     $7F,$77,$77,$77,$77,$77,$77,$77 ; D820  7F 77 77 77 77 77 77 77
                fcb     $77,$7F,$7E,$7C,$00,$00,$00,$00 ; D828  77 7F 7E 7C 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$7F,$7F ; D830  00 00 00 00 00 00 7F 7F
                fcb     $7F,$70,$70,$7C,$7C,$7C,$70,$70 ; D838  7F 70 70 7C 7C 7C 70 70
                fcb     $70,$7F,$7F,$7F,$00,$00,$00,$00 ; D840  70 7F 7F 7F 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$7F,$7F ; D848  00 00 00 00 00 00 7F 7F
                fcb     $7F,$70,$70,$7C,$7C,$7C,$70,$70 ; D850  7F 70 70 7C 7C 7C 70 70
                fcb     $70,$70,$70,$70,$00,$00,$00,$00 ; D858  70 70 70 70 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$1C,$3E ; D860  00 00 00 00 00 00 1C 3E
                fcb     $7F,$77,$77,$70,$70,$70,$70,$77 ; D868  7F 77 77 70 70 70 70 77
                fcb     $73,$7F,$3F,$1F,$00,$00,$00,$00 ; D870  73 7F 3F 1F 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$77,$77 ; D878  00 00 00 00 00 00 77 77
                fcb     $77,$77,$77,$7F,$7F,$7F,$77,$77 ; D880  77 77 77 7F 7F 7F 77 77
                fcb     $77,$77,$77,$77,$00,$00,$00,$00 ; D888  77 77 77 77 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$3E,$3E ; D890  00 00 00 00 00 00 3E 3E
                fcb     $3E,$1C,$1C,$1C,$1C,$1C,$1C,$1C ; D898  3E 1C 1C 1C 1C 1C 1C 1C
                fcb     $1C,$3E,$3E,$3E,$00,$00,$00,$00 ; D8A0  1C 3E 3E 3E 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$07,$07 ; D8A8  00 00 00 00 00 00 07 07
                fcb     $07,$07,$07,$07,$07,$07,$07,$77 ; D8B0  07 07 07 07 07 07 07 77
                fcb     $77,$7F,$3E,$1C,$00,$00,$00,$00 ; D8B8  77 7F 3E 1C 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$77,$77 ; D8C0  00 00 00 00 00 00 77 77
                fcb     $77,$77,$7F,$7E,$7C,$78,$7C,$7E ; D8C8  77 77 7F 7E 7C 78 7C 7E
                fcb     $7F,$77,$77,$77,$00,$00,$00,$00 ; D8D0  7F 77 77 77 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$70,$70 ; D8D8  00 00 00 00 00 00 70 70
                fcb     $70,$70,$70,$70,$70,$70,$70,$70 ; D8E0  70 70 70 70 70 70 70 70
                fcb     $70,$7F,$7F,$7F,$00,$00,$00,$00 ; D8E8  70 7F 7F 7F 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$63,$77 ; D8F0  00 00 00 00 00 00 63 77
                fcb     $7F,$7F,$7F,$6B,$6B,$6B,$63,$63 ; D8F8  7F 7F 7F 6B 6B 6B 63 63
                fcb     $63,$63,$63,$63,$00,$00,$00,$00 ; D900  63 63 63 63 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$63,$63 ; D908  00 00 00 00 00 00 63 63
                fcb     $73,$73,$7B,$7B,$7F,$6F,$6F,$67 ; D910  73 73 7B 7B 7F 6F 6F 67
                fcb     $67,$63,$63,$63,$00,$00,$00,$00 ; D918  67 63 63 63 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$1C,$3E ; D920  00 00 00 00 00 00 1C 3E
                fcb     $7F,$77,$77,$77,$77,$77,$77,$77 ; D928  7F 77 77 77 77 77 77 77
                fcb     $77,$7F,$3E,$1C,$00,$00,$00,$00 ; D930  77 7F 3E 1C 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$7C,$7E ; D938  00 00 00 00 00 00 7C 7E
                fcb     $7F,$77,$77,$7F,$7E,$7C,$70,$70 ; D940  7F 77 77 7F 7E 7C 70 70
                fcb     $70,$70,$70,$70,$00,$00,$00,$00 ; D948  70 70 70 70 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$1C,$3E ; D950  00 00 00 00 00 00 1C 3E
                fcb     $7F,$77,$77,$77,$77,$77,$77,$77 ; D958  7F 77 77 77 77 77 77 77
                fcb     $7F,$7E,$3F,$1B,$00,$00,$00,$00 ; D960  7F 7E 3F 1B 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$7C,$7E ; D968  00 00 00 00 00 00 7C 7E
                fcb     $7F,$77,$77,$7F,$7E,$7C,$7E,$7F ; D970  7F 77 77 7F 7E 7C 7E 7F
                fcb     $7F,$77,$77,$77,$00,$00,$00,$00 ; D978  7F 77 77 77 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$1C,$3E ; D980  00 00 00 00 00 00 1C 3E
                fcb     $7F,$77,$70,$78,$3C,$1E,$0F,$07 ; D988  7F 77 70 78 3C 1E 0F 07
                fcb     $77,$7F,$3E,$1C,$00,$00,$00,$00 ; D990  77 7F 3E 1C 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$7F,$7F ; D998  00 00 00 00 00 00 7F 7F
                fcb     $7F,$1C,$1C,$1C,$1C,$1C,$1C,$1C ; D9A0  7F 1C 1C 1C 1C 1C 1C 1C
                fcb     $1C,$1C,$1C,$1C,$00,$00,$00,$00 ; D9A8  1C 1C 1C 1C 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$77,$77 ; D9B0  00 00 00 00 00 00 77 77
                fcb     $77,$77,$77,$77,$77,$77,$77,$77 ; D9B8  77 77 77 77 77 77 77 77
                fcb     $77,$7F,$3E,$1C,$00,$00,$00,$00 ; D9C0  77 7F 3E 1C 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$77,$77 ; D9C8  00 00 00 00 00 00 77 77
                fcb     $77,$77,$77,$77,$77,$77,$7F,$3E ; D9D0  77 77 77 77 77 77 7F 3E
                fcb     $3E,$1C,$1C,$08,$00,$00,$00,$00 ; D9D8  3E 1C 1C 08 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$63,$63 ; D9E0  00 00 00 00 00 00 63 63
                fcb     $63,$63,$63,$63,$6B,$6B,$6B,$7F ; D9E8  63 63 63 63 6B 6B 6B 7F
                fcb     $7F,$7F,$77,$63,$00,$00,$00,$00 ; D9F0  7F 7F 77 63 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$77,$77 ; D9F8  00 00 00 00 00 00 77 77
                fcb     $77,$7F,$7F,$3E,$1C,$1C,$3E,$7F ; DA00  77 7F 7F 3E 1C 1C 3E 7F
                fcb     $7F,$77,$77,$77,$00,$00,$00,$00 ; DA08  7F 77 77 77 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$77,$77 ; DA10  00 00 00 00 00 00 77 77
                fcb     $77,$77,$7F,$7F,$3E,$1C,$1C,$1C ; DA18  77 77 7F 7F 3E 1C 1C 1C
                fcb     $1C,$1C,$1C,$1C,$00,$00,$00,$00 ; DA20  1C 1C 1C 1C 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$7F,$7F ; DA28  00 00 00 00 00 00 7F 7F
                fcb     $7F,$0F,$0F,$1E,$1E,$3C,$3C,$78 ; DA30  7F 0F 0F 1E 1E 3C 3C 78
                fcb     $78,$7F,$7F,$7F,$00,$00,$00,$00 ; DA38  78 7F 7F 7F 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$00,$03 ; DA40  00 00 00 00 00 00 00 03
                fcb     $63,$67,$06,$0E,$0C,$1C,$18,$38 ; DA48  63 67 06 0E 0C 1C 18 38
                fcb     $30,$73,$63,$60,$00,$00,$00,$00 ; DA50  30 73 63 60 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; DA58  00 00 00 00 00 00 00 00
                fcb     $00,$00,$00,$00,$7F,$7F,$7F,$00 ; DA60  00 00 00 00 7F 7F 7F 00
                fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; DA68  00 00 00 00 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$18,$18 ; DA70  00 00 00 00 00 00 18 18
                fcb     $18,$18,$00,$00,$00,$00,$00,$00 ; DA78  18 18 00 00 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; DA80  00 00 00 00 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$03,$07 ; DA88  00 00 00 00 00 00 03 07
                fcb     $0F,$1E,$3C,$38,$38,$38,$38,$3C ; DA90  0F 1E 3C 38 38 38 38 3C
                fcb     $1E,$0F,$07,$03,$00,$00,$00,$00 ; DA98  1E 0F 07 03 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$60,$70 ; DAA0  00 00 00 00 00 00 60 70
                fcb     $78,$3C,$1E,$0E,$0E,$0E,$0E,$1E ; DAA8  78 3C 1E 0E 0E 0E 0E 1E
                fcb     $3C,$78,$70,$60,$00,$00,$00,$00 ; DAB0  3C 78 70 60 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$00,$03 ; DAB8  00 00 00 00 00 00 00 03
                fcb     $03,$07,$06,$0E,$0C,$1C,$18,$38 ; DAC0  03 07 06 0E 0C 1C 18 38
                fcb     $30,$70,$60,$60,$00,$00,$00,$00 ; DAC8  30 70 60 60 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; DAD0  00 00 00 00 00 00 00 00
                fcb     $00,$00,$00,$00,$3E,$7F,$7F,$37 ; DAD8  00 00 00 00 3E 7F 7F 37
                fcb     $77,$7F,$3F,$17,$00,$00,$00,$00 ; DAE0  77 7F 3F 17 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$70,$70 ; DAE8  00 00 00 00 00 00 70 70
                fcb     $70,$70,$70,$70,$7C,$7E,$7F,$77 ; DAF0  70 70 70 70 7C 7E 7F 77
                fcb     $77,$7F,$7E,$74,$00,$00,$00,$00 ; DAF8  77 7F 7E 74 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; DB00  00 00 00 00 00 00 00 00
                fcb     $00,$00,$00,$00,$1C,$3E,$77,$70 ; DB08  00 00 00 00 1C 3E 77 70
                fcb     $70,$77,$3E,$1C,$00,$00,$00,$00 ; DB10  70 77 3E 1C 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$07,$07 ; DB18  00 00 00 00 00 00 07 07
                fcb     $07,$07,$07,$07,$1F,$3F,$7F,$77 ; DB20  07 07 07 07 1F 3F 7F 77
                fcb     $77,$7F,$3F,$17,$00,$00,$00,$00 ; DB28  77 7F 3F 17 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; DB30  00 00 00 00 00 00 00 00
                fcb     $00,$00,$00,$00,$1C,$3E,$77,$7F ; DB38  00 00 00 00 1C 3E 77 7F
                fcb     $70,$77,$3E,$1C,$00,$00,$00,$00 ; DB40  70 77 3E 1C 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$08,$1C ; DB48  00 00 00 00 00 00 08 1C
                fcb     $3E,$3F,$3B,$3B,$7C,$7C,$38,$38 ; DB50  3E 3F 3B 3B 7C 7C 38 38
                fcb     $38,$38,$38,$38,$00,$00,$00,$00 ; DB58  38 38 38 38 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; DB60  00 00 00 00 00 00 00 00
                fcb     $00,$00,$00,$00,$1C,$3E,$7F,$77 ; DB68  00 00 00 00 1C 3E 7F 77
                fcb     $77,$7F,$3F,$1F,$07,$0F,$1E,$1C ; DB70  77 7F 3F 1F 07 0F 1E 1C
                fcb     $00,$00,$00,$00,$00,$00,$70,$70 ; DB78  00 00 00 00 00 00 70 70
                fcb     $70,$70,$70,$70,$7C,$7E,$7F,$77 ; DB80  70 70 70 70 7C 7E 7F 77
                fcb     $77,$77,$77,$77,$00,$00,$00,$00 ; DB88  77 77 77 77 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$00,$08 ; DB90  00 00 00 00 00 00 00 08
                fcb     $1C,$08,$00,$00,$1C,$1C,$1C,$1C ; DB98  1C 08 00 00 1C 1C 1C 1C
                fcb     $1C,$1C,$1C,$1C,$00,$00,$00,$00 ; DBA0  1C 1C 1C 1C 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$00,$08 ; DBA8  00 00 00 00 00 00 00 08
                fcb     $1C,$08,$00,$00,$1C,$1C,$1C,$1C ; DBB0  1C 08 00 00 1C 1C 1C 1C
                fcb     $1C,$1C,$1C,$1C,$1C,$3C,$78,$70 ; DBB8  1C 1C 1C 1C 1C 3C 78 70
                fcb     $00,$00,$00,$00,$00,$00,$70,$70 ; DBC0  00 00 00 00 00 00 70 70
                fcb     $70,$70,$70,$70,$77,$7F,$7E,$7C ; DBC8  70 70 70 70 77 7F 7E 7C
                fcb     $7E,$77,$77,$77,$00,$00,$00,$00 ; DBD0  7E 77 77 77 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$1C,$1C ; DBD8  00 00 00 00 00 00 1C 1C
                fcb     $1C,$1C,$1C,$1C,$1C,$1C,$1C,$1C ; DBE0  1C 1C 1C 1C 1C 1C 1C 1C
                fcb     $1C,$1C,$1C,$1C,$00,$00,$00,$00 ; DBE8  1C 1C 1C 1C 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; DBF0  00 00 00 00 00 00 00 00
                fcb     $00,$00,$00,$00,$36,$7F,$7F,$6B ; DBF8  00 00 00 00 36 7F 7F 6B
                fcb     $6B,$63,$63,$63,$00,$00,$00,$00 ; DC00  6B 63 63 63 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; DC08  00 00 00 00 00 00 00 00
                fcb     $00,$00,$00,$00,$74,$7E,$7F,$77 ; DC10  00 00 00 00 74 7E 7F 77
                fcb     $77,$77,$77,$77,$00,$00,$00,$00 ; DC18  77 77 77 77 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; DC20  00 00 00 00 00 00 00 00
                fcb     $00,$00,$00,$00,$1C,$3E,$7F,$77 ; DC28  00 00 00 00 1C 3E 7F 77
                fcb     $77,$7F,$3E,$1C,$00,$00,$00,$00 ; DC30  77 7F 3E 1C 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; DC38  00 00 00 00 00 00 00 00
                fcb     $00,$00,$00,$00,$74,$7E,$7F,$77 ; DC40  00 00 00 00 74 7E 7F 77
                fcb     $77,$7F,$7E,$7C,$70,$70,$70,$70 ; DC48  77 7F 7E 7C 70 70 70 70
                fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; DC50  00 00 00 00 00 00 00 00
                fcb     $00,$00,$00,$00,$17,$3F,$7F,$77 ; DC58  00 00 00 00 17 3F 7F 77
                fcb     $77,$7F,$3F,$1F,$07,$07,$07,$07 ; DC60  77 7F 3F 1F 07 07 07 07
                fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; DC68  00 00 00 00 00 00 00 00
                fcb     $00,$00,$00,$00,$76,$7F,$7F,$78 ; DC70  00 00 00 00 76 7F 7F 78
                fcb     $70,$70,$70,$70,$00,$00,$00,$00 ; DC78  70 70 70 70 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; DC80  00 00 00 00 00 00 00 00
                fcb     $00,$00,$00,$00,$1C,$3E,$77,$38 ; DC88  00 00 00 00 1C 3E 77 38
                fcb     $0E,$77,$3E,$1C,$00,$00,$00,$00 ; DC90  0E 77 3E 1C 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; DC98  00 00 00 00 00 00 00 00
                fcb     $00,$00,$1C,$1C,$3E,$3E,$1C,$1C ; DCA0  00 00 1C 1C 3E 3E 1C 1C
                fcb     $1C,$1C,$1E,$0F,$00,$00,$00,$00 ; DCA8  1C 1C 1E 0F 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; DCB0  00 00 00 00 00 00 00 00
                fcb     $00,$00,$00,$00,$77,$77,$77,$77 ; DCB8  00 00 00 00 77 77 77 77
                fcb     $77,$7F,$3E,$1C,$00,$00,$00,$00 ; DCC0  77 7F 3E 1C 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; DCC8  00 00 00 00 00 00 00 00
                fcb     $00,$00,$00,$00,$77,$77,$77,$3E ; DCD0  00 00 00 00 77 77 77 3E
                fcb     $3E,$1C,$1C,$08,$00,$00,$00,$00 ; DCD8  3E 1C 1C 08 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; DCE0  00 00 00 00 00 00 00 00
                fcb     $00,$00,$00,$00,$63,$63,$6B,$6B ; DCE8  00 00 00 00 63 63 6B 6B
                fcb     $6B,$7F,$7F,$36,$00,$00,$00,$00 ; DCF0  6B 7F 7F 36 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; DCF8  00 00 00 00 00 00 00 00
                fcb     $00,$00,$00,$00,$77,$77,$3E,$1C ; DD00  00 00 00 00 77 77 3E 1C
                fcb     $1C,$3E,$77,$77,$00,$00,$00,$00 ; DD08  1C 3E 77 77 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; DD10  00 00 00 00 00 00 00 00
                fcb     $00,$00,$00,$00,$77,$77,$77,$77 ; DD18  00 00 00 00 77 77 77 77
                fcb     $77,$7F,$3F,$1F,$07,$0F,$1E,$1C ; DD20  77 7F 3F 1F 07 0F 1E 1C
                fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; DD28  00 00 00 00 00 00 00 00
                fcb     $00,$00,$00,$00,$7F,$7F,$7F,$1E ; DD30  00 00 00 00 7F 7F 7F 1E
                fcb     $3C,$7F,$7F,$7F,$00,$00,$00,$00 ; DD38  3C 7F 7F 7F 00 00 00 00

*  Glifos $7B-$7E da fonte normal: logotipo 'tms'
TMS_GLYPHS:     fcb     $00,$70,$70,$7C,$7C,$7C,$70,$70 ; DD40  00 70 70 7C 7C 7C 70 70
                fcb     $70,$70,$70,$70,$70,$3C,$1C,$00 ; DD48  70 70 70 70 70 3C 1C 00
                fcb     $00,$08,$08,$05,$05,$02,$00,$00 ; DD50  00 08 08 05 05 02 00 00
                fcb     $00,$FE,$FF,$FF,$E7,$E7,$E7,$E7 ; DD58  00 FE FF FF E7 E7 E7 E7
                fcb     $E7,$E7,$E7,$E7,$E7,$E7,$E7,$00 ; DD60  E7 E7 E7 E7 E7 E7 E7 00
                fcb     $00,$BB,$92,$12,$12,$3B,$00,$00 ; DD68  00 BB 92 12 12 3B 00 00
                fcb     $00,$3C,$3E,$3E,$0E,$0E,$0E,$0E ; DD70  00 3C 3E 3E 0E 0E 0E 0E
                fcb     $0E,$0E,$0E,$0E,$0E,$0E,$0E,$00 ; DD78  0E 0E 0E 0E 0E 0E 0E 00
                fcb     $00,$9E,$50,$5C,$50,$9E,$00,$00 ; DD80  00 9E 50 5C 50 9E 00 00
                fcb     $78,$F0,$F0,$F0,$78,$3C,$1E,$0F ; DD88  78 F0 F0 F0 78 3C 1E 0F
                fcb     $0F,$0F,$0F,$1E,$1E,$3C,$3C,$78 ; DD90  0F 0F 0F 1E 1E 3C 3C 78
                fcb     $00,$60,$90,$90,$90,$60,$00,$00 ; DD98  00 60 90 90 90 60 00 00

* ===========================================================================
*  Fonte 8x8 da tela de abertura (códigos $30-$7B, 8 bytes cada).
* ===========================================================================
FONT8X8:        fcb     $78,$CC,$CC,$CC,$CC,$CC,$78,$00 ; DDA0  78 CC CC CC CC CC 78 00
                fcb     $30,$70,$30,$30,$30,$30,$FC,$00 ; DDA8  30 70 30 30 30 30 FC 00
                fcb     $78,$CC,$0C,$18,$30,$60,$FC,$00 ; DDB0  78 CC 0C 18 30 60 FC 00
                fcb     $78,$CC,$0C,$18,$0C,$CC,$78,$00 ; DDB8  78 CC 0C 18 0C CC 78 00
                fcb     $CC,$CC,$CC,$CC,$FC,$0C,$0C,$00 ; DDC0  CC CC CC CC FC 0C 0C 00
                fcb     $F8,$C0,$C0,$78,$0C,$CC,$78,$00 ; DDC8  F8 C0 C0 78 0C CC 78 00
                fcb     $38,$CC,$C0,$F8,$CC,$CC,$78,$00 ; DDD0  38 CC C0 F8 CC CC 78 00
                fcb     $FC,$CC,$0C,$18,$18,$30,$30,$00 ; DDD8  FC CC 0C 18 18 30 30 00
                fcb     $78,$CC,$CC,$78,$CC,$CC,$78,$00 ; DDE0  78 CC CC 78 CC CC 78 00
                fcb     $78,$CC,$CC,$7C,$0C,$CC,$78,$00 ; DDE8  78 CC CC 7C 0C CC 78 00
                fcb     $00,$38,$38,$00,$38,$38,$00,$00 ; DDF0  00 38 38 00 38 38 00 00
                fcb     $00,$00,$00,$00,$00,$38,$18,$30 ; DDF8  00 00 00 00 00 38 18 30
                fcb     $30,$30,$30,$30,$30,$00,$30,$00 ; DE00  30 30 30 30 30 00 30 00
                fcb     $78,$CC,$CC,$18,$30,$00,$30,$00 ; DE08  78 CC CC 18 30 00 30 00
                fcb     $00,$00,$00,$00,$00,$70,$70,$00 ; DE10  00 00 00 00 00 70 70 00
                fcb     $30,$FC,$C0,$FC,$0C,$FC,$30,$00 ; DE18  30 FC C0 FC 0C FC 30 00
                fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; DE20  00 00 00 00 00 00 00 00
                fcb     $38,$7C,$C6,$C6,$FE,$C6,$C6,$00 ; DE28  38 7C C6 C6 FE C6 C6 00
                fcb     $FC,$C6,$C6,$FC,$C6,$C6,$FC,$00 ; DE30  FC C6 C6 FC C6 C6 FC 00
                fcb     $7C,$C6,$C6,$C0,$C6,$C6,$7C,$00 ; DE38  7C C6 C6 C0 C6 C6 7C 00
                fcb     $FC,$C6,$C6,$C6,$C6,$C6,$FC,$00 ; DE40  FC C6 C6 C6 C6 C6 FC 00
                fcb     $FE,$C6,$C0,$F8,$C0,$C6,$FE,$00 ; DE48  FE C6 C0 F8 C0 C6 FE 00
                fcb     $FE,$C6,$C0,$F8,$C0,$C0,$C0,$00 ; DE50  FE C6 C0 F8 C0 C0 C0 00
                fcb     $7C,$C6,$C0,$CE,$C6,$C6,$7C,$00 ; DE58  7C C6 C0 CE C6 C6 7C 00
                fcb     $C6,$C6,$C6,$FE,$C6,$C6,$C6,$00 ; DE60  C6 C6 C6 FE C6 C6 C6 00
                fcb     $3C,$18,$18,$18,$18,$18,$3C,$00 ; DE68  3C 18 18 18 18 18 3C 00
                fcb     $06,$06,$06,$06,$06,$C6,$7C,$00 ; DE70  06 06 06 06 06 C6 7C 00
                fcb     $C6,$CC,$D8,$F0,$D8,$CC,$C6,$00 ; DE78  C6 CC D8 F0 D8 CC C6 00
                fcb     $C0,$C0,$C0,$C0,$C0,$C6,$FE,$00 ; DE80  C0 C0 C0 C0 C0 C6 FE 00
                fcb     $C6,$EE,$FE,$D6,$C6,$C6,$C6,$00 ; DE88  C6 EE FE D6 C6 C6 C6 00
                fcb     $C6,$E6,$F6,$DE,$CE,$C6,$C6,$00 ; DE90  C6 E6 F6 DE CE C6 C6 00
                fcb     $7C,$C6,$C6,$C6,$C6,$C6,$7C,$00 ; DE98  7C C6 C6 C6 C6 C6 7C 00
                fcb     $FC,$C6,$C6,$FC,$C0,$C0,$C0,$00 ; DEA0  FC C6 C6 FC C0 C0 C0 00
                fcb     $7C,$C6,$C6,$C6,$CE,$CC,$7A,$00 ; DEA8  7C C6 C6 C6 CE CC 7A 00
                fcb     $FC,$C6,$C6,$FC,$D8,$CC,$C6,$00 ; DEB0  FC C6 C6 FC D8 CC C6 00
                fcb     $7C,$C6,$C0,$7C,$06,$C6,$7C,$00 ; DEB8  7C C6 C0 7C 06 C6 7C 00
                fcb     $7E,$18,$18,$18,$18,$18,$18,$00 ; DEC0  7E 18 18 18 18 18 18 00
                fcb     $C6,$C6,$C6,$C6,$C6,$C6,$7C,$00 ; DEC8  C6 C6 C6 C6 C6 C6 7C 00
                fcb     $C6,$C6,$C6,$6C,$6C,$6C,$38,$00 ; DED0  C6 C6 C6 6C 6C 6C 38 00
                fcb     $C6,$C6,$C6,$D6,$FC,$EE,$C6,$00 ; DED8  C6 C6 C6 D6 FC EE C6 00
                fcb     $C6,$C6,$6C,$38,$6C,$C6,$C6,$00 ; DEE0  C6 C6 6C 38 6C C6 C6 00
                fcb     $66,$66,$24,$3C,$18,$18,$18,$00 ; DEE8  66 66 24 3C 18 18 18 00
                fcb     $FE,$C6,$0C,$18,$30,$E6,$FE,$00 ; DEF0  FE C6 0C 18 30 E6 FE 00
                fcb     $E6,$AC,$F8,$3E,$6A,$CE,$00,$00 ; DEF8  E6 AC F8 3E 6A CE 00 00
                fcb     $00,$00,$00,$7C,$7C,$00,$00,$00 ; DF00  00 00 00 7C 7C 00 00 00
                fcb     $18,$18,$18,$00,$00,$00,$00,$00 ; DF08  18 18 18 00 00 00 00 00
                fcb     $18,$30,$60,$60,$60,$30,$18,$00 ; DF10  18 30 60 60 60 30 18 00
                fcb     $18,$0C,$06,$06,$06,$0C,$18,$00 ; DF18  18 0C 06 06 06 0C 18 00
                fcb     $06,$0C,$18,$30,$60,$C0,$00,$00 ; DF20  06 0C 18 30 60 C0 00 00
                fcb     $00,$00,$3C,$66,$66,$66,$3A,$00 ; DF28  00 00 3C 66 66 66 3A 00
                fcb     $60,$60,$60,$7C,$66,$66,$7C,$00 ; DF30  60 60 60 7C 66 66 7C 00
                fcb     $00,$00,$3C,$66,$60,$66,$3C,$00 ; DF38  00 00 3C 66 60 66 3C 00
                fcb     $06,$06,$06,$3E,$66,$66,$3E,$00 ; DF40  06 06 06 3E 66 66 3E 00
                fcb     $00,$00,$3C,$66,$7C,$60,$3C,$00 ; DF48  00 00 3C 66 7C 60 3C 00
                fcb     $0C,$18,$30,$38,$30,$30,$30,$00 ; DF50  0C 18 30 38 30 30 30 00
                fcb     $00,$00,$3C,$66,$66,$3E,$06,$7C ; DF58  00 00 3C 66 66 3E 06 7C
                fcb     $60,$60,$60,$7C,$66,$66,$66,$00 ; DF60  60 60 60 7C 66 66 66 00
                fcb     $00,$18,$00,$18,$18,$18,$18,$00 ; DF68  00 18 00 18 18 18 18 00
                fcb     $00,$00,$06,$06,$06,$06,$66,$3C ; DF70  00 00 06 06 06 06 66 3C
                fcb     $60,$60,$66,$6C,$70,$6C,$66,$00 ; DF78  60 60 66 6C 70 6C 66 00
                fcb     $18,$18,$18,$18,$18,$18,$18,$00 ; DF80  18 18 18 18 18 18 18 00
                fcb     $00,$00,$EE,$D6,$D6,$D6,$D6,$00 ; DF88  00 00 EE D6 D6 D6 D6 00
                fcb     $00,$00,$5C,$7E,$66,$66,$66,$00 ; DF90  00 00 5C 7E 66 66 66 00
                fcb     $00,$00,$3C,$66,$66,$66,$3C,$00 ; DF98  00 00 3C 66 66 66 3C 00
                fcb     $00,$00,$7C,$66,$66,$7C,$60,$60 ; DFA0  00 00 7C 66 66 7C 60 60
                fcb     $00,$00,$3E,$66,$66,$3E,$06,$06 ; DFA8  00 00 3E 66 66 3E 06 06
                fcb     $00,$00,$5C,$66,$60,$60,$60,$00 ; DFB0  00 00 5C 66 60 60 60 00
                fcb     $00,$00,$3E,$60,$7E,$06,$7C,$00 ; DFB8  00 00 3E 60 7E 06 7C 00
                fcb     $00,$18,$3C,$18,$18,$18,$18,$00 ; DFC0  00 18 3C 18 18 18 18 00
                fcb     $00,$00,$66,$66,$66,$7E,$3A,$00 ; DFC8  00 00 66 66 66 7E 3A 00
                fcb     $00,$00,$66,$66,$24,$3C,$18,$00 ; DFD0  00 00 66 66 24 3C 18 00
                fcb     $00,$00,$C6,$D6,$D6,$D6,$7C,$00 ; DFD8  00 00 C6 D6 D6 D6 7C 00
                fcb     $00,$00,$66,$66,$18,$66,$66,$00 ; DFE0  00 00 66 66 18 66 66 00
                fcb     $00,$00,$66,$66,$66,$3E,$06,$7C ; DFE8  00 00 66 66 66 3E 06 7C
                fcb     $00,$00,$7E,$46,$18,$62,$7E,$00 ; DFF0  00 00 7E 46 18 62 7E 00
                fcb     $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; DFF8  FF FF FF FF FF FF FF FF

* ===========================================================================
*  RESET - ponto de entrada (vetor $FFFE)
* ===========================================================================
RESET:          bra     COLD_START           ; E000  20 12

*  Tabela de 3 ponteiros logo após o BRA do reset: entradas úteis para
*  programas de cartucho (ler tecla, varrer teclado, laço de comandos).
ROM_API:        fdb     GETKEY               ; E002  E3 22
                fdb     KBD_SCAN             ; E004  E3 75
                fdb     MAIN_LOOP            ; E006  E2 31

*  Os vetores de hardware saltam por ponteiros em RAM. A ROM nunca habilita
*  interrupções nem inicializa esses ponteiros: são ganchos para cartuchos.
IRQ_ENTRY:      jmp     [>irq_vector]        ; E008  6E 9F 00 39    IRQ, FIRQ e NMI -> [irq_vector]
SWI_ENTRY:      jmp     [>swi_vector]        ; E00C  6E 9F 00 3B    SWI -> [swi_vector]
SWI23_ENTRY:    jmp     [>swi23_vector]      ; E010  6E 9F 00 3D    SWI2/SWI3 -> [swi23_vector]

* ===========================================================================
*  Inicialização
* ===========================================================================
COLD_START:     lds     #page_text           ; E014  10 CE 02 00    pilha no topo da área de variáveis
                ldx     #$2000               ; E018  8E 20 00
BOOT_DELAY:     leax    -1,X                 ; E01B  30 1F          ~64 ms para a fonte e o VDP estabilizarem
                bne     BOOT_DELAY           ; E01D  26 FC
                leax    >VDP_INIT_TAB,PCR    ; E01F  30 8D 00 18
                lda     #$02                 ; E023  86 02
                sta     <vdp_r0              ; E025  97 00
                lda     #$82                 ; E027  86 82
                sta     <vdp_r1              ; E029  97 01
                clr     <backdrop            ; E02B  0F 02
VDP_INIT_LOOP:  ldb     ,X+                  ; E02D  E6 80          pares (registrador|$80, valor)
                beq     CLEAR_VRAM           ; E02F  27 1B
                lda     ,X+                  ; E031  A6 80
                sta     VDP_CTRL             ; E033  B7 80 01
                stb     VDP_CTRL             ; E036  F7 80 01
                bra     VDP_INIT_LOOP        ; E039  20 F2

*  Registradores iniciais do VDP (modo Graphics II, 16K, sprites 16x16):
*    R0=$02 M3        R1=$82 16K, imagem desligada, sem interrupção, 16x16
*    R2=$0E nomes em $3800         R3=$FF cores em $2000 (bitmap completo)
*    R4=$03 padrões em $0000       R5=$78 atributos de sprites em $3C00
*    R6=$03 padrões de sprites em $1800   R7=$00 fundo preto
VDP_INIT_TAB:   fcb     $80,$02,$81,$82,$82,$0E,$83,$FF ; E03B  80 02 81 82 82 0E 83 FF
                fcb     $84,$03,$85,$78,$86,$03,$87,$00 ; E043  84 03 85 78 86 03 87 00
                fcb     $00                  ; E04B  00
CLEAR_VRAM:     ldd     #vdp_r0              ; E04C  CC 00 00       zera os 16 KB de VRAM
                lbsr    VDP_SET_WRITE        ; E04F  17 0A A6
                ldx     #CART0               ; E052  8E 40 00
                clra                         ; E055  4F
LE056:          sta     VDP_DATA             ; E056  B7 80 00
                leax    -1,X                 ; E059  30 1F
                bne     LE056                ; E05B  26 F9
INIT_NAMES:     ldd     #$3800               ; E05D  CC 38 00       tabela de nomes = 0..255 x 3 (bitmap)
                lbsr    VDP_SET_WRITE        ; E060  17 0A 95
                ldx     #$0300               ; E063  8E 03 00
                clra                         ; E066  4F
LE067:          sta     VDP_DATA             ; E067  B7 80 00
                inca                         ; E06A  4C
                leax    -1,X                 ; E06B  30 1F
                bne     LE067                ; E06D  26 F8
INIT_VARS:      ldd     #$0100               ; E06F  CC 01 00
                std     <key_delay           ; E072  DD 03
                ldb     #$29                 ; E074  C6 29
                ldx     #kbd_scan            ; E076  8E 00 05
LE079:          clr     ,X+                  ; E079  6F 80
                decb                         ; E07B  5A
                bne     LE079                ; E07C  26 FB
                lda     #$40                 ; E07E  86 40
                sta     <line_color          ; E080  97 24
                lda     #$02                 ; E082  86 02
                sta     <color_idx           ; E084  97 1C
                ldd     #BIG_FONT            ; E086  CC C0 00
                std     <fonta_big           ; E089  DD 35
                std     <fontb_big           ; E08B  DD 37
                ldd     #SMALL_FONT          ; E08D  CC D3 80
                std     <fonta_small         ; E090  DD 29
                std     <fontb_small         ; E092  DD 2B
                lda     #$FF                 ; E094  86 FF
                sta     <key_last            ; E096  97 20
                ldb     #$40                 ; E098  C6 40
BUILD_CMDTAB:   subb    #$02                 ; E09A  C0 02          SYSTAB (auto-relativa) -> cmd_table em RAM
                ldu     #cmd_table           ; E09C  CE 00 40
                leau    B,U                  ; E09F  33 C5
                leax    >SYSTAB,PCR          ; E0A1  30 8D 00 15
                abx                          ; E0A5  3A
                stb     ,-S                  ; E0A6  E7 E2
                ldd     ,X                   ; E0A8  EC 84
                bne     LE0AF                ; E0AA  26 03
                ldx     #vdp_r0              ; E0AC  8E 00 00
LE0AF:          leay    D,X                  ; E0AF  31 8B
                sty     ,U                   ; E0B1  10 AF C4
                ldb     ,S+                  ; E0B4  E6 E0
                bne     BUILD_CMDTAB         ; E0B6  26 E2
                bra     INIT_SPRITES         ; E0B8  20 40

*  Tabela de comandos: 32 deslocamentos auto-relativos (entrada + valor =
*  rotina). Copiada como endereços absolutos para cmd_table ($0040). O índice
*  é o código de tecla: 0 = caractere, 1..$0F = teclas de função, +$10 com
*  SHIFT (e códigos especiais com CONTROL). Zero = sem função.
SYSTAB:         fdb     CMD_CHAR-*           ; E0BA  03 62
                fdb     CMD_PAGE-*           ; E0BC  05 30
                fdb     CMD_BORDER-*         ; E0BE  05 19
                fdb     CMD_CLEAR_LINE-*     ; E0C0  08 A1
                fdb     CMD_OBJ-*            ; E0C2  04 5C
                fdb     CMD_EXTVID-*         ; E0C4  06 DE
                fdb     CMD_CURSOR-*         ; E0C6  07 13
                fdb     CMD_RETURN-*         ; E0C8  08 55
                fdb     CMD_COLOR-*          ; E0CA  04 3F
                fdb     CMD_LEFT-*           ; E0CC  03 EF
                fdb     CMD_DOWN-*           ; E0CE  04 2A
                fdb     CMD_OBJ_COLOR-*      ; E0D0  08 CC
                fdb     CMD_OBJ_LEFT-*       ; E0D2  08 AF
                fdb     CMD_OBJ_DOWN-*       ; E0D4  08 B9
                fdb     CMD_CENTER-*         ; E0D6  09 09
                fdb     CMD_FONTSIZE-*       ; E0D8  06 E6
                fdb     CMD_ROLL-*           ; E0DA  0A 5A
                fdb     CMD_PAGE_PREV-*      ; E0DC  06 BB
                fdb     CMD_BACKDROP-*       ; E0DE  06 A6
                fdb     CMD_CLEAR_PAGE-*     ; E0E0  08 52
                fdb     CMD_OBJ_SHAPE-*      ; E0E2  06 98
                fdb     CMD_EXTVID-*         ; E0E4  06 BE
                fdb     CMD_CAPS-*           ; E0E6  06 D1
                fdb     0                    ; E0E8  00 00
                fdb     0                    ; E0EA  00 00
                fdb     CMD_RIGHT-*          ; E0EC  06 22
                fdb     CMD_UP-*             ; E0EE  06 60
                fdb     CMD_OBJ_COLOR-*      ; E0F0  08 AC
                fdb     CMD_OBJ_RIGHT-*      ; E0F2  08 B4
                fdb     CMD_OBJ_UP-*         ; E0F4  08 C1
                fdb     CMD_CENTER_ALL-*     ; E0F6  08 CB
                fdb     0                    ; E0F8  00 00
INIT_SPRITES:   nop                          ; E0FA  12             atributos: Y=$D0 (fim da lista) nos 32 sprites
                lda     #$02                 ; E0FB  86 02
                sta     <obj_color           ; E0FD  97 17
                ldd     #$3C00               ; E0FF  CC 3C 00
                lbsr    VDP_SET_WRITE        ; E102  17 09 F3
                lda     #$20                 ; E105  86 20
LE107:          ldb     #$D0                 ; E107  C6 D0
                stb     VDP_DATA             ; E109  F7 80 00
                clrb                         ; E10C  5F
                lbsr    VDP_DELAY            ; E10D  17 09 CB
                stb     VDP_DATA             ; E110  F7 80 00
                lbsr    VDP_DELAY            ; E113  17 09 C5
                stb     VDP_DATA             ; E116  F7 80 00
                lbsr    VDP_DELAY            ; E119  17 09 BF
                stb     VDP_DATA             ; E11C  F7 80 00
                deca                         ; E11F  4A
                bne     LE107                ; E120  26 E5
LOAD_SPRITE_PATS: ldd     #$1800             ; E122  CC 18 00       copia 512 bytes de padrões de sprites para $1800
                lbsr    VDP_SET_WRITE        ; E125  17 09 D0
                leax    SPRITE_PATS,PCR      ; E128  30 8D 0F 77
                ldy     #page_text           ; E12C  10 8E 02 00
LE130:          lda     ,X+                  ; E130  A6 80
                sta     VDP_DATA             ; E132  B7 80 00
                leay    -1,Y                 ; E135  31 3F
                bne     LE130                ; E137  26 F7

* ---------------------------------------------------------------------------
*  Procura um cartucho "OBJECT" em $4000 e depois em $6000. Se achar, faz
*  LDX [base+6] / JSR base,X. Atenção: o indireto estendido lê DUAS vezes -
*  base+6 contém um PONTEIRO para a palavra com o deslocamento da entrada:
*      base+0 "OBJECT"   base+6 FDB base+8   base+8 FDB entrada-base
*  O programa do cartucho pode voltar com RTS para a ROM continuar a
*  inicialização, ou assumir a máquina de vez.
* ---------------------------------------------------------------------------
PROBE_OBJECT:   leax    >STR_OBJECT,PCR      ; E139  30 8D 00 1E
                ldy     #CART0               ; E13D  10 8E 40 00
LE141:          lda     ,X+                  ; E141  A6 80
                beq     CALL_CART0           ; E143  27 1D
                cmpa    ,Y+                  ; E145  A1 A0
                beq     LE141                ; E147  27 F8
                leax    >STR_OBJECT,PCR      ; E149  30 8D 00 0E
                ldy     #CART1               ; E14D  10 8E 60 00
LE151:          lda     ,X+                  ; E151  A6 80
                beq     CALL_CART1           ; E153  27 17
                cmpa    ,Y+                  ; E155  A1 A0
                beq     LE151                ; E157  27 F8
                bra     PROBE_FONT           ; E159  20 19
STR_OBJECT:     fcc     "OBJECT",$00         ; E15B  4F 42 4A 45 ..
CALL_CART0:     ldx     [CART0_ENTRY]        ; E162  AE 9F 40 06    X = palavra apontada por [$4006]
                jsr     CART0,X              ; E166  AD 89 40 00
                bra     PROBE_FONT           ; E16A  20 08
CALL_CART1:     ldx     [CART1_ENTRY]        ; E16C  AE 9F 60 06    X = palavra apontada por [$6006]
                jsr     CART1,X              ; E170  AD 89 60 00

* ---------------------------------------------------------------------------
*  Procura cartuchos "FONT": em $4000 substitui a fonte A; em $6000 (se o
*  byte de identificação for diferente do primeiro) instala a fonte B.
*  Formato: "FONT", id, ..., fonte grande em +$10, fonte normal em +$1390.
* ---------------------------------------------------------------------------
PROBE_FONT:     nop                          ; E174  12
                leax    >STR_FONT,PCR        ; E175  30 8D 00 0F
                ldy     #CART0               ; E179  10 8E 40 00
LE17D:          lda     ,X+                  ; E17D  A6 80
                beq     FONT0_FOUND          ; E17F  27 0C
                cmpa    ,Y+                  ; E181  A1 A0
                beq     LE17D                ; E183  27 F8
                clrb                         ; E185  5F
                bra     PROBE_FONT1          ; E186  20 12
STR_FONT:       fcc     "FONT",$00           ; E188  46 4F 4E 54 ..
FONT0_FOUND:    ldd     #$5390               ; E18D  CC 53 90
                std     <fonta_small         ; E190  DD 29
                ldd     #$4010               ; E192  CC 40 10
                std     <fonta_big           ; E195  DD 35
                ldb     CART0_ID             ; E197  F6 40 04
PROBE_FONT1:    leax    >STR_FONT,PCR        ; E19A  30 8D FF EA
                ldy     #CART1               ; E19E  10 8E 60 00
LE1A2:          lda     ,X+                  ; E1A2  A6 80
                beq     FONT1_FOUND          ; E1A4  27 06
                cmpa    ,Y+                  ; E1A6  A1 A0
                beq     LE1A2                ; E1A8  27 F8
                bra     CHECK_POWER          ; E1AA  20 0F
FONT1_FOUND:    cmpb    CART1_ID             ; E1AC  F1 60 04
                beq     CHECK_POWER          ; E1AF  27 0A
                ldd     #$7390               ; E1B1  CC 73 90
                std     <fontb_small         ; E1B4  DD 2B
                ldd     #$6010               ; E1B6  CC 60 10
                std     <fontb_big           ; E1B9  DD 37

* ---------------------------------------------------------------------------
*  Se a RAM não contém "POWER" em $0030 (bateria descarregada/primeira vez),
*  grava a assinatura e apaga os textos e atributos de todas as páginas.
* ---------------------------------------------------------------------------
CHECK_POWER:    nop                          ; E1BB  12
                leax    >STR_POWER,PCR       ; E1BC  30 8D 00 39
                ldy     #power_sig           ; E1C0  10 8E 00 30
LE1C4:          lda     ,X+                  ; E1C4  A6 80
                beq     START_TITLER         ; E1C6  27 37
                cmpa    ,Y+                  ; E1C8  A1 A0
                beq     LE1C4                ; E1CA  27 F8
                leax    >STR_POWER,PCR       ; E1CC  30 8D 00 29
                ldy     #power_sig           ; E1D0  10 8E 00 30
LE1D4:          lda     ,X+                  ; E1D4  A6 80
                beq     COLD_RAM_INIT        ; E1D6  27 04
                sta     ,Y+                  ; E1D8  A7 A0
                bra     LE1D4                ; E1DA  20 F8
COLD_RAM_INIT:  ldx     #page_text           ; E1DC  8E 02 00
                ldy     #$1E00               ; E1DF  10 8E 1E 00
                lda     #$40                 ; E1E3  86 40
LE1E5:          sta     ,X+                  ; E1E5  A7 80
                leay    -1,Y                 ; E1E7  31 3F
                bne     LE1E5                ; E1E9  26 FA
                ldx     #line_attr           ; E1EB  8E 00 A0
                ldb     #$F0                 ; E1EE  C6 F0
                lda     #$40                 ; E1F0  86 40
LE1F2:          sta     ,X+                  ; E1F2  A7 80
                decb                         ; E1F4  5A
                bne     LE1F2                ; E1F5  26 FB
                bra     START_TITLER         ; E1F7  20 06
STR_POWER:      fcc     "POWER",$00          ; E1F9  50 4F 57 45 ..

* ===========================================================================
*  Tela de abertura e laço principal
* ===========================================================================
START_TITLER:   nop                          ; E1FF  12
                lbsr    TITLE_SCREEN         ; E200  17 0C 9B
                lbsr    CMD_BORDER           ; E203  17 03 D1
TITLE_WAIT:     lbsr    GETKEY               ; E206  17 01 19       na abertura: SHIFT+BORDER muda o fundo, EXT MODE sobrepõe
                lda     <key_code            ; E209  96 1E
                cmpa    #$02                 ; E20B  81 02
                bne     LE218                ; E20D  26 09
                ldb     <key_shift           ; E20F  D6 10
                beq     LE218                ; E211  27 05
                lbsr    CMD_BACKDROP         ; E213  17 05 6E
                bra     TITLE_WAIT           ; E216  20 EE
LE218:          cmpa    #$05                 ; E218  81 05
                bne     ENTER_EDITOR         ; E21A  26 05
                lbsr    CMD_EXTVID           ; E21C  17 05 83
                bra     TITLE_WAIT           ; E21F  20 E5
ENTER_EDITOR:   lbsr    CMD_BORDER           ; E221  17 03 B3
                lda     #$40                 ; E224  86 40
                sta     <line_color          ; E226  97 24
                lbsr    PAGE_REDRAW          ; E228  17 03 EF
                lbsr    CMD_BORDER           ; E22B  17 03 A9
                lbsr    CMD_CURSOR           ; E22E  17 05 A8
MAIN_LOOP:      lbsr    GETKEY               ; E231  17 00 EE       lê tecla e despacha comando
                lda     <key_code            ; E234  96 1E
                cmpa    #$30                 ; E236  81 30
                bcs     DISPATCH_FUNC        ; E238  25 52
                tst     <cursor_mode         ; E23A  0D 0F
                bne     LE256                ; E23C  26 18
                cmpa    #$39                 ; E23E  81 39
                bhi     LE256                ; E240  22 14
                cmpa    #$30                 ; E242  81 30
                bcs     LE256                ; E244  25 10
                asl     <page_entry          ; E246  08 27
                asl     <page_entry          ; E248  08 27
                asl     <page_entry          ; E24A  08 27
                asl     <page_entry          ; E24C  08 27
                anda    #$0F                 ; E24E  84 0F
                ora     <page_entry          ; E250  9A 27
                sta     <page_entry          ; E252  97 27
                bra     MAIN_LOOP            ; E254  20 DB
LE256:          tst     <display_on          ; E256  0D 12
                beq     MAIN_LOOP            ; E258  27 D7
                tst     <cursor_mode         ; E25A  0D 0F
                beq     MAIN_LOOP            ; E25C  27 D3
                tst     <obj_mode            ; E25E  0D 13
                bne     MAIN_LOOP            ; E260  26 CF
                tst     <caps_lock           ; E262  0D 1D
                beq     LE26E                ; E264  27 08
                cmpa    #$61                 ; E266  81 61
                bcs     LE26E                ; E268  25 04
                suba    #$20                 ; E26A  80 20
                bra     LE286                ; E26C  20 18
LE26E:          tst     <key_shift           ; E26E  0D 10
                beq     LE286                ; E270  27 14
                cmpa    #$61                 ; E272  81 61
                bcs     LE27A                ; E274  25 04
                suba    #$20                 ; E276  80 20
                bra     LE286                ; E278  20 0C
LE27A:          cmpa    #$40                 ; E27A  81 40
                beq     LE286                ; E27C  27 08
                adda    #$0B                 ; E27E  8B 0B
                cmpa    #$40                 ; E280  81 40
                bcs     LE286                ; E282  25 02
                adda    #$1B                 ; E284  8B 1B
LE286:          jsr     [>cmd_table]         ; E286  AD 9F 00 40
                bra     MAIN_LOOP            ; E28A  20 A5
DISPATCH_FUNC:  cmpa    #$08                 ; E28C  81 08          códigos < $30: teclas de função
                bcs     LE29A                ; E28E  25 0A
                cmpa    #$0D                 ; E290  81 0D
                bhi     LE29A                ; E292  22 06
                tst     <obj_mode            ; E294  0D 13
                beq     LE29A                ; E296  27 02
                adda    #$03                 ; E298  8B 03
LE29A:          sta     <key_code            ; E29A  97 1E
                leax    >NOSHIFT_KEYS,PCR    ; E29C  30 8D 00 0A
LE2A0:          ldb     ,X+                  ; E2A0  E6 80
                beq     LE2AE                ; E2A2  27 0A
                cmpb    <key_code            ; E2A4  D1 1E
                beq     LE2B4                ; E2A6  27 0C
                bra     LE2A0                ; E2A8  20 F6

*  Teclas que ignoram SHIFT (RETURN, COLOR, CONTROL+CURSOR)
NOSHIFT_KEYS:   fcb     $07,$08,$0F,$00      ; E2AA  07 08 0F 00
LE2AE:          tst     <key_shift           ; E2AE  0D 10
                beq     LE2B4                ; E2B0  27 02
                adda    #$10                 ; E2B2  8B 10
LE2B4:          sta     <key_code            ; E2B4  97 1E
                cmpa    #$06                 ; E2B6  81 06
                bne     LE2C2                ; E2B8  26 08
                tst     <key_ctrl            ; E2BA  0D 25
                beq     LE2C2                ; E2BC  27 04
                lda     #$0F                 ; E2BE  86 0F
                sta     <key_code            ; E2C0  97 1E
LE2C2:          tst     <cursor_mode         ; E2C2  0D 0F
                bne     LE2E3                ; E2C4  26 1D
                leax    >CURSOR_OFF_KEYS,PCR ; E2C6  30 8D 00 0C
LE2CA:          ldb     ,X+                  ; E2CA  E6 80
                beq     LE2E3                ; E2CC  27 15
                cmpb    <key_code            ; E2CE  D1 1E
                lbeq    MAIN_LOOP            ; E2D0  10 27 FF 5D
                bra     LE2CA                ; E2D4  20 F4

*  Comandos ignorados enquanto o cursor está desligado
CURSOR_OFF_KEYS: fcb     $03,$07,$08,$09,$0A,$0E,$0F,$13 ; E2D6  03 07 08 09 0A 0E 0F 13
                fcb     $16,$19,$1A,$1E,$00  ; E2DE  16 19 1A 1E 00
LE2E3:          cmpa    #$01                 ; E2E3  81 01
                bne     LE2F3                ; E2E5  26 0C
                tst     <key_ctrl            ; E2E7  0D 25
                beq     LE2F3                ; E2E9  27 08
                tst     <cursor_mode         ; E2EB  0D 0F
                bne     LE2F3                ; E2ED  26 04
                lda     #$10                 ; E2EF  86 10
                sta     <key_code            ; E2F1  97 1E
LE2F3:          tst     <display_on          ; E2F3  0D 12
                bne     CALL_CMD             ; E2F5  26 17
                leax    >BLANKED_KEYS,PCR    ; E2F7  30 8D 00 0C
LE2FB:          ldb     ,X+                  ; E2FB  E6 80
                lbeq    MAIN_LOOP            ; E2FD  10 27 FF 30
                cmpb    <key_code            ; E301  D1 1E
                beq     CALL_CMD             ; E303  27 09
                bra     LE2FB                ; E305  20 F4

*  Comandos aceitos com a imagem desligada (BORDER BLK)
BLANKED_KEYS:   fcb     $01,$02,$05,$11,$12,$15,$00 ; E307  01 02 05 11 12 15 00
CALL_CMD:       tfr     A,B                  ; E30E  1F 89          salta para cmd_table[código]
                aslb                         ; E310  58
                ldx     #cmd_table           ; E311  8E 00 40
                abx                          ; E314  3A
                ldd     ,X                   ; E315  EC 84
                lbeq    MAIN_LOOP            ; E317  10 27 FF 16
                tfr     D,X                  ; E31B  1F 01
                jsr     ,X                   ; E31D  AD 84
                lbra    MAIN_LOOP            ; E31F  16 FF 0F

* ---------------------------------------------------------------------------
*  GETKEY: espera uma tecla (debounce e auto-repetição). Retorna o código
*  em key_code. Modificadores em key_shift / key_ctrl.
* ---------------------------------------------------------------------------
GETKEY:         bsr     KBD_SCAN             ; E322  8D 51
                lda     <key_raw             ; E324  96 1F
                bne     LE34A                ; E326  26 22
                bsr     KEY_DEBOUNCE         ; E328  8D 43
                bsr     KBD_SCAN             ; E32A  8D 49
                lda     <key_raw             ; E32C  96 1F
                bne     GETKEY               ; E32E  26 F2
LE330:          bsr     KBD_SCAN             ; E330  8D 43
                lda     <key_raw             ; E332  96 1F
                beq     LE330                ; E334  27 FA
                bsr     KEY_DEBOUNCE         ; E336  8D 35
                bsr     KBD_SCAN             ; E338  8D 3B
                lda     <key_raw             ; E33A  96 1F
                beq     LE330                ; E33C  27 F2
                ldy     #$0800               ; E33E  10 8E 08 00
                sty     <key_repeat          ; E342  10 9F 2D
                sta     <key_last            ; E345  97 20
                sta     <key_code            ; E347  97 1E
                rts                          ; E349  39
LE34A:          cmpa    <key_last            ; E34A  91 20
                bne     GETKEY               ; E34C  26 D4
                cmpa    #$09                 ; E34E  81 09
                bcs     GETKEY               ; E350  25 D0
                ldy     <key_repeat          ; E352  10 9E 2D
LE355:          bsr     KBD_SCAN             ; E355  8D 1E
                lda     <key_raw             ; E357  96 1F
                beq     GETKEY               ; E359  27 C7
                cmpa    <key_last            ; E35B  91 20
                bne     GETKEY               ; E35D  26 C3
                leay    -1,Y                 ; E35F  31 3F
                bne     LE355                ; E361  26 F2
                sta     <key_code            ; E363  97 1E
                ldy     #$0100               ; E365  10 8E 01 00
                sty     <key_repeat          ; E369  10 9F 2D
                rts                          ; E36C  39
KEY_DEBOUNCE:   ldd     <key_delay           ; E36D  DC 03          espera key_delay iterações
LE36F:          subd    #vdp_r1              ; E36F  83 00 01
                bne     LE36F                ; E372  26 FB
                rts                          ; E374  39

* ---------------------------------------------------------------------------
*  KBD_SCAN: varre a matriz 7x8. Escreve a linha em $8002 (bit n = 0 seleciona
*  a linha n+1), lê as colunas em $8002 (0 = tecla apertada). A coluna do
*  bit 3 é dos modificadores e só vale na linha 3 (EXT MODE). SHIFT (linha 1)
*  e CONTROL (linha 2) são lidos em separado. Resultado em key_raw.
* ---------------------------------------------------------------------------
KBD_SCAN:       clr     <key_shift           ; E375  0F 10
                clr     <key_ctrl            ; E377  0F 25
                clr     <key_mod3            ; E379  0F 26
                ldb     #$FF                 ; E37B  C6 FF
                lda     #$07                 ; E37D  86 07
                sta     <kbd_rows            ; E37F  97 06
                lda     #$7E                 ; E381  86 7E
                sta     <kbd_scan            ; E383  97 05
LE385:          sta     KEYBOARD             ; E385  B7 80 02
                lda     KEYBOARD             ; E388  B6 80 02
                cmpb    #$0F                 ; E38B  C1 0F
                beq     LE391                ; E38D  27 02
                ora     #$08                 ; E38F  8A 08
LE391:          cmpa    #$FF                 ; E391  81 FF
                bne     KBD_FOUND            ; E393  26 11
                addb    #$08                 ; E395  CB 08
                orcc    #$01                 ; E397  1A 01
                rol     <kbd_scan            ; E399  09 05
                lda     <kbd_scan            ; E39B  96 05
                anda    #$7F                 ; E39D  84 7F
                dec     <kbd_rows            ; E39F  0A 06
                bne     LE385                ; E3A1  26 E2
                clr     <key_raw             ; E3A3  0F 1F
                rts                          ; E3A5  39
KBD_FOUND:      sta     <tmp0e               ; E3A6  97 0E
                lda     #$7E                 ; E3A8  86 7E
                sta     KEYBOARD             ; E3AA  B7 80 02
                lda     KEYBOARD             ; E3AD  B6 80 02
                anda    #$08                 ; E3B0  84 08
                bne     LE3B8                ; E3B2  26 04
                inc     <key_shift           ; E3B4  0C 10
                bra     LE3D6                ; E3B6  20 1E
LE3B8:          lda     #$7D                 ; E3B8  86 7D
                sta     KEYBOARD             ; E3BA  B7 80 02
                lda     KEYBOARD             ; E3BD  B6 80 02
                anda    #$08                 ; E3C0  84 08
                bne     LE3C8                ; E3C2  26 04
                inc     <key_ctrl            ; E3C4  0C 25
                bra     LE3D6                ; E3C6  20 0E
LE3C8:          lda     #$3F                 ; E3C8  86 3F
                sta     KEYBOARD             ; E3CA  B7 80 02
                lda     KEYBOARD             ; E3CD  B6 80 02
                anda    #$08                 ; E3D0  84 08
                bne     LE3D6                ; E3D2  26 02
                inc     <key_mod3            ; E3D4  0C 26
LE3D6:          incb                         ; E3D6  5C
                lsr     <tmp0e               ; E3D7  04 0E
                bcs     LE3D6                ; E3D9  25 FB
                leax    >KEYMAP,PCR          ; E3DB  30 8D 00 05
                lda     B,X                  ; E3DF  A6 85
                sta     <key_raw             ; E3E1  97 1F
                rts                          ; E3E3  39

*  KEYMAP: código de cada posição da matriz (linha 1..7, bits 0..7):
*    $01 PAGE  $02 BORDER BLK  $03 CLEAR  $04 OBJ  $05 EXT MODE  $06 CURSOR
*    $07 RETURN  $08 COLOR  $09 ESQ/DIR  $0A CIMA/BAIXO  $0E AUTO CENTER
*    $00 = modificador/sem tecla (inclui o 'C' amarelo na linha 6, bit 3)
*    $1F = posição sem tecla física (linha 6, bit 6)
KEYMAP:         fcb     $31,$71,$61,$00,$37,$75,$6A,$6E ; E3E4  31 71 61 00 37 75 6A 6E
                fcb     $32,$77,$73,$00,$38,$69,$6B,$6D ; E3EC  32 77 73 00 38 69 6B 6D
                fcb     $33,$65,$64,$05,$39,$6F,$6C,$40 ; E3F4  33 65 64 05 39 6F 6C 40
                fcb     $34,$72,$66,$00,$30,$70,$07,$02 ; E3FC  34 72 66 00 30 70 07 02
                fcb     $35,$74,$67,$00,$3A,$06,$0E,$08 ; E404  35 74 67 00 3A 06 0E 08
                fcb     $36,$79,$68,$00,$0A,$04,$1F,$01 ; E40C  36 79 68 00 0A 04 1F 01
                fcb     $7A,$78,$63,$00,$09,$03,$76,$62 ; E414  7A 78 63 00 09 03 76 62

* ===========================================================================
*  Comandos (entradas de SYSTAB). Slot = código de tecla.
* ===========================================================================
*  Slot 0: imprime o caractere em A na posição do cursor
CMD_CHAR:       sta     <tmp0e               ; E41C  97 0E
                lbsr    CALC_TEXT_OFS        ; E41E  17 06 BB
                lbsr    CALC_CELL_VADDR      ; E421  17 03 39
                ldd     <cell_vaddr          ; E424  DC 09
                lbsr    VDP_SET_WRITE        ; E426  17 06 CF
                nop                          ; E429  12
                lbsr    CTRL_ACCENT          ; E42A  17 0F 65
                tst     <big_font            ; E42D  0D 28
                beq     LE46F                ; E42F  27 3E
                cmpa    #$01                 ; E431  81 01
                beq     LE441                ; E433  27 0C
                ldx     <fontb_big           ; E435  9E 37
                orb     #$80                 ; E437  CA 80
                stb     page_text,U          ; E439  E7 C9 02 00
                andb    #$7F                 ; E43D  C4 7F
                bra     DRAW_BIG_GLYPH       ; E43F  20 06
LE441:          ldx     <fonta_big           ; E441  9E 35
                stb     page_text,U          ; E443  E7 C9 02 00
DRAW_BIG_GLYPH: nop                          ; E447  12
                lbsr    BIGFONT_INDEX_B      ; E448  17 0F AE
                mul                          ; E44B  3D
                leax    D,X                  ; E44C  30 8B
                ldb     #$10                 ; E44E  C6 10
                bsr     VDP_WRITE_N          ; E450  8D 5D
                ldd     <cell_vaddr          ; E452  DC 09
                addd    #$0100               ; E454  C3 01 00
                lbsr    VDP_SET_WRITE        ; E457  17 06 9E
                ldb     #$10                 ; E45A  C6 10
                bsr     VDP_WRITE_N          ; E45C  8D 51
                ldd     <cell_vaddr          ; E45E  DC 09
                addd    #page_text           ; E460  C3 02 00
                lbsr    VDP_SET_WRITE        ; E463  17 06 92
                ldb     #$10                 ; E466  C6 10
                bsr     VDP_WRITE_N          ; E468  8D 45
                tst     <tmp0e               ; E46A  0D 0E
                bne     LE4A8                ; E46C  26 3A
                rts                          ; E46E  39
LE46F:          cmpa    #$01                 ; E46F  81 01
                beq     LE47F                ; E471  27 0C
                ldx     <fontb_small         ; E473  9E 2B
                orb     #$80                 ; E475  CA 80
                stb     page_text,U          ; E477  E7 C9 02 00
                andb    #$7F                 ; E47B  C4 7F
                bra     LE485                ; E47D  20 06
LE47F:          ldx     <fonta_small         ; E47F  9E 29
                stb     page_text,U          ; E481  E7 C9 02 00
LE485:          subb    #$13                 ; E485  C0 13
                lda     #$18                 ; E487  86 18
                mul                          ; E489  3D
                leax    D,X                  ; E48A  30 8B
                ldb     #$08                 ; E48C  C6 08
                bsr     VDP_WRITE_N          ; E48E  8D 1F
                ldd     <cell_vaddr          ; E490  DC 09
                addd    #$0100               ; E492  C3 01 00
                lbsr    VDP_SET_WRITE        ; E495  17 06 60
                ldb     #$08                 ; E498  C6 08
                bsr     VDP_WRITE_N          ; E49A  8D 13
                ldd     <cell_vaddr          ; E49C  DC 09
                addd    #page_text           ; E49E  C3 02 00
                lbsr    VDP_SET_WRITE        ; E4A1  17 06 54
                ldb     #$08                 ; E4A4  C6 08
                bsr     VDP_WRITE_N          ; E4A6  8D 07
LE4A8:          lbsr    SET_LINE_COLOR       ; E4A8  17 05 FD
                lbsr    CURSOR_ADVANCE       ; E4AB  17 02 63
                rts                          ; E4AE  39
VDP_WRITE_N:    lda     ,X+                  ; E4AF  A6 80          escreve B bytes de ,X na VRAM (com pausa)
                sta     VDP_DATA             ; E4B1  B7 80 00
                lbsr    VDP_DELAY            ; E4B4  17 06 24
                decb                         ; E4B7  5A
                bne     VDP_WRITE_N          ; E4B8  26 F5
                rts                          ; E4BA  39

*  Slot 9: ESQ/DIR sem SHIFT = cursor para a esquerda
CMD_LEFT:       lbsr    CURSOR_ERASE         ; E4BB  17 03 45
                lda     <cur_col             ; E4BE  96 0C
                tst     <big_font            ; E4C0  0D 28
                beq     LE4E0                ; E4C2  27 1C
                ldb     <cur_col             ; E4C4  D6 0C
                lsrb                         ; E4C6  54
                cmpb    #$01                 ; E4C7  C1 01
                bne     LE4D9                ; E4C9  26 0E
                ldb     <cur_line            ; E4CB  D6 0B
                bne     LE4D1                ; E4CD  26 02
                ldb     #$08                 ; E4CF  C6 08
LE4D1:          decb                         ; E4D1  5A
                stb     <cur_line            ; E4D2  D7 0B
                lbsr    GET_LINE_ATTR        ; E4D4  17 06 2A
                lda     #$1F                 ; E4D7  86 1F
LE4D9:          suba    #$02                 ; E4D9  80 02
                sta     <cur_col             ; E4DB  97 0C
                lbra    CURSOR_DRAW          ; E4DD  16 03 99
LE4E0:          cmpa    #$02                 ; E4E0  81 02
                bne     LE4F2                ; E4E2  26 0E
                ldb     <cur_line            ; E4E4  D6 0B
                bne     LE4EA                ; E4E6  26 02
                ldb     #$08                 ; E4E8  C6 08
LE4EA:          decb                         ; E4EA  5A
                stb     <cur_line            ; E4EB  D7 0B
                lbsr    GET_LINE_ATTR        ; E4ED  17 06 11
                lda     #$1E                 ; E4F0  86 1E
LE4F2:          deca                         ; E4F2  4A
                sta     <cur_col             ; E4F3  97 0C
                lbra    CURSOR_DRAW          ; E4F5  16 03 81

*  Slot 10: CIMA/BAIXO sem SHIFT = cursor para baixo
CMD_DOWN:       lbsr    CURSOR_ERASE         ; E4F8  17 03 08
                lda     <cur_line            ; E4FB  96 0B
                cmpa    #$07                 ; E4FD  81 07
                bne     LE503                ; E4FF  26 02
                lda     #$FF                 ; E501  86 FF
LE503:          inca                         ; E503  4C
                sta     <cur_line            ; E504  97 0B
                lbra    CURSOR_DRAW          ; E506  16 03 70

*  Slot 8: COLOR = próxima cor da linha
CMD_COLOR:      lda     <color_idx           ; E509  96 1C
                inca                         ; E50B  4C
                anda    #$0F                 ; E50C  84 0F
                sta     <color_idx           ; E50E  97 1C
                lbsr    COLOR_XLATE          ; E510  17 06 08
                ldb     #$10                 ; E513  C6 10
                mul                          ; E515  3D
                stb     <line_color          ; E516  D7 24
                lbsr    SET_LINE_COLOR       ; E518  17 05 8D
                lbra    CURSOR_DRAW          ; E51B  16 03 5B

*  Slot 4: OBJ = mostra/esconde o objeto (4 sprites 16x16)
CMD_OBJ:        lda     <obj_mode            ; E51E  96 13
                bne     OBJ_HIDE             ; E520  26 06
                lda     #$01                 ; E522  86 01
                sta     <obj_mode            ; E524  97 13
                bra     OBJ_DRAW             ; E526  20 26
OBJ_HIDE:       ldd     #$3C00               ; E528  CC 3C 00
                lbsr    VDP_SET_WRITE        ; E52B  17 05 CA
                ldb     #$04                 ; E52E  C6 04
LE530:          lda     #$D0                 ; E530  86 D0
                sta     VDP_DATA             ; E532  B7 80 00
                lbsr    VDP_DELAY            ; E535  17 05 A3
                clra                         ; E538  4F
                sta     VDP_DATA             ; E539  B7 80 00
                lbsr    VDP_DELAY            ; E53C  17 05 9C
                sta     VDP_DATA             ; E53F  B7 80 00
                lbsr    VDP_DELAY            ; E542  17 05 96
                sta     VDP_DATA             ; E545  B7 80 00
                decb                         ; E548  5A
                bne     LE530                ; E549  26 E5
                clr     <obj_mode            ; E54B  0F 13
                rts                          ; E54D  39
OBJ_DRAW:       ldd     #$3C00               ; E54E  CC 3C 00       grava os atributos dos sprites 0-3
                lbsr    VDP_SET_WRITE        ; E551  17 05 A4
                lda     <obj_y               ; E554  96 18
                sta     VDP_DATA             ; E556  B7 80 00
                lbsr    VDP_DELAY            ; E559  17 05 7F
                lda     <obj_x               ; E55C  96 19
                sta     VDP_DATA             ; E55E  B7 80 00
                ldb     <obj_shape           ; E561  D6 1A
                lda     #$10                 ; E563  86 10
                mul                          ; E565  3D
                stb     VDP_DATA             ; E566  F7 80 00
                lda     <obj_color           ; E569  96 17
                lbsr    COLOR_XLATE          ; E56B  17 05 AD
                sta     VDP_DATA             ; E56E  B7 80 00
                lbsr    VDP_DELAY            ; E571  17 05 67
                lda     <obj_y               ; E574  96 18
                adda    #$10                 ; E576  8B 10
                sta     VDP_DATA             ; E578  B7 80 00
                lbsr    VDP_DELAY            ; E57B  17 05 5D
                lda     <obj_x               ; E57E  96 19
                sta     VDP_DATA             ; E580  B7 80 00
                ldb     <obj_shape           ; E583  D6 1A
                lda     #$10                 ; E585  86 10
                mul                          ; E587  3D
                addb    #$04                 ; E588  CB 04
                stb     VDP_DATA             ; E58A  F7 80 00
                lda     <obj_color           ; E58D  96 17
                lbsr    COLOR_XLATE          ; E58F  17 05 89
                sta     VDP_DATA             ; E592  B7 80 00
                lbsr    VDP_DELAY            ; E595  17 05 43
                lda     <obj_y               ; E598  96 18
                sta     VDP_DATA             ; E59A  B7 80 00
                lda     <obj_x               ; E59D  96 19
                adda    #$10                 ; E59F  8B 10
                sta     VDP_DATA             ; E5A1  B7 80 00
                ldb     <obj_shape           ; E5A4  D6 1A
                lda     #$10                 ; E5A6  86 10
                mul                          ; E5A8  3D
                addb    #$08                 ; E5A9  CB 08
                stb     VDP_DATA             ; E5AB  F7 80 00
                lda     <obj_color           ; E5AE  96 17
                lbsr    COLOR_XLATE          ; E5B0  17 05 68
                sta     VDP_DATA             ; E5B3  B7 80 00
                lda     <obj_y               ; E5B6  96 18
                adda    #$10                 ; E5B8  8B 10
                sta     VDP_DATA             ; E5BA  B7 80 00
                lda     <obj_x               ; E5BD  96 19
                adda    #$10                 ; E5BF  8B 10
                sta     VDP_DATA             ; E5C1  B7 80 00
                ldb     <obj_shape           ; E5C4  D6 1A
                lda     #$10                 ; E5C6  86 10
                mul                          ; E5C8  3D
                addb    #$0C                 ; E5C9  CB 0C
                stb     VDP_DATA             ; E5CB  F7 80 00
                lda     <obj_color           ; E5CE  96 17
                lbsr    COLOR_XLATE          ; E5D0  17 05 48
                sta     VDP_DATA             ; E5D3  B7 80 00
                rts                          ; E5D6  39

*  Slot 2: BORDER BLK = liga/desliga a imagem (bit BLANK de R1)
CMD_BORDER:     lda     <vdp_r1              ; E5D7  96 01
                eora    #$40                 ; E5D9  88 40
                sta     <vdp_r1              ; E5DB  97 01
                ldb     #$81                 ; E5DD  C6 81
                sta     VDP_CTRL             ; E5DF  B7 80 01
                stb     VDP_CTRL             ; E5E2  F7 80 01
                lda     <display_on          ; E5E5  96 12
                eora    #$40                 ; E5E7  88 40
                sta     <display_on          ; E5E9  97 12
                rts                          ; E5EB  39

*  Slot 1: PAGE = próxima página (ou a página digitada antes)
CMD_PAGE:       lda     <page_entry          ; E5EC  96 27
                beq     LE610                ; E5EE  27 20
                cmpa    #$31                 ; E5F0  81 31
                bcs     LE5F7                ; E5F2  25 03
                clr     <page_entry          ; E5F4  0F 27
                rts                          ; E5F6  39
LE5F7:          cmpa    #$0A                 ; E5F7  81 0A
                bcs     LE609                ; E5F9  25 0E
                cmpa    #$1A                 ; E5FB  81 1A
                bcs     LE607                ; E5FD  25 08
                cmpa    #$2A                 ; E5FF  81 2A
                bcs     LE605                ; E601  25 02
                suba    #$06                 ; E603  80 06
LE605:          suba    #$06                 ; E605  80 06
LE607:          suba    #$06                 ; E607  80 06
LE609:          deca                         ; E609  4A
                clr     <page_entry          ; E60A  0F 27
                sta     <page                ; E60C  97 14
                bra     PAGE_REDRAW          ; E60E  20 0A
LE610:          lda     <page                ; E610  96 14
                cmpa    #$1D                 ; E612  81 1D
                bne     LE617                ; E614  26 01
                rts                          ; E616  39
LE617:          inca                         ; E617  4C
                sta     <page                ; E618  97 14
PAGE_REDRAW:    lda     <vdp_r1              ; E61A  96 01          redesenha as 8 linhas com a imagem desligada
                anda    #$BF                 ; E61C  84 BF
                sta     VDP_CTRL             ; E61E  B7 80 01
                ldb     #$81                 ; E621  C6 81
                stb     VDP_CTRL             ; E623  F7 80 01
                clr     <cur_line            ; E626  0F 0B
LE628:          bsr     LINE_REDRAW          ; E628  8D 23
                lda     <cur_line            ; E62A  96 0B
                cmpa    #$07                 ; E62C  81 07
                beq     LE635                ; E62E  27 05
                inca                         ; E630  4C
                sta     <cur_line            ; E631  97 0B
                bra     LE628                ; E633  20 F3
LE635:          clr     <cur_line            ; E635  0F 0B
                lda     #$02                 ; E637  86 02
                sta     <cur_col             ; E639  97 0C
                tst     <cursor_mode         ; E63B  0D 0F
                beq     LE642                ; E63D  27 03
                lbsr    CURSOR_DRAW          ; E63F  17 02 37
LE642:          lda     <vdp_r1              ; E642  96 01
                sta     VDP_CTRL             ; E644  B7 80 01
                ldb     #$81                 ; E647  C6 81
                stb     VDP_CTRL             ; E649  F7 80 01
                rts                          ; E64C  39
LINE_REDRAW:    clr     <cur_col             ; E64D  0F 0C          redesenha a linha cur_line
                lbsr    GET_LINE_ATTR        ; E64F  17 04 AF
                lbsr    CALC_CELL_VADDR      ; E652  17 01 08
                lbsr    VDP_SET_WRITE        ; E655  17 04 A0
                tfr     D,X                  ; E658  1F 01
                tst     <big_font            ; E65A  0D 28
                beq     LE662                ; E65C  27 04
                bsr     LINE_DRAW_BIG        ; E65E  8D 1A
                bra     LE664                ; E660  20 02
LE662:          bsr     LINE_DRAW_SMALL      ; E662  8D 64
LE664:          tfr     X,D                  ; E664  1F 10
                addd    #$2000               ; E666  C3 20 00
                lbsr    VDP_SET_WRITE        ; E669  17 04 8C
                ldy     #$0300               ; E66C  10 8E 03 00
                lda     <line_color          ; E670  96 24
LE672:          sta     VDP_DATA             ; E672  B7 80 00
                leay    -1,Y                 ; E675  31 3F
                bne     LE672                ; E677  26 F9
                rts                          ; E679  39
LINE_DRAW_BIG:  ldd     #vdp_r0              ; E67A  CC 00 00
LE67D:          std     <tmp15               ; E67D  DD 15
                lbsr    CALC_TEXT_OFS        ; E67F  17 04 5A
                leau    page_text,U          ; E682  33 C9 02 00
LE686:          lda     ,U+                  ; E686  A6 C0
LE688:          bmi     LE68F                ; E688  2B 05
                ldy     <fonta_big           ; E68A  10 9E 35
                bra     LE694                ; E68D  20 05
LE68F:          anda    #$7F                 ; E68F  84 7F
                ldy     <fontb_big           ; E691  10 9E 37
LE694:          nop                          ; E694  12
                lbsr    BIGFONT_INDEX_A      ; E695  17 0D 56
                mul                          ; E698  3D
                addd    <tmp15               ; E699  D3 15
                leay    D,Y                  ; E69B  31 AB
                ldb     #$10                 ; E69D  C6 10
LE69F:          lda     ,Y+                  ; E69F  A6 A0
                sta     VDP_DATA             ; E6A1  B7 80 00
                decb                         ; E6A4  5A
                bne     LE69F                ; E6A5  26 F8
                lda     <cur_col             ; E6A7  96 0C
                inca                         ; E6A9  4C
                sta     <cur_col             ; E6AA  97 0C
                cmpa    #$10                 ; E6AC  81 10
                beq     LE6B8                ; E6AE  27 08
                cmpa    #$0F                 ; E6B0  81 0F
                bne     LE686                ; E6B2  26 D2
                lda     #$40                 ; E6B4  86 40
                bra     LE688                ; E6B6  20 D0
LE6B8:          ldb     <tmp16               ; E6B8  D6 16
                cmpb    #$20                 ; E6BA  C1 20
                beq     LE6C7                ; E6BC  27 09
                clr     <cur_col             ; E6BE  0F 0C
                ldd     <tmp15               ; E6C0  DC 15
                addd    #key_shift           ; E6C2  C3 00 10
                bra     LE67D                ; E6C5  20 B6
LE6C7:          rts                          ; E6C7  39
LINE_DRAW_SMALL: ldd     #vdp_r0             ; E6C8  CC 00 00
LE6CB:          std     <tmp15               ; E6CB  DD 15
                lbsr    CALC_TEXT_OFS        ; E6CD  17 04 0C
                leau    page_text,U          ; E6D0  33 C9 02 00
LE6D4:          lda     ,U+                  ; E6D4  A6 C0
                bmi     LE6DD                ; E6D6  2B 05
                ldy     <fonta_small         ; E6D8  10 9E 29
                bra     LE6E2                ; E6DB  20 05
LE6DD:          anda    #$7F                 ; E6DD  84 7F
                ldy     <fontb_small         ; E6DF  10 9E 2B
LE6E2:          suba    #$13                 ; E6E2  80 13
                ldb     #$18                 ; E6E4  C6 18
                mul                          ; E6E6  3D
                addd    <tmp15               ; E6E7  D3 15
                leay    D,Y                  ; E6E9  31 AB
                ldb     #$08                 ; E6EB  C6 08
LE6ED:          lda     ,Y+                  ; E6ED  A6 A0
                sta     VDP_DATA             ; E6EF  B7 80 00
                decb                         ; E6F2  5A
                bne     LE6ED                ; E6F3  26 F8
                lda     <cur_col             ; E6F5  96 0C
                inca                         ; E6F7  4C
                sta     <cur_col             ; E6F8  97 0C
                cmpa    #$20                 ; E6FA  81 20
                bne     LE6D4                ; E6FC  26 D6
                ldb     <tmp16               ; E6FE  D6 16
                cmpb    #$10                 ; E700  C1 10
                beq     LE70D                ; E702  27 09
                clr     <cur_col             ; E704  0F 0C
                ldd     <tmp15               ; E706  DC 15
                addd    #tmp08               ; E708  C3 00 08
                bra     LE6CB                ; E70B  20 BE
LE70D:          rts                          ; E70D  39

*  Slot 25: SHIFT+ESQ/DIR = cursor para a direita
CMD_RIGHT:      lbsr    CURSOR_ERASE         ; E70E  17 00 F2
CURSOR_ADVANCE: lda     <cur_col             ; E711  96 0C
                tst     <big_font            ; E713  0D 28
                beq     LE734                ; E715  27 1D
                ldb     <cur_col             ; E717  D6 0C
                lsrb                         ; E719  54
                cmpb    #$0E                 ; E71A  C1 0E
                bne     LE72D                ; E71C  26 0F
                ldb     <cur_line            ; E71E  D6 0B
                cmpb    #$07                 ; E720  C1 07
                bne     LE726                ; E722  26 02
                ldb     #$FF                 ; E724  C6 FF
LE726:          incb                         ; E726  5C
                stb     <cur_line            ; E727  D7 0B
                lbsr    GET_LINE_ATTR        ; E729  17 03 D5
                clra                         ; E72C  4F
LE72D:          adda    #$02                 ; E72D  8B 02
                sta     <cur_col             ; E72F  97 0C
                lbra    CURSOR_DRAW          ; E731  16 01 45
LE734:          cmpa    #$1D                 ; E734  81 1D
                bne     LE748                ; E736  26 10
                ldb     <cur_line            ; E738  D6 0B
                cmpb    #$07                 ; E73A  C1 07
                bne     LE740                ; E73C  26 02
                ldb     #$FF                 ; E73E  C6 FF
LE740:          incb                         ; E740  5C
                stb     <cur_line            ; E741  D7 0B
                lbsr    GET_LINE_ATTR        ; E743  17 03 BB
                lda     #$01                 ; E746  86 01
LE748:          inca                         ; E748  4C
                sta     <cur_col             ; E749  97 0C
                lbra    CURSOR_DRAW          ; E74B  16 01 2B

*  Slot 26: SHIFT+CIMA/BAIXO = cursor para cima
CMD_UP:         lbsr    CURSOR_ERASE         ; E74E  17 00 B2
                lda     <cur_line            ; E751  96 0B
                bne     LE757                ; E753  26 02
                lda     #$08                 ; E755  86 08
LE757:          deca                         ; E757  4A
                sta     <cur_line            ; E758  97 0B
                lbra    CURSOR_DRAW          ; E75A  16 01 1C
CALC_CELL_VADDR: lda     <cur_col            ; E75D  96 0C          cell_vaddr = linha*$300 + coluna*8
                ldb     <big_font            ; E75F  D6 28
                beq     LE768                ; E761  27 05
                lsra                         ; E763  44
                ldb     #$10                 ; E764  C6 10
                bra     LE76A                ; E766  20 02
LE768:          ldb     #$08                 ; E768  C6 08
LE76A:          mul                          ; E76A  3D
                std     ,--S                 ; E76B  ED E3
                lda     <cur_line            ; E76D  96 0B
                ldb     #$10                 ; E76F  C6 10
                mul                          ; E771  3D
                lda     #$30                 ; E772  86 30
                mul                          ; E774  3D
                addd    ,S++                 ; E775  E3 E1
                std     <cell_vaddr          ; E777  DD 09
                rts                          ; E779  39

*  Slot 20: SHIFT+OBJ = próxima forma do objeto
CMD_OBJ_SHAPE:  lda     <obj_shape           ; E77A  96 1A
                inca                         ; E77C  4C
                anda    #$03                 ; E77D  84 03
                sta     <obj_shape           ; E77F  97 1A
                lbra    OBJ_DRAW             ; E781  16 FD CA

*  Slot 18: SHIFT+BORDER BLK = próxima cor de fundo (R7)
CMD_BACKDROP:   lda     <backdrop            ; E784  96 02
                inca                         ; E786  4C
                anda    #$0F                 ; E787  84 0F
                sta     <backdrop            ; E789  97 02
                lbsr    COLOR_XLATE          ; E78B  17 03 8D
                ldb     #$87                 ; E78E  C6 87
                sta     VDP_CTRL             ; E790  B7 80 01
                stb     VDP_CTRL             ; E793  F7 80 01
                rts                          ; E796  39

*  Slot 17: SHIFT+PAGE = página anterior
CMD_PAGE_PREV:  lda     <page                ; E797  96 14
                bne     LE79C                ; E799  26 01
                rts                          ; E79B  39
LE79C:          deca                         ; E79C  4A
                sta     <page                ; E79D  97 14
                lbra    PAGE_REDRAW          ; E79F  16 FE 78

*  Slots 5/21: EXT MODE = liga/desliga sobreposição ao vídeo externo (R0 bit0)
CMD_EXTVID:     lda     <vdp_r0              ; E7A2  96 00
                eora    #$01                 ; E7A4  88 01
                sta     <vdp_r0              ; E7A6  97 00
                ldb     #$80                 ; E7A8  C6 80
                sta     VDP_CTRL             ; E7AA  B7 80 01
                stb     VDP_CTRL             ; E7AD  F7 80 01
                lda     <extvid_on           ; E7B0  96 11
                eora    #$80                 ; E7B2  88 80
                sta     <extvid_on           ; E7B4  97 11
                rts                          ; E7B6  39

*  Slot 22: SHIFT+CURSOR = trava de maiúsculas
CMD_CAPS:       lda     <caps_lock           ; E7B7  96 1D
                eora    #$80                 ; E7B9  88 80
                sta     <caps_lock           ; E7BB  97 1D
                rts                          ; E7BD  39

*  Slot 15: CONTROL+CURSOR = alterna fonte grande/normal na linha
CMD_FONTSIZE:   lbsr    GET_LINE_ATTR        ; E7BE  17 03 40
                lda     <big_font            ; E7C1  96 28
                eora    #$01                 ; E7C3  88 01
                adda    <line_color          ; E7C5  9B 24
                sta     160,U                ; E7C7  A7 C9 00 A0
                lbsr    VDP_WAIT_VBLANK      ; E7CB  17 02 D1
                lbsr    LINE_REDRAW          ; E7CE  17 FE 7C
                lda     #$02                 ; E7D1  86 02
                sta     <cur_col             ; E7D3  97 0C
                lbsr    CURSOR_DRAW          ; E7D5  17 00 A1
                rts                          ; E7D8  39

*  Slot 6: CURSOR = alterna forma do cursor (desligado/bloco/sublinhado)
CMD_CURSOR:     lda     <cursor_mode         ; E7D9  96 0F
                inca                         ; E7DB  4C
                cmpa    #$03                 ; E7DC  81 03
                bne     LE7E4                ; E7DE  26 04
                clr     <cursor_mode         ; E7E0  0F 0F
                bra     CURSOR_ERASE         ; E7E2  20 1F
LE7E4:          sta     <cursor_mode         ; E7E4  97 0F
                cmpa    #$01                 ; E7E6  81 01
                bne     LE7F5                ; E7E8  26 0B
                lda     #$FF                 ; E7EA  86 FF
                sta     <cursor_pat          ; E7EC  97 21
                sta     <$22                 ; E7EE  97 22
                sta     <$23                 ; E7F0  97 23
                lbra    CURSOR_DRAW          ; E7F2  16 00 84
LE7F5:          lda     #$FC                 ; E7F5  86 FC
                sta     <cursor_pat          ; E7F7  97 21
                lda     #$3F                 ; E7F9  86 3F
                sta     <$22                 ; E7FB  97 22
                lda     #$E7                 ; E7FD  86 E7
                sta     <$23                 ; E7FF  97 23
                bra     CURSOR_DRAW          ; E801  20 76
CURSOR_ERASE:   lbsr    CALC_CELL_VADDR      ; E803  17 FF 57       restaura a célula sob o cursor
                addd    #page_text           ; E806  C3 02 00
                lbsr    VDP_SET_WRITE        ; E809  17 02 EC
                lbsr    CALC_TEXT_OFS        ; E80C  17 02 CD
                tst     <big_font            ; E80F  0D 28
                beq     LE846                ; E811  27 33
                lda     page_text,U          ; E813  A6 C9 02 00
                bmi     LE81D                ; E817  2B 04
                ldx     <fonta_big           ; E819  9E 35
                bra     LE821                ; E81B  20 04
LE81D:          anda    #$7F                 ; E81D  84 7F
                ldx     <fontb_big           ; E81F  9E 37
LE821:          nop                          ; E821  12
                lbsr    BIGFONT_INDEX_A      ; E822  17 0B C9
                mul                          ; E825  3D
                addd    #key_last            ; E826  C3 00 20
                leax    D,X                  ; E829  30 8B
                ldb     #$10                 ; E82B  C6 10
                lbsr    VDP_WRITE_N          ; E82D  17 FC 7F
                ldd     <cell_vaddr          ; E830  DC 09
                addd    #$2200               ; E832  C3 22 00
                lbsr    VDP_SET_WRITE        ; E835  17 02 C0
                lda     <line_color          ; E838  96 24
                ldb     #$0C                 ; E83A  C6 0C
LE83C:          sta     VDP_DATA             ; E83C  B7 80 00
                lbsr    VDP_DELAY            ; E83F  17 02 99
                decb                         ; E842  5A
                bne     LE83C                ; E843  26 F7
                rts                          ; E845  39
LE846:          lda     page_text,U          ; E846  A6 C9 02 00
                bmi     LE850                ; E84A  2B 04
                ldx     <fonta_small         ; E84C  9E 29
                bra     LE854                ; E84E  20 04
LE850:          anda    #$7F                 ; E850  84 7F
                ldx     <fontb_small         ; E852  9E 2B
LE854:          suba    #$13                 ; E854  80 13
                ldb     #$18                 ; E856  C6 18
                mul                          ; E858  3D
                addd    #key_shift           ; E859  C3 00 10
                leax    D,X                  ; E85C  30 8B
                ldb     #$08                 ; E85E  C6 08
                lbsr    VDP_WRITE_N          ; E860  17 FC 4C
                ldd     <cell_vaddr          ; E863  DC 09
                addd    #$2200               ; E865  C3 22 00
                lbsr    VDP_SET_WRITE        ; E868  17 02 8D
                lda     <line_color          ; E86B  96 24
                ldb     #$04                 ; E86D  C6 04
LE86F:          sta     VDP_DATA             ; E86F  B7 80 00
                lbsr    VDP_DELAY            ; E872  17 02 66
                decb                         ; E875  5A
                bne     LE86F                ; E876  26 F7
                rts                          ; E878  39
CURSOR_DRAW:    lbsr    GET_LINE_ATTR        ; E879  17 02 85
                lbsr    CALC_CELL_VADDR      ; E87C  17 FE DE
                addd    #$0204               ; E87F  C3 02 04
                lbsr    VDP_SET_WRITE        ; E882  17 02 73
                tst     <big_font            ; E885  0D 28
                beq     LE8EE                ; E887  27 65
                lda     <cursor_pat          ; E889  96 21
                sta     VDP_DATA             ; E88B  B7 80 00
                lbsr    VDP_DELAY            ; E88E  17 02 4A
                sta     VDP_DATA             ; E891  B7 80 00
                eora    #$FF                 ; E894  88 FF
                lbsr    VDP_DELAY            ; E896  17 02 42
                sta     VDP_DATA             ; E899  B7 80 00
                lbsr    VDP_DELAY            ; E89C  17 02 3C
                sta     VDP_DATA             ; E89F  B7 80 00
                ldd     <cell_vaddr          ; E8A2  DC 09
                addd    #$020C               ; E8A4  C3 02 0C
                lbsr    VDP_SET_WRITE        ; E8A7  17 02 4E
                lda     <$22                 ; E8AA  96 22
                sta     VDP_DATA             ; E8AC  B7 80 00
                lbsr    VDP_DELAY            ; E8AF  17 02 29
                sta     VDP_DATA             ; E8B2  B7 80 00
                eora    #$FF                 ; E8B5  88 FF
                lbsr    VDP_DELAY            ; E8B7  17 02 21
                sta     VDP_DATA             ; E8BA  B7 80 00
                lbsr    VDP_DELAY            ; E8BD  17 02 1B
                sta     VDP_DATA             ; E8C0  B7 80 00
                ldd     <cell_vaddr          ; E8C3  DC 09
                addd    #$2204               ; E8C5  C3 22 04
                lbsr    VDP_SET_WRITE        ; E8C8  17 02 2D
                lda     <line_color          ; E8CB  96 24
                ldb     #$04                 ; E8CD  C6 04
LE8CF:          sta     VDP_DATA             ; E8CF  B7 80 00
                lbsr    VDP_DELAY            ; E8D2  17 02 06
                decb                         ; E8D5  5A
                bne     LE8CF                ; E8D6  26 F7
                ldd     <cell_vaddr          ; E8D8  DC 09
                addd    #$220C               ; E8DA  C3 22 0C
                lbsr    VDP_SET_WRITE        ; E8DD  17 02 18
                lda     <line_color          ; E8E0  96 24
                ldb     #$04                 ; E8E2  C6 04
LE8E4:          sta     VDP_DATA             ; E8E4  B7 80 00
                lbsr    VDP_DELAY            ; E8E7  17 01 F1
                decb                         ; E8EA  5A
                bne     LE8E4                ; E8EB  26 F7
                rts                          ; E8ED  39
LE8EE:          lda     <$23                 ; E8EE  96 23
                sta     VDP_DATA             ; E8F0  B7 80 00
                lbsr    VDP_DELAY            ; E8F3  17 01 E5
                sta     VDP_DATA             ; E8F6  B7 80 00
                eora    #$FF                 ; E8F9  88 FF
                lbsr    VDP_DELAY            ; E8FB  17 01 DD
                sta     VDP_DATA             ; E8FE  B7 80 00
                lbsr    VDP_DELAY            ; E901  17 01 D7
                sta     VDP_DATA             ; E904  B7 80 00
                ldd     <cell_vaddr          ; E907  DC 09
                addd    #$2204               ; E909  C3 22 04
                lbsr    VDP_SET_WRITE        ; E90C  17 01 E9
                lda     <line_color          ; E90F  96 24
                ldb     #$04                 ; E911  C6 04
LE913:          sta     VDP_DATA             ; E913  B7 80 00
                lbsr    VDP_DELAY            ; E916  17 01 C2
                decb                         ; E919  5A
                bne     LE913                ; E91A  26 F7
                rts                          ; E91C  39

*  Slot 7: RETURN = próxima linha
CMD_RETURN:     lbsr    CURSOR_ERASE         ; E91D  17 FE E3
                lda     #$02                 ; E920  86 02
                sta     <cur_col             ; E922  97 0C
                lda     <cur_line            ; E924  96 0B
                cmpa    #$07                 ; E926  81 07
                bne     LE92C                ; E928  26 02
                lda     #$FF                 ; E92A  86 FF
LE92C:          inca                         ; E92C  4C
                sta     <cur_line            ; E92D  97 0B
                lbra    CURSOR_DRAW          ; E92F  16 FF 47

*  Slot 19: SHIFT+CLEAR = apaga a página
CMD_CLEAR_PAGE: clr     <cur_line            ; E932  0F 0B
                clr     <cur_col             ; E934  0F 0C
                lbsr    CALC_TEXT_OFS        ; E936  17 01 A3
                clrb                         ; E939  5F
                lda     #$40                 ; E93A  86 40
                leau    page_text,U          ; E93C  33 C9 02 00
LE940:          sta     ,U+                  ; E940  A7 C0
                decb                         ; E942  5A
                bne     LE940                ; E943  26 FB
                lda     <page                ; E945  96 14
                ldb     #$08                 ; E947  C6 08
                mul                          ; E949  3D
                addd    #line_attr           ; E94A  C3 00 A0
                tfr     D,U                  ; E94D  1F 03
                ldb     #$08                 ; E94F  C6 08
                lda     <line_color          ; E951  96 24
LE953:          sta     ,U+                  ; E953  A7 C0
                decb                         ; E955  5A
                bne     LE953                ; E956  26 FB
                clr     <big_font            ; E958  0F 28
                lda     #$02                 ; E95A  86 02
                sta     <cur_col             ; E95C  97 0C
                lbra    PAGE_REDRAW          ; E95E  16 FC B9

*  Slot 3: CLEAR = apaga a linha
CMD_CLEAR_LINE: clr     <cur_col             ; E961  0F 0C
                lbsr    CALC_TEXT_OFS        ; E963  17 01 76
                ldb     #$20                 ; E966  C6 20
                lda     #$40                 ; E968  86 40
                leau    page_text,U          ; E96A  33 C9 02 00
LE96E:          sta     ,U+                  ; E96E  A7 C0
                decb                         ; E970  5A
                bne     LE96E                ; E971  26 FB
                lbsr    VDP_WAIT_VBLANK      ; E973  17 01 29
                lbsr    LINE_REDRAW          ; E976  17 FC D4
                lda     #$02                 ; E979  86 02
                sta     <cur_col             ; E97B  97 0C
                lbsr    CURSOR_DRAW          ; E97D  17 FE F9
                rts                          ; E980  39

*  Slot 12: modo OBJ, ESQ/DIR = objeto para a esquerda
CMD_OBJ_LEFT:   lda     <obj_x               ; E981  96 19
                suba    #$04                 ; E983  80 04
                bcc     LE988                ; E985  24 01
                clra                         ; E987  4F
LE988:          sta     <obj_x               ; E988  97 19
                lbra    OBJ_DRAW             ; E98A  16 FB C1

*  Slot 13: modo OBJ, CIMA/BAIXO = objeto para baixo
CMD_OBJ_DOWN:   lda     <obj_y               ; E98D  96 18
                adda    #$04                 ; E98F  8B 04
                cmpa    #$A4                 ; E991  81 A4
                bcs     LE997                ; E993  25 02
                suba    #$04                 ; E995  80 04
LE997:          sta     <obj_y               ; E997  97 18
                lbra    OBJ_DRAW             ; E999  16 FB B2

*  Slots 11/27: modo OBJ, COLOR = cor do objeto
CMD_OBJ_COLOR:  lda     <obj_color           ; E99C  96 17
                inca                         ; E99E  4C
                anda    #$0F                 ; E99F  84 0F
                sta     <obj_color           ; E9A1  97 17
                lbra    OBJ_DRAW             ; E9A3  16 FB A8

*  Slot 28: modo OBJ, SHIFT+ESQ/DIR = objeto para a direita
CMD_OBJ_RIGHT:  lda     <obj_x               ; E9A6  96 19
                adda    #$04                 ; E9A8  8B 04
                cmpa    #$E4                 ; E9AA  81 E4
                bcs     LE9B0                ; E9AC  25 02
                suba    #$04                 ; E9AE  80 04
LE9B0:          sta     <obj_x               ; E9B0  97 19
                lbra    OBJ_DRAW             ; E9B2  16 FB 99

*  Slot 29: modo OBJ, SHIFT+CIMA/BAIXO = objeto para cima
CMD_OBJ_UP:     lda     <obj_y               ; E9B5  96 18
                suba    #$04                 ; E9B7  80 04
                bcc     LE9BC                ; E9B9  24 01
                clra                         ; E9BB  4F
LE9BC:          sta     <obj_y               ; E9BC  97 18
                lbra    OBJ_DRAW             ; E9BE  16 FB 8D

*  Slot 30: SHIFT+AUTO CENTER = centraliza todas as linhas
CMD_CENTER_ALL: lbsr    CURSOR_ERASE         ; E9C1  17 FE 3F
                clr     <cur_line            ; E9C4  0F 0B
LE9C6:          clr     <cur_col             ; E9C6  0F 0C
                bsr     CENTER_LINE          ; E9C8  8D 22
                lda     <cur_line            ; E9CA  96 0B
                cmpa    #$07                 ; E9CC  81 07
                beq     LE9D5                ; E9CE  27 05
                inca                         ; E9D0  4C
                sta     <cur_line            ; E9D1  97 0B
                bra     LE9C6                ; E9D3  20 F1
LE9D5:          lda     #$02                 ; E9D5  86 02
                sta     <cur_col             ; E9D7  97 0C
                clr     <cur_line            ; E9D9  0F 0B
                lbsr    CURSOR_DRAW          ; E9DB  17 FE 9B
                rts                          ; E9DE  39

*  Slot 14: AUTO CENTER = centraliza a linha atual
CMD_CENTER:     lbsr    CURSOR_ERASE         ; E9DF  17 FE 21
                bsr     CENTER_LINE          ; E9E2  8D 08
                lda     #$02                 ; E9E4  86 02
                sta     <cur_col             ; E9E6  97 0C
                lbsr    CURSOR_DRAW          ; E9E8  17 FE 8E
                rts                          ; E9EB  39
CENTER_LINE:    lbsr    GET_LINE_ATTR        ; E9EC  17 01 12
                lda     <page                ; E9EF  96 14
                ldb     #$08                 ; E9F1  C6 08
                mul                          ; E9F3  3D
                addb    <cur_line            ; E9F4  DB 0B
                lda     #$20                 ; E9F6  86 20
                mul                          ; E9F8  3D
                addd    #page_text           ; E9F9  C3 02 00
                tfr     D,X                  ; E9FC  1F 01
                std     <tmp07               ; E9FE  DD 07
                tfr     D,U                  ; EA00  1F 03
                addd    #key_shift           ; EA02  C3 00 10
                tst     <big_font            ; EA05  0D 28
                bne     LEA0C                ; EA07  26 03
                addd    #key_shift           ; EA09  C3 00 10
LEA0C:          tfr     D,Y                  ; EA0C  1F 02
                ldb     #$10                 ; EA0E  C6 10
                tst     <big_font            ; EA10  0D 28
                bne     LEA16                ; EA12  26 02
                addb    #$10                 ; EA14  CB 10
LEA16:          lda     ,X+                  ; EA16  A6 80
                leau    1,U                  ; EA18  33 41
                anda    #$7F                 ; EA1A  84 7F
                cmpa    #$40                 ; EA1C  81 40
                bne     LEA24                ; EA1E  26 04
                decb                         ; EA20  5A
                bne     LEA16                ; EA21  26 F3
                rts                          ; EA23  39
LEA24:          stb     <tmp2f               ; EA24  D7 2F
                ldb     #$10                 ; EA26  C6 10
                tst     <big_font            ; EA28  0D 28
                bne     LEA2E                ; EA2A  26 02
                addb    #$10                 ; EA2C  CB 10
LEA2E:          subb    <tmp2f               ; EA2E  D0 2F
                stb     <tmp2f               ; EA30  D7 2F
                clrb                         ; EA32  5F
LEA33:          lda     ,-Y                  ; EA33  A6 A2
                anda    #$7F                 ; EA35  84 7F
                cmpa    #$40                 ; EA37  81 40
                bne     LEA3E                ; EA39  26 03
                incb                         ; EA3B  5C
                bra     LEA33                ; EA3C  20 F5
LEA3E:          addb    <tmp2f               ; EA3E  DB 2F
                stb     <tmp2f               ; EA40  D7 2F
                ldb     #$10                 ; EA42  C6 10
                tst     <big_font            ; EA44  0D 28
                bne     LEA4A                ; EA46  26 02
                addb    #$10                 ; EA48  CB 10
LEA4A:          subb    <tmp2f               ; EA4A  D0 2F
                tfr     S,X                  ; EA4C  1F 41
                leax    -1,X                 ; EA4E  30 1F
                clr     ,-X                  ; EA50  6F 82
                leau    -1,U                 ; EA52  33 5F
LEA54:          lda     ,U+                  ; EA54  A6 C0
                sta     ,-X                  ; EA56  A7 82
                decb                         ; EA58  5A
                bne     LEA54                ; EA59  26 F9
                ldb     <tmp2f               ; EA5B  D6 2F
                lda     <tmp2f               ; EA5D  96 2F
                ldu     <tmp07               ; EA5F  DE 07
                lsra                         ; EA61  44
                sta     <tmp2f               ; EA62  97 2F
                tst     <big_font            ; EA64  0D 28
                beq     LEA6A                ; EA66  27 02
                inc     <tmp2f               ; EA68  0C 2F
LEA6A:          lsrb                         ; EA6A  54
                bcc     LEA6E                ; EA6B  24 01
                incb                         ; EA6D  5C
LEA6E:          tst     <big_font            ; EA6E  0D 28
                beq     LEA76                ; EA70  27 04
                decb                         ; EA72  5A
                tstb                         ; EA73  5D
                beq     LEA98                ; EA74  27 22
LEA76:          lda     #$40                 ; EA76  86 40
                leau    16,U                 ; EA78  33 C8 10
                tst     <big_font            ; EA7B  0D 28
                bne     LEA82                ; EA7D  26 03
                leau    16,U                 ; EA7F  33 C8 10
LEA82:          sta     ,-U                  ; EA82  A7 C2
                decb                         ; EA84  5A
                bne     LEA82                ; EA85  26 FB
LEA87:          lda     ,X+                  ; EA87  A6 80
                beq     LEA8F                ; EA89  27 04
                sta     ,-U                  ; EA8B  A7 C2
                bra     LEA87                ; EA8D  20 F8
LEA8F:          ldb     <tmp2f               ; EA8F  D6 2F
                lda     #$40                 ; EA91  86 40
LEA93:          sta     ,-U                  ; EA93  A7 C2
                decb                         ; EA95  5A
                bne     LEA93                ; EA96  26 FB
LEA98:          lbsr    VDP_WAIT_VBLANK      ; EA98  17 00 04
                lbsr    LINE_REDRAW          ; EA9B  17 FB AF
                rts                          ; EA9E  39

* ===========================================================================
*  Rotinas de apoio ao VDP
* ===========================================================================
VDP_WAIT_VBLANK: lda     VDP_CTRL            ; EA9F  B6 80 01       lê o status até o bit F (fim de quadro)
LEAA2:          lda     VDP_CTRL             ; EAA2  B6 80 01
                bpl     LEAA2                ; EAA5  2A FB
                rts                          ; EAA7  39
SET_LINE_COLOR: lda     <page                ; EAA8  96 14          grava a cor em line_attr e na tabela de cores
                ldb     #$08                 ; EAAA  C6 08
                mul                          ; EAAC  3D
                addb    <cur_line            ; EAAD  DB 0B
                tfr     D,U                  ; EAAF  1F 03
                lda     160,U                ; EAB1  A6 C9 00 A0
                anda    #$0F                 ; EAB5  84 0F
                adda    <line_color          ; EAB7  9B 24
                sta     160,U                ; EAB9  A7 C9 00 A0
                lda     <cur_line            ; EABD  96 0B
                ldb     #$10                 ; EABF  C6 10
                mul                          ; EAC1  3D
                lda     #$30                 ; EAC2  86 30
                mul                          ; EAC4  3D
FILL_LINE_COLOR: addd    #$2000              ; EAC5  C3 20 00       preenche $300 bytes de cor a partir de D+$2000
                lbsr    VDP_SET_WRITE        ; EAC8  17 00 2D
                ldx     #$0300               ; EACB  8E 03 00
                lda     <line_color          ; EACE  96 24
LEAD0:          sta     VDP_DATA             ; EAD0  B7 80 00
                lbsr    VDP_DELAY            ; EAD3  17 00 05
                leax    -1,X                 ; EAD6  30 1F
                bne     LEAD0                ; EAD8  26 F6
                rts                          ; EADA  39
VDP_DELAY:      rts                          ; EADB  39             só RTS: pausa proposital entre escritas na VRAM
CALC_TEXT_OFS:  clrb                         ; EADC  5F             U = page*256 + line*32 + col
                lda     <page                ; EADD  96 14
                std     ,--S                 ; EADF  ED E3
                lda     <cur_line            ; EAE1  96 0B
                ldb     #$20                 ; EAE3  C6 20
                mul                          ; EAE5  3D
                stb     ,-S                  ; EAE6  E7 E2
                ldb     <cur_col             ; EAE8  D6 0C
                tst     <big_font            ; EAEA  0D 28
                beq     LEAF0                ; EAEC  27 02
                lsrb                         ; EAEE  54
                incb                         ; EAEF  5C
LEAF0:          addb    ,S+                  ; EAF0  EB E0
                clra                         ; EAF2  4F
                addd    ,S++                 ; EAF3  E3 E1
                tfr     D,U                  ; EAF5  1F 03
                rts                          ; EAF7  39
VDP_SET_WRITE:  stb     VDP_CTRL             ; EAF8  F7 80 01       endereço de escrita da VRAM = D
                ora     #$40                 ; EAFB  8A 40
                sta     VDP_CTRL             ; EAFD  B7 80 01
                rts                          ; EB00  39
GET_LINE_ATTR:  ldb     <page                ; EB01  D6 14          big_font e line_color da linha atual
                lda     #$08                 ; EB03  86 08
                mul                          ; EB05  3D
                addb    <cur_line            ; EB06  DB 0B
                tfr     D,U                  ; EB08  1F 03
                lda     160,U                ; EB0A  A6 C9 00 A0
                anda    #$01                 ; EB0E  84 01
                sta     <big_font            ; EB10  97 28
                lda     160,U                ; EB12  A6 C9 00 A0
                anda    #$F0                 ; EB16  84 F0
                sta     <line_color          ; EB18  97 24
                rts                          ; EB1A  39
COLOR_XLATE:    leax    >COLORMAP,PCR        ; EB1B  30 8D 00 05    A = COLORMAP[A]
                ldb     A,X                  ; EB1F  E6 86
                tfr     B,A                  ; EB21  1F 98
                rts                          ; EB23  39

*  Ordem das 16 cores ao apertar COLOR: índice -> cor do TMS9918
*  (preto, transp.? , azul médio, azul claro, vermelho escuro, magenta, ...)
COLORMAP:       fcb     $00,$01,$04,$05,$07,$0D,$06,$08 ; EB24  00 01 04 05 07 0D 06 08
                fcb     $09,$0C,$02,$03,$0A,$0B,$0E,$0F ; EB2C  09 0C 02 03 0A 0B 0E 0F

* ===========================================================================
*  Slot 16: CONTROL+PAGE = rolagem vertical suave das páginas (letreiro de
*  créditos). Rola pixel a pixel até a última página; ESPAÇO interrompe.
* ===========================================================================
CMD_ROLL:       lda     <page                ; EB34  96 14
                cmpa    #$1D                 ; EB36  81 1D
                lbeq    LED1B                ; EB38  10 27 01 DF
                lda     #$01                 ; EB3C  86 01
                sta     <tmp07               ; EB3E  97 07
                clr     <cur_line            ; EB40  0F 0B
                clr     <tmp2f               ; EB42  0F 2F
                clr     <roll_stop           ; EB44  0F 3F
                lda     <page                ; EB46  96 14
                ldb     #$08                 ; EB48  C6 08
                mul                          ; EB4A  3D
                stb     <tmp08               ; EB4B  D7 08
                lda     #$FB                 ; EB4D  86 FB
                sta     KEYBOARD             ; EB4F  B7 80 02
                bra     LEB57                ; EB52  20 03
LEB54:          lbsr    LEE19                ; EB54  17 02 C2
LEB57:          lbsr    LEDE4                ; EB57  17 02 8A
                lda     #$02                 ; EB5A  86 02
                sta     <cur_col             ; EB5C  97 0C
                tst     <tmp2f               ; EB5E  0D 2F
                bne     LEB6E                ; EB60  26 0C
                ldb     <tmp08               ; EB62  D6 08
                ldx     #line_attr           ; EB64  8E 00 A0
                abx                          ; EB67  3A
                lda     ,X                   ; EB68  A6 84
                anda    #$01                 ; EB6A  84 01
                sta     <big_font            ; EB6C  97 28
LEB6E:          lda     <tmp2f               ; EB6E  96 2F
                cmpa    #$02                 ; EB70  81 02
                bne     LEBAC                ; EB72  26 38
                lbsr    LEC84                ; EB74  17 01 0D
                lda     <cur_line            ; EB77  96 0B
                cmpa    #$17                 ; EB79  81 17
                bne     LEB54                ; EB7B  26 D7
                lda     KEYBOARD             ; EB7D  B6 80 02
                anda    #$80                 ; EB80  84 80
                bne     LEB88                ; EB82  26 04
                lda     #$01                 ; EB84  86 01
                sta     <roll_stop           ; EB86  97 3F
LEB88:          ldb     <tmp08               ; EB88  D6 08
                andb    #$07                 ; EB8A  C4 07
                cmpb    #$07                 ; EB8C  C1 07
                bne     LEB54                ; EB8E  26 C4
                lda     <tmp07               ; EB90  96 07
                bne     LEB54                ; EB92  26 C0
                lda     <roll_stop           ; EB94  96 3F
                bne     LEB9E                ; EB96  26 06
                lda     <tmp08               ; EB98  96 08
                cmpa    #$EF                 ; EB9A  81 EF
                bne     LEB54                ; EB9C  26 B6
LEB9E:          lda     #$02                 ; EB9E  86 02
                sta     <cur_col             ; EBA0  97 0C
                clr     <cur_line            ; EBA2  0F 0B
                lda     <tmp08               ; EBA4  96 08
                lsra                         ; EBA6  44
                lsra                         ; EBA7  44
                lsra                         ; EBA8  44
                sta     <page                ; EBA9  97 14
                rts                          ; EBAB  39
LEBAC:          lbsr    LEBB1                ; EBAC  17 00 02
                bra     LEB54                ; EBAF  20 A3
LEBB1:          ldb     #$10                 ; EBB1  C6 10
                stb     VDP_CTRL             ; EBB3  F7 80 01
                lda     <cur_line            ; EBB6  96 0B
                ora     #$40                 ; EBB8  8A 40
                sta     VDP_CTRL             ; EBBA  B7 80 01
                tst     <big_font            ; EBBD  0D 28
                bne     LEC22                ; EBBF  26 61
LEBC1:          lda     ,U+                  ; EBC1  A6 C0
                bmi     LEBD0                ; EBC3  2B 0B
                ldx     <fonta_small         ; EBC5  9E 29
                suba    #$13                 ; EBC7  80 13
                ldb     #$18                 ; EBC9  C6 18
                mul                          ; EBCB  3D
                leax    D,X                  ; EBCC  30 8B
                bra     LEBDB                ; EBCE  20 0B
LEBD0:          ldx     <fontb_small         ; EBD0  9E 2B
                anda    #$7F                 ; EBD2  84 7F
                suba    #$13                 ; EBD4  80 13
                ldb     #$18                 ; EBD6  C6 18
                mul                          ; EBD8  3D
                leax    D,X                  ; EBD9  30 8B
LEBDB:          lda     <tmp07               ; EBDB  96 07
                tst     <tmp2f               ; EBDD  0D 2F
                beq     LEBE3                ; EBDF  27 02
                adda    #$08                 ; EBE1  8B 08
LEBE3:          leax    A,X                  ; EBE3  30 86
                lda     ,X+                  ; EBE5  A6 80
                sta     VDP_DATA             ; EBE7  B7 80 00
                lda     ,X+                  ; EBEA  A6 80
                sta     VDP_DATA             ; EBEC  B7 80 00
                lda     ,X+                  ; EBEF  A6 80
                sta     VDP_DATA             ; EBF1  B7 80 00
                lda     ,X+                  ; EBF4  A6 80
                sta     VDP_DATA             ; EBF6  B7 80 00
                lda     ,X+                  ; EBF9  A6 80
                sta     VDP_DATA             ; EBFB  B7 80 00
                lda     ,X+                  ; EBFE  A6 80
                sta     VDP_DATA             ; EC00  B7 80 00
                lda     ,X+                  ; EC03  A6 80
                sta     VDP_DATA             ; EC05  B7 80 00
                lda     ,X+                  ; EC08  A6 80
                sta     VDP_DATA             ; EC0A  B7 80 00
                lda     <cur_col             ; EC0D  96 0C
                inca                         ; EC0F  4C
                sta     <cur_col             ; EC10  97 0C
                cmpa    #$1E                 ; EC12  81 1E
                bne     LEBC1                ; EC14  26 AB
                lda     <tmp07               ; EC16  96 07
                bne     LEC21                ; EC18  26 07
                lda     <tmp2f               ; EC1A  96 2F
                bne     LEC21                ; EC1C  26 03
                lbra    LEE6A                ; EC1E  16 02 49
LEC21:          rts                          ; EC21  39
LEC22:          lbsr    LEDEF                ; EC22  17 01 CA
                clrb                         ; EC25  5F
                lda     #$10                 ; EC26  86 10
                tst     <tmp2f               ; EC28  0D 2F
                beq     LEC30                ; EC2A  27 04
                adda    #$10                 ; EC2C  8B 10
                addb    #$10                 ; EC2E  CB 10
LEC30:          leay    A,X                  ; EC30  31 86
                leax    B,X                  ; EC32  30 85
                lda     <tmp07               ; EC34  96 07
                leax    A,X                  ; EC36  30 86
                ldb     #$08                 ; EC38  C6 08
                subb    <tmp07               ; EC3A  D0 07
LEC3C:          lda     ,X+                  ; EC3C  A6 80
                sta     VDP_DATA             ; EC3E  B7 80 00
                decb                         ; EC41  5A
                bne     LEC3C                ; EC42  26 F8
                ldb     <tmp07               ; EC44  D6 07
                beq     LEC50                ; EC46  27 08
LEC48:          lda     ,Y+                  ; EC48  A6 A0
                sta     VDP_DATA             ; EC4A  B7 80 00
                decb                         ; EC4D  5A
                bne     LEC48                ; EC4E  26 F8
LEC50:          leay    16,X                 ; EC50  31 88 10
                ldb     <tmp07               ; EC53  D6 07
                leax    B,X                  ; EC55  30 85
                ldb     #$08                 ; EC57  C6 08
                subb    <tmp07               ; EC59  D0 07
LEC5B:          lda     ,X+                  ; EC5B  A6 80
                sta     VDP_DATA             ; EC5D  B7 80 00
                decb                         ; EC60  5A
                bne     LEC5B                ; EC61  26 F8
                ldb     <tmp07               ; EC63  D6 07
                beq     LEC6F                ; EC65  27 08
LEC67:          lda     ,Y+                  ; EC67  A6 A0
                sta     VDP_DATA             ; EC69  B7 80 00
                decb                         ; EC6C  5A
                bne     LEC67                ; EC6D  26 F8
LEC6F:          lda     <cur_col             ; EC6F  96 0C
                inca                         ; EC71  4C
                sta     <cur_col             ; EC72  97 0C
                cmpa    #$10                 ; EC74  81 10
                bne     LEC22                ; EC76  26 AA
                lda     <tmp07               ; EC78  96 07
                bne     LEC83                ; EC7A  26 07
                lda     <tmp2f               ; EC7C  96 2F
                bne     LEC83                ; EC7E  26 03
                lbra    LEE6A                ; EC80  16 01 E7
LEC83:          rts                          ; EC83  39
LEC84:          ldb     #$10                 ; EC84  C6 10
                lda     <cur_line            ; EC86  96 0B
                tfr     D,Y                  ; EC88  1F 02
                tst     <big_font            ; EC8A  0D 28
                lbne    LED1C                ; EC8C  10 26 00 8C
LEC90:          lbsr    LEDEF                ; EC90  17 01 5C
                tfr     Y,D                  ; EC93  1F 20
                stb     VDP_CTRL             ; EC95  F7 80 01
                ora     #$40                 ; EC98  8A 40
                sta     VDP_CTRL             ; EC9A  B7 80 01
                ldb     #$10                 ; EC9D  C6 10
                addb    <tmp07               ; EC9F  DB 07
                leax    B,X                  ; ECA1  30 85
                ldb     #$08                 ; ECA3  C6 08
                subb    <tmp07               ; ECA5  D0 07
LECA7:          lda     ,X+                  ; ECA7  A6 80
                sta     VDP_DATA             ; ECA9  B7 80 00
                decb                         ; ECAC  5A
                bne     LECA7                ; ECAD  26 F8
                leay    8,Y                  ; ECAF  31 28
                lda     <cur_col             ; ECB1  96 0C
                inca                         ; ECB3  4C
                sta     <cur_col             ; ECB4  97 0C
                cmpa    #$1E                 ; ECB6  81 1E
                bne     LEC90                ; ECB8  26 D6
LECBA:          tst     <tmp07               ; ECBA  0D 07
                lbeq    LED1B                ; ECBC  10 27 00 5B
                ldb     <tmp08               ; ECC0  D6 08
                ldx     #$00A1               ; ECC2  8E 00 A1
                abx                          ; ECC5  3A
                lda     ,X                   ; ECC6  A6 84
                tfr     A,B                  ; ECC8  1F 89
                andb    #$F0                 ; ECCA  C4 F0
                stb     <line_color          ; ECCC  D7 24
                anda    #$01                 ; ECCE  84 01
                sta     <big_font            ; ECD0  97 28
                lbne    LED65                ; ECD2  10 26 00 8F
                lbsr    LEDE4                ; ECD6  17 01 0B
                lda     #$10                 ; ECD9  86 10
                sta     <cur_col             ; ECDB  97 0C
                leau    32,U                 ; ECDD  33 C8 20
LECE0:          lbsr    LEDEF                ; ECE0  17 01 0C
                ldb     <cur_col             ; ECE3  D6 0C
                lda     <cur_line            ; ECE5  96 0B
                addb    #$08                 ; ECE7  CB 08
                subb    <tmp07               ; ECE9  D0 07
                tfr     D,Y                  ; ECEB  1F 02
                stb     VDP_CTRL             ; ECED  F7 80 01
                ora     #$40                 ; ECF0  8A 40
                sta     VDP_CTRL             ; ECF2  B7 80 01
                ldb     <tmp07               ; ECF5  D6 07
LECF7:          lda     ,X+                  ; ECF7  A6 80
                sta     VDP_DATA             ; ECF9  B7 80 00
                decb                         ; ECFC  5A
                bne     LECF7                ; ECFD  26 F8
                tfr     Y,D                  ; ECFF  1F 20
                addd    #$2000               ; ED01  C3 20 00
                stb     VDP_CTRL             ; ED04  F7 80 01
                ora     #$40                 ; ED07  8A 40
                sta     VDP_CTRL             ; ED09  B7 80 01
                ldb     <line_color          ; ED0C  D6 24
                lda     <cur_col             ; ED0E  96 0C
                adda    #$08                 ; ED10  8B 08
                sta     <cur_col             ; ED12  97 0C
                stb     VDP_DATA             ; ED14  F7 80 00
                cmpa    #$F0                 ; ED17  81 F0
                bne     LECE0                ; ED19  26 C5
LED1B:          rts                          ; ED1B  39
LED1C:          lbsr    LEDEF                ; ED1C  17 00 D0
                tfr     Y,D                  ; ED1F  1F 20
                stb     VDP_CTRL             ; ED21  F7 80 01
                ora     #$40                 ; ED24  8A 40
                sta     VDP_CTRL             ; ED26  B7 80 01
                ldb     #$20                 ; ED29  C6 20
                addb    <tmp07               ; ED2B  DB 07
                leax    B,X                  ; ED2D  30 85
                ldb     #$08                 ; ED2F  C6 08
                subb    <tmp07               ; ED31  D0 07
LED33:          lda     ,X+                  ; ED33  A6 80
                sta     VDP_DATA             ; ED35  B7 80 00
                decb                         ; ED38  5A
                bne     LED33                ; ED39  26 F8
                leay    8,Y                  ; ED3B  31 28
                tfr     Y,D                  ; ED3D  1F 20
                stb     VDP_CTRL             ; ED3F  F7 80 01
                ora     #$40                 ; ED42  8A 40
                sta     VDP_CTRL             ; ED44  B7 80 01
                ldb     <tmp07               ; ED47  D6 07
                leax    B,X                  ; ED49  30 85
                ldb     #$08                 ; ED4B  C6 08
                subb    <tmp07               ; ED4D  D0 07
LED4F:          lda     ,X+                  ; ED4F  A6 80
                sta     VDP_DATA             ; ED51  B7 80 00
                decb                         ; ED54  5A
                bne     LED4F                ; ED55  26 F8
                leay    8,Y                  ; ED57  31 28
                lda     <cur_col             ; ED59  96 0C
                inca                         ; ED5B  4C
                sta     <cur_col             ; ED5C  97 0C
                cmpa    #$10                 ; ED5E  81 10
                bne     LED1C                ; ED60  26 BA
                lbra    LECBA                ; ED62  16 FF 55
LED65:          lda     #$10                 ; ED65  86 10
                sta     <cur_col             ; ED67  97 0C
                lbsr    LEDE4                ; ED69  17 00 78
                leau    32,U                 ; ED6C  33 C8 20
LED6F:          lbsr    LEDEF                ; ED6F  17 00 7D
                ldb     <cur_col             ; ED72  D6 0C
                lda     <cur_line            ; ED74  96 0B
                addb    #$08                 ; ED76  CB 08
                subb    <tmp07               ; ED78  D0 07
                tfr     D,Y                  ; ED7A  1F 02
                stb     VDP_CTRL             ; ED7C  F7 80 01
                ora     #$40                 ; ED7F  8A 40
                sta     VDP_CTRL             ; ED81  B7 80 01
                ldb     <tmp07               ; ED84  D6 07
LED86:          lda     ,X+                  ; ED86  A6 80
                sta     VDP_DATA             ; ED88  B7 80 00
                decb                         ; ED8B  5A
                bne     LED86                ; ED8C  26 F8
                tfr     Y,D                  ; ED8E  1F 20
                addd    #tmp08               ; ED90  C3 00 08
                stb     VDP_CTRL             ; ED93  F7 80 01
                ora     #$40                 ; ED96  8A 40
                sta     VDP_CTRL             ; ED98  B7 80 01
                ldb     #$08                 ; ED9B  C6 08
                subb    <tmp07               ; ED9D  D0 07
                leax    B,X                  ; ED9F  30 85
                ldb     <tmp07               ; EDA1  D6 07
LEDA3:          lda     ,X+                  ; EDA3  A6 80
                sta     VDP_DATA             ; EDA5  B7 80 00
                decb                         ; EDA8  5A
                bne     LEDA3                ; EDA9  26 F8
                tfr     Y,D                  ; EDAB  1F 20
                addd    #$2000               ; EDAD  C3 20 00
                stb     VDP_CTRL             ; EDB0  F7 80 01
                ora     #$40                 ; EDB3  8A 40
                sta     VDP_CTRL             ; EDB5  B7 80 01
                lda     <line_color          ; EDB8  96 24
                nop                          ; EDBA  12
                nop                          ; EDBB  12
                nop                          ; EDBC  12
                nop                          ; EDBD  12
                sta     VDP_DATA             ; EDBE  B7 80 00
                tfr     Y,D                  ; EDC1  1F 20
                addd    #$2008               ; EDC3  C3 20 08
                stb     VDP_CTRL             ; EDC6  F7 80 01
                ora     #$40                 ; EDC9  8A 40
                sta     VDP_CTRL             ; EDCB  B7 80 01
                lda     <line_color          ; EDCE  96 24
                nop                          ; EDD0  12
                nop                          ; EDD1  12
                nop                          ; EDD2  12
                nop                          ; EDD3  12
                sta     VDP_DATA             ; EDD4  B7 80 00
                lda     <cur_col             ; EDD7  96 0C
                adda    #$10                 ; EDD9  8B 10
                sta     <cur_col             ; EDDB  97 0C
                cmpa    #$F0                 ; EDDD  81 F0
                lbne    LED6F                ; EDDF  10 26 FF 8C
                rts                          ; EDE3  39
LEDE4:          lda     <tmp08               ; EDE4  96 08
                ldb     #$20                 ; EDE6  C6 20
                mul                          ; EDE8  3D
                addd    #$0202               ; EDE9  C3 02 02
                tfr     D,U                  ; EDEC  1F 03
                rts                          ; EDEE  39
LEDEF:          lda     ,U+                  ; EDEF  A6 C0
                bmi     LEDFF                ; EDF1  2B 0C
                tst     <big_font            ; EDF3  0D 28
                bne     LEDFB                ; EDF5  26 04
                ldx     <fonta_small         ; EDF7  9E 29
                bra     LEE0B                ; EDF9  20 10
LEDFB:          ldx     <fonta_big           ; EDFB  9E 35
                bra     LEE0B                ; EDFD  20 0C
LEDFF:          tst     <big_font            ; EDFF  0D 28
                bne     LEE07                ; EE01  26 04
                ldx     <fontb_small         ; EE03  9E 2B
                bra     LEE09                ; EE05  20 02
LEE07:          ldx     <fontb_big           ; EE07  9E 37
LEE09:          anda    #$7F                 ; EE09  84 7F
LEE0B:          suba    #$13                 ; EE0B  80 13
                ldb     #$18                 ; EE0D  C6 18
                tst     <big_font            ; EE0F  0D 28
                beq     LEE15                ; EE11  27 02
                addb    #$18                 ; EE13  CB 18
LEE15:          mul                          ; EE15  3D
                leax    D,X                  ; EE16  30 8B
                rts                          ; EE18  39
LEE19:          lda     <cur_line            ; EE19  96 0B
                inca                         ; EE1B  4C
                cmpa    #$18                 ; EE1C  81 18
                bne     LEE5B                ; EE1E  26 3B
                clr     <cur_line            ; EE20  0F 0B
                lda     <tmp08               ; EE22  96 08
                suba    #$08                 ; EE24  80 08
                sta     <tmp08               ; EE26  97 08
                lda     <tmp2f               ; EE28  96 2F
                cmpa    #$02                 ; EE2A  81 02
                bne     LEE30                ; EE2C  26 02
                inc     <tmp08               ; EE2E  0C 08
LEE30:          ldb     <tmp07               ; EE30  D6 07
                incb                         ; EE32  5C
                andb    #$07                 ; EE33  C4 07
                bne     LEE3D                ; EE35  26 06
                inca                         ; EE37  4C
                cmpa    #$03                 ; EE38  81 03
                bne     LEE3D                ; EE3A  26 01
                clra                         ; EE3C  4F
LEE3D:          inca                         ; EE3D  4C
                cmpa    #$03                 ; EE3E  81 03
                bne     LEE43                ; EE40  26 01
                clra                         ; EE42  4F
LEE43:          sta     <tmp2f               ; EE43  97 2F
                bne     LEE4C                ; EE45  26 05
                tstb                         ; EE47  5D
                bne     LEE4C                ; EE48  26 02
                inc     <tmp08               ; EE4A  0C 08
LEE4C:          stb     <tmp07               ; EE4C  D7 07
                ldb     <tmp08               ; EE4E  D6 08
                ldx     #line_attr           ; EE50  8E 00 A0
                abx                          ; EE53  3A
                lda     ,X                   ; EE54  A6 84
                anda    #$01                 ; EE56  84 01
                sta     <big_font            ; EE58  97 28
                rts                          ; EE5A  39
LEE5B:          sta     <cur_line            ; EE5B  97 0B
                ldb     <tmp2f               ; EE5D  D6 2F
                incb                         ; EE5F  5C
                cmpb    #$03                 ; EE60  C1 03
                bne     LEE67                ; EE62  26 03
                clrb                         ; EE64  5F
                inc     <tmp08               ; EE65  0C 08
LEE67:          stb     <tmp2f               ; EE67  D7 2F
                rts                          ; EE69  39
LEE6A:          lda     <cur_line            ; EE6A  96 0B
                ldb     #$02                 ; EE6C  C6 02
                stb     <cur_col             ; EE6E  D7 0C
                ldb     #$10                 ; EE70  C6 10
                addd    #$2000               ; EE72  C3 20 00
                tfr     D,Y                  ; EE75  1F 02
                ldb     <tmp08               ; EE77  D6 08
                ldx     #line_attr           ; EE79  8E 00 A0
                abx                          ; EE7C  3A
                lda     ,X                   ; EE7D  A6 84
                anda    #$F0                 ; EE7F  84 F0
                sta     <line_color          ; EE81  97 24
LEE83:          tfr     Y,D                  ; EE83  1F 20
                stb     VDP_CTRL             ; EE85  F7 80 01
                ora     #$40                 ; EE88  8A 40
                sta     VDP_CTRL             ; EE8A  B7 80 01
                ldb     <line_color          ; EE8D  D6 24
                leay    8,Y                  ; EE8F  31 28
                lda     <cur_col             ; EE91  96 0C
                inca                         ; EE93  4C
                sta     <cur_col             ; EE94  97 0C
                stb     VDP_DATA             ; EE96  F7 80 00
                cmpa    #$1E                 ; EE99  81 1E
                bne     LEE83                ; EE9B  26 E6
                rts                          ; EE9D  39

* ===========================================================================
*  Tela de abertura: textos com a fonte grande, textos com a fonte 8x8 e o
*  logotipo "tms".
* ===========================================================================
TITLE_SCREEN:   leay    >TITLE_BIG_TEXT,PCR  ; EE9E  31 8D 00 28
LEEA2:          ldd     ,Y++                 ; EEA2  EC A1
                beq     TITLE_SMALL          ; EEA4  27 48
                std     <cell_vaddr          ; EEA6  DD 09
                lbsr    VDP_SET_WRITE        ; EEA8  17 FC 4D
                lda     ,Y+                  ; EEAB  A6 A0
                sta     <line_color          ; EEAD  97 24
LEEAF:          ldb     ,Y+                  ; EEAF  E6 A0
                beq     LEEA2                ; EEB1  27 EF
                ldx     #BIG_FONT            ; EEB3  8E C0 00
                lbsr    DRAW_BIG_GLYPH       ; EEB6  17 F5 8E
                ldd     <cell_vaddr          ; EEB9  DC 09
                lbsr    FILL_LINE_COLOR      ; EEBB  17 FC 07
                ldd     <cell_vaddr          ; EEBE  DC 09
                addd    #key_shift           ; EEC0  C3 00 10
                std     <cell_vaddr          ; EEC3  DD 09
                lbsr    VDP_SET_WRITE        ; EEC5  17 FC 30
                bra     LEEAF                ; EEC8  20 E5

*  Registros: FDB endereço VRAM, FCB cor, texto..., 0   (FDB 0 termina)
TITLE_BIG_TEXT: fdb     $0068                ; EECA  00 68
                fcb     $F0                  ; EECC  F0
                fcc     "THE",$00            ; EECD  54 48 45 00
                fdb     $0320                ; EED1  03 20
                fcb     $60                  ; EED3  60
                fcc     "VIDEO@EFFECTS",$00  ; EED4  56 49 44 45 ..
                fdb     $0650                ; EEE2  06 50
                fcb     $C0                  ; EEE4  C0
                fcc     "TITLER",$00         ; EEE5  54 49 54 4C ..
                fdb     $0000                ; EEEC  00 00
TITLE_SMALL:    leay    >TITLE_SMALL_TEXT,PCR ; EEEE  31 8D 00 4A
LEEF2:          ldd     ,Y++                 ; EEF2  EC A1
                lbeq    TITLE_LOGO           ; EEF4  10 27 00 CF
                std     <cell_vaddr          ; EEF8  DD 09
                lbsr    VDP_SET_WRITE        ; EEFA  17 FB FB
                lda     ,Y+                  ; EEFD  A6 A0
                sta     <line_color          ; EEFF  97 24
                lda     ,Y+                  ; EF01  A6 A0
                sta     <tmp0e               ; EF03  97 0E
LEF05:          lda     ,Y+                  ; EF05  A6 A0
                beq     LEF22                ; EF07  27 19
                suba    #$30                 ; EF09  80 30
                ldb     #$08                 ; EF0B  C6 08
                mul                          ; EF0D  3D
                ldx     #FONT8X8             ; EF0E  8E DD A0
                leax    D,X                  ; EF11  30 8B
                ldb     #$08                 ; EF13  C6 08
LEF15:          lda     ,X+                  ; EF15  A6 80
                sta     VDP_DATA             ; EF17  B7 80 00
                lbsr    VDP_DELAY            ; EF1A  17 FB BE
                decb                         ; EF1D  5A
                bne     LEF15                ; EF1E  26 F5
                bra     LEF05                ; EF20  20 E3
LEF22:          ldd     <cell_vaddr          ; EF22  DC 09
                addd    #$2000               ; EF24  C3 20 00
                lbsr    VDP_SET_WRITE        ; EF27  17 FB CE
                lda     <tmp0e               ; EF2A  96 0E
                ldb     #$08                 ; EF2C  C6 08
                mul                          ; EF2E  3D
                lda     <line_color          ; EF2F  96 24
LEF31:          sta     VDP_DATA             ; EF31  B7 80 00
                lbsr    VDP_DELAY            ; EF34  17 FB A4
                decb                         ; EF37  5A
                bne     LEF31                ; EF38  26 F7
                bra     LEEF2                ; EF3A  20 B6

*  Registros: FDB endereço VRAM, FCB cor, nº de tiles a colorir, texto..., 0
*  (texto no conjunto interno: '@' = espaço, '>' = ponto, ';' = vírgula)
TITLE_SMALL_TEXT: fdb     $0A70              ; EF3C  0A 70
                fcb     $50,$04              ; EF3E  50 04
                fcc     "@@@@",$00           ; EF40  40 40 40 40 ..
                fdb     $1218                ; EF45  12 18
                fcb     $50,$1B              ; EF47  50 1B
                fcc     "Sistema@Operacional@Vr@2>1",$00 ; EF49  53 69 73 74 ..
                fdb     $1348                ; EF64  13 48
                fcb     $50,$0E              ; EF66  50 0E
                fcc     "@@@@@@@@@@@@@@",$00 ; EF68  40 40 40 40 ..
                fdb     $1430                ; EF77  14 30
                fcb     $F0,$13              ; EF79  F0 13
                fcc     "@TMS@@MICROSISTEMAS@",$00 ; EF7B  40 54 4D 53 ..
                fdb     $1538                ; EF90  15 38
                fcb     $50,$13              ; EF92  50 13
                fcc     "Copyright@1988",$3B,"1989",$00 ; EF94  43 6F 70 79 ..
                fdb     $1720                ; EFA8  17 20
                fcb     $B0,$18              ; EFAA  B0 18
                fcc     "Pressione@qualquer@tecla",$00 ; EFAC  50 72 65 73 ..
                fdb     $0000                ; EFC5  00 00
TITLE_LOGO:     leax    >TMS_LOGO,PCR        ; EFC7  30 8D 00 48
                ldd     #$0D68               ; EFCB  CC 0D 68
                bsr     VDP_COPY_48          ; EFCE  8D 32
                ldd     #$0E68               ; EFD0  CC 0E 68
                bsr     VDP_COPY_48          ; EFD3  8D 2D
                ldd     #$0F68               ; EFD5  CC 0F 68
                bsr     VDP_COPY_48          ; EFD8  8D 28
                lda     #$05                 ; EFDA  86 05
                sta     <tmp0e               ; EFDC  97 0E
                ldd     #$2C60               ; EFDE  CC 2C 60
LEFE1:          std     <cell_vaddr          ; EFE1  DD 09
                lbsr    VDP_SET_WRITE        ; EFE3  17 FB 12
                ldb     #$40                 ; EFE6  C6 40
                lda     #$4A                 ; EFE8  86 4A
LEFEA:          sta     VDP_DATA             ; EFEA  B7 80 00
                lbsr    VDP_DELAY            ; EFED  17 FA EB
                decb                         ; EFF0  5A
                bne     LEFEA                ; EFF1  26 F7
                lda     <tmp0e               ; EFF3  96 0E
                deca                         ; EFF5  4A
                beq     LF001                ; EFF6  27 09
                sta     <tmp0e               ; EFF8  97 0E
                ldd     <cell_vaddr          ; EFFA  DC 09
                addd    #$0100               ; EFFC  C3 01 00
                bra     LEFE1                ; EFFF  20 E0
LF001:          rts                          ; F001  39
VDP_COPY_48:    lbsr    VDP_SET_WRITE        ; F002  17 FA F3
                ldb     #$30                 ; F005  C6 30
LF007:          lda     ,X+                  ; F007  A6 80
                sta     VDP_DATA             ; F009  B7 80 00
                lbsr    VDP_DELAY            ; F00C  17 FA CC
                decb                         ; F00F  5A
                bne     LF007                ; F010  26 F5
                rts                          ; F012  39

*  Padrões do logotipo 'tms' (3 linhas de 6 tiles)
TMS_LOGO:       fcb     $F8,$F8,$FF,$FF,$FF,$FF,$FF,$FF ; F013  F8 F8 FF FF FF FF FF FF
                fcb     $3F,$3F,$3F,$3F,$3F,$3F,$3F,$3E ; F01B  3F 3F 3F 3F 3F 3F 3F 3E
                fcb     $F8,$FC,$FC,$FE,$FE,$FE,$FE,$3E ; F023  F8 FC FC FE FE FE FE 3E
                fcb     $FC,$FE,$FF,$FF,$FF,$FF,$FF,$1F ; F02B  FC FE FF FF FF FF FF 1F
                fcb     $0F,$0F,$1F,$9F,$9F,$9F,$9F,$8F ; F033  0F 0F 1F 9F 9F 9F 9F 8F
                fcb     $C0,$C0,$80,$80,$80,$80,$80,$C0 ; F03B  C0 C0 80 80 80 80 80 C0
                fcb     $F8,$F8,$F8,$F8,$F8,$F8,$F8,$F8 ; F043  F8 F8 F8 F8 F8 F8 F8 F8
                fcb     $3E,$3E,$3E,$3E,$3E,$3E,$3E,$3E ; F04B  3E 3E 3E 3E 3E 3E 3E 3E
                fcb     $3E,$3E,$3E,$3E,$3E,$3E,$3E,$3E ; F053  3E 3E 3E 3E 3E 3E 3E 3E
                fcb     $0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F ; F05B  0F 0F 0F 0F 0F 0F 0F 0F
                fcb     $87,$83,$81,$80,$80,$80,$80,$80 ; F063  87 83 81 80 80 80 80 80
                fcb     $E0,$F0,$F8,$FC,$7E,$3E,$3F,$3F ; F06B  E0 F0 F8 FC 7E 3E 3F 3F
                fcb     $F8,$F8,$7F,$3F,$1F,$00,$00,$00 ; F073  F8 F8 7F 3F 1F 00 00 00
                fcb     $3E,$3E,$3E,$3E,$3E,$00,$00,$00 ; F07B  3E 3E 3E 3E 3E 00 00 00
                fcb     $3E,$3E,$3E,$3E,$3E,$00,$00,$00 ; F083  3E 3E 3E 3E 3E 00 00 00
                fcb     $0F,$0F,$0F,$0F,$0F,$00,$00,$00 ; F08B  0F 0F 0F 0F 0F 00 00 00
                fcb     $80,$80,$80,$80,$80,$07,$07,$07 ; F093  80 80 80 80 80 07 07 07
                fcb     $3F,$3F,$7F,$7F,$FE,$FE,$FC,$F8 ; F09B  3F 3F 7F 7F FE FE FC F8

*  Padrões de 16 sprites 16x16 (segmentos de moldura/linhas) -> VRAM $1800,
*  usados pelo modo OBJ.
SPRITE_PATS:    fcb     $C0,$E0,$70,$38,$1C,$0E,$07,$03 ; F0A3  C0 E0 70 38 1C 0E 07 03
                fcb     $01,$00,$00,$00,$00,$00,$00,$00 ; F0AB  01 00 00 00 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$00,$80 ; F0B3  00 00 00 00 00 00 00 80
                fcb     $C0,$E0,$70,$38,$1C,$0E,$07,$03 ; F0BB  C0 E0 70 38 1C 0E 07 03
                fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; F0C3  00 00 00 00 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; F0CB  00 00 00 00 00 00 00 00
                fcb     $01,$00,$00,$00,$00,$00,$00,$00 ; F0D3  01 00 00 00 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; F0DB  00 00 00 00 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; F0E3  00 00 00 00 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$00,$80 ; F0EB  00 00 00 00 00 00 00 80
                fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; F0F3  00 00 00 00 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; F0FB  00 00 00 00 00 00 00 00
                fcb     $C0,$E0,$70,$38,$1C,$0E,$07,$03 ; F103  C0 E0 70 38 1C 0E 07 03
                fcb     $01,$00,$00,$00,$00,$00,$FF,$FF ; F10B  01 00 00 00 00 00 FF FF
                fcb     $03,$03,$03,$03,$03,$03,$03,$83 ; F113  03 03 03 03 03 03 03 83
                fcb     $C3,$E3,$73,$3B,$1F,$0F,$FF,$FF ; F11B  C3 E3 73 3B 1F 0F FF FF
                fcb     $FF,$80,$80,$80,$80,$80,$80,$80 ; F123  FF 80 80 80 80 80 80 80
                fcb     $80,$80,$80,$80,$80,$80,$80,$80 ; F12B  80 80 80 80 80 80 80 80
                fcb     $FF,$00,$00,$00,$00,$00,$00,$00 ; F133  FF 00 00 00 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; F13B  00 00 00 00 00 00 00 00
                fcb     $80,$80,$80,$80,$80,$80,$80,$80 ; F143  80 80 80 80 80 80 80 80
                fcb     $80,$80,$80,$80,$80,$80,$80,$FF ; F14B  80 80 80 80 80 80 80 FF
                fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; F153  00 00 00 00 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$00,$FF ; F15B  00 00 00 00 00 00 00 FF
                fcb     $FF,$00,$00,$00,$00,$00,$00,$00 ; F163  FF 00 00 00 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; F16B  00 00 00 00 00 00 00 00
                fcb     $FF,$01,$01,$01,$01,$01,$01,$01 ; F173  FF 01 01 01 01 01 01 01
                fcb     $01,$01,$01,$01,$01,$01,$01,$01 ; F17B  01 01 01 01 01 01 01 01
                fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; F183  00 00 00 00 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$00,$FF ; F18B  00 00 00 00 00 00 00 FF
                fcb     $01,$01,$01,$01,$01,$01,$01,$01 ; F193  01 01 01 01 01 01 01 01
                fcb     $01,$01,$01,$01,$01,$01,$01,$FF ; F19B  01 01 01 01 01 01 01 FF
                fcb     $00,$00,$00,$01,$03,$06,$0C,$18 ; F1A3  00 00 00 01 03 06 0C 18
                fcb     $30,$30,$30,$30,$30,$30,$30,$30 ; F1AB  30 30 30 30 30 30 30 30
                fcb     $3F,$7F,$C0,$80,$00,$00,$00,$00 ; F1B3  3F 7F C0 80 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; F1BB  00 00 00 00 00 00 00 00
                fcb     $30,$30,$30,$30,$30,$30,$30,$30 ; F1C3  30 30 30 30 30 30 30 30
                fcb     $18,$0C,$06,$03,$01,$00,$00,$00 ; F1CB  18 0C 06 03 01 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; F1D3  00 00 00 00 00 00 00 00
                fcb     $00,$00,$00,$00,$80,$C0,$7F,$3F ; F1DB  00 00 00 00 80 C0 7F 3F
                fcb     $FC,$FE,$03,$01,$00,$00,$00,$00 ; F1E3  FC FE 03 01 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; F1EB  00 00 00 00 00 00 00 00
                fcb     $00,$00,$00,$80,$C0,$60,$30,$18 ; F1F3  00 00 00 80 C0 60 30 18
                fcb     $0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C ; F1FB  0C 0C 0C 0C 0C 0C 0C 0C
                fcb     $00,$00,$00,$00,$00,$00,$00,$00 ; F203  00 00 00 00 00 00 00 00
                fcb     $00,$00,$00,$00,$01,$03,$FE,$FC ; F20B  00 00 00 00 01 03 FE FC
                fcb     $0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C ; F213  0C 0C 0C 0C 0C 0C 0C 0C
                fcb     $18,$30,$60,$C0,$80,$00,$00,$00 ; F21B  18 30 60 C0 80 00 00 00
                fcb     $C0,$E0,$70,$38,$1C,$0E,$07,$03 ; F223  C0 E0 70 38 1C 0E 07 03
                fcb     $01,$00,$00,$00,$00,$00,$00,$00 ; F22B  01 00 00 00 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$00,$80 ; F233  00 00 00 00 00 00 00 80
                fcb     $C0,$E0,$70,$38,$1C,$0E,$07,$03 ; F23B  C0 E0 70 38 1C 0E 07 03
                fcb     $00,$00,$00,$00,$00,$00,$00,$01 ; F243  00 00 00 00 00 00 00 01
                fcb     $03,$07,$0E,$1C,$38,$70,$E0,$C0 ; F24B  03 07 0E 1C 38 70 E0 C0
                fcb     $03,$07,$0E,$1C,$38,$70,$E0,$C0 ; F253  03 07 0E 1C 38 70 E0 C0
                fcb     $80,$00,$00,$00,$00,$00,$00,$00 ; F25B  80 00 00 00 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$00,$01 ; F263  00 00 00 00 00 00 00 01
                fcb     $03,$07,$0E,$1C,$38,$70,$E0,$C0 ; F26B  03 07 0E 1C 38 70 E0 C0
                fcb     $03,$07,$0E,$1C,$38,$70,$E0,$C0 ; F273  03 07 0E 1C 38 70 E0 C0
                fcb     $80,$00,$00,$00,$00,$00,$00,$00 ; F27B  80 00 00 00 00 00 00 00
                fcb     $C0,$E0,$70,$38,$1C,$0E,$07,$03 ; F283  C0 E0 70 38 1C 0E 07 03
                fcb     $01,$00,$00,$00,$00,$00,$00,$00 ; F28B  01 00 00 00 00 00 00 00
                fcb     $00,$00,$00,$00,$00,$00,$00,$80 ; F293  00 00 00 00 00 00 00 80
                fcb     $C0,$E0,$70,$38,$1C,$0E,$07,$03 ; F29B  C0 E0 70 38 1C 0E 07 03

*  Área livre da EPROM ($FF, 238 bytes)
FREE_SPACE1:    fcb     $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; F2A3  FF FF FF FF FF FF FF FF
                fcb     $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; F2AB  FF FF FF FF FF FF FF FF
                fcb     $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; F2B3  FF FF FF FF FF FF FF FF
                fcb     $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; F2BB  FF FF FF FF FF FF FF FF
                fcb     $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; F2C3  FF FF FF FF FF FF FF FF
                fcb     $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; F2CB  FF FF FF FF FF FF FF FF
                fcb     $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; F2D3  FF FF FF FF FF FF FF FF
                fcb     $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; F2DB  FF FF FF FF FF FF FF FF
                fcb     $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; F2E3  FF FF FF FF FF FF FF FF
                fcb     $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; F2EB  FF FF FF FF FF FF FF FF
                fcb     $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; F2F3  FF FF FF FF FF FF FF FF
                fcb     $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; F2FB  FF FF FF FF FF FF FF FF
                fcb     $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; F303  FF FF FF FF FF FF FF FF
                fcb     $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; F30B  FF FF FF FF FF FF FF FF
                fcb     $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; F313  FF FF FF FF FF FF FF FF
                fcb     $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; F31B  FF FF FF FF FF FF FF FF
                fcb     $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; F323  FF FF FF FF FF FF FF FF
                fcb     $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; F32B  FF FF FF FF FF FF FF FF
                fcb     $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; F333  FF FF FF FF FF FF FF FF
                fcb     $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; F33B  FF FF FF FF FF FF FF FF
                fcb     $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; F343  FF FF FF FF FF FF FF FF
                fcb     $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; F34B  FF FF FF FF FF FF FF FF
                fcb     $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; F353  FF FF FF FF FF FF FF FF
                fcb     $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; F35B  FF FF FF FF FF FF FF FF
                fcb     $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; F363  FF FF FF FF FF FF FF FF
                fcb     $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; F36B  FF FF FF FF FF FF FF FF
                fcb     $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; F373  FF FF FF FF FF FF FF FF
                fcb     $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; F37B  FF FF FF FF FF FF FF FF
                fcb     $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; F383  FF FF FF FF FF FF FF FF
                fcb     $FF,$FF,$FF,$FF,$FF,$FF,$12 ; F38B  FF FF FF FF FF FF 12

*  CONTROL + tecla = caractere acentuado / bloco gráfico / logotipo
CTRL_ACCENT:    nop                          ; F392  12
                nop                          ; F393  12
                tst     <key_ctrl            ; F394  0D 25
                beq     LF3B9                ; F396  27 21
                ldb     <tmp0e               ; F398  D6 0E
                cmpb    #$30                 ; F39A  C1 30
                bcs     LF3B9                ; F39C  25 1B
                cmpb    #$61                 ; F39E  C1 61
                bcs     LF3A4                ; F3A0  25 02
                subb    #$20                 ; F3A2  C0 20
LF3A4:          leax    >ACCENT_TAB,PCR      ; F3A4  30 8D 00 16
                subb    #$30                 ; F3A8  C0 30
                abx                          ; F3AA  3A
                ldb     ,X                   ; F3AB  E6 84
                cmpb    #$7A                 ; F3AD  C1 7A
                bcs     LF3B7                ; F3AF  25 06
                tst     <big_font            ; F3B1  0D 28
                beq     LF3B7                ; F3B3  27 02
                ldb     #$40                 ; F3B5  C6 40
LF3B7:          stb     <tmp0e               ; F3B7  D7 0E
LF3B9:          lda     <cursor_mode         ; F3B9  96 0F
                ldb     <tmp0e               ; F3BB  D6 0E
                rts                          ; F3BD  39

*  Tabela CONTROL+tecla ('0'..'_') -> caractere interno
ACCENT_TAB:     fcb     $1C,$13,$14,$15,$16,$17,$18,$19 ; F3BE  1C 13 14 15 16 17 18 19
                fcb     $1A,$1B,$1D,$40,$40,$40,$40,$40 ; F3C6  1A 1B 1D 40 40 40 40 40
                fcb     $40,$28,$40,$7D,$2A,$20,$2B,$2C ; F3CE  40 28 40 7D 2A 20 2B 2C
                fcb     $2D,$25,$2E,$2F,$40,$40,$40,$26 ; F3D6  2D 25 2E 2F 40 40 40 26
                fcb     $27,$1E,$21,$29,$22,$24,$7E,$1F ; F3DE  27 1E 21 29 22 24 7E 1F
                fcb     $7C,$23,$7B,$40,$40,$40,$40,$40 ; F3E6  7C 23 7B 40 40 40 40 40
BIGFONT_INDEX_A: cmpa    #$7B                ; F3EE  81 7B          A = código -> índice (A-$13), B = 48
                bcs     LF3F4                ; F3F0  25 02
                lda     #$40                 ; F3F2  86 40
LF3F4:          suba    #$13                 ; F3F4  80 13
                ldb     #$30                 ; F3F6  C6 30
                rts                          ; F3F8  39
BIGFONT_INDEX_B: cmpb    #$7B                ; F3F9  C1 7B          B = código -> índice (B-$13), A = 48
                bcs     LF3FF                ; F3FB  25 02
                ldb     #$40                 ; F3FD  C6 40
LF3FF:          subb    #$13                 ; F3FF  C0 13
                lda     #$30                 ; F401  86 30
                rts                          ; F403  39

*  Área livre da EPROM ($FF, 3052 bytes)
FREE_SPACE2:    fill    $FF,3052             ; F404  FF x3052
VECTORS:        fdb     VECTORS+15           ; FFF0  FF FF
                fdb     SWI23_ENTRY          ; FFF2  E0 10
                fdb     SWI23_ENTRY          ; FFF4  E0 10
                fdb     IRQ_ENTRY            ; FFF6  E0 08
                fdb     IRQ_ENTRY            ; FFF8  E0 08
                fdb     SWI_ENTRY            ; FFFA  E0 0C
                fdb     IRQ_ENTRY            ; FFFC  E0 08
                fdb     RESET                ; FFFE  E0 00

		end
