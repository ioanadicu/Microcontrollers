;-----------------------------------------------------------------------------
;       Display Operations Library
;       Maria-Ioana Dicu
;       19 February 2026
;
;       This library includes the following functions for the display:
;       - moveCursor(): moves the cursor to the second line of the display
;       - printString(pointer): cycles through every character of a string until it 
;                   finds the null character and calls another function to print each
;       - waitLcdIdle(): a function that waits and checks for the LCD to be idle
;       - lcdSendCommand(): prints a character to the display or clears the display or
;                   moves cursor based on signals
;       - waitingLoop(): a waiting loop to stretch pulse width/ separate enable pulses
;
;       Display documentation: https://cdn.sparkfun.com/assets/9/5/f/7/b/HD44780.pdf
;
;       Known bugs:
;       - none
;
;-----------------------------------------------------------------------------

; Defining names to aid readability
LCD_DATA        EQU     0x0001_0100         ; address where we write display data
LCD_CONTROL     EQU     0x0001_0101         ; address where we write control signals for the display
MASK7           EQU     0x80                ; mask used to find wether bit 7 set with an AND operaton
DELAY           EQU     0x000690            ; delay used in the counter
WRITE_CTRL      EQU     0b1010              ; controls when we want to write a character to the display
SHIFT_NEXT      EQU     0b1100_0000         ; DB7-DB0 data to move cursor to next line
MASKPRINT       EQU     0b1111
AMIN            EQU     'A' - 0x10
                align


; def moveCursor(): moves the cursor to the second line of the display
moveCursor
    subi    sp, sp, 4
    sw      ra,  0[sp]  ; caller saved - I save it here and use it at the end of the function 

    call waitLcdIdle

    li a0, SHIFT_NEXT
    li a1, CLEAR_CTRL                       ; using same controls as the ones when clearing the display
    call lcdSendCommand                     ; calling lcdSendCommand with DB7-DB0 data to move cursor

    lw      ra,  0[sp]
    addi    sp, sp, 4

    jr ra




; def printString(pointer): cycles through every character of a string until it 
;                   finds the null character and calls another function to print each
; function arguments
; a0 = pointer to string

; local variables
; s0 = will hold the pointer because we plan on overwriting a0 for passing arguments to other functions
; s1 = using it to load chat at address pointed


printString
    subi    sp, sp, 12
    sw      ra,  8[sp]  ; caller saved - I save it here and use it at the end of the function 
    sw      s0,  4[sp]  ; calee saved - saving it before executing anything and restoring when done
    sw      s1,  0[sp]

    mv s0, a0
    lb s1, [s0]

    ; printing first character
    mv a0, s1
    li a1, WRITE_CTRL   ; will be used as function argument in writeString
    call lcdSendCommand

    ; printing the other characters until we reach the null character so we know our string ended
notEnded
    addi s0, s0, 1
    lb s1, [s0]
    beqz s1, foundNull

    mv a0, s1
    li a1, WRITE_CTRL   ; will be used as function argument in writeString
    call lcdSendCommand

    j notEnded

foundNull

    ; Getting ra back and the callee saved registers
    lw      s1,  0[sp]
    lw      s0,  4[sp]
    lw      ra,  8[sp]
    addi    sp, sp, 12

    jr ra




; def waitLcdIdle(): a function that waits and checks for the LCD to be idle

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
    sw      s0, 16[sp]  ; s registers calee saved - saving it before executing anything and restoring when done
    sw      s1, 12[sp]
    sw      s2,  8[sp]
    sw      s3,  4[sp]
    sw      s4,  0[sp]

    li s0, LCD_DATA
    li s1, 0b1101       ; control signals with E=1
    li s2, 0b1001       ; control signals with E=0
    li s3, MASK7        ; bit 7 mask

    ; Set to read control with data bus direction as input
    sb s2, 1[s0]

STEP_2
    ; Enable signal 1
    sb s1, 1[s0]

    ; Delay to stretch pulse
    call waiting_loop

    ; Read LCD status byte
    lw s4, [s0]

    ; Enable signal 0
    sb s2, 1[s0]

    ; Delay to separate enable pulses
    call waiting_loop

    ; If bit 7 high repeat from step 2
    and s4, s4, s3
    bnez s4, STEP_2

    ; Getting ra back and the callee saved registers
    lw      s4,  0[sp]  
    lw      s3,  4[sp]
    lw      s2,  8[sp]
    lw      s1, 12[sp]
    lw      s0, 16[sp]
    lw      ra, 20[sp]
    addi    sp, sp, 24

    ret




; def lcdSendCommand (character a0, signals a2): prints a character to the display or clears the display or
;                   moves cursor based on signals

; function arguments
; a0 = character/command to be written
; a1 = control signals (with enable = 0)

; local variables
; s0 = LCD_DATA
lcdSendCommand

    subi    sp, sp, 8
    sw      ra,  4[sp]  ; caller saved - I save it here and use it at the end of the function 
    sw      s0,  0[sp]  ; s register calee saved - saving it before executing anything and restoring when done


    subi    sp, sp, 8
    sw      a0,  4[sp]  ; caller saved
    sw      a1,  0[sp]

    call waitLcdIdle

    lw      a1,  0[sp]
    lw      a0,  4[sp]
    addi    sp, sp, 8


    li s0, LCD_DATA

    ; Set to write data with data bus direction as output
    sb a1, 1[s0]

    ; Output desired byte
    sw a0, 0[s0]

    ; Enable signal 1
    addi a1, a1, 4
    sb a1, 1[s0]

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
    sb a1, 1[s0]

    ; Getting ra back and the callee saved registers
    lw      s0,  0[sp]
    lw      ra,  4[sp]
    addi    sp, sp, 8

    jr ra




; def waiting_loop(): a waiting loop to stretch pulse width/ separate enable pulses

; local variables
; t0 = takes the delay value (caller saved, we don't need to worry)

waiting_loop
    li t0, DELAY
loop_point
    subi t0, t0, 0b1
    bne t0, zero, loop_point
    jr  ra




; printing hex
; a0 - number

PrintHex8
    subi    sp, sp, 8
    sw      ra,  4[sp]  ; caller saved - I save it here and use it at the end of the function 
    sw      s0,  0[sp]  ; s register calee saved - saving it before executing anything and restoring when done

    mv      s0, a0              ; Make a copy of the input
    srli    a0, a0, 0x4         ; Shift right 4 places
    call    printHex4
    mv      a0, s0              ; Restore value from the copy
    call    printHex4

    ; Getting ra back and the callee saved registers
    lw      s0,  0[sp]
    lw      ra,  4[sp]
    addi    sp, sp, 8

    jr ra

printHex4
    subi    sp, sp, 4
    sw      ra,  0[sp]  ; caller saved - I save it here and use it at the end of the function 

    andi    a0, a0, MASKPRINT   ; Mask off everything except lower 4 bits
    li      t0, 0x9      
    bgt     a0, t0, addition    ; if a0 > 9
    addi    a0, a0, '0'
    j       calling
addition
    addi    a0, a0, AMIN
calling
    li      a1, WRITE_CTRL   ; will be used as function argument in writeString
    call    lcdSendCommand

    lw      ra,  0[sp]
    addi    sp, sp, 4

    jr      ra



PrintDecU32
    subi    sp, sp, 12
    sw      ra,  8[sp]
    sw      s0,  4[sp]
    sw      s1,  0[sp]

    mv      s0, a0          ; s0 = value
    li      s1, 0           ; s1 = digit count

    ; Special case: if value == 0, print '0' and return
    bnez    s0, dec_loop
    li      a0, '0'
    li      a1, WRITE_CTRL
    call    lcdSendCommand
    j       dec_done

dec_loop
    li      t1, 10
    remu    t0, s0, t1      ; t0 = s0 % 10
    divu    s0, s0, t1      ; s0 = s0 / 10
    addi    t0, t0, '0'     ; ASCII digit

    subi    sp, sp, 4
    sw      t0, 0[sp]       ; push ASCII digit as a word
    addi    s1, s1, 1
    bnez    s0, dec_loop

print_loop
    ; pop and print digits
    lw      a0, 0[sp]
    addi    sp, sp, 4
    li      a1, WRITE_CTRL
    call    lcdSendCommand

    addi    s1, s1, -1
    bnez    s1, print_loop

dec_done
    lw      s1,  0[sp]
    lw      s0,  4[sp]
    lw      ra,  8[sp]
    addi    sp, sp, 12
    ret