; =============================================================================
; User Space Screen Routines
; Maria-Ioana Dicu
; 12 March 2026
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
;
;   - displayTime()
;       Prints the current timer values using the display ecalls.
;
;   - displayStartScreen()
;       Prints the start screen.
;
;   - displayPauseScreen()
;       Prints the pause screen.
;
; Notes:
;   - These routines do not directly control the LCD hardware.
;   - They rely on ecalls that perform display operations such as clearing the
;     screen, printing strings, printing characters, and moving to the next line.
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
    li      a1, LIGHT | RS

    li      a7, 1
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
    li      a1, LIGHT | RS

    li      a7, 1
    ecall 

    addi    s1, s1, -1
    bnez    s1, printLoop

decDone
    lw      s1,  0[sp]
    lw      s0,  4[sp]
    lw      ra,  8[sp]
    addi    sp, sp, 12
    ret


; =============================================================================
; displayTime
; =============================================================================
; Prints the current timer values using display ecalls.
; Extracted from main to keep the main program shorter and clearer.
;
; Assumes:
;   s2 = weeks
;   s1 = hours
;   s0 = minutes
; =============================================================================

displayTime
    subi    sp, sp, 4
    sw      ra, 0[sp]

    ; Clear display
    li      a7, 0
    ecall

    ; Print "Current time: "
    la      a0, runLine1
    li      a7, 2
    ecall

    ; Move cursor to next line
    li      a7, 3
    ecall

    ;  Print hours value
    mv      a0, s2
    call    printDec

    ; Print h
    la      a0, strh
    li      a7, 2
    ecall

    ; Print minutes value
    mv      a0, s1
    call    printDec

    ; Print m
    la      a0, strm
    li      a7, 2
    ecall

    ; Print seconds value
    mv      a0, s0
    call    printDec

    ; Print s
    la      a0, strs
    li      a7, 2
    ecall

    lw      ra, 0[sp]
    addi    sp, sp, 4
    ret


; =============================================================================
; displayStartScreen
; =============================================================================
; Prints the start screen using display ecalls.
; Extracted from main to keep the main program shorter and clearer.
; =============================================================================

displayStartScreen
	subi    sp, sp, 4
    sw      ra, 0[sp]

	; Clear display
    li 		a7, 0
	ecall

    ; Print first line
    la 		a0, startLine1
	li 		a7, 2
	ecall

    ; Move cursor to next line
	li		a7, 3
	ecall

    ; Print second line
	la 		a0, startLine2
	li 		a7, 2
	ecall

	lw      ra, 0[sp]
    addi    sp, sp, 4
    ret


; =============================================================================
; displayPauseScreen
; =============================================================================
; Prints the pause screen using display ecalls.
; Extracted from main to keep the main program shorter and clearer.
; =============================================================================

displayPauseScreen
	subi    sp, sp, 4
    sw      ra, 0[sp]

    ; Clear display
	li 		a7, 0
	ecall

    ; Print first line
	la 		a0, pauseLine1
	li 		a7, 2
	ecall

    ; Move cursor to next line
	li		a7, 3
	ecall

    ; Print second line
	la 		a0, pauseLine2
	li 		a7, 2
	ecall

	lw      ra, 0[sp]
    addi    sp, sp, 4
    ret