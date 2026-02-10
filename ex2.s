; Exercise 3

; Define names to aid readability


                la      sp, stack_base      ; Set sp pointing to the end of our stack
                j       START

LCD_DATA        EQU     0x0001_0100
LCD_CONTROL     EQU     0x0001_0101
MASK_BIT7       EQU     0x0000_0000
CLEAR_DB        EQU     0b0000_0001
DELAY           EQU     0x089690

str             defb    "Hello world!\0"    ; String that we want to print
                align

stack           defs    100                 ; Defining a chunk of memory (100 bytes) to be used for the stack
stack_base                                  ; This label is 'just after' the stack base - FULL DESCENDING
                align

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

J END

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
    subi sp, sp, 0x4
    sw ra, [sp]

    subi sp, sp, 0x4
    sw t0, [sp]

    call waiting_loop

    lw t0, [sp]
    addi sp, sp, 0x4

    lw ra, [sp]
    addi sp, sp, 0x4

    ; Read LCD status byte
    LI t3, LCD_DATA
    LW a3, [t3]

    ; Enable signal 0
    LI a2, 0x9 ; 1001
    LI t0, LCD_DATA
    SB a2, 1[t0]

    ; Delay to separate enable pulses
    subi sp, sp, 0x4
    sw ra, [sp]

    subi sp, sp, 0x4
    sw t0, [sp]

    call waiting_loop

    lw t0, [sp]
    addi sp, sp, 0x4

    lw ra, [sp]
    addi sp, sp, 0x4

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
    subi sp, sp, 0x4
    sw ra, [sp]

    subi sp, sp, 0x4
    sw t0, [sp]

    call waiting_loop

    lw t0, [sp]
    addi sp, sp, 0x4

    lw ra, [sp]
    addi sp, sp, 0x4

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
    subi sp, sp, 0x4
    sw ra, [sp]

    subi sp, sp, 0x4
    sw t0, [sp]

    call waiting_loop

    lw t0, [sp]
    addi sp, sp, 0x4

    lw ra, [sp]
    addi sp, sp, 0x4

    ; Read LCD status byte
    LI t3, LCD_DATA
    LW a3, [t3]

    ; Enable signal 0
    LI a2, 0x9 ; 1001
    LI t0, LCD_DATA
    SB a2, 1[t0]

    ; Delay to separate enable pulses
    subi sp, sp, 0x4
    sw ra, [sp]

    subi sp, sp, 0x4
    sw t0, [sp]

    call waiting_loop

    lw t0, [sp]
    addi sp, sp, 0x4

    lw ra, [sp]
    addi sp, sp, 0x4

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
    subi sp, sp, 0x4
    sw ra, [sp]

    subi sp, sp, 0x4
    sw t0, [sp]

    call waiting_loop

    lw t0, [sp]
    addi sp, sp, 0x4

    lw ra, [sp]
    addi sp, sp, 0x4

    ; Disable signal 0
    LI a2, 0b1000 ; 1000
    LI t0, LCD_DATA
    SB a2, 1[t0]

    jr  ra


waiting_loop
    li t0, DELAY
loop_point
    subi t0, t0, 0b1
    bne t0, zero, loop_point
    jr  ra

END