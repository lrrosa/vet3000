# Copyright (C) 2026 Leonardo Roman da Rosa
# SPDX-License-Identifier: GPL-3.0-or-later
# Software livre sob a GNU GPL versão 3 ou (a seu critério) posterior; veja LICENSE.
#
# Anotações do disassembly da ROM do VET 3000 v2.1 (usado por tools/dis6809.py)
#
#   python tools/dis6809.py rom/VET2.1-TMS_VET3000_27128A.BIN --hints disasm/hints.py \
#          -o disasm/vet3000_v2.1.asm
#
# O arquivo gerado remonta byte a byte idêntico com o asm6809 (ver disasm/build.sh).

import os

_HERE = os.path.dirname(os.path.abspath(__file__))
_ROM = open(os.path.join(_HERE, "..", "rom", "VET2.1-TMS_VET3000_27128A.BIN"), "rb").read()


def _b(a):
    return _ROM[a - 0xC000]


def _w(a):
    return (_b(a) << 8) | _b(a + 1)


HEADER = """
===========================================================================
 VET 3000 "The Video Effects Titler" - firmware v2.1 (EPROM 27128, $C000-$FFFF)
 TMS - Tecnologia em Micro Sistemas (Brasil), (C) 1988,1989
===========================================================================
 Disassembly comentado gerado por tools/dis6809.py + disasm/hints.py.
 Anotações, nomes e comentários: Copyright (C) 2026 Leonardo Roman da Rosa,
 GPL-3.0-or-later. O código e os dados da ROM são (C) 1988,1989 TMS -
 Tecnologia em Micro Sistemas; publicados aqui para estudo e preservação.
 Remonta byte a byte idêntico ao dump original com o asm6809:
     asm6809 -B -o vet3000_v2.1.bin vet3000_v2.1.asm
 CRC32 bfdef5fa  SHA1 cd4da3cbda7fa12c9413d052bf69ee758cfe68b3

 Hardware (ver docs/hardware.md):
   CPU  MC6809 (clock de entrada 3,579545 MHz -> E = 0,895 MHz)
   VDP  TMS9128NL + 16 KB de VRAM (2x uPD41416), modo Graphics II
   RAM  8 KB estática HY6264 com bateria ($0000-$1FFF)
   ROM  16 KB 27128 ($C000-$FFFF)
   I/O  $8000 VDP dados, $8001 VDP controle, $8002 teclado
   CART $4000-$7FFF no conector traseiro CN1 (assinaturas "OBJECT" e "FONT")

 Mapa da ROM:
   $C000-$D37F  fonte grande 16x24 (48 bytes/glifo, códigos $13-$7A)
   $D380-$DD3F  fonte normal 8x24  (24 bytes/glifo, códigos $13-$7A)
   $DD40-$DD9F  glifos $7B-$7E da fonte normal = logotipo "tms"
   $DDA0-$DFFF  fonte 8x8 da tela de abertura (códigos $30-$7B)
   $E000-$F403  programa e tabelas
   $F2A3-$F390, $F404-$FFEF  livres ($FF)
   $FFF0-$FFFF  vetores do 6809

 Conjunto de caracteres interno (quase ASCII):
   $13-$1E á â ã à é ê í ó ô õ ú ç    $1F-$2A Á Â Ã À É Ê Í Ó Ô Õ Ú Ç
   $2B-$2F blocos gráficos            $30-$39 0-9   $3A :  $3B ,  $3C !
   $3D ?  $3E .  $3F $  $40 ESPAÇO     $41-$5A A-Z   $5B %  $5C -  $5D '
   $5E (  $5F )  $60 /                 $61-$7A a-z   $7B-$7E logotipo tms
   bit 7 = 1 seleciona a fonte "B" (cursor sublinhado; cartucho FONT em $6000)
"""

ROM = 0xC000
SYSTAB = 0xE0BA

ENTRY = []

# ---------------------------------------------------------------------------
# Hardware e variáveis de RAM
# ---------------------------------------------------------------------------
LABELS = {
    # I/O
    0x8000: "VDP_DATA",
    0x8001: "VDP_CTRL",
    0x8002: "KEYBOARD",
    # cartucho
    0x4000: "CART0",
    0x4004: "CART0_ID",
    0x4006: "CART0_ENTRY",
    0x6000: "CART1",
    0x6004: "CART1_ID",
    0x6006: "CART1_ENTRY",
    # variáveis na página direta (DP = $00)
    0x00: "vdp_r0",
    0x01: "vdp_r1",
    0x02: "backdrop",
    0x03: "key_delay",
    0x05: "kbd_scan",
    0x06: "kbd_rows",
    0x07: "tmp07",
    0x08: "tmp08",
    0x09: "cell_vaddr",
    0x0B: "cur_line",
    0x0C: "cur_col",
    0x0E: "tmp0e",
    0x0F: "cursor_mode",
    0x10: "key_shift",
    0x11: "extvid_on",
    0x12: "display_on",
    0x13: "obj_mode",
    0x14: "page",
    0x15: "tmp15",
    0x16: "tmp16",
    0x17: "obj_color",
    0x18: "obj_y",
    0x19: "obj_x",
    0x1A: "obj_shape",
    0x1C: "color_idx",
    0x1D: "caps_lock",
    0x1E: "key_code",
    0x1F: "key_raw",
    0x20: "key_last",
    0x21: "cursor_pat",
    0x24: "line_color",
    0x25: "key_ctrl",
    0x26: "key_mod3",
    0x27: "page_entry",
    0x28: "big_font",
    0x29: "fonta_small",
    0x2B: "fontb_small",
    0x2D: "key_repeat",
    0x2F: "tmp2f",
    0x30: "power_sig",
    0x35: "fonta_big",
    0x37: "fontb_big",
    0x39: "irq_vector",
    0x3B: "swi_vector",
    0x3D: "swi23_vector",
    0x3F: "roll_stop",
    0x40: "cmd_table",
    0xA0: "line_attr",
    0x0200: "page_text",
}

COMMENTS = {
    0x8000: "porta de dados do TMS9128 (MODE=0)",
    0x8001: "registradores/endereço/status do TMS9128 (MODE=1)",
    0x8002: "escrita: linha do teclado (ativa em 0); leitura: colunas (ativas em 0)",
    0x4000: "cartucho: janela $4000-$7FFF (CN1)",
    0x4004: "cartucho FONT: byte de identificação",
    0x4006: "cartucho OBJECT: ponteiro para a palavra com o deslocamento da entrada",
    0x00: "cópia do registrador 0 do VDP (bit0 = EXTVID)",
    0x01: "cópia do registrador 1 do VDP (bit6 = display ligado)",
    0x02: "índice (0-15) da cor de fundo/borda (R7)",
    0x03: "atraso de debounce do teclado (16 bits, $0100)",
    0x05: "padrão de varredura da linha do teclado",
    0x06: "contador de linhas na varredura",
    0x09: "endereço VRAM (padrões) da célula do cursor (16 bits)",
    0x0B: "linha de texto atual (0-7)",
    0x0C: "coluna atual (0-31; em fonte grande conta de 2 em 2)",
    0x0F: "cursor: 0 desligado, 1 bloco (fonte A), 2 sublinhado (fonte B)",
    0x10: "SHIFT pressionado (1)",
    0x11: "bit7 = sobreposição de vídeo externo ativa",
    0x12: "bit6 = imagem ligada (BORDER BLK alterna)",
    0x13: "modo OBJ ativo (objeto de 4 sprites visível)",
    0x14: "página atual (0-29)",
    0x17: "cor do objeto (índice 0-15)",
    0x18: "objeto: posição Y",
    0x19: "objeto: posição X",
    0x1A: "objeto: forma (0-3)",
    0x1C: "índice da cor da linha (tecla COLOR)",
    0x1D: "bit7 = CAPS (SHIFT+CURSOR)",
    0x1E: "código da tecla já traduzido",
    0x1F: "código cru da tecla (tabela KEYMAP)",
    0x20: "última tecla (auto-repetição)",
    0x21: "3 bytes com o desenho do cursor",
    0x24: "cor da linha no formato do VDP (frente<<4 | fundo)",
    0x25: "CONTROL pressionado (1)",
    0x26: "3o modificador (linha 7, bit 3) - lido mas nunca usado",
    0x27: "número de página digitado (BCD) antes de PAGE",
    0x28: "1 = linha atual usa a fonte grande",
    0x29: "ponteiro da fonte normal A ($D380 ou cartucho)",
    0x2B: "ponteiro da fonte normal B (bit7 do caractere)",
    0x2D: "contador de auto-repetição (16 bits)",
    0x30: '"POWER": RAM válida (mantida pela bateria)',
    0x35: "ponteiro da fonte grande A ($C000 ou cartucho)",
    0x37: "ponteiro da fonte grande B",
    0x39: "vetor RAM de IRQ/FIRQ/NMI (não usado pela ROM)",
    0x3B: "vetor RAM de SWI (não usado pela ROM)",
    0x3D: "vetor RAM de SWI2/SWI3 (não usado pela ROM)",
    0x3F: "1 = barra de espaço interrompeu a rolagem",
    0x40: "32 ponteiros de comandos (copiados de SYSTAB)",
    0xA0: "atributos: 30 páginas x 8 linhas (bit0 fonte grande, bits4-7 cor)",
    0x0200: "texto: 30 páginas x 8 linhas x 32 caracteres ($1E00 bytes)",
}

BLOCK_COMMENTS = {}
DATA = []


def code(addr, name, block=None, comment=None):
    LABELS[addr] = name
    if block:
        BLOCK_COMMENTS[addr] = block
    if comment:
        COMMENTS[addr] = comment


def data(addr, length, kind, name=None, block=None):
    DATA.append((addr, length, kind))
    if name:
        LABELS[addr] = name
    if block:
        BLOCK_COMMENTS[addr] = block


# ---------------------------------------------------------------------------
# Reset e vetores
# ---------------------------------------------------------------------------
code(0xE000, "RESET", """
===========================================================================
 RESET - ponto de entrada (vetor $FFFE)
===========================================================================""")
data(0xE002, 6, "ptr", "ROM_API", """
 Tabela de 3 ponteiros logo após o BRA do reset: entradas úteis para
 programas de cartucho (ler tecla, varrer teclado, laço de comandos).""")
code(0xE008, "IRQ_ENTRY", """
 Os vetores de hardware saltam por ponteiros em RAM. A ROM nunca habilita
 interrupções nem inicializa esses ponteiros: são ganchos para cartuchos.""",
     "IRQ, FIRQ e NMI -> [irq_vector]")
code(0xE00C, "SWI_ENTRY", comment="SWI -> [swi_vector]")
code(0xE010, "SWI23_ENTRY", comment="SWI2/SWI3 -> [swi23_vector]")

code(0xE014, "COLD_START", """
===========================================================================
 Inicialização
===========================================================================""",
     "pilha no topo da área de variáveis")
code(0xE01B, "BOOT_DELAY", comment="~64 ms para a fonte e o VDP estabilizarem")
code(0xE02D, "VDP_INIT_LOOP", comment="pares (registrador|$80, valor)")
data(0xE03B, 17, "fcb", "VDP_INIT_TAB", """
 Registradores iniciais do VDP (modo Graphics II, 16K, sprites 16x16):
   R0=$02 M3        R1=$82 16K, imagem desligada, sem interrupção, 16x16
   R2=$0E nomes em $3800         R3=$FF cores em $2000 (bitmap completo)
   R4=$03 padrões em $0000       R5=$78 atributos de sprites em $3C00
   R6=$03 padrões de sprites em $1800   R7=$00 fundo preto""")
code(0xE04C, "CLEAR_VRAM", comment="zera os 16 KB de VRAM")
code(0xE05D, "INIT_NAMES", comment="tabela de nomes = 0..255 x 3 (bitmap)")
code(0xE06F, "INIT_VARS")
code(0xE09A, "BUILD_CMDTAB", comment="SYSTAB (auto-relativa) -> cmd_table em RAM")
data(SYSTAB, 64, "selfrel", "SYSTAB", """
 Tabela de comandos: 32 deslocamentos auto-relativos (entrada + valor =
 rotina). Copiada como endereços absolutos para cmd_table ($0040). O índice
 é o código de tecla: 0 = caractere, 1..$0F = teclas de função, +$10 com
 SHIFT (e códigos especiais com CONTROL). Zero = sem função.""")
code(0xE0FA, "INIT_SPRITES", comment="atributos: Y=$D0 (fim da lista) nos 32 sprites")
code(0xE122, "LOAD_SPRITE_PATS", comment="copia 512 bytes de padrões de sprites para $1800")

code(0xE139, "PROBE_OBJECT", """
---------------------------------------------------------------------------
 Procura um cartucho "OBJECT" em $4000 e depois em $6000. Se achar, faz
 LDX [base+6] / JSR base,X. Atenção: o indireto estendido lê DUAS vezes -
 base+6 contém um PONTEIRO para a palavra com o deslocamento da entrada:
     base+0 "OBJECT"   base+6 FDB base+8   base+8 FDB entrada-base
 O programa do cartucho pode voltar com RTS para a ROM continuar a
 inicialização, ou assumir a máquina de vez.
---------------------------------------------------------------------------""")
data(0xE15B, 7, "fcc", "STR_OBJECT")
code(0xE162, "CALL_CART0", comment="X = palavra apontada por [$4006]")
code(0xE16C, "CALL_CART1", comment="X = palavra apontada por [$6006]")
code(0xE174, "PROBE_FONT", """
---------------------------------------------------------------------------
 Procura cartuchos "FONT": em $4000 substitui a fonte A; em $6000 (se o
 byte de identificação for diferente do primeiro) instala a fonte B.
 Formato: "FONT", id, ..., fonte grande em +$10, fonte normal em +$1390.
---------------------------------------------------------------------------""")
data(0xE188, 5, "fcc", "STR_FONT")
code(0xE18D, "FONT0_FOUND")
code(0xE19A, "PROBE_FONT1")
code(0xE1AC, "FONT1_FOUND")
code(0xE1BB, "CHECK_POWER", """
---------------------------------------------------------------------------
 Se a RAM não contém "POWER" em $0030 (bateria descarregada/primeira vez),
 grava a assinatura e apaga os textos e atributos de todas as páginas.
---------------------------------------------------------------------------""")
data(0xE1F9, 6, "fcc", "STR_POWER")
code(0xE1DC, "COLD_RAM_INIT")

code(0xE1FF, "START_TITLER", """
===========================================================================
 Tela de abertura e laço principal
===========================================================================""")
code(0xE206, "TITLE_WAIT", comment="na abertura: SHIFT+BORDER muda o fundo, EXT MODE sobrepõe")
code(0xE221, "ENTER_EDITOR")
code(0xE231, "MAIN_LOOP", comment="lê tecla e despacha comando")
code(0xE28C, "DISPATCH_FUNC", comment="códigos < $30: teclas de função")
data(0xE2AA, 4, "fcb", "NOSHIFT_KEYS", " Teclas que ignoram SHIFT (RETURN, COLOR, CONTROL+CURSOR)")
data(0xE2D6, 13, "fcb", "CURSOR_OFF_KEYS", " Comandos ignorados enquanto o cursor está desligado")
data(0xE307, 7, "fcb", "BLANKED_KEYS", " Comandos aceitos com a imagem desligada (BORDER BLK)")
code(0xE30E, "CALL_CMD", comment="salta para cmd_table[código]")

code(0xE322, "GETKEY", """
---------------------------------------------------------------------------
 GETKEY: espera uma tecla (debounce e auto-repetição). Retorna o código
 em key_code. Modificadores em key_shift / key_ctrl.
---------------------------------------------------------------------------""")
code(0xE36D, "KEY_DEBOUNCE", comment="espera key_delay iterações")
code(0xE375, "KBD_SCAN", """
---------------------------------------------------------------------------
 KBD_SCAN: varre a matriz 7x8. Escreve a linha em $8002 (bit n = 0 seleciona
 a linha n+1), lê as colunas em $8002 (0 = tecla apertada). A coluna do
 bit 3 é dos modificadores e só vale na linha 3 (EXT MODE). SHIFT (linha 1)
 e CONTROL (linha 2) são lidos em separado. Resultado em key_raw.
---------------------------------------------------------------------------""")
code(0xE3A6, "KBD_FOUND")
data(0xE3E4, 56, "fcb", "KEYMAP", """
 KEYMAP: código de cada posição da matriz (linha 1..7, bits 0..7):
   $01 PAGE  $02 BORDER BLK  $03 CLEAR  $04 OBJ  $05 EXT MODE  $06 CURSOR
   $07 RETURN  $08 COLOR  $09 ESQ/DIR  $0A CIMA/BAIXO  $0E AUTO CENTER
   $00 = modificador/sem tecla (inclui o 'C' amarelo na linha 6, bit 3)
   $1F = posição sem tecla física (linha 6, bit 6)""")

code(0xE41C, "CMD_CHAR", """
===========================================================================
 Comandos (entradas de SYSTAB). Slot = código de tecla.
===========================================================================
 Slot 0: imprime o caractere em A na posição do cursor""")
code(0xE447, "DRAW_BIG_GLYPH")
code(0xE4AF, "VDP_WRITE_N", comment="escreve B bytes de ,X na VRAM (com pausa)")
code(0xE4BB, "CMD_LEFT", block=" Slot 9: ESQ/DIR sem SHIFT = cursor para a esquerda")
code(0xE4F8, "CMD_DOWN", block=" Slot 10: CIMA/BAIXO sem SHIFT = cursor para baixo")
code(0xE509, "CMD_COLOR", block=" Slot 8: COLOR = próxima cor da linha")
code(0xE51E, "CMD_OBJ", block=" Slot 4: OBJ = mostra/esconde o objeto (4 sprites 16x16)")
code(0xE528, "OBJ_HIDE")
code(0xE54E, "OBJ_DRAW", comment="grava os atributos dos sprites 0-3")
code(0xE5D7, "CMD_BORDER", block=" Slot 2: BORDER BLK = liga/desliga a imagem (bit BLANK de R1)")
code(0xE5EC, "CMD_PAGE", block=" Slot 1: PAGE = próxima página (ou a página digitada antes)")
code(0xE61A, "PAGE_REDRAW", comment="redesenha as 8 linhas com a imagem desligada")
code(0xE64D, "LINE_REDRAW", comment="redesenha a linha cur_line")
code(0xE67A, "LINE_DRAW_BIG")
code(0xE6C8, "LINE_DRAW_SMALL")
code(0xE70E, "CMD_RIGHT", block=" Slot 25: SHIFT+ESQ/DIR = cursor para a direita")
code(0xE711, "CURSOR_ADVANCE")
code(0xE74E, "CMD_UP", block=" Slot 26: SHIFT+CIMA/BAIXO = cursor para cima")
code(0xE75D, "CALC_CELL_VADDR", comment="cell_vaddr = linha*$300 + coluna*8")
code(0xE77A, "CMD_OBJ_SHAPE", block=" Slot 20: SHIFT+OBJ = próxima forma do objeto")
code(0xE784, "CMD_BACKDROP", block=" Slot 18: SHIFT+BORDER BLK = próxima cor de fundo (R7)")
code(0xE797, "CMD_PAGE_PREV", block=" Slot 17: SHIFT+PAGE = página anterior")
code(0xE7A2, "CMD_EXTVID", block=" Slots 5/21: EXT MODE = liga/desliga sobreposição ao vídeo externo (R0 bit0)")
code(0xE7B7, "CMD_CAPS", block=" Slot 22: SHIFT+CURSOR = trava de maiúsculas")
code(0xE7BE, "CMD_FONTSIZE", block=" Slot 15: CONTROL+CURSOR = alterna fonte grande/normal na linha")
code(0xE7D9, "CMD_CURSOR", block=" Slot 6: CURSOR = alterna forma do cursor (desligado/bloco/sublinhado)")
code(0xE803, "CURSOR_ERASE", comment="restaura a célula sob o cursor")
code(0xE879, "CURSOR_DRAW")
code(0xE91D, "CMD_RETURN", block=" Slot 7: RETURN = próxima linha")
code(0xE932, "CMD_CLEAR_PAGE", block=" Slot 19: SHIFT+CLEAR = apaga a página")
code(0xE961, "CMD_CLEAR_LINE", block=" Slot 3: CLEAR = apaga a linha")
code(0xE981, "CMD_OBJ_LEFT", block=" Slot 12: modo OBJ, ESQ/DIR = objeto para a esquerda")
code(0xE98D, "CMD_OBJ_DOWN", block=" Slot 13: modo OBJ, CIMA/BAIXO = objeto para baixo")
code(0xE99C, "CMD_OBJ_COLOR", block=" Slots 11/27: modo OBJ, COLOR = cor do objeto")
code(0xE9A6, "CMD_OBJ_RIGHT", block=" Slot 28: modo OBJ, SHIFT+ESQ/DIR = objeto para a direita")
code(0xE9B5, "CMD_OBJ_UP", block=" Slot 29: modo OBJ, SHIFT+CIMA/BAIXO = objeto para cima")
code(0xE9C1, "CMD_CENTER_ALL", block=" Slot 30: SHIFT+AUTO CENTER = centraliza todas as linhas")
code(0xE9DF, "CMD_CENTER", block=" Slot 14: AUTO CENTER = centraliza a linha atual")
code(0xE9EC, "CENTER_LINE")
code(0xEA9F, "VDP_WAIT_VBLANK", """
===========================================================================
 Rotinas de apoio ao VDP
===========================================================================""",
     "lê o status até o bit F (fim de quadro)")
code(0xEAA8, "SET_LINE_COLOR", comment="grava a cor em line_attr e na tabela de cores")
code(0xEAC5, "FILL_LINE_COLOR", comment="preenche $300 bytes de cor a partir de D+$2000")
code(0xEADB, "VDP_DELAY", comment="só RTS: pausa proposital entre escritas na VRAM")
code(0xEADC, "CALC_TEXT_OFS", comment="U = page*256 + line*32 + col")
code(0xEAF8, "VDP_SET_WRITE", comment="endereço de escrita da VRAM = D")
code(0xEB01, "GET_LINE_ATTR", comment="big_font e line_color da linha atual")
code(0xEB1B, "COLOR_XLATE", comment="A = COLORMAP[A]")
data(0xEB24, 16, "fcb", "COLORMAP", """
 Ordem das 16 cores ao apertar COLOR: índice -> cor do TMS9918
 (preto, transp.? , azul médio, azul claro, vermelho escuro, magenta, ...)""")
code(0xEB34, "CMD_ROLL", """
===========================================================================
 Slot 16: CONTROL+PAGE = rolagem vertical suave das páginas (letreiro de
 créditos). Rola pixel a pixel até a última página; ESPAÇO interrompe.
===========================================================================""")
code(0xEE9E, "TITLE_SCREEN", """
===========================================================================
 Tela de abertura: textos com a fonte grande, textos com a fonte 8x8 e o
 logotipo "tms".
===========================================================================""")
data(0xEECA, 36, "fcb", "TITLE_BIG_TEXT", """
 Registros: FDB endereço VRAM, FCB cor, texto..., 0   (FDB 0 termina)""")
code(0xEEEE, "TITLE_SMALL")
code(0xEFC7, "TITLE_LOGO")
code(0xF002, "VDP_COPY_48")
data(0xF013, 0x90, "fcb", "TMS_LOGO", " Padrões do logotipo 'tms' (3 linhas de 6 tiles)")
data(0xF0A3, 0x200, "fcb", "SPRITE_PATS", """
 Padrões de 16 sprites 16x16 (segmentos de moldura/linhas) -> VRAM $1800,
 usados pelo modo OBJ.""")
code(0xF392, "CTRL_ACCENT", """
 CONTROL + tecla = caractere acentuado / bloco gráfico / logotipo""")
data(0xF3BE, 48, "fcb", "ACCENT_TAB", " Tabela CONTROL+tecla ('0'..'_') -> caractere interno")
code(0xF3EE, "BIGFONT_INDEX_A", comment="A = código -> índice (A-$13), B = 48")
code(0xF3F9, "BIGFONT_INDEX_B", comment="B = código -> índice (B-$13), A = 48")

# --- fontes
data(0xC000, 0xD380 - 0xC000, "fcb", "BIG_FONT", """
===========================================================================
 Fonte grande: 104 glifos 16x24 (códigos $13-$7A), 48 bytes cada:
 3 linhas de tiles x (tile esquerdo 8 bytes + tile direito 8 bytes).
===========================================================================""")
data(0xD380, 0xDD40 - 0xD380, "fcb", "SMALL_FONT", """
===========================================================================
 Fonte normal: 104 glifos 8x24 (códigos $13-$7A), 24 bytes cada.
===========================================================================""")
data(0xDD40, 0x60, "fcb", "TMS_GLYPHS", " Glifos $7B-$7E da fonte normal: logotipo 'tms'")
data(0xDDA0, 0xE000 - 0xDDA0, "fcb", "FONT8X8", """
===========================================================================
 Fonte 8x8 da tela de abertura (códigos $30-$7B, 8 bytes cada).
===========================================================================""")


# --- textos da tela de abertura (registros com ponteiro, cor, contagem)
def _small_records(a):
    while True:
        if _w(a) == 0:
            DATA.append((a, 2, "fdb"))
            return
        DATA.append((a, 2, "fdb"))
        DATA.append((a + 2, 2, "fcb"))
        n = 0
        while _b(a + 4 + n):
            n += 1
        DATA.append((a + 4, n + 1, "fcc"))
        a += 4 + n + 1


def _big_records(a):
    while True:
        if _w(a) == 0:
            DATA.append((a, 2, "fdb"))
            return
        DATA.append((a, 2, "fdb"))
        DATA.append((a + 2, 1, "fcb"))
        n = 0
        while _b(a + 3 + n):
            n += 1
        DATA.append((a + 3, n + 1, "fcc"))
        a += 3 + n + 1


DATA[:] = [d for d in DATA if d[0] != 0xEECA]
_big_records(0xEECA)
LABELS[0xEF3C] = "TITLE_SMALL_TEXT"
BLOCK_COMMENTS[0xEF3C] = """
 Registros: FDB endereço VRAM, FCB cor, nº de tiles a colorir, texto..., 0
 (texto no conjunto interno: '@' = espaço, '>' = ponto, ';' = vírgula)"""
_small_records(0xEF3C)

LABELS[0xF2A3] = "FREE_SPACE1"
BLOCK_COMMENTS[0xF2A3] = " Área livre da EPROM ($FF, 238 bytes)"
LABELS[0xF404] = "FREE_SPACE2"
BLOCK_COMMENTS[0xF404] = " Área livre da EPROM ($FF, 3052 bytes)"

INLINE = {}
NORETURN = set()
COVERAGE = os.path.join(_HERE, "coverage.txt")
