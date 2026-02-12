; Exercise 3

; Defining names to aid readability

                la      sp, stack_base      ; Set sp pointing to the end of our stack
                j       START

LCD_DATA        EQU     0x0001_0100
LCD_CONTROL     EQU     0x0001_0101
MASK_BIT7       EQU     0x0000_0000
CLEAR_DB        EQU     0b0000_0001
DELAY           EQU     0x099690

str             defb    "Hello world!\0"    ; String that we want to print
                align

stack           defs    100                 ; Defining a chunk of memory (100 bytes) to be used for the stack
stack_base      align                       ; This label is 'just after' the stack base - FULL DESCENDING




; def main()

; local variables
; a7 = pointer to string
; a0 = character to be written
; a2 = display control signals

START
    ; Clearing the display - we're using writeCharacter for this but with the special clearing signals
    li a0, CLEAR_DB
    li a2, 0b1000 

    call writeCharacter


    ; Printing each thing
    li a2, 0b1010

    LA a7, str
    LB a0, [a7]

    CALL writeCharacter

notEnded
    addi a7, a7, 1
    LB a0, [a7]
    BEQZ a0, foundNull
    CALL writeCharacter
    J notEnded

foundNull

J END




; def waitLcdIdle()

; local variables
; s0 = LCD_DATA
; s1 = Enable on
; s2 = Enable off
; s3 = bit mask
; s4 = status byte

waitLcdIdle
    ; save ra and s registers
    subi    sp, sp, 24
    sw      ra, 20[sp]
    sw      s0, 16[sp]
    sw      s1, 12[sp]
    sw      s2,  8[sp]
    sw      s3,  4[sp]
    sw      s4,  0[sp]

    li s0, LCD_DATA
    li s1, 0b1101       ; E=1
    li s2, 0b1001       ; E=0
    li s3, 0x80         ; bit 7 mask

    ; Set to read control with data bus direction as input
    SB s2, 1[s0]

STEP_2
    ; Enable signal 1
    SB s1, 1[s0]

    ; Delay to stretch pulse
    call waiting_loop

    ; Read LCD status byte
    LW s4, [s0]

    ; Enable signal 0
    SB s2, 1[s0]

    ; Delay to separate enable pulses
    call waiting_loop

    ; If bit 7 high repeat from step 2
    AND s4, s4, s3
    BNEZ s4, STEP_2

    ; Getting ra back
    lw      s4,  0[sp]
    lw      s3,  4[sp]
    lw      s2,  8[sp]
    lw      s1, 12[sp]
    lw      s0, 16[sp]
    lw      ra, 20[sp]
    addi    sp, sp, 24

    ret




; def writeCharacter (char)

; function arguments
; a0 = character to be written
; *a1 = enable 1 (auto deduced from a2)
; a2 = enable 0

; local variables
; s0 = LCD_DATA
writeCharacter

    subi    sp, sp, 8
    sw      ra,  4[sp]
    sw      s0,  0[sp]


    call waitLcdIdle

    addi  a1, a2, 4

    li s0, LCD_DATA

    ; Set to write data with data bus direction as output
    SB a2, 1[s0]

    ; Output desired byte
    SW a0, 0[s0]

    ; Enable signal 1
    SB a1, 1[s0]

    ; Delay to stretch pulse
    call waiting_loop

    ; Disable signal 0
    SB a2, 1[s0]

    lw      s0,  0[sp]
    lw      ra,  4[sp]
    addi    sp, sp, 8

    jr ra




; def waiting_loop

; local variables
; t0 = takes the delay value

waiting_loop
    li t0, DELAY
loop_point
    subi t0, t0, 0b1
    bne t0, zero, loop_point
    jr  ra

END J .