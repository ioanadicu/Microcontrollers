; =============================================================================
; User Space Screen Routines
; Maria-Ioana Dicu
; 8 May 2026
;
; This file contains helper routines used to print common screens and values
; through the display-related ecalls.
;
; The main purpose of these functions is to keep the main program shorter and
; avoid repeating the same display-printing sequences multiple times.
;
; Functions provided:
;   - printDec(value)
;       Prints an unsigned decimal number digit by digit.
; =============================================================================


; =============================================================================
; printDec
; =============================================================================
; Prints an unsigned decimal number.
; The digits are extracted using repeated division by 10 and temporarily
; stored on the stack so they can be printed in the correct order.
;
; Input:
;   a0 = integer value to print
;
; Registers used:
;   s0 = working copy of the value
;   s1 = digit counter
; =============================================================================

printDec
    subi    sp, sp, 12
    sw      ra,  8[sp]
    sw      s0,  4[sp]
    sw      s1,  0[sp]

    mv      s0, a0          ; s0 = value being printed
    li      s1, 0           ; s1 = digit counter

    ; -------------------------------------------------------------------------
    ; Special case: value = 0
    ; -------------------------------------------------------------------------

    bnez    s0, decLoop
    li      a0, '0'

    li      a7, ECALL_PRINT_CHAR
    ecall 
    
    j       decDone


; -------------------------------------------------------------------------
; Extract digits and push them onto the stack
; -------------------------------------------------------------------------

decLoop
    li      t1, 10
    remu    t0, s0, t1      ; t0 = s0 % 10
    divu    s0, s0, t1      ; s0 = s0 / 10
    addi    t0, t0, '0'     ; Convert to ASCII digit

    subi    sp, sp, 4
    sw      t0, 0[sp]       ; push digit onto stack
    addi    s1, s1, 1
    bnez    s0, decLoop


; -------------------------------------------------------------------------
; Pop digits and print them
; -------------------------------------------------------------------------

printLoop
    lw      a0, 0[sp]
    addi    sp, sp, 4

    li      a7, ECALL_PRINT_CHAR
    ecall 

    addi    s1, s1, -1
    bnez    s1, printLoop

decDone
    lw      s1,  0[sp]
    lw      s0,  4[sp]
    lw      ra,  8[sp]
    addi    sp, sp, 12
    ret
