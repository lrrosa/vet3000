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
2               ldd #$0100
                rts
1               ldd #-$0100
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

* A CPU corre até onde a bola vai chegar (attract_target) em vez de seguir a
* bola de lado, e rebate 8 pixels fora do centro (o lado muda com os tijolos
* quebrados) para variar o ângulo.
attract_update  lda keys
                sta attract_keys
                ldd attract_timer
                subb ticks
                sbca #0
                std attract_timer
                bls 8F
                lbsr attract_target     ; A = x do centro da bola no rebatedor
                ldb hitcnt
                andb #1
                beq 1F
                suba #16
1               adda #8
                sta tmp2                ; centro desejado do rebatedor
                lda wide
                lsra
                adda paddle_x
                adda #16
                sta tmp                 ; centro atual
                clrb
                lda tmp2
                suba tmp
                bcs 2F
                cmpa #PADDLE_STEP
                blo 3F
                ldb #K_RIGHT
                bra 3F
2               nega
                cmpa #PADDLE_STEP
                blo 3F
                ldb #K_LEFT
3               orb #K_FIRE
                stb keys
                lda #K_FIRE
                sta keys_new
                clra
                rts
8               lda #1
                rts

* attract_target: A = x do centro da bola quando ela chegar à altura do
* rebatedor, refletido nas paredes. Subindo, supõe a volta pelo teto.
* Deslocamento = distância vertical * |dx| / |dy| (dx e dy divididos por 4).
CPU_REST        equ PADDLE_Y-6          ; ball_y com a bola encostada no rebatedor
CPU_W           equ FIELD_R-FIELD_L-6   ; faixa do centro da bola: FIELD_L+3..+CPU_W
attract_target  tst ball_state
                beq 9F
                ldd ball_dy
                bpl 1F
                coma
                comb
                addd #1
                bsr quarter
                clra
                ldb ball_y              ; subindo: até o teto e de volta
                addd #CPU_REST-2*FIELD_T
                bra 3F
1               bsr quarter
                clra
                ldb #CPU_REST
                subb ball_y
                bcc 3F
                clrb                    ; já abaixo do rebatedor
3               std tmp2                ; distância vertical (pixels)
                tst tmp+1
                beq 9F
                ldd ball_dx
                bpl 4F
                coma
                comb
                addd #1
4               lsra
                rorb
                lsra
                rorb
                stb tmp                 ; |dx|/4
                lda tmp2+1              ; distância * |dx|/4 (distância < 512)
                mul
                pshs d
                lda tmp2
                ldb tmp
                mul
                addb ,S
                stb ,S
                puls d
                bsr div16_8             ; / (|dy|/4)
                tst ball_dx
                bpl 5F
                coma
                comb
                addd #1
5               addb ball_x
                adca #0
                subd #FIELD_L           ; posição dentro da faixa, com sinal
6               tsta
                bpl 7F
                addd #2*CPU_W
                bra 6B
7               cmpd #2*CPU_W
                blo 8F
                subd #2*CPU_W
                bra 7B
8               cmpd #CPU_W
                bls 2F
                pshs d                  ; reflexo na parede direita
                ldd #2*CPU_W
                subd ,S++
2               addb #FIELD_L+3
                tfr b,a
                rts
9               lda ball_x              ; bola presa ou parada: segue a bola
                adda #3
                rts
* quarter: tmp+1 = D/4 (|dy| até $3FF)
quarter         lsra
                rorb
                lsra
                rorb
                stb tmp+1
                rts
* div16_8: D = D / tmp+1 (quociente de 16 bits, resto descartado)
div16_8         pshs d
                clra
                ldb #16
                stb cnt
1               lsl 1,S
                rol ,S
                rola
                bcs 2F
                cmpa tmp+1
                blo 3F
2               suba tmp+1
                inc 1,S
3               dec cnt
                bne 1B
                puls d,pc

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
                ldx #hs_play_msg
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
