; =============================================================================
; Exercise 7: Key Debouncing and Keyboard Scanning
; Maria-Ioana Dicu
; =============================================================================


; =============================================================================
; OS SECTION
; =============================================================================

ORG             0x0000_0000
j               initialisation

INCLUDE         DisplayOperations.s


; =============================================================================
; Constants
; =============================================================================

mppMask         EQU     0x18967F
bit0            EQU     0x0000_0001
bit31           EQU     0x8000_0000

MSTATUS_MIE     EQU     0x8
MIE_MEIE        EQU     0x800

INTR_CTRL       EQU     0x0001_0400
INTR_EN         EQU     0x04
INTR_RQ         EQU     0x08
INTR_MODE       EQU     0x0C

TIMER_INT       EQU     0b00_0001_0000

TIME_PERIPH     EQU     0x0001_0200
TIME_REG_LIMIT  EQU     0x04
TIME_REG_STATUS EQU     0x0C
TIME_REG_CMD    EQU     0x10
TIME_REG_CTRL   EQU     0x14

PIO_BASE        EQU     0x0001_0300
PIO_DATA        EQU     0x00
PIO_DIR         EQU     0x04
PIO_CLR         EQU     0x08
PIO_SET         EQU     0x0C

ROW_MASK        EQU     0x00000F00      ; bits 8-11 outputs
COL_MASK        EQU     0x0000F000      ; bits 12-15 inputs

KEY_DIR         EQU     0x0000F000      ; bits 12-15 input, rest output

SCAN_MODULUS    EQU     999             ; 1 ms if timer ticks every 1 us

ecall_max       EQU     (ecall_end - ecall_0) / 4


; =============================================================================
; Machine-mode data
; =============================================================================

row_drive_table
    defw    0x00000100      ; output bit 8
    defw    0x00000200      ; output bit 9
    defw    0x00000400      ; output bit 10
    defw    0x00000800      ; output bit 11

key_ascii_table
    defb    "*741"          ; bit 8 active, inputs 12,13,14,15
    defb    "0852"          ; bit 9 active
    defb    "#963"          ; bit 10 active
    defb    "C=-+"          ; bit 11 active
    align

key_history
    defs    16              ; one byte per key
    align

key_state
    defs    16              ; 0 = released, 1 = pressed
    align

fifo_buf
    defs    16
    align
fifo_head
    defw    0
fifo_tail
    defw    0

mstack          defs    256
mstack_base     align


; =============================================================================
; Initialisation
; =============================================================================

initialisation
    ; enter user mode later
    li      t0, mppMask
    csrc    MSTATUS, t0

    la      t0, mhandler
    csrw    MTVEC, t0

    la      t0, mstack_base
    csrw    MSCRATCH, t0

    ; -------------------------
    ; Timer setup: 1 ms interrupt
    ; -------------------------
    li      t1, TIME_PERIPH
    li      t0, SCAN_MODULUS
    sw      t0, TIME_REG_LIMIT[t1]

    li      t0, 0b1011          ; enable + modulus + interrupt enable
    sw      t0, TIME_REG_CTRL[t1]

    li      t0, bit31           ; clear terminal count
    sw      t0, TIME_REG_CMD[t1]

    ; -------------------------
    ; Interrupt controller
    ; -------------------------
    li      t1, INTR_CTRL
    li      t0, 0
    sw      t0, INTR_MODE[t1]   ; level-sensitive

    li      t0, TIMER_INT
    sw      t0, INTR_EN[t1]

    li      t0, MIE_MEIE
    csrs    MIE, t0

    li      t0, MSTATUS_MIE
    csrs    MSTATUS, t0

    ; -------------------------
    ; PIO setup for keypad
    ; rows 0..3 = outputs
    ; cols 4..7 = inputs
    ; everything else input
    ; -------------------------
    li      t0, PIO_BASE
    
    li      t1, KEY_DIR          ; 0x0000F000
    sw      t1, PIO_DIR[t0]      ; offset 04 = direction

    ; all rows inactive initially
    li      t1, ROW_MASK
    sw      t1, PIO_CLR[t0]      ; turn all output lines off

    ; clear debounce/state/fifo vars
    la      t0, key_history
    li      t1, 16
clear_hist_loop
    sb      zero, [t0]
    addi    t0, t0, 1
    subi    t1, t1, 1
    bnez    t1, clear_hist_loop

    la      t0, key_state
    li      t1, 16
clear_state_loop
    sb      zero, [t0]
    addi    t0, t0, 1
    subi    t1, t1, 1
    bnez    t1, clear_state_loop

    la      t0, fifo_head
    sw      zero, [t0]
    la      t0, fifo_tail
    sw      zero, [t0]

    ; enter user mode
    la      sp, user_stack_base
    la      t0, user_code
    csrw    MEPC, t0
    mret


; =============================================================================
; Trap handler
; =============================================================================

mhandler
    csrrw   sp, MSCRATCH, sp

    ; save everything this handler may disturb
    subi    sp, sp, 60
    sw      ra,  0[sp]
    sw      t0,  4[sp]
    sw      t1,  8[sp]
    sw      t2, 12[sp]
    sw      t3, 16[sp]
    sw      t4, 20[sp]
    sw      t5, 24[sp]
    sw      t6, 28[sp]
    sw      a0, 32[sp]
    sw      a1, 36[sp]
    sw      a2, 40[sp]
    sw      a3, 44[sp]
    sw      a4, 48[sp]
    sw      a5, 52[sp]
    sw      a6, 56[sp]

    csrr    t0, MCAUSE
    bgez    t0, handle_trap

    ; interrupt
    andi    t0, t0, 0xF
    li      t1, 11
    beq     t0, t1, interrupt_11
    j       interrupt_exit

handle_trap
    andi    t0, t0, 0xF
    la      t1, trap_table
    slli    t0, t0, 2
    add     t1, t1, t0
    lw      t1, [t1]
    jr      t1


; =============================================================================
; Interrupt handlers
; =============================================================================

interrupt_11
    ; identify interrupt source
    li      t0, INTR_CTRL
    lw      t1, INTR_RQ[t0]

    andi    t2, t1, TIMER_INT
    beqz    t2, interrupt_exit

    ; acknowledge timer
    li      t0, TIME_PERIPH
    li      t1, bit31
    sw      t1, TIME_REG_CMD[t0]

    ; scan keypad and debounce
    call    scan_keyboard

    j       interrupt_exit


interrupt_exit
    lw      ra,  0[sp]
    lw      t0,  4[sp]
    lw      t1,  8[sp]
    lw      t2, 12[sp]
    lw      t3, 16[sp]
    lw      t4, 20[sp]
    lw      t5, 24[sp]
    lw      t6, 28[sp]
    lw      a0, 32[sp]
    lw      a1, 36[sp]
    lw      a2, 40[sp]
    lw      a3, 44[sp]
    lw      a4, 48[sp]
    lw      a5, 52[sp]
    lw      a6, 56[sp]
    addi    sp, sp, 60
    csrrw   sp, MSCRATCH, sp
    mret


; =============================================================================
; Keyboard scan
; =============================================================================
; Scans all 4 rows once.
; For each key:
;   history = (history << 1) | sample_bit
;   if history == 0xFF and state == 0:
;       state = 1
;       enqueue ASCII
;   if history == 0x00 and state == 1:
;       state = 0
; =============================================================================

scan_keyboard
    li      t0, 0                  ; output-line index: 0..3

scan_row_loop
    ; clear all output lines first
    li      t1, PIO_BASE
    li      t2, ROW_MASK
    sw      t2, PIO_CLR[t1]        ; offset 08

    ; small settle delay
    nop
    nop
    nop
    nop

    ; activate one output line using offset 0C
    la      t2, row_drive_table
    slli    t3, t0, 2              ; table index = row * 4 bytes
    add     t2, t2, t3
    lw      t4, [t2]               ; 0x100, 0x200, 0x400, or 0x800
    sw      t4, PIO_SET[t1]        ; offset 0C = data set

    ; small settle delay
    nop
    nop
    nop
    nop

    ; read input bits 12-15
    lw      t5, PIO_DATA[t1]
    andi    t5, t5, COL_MASK
    srli    t5, t5, 12             ; move bits 12-15 down to bits 0-3

    li      t6, 0                  ; input index: 0..3

scan_col_loop
    ; a0 = 1 if this input bit is active, otherwise 0
    srl     a0, t5, t6
    andi    a0, a0, 1

    ; key index = output_line * 4 + input_index
    slli    a1, t0, 2
    add     a1, a1, t6

    ; update debounce history byte
    la      a2, key_history
    add     a2, a2, a1
    lbu     a3, [a2]

    slli    a3, a3, 1
    or      a3, a3, a0
    andi    a3, a3, 0xFF
    sb      a3, [a2]

    ; check previous stable state
    la      a4, key_state
    add     a4, a4, a1
    lbu     a5, [a4]

    ; if history == FF and previous state was released, new key press
    li      a6, 0xFF
    bne     a3, a6, check_key_release
    bnez    a5, next_key

    li      a5, 1
    sb      a5, [a4]

    ; translate physical key position to ASCII
    la      a6, key_ascii_table
    add     a6, a6, a1
    lbu     a0, [a6]

    ; ignore blank/undefined if needed
    li      a2, ' '
    beq     a0, a2, next_key

    call    fifo_put
    j       next_key

check_key_release
    ; if history == 00, mark key released
    bnez    a3, next_key
    beqz    a5, next_key
    sb      zero, [a4]

next_key
    addi    t6, t6, 1
    li      a0, 4
    blt     t6, a0, scan_col_loop

    addi    t0, t0, 1
    li      a0, 4
    blt     t0, a0, scan_row_loop

    ; turn all output lines off before leaving
    li      t1, PIO_BASE
    li      t2, ROW_MASK
    sw      t2, PIO_CLR[t1]

    ret


; =============================================================================
; FIFO routines
; =============================================================================

fifo_put
    ; a0 = char to enqueue
    la      t0, fifo_head
    lw      t1, [t0]

    la      t2, fifo_tail
    lw      t3, [t2]

    addi    t4, t1, 1
    andi    t4, t4, 0x0F           ; modulo 16

    beq     t4, t3, fifo_put_done  ; full -> drop character

    la      t5, fifo_buf
    add     t5, t5, t1
    sb      a0, [t5]

    sw      t4, [t0]

fifo_put_done
    ret


fifo_get
    ; returns:
    ; a0 = char, or 0 if empty
    la      t0, fifo_head
    lw      t1, [t0]

    la      t2, fifo_tail
    lw      t3, [t2]

    beq     t1, t3, fifo_empty

    la      t4, fifo_buf
    add     t4, t4, t3
    lbu     a0, [t4]

    addi    t3, t3, 1
    andi    t3, t3, 0x0F
    sw      t3, [t2]
    ret

fifo_empty
    li      a0, 0
    ret


; =============================================================================
; Trap dispatch table
; =============================================================================

trap_table
    defw    trap_handler_0
    defw    trap_handler_1
    defw    trap_handler_2
    defw    trap_handler_3
    defw    trap_handler_4
    defw    trap_handler_5
    defw    trap_handler_6
    defw    trap_handler_7
    defw    trap_handler_8
    defw    trap_handler_9
    defw    trap_handler_10
    defw    trap_handler_11
    defw    trap_handler_12
    defw    trap_handler_13
    defw    trap_handler_14
    defw    trap_handler_15

trap_handler_0      j   .
trap_handler_1      j   .
trap_handler_2      j   .
trap_handler_3      j   .
trap_handler_4      j   .
trap_handler_5      j   .
trap_handler_6      j   .
trap_handler_7      j   .

trap_handler_8
    li      t0, ecall_max
    bgeu    a7, t0, ecall_range
    la      t0, ecall_jump
    slli    t1, a7, 2
    add     t0, t0, t1
    lw      t0, [t0]
    jr      t0

trap_handler_9      j   .
trap_handler_10     j   .
trap_handler_11     j   .
trap_handler_12     j   .
trap_handler_13     j   .
trap_handler_14     j   .
trap_handler_15     j   .


; =============================================================================
; Ecall jump table
; =============================================================================

ecall_jump
    defw    ecall_0         ; clear display
    defw    ecall_1         ; print character
    defw    ecall_2         ; print string
    defw    ecall_3         ; next line
    defw    ecall_4         ; unused here
    defw    ecall_5         ; unused here
    defw    ecall_6         ; unused here
    defw    ecall_7         ; unused here
    defw    ecall_8         ; unused here
    defw    ecall_9         ; unused here
    defw    ecall_10        ; get next key char


; =============================================================================
; Ecall service routines
; =============================================================================

ecall_range
    j       .

ecall_0
    li      a0, CLEAR_DIS
    li      a1, LIGHT
    call    lcdSendCommand
    j       ecall_exit

ecall_1
    call    lcdSendCommand
    j       ecall_exit

ecall_2
    call    printString
    j       ecall_exit

ecall_3
    li      a0, SHIFT_NEXT
    li      a1, LIGHT
    call    lcdSendCommand
    j       ecall_exit

ecall_4
    j       ecall_exit

ecall_5
    j       ecall_exit

ecall_6
    j       ecall_exit

ecall_7
    j       ecall_exit

ecall_8
    j       ecall_exit

ecall_9
    j       ecall_exit

ecall_10
    call    fifo_get
    j       ecall_exit

ecall_end


ecall_exit
    csrr    t0, MEPC
    addi    t0, t0, 4
    csrw    MEPC, t0
    j       interrupt_exit


; =============================================================================
; USER SECTION
; =============================================================================

ORG             0x0004_0000

user_code
    la      sp, user_stack_base
    j       START


; =============================================================================
; User constants / strings
; =============================================================================

CLEAR_DIS       EQU     0b0000_0001

msg1            defb    "Keypad input:\0"
                align
msg2            defb    "Press keys...\0"
                align

user_stack      defs    128
user_stack_base align

INCLUDE UserSpaceLib.s


; =============================================================================
; User programme
; =============================================================================

START
    li      a7, 0
    ecall

    la      a0, msg1
    li      a7, 2
    ecall

    li      a7, 3
    ecall

main_loop
    li      a7, 10          ; get next queued key, 0 if none
    ecall

    beqz    a0, main_loop

    ; print returned character in a0
    li      a1, LIGHT
    li      a7, 1
    ecall

    j       main_loop


END
    j       END

