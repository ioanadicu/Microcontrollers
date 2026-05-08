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

msg1            defb    "Playing tune2...\0"
                align

user_stack      defs    128
user_stack_base align

INCLUDE         UserSpaceLib.s

; =============================================================================
; Music Player Virtual Machine (Interpreter)
; =============================================================================

START
    li      a7, ECALL_CLEAR_DISPLAY
    ecall
    la      a0, msg1
    li      a7, ECALL_PRINT_STRING
    ecall

    ; 1. Setup the song pointer
    la      s0, tune2           ; s0 = pointer to current byte in song
    li      s1, BUZZER_BASE     ; s1 = memory address of our Verilog Buzzer

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

    ; 9. Note Separator (Tiny gap of silence)
    li      a0, 0
    li      a7, ECALL_PLAY_NOTE
    ecall
    
    li      a0, 15              ; 15 ms articulation gap
    call    delay_ms

    ; 10. Move pointer to next note pair and loop
    addi    s0, s0, 2           
    j       play_loop

end_song
    li      a0, 0               ; Ensure buzzer is off at the end
    li      a7, ECALL_PLAY_NOTE
    ecall
    
end_loop
    j       end_loop            ; Infinite loop at end

; =============================================================================
; Helper: Delay in Milliseconds
; =============================================================================
; Input: a0 = milliseconds to delay
; At 40MHz, 1ms = 40,000 cycles. A 4-instruction loop takes ~4 cycles.
; So we loop ~10,000 times per millisecond.
delay_ms
    li      t4, 10000
    mul     t4, t4, a0          ; Total loop iterations needed
delay_loop
    addi    t4, t4, -1
    bnez    t4, delay_loop
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


INCLUDE tune2.s