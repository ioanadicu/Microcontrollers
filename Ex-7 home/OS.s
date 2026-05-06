; =============================================================================
; Operating System Initialisation
; Maria-Ioana Dicu
; 12 March 2026
;
; Performs the machine-mode setup needed before entering the user programme.
;
; Responsibilities:
;   - Configure trap handling through MTVEC.
;   - Set up the machine-mode stack through MSCRATCH.
;   - Configure the timer to generate 1 ms interrupts.
;   - Enable timer interrupts through the interrupt controller.
;   - Configure the PIO direction for keypad scanning.
;   - Clear keypad debounce state and FIFO pointers.
;   - Enter user mode using mret.
;
; Notes:
;   - MSTATUS_MPIE is set instead of MSTATUS_MIE. mret then copies MPIE into
;     MIE when entering user mode.
;   - Hardware setup is done in machine mode because user mode cannot access
;     protected I/O addresses directly.
; =============================================================================


; =============================================================================
; Initialisation
; =============================================================================

initialisation
    ; -------------------------------------------------------------------------
    ; Prepare to enter user mode
    ; -------------------------------------------------------------------------

    li      t0, mppMask
    csrc    MSTATUS, t0            ; Clear MPP bits so mret enters user mode

    la      t0, mhandler
    csrw    MTVEC, t0              ; Set trap/interrupt handler entry point

    la      t0, mstack_base
    csrw    MSCRATCH, t0           ; Store machine stack pointer in MSCRATCH


    ; -------------------------------------------------------------------------
    ; Timer setup: 1 ms interrupt period
    ; -------------------------------------------------------------------------

    li      t1, TIME_PERIPH
    li      t0, SCAN_MODULUS
    sw      t0, TIME_REG_LIMIT[t1] ; Timer modulus = SCAN_MODULUS + 1

    li      t0, 0b1011
    sw      t0, TIME_REG_CTRL[t1]  ; Enable timer, modulus mode and interrupts

    li      t0, bit31
    sw      t0, TIME_REG_CMD[t1]   ; Clear terminal-count status bit


    ; -------------------------------------------------------------------------
    ; Interrupt controller setup
    ; -------------------------------------------------------------------------

    li      t1, INTR_CTRL
    li      t0, 0
    sw      t0, INTR_MODE[t1]      ; Use level-sensitive interrupt requests

    li      t0, TIMER_INT
    sw      t0, INTR_EN[t1]        ; Enable timer interrupt source

    li      t0, MIE_MEIE
    csrs    MIE, t0                ; Enable machine external interrupts

    li      t0, MSTATUS_MPIE
    csrs    MSTATUS, t0            ; Enable interrupts after mret


    ; -------------------------------------------------------------------------
    ; PIO setup for keypad
    ; -------------------------------------------------------------------------

    li      t0, PIO_BASE

    li      t1, KEY_DIR
    sw      t1, PIO_DIR[t0]        ; Bits 12-15 input, output lines as outputs

    li      t1, ROW_MASK
    sw      t1, PIO_CLR[t0]        ; Start with all keypad output lines inactive


    ; -------------------------------------------------------------------------
    ; Clear keypad debounce history
    ; -------------------------------------------------------------------------

    la      t0, key_history
    li      t1, 16

clear_hist_loop
    sb      zero, [t0]
    addi    t0, t0, 1
    subi    t1, t1, 1
    bnez    t1, clear_hist_loop


    ; -------------------------------------------------------------------------
    ; Clear keypad stable-state table
    ; -------------------------------------------------------------------------

    la      t0, key_state
    li      t1, 16

clear_state_loop
    sb      zero, [t0]
    addi    t0, t0, 1
    subi    t1, t1, 1
    bnez    t1, clear_state_loop


    ; -------------------------------------------------------------------------
    ; Clear FIFO pointers
    ; -------------------------------------------------------------------------

    la      t0, fifo_head
    sw      zero, [t0]

    la      t0, fifo_tail
    sw      zero, [t0]


    ; -------------------------------------------------------------------------
    ; Enter user mode
    ; -------------------------------------------------------------------------

    la      sp, user_stack_base
    la      t0, user_code
    csrw    MEPC, t0
    mret


; =============================================================================
; Machine-mode stack
; =============================================================================

mstack
    defs    256

mstack_base
    align