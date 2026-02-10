START
    CALL CLEAR

    ;LI a0, LETTER_A 
    LA a1, str
    LB a0, [a1]

    CALL WAIT_LCD_IDLE

    ADDI a1, a1, 0b1
    LB a0, [a1]
    CALL WAIT_LCD_IDLE

    ADDI a1, a1, 0b1
    LB a0, [a1]
    CALL WAIT_LCD_IDLE

    ADDI a1, a1, 0b1
    LB a0, [a1]
    CALL WAIT_LCD_IDLE

    ADDI a1, a1, 0b1
    LB a0, [a1]
    CALL WAIT_LCD_IDLE

    ADDI a1, a1, 0b1
    LB a0, [a1]
    CALL WAIT_LCD_IDLE

    ADDI a1, a1, 0b1
    LB a0, [a1]
    CALL WAIT_LCD_IDLE

    ADDI a1, a1, 0b1
    LB a0, [a1]
    CALL WAIT_LCD_IDLE

    ADDI a1, a1, 0b1
    LB a0, [a1]
    CALL WAIT_LCD_IDLE

    ADDI a1, a1, 0b1
    LB a0, [a1]
    CALL WAIT_LCD_IDLE

    ADDI a1, a1, 0b1
    LB a0, [a1]
    CALL WAIT_LCD_IDLE

    ADDI a1, a1, 0b1
    LB a0, [a1]
    CALL WAIT_LCD_IDLE


JAL END

WAIT_LCD_IDLE
    ; Set to read control with data bus direction as input
    LI a2, 0b1001 ;1001
    LI t0, LCD_DATA
    SB a2, 1[t0]

STEP_2
    ; Enable signal 1
    LI a2, 0b1101 ;1101
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
    LI a2, 0b1010 ; 1010
    LI t0, LCD_DATA
    SB a2, 1[t0]

    ; Output desired byte
    SW a0, LCD_DATA, t0

    ; Enable signal 1
    LI a2, 0b1110 ; 1110
    LI t0, LCD_DATA
    SB a2, 1[t0]

    ; Delay to stretch pulse
    LI a2, 0x989690
LOOP_SUBS3
    SUBI a2, a2, 0x1 
    BNE a2, zero, LOOP_SUBS3

    ; Disable signal 0
    LI a2, 0b1010 ; 1010
    LI t0, LCD_DATA
    SB a2, 1[t0]

    RET

CLEAR
    ; Set to read control with data bus direction as input
    LI a2, 0b1001 ;1001
    LI t0, LCD_DATA
    SB a2, 1[t0]

STEP_22
    ; Enable signal 1
    LI a2, 0b1101 ;1101
    LI t0, LCD_DATA
    SB a2, 1[t0]

    ; Delay to stretch pulse
    LI a2, 0x989690
LOOP_SUBS4
    SUBI a2, a2, 0x1 
    BNE a2, zero, LOOP_SUBS4

    ; Read LCD status byte
    LI t3, LCD_DATA
    LW a3, [t3]

    ; Enable signal 0
    LI a2, 0x9 ; 1001
    LI t0, LCD_DATA
    SB a2, 1[t0]

    ; Delay to separate enable pulses
    LI a2, 0x989690
LOOP_SUBS5
    SUBI a2, a2, 0x1 
    BNE a2, zero, LOOP_SUBS5

    ; If bit 7 high repeat from step 2
    LI a4, 0x80
    AND a3, a3, a4
    BNEZ a3, STEP_22


    ; DB CODE
    LI a0, CLEAR_DB

    ; RS = 0, R/W = 0, E = 0
    LI a2, 0b1000 ; 1000
    LI t0, LCD_DATA
    SB a2, 1[t0]

    ; Output desired byte
    SW a0, LCD_DATA, t0

    ; Enable signal 1
    LI a2, 0b1100 ; 1100
    LI t0, LCD_DATA
    SB a2, 1[t0]

    ; Delay to stretch pulse
    LI a2, 0x989690
LOOP_SUBS6
    SUBI a2, a2, 0x1 
    BNE a2, zero, LOOP_SUBS6

    ; Disable signal 0
    LI a2, 0b1000 ; 1000
    LI t0, LCD_DATA
    SB a2, 1[t0]

    RET

END

LCD_DATA    EQU 0x0001_0100
LCD_CONTROL EQU 0x0001_0101
MASK_BIT7   EQU 0x0000_0000

str defb "Hello world!\0"
align
LETTER_A    EQU 'h'
CLEAR_DB    EQU 0b0000_0001
