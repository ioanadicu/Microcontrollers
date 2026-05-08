; =============================================================================
; Display Operations Library
; Maria-Ioana Dicu
; 1 May 2026
;
; Provides helper routines for driving the LCD display:
;   - printString(pointer)
;       Prints a null-terminated string character by character.
;   - lcdSendCommand(value, control_signals)
;       Sends either data or a command to the LCD.
;   - waiting_loop()
;       Small delay loop used to stretch pulse width and separate enable pulses.
;
; Reference:
;   HD44780 LCD controller documentation:
;   https://cdn.sparkfun.com/assets/9/5/f/7/b/HD44780.pdf
;
; =============================================================================


; =============================================================================
; Named constants
; =============================================================================

LCD_DATA        EQU     0x0001_0100         ; Base LCD address
LCD_BUSY        EQU     0x80                ; Busy flag mask (bit 7)
DELAY           EQU     0x000690            ; Delay counter value
SHIFT_NEXT      EQU     0b1100_0000         ; Command to move cursor to second line

LCD_REG_DATA    EQU     0x0                 ; Data register / status register
LCD_REG_CTRL    EQU     0x1                 ; Control register

RW              EQU     0x1                 ; Read/Write control bit
RS              EQU     0x2                 ; Register Select control bit
E               EQU     0x4                 ; Enable control bit
LIGHT           EQU     0x8                 ; Backlight control bit


; =============================================================================
; printString
; =============================================================================
; Prints a null-terminated string to the LCD.
;
; Input:
;   a0 = pointer to string
;
; Registers used:
;   s0 = current string pointer
;   s1 = current character
; =============================================================================

printString
    subi    sp, sp, 12
    sw      ra,  8[sp]  ; Save return address
    sw      s0,  4[sp]  ; Save callee-saved register
    sw      s1,  0[sp]  ; Save callee-saved register

    mv      s0, a0
    lb      s1, [s0]

whileChar
    ; Loop until null reached
    beqz    s1, foundNull

    ; Print current character
    mv      a0, s1
    li      a1, LIGHT | RS
    call    lcdSendCommand

    ; Advance to next character
    addi    s0, s0, 1
    lb      s1, [s0]
    j       whileChar  

foundNull
    ; Restore saved registers and return
    lw      s1,  0[sp]
    lw      s0,  4[sp]
    lw      ra,  8[sp]
    addi    sp, sp, 12

    ret


; =============================================================================
; lcdSendCommand
; =============================================================================
; Sends either data or a command to the LCD.
;
; Input:
;   a0 = character or command to send
;   a1 = control signals, with E initially low
;
; Registers used:
;   s0 = LCD base address
;   s1 = LCD status
; =============================================================================

lcdSendCommand

    subi    sp, sp, 12
    sw      ra,  8[sp]  ; Save return address
    sw      s0,  4[sp]  ; Save callee-saved register
    sw      s1,  0[sp]  ; Save callee-saved register

    ; -------------------------------------------------------------------------
    ; Wait until LCD is no longer busy
    ; -------------------------------------------------------------------------

    li s0, LCD_DATA

    ; Configure LCD for control read with data bus as input
    li      t0, LIGHT | RW 
    sb      t0, LCD_REG_CTRL[s0]

STEP_2
    ; Set enable high
    li      t0, LIGHT | E | RW 
    sb      t0, LCD_REG_CTRL[s0]

    ; Stretch enable pulse
    call    waiting_loop

    ; Stretch enable pulse
    lw      s1, LCD_REG_DATA[s0]

    ; Set enable low
    li      t0, LIGHT | RW 
    sb      t0, LCD_REG_CTRL[s0]

    ; Separate enable pulses
    call    waiting_loop ; waiting_loop only uses t0 so not saving registers (intentional)

    ; Repeat while bit 7 high
    andi    s1, s1, LCD_BUSY
    bnez    s1, STEP_2


    ; -------------------------------------------------------------------------
    ; Write data/ command to LCD
    ; -------------------------------------------------------------------------

    ; Configure LCD for control read with data bus as output
    sb      a1, LCD_REG_CTRL[s0]

    ; Write byte to data register
    sw      a0, LCD_REG_DATA[s0]

    ; Pulse enable high
    ori     t0, a1, E
    sb      t0, LCD_REG_CTRL[s0]

    ; Delay to stretch pulse
    call    waiting_loop ; waiting_loop only uses t0 so not saving registers (intentional)

    ; Disable signal 0
    sb      a1, LCD_REG_CTRL[s0]

    ; Restore saved registers and return
    lw      s1,  0[sp]
    lw      s0,  4[sp]
    lw      ra,  8[sp]
    addi    sp, sp, 12

    ret


; =============================================================================
; waiting_loop
; =============================================================================
; Small delay used for LCD timing.
;
; Registers used:
;   t0 = delay counter
; =============================================================================

waiting_loop
    li      t0, DELAY
loop_point
    subi    t0, t0, 0b1
    bnez    t0, loop_point
    jr      ra
