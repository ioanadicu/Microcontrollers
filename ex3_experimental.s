;---------------------------------------------------------
;       Exercise 3: Nesting Procedure Calls
;       Maria-Ioana Dicu
;       17 February 2026
;
;       This programme prints 2 strings on the display.
;
;       Known bugs:
;       - Not following ABI for main function
;       - No pause in between strings
;       - Repeated logic for printing strings
;       - in printString writeCharcter should take a0 
;
;---------------------------------------------------------

; Defining names to aid readability

                la      sp, stack_base      ; Set sp pointing to the end of our stack
                j       START

LCD_DATA        EQU     0x0001_0100
LCD_CONTROL     EQU     0x0001_0101
MASK_BIT7       EQU     0x0000_0000
CLEAR_DB        EQU     0b0000_0001
DELAY           EQU     0x099690

str1            defb    "Hello world! \0"    ; String that we want to print
                align

str2            defb    "Computer\0"
                align

stack           defs    100                 ; Defining a chunk of memory (100 bytes) to be used for the stack
stack_base      align                       ; This label is 'just after' the stack base - FULL DESCENDING




; def main()

; local variables - used as function arguments
; a0 = character to be written
; a1 = control signals (with enable = 0)
; a2 = display control signals
; a7 = pointer to string

START
    ; Clearing the display - we're using writeCharacter for this but with the special clearing signals
    li a0, CLEAR_DB
    li a1, 0b1000 
    call writeCharacter

    la a0, str1
    call printString

    la a0, str2
    call printString

J END




; def printString()
; a0 = pointer to string
; s0 = using it to load char at address pointed


printString
    subi    sp, sp, 8
    sw      ra,  4[sp]  ; caller saved - I save it here and use it at the end of the function 
    sw      s0,  0[sp]  ; calee saved - saving it before executing anything and restoring when done

    
    lb s0, [a0]

    li a1, 0b1010   ; will be used as function argument in writeString
    call writeCharacter

notEnded
    addi a0, a0, 1
    lb s0, [a0]
    beqz s0, foundNull

    li a1, 0b1010   ; will be used as function argument in writeString
    call writeCharacter

    j notEnded
foundNull

    ; Getting ra back and the callee saved registers
    lw      s0,  0[sp]
    lw      ra,  4[sp]
    addi    sp, sp, 8

    jr ra






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
    sw      ra, 20[sp]  ; caller saved - I save it here and use it at the end of the function 
    sw      s0, 16[sp]  ; calee saved - saving it before executing anything and restoring when done
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

    ; Getting ra back and the callee saved registers
    lw      s4,  0[sp]  
    lw      s3,  4[sp]
    lw      s2,  8[sp]
    lw      s1, 12[sp]
    lw      s0, 16[sp]
    lw      ra, 20[sp]
    addi    sp, sp, 24

    ret




; def writeCharacter (character a0, signals a2)

; function arguments
; a0 = character to be written
; a1 = control signals (with enable = 0)

; local variables
; s0 = LCD_DATA
writeCharacter

    subi    sp, sp, 8
    sw      ra,  4[sp]  ; caller saved - I save it here and use it at the end of the function 
    sw      s0,  0[sp]  ; calee saved - saving it before executing anything and restoring when done


    subi    sp, sp, 8
    sw      a0,  4[sp]  ; caller saved
    sw      a1,  0[sp]

    call waitLcdIdle

    lw      a1,  0[sp]
    lw      a0,  4[sp]
    addi    sp, sp, 8


    li s0, LCD_DATA

    ; Set to write data with data bus direction as output
    SB a1, 1[s0]

    ; Output desired byte
    SW a0, 0[s0]

    ; Enable signal 1
    addi a1, a1, 4
    SB a1, 1[s0]

    ; Delay to stretch pulse
    subi    sp, sp, 8
    sw      a0,  4[sp]  ; caller saved
    sw      a1,  0[sp]

    call waiting_loop

    lw      a1,  0[sp]
    lw      a0,  4[sp]
    addi    sp, sp, 8


    ; Disable signal 0
    subi a1, a1, 4
    SB a1, 1[s0]

    ; Getting ra back and the callee saved registers
    lw      s0,  0[sp]
    lw      ra,  4[sp]
    addi    sp, sp, 8

    jr ra




; def waiting_loop()

; local variables
; t0 = takes the delay value

waiting_loop
    li t0, DELAY
loop_point
    subi t0, t0, 0b1
    bne t0, zero, loop_point
    jr  ra




END J . ; infinite loop to stop the program