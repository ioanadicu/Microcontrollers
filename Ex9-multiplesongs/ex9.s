; =============================================================================
; Exercise 7: Key Debouncing and Keyboard Scanning
; Maria-Ioana Dicu
; =============================================================================

ORG             0x0000_0000
j               initialisation

INCLUDE         Definitions.s
INCLUDE         DisplayOperations.s
INCLUDE         Keypad.s
INCLUDE         TrapHandler.s
INCLUDE         OS.s


; =============================================================================
; USER SECTION (Exercise 9 - Music Player)
; =============================================================================

ORG             0x0004_0000

user_code
    la      sp, user_stack_base
    j       START


; =============================================================================
; User strings / stack
; =============================================================================

timer_ticks     defw    0
                align

homeLine1       defb    "Pick a song:\0"
                align

homeLine2       defb    "1:Tune1 2:Tune2\0"
                align

playLine1       defb    "Playing...\0"
                align

user_stack      defs    128
user_stack_base align

INCLUDE         UserSpaceLib.s

; =============================================================================
; Music Player Virtual Machine (Interpreter)
; =============================================================================

START
menu_start
    ; Show homescreen and wait for keypad selection
    li      a7, ECALL_CLEAR_DISPLAY
    ecall
    la      a0, homeLine1
    li      a7, ECALL_PRINT_STRING
    ecall
    li      a7, ECALL_NEXT_LINE
    ecall
    la      a0, homeLine2
    li      a7, ECALL_PRINT_STRING
    ecall

wait_for_key
    li      a7, ECALL_GET_KEY
    ecall
    beqz    a0, wait_for_key

    li      t0, '1'
    beq     a0, t0, select_song1
    li      t0, '2'
    beq     a0, t0, select_song2
    j       menu_start

select_song1
    la      s0, tune1
    j       start_play

select_song2
    la      s0, tune2

start_play
    li      s1, BUZZER_BASE     ; s1 = memory address of our Verilog Buzzer
    ; Show playing line
    li      a7, ECALL_CLEAR_DISPLAY
    ecall
    la      a0, playLine1
    li      a7, ECALL_PRINT_STRING
    ecall

play_loop
    ; 2. Fetch Pitch (Byte 0) and Duration (Byte 1)
    lbu     t0, 0[s0]           
    
    ; 3. Check for End of Tune (0xFF / 255)
    li      t3, 255
    beq     t0, t3, end_song

    ; 4. Fetch Duration and convert to milliseconds
    lbu     t2, 1[s0]           
    li      t3, 100
    mul     t2, t2, t3          

    ; 5. Check for Rest (Pitch 0)
    beqz    t0, play_rest

    ; 6. Look up the base period from the LUT
    addi    t0, t0, -1          
    slli    t0, t0, 2           
    
    la      t4, note_lut        
    add     t4, t4, t0          
    lw      t6, 0[t4]           

    ; 7. Send to Hardware (via ECALL instead of direct store)
    mv      a0, t6              ; Put half-period in a0
    li      a7, ECALL_PLAY_NOTE ; Call OS to write to hardware
    ecall
    j       wait_duration

play_rest
    li      a0, 0               ; Period 0 = Silence
    li      a7, ECALL_PLAY_NOTE
    ecall

wait_duration
    ; 8. Delay for the note's duration
    mv      a0, t2              ; Pass duration (ms) to delay function
    call    delay_ms

    ; If delay aborted, return to menu
    li      t0, 0xFF
    beq     a0, t0, menu_start

    ; 9. Note Separator (Tiny gap of silence)
    li      a0, 0
    li      a7, ECALL_PLAY_NOTE
    ecall
    
    li      a0, 15              ; 15 ms articulation gap
    call    delay_ms

    li      t0, 0xFF
    beq     a0, t0, menu_start

    ; 10. Move pointer to next note pair and loop
    addi    s0, s0, 2           
    j       play_loop

end_song
    li      a0, 0               ; Ensure buzzer is off at the end
    li      a7, ECALL_PLAY_NOTE
    ecall
    j       menu_start          ; Return to homescreen after the song ends

; =============================================================================
; Helper: Delay in Milliseconds
; =============================================================================
; Input: a0 = milliseconds to delay
delay_ms
    beqz    a0, delay_done

    mv      t3, a0              ; t3 = remaining ms counter (preserve across ecalls)

delay_ms_loop
    la      t0, timer_ticks
    lw      t1, [t0]            ; Snapshot the current 1 ms tick

wait_tick
    lw      t2, [t0]
    beq     t2, t1, wait_tick   ; Wait for the next timer interrupt
    ; Also poll SW1 during each ms to allow stopping playback
    li      a7, ECALL_READ_BUTTONS
    ecall
    andi    a0, a0, BTTN1
    bnez    a0, delay_abort

    subi    t3, t3, 1
    bnez    t3, delay_ms_loop

delay_done
    li      a0, 0               ; Normal return value 0
    ret

delay_abort
    li      a0, 0               ; Silence buzzer immediately on stop
    li      a7, ECALL_PLAY_NOTE
    ecall

    li      a0, 0xFF            ; signal abort
    ret


; =============================================================================
; Look-Up Table (LUT): 1-based Major Scale Half-Periods
; =============================================================================
; Calculated for 40MHz clock. Middle C (Pitch 1) is ~1046 Hz for better piezo volume.
; Pitch 8 is exactly half the period of Pitch 1 (one octave up).
note_lut
    defw   19111   ; Pitch 1  (C)
    defw   17026   ; Pitch 2  (D)
    defw   15169   ; Pitch 3  (E)
    defw   14317   ; Pitch 4  (F)
    defw   12755   ; Pitch 5  (G)
    defw   11364   ; Pitch 6  (A)
    defw   10124   ; Pitch 7  (B)
    
    defw   9555    ; Pitch 8  (High C)
    defw   8513    ; Pitch 9  (High D)
    defw   7584    ; Pitch 10 (High E)
    defw   7158    ; Pitch 11 (High F)
    defw   6377    ; Pitch 12 (High G)
    defw   5682    ; Pitch 13 (High A)
    defw   5062    ; Pitch 14 (High B)
    
    defw   4777    ; Pitch 15 (Higher C)


INCLUDE tune1.s

INCLUDE tune2.s