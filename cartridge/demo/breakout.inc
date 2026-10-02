* Extra game rules and battery-backed top ten (firmware v2.1).
* Repaint only the cracked brick; full ten-row redraw is a scene operation.
brick_crack    lda tmp2
               adda #3
               ldb #32
               mul
               addd #NAMES+1
               addb tmp2+1
               adca #0
               addb tmp2+1
               adca #0
               lbsr vdp_wr
               lda tmp2
               cmpa #6
               blo 1F
               suba #6
1              lsla
               adda #T_BRICK
               sta VDP_DATA
               inca
               nop
               sta VDP_DATA
               rts

slow_delta     tst slow
               beq 1F
               asra
               rorb
1              rts

* One capsule every fourth destroyed brick; stage offsets the E/S/V/C/B/L/D cycle.
* None while extra balls are in play (as in Arkanoid's Disruption).
* Preserve collision temporaries and X (the brick row pointer).
P_DISRUPT      equ 7                  ; cápsula D: três bolas
P_BOLT         equ 8                  ; projétil do chefão (usa a vaga da cápsula)
power_spawn    inc hitcnt
               lda hitcnt
               anda #3
               bne 9F
               tst power_kind
               bne 9F
               tst extra_balls
               bne 9F
               lda hitcnt
               lsra
               lsra
               adda level
1              cmpa #7
               blo 2F
               suba #7
               bra 1B
2              inca
               sta power_kind
               lda tmp2+1
               lsla
               lsla
               lsla
               lsla
               adda #FIELD_L+4
               sta power_x
               lda tmp2
               lsla
               lsla
               lsla
               adda #BRICK_Y
               sta power_y
               clr power_clock
9              rts

power_step     tst power_kind
               beq 9F
               lda power_kind
               cmpa #P_BOLT
               lbeq boss_bolt
               inc power_clock
               lda power_clock
               bita #1
               bne 9F
               inc power_y
               lda power_y
               cmpa #PADDLE_Y-11
               blo 9F
               cmpa #PADDLE_Y
               bhi 8F
               lda power_x
               adda #10
               cmpa paddle_x
               bls 9F
               lda paddle_x
               adda #32
               adda wide
               cmpa power_x
               bls 9F
               lda power_kind
               cmpa #1
               bne 1F
               lda #16
               sta wide
               lda paddle_x
               cmpa #FIELD_R-48
               bls 8F
               lda #FIELD_R-48
               sta paddle_x
               bra 8F
1              cmpa #2
               bne 2F
               lda #1
               sta slow
               bra 8F
2              cmpa #4
               beq power_catch
               cmpa #5
               lbeq power_gate
               cmpa #6
               beq power_laser
               cmpa #P_DISRUPT
               beq power_disrupt
               lda lives
               cmpa #9
               bhs 8F
               inc lives
               inc dirty
8              clr power_kind
9              rts

power_catch    lda #1
               sta sticky
               clr power_kind
               rts
power_laser    lda #1
               sta laser
               clr power_kind
               rts

* Cápsula D (Disruption do Arkanoid): a bola vira três. A vida só se perde
* quando cai a última; com mais de uma bola não caem cápsulas, e o C (prender
* a bola) é cancelado.
power_disrupt  clr power_kind
               clr sticky
               tst ball_state
               bne 1F
               lbsr launch_ball        ; bola presa: sai antes de dividir
1              ldx #BALL2
               ldd #-$01AB
               bsr split_ball
               ldx #BALL3
               ldd #$01AB
               bsr split_ball
               lda #3
               sta extra_balls
               rts
* split_ball: bola extra em X, na posição da principal, com dx = D, subindo
split_ball     std 4,X
               ldd ball_x
               std ,X
               ldd ball_y
               std 2,X
               ldd #0
               subd speed
               std 6,X
               rts

* multi_step: move as bolas extras com a mesma física da principal, trocando
* cada uma de lugar com ball_x..ball_dy durante o ball_move
multi_step     ldx #BALL2
               lda #1
               bsr multi_one
               ldx #BALL3
               lda #2
multi_one      bita extra_balls        ; A = bit da bola, X = seus 8 bytes
               beq 9F
               pshs a,x
               bsr ball_swap
               lbsr ball_move
               ldx 1,S
               pshs cc
               bsr ball_swap
               puls cc
               puls a,x
               bcc 9F
               coma                    ; caiu: só sai do jogo
               anda extra_balls
               sta extra_balls
9              rts
* ball_swap: troca os 8 bytes em X com ball_x..ball_dy
ball_swap      ldu #ball_x
               ldb #8
1              lda ,X
               pshs a
               lda ,U
               sta ,X+
               puls a
               sta ,U+
               decb
               bne 1B
               rts

* primary_lost: a bola principal caiu. Com uma extra em jogo, ela vira a
* principal; se era a última, perde-se uma vida.
primary_lost   lda extra_balls
               beq 3F
               ldx #BALL2
               ldb #$FE
               bita #1
               bne 1F
               ldx #BALL3
               ldb #$FD
1              andb extra_balls
               stb extra_balls
               ldu #ball_x
               ldb #8
2              lda ,X+
               sta ,U+
               decb
               bne 2B
               rts
3              dec lives
               lda dirty
               ora #2
               sta dirty
               tst lives
               beq 4F
               lbsr serve
4              rts
power_gate     lda #1
               sta gate
               clr power_kind
               ldd #NAMES+21*32+31
               lbsr vdp_wr
               lda #'>-FONT_FIRST
               sta VDP_DATA
               ldd #NAMES+22*32+31
               lbsr vdp_wr
               clra
               sta VDP_DATA
               rts
* Com a saída aberta o rebatedor atravessa a parede direita e a fase só acaba
* quando ao menos 1/6 dele já saiu da tela: 6 de 32 pixels (x >= 230) ou 8 de
* 48 no grande (x >= 216).
gate_step      tst gate
               beq 1F
               lbsr paddle_limit
               cmpb paddle_x
               bhi 1F
               clr bricks_left
1              rts

* gate_slide: se a fase acabou com o rebatedor na saída, ele continua andando
* para a direita, sem a bola, até sair da tela por inteiro.
gate_slide     tst gate
               beq 9F
               lbsr paddle_limit
               cmpb paddle_x
               bhi 9F
               lda #200               ; bolas, cápsula e tiro saem de cena
               sta ball_y
               clr extra_balls
               clr power_kind
               clr shot_active
               lbsr game_sprites
1              lbsr wait_frame
               lbsr put_game_sat
               ldb ticks
2              lda paddle_x
               adda #PADDLE_STEP
               bcs 3F                 ; passaria de 255: já saiu
               sta paddle_x
               decb
               bne 2B
               bra 1B
3              lbra hide_sprites
9              rts

* paddle_limit: B = maior paddle_x (sem a saída, encostado na parede)
paddle_limit   ldb #FIELD_R-32
               tst gate
               beq 1F
               ldb #256-32+6          ; normal: 6 pixels fora da tela
               tst wide
               beq 2F
               ldb #256-48+8+16       ; grande: 8 fora (o subb abaixo tira o wide)
1              subb wide
2              rts

* One projectile at a time; SPACE fires while the ball is in play.
laser_step     tst shot_active
               bne laser_move
               tst laser
               beq 9F
               tst ball_state
               beq 9F
               lda keys
               bita #K_FIRE
               beq 9F
               lda wide               ; centro do rebatedor, normal ou grande
               lsra
               adda paddle_x
               adda #13
               sta shot_x
               lda #PADDLE_Y-10
               sta shot_y
               inc shot_active
9              rts
laser_move     lda shot_y
               suba #4
               sta shot_y
               cmpa #FIELD_T
               bls laser_end
               ldd ball_x
               pshs d
               ldd ball_y
               pshs d
               lda shot_x
               clrb
               std ball_x
               lda shot_y
               std ball_y
               lbsr brick_hit
               puls d
               std ball_y
               puls d
               std ball_x
               bcc 9F
laser_end      clr shot_active
9              rts

campaign_done  lbsr hide_sprites
               ldd #NAMES+3*32+1
               std tmp
               lda #20
               sta cnt
1              ldd tmp
               lbsr vdp_wr
               clra
               ldy #30
               lbsr vdp_fill
               ldd tmp
               addd #32
               std tmp
               dec cnt
               bne 1B
               ldx #msg_conquered
               ldd #NAMES+12*32
               lbsr print_centered
               ldx #msg_victory
               ldd #NAMES+15*32
               lbsr print_centered
               ldb #240
               lbsr pause_frames
               lbra hs_game_over

* Format: "B2", 16-bit sum, 10 x (3 BCD score bytes + 3 ASCII initials).
* Invalidate before updating, commit signature last. Invalid data resets safely.
hs_sum         ldx #HS_DATA
               ldd #0
1              addb ,X+
               adca #0
               cmpx #HS_END
               blo 1B
               rts
hs_commit      lbsr hs_sum
               std HS+2
               ldd #"B2"
               std HS
               rts
hs_init        ldd HS
               cmpd #"B2"
               bne hs_clear
               lbsr hs_sum
               cmpd HS+2
               bne hs_clear
               rts
hs_clear       clr HS
               ldx #HS_DATA
1              clr ,X+
               clr ,X+
               clr ,X+
               lda #'A
               sta ,X+
               sta ,X+
               sta ,X+
               cmpx #HS_END
               blo 1B
               bra hs_commit

* Stable descending order: ties follow existing entries. Zero is not a record.
* hs_pos = 0..9 or 10 if the score did not qualify.
hs_insert      lda #10
               sta hs_pos
               lda score
               ora score+1
               ora score+2
               beq 9F
               ldx #HS_DATA
               clrb
1              lda score
               cmpa ,X
               bhi 3F
               blo 2F
               lda score+1
               cmpa 1,X
               bhi 3F
               blo 2F
               lda score+2
               cmpa 2,X
               bhi 3F
2              leax 6,X
               incb
               cmpb #10
               blo 1B
9              rts
3              stb hs_pos
               clr HS
               stx tmp
               ldx #HS_END-7
4              cmpx tmp
               blo 5F
               lda ,X
               sta 6,X
               leax -1,X
               bra 4B
5              ldx tmp
               ldd score
               std ,X
               lda score+2
               sta 2,X
               lda #$20               ; iniciais em branco até serem digitadas
               sta 3,X
               sta 4,X
               sta 5,X
               lbra hs_commit

* Entrada das iniciais: a letra em edição pisca com um bloco amarelo.
* Digitar avança o cursor; na terceira posição a letra é trocada no lugar.
hs_game_over   lbsr hs_insert
               lda hs_pos
               cmpa #10
               lbhs hs_show
               clr hs_letter
               clr alpha_last
               lbsr hs_draw
               ldx #hs_edit_msg
               ldd #NAMES+18*32
               lbsr print_centered
               ldx #hs_clear_msg
               ldd #NAMES+20*32
               lbsr print_centered
               ldx #hs_confirm_msg
               ldd #NAMES+22*32
               lbsr print_centered
               clr hs_blink            ; cursor aceso
2              lbsr wait_frame
               lbsr hs_cursor
               lbsr read_keys
               lda keys_new
               bita #K_EXIT
               lbne exit_to_titler
               lbsr read_alpha
               tsta
               lbeq 5F
               pshs a
               lbsr hs_initial_ptr
               puls a
               clr HS
               sta ,X
               lbsr hs_commit
               lbsr hs_letter_cell     ; a letra digitada no lugar do cursor
               lda hs_letter
               cmpa #2
               bhs 3F
               inc hs_letter
               clr hs_blink            ; cursor aceso na próxima posição
               lbra 2B
3              lda #16                 ; última posição: a letra aparece primeiro
               sta hs_blink
               lbra 2B
5              lda keys_new
               bita #K_BACK
               beq 6F
               lbsr hs_backspace
               lbra 2B
6              lda keys_new
               bita #K_PAUSE
               lbne hs_show
               bita #K_FIRE
               lbeq 2B
               lda hs_letter
               cmpa #2
               lbhs hs_show
               lbsr hs_letter_cell
               inc hs_letter
               clr hs_blink
               lbra 2B

* hs_backspace (CLEAR): apaga a letra sob o cursor; se ela já está vazia,
* volta uma posição e apaga a anterior. Grava na SRAM como a digitação.
hs_backspace   lbsr hs_initial_ptr
               lda ,X
               cmpa #$20
               bne 1F
               lda hs_letter
               beq 9F                 ; primeira posição já vazia
               lbsr hs_letter_cell    ; a posição deixada fica sem o cursor
               dec hs_letter
               lbsr hs_initial_ptr
1              clr HS
               lda #$20
               sta ,X
               lbsr hs_commit
               clr hs_blink           ; cursor aceso
               lbra hs_letter_cell
9              rts

* hs_cursor: alterna bloco e letra a cada 16 passos (~2 piscadas por segundo)
hs_cursor      lda hs_blink
               adda ticks
               sta hs_blink
               bita #16
               bne hs_letter_cell
               bsr hs_cell_addr
               lda #T_CURSOR
               sta VDP_DATA
               rts
hs_letter_cell bsr hs_cell_addr
               lbsr hs_initial_ptr
               lda ,X
               suba #FONT_FIRST
               sta VDP_DATA
               rts
* hs_cell_addr: endereço de escrita da inicial hs_letter da linha hs_pos
hs_cell_addr   lda hs_pos
               adda #HS_ROW0
               ldb #32
               mul
               addd #NAMES+HS_COL+4
               addb hs_letter
               adca #0
               lbra vdp_wr

* Keyboard letters, physical matrix independent of SHIFT/CAPS. One event per press.
read_alpha     ldx #alpha_rows
               ldu #alpha_chars
               lda #7
               sta cnt
1              lda ,X+
               sta KEYBOARD
               lda KEYBOARD
               coma
               sta tmp
               ldb #8
2              lda ,U+
               lsr tmp
               bcc 3F
               tsta
               bne 4F
3              decb
               bne 2B
               dec cnt
               bne 1B
               clr alpha_last
               clra
               rts
4              cmpa alpha_last
               beq 5F
               sta alpha_last
               rts
5              clra
               rts
alpha_rows     fcb $FE,$FD,$FB,$F7,$EF,$DF,$BF
alpha_chars    fcb 0,'Q,'A,0,0,'U,'J,'N
               fcb 0,'W,'S,0,0,'I,'K,'M
               fcb 0,'E,'D,0,0,'O,'L,0
               fcb 0,'R,'F,0,0,'P,0,0
               fcb 0,'T,'G,0,0,0,0,0
               fcb 0,'Y,'H,0,0,0,0,0
               fcb 'Z,'X,'C,0,0,0,'V,'B
hs_initial_ptr lda hs_pos
               ldb #6
               mul
               ldx #HS_DATA+3
               abx
               ldb hs_letter
               abx
               rts
hs_show        lbsr hs_draw
               ldx #hs_return_msg
               ldd #NAMES+21*32
               lbsr print_centered
1              lbsr wait_frame
               lbsr read_keys
               lda keys_new
               bita #K_EXIT
               lbne exit_to_titler
               bita #K_VIDEO
               beq 2F
               lbsr toggle_video
2              lda keys_new
               bita #K_FIRE+K_PAUSE
               beq 1B
               rts

* Tabela centralizada: 16 colunas a partir de HS_COL, "NN  ABC   000000"
* sob o cabeçalho "    NOME  PONTOS".
HS_COL         equ 8
HS_ROW0        equ 5
hs_draw        lbsr screen_off
               lbsr hide_sprites
               ldd #NAMES
               lbsr vdp_wr
               clra
               ldy #768
               lbsr vdp_fill
               ldx #hs_title
               ldd #NAMES+32
               lbsr print_centered
               ldx #hs_header
               ldd #NAMES+3*32+HS_COL
               lbsr print_at
               clr hs_row
               ldu #HS_DATA
1              lda hs_row
               adda #HS_ROW0
               ldb #32
               mul
               addd #NAMES+HS_COL
               lbsr vdp_wr
               lda #'0-FONT_FIRST      ; posição 01..10
               ldb hs_row
               cmpb #9
               bne 2F
               inca
2              sta VDP_DATA
               lda hs_row
               inca
               cmpa #10
               blo 3F
               clra
3              adda #'0-FONT_FIRST
               sta VDP_DATA
               ldb #2
               bsr hs_spaces
               lda 3,U
               suba #FONT_FIRST
               sta VDP_DATA
               lda 4,U
               suba #FONT_FIRST
               sta VDP_DATA
               lda 5,U
               suba #FONT_FIRST
               sta VDP_DATA
               ldb #3
               bsr hs_spaces
               ldb #3
4              lda ,U
               lsra
               lsra
               lsra
               lsra
               adda #'0-FONT_FIRST
               sta VDP_DATA
               lda ,U+
               anda #15
               adda #'0-FONT_FIRST
               sta VDP_DATA
               decb
               bne 4B
               leau 3,U
               inc hs_row
               lda hs_row
               cmpa #10
               blo 1B
               lbra screen_on
* hs_spaces: B espaços (tile 0) na VRAM, 10 ciclos entre escritas
hs_spaces      clra
1              sta VDP_DATA
               decb
               bne 1B
               rts
