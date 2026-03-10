;-----------------------------------------------------------------------------
;       Display Operations Library
;       Maria-Ioana Dicu
;       19 February 2026
;
;       This library includes the following functions for the display:
;       - moveCursor(): moves the cursor to the second line of the display
;       - printString(pointer): cycles through every character of a string until it 
;                   finds the null character and calls another function to print each
;       - lcdSendCommand(): prints a character to the display or clears the display or
;                   moves cursor based on signals
;       - waitingLoop(): a waiting loop to stretch pulse width/ separate enable pulses
;
;       Display documentation: https://cdn.sparkfun.com/assets/9/5/f/7/b/HD44780.pdf
;
;       Known bugs:
;       - name offsets
;       - delay different times?
;
;-----------------------------------------------------------------------------

; Defining names to aid readability
LCD_DATA        EQU     0x0001_0100         ; address where we write display data
LCD_BUSY        EQU     0x80                ; mask used to find wether bit 7 set with an AND operaton
DELAY           EQU     0x000690            ; delay used in the counter
SHIFT_NEXT      EQU     0b1100_0000         ; DB7-DB0 data to move cursor to next line

LCD_REG_DATA    EQU     0x0     ; data register / status register
LCD_REG_CTRL    EQU     0x1     ; control register

RW              EQU     0x1 
RS              EQU     0x2 
E               EQU     0x4 
LIGHT           EQU     0x8
AMIN            EQU     'A' - 0x10
                align




; def printString(pointer): cycles through every character of a string until it 
;                   finds the null character and calls another function to print each
; function argument
; a0 = pointer to string

; local variables
; s0 = will hold the pointer because we plan on overwriting a0 for passing arguments to other functions
; s1 = using it to load char at address pointed


printString
    subi    sp, sp, 12
    sw      ra,  8[sp]  ; saving return address
    sw      s0,  4[sp]  ; calee saved - saving it before executing anything and restoring when done
    sw      s1,  0[sp]

    mv s0, a0
    lb s1, [s0]

whileChar
    ; while (char != null)
    beqz    s1, foundNull

    ; print character
    mv      a0, s1
    li      a1, LIGHT | RS
    call    lcdSendCommand

    ; point to next character
    addi    s0, s0, 1
    lb      s1, [s0]
    j       whileChar  

foundNull

    ; Getting ra back and the callee saved registers
    lw      s1,  0[sp]
    lw      s0,  4[sp]
    lw      ra,  8[sp]
    addi    sp, sp, 12

    ret




; def lcdSendCommand (character a0, signals a2): prints a character to the display or clears the display or
;                   moves cursor based on signals

; function arguments
; a0 = character/command to be written
; a1 = control signals (with enable = 0)

; local variables
; s0 = LCD_DATA
lcdSendCommand

    subi    sp, sp, 12
    sw      ra,  8[sp]  ; saving return address
    sw      s0,  4[sp]  ; s register calee saved - saving it before executing anything and restoring when done
    sw      s1,  0[sp]


    ; Waiting for lcd to be idle

    li s0, LCD_DATA

    ; Set to read control with data bus direction as input
    li t0, LIGHT | RW 
    sb t0, LCD_REG_CTRL[s0]

STEP_2
    ; Enable signal 1
    li t0, LIGHT | E | RW 
    sb t0, LCD_REG_CTRL[s0]

    ; Delay to stretch pulse
    call waiting_loop

    ; Read LCD status byte
    lw s1, LCD_REG_DATA[s0]

    ; Enable signal 0
    li t0, LIGHT | RW 
    sb t0, LCD_REG_CTRL[s0]

    ; Delay to separate enable pulses
    call waiting_loop   ; not saving a registers becase we know for sure waiting loop only uses t0

    ; If bit 7 high repeat from step 2
    andi    s1, s1, LCD_BUSY
    bnez    s1, STEP_2


    ; Actual printing

    ; Set to write data with data bus direction as output
    sb a1, LCD_REG_CTRL[s0]

    ; Output desired byte
    sw a0, LCD_REG_DATA[s0]

    ; Enable signal 1
    ori t0, a1, E
    sb t0, LCD_REG_CTRL[s0]

    ; Delay to stretch pulse
    subi    sp, sp, 4
    sw      a1,  0[sp]  ; caller saved, only a1 needed after the call so not saving a0

    call waiting_loop   ; not saving a registers becase we know for sure waiting loop only uses t0

    lw      a1,  0[sp]
    addi    sp, sp, 4

    ; Disable signal 0
    sb a1, LCD_REG_CTRL[s0]

    ; Getting ra back and the callee saved registers
    lw      s1,  0[sp]
    lw      s0,  4[sp]
    lw      ra,  8[sp]
    addi    sp, sp, 12

    ret




; def waiting_loop(): a waiting loop to stretch pulse width/ separate enable pulses

; local variables
; t0 = takes the delay value (caller saved, we don't need to worry)

waiting_loop
    li t0, DELAY
loop_point
    subi t0, t0, 0b1
    bnez t0, loop_point
    jr  ra
