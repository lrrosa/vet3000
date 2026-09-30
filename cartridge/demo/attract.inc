* Attract cycle: complete scroller, three 10-second CPU rounds, 8-second ranking.
* No CPU score is ever submitted to the high-score table.
launch_velocity lda launch_dir
                eora #1
                sta launch_dir
                lda keys
                bita #K_LEFT
                bne 1F
                bita #K_RIGHT
                bne 2F
                tst launch_dir
                bne 1F
2               ldd #$00C0
                rts
1               ldd #-$00C0
                rts

attract_pick    lda attract_rng
                bne 1F
                lda #$A7
1               lsra
                bcc 2F
                eora #$B8
2               sta attract_rng
                anda #31
                cmpa attract_prev
                beq attract_pick
                sta attract_prev
                sta level
                ldd #600
                std attract_timer
                rts

attract_update  lda keys
                sta attract_keys
                ldd attract_timer
                subb ticks
                sbca #0
                std attract_timer
                bls 8F
                lda wide
                lsra
                adda paddle_x
                adda #16
                sta tmp
                lda ball_x
                adda #3
                clrb
                cmpa tmp
                blo 1F
                suba tmp
                cmpa #3
                blo 2F
                ldb #K_RIGHT
                bra 2F
1               ldb #K_LEFT
2               orb #K_FIRE
                stb keys
                lda #K_FIRE
                sta keys_new
                clra
                rts
8               lda #1
                rts

attract_start   clr attract_mode
                lbra game
attract_next    dec attract_count
                beq attract_scores
                lbsr attract_pick
                lda #4
                sta lives
                lbra new_level

attract_scores  lda #2
                sta attract_mode
                lbsr hs_draw
                ldx #attract_help
                ldd #NAMES+21*32
                lbsr print_centered
                ldd #480
                std attract_timer
1               lbsr wait_frame
                lbsr read_keys
                lda keys_new
                bita #K_EXIT
                lbne exit_to_titler
                bita #K_FIRE
                bne attract_start
                bita #K_VIDEO
                beq 2F
                lbsr toggle_video
2               ldd attract_timer
                subb ticks
                sbca #0
                std attract_timer
                bhi 1B
                clr attract_mode
                rts
attract_help    fcc "DEMONSTRACAO - ESPACO: JOGAR",0
