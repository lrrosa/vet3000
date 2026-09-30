* GUARDIAO: final arena after 32 courts. 24 HP, moving mask and aimed bolts.
* Uses title scratch; boss_tick aliases the unused gold mask in this arena.
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
               rts

boss_draw      lda #8
               sta cnt
               clra
               ldb boss_col
               addd #NAMES+4*32-1
               std tmp
               ldx #boss_face
1              ldd tmp
               lbsr vdp_wr
               clra
               sta VDP_DATA
               ldb #8
2              lda ,X+
               tst boss_flash
               beq 3F
               cmpa #92
               blo 3F
               lda #95
3              sta VDP_DATA
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
1              clra
               cmpb bricks_left
               bhs 2F
               lda #T_BRICK
2              sta VDP_DATA
               incb
               cmpb #24
               blo 1B
               rts

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
1              inc boss_tick
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
               lda #7
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

boss_face      fcb 0,89,88,88,88,88,90,0
               fcb 89,88,88,88,88,88,88,90
               fcb 91,92,92,88,88,92,92,91
               fcb 91,92,92,88,88,92,92,91
               fcb 91,88,88,91,91,88,88,91
               fcb 91,88,93,93,94,94,88,91
               fcb 0,91,88,88,88,88,91,0
               fcb 0,0,91,91,91,91,0,0
msg_boss       fcc "GUARDIAO - ESPACO: LASER",0
