* GUARDIAO: final arena after 32 courts. 24 HP, moving face and aimed bolts.
* Uses title scratch; boss_tick aliases the unused gold mask in this arena.
* O rosto (boss_art.py) é um bitmap de 8x8 tiles próprios a partir de
* BOSS_T0, carregados nos bancos 0 e 1 (linhas 4-11 da tela) só nesta fase.
* Ao levar dano os olhos ficam brancos e, ao atirar, a boca se abre: os tiles
* dessas versões ficam BOSS_N posições depois dos normais.
boss_mouth     equ $5E                ; passos que a boca ainda fica aberta
BOSS_MOUTH_TIME equ 16
boss_init      ldx #ARMOR
               ldb #40
1              clr ,X+
               decb
               bne 1B
               ldx #BRICKS
               ldb #20
2              clr ,X+
               decb
               bne 2B
               lda #24
               sta bricks_left
               lda #12
               sta boss_col
               lda #1
               sta boss_dir
               clr boss_flash
               clr boss_tick
               clr hitcnt
               ldd #PAT+BOSS_T0*8      ; tiles do rosto nos bancos 0 e 1
               bsr boss_load_pat
               ldd #PAT+$0800+BOSS_T0*8
               bsr boss_load_pat
               ldd #COL+BOSS_T0*8
               bsr boss_load_col
               ldd #COL+$0800+BOSS_T0*8
boss_load_col  lbsr vdp_wr
               ldx #BOSS_COL
               lbra vdp_unrle
boss_load_pat  lbsr vdp_wr
               ldx #BOSS_PAT
               lbra vdp_unrle

boss_draw      lda #8
               sta cnt
               clra
               ldb boss_col
               addd #NAMES+4*32-1
               std tmp
               ldx #BOSS_MAP
1              ldd tmp
               lbsr vdp_wr
               clra
               sta VDP_DATA            ; coluna vazia: apaga o rastro ao andar
               ldb #8
2              lda ,X+
               bsr boss_tile
               sta VDP_DATA
               decb
               bne 2B
               clra
               sta VDP_DATA
               ldd tmp
               addd #32
               std tmp
               dec cnt
               bne 1B
boss_energy    ldd #NAMES+13*32+4
               lbsr vdp_wr
               ldb #0
1              lda #T_ENERGY_OFF
               cmpb bricks_left
               bhs 2F
               lda #T_ENERGY
2              sta VDP_DATA
               incb
               cmpb #24
               blo 1B
               rts

* boss_tile: A = tile do mapa; troca pelos olhos de dano ou pela boca aberta
boss_tile      tst boss_flash
               beq 1F
               cmpa #BOSS_EYE0
               blo 1F
               cmpa #BOSS_EYE_END
               bhs 1F
               adda #BOSS_N
               rts
1              tst boss_mouth
               beq 2F
               cmpa #BOSS_MOUTH0
               blo 2F
               cmpa #BOSS_MOUTH_END
               bhs 2F
               adda #BOSS_N
2              rts

boss_step      lda level
               cmpa #NUM_LEVELS
               bne 9F
               tst bricks_left
               beq 9F
               tst boss_flash
               beq 1F
               dec boss_flash
               bne 1F
               lbsr boss_draw
1              tst boss_mouth          ; a boca fecha depois do tiro
               beq 7F
               dec boss_mouth
               bne 7F
               lbsr boss_draw
7              inc boss_tick
               lda boss_tick
               bita #15
               bne 4F
               lda boss_col
               adda boss_dir
               sta boss_col
               cmpa #4
               beq 2F
               cmpa #20
               bne 3F
2              neg boss_dir
3              lbsr boss_draw
4              lda boss_tick
               bita #63
               bne 9F
               tst ball_state
               beq 9F
               tst power_kind
               bne 9F
               lda #P_BOLT
               sta power_kind
               lda boss_col
               lsla
               lsla
               lsla
               adda #29
               sta power_x
               clr boss_bolt_dx
               lda paddle_x
               adda #13
               cmpa power_x
               beq 5F
               blo 6F
               inc boss_bolt_dx
               bra 5F
6              dec boss_bolt_dx
5
               lda #96
               sta power_y
               lda #BOSS_MOUTH_TIME    ; abre a boca ao atirar
               sta boss_mouth
               lbsr boss_draw
9              rts

boss_bolt      lda power_x
               adda boss_bolt_dx
               sta power_x
               cmpa #FIELD_L
               blo 8F
               cmpa #FIELD_R-6
               bhi 8F
               lda power_y
               adda #2
               sta power_y
               cmpa #PADDLE_Y-8
               blo 9F
               cmpa #PADDLE_Y
               bhi 8F
               lda power_x
               adda #6
               cmpa paddle_x
               bls 9F
               lda paddle_x
               adda #32
               adda wide
               cmpa power_x
               bls 9F
               dec lives
               inc dirty
               lbsr serve
8              clr power_kind
9              rts

boss_hit       lda ball_y
               adda #3
               cmpa #32
               blo 9F
               cmpa #96
               bhs 9F
               lda ball_x
               adda #3
               lsra
               lsra
               lsra
               suba boss_col
               cmpa #8
               bhs 9F
               tst bricks_left
               beq 9F
               tst boss_flash
               bne 8F
               lda #8
               sta boss_flash
               dec bricks_left
               lda score+1
               adda #1
               daa
               sta score+1
               lda score
               adca #0
               daa
               sta score
               bcc 1F
               lda #$99
               sta score
               sta score+1
               sta score+2
1              inc dirty
               lbsr boss_draw
8              orcc #1
               rts
9              andcc #$FE
               rts

