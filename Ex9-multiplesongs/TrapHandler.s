; =============================================================================
; Trap and Interrupt Handler
; Maria-Ioana Dicu
; 12 March 2026
;
; Handles traps and interrupts for Exercise 7.
;
; Responsibilities:
;   - Save and restore user context when entering machine mode.
;   - Dispatch synchronous traps using MCAUSE.
;   - Handle user-mode ecalls.
;   - Handle timer interrupts and call the keypad scanner.
;   - Return to user mode using mret.
;
; Ecall services:
;   a7 = 0   Clear display
;   a7 = 1   Print character in a0 using LCD control bits in a1
;   a7 = 2   Print null-terminated string pointed to by a0
;   a7 = 3   Move cursor to second line
;   a7 = 4   Get next keypad character from FIFO, returns char in a0 or 0
;
; Notes:
;   - ECALL returns must increment MEPC by 4.
;   - Interrupt returns must not increment MEPC.
;   - ecall_10 saves a0 back into the saved-context slot so the returned
;     character is not overwritten during context restore.
; =============================================================================


; =============================================================================
; Ecall table size
; =============================================================================

ecall_max       EQU     (ecall_jump_end - ecall_jump) / 4


; =============================================================================
; Trap handler entry
; =============================================================================

mhandler
    csrrw   sp, MSCRATCH, sp       ; Save user SP, load machine SP

    ; -------------------------------------------------------------------------
    ; Save registers used by trap, interrupt and ecall handling
    ; -------------------------------------------------------------------------

    subi    sp, sp, 68
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
    sw      s0, 60[sp]
    sw      s1, 64[sp]

    ; -------------------------------------------------------------------------
    ; Work out whether this was an interrupt or synchronous trap
    ; -------------------------------------------------------------------------

    csrr    t0, MCAUSE
    bgez    t0, handle_trap        ; Interrupts have the top bit set

    ; -------------------------------------------------------------------------
    ; Interrupt path
    ; -------------------------------------------------------------------------

    andi    t0, t0, 0xF            ; Keep interrupt cause number
    li      t1, 11                 ; Cause 11 = machine external interrupt
    beq     t0, t1, interrupt_11

    j       interrupt_exit         ; Ignore other interrupt causes


; =============================================================================
; Synchronous trap dispatch
; =============================================================================

handle_trap
    andi    t0, t0, 0xF            ; Keep cause number in range 0-15
    la      t1, trap_table
    slli    t0, t0, 2              ; Word offset into table
    add     t1, t1, t0
    lw      t1, [t1]               ; Load handler address
    jr      t1


; =============================================================================
; Interrupt handler: machine external interrupt
; =============================================================================

interrupt_11
    ; -------------------------------------------------------------------------
    ; Check whether the timer caused this interrupt
    ; -------------------------------------------------------------------------

    li      t0, INTR_CTRL
    lw      t1, INTR_RQ[t0]

    andi    t2, t1, TIMER_INT
    beqz    t2, interrupt_exit


    ; -------------------------------------------------------------------------
    ; Acknowledge timer interrupt
    ; -------------------------------------------------------------------------

    li      t0, TIME_PERIPH
    li      t1, bit31
    sw      t1, TIME_REG_CMD[t0]


    ; -------------------------------------------------------------------------
    ; Scan keypad once per timer interrupt
    ; -------------------------------------------------------------------------

    call    scan_keyboard

    la      t0, timer_ticks
    lw      t1, [t0]
    addi    t1, t1, 1
    sw      t1, [t0]

    j       interrupt_exit


; =============================================================================
; Trap / interrupt common exit
; =============================================================================

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
    lw      s0, 60[sp]
    lw      s1, 64[sp]
    addi    sp, sp, 68

    csrrw   sp, MSCRATCH, sp       ; Save machine SP, restore user SP
    mret


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


; =============================================================================
; Individual trap handlers
; =============================================================================

trap_handler_0      j   .          ; Instruction address misaligned
trap_handler_1      j   .          ; Instruction access fault
trap_handler_2      j   .          ; Illegal instruction
trap_handler_3      j   .          ; Breakpoint
trap_handler_4      j   .          ; Load address misaligned
trap_handler_5      j   .          ; Load access fault
trap_handler_6      j   .          ; Store address misaligned
trap_handler_7      j   .          ; Store access fault


; =============================================================================
; User-mode ecall handler
; =============================================================================

trap_handler_8
    li      t0, ecall_max
    bgeu    a7, t0, ecall_range    ; Reject unknown ecall numbers

    la      t0, ecall_jump
    slli    t1, a7, 2              ; Word offset = ecall number * 4
    add     t0, t0, t1
    lw      t0, [t0]               ; Load service routine address
    jr      t0


trap_handler_9      j   .          ; Environment call from S-mode
trap_handler_10     j   .          ; Reserved
trap_handler_11     j   .          ; Environment call from M-mode
trap_handler_12     j   .          ; Instruction page fault
trap_handler_13     j   .          ; Load page fault
trap_handler_14     j   .          ; Reserved
trap_handler_15     j   .          ; Store page fault


; =============================================================================
; Ecall jump table
; =============================================================================

ecall_jump
    defw    ecall_0                ; Clear display
    defw    ecall_1                ; Print character
    defw    ecall_2                ; Print string
    defw    ecall_3                ; Move cursor to second line
    defw    ecall_4                ; Get next keypad character
    defw    ecall_5                ; Play note on custom Buzzer hardware
    defw    ecall_6                ; Read board buttons (SWs)
ecall_jump_end

; =============================================================================
; Ecall service routines
; =============================================================================

ecall_range
    j       .                      ; Invalid ecall number


ecall_0
    li      a0, CLEAR_DIS
    li      a1, LIGHT
    call    lcdSendCommand
    j       ecall_exit


ecall_1
    li      a1, LIGHT | RS ; new change!!
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
    call    fifo_get
    sw      a0, 32[sp]             ; Preserve return value through restore
    j       ecall_exit

ecall_5
    li      t0, BUZZER_BASE
    sw      a0, 0[t0]              ; Write the requested period to the hardware
    j       ecall_exit

ecall_6
    li      t0, BUTTONS
    lb      a0, [t0]
    sw      a0, 32[sp]             ; Preserve return value through restore
    j       ecall_exit
    

; =============================================================================
; Ecall return
; =============================================================================

ecall_exit
    csrr    t0, MEPC
    addi    t0, t0, 4              ; Return after the ecall instruction
    csrw    MEPC, t0

    j       interrupt_exit