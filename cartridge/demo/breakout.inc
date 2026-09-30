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

* One capsule every fourth destroyed brick; stage offsets the E/S/V/C/B/L cycle.
* Preserve collision temporaries and X (the brick row pointer).
power_spawn    inc hitcnt
               lda hitcnt
               anda #3
               bne 9F
               tst power_kind
               bne 9F
               lda hitcnt
               lsra
               lsra
               adda level
1              cmpa #6
               blo 2F
               suba #6
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
               cmpa #7
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
               beq power_gate
               cmpa #6
               beq power_laser
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
gate_step      tst gate
               beq 1F
               lda paddle_x
               adda wide
               cmpa #FIELD_R-32
               blo 1F
               clr bricks_left
1              rts

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
               lda paddle_x
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
               ldd #NAMES+12*32+6
               lbsr print_at
               ldx #msg_victory
               ldd #NAMES+15*32+6
               lbsr print_at
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
               lda #'A
               sta 3,X
               sta 4,X
               sta 5,X
               lbra hs_commit

hs_game_over   lbsr hs_insert
               lda hs_pos
               cmpa #10
               lbhs hs_show
               clr hs_letter
               clr alpha_last
               lbsr hs_draw
1              lbsr hs_prompt
2              lbsr wait_frame
               lbsr read_keys
               lda keys_new
               bita #K_EXIT
               lbne exit_to_titler
               lbsr read_alpha
               tsta
               beq 5F
               pshs a
               lbsr hs_initial_ptr
               puls a
               clr HS
               sta ,X
               lbsr hs_commit
               lda hs_letter
               cmpa #2
               bhs 3F
               inc hs_letter
3              lbsr hs_draw
               bra 1B
5              lda keys_new
               bita #K_PAUSE
               lbne hs_show
               bita #K_FIRE
               beq 2B
               lda hs_letter
               cmpa #2
               lbhs hs_show
               inc hs_letter
               bra 1B

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
hs_prompt      ldx #hs_edit_msg
               ldd #NAMES+19*32+2
               lbsr print_at
               ldx #hs_confirm_msg
               ldd #NAMES+21*32+2
               lbsr print_at
               ldd #NAMES+20*32
               lbsr vdp_wr
               clra
               ldy #32
               lbsr vdp_fill
               lda hs_letter
               adda #'1
               suba #FONT_FIRST
               pshs a
               ldd #NAMES+20*32+15
               lbsr vdp_wr
               puls a
               sta VDP_DATA
               rts
hs_show        lbsr hs_draw
               ldx #hs_return_msg
               ldd #NAMES+21*32+4
               lbsr print_at
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
hs_draw        lbsr screen_off
               lbsr hide_sprites
               ldd #NAMES
               lbsr vdp_wr
               clra
               ldy #768
               lbsr vdp_fill
               ldx #hs_title
               ldd #NAMES+32+5
               lbsr print_at
               ldx #hs_header
               ldd #NAMES+3*32+5
               lbsr print_at
               clr hs_row
               ldu #HS_DATA
1              lda hs_row
               adda #5
               ldb #32
               mul
               addd #NAMES+5
               lbsr vdp_wr
               lda #'0-FONT_FIRST
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
               clra
               nop
               sta VDP_DATA
               lda 3,U
               suba #FONT_FIRST
               sta VDP_DATA
               lda 4,U
               suba #FONT_FIRST
               sta VDP_DATA
               lda 5,U
               suba #FONT_FIRST
               sta VDP_DATA
               clra
               nop
               sta VDP_DATA
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
hs_title       fcc "QUEBRA-TIJOLO: TOP 10",0
hs_header      fcc "   NOME  PONTOS",0
hs_edit_msg    fcc "A-Z: DIGITE AS 3 INICIAIS",0
hs_confirm_msg fcc "RETURN: CONFIRMA O NOME",0
hs_return_msg  fcc "ESPACO: VOLTAR",0
power_help     fcc "Z/X: MOVE  ESPACO: LANCA/TIRO",0
msg_pause      fcc "    PAUSA    ",0
msg_victory    fcc "CAMPANHA COMPLETA!",0
msg_conquered  fcc "32 FASES + GUARDIAO",0
