START
    LI a0, LETTER_A 

    CALL WAIT_LCD_IDLE
JAL START

WAIT_LCD_IDLE
    ; Set to read control with data bus direction as input
    LI a2, 0x9 ; 1001
    LI t0, LCD_DATA
    SB a2, 1[t0]

STEP_2
    ; Enable signal 1
    LI a2, 0xB ; 1011
    LI t0, LCD_DATA
    SB a2, 1[t0]

    ; Delay to stretch pulse
    LI a2, 0x989690
LOOP_SUBS1
    SUBI a2, a2, 0x1 
    BNE a2, zero, LOOP_SUBS1

    ; Read LCD status byte
    LI t3, LCD_DATA
    LW a3, [t3]

    ; Enable signal 0
    LI a2, 0x9 ; 1001
    LI t0, LCD_DATA
    SB a2, 1[t0]

    ; Delay to separate enable pulses
    LI a2, 0x989690
LOOP_SUBS2
    SUBI a2, a2, 0x1 
    BNE a2, zero, LOOP_SUBS2

    ; If bit 7 high repeat from step 2
    LI a4, 0x80
    AND a3, a3, a4
    BNEZ a3, STEP_2


WRITE_CHARACTER
    ; Called with function argument a0

    ; Set to write data with data bus direction as output
    LI a2, 0x5 ; 0101
    LI t0, LCD_DATA
    SB a2, 1[t0]

    ; Output desired byte
    SW a0, LCD_DATA, t0

    ; Enable signal 1
    LI a2, 0x7 ; 0111
    LI t0, LCD_DATA
    SB a2, 1[t0]

    ; Delay to stretch pulse
    LI a2, 0x989690
LOOP_SUBS3
    SUBI a2, a2, 0x1 
    BNE a2, zero, LOOP_SUBS3

    ; Disable signal 0
    LI a2, 0x5 ; 0101
    LI t0, LCD_DATA
    SB a2, 1[t0]

    RET

LCD_DATA    EQU 0001_0100
LCD_CONTROL EQU 0001_0101
MASK_BIT7   EQU 1000_0000

LETTER_A    EQU 0110_0001
