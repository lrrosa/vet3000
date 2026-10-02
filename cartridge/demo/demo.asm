* Copyright (C) 2026 Leonardo Roman da Rosa
* SPDX-License-Identifier: GPL-3.0-or-later
* Software livre sob a GNU GPL versão 3 ou (a seu critério) posterior; veja LICENSE.
*
* ===========================================================================
*  VET 3000 DEMO - cartucho para o conector traseiro CN1 ($4000-$7FFF)
*
*  Abertura com logotipo em ciclo de cores, barras de cor, scroller suave e
*  sprites + o jogo QUEBRA-TIJOLO. Montar com asm6809 (ver build.sh /
*  build.ps1):
*      python gen_assets.py
*      asm6809 -B -o build/vet3000_demo.bin demo.asm
*
*  Regras seguidas para conviver com o firmware v2.1:
*   - Usa só RAM que o titulador reinicializa ou não usa: $0000-$002F,
*     $0035-$009F e $01D0-$01FF. Reserva $0190-$01CF para o top 10.
*     Os textos ($00A0-$018F, $0200-$1FFF) e a
*     assinatura "POWER" ($0030-$0034) ficam intactos.
*   - EXT MODE volta ao titulador (reset com a marca "EXIT" em $0080).
*   - Segurar EXT MODE ao ligar pula o cartucho.
*   - No editor do titulador, SHIFT+EXT MODE volta à demo: o cartucho troca
*     esse comando (que só repetia o EXT MODE) na tabela em RAM do firmware.
*   - Sincronismo lendo o bit F do status do VDP, com IRQ e FIRQ mascaradas.
*     No aparelho o /INT do VDP não está ligado ao IRQ do 6809 (medido), então
*     SYNC travaria; no MAME o driver liga os dois e esconderia o problema.
*   - Entre acessos à porta de dados do VDP há sempre >= 8 ciclos
*     (8,9 us a 0,895 MHz), o pior caso do TMS9128 na área ativa.
* ===========================================================================

VDP_DATA	equ	$8000
VDP_CTRL	equ	$8001
KEYBOARD	equ	$8002

* ---- VRAM (layout "Screen 2")
PAT		equ	$0000		; padrões: bancos em $0000/$0800/$1000
SPRPAT		equ	$1800
COL		equ	$2000		; cores: bancos em $2000/$2800/$3000
NAMES		equ	$3800
SPRATT		equ	$3B00

R1_ON		equ	$C2		; 16K | imagem | sprites 16x16 (sem IE)
R1_OFF		equ	$82		; 16K | sprites 16x16 (imagem desligada)

* ---- teclas (bits de 'keys')
K_LEFT		equ	$01
K_RIGHT		equ	$02
K_FIRE		equ	$04
K_EXIT		equ	$08
K_VIDEO		equ	$10
K_PAUSE		equ	$20
K_BACK		equ	$40		; CLEAR (Backspace no MAME)

* ---- cores do TMS9918
C_BLACK		equ	1
C_LBLUE		equ	5
C_CYAN		equ	7
C_MRED		equ	8
C_LRED		equ	9
C_DYELLOW	equ	10
C_LYELLOW	equ	11
C_LGREEN	equ	3
C_MAGENTA	equ	13
C_WHITE		equ	15
C_GRAY		equ	14

* ---- RAM (página direta = $00)
ticks		equ	$00		; passos de lógica por quadro (1 no HW, 3 no MAME 0.289)
frame		equ	$01
keys		equ	$02
keys_new	equ	$03		; teclas que acabaram de ser apertadas
vdp_r0		equ	$04
backdrop	equ	$05
tmp		equ	$06		; 2 bytes
tmp2		equ	$08		; 2 bytes
cnt		equ	$0A
scroll_ptr	equ	$0B		; 2 bytes
scroll_s	equ	$0D
shl_base	equ	$0E		; 2 bytes
shr_base	equ	$10		; 2 bytes
bar_phase	equ	$12
spr_phase	equ	$13
blink		equ	$14
spr_rot		equ	$15
* jogo
ball_x		equ	$18		; 8.8
ball_y		equ	$1A		; 8.8
ball_dx		equ	$1C		; 8.8 com sinal
ball_dy		equ	$1E
paddle_x	equ	$20
lives		equ	$21
level		equ	$22
score		equ	$23		; 3 bytes BCD
bricks_left	equ	$26
ball_state	equ	$27		; 0 = presa na raquete, 1 = em jogo
speed		equ	$28		; 2 bytes (velocidade vertical 8.8)
paused		equ	$2A
dirty		equ	$2B		; bit0 = placar, bit1 = vidas/fase
hitcnt		equ	$2C
* logotipo
logo_theme	equ	$2D		; tema de cores (0..LOGO_THEMES-1)
logo_pos	equ	$2E		; linhas já trocadas para o tema
logo_timer	equ	$2F		; passos até a próxima troca
* $30-$34: "POWER" do titulador - não tocar
attract_mode equ $35           ; 0 player, 1 CPU game, 2 timed ranking
attract_timer equ $36          ; 16-bit logic ticks
attract_count equ $38
attract_rng equ $39
attract_prev equ $3A
scroll_done equ $3B
alpha_last equ $3C
attract_keys equ $3D
serve_clock equ $3E            ; passos com a bola presa (lançamento automático)
extra_balls equ $3F            ; bolas extras em jogo: bit0 = BALL2, bit1 = BALL3
CMD_TABLE	equ	$0040		; tabela de comandos do titulador (recriada no boot)
CMD_SHIFT_EXT	equ	$15		; código de SHIFT+EXT MODE
BARBUF		equ	$0040		; 64 bytes: cor de cada linha das barras
EXIT_MAGIC	equ	$0080		; "EXIT" = voltar ao titulador após o reset
BRICKS		equ	$0084		; 10 palavras: tijolos de cada linha (bit15 = coluna 0)
dbg_warm	equ	$0098		; build DEBUG: quadros a ignorar no início da cena
dbg_skip	equ	$0099		; build DEBUG: quadro já sincronizado
DBG_FRAME	equ	$009A		; build DEBUG: voltas de 13 ciclos num quadro inteiro
DBG_MINIDLE	equ	$009C		; build DEBUG: menor sobra (voltas) já medida
SAT		equ	$0040		; cópia da tabela de atributos de sprites (33 bytes)
* BARBUF and SAT share RAM: title uploads bars before building sprites.
* Game aliases title-only scratch. Armor/gold live where the title draws bars.
power_kind equ $0B
power_x equ $0C
power_y equ $0D
power_clock equ $0E
wide equ $0F
slow equ $10
sticky equ $11
gate equ $12
laser equ $13
shot_x equ $14
shot_y equ $15
shot_active equ $16
launch_dir equ $17
boss_col equ $2D
boss_dir equ $2E
boss_flash equ $2F
boss_tick equ $60              ; boss arena does not use GOLD masks
boss_bolt_dx equ $5F
ARMOR equ $40                  ; 10 mutable row masks (two-hit silver)
GOLD equ $54                   ; 10 immutable row masks (indestructible)
GAME_SAT equ $6B               ; cápsula e tiro + terminador, até $73
BALL2 equ $74                  ; bolas extras (cápsula D): x, y, dx, dy em 8.8,
BALL3 equ $7C                  ; como ball_x..ball_dy; $80-$83 só guarda EXIT na saída
brick_color equ $68
brick_gold equ $69             ; draw-only shifting gold mask
hs_pos equ $61                 ; ranking aliases game-only masks
hs_letter equ $62
hs_row equ $63
hs_blink equ $64               ; relógio do cursor das iniciais
HS equ $0190                   ; 64 battery-backed bytes, outside title storage
HS_DATA equ HS+4               ; ten entries: 3 BCD bytes, 3 ASCII initials
HS_END equ HS+64
STACK_TOP	equ	$0200

		setdp	0

* ===========================================================================
*  Cabeçalho procurado pela ROM (PROBE_OBJECT em $E139)
* ===========================================================================
		org	$4000
		fcc	"OBJECT"		; assinatura
		fdb	cart_vec		; a ROM faz LDX [$4006]: ponteiro para...
cart_vec	fdb	entry-$4000		; ...o deslocamento da entrada (JSR $4000,X)
		fcc	"VET 3000 DEMO 1.5 (C) 2026 LEONARDO ROMAN DA ROSA - GPL-3.0",0

* ===========================================================================
*  Entrada: chamada pela ROM com JSR durante o boot (VDP já inicializado,
*  IRQ mascarada, DP = 0, pilha em ~$01FE).
* ===========================================================================
entry		ldd	EXIT_MAGIC		; voltando da demo por EXT MODE?
		cmpd	#"EX"
		bne	1F
		ldd	EXIT_MAGIC+2
		cmpd	#"IT"
		bne	1F
		clr	EXIT_MAGIC
		clr	EXIT_MAGIC+2
		bra	2F			; -> firmware segue para o titulador
1		lda	#$FB			; linha 3 do teclado
		sta	KEYBOARD
		lda	KEYBOARD
		bita	#$08			; EXT MODE apertado?
		bne	start			; solta: roda a demo
2		ldd	#back_to_demo		; indo para o titulador: lá, SHIFT+EXT MODE
		std	CMD_TABLE+2*CMD_SHIFT_EXT	; passa a trazer a demo de volta
		rts

start		orcc	#$50			; IRQ e FIRQ mascaradas (sem interrupções)
		lds	#STACK_TOP
		lda	#$02
		sta	vdp_r0
		lda	#C_BLACK
		sta	backdrop
		lbsr	vdp_init
		lbsr	calibrate
		clr	attract_mode
		lda	frame
		eora	#$A7
		sta	attract_rng
main_loop	lbsr	hs_init
		lbsr	title
		lbsr	game
		bra	main_loop

* ---------------------------------------------------------------------------
*  exit_to_titler: marca "EXIT" e reinicia a máquina
* ---------------------------------------------------------------------------
exit_to_titler
		lda	#$82			; R1: imagem e interrupção desligadas
		ldb	#1
		lbsr	vdp_reg
		ldd	#"EX"
		std	EXIT_MAGIC
		ldd	#"IT"
		std	EXIT_MAGIC+2
		jmp	[$FFFE]

* ---------------------------------------------------------------------------
*  back_to_demo: comando SHIFT+EXT MODE instalado na tabela do titulador
*  pela entrada. Apaga a tela, espera EXT MODE ficar solta (apertada, ela faz
*  o boot pular o cartucho) e reinicia a máquina, que volta a rodar a demo.
* ---------------------------------------------------------------------------
back_to_demo	orcc	#$50
		lda	#$82			; R1: imagem e interrupção desligadas
		ldb	#1
		lbsr	vdp_reg
		clr	EXIT_MAGIC
1		ldx	#1000			; ~28 ms seguidos com a tecla solta
2		lda	#$FB			; linha 3: EXT MODE (bit 3)
		sta	KEYBOARD
		lda	KEYBOARD
		bita	#$08
		beq	1B			; ainda apertada: recomeça a contagem
		leax	-1,X
		bne	2B
		jmp	[$FFFE]

* ===========================================================================
*  Rotinas do VDP
* ===========================================================================

* vdp_reg: A = valor, B = número do registrador (preserva B)
vdp_reg		sta	VDP_CTRL
		pshs	b
		orb	#$80
		stb	VDP_CTRL
		puls	b,pc

* vdp_wr: D = endereço de escrita na VRAM
vdp_wr		stb	VDP_CTRL
		ora	#$40
		sta	VDP_CTRL
		rts

* vdp_fill: preenche Y bytes com A (13 ciclos por byte)
vdp_fill	sta	VDP_DATA
		leay	-1,Y
		bne	vdp_fill
		rts

* vdp_copy: copia Y bytes de X (19 ciclos por byte)
vdp_copy	lda	,X+
		sta	VDP_DATA
		leay	-1,Y
		bne	vdp_copy
		rts

* vdp_unrle: descompacta RLE de X para a VRAM (endereço já definido)
*   n < $80: n bytes literais; n >= $80: repete o próximo byte n-$7E vezes; 0 = fim
vdp_unrle	ldb	,X+
		beq	3F
		bmi	2F
1		lda	,X+
		sta	VDP_DATA
		decb
		bne	1B
		bra	vdp_unrle
2		subb	#$7E
		lda	,X+
1		sta	VDP_DATA		; 10 ciclos entre escritas
		decb
		bne	1B
		bra	vdp_unrle
3		rts

* wait_frame: espera o fim do quadro lendo o status do VDP até o bit F, como
* o firmware (VDP_WAIT_VBLANK). Se o F já estava ligado, volta na hora.
wait_frame
		if DEBUG
		tst	dbg_skip		; dbg_done já esperou o quadro
		beq	1F
		clr	dbg_skip
		bra	2F
		endif
1		lda	VDP_CTRL		; bit 7 = F; a leitura zera o F
		bpl	1B
2		inc	frame
		rts

* dbg_done (só no build DEBUG): conta voltas ociosas de 13 ciclos até o
* próximo quadro e guarda a menor em DBG_MINIDLE (lida pelo script Lua)
dbg_done
		if DEBUG
		ldx	#0
1		leax	1,X
		lda	VDP_CTRL
		bpl	1B
		tst	dbg_warm		; ignora os primeiros quadros da cena
		beq	3F
		dec	dbg_warm
		bra	2F
3		cmpx	DBG_MINIDLE
		bhs	2F
		stx	DBG_MINIDLE
2		inc	dbg_skip
		endif
		rts

* dbg_scene (só no build DEBUG): recomeça a medida numa cena nova
dbg_scene
		if DEBUG
		ldd	#$FFFF
		std	DBG_MINIDLE
		lda	#4
		sta	dbg_warm
		endif
		rts

* vdp_init: registros fixos do modo Graphics II, VRAM zerada, imagem desligada
vdp_init	ldx	#vdp_regs
		ldb	#0
1		lda	,X+
		lbsr	vdp_reg
		incb
		cmpb	#8
		bne	1B
		ldd	#$0000
		lbsr	vdp_wr
		clra
		ldy	#$4000
		lbra	vdp_fill
vdp_regs	fcb	$02,R1_OFF,$0E,$FF,$03,$76,$03,C_BLACK

screen_off	lda	#R1_OFF
		ldb	#1
		lbra	vdp_reg
screen_on	lda	#R1_ON
		ldb	#1
		lbra	vdp_reg

* hide_sprites: primeiro sprite com Y = $D0 (fim da lista)
hide_sprites	ldd	#SPRATT
		lbsr	vdp_wr
		lda	#$D0
		sta	VDP_DATA
		lda	#$D0
		sta	SAT
		rts

* put_game_sat: rebatedor (4 sprites, 6 no grande) gravado direto na VRAM a
* partir de paddle_x, seguido da bola, da cápsula e do tiro da tabela em RAM.
* O rebatedor vem primeiro: com 4 sprites numa linha o VDP descarta os de
* número maior, então quem some é uma cápsula ou a bola já perdida ao lado
* dele, nunca um pedaço do rebatedor. Os terminais e o corpo cinza começam nas
* linhas 0 e 2; o brilho branco termina na linha 1 (ver gen_assets.py).
put_game_sat	ldd	#SPRATT
		lbsr	vdp_wr
		ldx	#paddle_parts
		ldb	#4			; normal: brilho, 2 terminais, corpo
		tst	wide
		beq	1F
		ldb	#6			; grande: mais um segmento de corpo
1		lda	1,X			; deslocamento X
		cmpx	#paddle_parts+8		; terminal direito: anda com o wide
		bne	2F
		adda	wide
2		adda	paddle_x
		sta	tmp+1
		lda	,X			; Y
		bcc	3F
		lda	#$C0			; passou de x=255 (saída): fora da tela
3		sta	VDP_DATA
		lda	tmp+1
		leax	2,X
		sta	VDP_DATA
		lda	,X+			; padrão
		sta	VDP_DATA
		lda	,X+			; cor
		sta	VDP_DATA
		decb
		bne	1B
		bsr	put_balls
		ldx	#GAME_SAT
		bra	sat_copy
paddle_parts	fcb	PADDLE_Y-15,8,PAT_SHINE,C_WHITE		; linhas 0-1 do corpo
		fcb	PADDLE_Y-1,0,PAT_TIP_L,C_MRED
		fcb	PADDLE_Y-1,16,PAT_TIP_R,C_MRED		; + wide
		fcb	PADDLE_Y+1,8,PAT_BODY,C_GRAY		; linhas 2-5 do corpo
		fcb	PADDLE_Y-15,24,PAT_SHINE,C_WHITE	; só no grande
		fcb	PADDLE_Y+1,24,PAT_BODY,C_GRAY

* put_balls: a bola principal e as extras ativas. A ordem inverte a cada
* quadro: se 5 sprites caírem numa linha, a bola descartada pisca em vez de
* sumir. O desenho fica nas linhas 10-15 do sprite (Y = y - 11).
put_balls	ldx	#ball_order
		lda	frame
		bita	#1
		beq	1F
		ldx	#ball_order+9
1		ldb	#3
2		lda	2,X			; bit em extra_balls (0 = principal)
		beq	3F
		bita	extra_balls
		beq	4F
3		ldu	,X
		lda	2,U			; y (parte inteira)
		suba	#11
		sta	VDP_DATA
		lda	,U			; x
		sta	VDP_DATA
		lda	#PAT_BALL
		nop
		sta	VDP_DATA
		lda	#C_WHITE
		nop
		sta	VDP_DATA
4		leax	3,X
		decb
		bne	2B
		rts
ball_order	fdb	ball_x
		fcb	0
		fdb	BALL2
		fcb	1
		fdb	BALL3
		fcb	2
		fdb	BALL3			; quadros ímpares: ordem invertida
		fcb	2
		fdb	BALL2
		fcb	1
		fdb	ball_x
		fcb	0

* put_sat: copia a tabela de sprites da RAM (termina no Y = $D0)
put_sat		ldd	#SPRATT
		lbsr	vdp_wr
		ldx	#SAT
sat_copy
1		lda	,X+
		sta	VDP_DATA
		cmpa	#$D0
		beq	2F
		ldb	#3
3		lda	,X+
		sta	VDP_DATA
		decb
		bne	3B
		bra	1B
2		rts

* ---------------------------------------------------------------------------
*  calibrate: mede os ciclos por quadro (laço de 13 ciclos) e define 'ticks'.
*  VET 3000 real: ~14.930 ciclos (60 Hz) -> 1.  MAME 0.289: o driver usa
*  3,58 MHz no VDP (20 Hz) -> ~44.800 ciclos -> 3 passos de lógica por quadro.
* ---------------------------------------------------------------------------
calibrate	lda	#R1_OFF
		ldb	#1
		lbsr	vdp_reg			; R1 sem IE, imagem desligada
		ldu	#$FFFF			; menor medida
		lda	#3
		sta	cnt
		lda	VDP_CTRL		; descarta um fim de quadro antigo (F já em 1)
		lbsr	wait_frame		; agora sim: início de um quadro
1		ldx	#0			; cada medida começa onde a anterior viu o F
2		leax	1,X			; 5
		lda	VDP_CTRL		; 5 (lê o status: bit 7 = fim de quadro)
		bpl	2B			; 3
		stx	tmp
		cmpu	tmp
		bls	3F
		ldu	tmp
3		dec	cnt
		bne	1B
		if DEBUG
		stu	DBG_FRAME
		ldd	#$FFFF
		std	DBG_MINIDLE
		clr	dbg_skip
		endif
		clr	ticks			; ticks = (n + 573) / 1147, entre 1 e 4
		tfr	U,D
		addd	#573
4		subd	#1147
		bcs	5F
		inc	ticks
		bra	4B
5		lda	ticks
		bne	6F
		inca
6		cmpa	#4
		bls	7F
		lda	#4
7		sta	ticks
		rts

* ---------------------------------------------------------------------------
*  read_keys: varre as teclas usadas -> keys / keys_new
*    Z / O / ESQ-DIR  = esquerda     X / P / SHIFT+ESQ-DIR = direita
*    ESPAÇO = ação    EXT MODE = sair    V = sobrepor vídeo    RETURN = pausa
* ---------------------------------------------------------------------------
read_keys	clrb
		lda	#$BF			; linha 7: Z(0) X(1) ESQ/DIR(4) CLEAR(5) V(6)
		sta	KEYBOARD
		lda	KEYBOARD
		coma
		bita	#$20
		beq	1F
		orb	#K_BACK
1		bita	#$01
		beq	1F
		orb	#K_LEFT
1		bita	#$02
		beq	1F
		orb	#K_RIGHT
1		bita	#$40
		beq	1F
		orb	#K_VIDEO
1		bita	#$10
		beq	2F
		lda	#$FE			; linha 1: SHIFT(3)
		sta	KEYBOARD
		lda	KEYBOARD
		bita	#$08
		bne	1F
		orb	#K_RIGHT
		bra	2F
1		orb	#K_LEFT
2		lda	#$FB			; linha 3: EXT MODE(3) O(5) ESPAÇO(7)
		sta	KEYBOARD
		lda	KEYBOARD
		coma
		bita	#$80
		beq	1F
		orb	#K_FIRE
1		bita	#$08
		beq	1F
		orb	#K_EXIT
1		bita	#$20
		beq	1F
		orb	#K_LEFT
1		lda	#$F7			; linha 4: P(5) RETURN(6)
		sta	KEYBOARD
		lda	KEYBOARD
		coma
		bita	#$20
		beq	1F
		orb	#K_RIGHT
1		bita	#$40
		beq	1F
		orb	#K_PAUSE
1		pshs	b
		lda	keys			; keys_new = agora AND NOT antes
		coma
		anda	,S+
		sta	keys_new
		stb	keys
		rts

* ===========================================================================
*  ABERTURA (demo)
* ===========================================================================
title		lbsr	screen_off
		lbsr	hide_sprites
		* tabela de nomes: bancos 0 e 2 em modo bitmap (0..255); no banco 1
		* cada linha de tiles usa um único tile (0..7, padrão $FF) repetido nas
		* 32 colunas: as cores desses 8 tiles pintam 64 scanlines inteiras
		ldd	#NAMES
		lbsr	vdp_wr
		lbsr	names_seq
		clra
2		ldb	#32
3		sta	VDP_DATA
		decb
		bne	3B
		inca
		cmpa	#8
		bne	2B
		lbsr	names_seq
		* padrões e cores das partes fixas
		ldd	#PAT
		lbsr	vdp_wr
		ldx	#TITLE0_PAT
		lbsr	vdp_unrle
		ldd	#COL
		lbsr	vdp_wr
		ldx	#TITLE0_COL
		lbsr	vdp_unrle
		ldd	#PAT+$1000
		lbsr	vdp_wr
		ldx	#TITLE2_PAT
		lbsr	vdp_unrle
		ldd	#COL+$1000
		lbsr	vdp_wr
		ldx	#TITLE2_COL
		lbsr	vdp_unrle
		ldd	#PAT+$0800		; tiles 0..7 do banco 1 = $FF
		lbsr	vdp_wr
		lda	#$FF
		ldy	#64
		lbsr	vdp_fill
		ldd	#SPRPAT
		lbsr	vdp_wr
		ldx	#SPRITE_PATS
		ldy	#SPRITE_PATS_END-SPRITE_PATS
		lbsr	vdp_copy
		* variáveis
		ldd	#SCROLL_TEXT
		std	scroll_ptr
		clr	scroll_s
		clr	scroll_done
		clr	blink
		clr	keys
		clr	logo_theme		; o logotipo começa no tema gravado na tela
		lda	#LOGO_LINES
		sta	logo_pos
		lda	#LOGO_HOLD
		sta	logo_timer
		lbsr	build_bars
		lbsr	put_bars
		lbsr	build_balls
		lbsr	put_sat
		lbsr	wait_frame
		lbsr	screen_on
		lbsr	dbg_scene

title_loop	lbsr	wait_frame
		* --- atualizações de VRAM (começam no apagamento vertical)
		lbsr	put_bars
		lbsr	build_balls
		lbsr	put_sat
		lbsr	put_scroller
		lda	frame
		anda	#31
		bne	1F
		lbsr	put_blink
		* --- lógica: 'ticks' passos por quadro
1		ldb	ticks
2		pshs	b
		lbsr	title_step
		puls	b
		decb
		bne	2B
		lbsr	build_bars
		lbsr	dbg_done
		lbsr	read_keys
		lda	keys_new
		bita	#K_EXIT
		lbne	exit_to_titler
		bita	#K_VIDEO
		beq	3F
		lbsr	toggle_video
3		lda	keys_new
		bita	#K_PAUSE
		beq	4F
		lbsr	game_tiles_init
		lbsr	hs_show
		lbra	title
4		lda	keys_new
		bita	#K_FIRE
                bne 5F
                tst scroll_done
                lbeq title_loop
                lda #1
                sta attract_mode
                rts
5               clr attract_mode
                rts

* names_seq: escreve 0..255 na tabela de nomes (endereço já definido)
names_seq	clra
1		sta	VDP_DATA
		nop
		inca
		bne	1B
		rts

* title_step: avança as animações um passo de 1/60 s
title_step	lda	bar_phase
		adda	#3
		sta	bar_phase
		lda	spr_phase
		adda	#2
		sta	spr_phase
		lda	scroll_s
		adda	#2
		cmpa	#8
		bne	1F
		ldx	scroll_ptr
		leax	2,X
		cmpx	#SCROLL_WRAP
		bne	2F
		ldx	#SCROLL_TEXT
		inc	scroll_done
2		stx	scroll_ptr
		clra
1		sta	scroll_s
*		(segue em logo_step)

* ---------------------------------------------------------------------------
*  Logotipo em ciclo de cores. A cor de cada linha de pixel vem de um tema
*  (LOGO_COLORS, gerado com degradê por nível de brilho). A cada LOGO_STEP
*  passos uma linha passa para o tema seguinte, na ordem de LOGO_ORDER; com
*  todas trocadas, o tema fica LOGO_HOLD passos e o ciclo continua.
*  Trocar uma linha custa ~900 ciclos (uma vez a cada LOGO_STEP passos).
* ---------------------------------------------------------------------------
LOGO_STEP	equ	4		; passos entre duas linhas (15 linhas/s)
LOGO_HOLD	equ	60		; passos com o tema completo (1 s)

logo_step	dec	logo_timer
		beq	1F
		rts
1		ldb	logo_pos
		cmpb	#LOGO_LINES
		blo	2F
		lda	logo_theme		; tema completo: começa o próximo
		inca
		cmpa	#LOGO_THEMES
		blo	3F
		clra
3		sta	logo_theme
		clrb
2		incb
		stb	logo_pos
		lda	#LOGO_STEP
		cmpb	#LOGO_LINES
		bne	4F
		lda	#LOGO_HOLD
4		sta	logo_timer
		ldx	#LOGO_ORDER-1
		ldb	B,X			; linha a trocar
		pshs	b
		lda	logo_theme		; cor = LOGO_COLORS[tema*LOGO_LINES + linha]
		ldb	#LOGO_LINES
		mul
		addb	,S
		adca	#0
		ldx	#LOGO_COLORS
		lda	D,X
		puls	b
*		(segue em logo_line)

* logo_line: grava a cor A (frente<<4 | fundo) na linha B do logotipo, nas
*   colunas LOGO_COL0..LOGO_COL1-1: um byte por tile, refazendo o endereço a
*   cada coluna (34 ciclos por coluna, >= 9 entre acessos ao VDP)
logo_line	sta	tmp+1			; cor
		addb	#LOGO_Y			; linha de pixels no banco 0
		tfr	b,a
		lsra
		lsra
		lsra
		ora	#(COL>>8)|$40		; COL + linha de tiles * $100, para escrita
		sta	tmp
		andb	#7
		addb	#LOGO_COL0*8
		lda	#LOGO_COL1-LOGO_COL0
		sta	cnt
1		stb	VDP_CTRL		; endereço: byte baixo...
		lda	tmp
		sta	VDP_CTRL		; ...e alto
		lda	tmp+1
		sta	VDP_DATA
		addb	#8			; a mesma linha na próxima coluna
		dec	cnt
		bne	1B
		rts

* toggle_video: EXTVID (R0 bit 0) + fundo transparente = texto sobre o vídeo
*   da entrada do VET (no MAME a entrada de vídeo não é emulada). O vídeo só
*   passa onde a cor é 0, então todos os fundos da demo (tiles, barras,
*   logotipo) são cor 0, não preto: com o backdrop preto parecem pretos
toggle_video	lda	vdp_r0
		eora	#$01
		sta	vdp_r0
		ldb	#0
		lbsr	vdp_reg
		lda	backdrop
		eora	#C_BLACK		; alterna entre preto (1) e transparente (0)
		sta	backdrop
		ldb	#7
		lbra	vdp_reg

* put_blink: pisca "ESPACO: JOGAR" trocando os nomes da linha
put_blink	ldd	#NAMES+(16+BLINK_ROW)*32
		lbsr	vdp_wr
		com	blink
		beq	2F
		lda	#255			; tile vazio
		ldb	#32
1		sta	VDP_DATA
		decb
		bne	1B
		rts
2		lda	#BLINK_ROW*32
		ldb	#32
3		sta	VDP_DATA
		inca
		decb
		bne	3B
		rts

* ---------------------------------------------------------------------------
*  Barras de cor: as 8 linhas de tiles do banco 1 usam um tile cada, repetido
*  nas 32 colunas. Mudar as 8 cores de um tile muda 8 scanlines inteiras:
*  64 bytes por quadro desenham as barras sem interrupção de linha.
* ---------------------------------------------------------------------------
put_bars	ldd	#COL+$0800		; cores dos tiles 0..7 do banco 1
		lbsr	vdp_wr
		ldx	#BARBUF
		ldb	#64
1		lda	,X+
		sta	VDP_DATA
		decb
		bne	1B
		rts

build_bars	ldx	#BARBUF			; fundo transparente (cor 0; ver toggle_video)
		ldd	#$0000
		ldy	#32
1		std	,X++
		leay	-1,Y
		bne	1B
		* duas passadas: primeiro as barras "atrás" (cos < 0), depois as da frente
		clr	tmp2
2		clr	cnt			; barra 0..3
3		lda	cnt
		ldb	#256/NUM_BARS
		mul				; B = barra*51
		addb	bar_phase		; fase
		stb	tmp
		ldx	#SINE_C
		addb	#64			; cos = sin(fase + 64)
		eorb	#$80			; índice sem sinal -> deslocamento com sinal
		ldb	B,X
		andb	#$80			; sinal do cosseno
		eorb	tmp2			; passada 0: desenha se cos < 0 (b7=1)
		bpl	5F
		ldb	tmp
		eorb	#$80
		lda	B,X			; seno com sinal -> 0..64-BAR_H
		adda	#128
		ldb	#64-BAR_H+1
		mul
		ldy	#BARBUF
		leay	A,Y
		lda	cnt			; X = BAR_GRAD + barra*BAR_H
		ldb	#BAR_H
		mul
		ldx	#BAR_GRAD
		abx
		ldb	#BAR_H
4		lda	,X+
		sta	,Y+
		decb
		bne	4B
5		inc	cnt
		lda	cnt
		cmpa	#NUM_BARS
		bne	3B
		lda	tmp2
		bne	6F
		lda	#$80
		sta	tmp2
		bra	2B
6		rts

* ---------------------------------------------------------------------------
*  Scroller: 32 tiles da linha 19 (banco 2). Cada byte = (glifo<<s)|(próximo>>(8-s)),
*  lido de tabelas pré-deslocadas na ROM: LDA/ORA/STA = 15 ciclos por byte.
* ---------------------------------------------------------------------------
put_scroller	ldb	scroll_s		; s = 0,2,4,6 -> SCROLL_TABS + s*2
		lslb
		ldx	#SCROLL_TABS
		abx
		ldd	,X
		std	shl_base
		ldd	2,X
		std	shr_base
		ldd	#PAT+$1000+SCROLL_ROW*256
		lbsr	vdp_wr
		ldu	scroll_ptr
		lda	#32
		sta	cnt
1		ldd	,U			; coluna c
		addd	shl_base
		tfr	D,X
		ldd	2,U			; coluna c+1
		addd	shr_base
		tfr	D,Y
		leau	2,U
		lda	,X
		ora	,Y
		sta	VDP_DATA
		lda	1,X
		ora	1,Y
		sta	VDP_DATA
		lda	2,X
		ora	2,Y
		sta	VDP_DATA
		lda	3,X
		ora	3,Y
		sta	VDP_DATA
		lda	4,X
		ora	4,Y
		sta	VDP_DATA
		lda	5,X
		ora	5,Y
		sta	VDP_DATA
		lda	6,X
		ora	6,Y
		sta	VDP_DATA
		lda	7,X
		ora	7,Y
		sta	VDP_DATA
		dec	cnt
		bne	1B
		rts

* ---------------------------------------------------------------------------
*  Bolas: 6 sprites numa curva de Lissajous sobre as barras. A ordem na
*  tabela gira a cada quadro para dividir o limite de 4 sprites por linha.
* ---------------------------------------------------------------------------
NUM_BALLS	equ	6
build_balls	inc	spr_rot
		lda	spr_rot
		cmpa	#NUM_BALLS
		blo	1F
		clr	spr_rot
1		ldu	#SAT
		clr	cnt
2		lda	cnt			; bola i = (cnt + spr_rot) mod 6
		adda	spr_rot
		cmpa	#NUM_BALLS
		blo	3F
		suba	#NUM_BALLS
3		sta	tmp			; i
		ldb	#43			; deslocamento de fase entre bolas
		mul
		addb	spr_phase
		stb	tmp+1			; fase da bola
		ldx	#SINE_C
		lslb				; y = 58 + (sin(2*fase+64)+128)*56/256
		addb	#64
		eorb	#$80
		lda	B,X
		adda	#128
		ldb	#56
		mul
		adda	#58
		sta	,U+
		ldb	tmp+1			; x = 8 + (sin(fase)+128)*224/256
		eorb	#$80
		lda	B,X
		adda	#128
		ldb	#224
		mul
		adda	#8
		sta	,U+
		clr	,U+			; padrão 0 (bola 16x16)
		ldx	#ball_colors
		ldb	tmp
		lda	B,X
		sta	,U+
		inc	cnt
		lda	cnt
		cmpa	#NUM_BALLS
		bne	2B
		lda	#$D0
		sta	,U
		rts
ball_colors	fcb	C_LRED,C_LYELLOW,C_LGREEN,C_CYAN,C_LBLUE,C_MAGENTA

* ===========================================================================
*  JOGO: QUEBRA-TIJOLO
* ===========================================================================
PADDLE_Y	equ	176
FIELD_L		equ	8
FIELD_R		equ	248
FIELD_T		equ	16
BRICK_Y		equ	24		; linha de tiles 3
SPEED_START	equ	$0200		; velocidade vertical inicial (8.8, pixels por passo)
SPEED_STEP	equ	$0040		; aumento a cada fase
SPEED_MAX	equ	$0340
PADDLE_STEP	equ	4		; pixels por passo do rebatedor (3 até a versão 1.4)
AUTO_LAUNCH	equ	240		; passos com a bola presa até ela sair sozinha (4 s)
MSG_ROW		equ	14		; linha do meio da tela: estágio, fim de fase/jogo
HINT_ROW	equ	16		; PAUSA

game_tiles_init	lbsr	screen_off
		lbsr	hide_sprites
		* tiles do jogo nos 3 bancos
		clr	cnt
1		lda	cnt
		clrb
		lsla
		lsla
		lsla				; D = banco * $800
		lbsr	vdp_wr
		ldx	#GAME_PAT
		lbsr	vdp_unrle
		lda	cnt
		clrb
		lsla
		lsla
		lsla
		adda	#$20
		lbsr	vdp_wr
		ldx	#GAME_COL
		lbsr	vdp_unrle
		inc	cnt
		lda	cnt
		cmpa	#3
		bne	1B
		rts
game		lbsr	game_tiles_init
		* variáveis
		lda	#4
		sta	lives
		clr	level
		clr	score
		clr	score+1
		clr	score+2
		clr	paused
		clr	launch_dir
		ldd	#SPEED_START
		std	speed
                tst attract_mode
                beq new_level
                lda #3
                sta attract_count
                lda #255
                sta attract_prev
                lbsr attract_pick
new_level	clr	gate
		lbsr	screen_off
		lbsr	draw_field
		lbsr	load_level
		lbsr	draw_bricks
		lbsr	draw_status
		lbsr	serve
		lbsr	game_sprites
		lbsr	put_game_sat
		lbsr	wait_frame
		lbsr	screen_on
		lbsr	dbg_scene

game_loop	lbsr	wait_frame
		lbsr	put_game_sat
		lda	dirty
		beq	1F
		lbsr	draw_status
1		lbsr	read_keys
		lda	keys_new
		bita	#K_EXIT
		lbne	exit_to_titler
		bita	#K_VIDEO
		beq	2F
		lbsr	toggle_video
2               tst attract_mode
                beq 6F
                lda keys
                bita #K_FIRE
                lbne attract_start
                lbsr attract_update
                tsta
                lbne attract_next
                bra 3F
6		lda	keys_new
		bita	#K_PAUSE
		beq	3F
		com	paused
		ldx	#msg_pause
		tst	paused
		bne	5F
		ldx	#msg_blank
5		ldd	#NAMES+HINT_ROW*32
		lbsr	print_centered
3		tst	paused
		bne	game_loop
		ldb	ticks
4		pshs	b
		lbsr	game_step
		puls	b
		tst	lives			; fim de jogo?
		beq	game_over
		tst	bricks_left		; fase completa?
		beq	level_done
		decb
		bne	4B
		lbsr	game_sprites
		tst	attract_mode
		beq	7F
		lda	attract_keys
		sta	keys
7
		lbsr	dbg_done
		bra	game_loop

level_done	tst	attract_mode
		lbne	attract_next
		lbsr	draw_status		; inclui os pontos do último tijolo
		lbsr	gate_slide		; saiu pela parede: termina de passar
		inc	level
		lda	level
		cmpa	#NUM_LEVELS+1
		lbeq	campaign_done
		ldd	speed			; mais rápido a cada fase
		cmpd	#SPEED_MAX
		bhs	1F
		addd	#SPEED_STEP
		std	speed
1		ldx	#msg_level
		lbsr	center_msg
		ldb	#90
		lbsr	pause_frames
		lbra	new_level

game_over	tst	attract_mode
		lbne	attract_next
		lbsr	draw_status
		lbsr	hide_sprites
		ldx	#msg_over
		lbsr	center_msg
		ldb	#180
		lbsr	pause_frames
		lbra	hs_game_over

* center_msg: mensagem X no meio da tela (16 caracteres, cobre "FASE 01") e
* apaga a linha de baixo (PAUSA)
center_msg	ldd	#NAMES+MSG_ROW*32
		lbsr	print_centered
		ldx	#msg_blank
		ldd	#NAMES+HINT_ROW*32
		lbra	print_centered

* pause_frames: espera B passos de 1/60 s (ou ESPAÇO)
* (as mensagens msg_* ficam em assets.inc, com acentos)
pause_frames	pshs	b
		lbsr	wait_frame
		lbsr	read_keys
		puls	b
		lda	keys_new
		bita	#K_EXIT
		lbne	exit_to_titler
		bita	#K_FIRE
		bne	2F
		subb	ticks
		bhi	pause_frames
2		rts


* X = text, D = first cell of row; center on the 32-column display.
print_centered  pshs d,x
                ldb #32
1               lda ,X+
                beq 2F
                decb
                bra 1B
2               lsrb
                clra
                addd ,S
                ldx 2,S
                leas 4,S
                lbra print_at

* print_at: X = texto (ASCII, 0 no fim), D = endereço na tabela de nomes
print_at	lbsr	vdp_wr
1		lda	,X+
		beq	2F
		suba	#FONT_FIRST
		sta	VDP_DATA
		bra	1B
2		rts

* draw_field: status na linha 0, paredes nas bordas, área limpa
draw_field	ldd	#NAMES
		lbsr	vdp_wr
		clra
		ldy	#768
		lbsr	vdp_fill		; tudo "espaço" (tile 0)
		ldd	#NAMES+32		; teto
		lbsr	vdp_wr
		lda	#T_WALL_TOP
		ldy	#32
		lbsr	vdp_fill
		lda	#2			; paredes laterais nas linhas 2..23
		sta	cnt
1		lda	cnt
		ldb	#32
		mul
		addd	#NAMES
		std	tmp
		lbsr	vdp_wr
		lbsr	wall_tile
		sta	VDP_DATA
		ldd	tmp
		addd	#31
		lbsr	vdp_wr
		lbsr	wall_tile
		sta	VDP_DATA
		inc	cnt
		lda	cnt
		cmpa	#24
		bne	1B
		ldx	#msg_hud
		ldd	#NAMES
		lbsr	print_at
		ldx	#power_help
		tst	attract_mode
		beq	7F
		ldx	#attract_help
7		ldd	#NAMES+23*32
		lbra	print_centered

* Metal rails have a joint every four tiles instead of a rivet every eight pixels.
wall_tile       lda #T_WALL
                ldb cnt
                andb #3
                bne 1F
                lda #68
1               rts

* draw_status: placar (BCD), vidas e fase
draw_status	clr	dirty
		ldd	#NAMES+7
		lbsr	vdp_wr
		ldx	#score
		ldb	#3
1		lda	,X
		lsra
		lsra
		lsra
		lsra
		adda	#'0-FONT_FIRST
		sta	VDP_DATA
		lda	,X+
		anda	#$0F
		adda	#'0-FONT_FIRST
		sta	VDP_DATA
		decb
		bne	1B
		ldd	#NAMES+21
		lbsr	vdp_wr
		lda	lives
		adda	#'0-FONT_FIRST
		sta	VDP_DATA
		ldd	#NAMES+29
		lbsr	vdp_wr
		clra
		sta	VDP_DATA
*		(segue em put_level)

* put_level: escreve o número da fase (level+1) com dois dígitos na VRAM, no
* endereço já definido
put_level	clra
		ldb	level
		addd	#1			; 1..256, sem overflow de 8 bits
		cmpd	#99
		bls	2F
		ldd	#99
2
		ldx	#10
		lbsr	status_digit
		ldx	#1
		lbra	status_digit

* D = resto; X = divisor decimal. Dois dígitos (01..33 no jogo; satura em 99).
status_digit	stx	tmp
		clr	cnt
1		cmpd	tmp
		blo	2F
		subd	tmp
		inc	cnt
		bra	1B
2		pshs	a
		lda	cnt
		adda	#'0-FONT_FIRST
		sta	VDP_DATA
		puls	a
		rts

* load_level: copia o desenho da fase (level mod NUM_LEVELS) e conta os tijolos
load_level	lda level
                cmpa #NUM_LEVELS
                lbeq boss_init
                anda #31
                lsla
                ldx #LEVELS
                ldx A,X
                ldu #ARMOR
                lbsr level_unpack
                clr hitcnt
                clr bricks_left
                ldx #BRICKS
                ldu #GOLD
                ldb #20
1               lda ,U+
                coma
                anda ,X+
2               lsla
                bcc 3F
                inc bricks_left
3               tsta
                bne 2B
                decb
                bne 1B
                rts

* ROM RLE -> ARMOR[20], GOLD[20], BRICKS[20]; leave all other RAM alone.
level_unpack    ldb ,X+
                beq 9F
                bmi 2F
1               lda ,X+
                bsr level_store
                decb
                bne 1B
                bra level_unpack
2               subb #$7E
                lda ,X+
3               bsr level_store
                decb
                bne 3B
                bra level_unpack
9               rts
level_store     sta ,U+
                cmpu #GOLD+20
                bne 1F
                ldu #BRICKS
1               rts

* draw_bricks: desenha as 6 linhas de tijolos (linhas de tela 3..8)
draw_bricks	lda	level
		cmpa	#NUM_LEVELS
		lbeq	boss_draw
		clr	cnt
1		lda	cnt
		adda	#3
		ldb	#32
		mul
		addd	#NAMES+1
		lbsr	vdp_wr
		ldx	#BRICKS
		lda	cnt
		lsla
		ldd	A,X
		std	tmp			; máscara da linha
		ldx	#ARMOR
		lda	cnt
		lsla
		ldd	A,X
		std	tmp2
		ldx	#GOLD
		lda	cnt
		lsla
		ldd	A,X
		std	brick_gold
		lda	cnt
		cmpa	#6
		blo	6F
		suba	#6
6		lsla
		adda	#T_BRICK
		sta	brick_color
		ldb	#15
2		lsl	brick_gold+1
		rol	brick_gold
		pshs	cc
		lsl	tmp2+1
		rol	tmp2
		pshs	cc
		lsl	tmp+1
		rol	tmp
		bcc	3F
		lda	1,S
		bita	#1
		beq	7F
		lda	#86
		bra	5F
7		lda	,S
		bita	#1
		beq	6F
		lda	#84
		bra	5F
6		lda	brick_color
5		sta	VDP_DATA
		inca
		nop
		sta	VDP_DATA
		bra	4F
3		clra
		sta	VDP_DATA
		nop
		nop
		sta	VDP_DATA
4		leas	2,S
		decb
		bne	2B
		inc	cnt
		lda	cnt
		cmpa	#BRICK_ROWS
		lbne	1B
		rts

* serve: bola presa no centro da raquete
serve		clr	sticky
		clr	laser
		lda	level
		cmpa	#NUM_LEVELS
		bne	8F
		inc	laser
8
		clr	shot_active
		clr	power_kind
		clr	wide
		clr	slow
		lda	#112
		sta	paddle_x
		clr	ball_state
		clr	serve_clock
		clr	extra_balls
		bsr	stick_ball
		ldx	#msg_stage		; "FASE 01" no meio da tela; como lançar já
		ldd	#NAMES+MSG_ROW*32+12	; aparece na linha de baixo
		lbsr	print_at
		lbra	put_level

stick_ball	lda	wide
		lsra
		adda	paddle_x
		adda	#13
		clrb
		std	ball_x
		lda	#PADDLE_Y-6
		std	ball_y
		rts

* game_sprites: cápsula e tiro (rebatedor e bolas são gravados por put_game_sat)
game_sprites	ldu	#GAME_SAT
		tst	power_kind
		beq	2F
		lda	power_y
		deca
		sta	,U+
		lda	power_x
		sta	,U+
		lda	power_kind
		lsla
		lsla
		adda	#12
		sta	,U+
		ldx	#capsule_colors-1
		ldb	power_kind
		lda	B,X
		sta	,U+
2		tst	shot_active
		beq	3F
		lda	shot_y
		deca
		sta	,U+
		lda	shot_x
		sta	,U+
		lda	#PAT_SHOT
		sta	,U+
		lda	#C_LRED
		sta	,U+
3		lda	#$D0
		sta	,U
		rts
* cores das cápsulas E S P C B L D, como no Arkanoid, e do projétil do chefão
capsule_colors	fcb	C_LBLUE,C_DYELLOW,C_GRAY,C_LGREEN,C_MAGENTA,C_MRED,C_CYAN,C_LRED

* ---------------------------------------------------------------------------
*  game_step: um passo de 1/60 s
* ---------------------------------------------------------------------------
game_step	lbsr	power_step
		lbsr	boss_step
		lbsr	gate_step
		tst	bricks_left
		lbeq	step_done
		lbsr	laser_step
		tst	bricks_left
		lbeq	step_done
		lda	keys			; raquete
		bita	#K_LEFT
		beq	1F
		ldb	paddle_x
		subb	#PADDLE_STEP
		cmpb	#FIELD_L
		bhs	2F
		ldb	#FIELD_L
2		stb	paddle_x
1		lda	keys
		bita	#K_RIGHT
		beq	1F
		lbsr	paddle_limit
		stb	tmp
		ldb	paddle_x
		addb	#PADDLE_STEP
		cmpb	tmp
		bls	2F
		ldb	tmp
2		stb	paddle_x
1		tst	ball_state
		beq	4F
		lbsr	ball_move		; bola principal; C = 1 se caiu
		bcc	3F
		lbsr	primary_lost
3		lbra	multi_step		; bolas extras da cápsula D
4		lbsr	stick_ball
		lda	keys_new
		bita	#K_FIRE
		bne	8F
		inc	serve_clock		; sem ESPAÇO, a bola sai sozinha
		lda	serve_clock
		cmpa	#AUTO_LAUNCH
		blo	9F
8		lbsr	launch_ball
9
step_done	clr	keys_new		; o lançamento só vale num passo
		rts

* launch_ball: solta a bola presa (ESPAÇO, tempo esgotado ou cápsula D)
launch_ball	inc	ball_state
		lbsr	launch_velocity
		std	ball_dx
		ldd	#0
		subd	speed
		std	ball_dy
		ldx	#msg_blank		; apaga "FASE 01"
		ldd	#NAMES+MSG_ROW*32
		lbra	print_centered

ball_move	* --- eixo X
		ldd	ball_dx
		lbsr	slow_delta
		addd	ball_x
		std	ball_x
		cmpa	#FIELD_L
		bhs	1F
		lda	#FIELD_L
		clrb
		std	ball_x
		bra	2F
1		cmpa	#FIELD_R-6
		bls	3F
		lda	#FIELD_R-6
		clrb
		std	ball_x
2		ldd	#0			; inverte dx
		subd	ball_dx
		std	ball_dx
		bra	4F			; parede já resolveu X; evita inverter duas vezes
3		lbsr	brick_hit
		bcc	4F
		ldd	#0
		subd	ball_dx
		std	ball_dx
		ldd	ball_dx
		lbsr	slow_delta
		addd	ball_x
		std	ball_x
4		* --- eixo Y
		ldd	ball_dy
		lbsr	slow_delta
		addd	ball_y
		std	ball_y
		cmpa	#FIELD_T
		bhs	5F
		lda	#FIELD_T
		clrb
		std	ball_y
		ldd	#0
		subd	ball_dy
		std	ball_dy
5		lbsr	brick_hit
		bcc	6F
		ldd	#0
		subd	ball_dy
		std	ball_dy
		ldd	ball_dy
		lbsr	slow_delta
		addd	ball_y
		std	ball_y
6		* --- raquete
		tst	ball_dy
		bmi	8F			; subindo
		lda	ball_y
		adda	#6
		cmpa	#PADDLE_Y
		blo	8F
		cmpa	#PADDLE_Y+6
		bhi	7F			; passou da raquete
		lda	ball_x			; ball_x+6 > paddle_x e ball_x < paddle_x+32
		adda	#6
		cmpa	paddle_x
		bls	8F
		lda	paddle_x
		adda	#32
		adda	wide
		cmpa	ball_x
		bls	8F
		* rebate: ângulo pela posição (0..37 -> zona 0..7)
		lda	ball_x
		adda	#3
		suba	paddle_x
		tst	wide
		beq	3F
		suba	#8
3		cmpa	#128
		blo	1F
		clra
1		lsra
		lsra
		cmpa	#7
		bls	2F
		lda	#7
2		lsla
		ldx	#bounce_dx
		ldd	A,X
		std	ball_dx
		ldd	#0
		subd	speed
		std	ball_dy
		lda	#PADDLE_Y-6
		clrb
		std	ball_y
		tst	sticky
		beq	8F
		clr	ball_state
		clr	serve_clock
		lbsr	stick_ball
		andcc	#$FE
		rts
7		lda	ball_y			; caiu? (quem chamou decide: vida ou bola extra)
		cmpa	#196
		blo	8F
		orcc	#$01
		rts
8		andcc	#$FE
		rts

* ângulos do rebote (dx 8.8 por zona); com SPEED_START = $0200 a proporção
* dx/dy é a mesma da versão 1.4, que começava em $0180
bounce_dx	fdb	-$0255,-$01AB,-$0100,-$0055,$0055,$0100,$01AB,$0255

* brick_hit: testa o centro da bola; se há tijolo, remove, pontua e volta com C=1
brick_hit	lda	level
		cmpa	#NUM_LEVELS
		lbeq	boss_hit
		lda	ball_y
		adda	#3
		suba	#BRICK_Y
		lblo	9F
		lsra
		lsra
		lsra				; linha 0..
		cmpa	#BRICK_ROWS
		lbhs	9F
		sta	tmp2			; linha
		lda	ball_x
		adda	#3
		suba	#FIELD_L
		lblo	9F
		lsra
		lsra
		lsra
		lsra				; coluna 0..14
		cmpa	#15
		lbhs	9F
		sta	tmp2+1			; coluna
		lsla				; máscara do bit = $8000 >> coluna
		ldx	#mask_tab
		ldd	A,X
		std	tmp
		ldx	#BRICKS
		lda	tmp2
		lsla
		leax	A,X
		ldd	,X
		anda	tmp
		bne	3F
		andb	tmp+1
		lbeq	9F
3               lda tmp2
                lsla
                ldu #GOLD
                leau A,U
                ldd ,U
                anda tmp
                bne 7F
                andb tmp+1
                bne 7F
* A was changed by the mask test; calculate the row again.
                lda tmp2
                lsla
                ldu #ARMOR
                leau A,U
                ldd ,U
                anda tmp
                bne 5F
                andb tmp+1
                beq 4F
5               ldd tmp
                coma
                comb
                anda ,U
                andb 1,U
                std ,U
                lbsr brick_crack
7               orcc #1
                rts
4		lbsr	power_spawn
		ldd	tmp			; remove o bit
		coma
		comb
		anda	,X
		andb	1,X
		std	,X
		dec	bricks_left
		* apaga na tela: NAMES + (3+linha)*32 + 1 + coluna*2
		lda	tmp2
		adda	#3
		ldb	#32
		mul
		addd	#NAMES+1
		addb	tmp2+1
		adca	#0
		addb	tmp2+1
		adca	#0
		lbsr	vdp_wr
		clra
		sta	VDP_DATA
		exg	a,a			; >= 8 ciclos entre escritas
		sta	VDP_DATA
		* pontos: 10 x (6 - linha), em BCD
		lda	tmp2
		cmpa	#6
		blo	6F
		suba	#6
6		sta	tmp2
		lda	#6
		suba	tmp2
		lsla
		lsla
		lsla
		lsla				; dezenas em BCD
		adda	score+2
		daa
		sta	score+2
		lda	score+1
		adca	#0
		daa
		sta	score+1
		lda	score
		adca	#0
		daa
		sta	score
		bcc	8F
		lda	#$99
		sta	score
		sta	score+1
		sta	score+2
8
		lda	dirty
		ora	#1
		sta	dirty
		orcc	#$01
		rts
9		andcc	#$FE
		rts

mask_tab	fdb	$8000,$4000,$2000,$1000,$0800,$0400,$0200,$0100
		fdb	$0080,$0040,$0020,$0010,$0008,$0004,$0002

* ===========================================================================
*  Dados
* ===========================================================================
		include	"breakout.inc"
		include	"boss.inc"
		include	"attract.inc"
		include	"assets.inc"

end_of_code
		assert	end_of_code<=$8000,"cartucho maior que 16 KB"
		end
