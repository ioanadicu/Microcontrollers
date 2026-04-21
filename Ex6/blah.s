; =============================================================================
; Exercise 6: Interrupt-driven stopwatch
; Maria-Ioana Dicu
; 16 March 2026
;
; Starting point: Exercise 5 / system-call stopwatch.
; This version keeps the ECALL interface for LCD/buttons, but replaces
; timer polling with a machine external interrupt from the interrupt
; controller. The timer peripheral raises local interrupt bit 4.
;
; Design:
;   - User mode still handles the application state machine.
;   - Machine mode handles ECALL traps and external interrupts.
;   - Timer ISR acknowledges the timer and sets tick_flag = 1.
;   - User mode consumes tick_flag and updates h:m:s on the LCD.
;
; Notes:
;   - Interrupts and exceptions both arrive through MTVEC.
;   - MCAUSE MSB = 0  => exception / trap
;   - MCAUSE MSB = 1  => interrupt
;   - For ECALL return, MEPC must be incremented by 4.
;   - For interrupt return, MEPC must NOT be incremented.
; =============================================================================




; =============================================================================
; OS SECTION
; Machine mode
; =============================================================================


        ORG             0x0000_0000
        j               initialisation


        INCLUDE         DisplayOperations.s




; =============================================================================
; Constants
; =============================================================================


CLEAR_DIS       EQU             0b0000_0001
LIGHT           EQU             0b1000
SHIFT_NEXT      EQU             0b1100_0000


SECOND          EQU             0x18967F
MODULUS         EQU             999999
REGINIT         EQU             0b11


TIME_PERIPH     EQU             0x0001_0200
TIME_REG_LIMIT  EQU             0x04
TIME_REG_STATUS EQU             0x0C
TIME_REG_CMD    EQU             0x10
TIME_REG_CTRL   EQU             0x14


BUTTONS         EQU             0x0001_0001
BTTN1           EQU             0b0001
BTTN2           EQU             0b0010
BTTN3           EQU             0b0100


INT_CTRL        EQU             0x0001_0400
INT_ENABLES     EQU             0x04
INT_REQUESTS    EQU             0x08
INT_MODE        EQU             0x0C


TIMER_INT_BIT   EQU             0b0001_0000          ; local interrupt bit 4
BUTTON_INT_BIT  EQU             0b0010_0000          ; local interrupt bit 5


MSTATUS_MIE     EQU             0x8                  ; MSTATUS bit 3
MIE_MEIE        EQU             0x800                ; MIE bit 11
MCAUSE_U_ECALL  EQU             8
MCAUSE_M_EXT    EQU             11


MPP_MASK        EQU             0x00001800           ; MSTATUS.MPP bits
BIT0            EQU             0b1
BIT31           EQU             0x8000_0000


ECALL_MAX       EQU             (ecall_end - ecall_0) / 4




; =============================================================================
; Machine-mode initialisation
; =============================================================================


initialisation
    li              t0, MPP_MASK
    csrc            MSTATUS, t0          ; drop return privilege to U mode


    la              t0, mhandler
    csrw            MTVEC, t0


    la              t0, mstack_base
    csrw            MSCRATCH, t0


    ; -------------------------------------------------------------
    ; Timer configuration: 1 second periodic interrupt
    ; bit0 = enable
    ; bit1 = modulus/reload mode
    ; bit3 = interrupt output enable
    ; -------------------------------------------------------------
    li              t1, TIME_PERIPH
    li              t0, MODULUS
    sw              t0, TIME_REG_LIMIT[t1]


    li              t0, 0b1011
    sw              t0, TIME_REG_CTRL[t1]


    ; Clear any stale terminal-count status before enabling IRQ flow
    li              t0, BIT31
    sw              t0, TIME_REG_CMD[t1]


    ; -------------------------------------------------------------
    ; Interrupt controller setup
    ; local bit 4 = timer
    ; leave mode register at 0 => level-sensitive inputs
    ; -------------------------------------------------------------
    li              t1, INT_CTRL
    li              t0, 0
    sw              t0, INT_MODE[t1]


    li              t0, TIMER_INT_BIT
    sw              t0, INT_ENABLES[t1]


    ; -------------------------------------------------------------
    ; Enable machine external interrupts
    ; -------------------------------------------------------------
    li              t0, MIE_MEIE
    csrs            MIE, t0


    li              t0, MSTATUS_MIE
    csrs            MSTATUS, t0


    ; -------------------------------------------------------------
    ; Enter user mode
    ; -------------------------------------------------------------
    la              sp, user_stack_base
    la              t0, user_code
    csrw            MEPC, t0
    mret




; =============================================================================
; Trap handler entry
; =============================================================================


mhandler
    csrrw           sp, MSCRATCH, sp     ; swap user SP for machine SP
    subi            sp, sp, 24
    sw              ra,  0[sp]
    sw              t0,  4[sp]
    sw              t1,  8[sp]
    sw              t2, 12[sp]
    sw              s0, 16[sp]
    sw              s1, 20[sp]


    csrr            t0, MCAUSE
    bgez            t0, handle_exception ; MSB clear => exception/trap


    ; Interrupt path: use low bits as cause code
    andi            t0, t0, 0xF
    li              t1, MCAUSE_M_EXT
    beq             t0, t1, interrupt_handler_11
    j               interrupt_exit       ; ignore unknown interrupts




; =============================================================================
; Exception / trap dispatch table
; =============================================================================


handle_exception
    andi            t0, t0, 0xF
    la              t1, trap_table
    slli            t0, t0, 2
    add             t1, t0, t1
    lw              t1, [t1]
    jr              t1


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
; Interrupt dispatch table
; These are the architectural interrupt causes from the manual.
; In this lab we only need cause 11 = machine external interrupt.
; =============================================================================


interrupt_table
    defw    interrupt_handler_0
    defw    interrupt_handler_1
    defw    interrupt_handler_2
    defw    interrupt_handler_3
    defw    interrupt_handler_4
    defw    interrupt_handler_5
    defw    interrupt_handler_6
    defw    interrupt_handler_7
    defw    interrupt_handler_8
    defw    interrupt_handler_9
    defw    interrupt_handler_10
    defw    interrupt_handler_11
    defw    interrupt_handler_12
    defw    interrupt_handler_13
    defw    interrupt_handler_14
    defw    interrupt_handler_15




; =============================================================================
; Exception handlers
; =============================================================================


trap_handler_0      j       .
trap_handler_1      j       .
trap_handler_2      j       .
trap_handler_3      j       .
trap_handler_4      j       .
trap_handler_5      j       .
trap_handler_6      j       .
trap_handler_7      j       .


trap_handler_8                              ; ECALL from user mode
    li              t0, ECALL_MAX
    bgeu            a7, t0, ecall_range
    la              t0, ecall_jump
    slli            t1, a7, 2
    add             t0, t0, t1
    lw              t0, [t0]
    jr              t0


trap_handler_9      j       .
trap_handler_10     j       .
trap_handler_11     j       .
trap_handler_12     j       .
trap_handler_13     j       .
trap_handler_14     j       .
trap_handler_15     j       .




; =============================================================================
; Interrupt handlers
; Architectural causes. Only machine external is used here.
; =============================================================================


interrupt_handler_0     j       interrupt_exit
interrupt_handler_1     j       interrupt_exit
interrupt_handler_2     j       interrupt_exit
interrupt_handler_3     j       interrupt_exit
interrupt_handler_4     j       interrupt_exit
interrupt_handler_5     j       interrupt_exit
interrupt_handler_6     j       interrupt_exit
interrupt_handler_7     j       interrupt_exit
interrupt_handler_8     j       interrupt_exit
interrupt_handler_9     j       interrupt_exit
interrupt_handler_10    j       interrupt_exit


interrupt_handler_11                        ; Machine external interrupt
    ; Read the local interrupt controller to see which source fired.
    li              t0, INT_CTRL
    lw              t1, INT_REQUESTS[t0]


    ; Timer local interrupt bit 4?
    andi            t2, t1, TIMER_INT_BIT
    beqz            t2, interrupt_exit


    ; Acknowledge timer source by clearing terminal-count status.
    li              t0, TIME_PERIPH
    li              t2, BIT31
    sw              t2, TIME_REG_CMD[t0]


    ; Tell user-mode foreground code that one second elapsed.
    la              t0, tick_flag
    li              t1, 1
    sw              t1, [t0]


    j               interrupt_exit


interrupt_handler_12    j       interrupt_exit
interrupt_handler_13    j       interrupt_exit
interrupt_handler_14    j       interrupt_exit
interrupt_handler_15    j       interrupt_exit




; =============================================================================
; ECALL dispatch table
; =============================================================================


ecall_jump
    defw    ecall_0
    defw    ecall_1
    defw    ecall_2
    defw    ecall_3
    defw    ecall_4
    defw    ecall_5
    defw    ecall_6
    defw    ecall_7
    defw    ecall_8
    defw    ecall_9




; =============================================================================
; ECALL service routines
; =============================================================================


ecall_range     j       .


ecall_0
    li              a0, CLEAR_DIS
    li              a1, LIGHT
    call            lcdSendCommand
    j               ecall_exit


ecall_1
    call            lcdSendCommand
    j               ecall_exit


ecall_2
    call            printString
    j               ecall_exit


ecall_3
    li              a0, SHIFT_NEXT
    li              a1, LIGHT
    call            lcdSendCommand
    j               ecall_exit


ecall_4                                      ; Optional software re-initialise timer
    li              t0, MODULUS
    li              t1, TIME_PERIPH
    sw              t0, TIME_REG_LIMIT[t1]
    li              t0, 0b1011
    sw              t0, TIME_REG_CTRL[t1]
    li              t0, BIT31
    sw              t0, TIME_REG_CMD[t1]
    j               ecall_exit


ecall_5
    li              t0, BUTTONS
    lb              a0, [t0]
    j               ecall_exit


ecall_6
    li              t0, TIME_PERIPH
    lw              a0, TIME_REG_STATUS[t0]
    j               ecall_exit


ecall_7
    li              t0, BIT31
    li              t1, TIME_PERIPH
    sw              t0, TIME_REG_CMD[t1]
    j               ecall_exit


ecall_8                                      ; Pause timer
    li              t0, BIT0
    li              t1, TIME_PERIPH
    sw              t0, TIME_REG_CMD[t1]
    j               ecall_exit


ecall_9                                      ; Resume timer
    li              t0, 0b1011
    li              t1, TIME_PERIPH
    sw              t0, TIME_REG_CTRL[t1]
    j               ecall_exit


ecall_end




; =============================================================================
; Return paths
; =============================================================================


ecall_exit
    csrr            t0, MEPC
    addi            t0, t0, 4          ; skip the ECALL instruction
    csrw            MEPC, t0
    j               trap_restore


interrupt_exit
    ; Do NOT increment MEPC for interrupts.
    j               trap_restore


trap_restore
    lw              ra,  0[sp]
    lw              t0,  4[sp]
    lw              t1,  8[sp]
    lw              t2, 12[sp]
    lw              s0, 16[sp]
    lw              s1, 20[sp]
    addi            sp, sp, 24
    csrrw           sp, MSCRATCH, sp
    mret




; =============================================================================
; Machine stack
; =============================================================================


mstack          defs    100
mstack_base     align






; =============================================================================
; USER SECTION
; User mode application
; =============================================================================


               ORG             0x0004_0000


user_code
               la              sp, user_stack_base
               j               START




; =============================================================================
; Strings and variables
; =============================================================================


startLine1      defb    "Press button SW1\0"
               align
startLine2      defb    " to start.\0"
               align
runLine1        defb    "Current time: \0"
               align
strh            defb    "h \0"
               align
strm            defb    "m \0"
               align
strs            defb    "s \0"
               align
pauseLine1      defb    "Pause SW1-Resume\0"
               align
pauseLine2      defb    "      SW3-Reset \0"
               align


tick_flag       defw    0
               align


user_stack      defs    100
user_stack_base align


               INCLUDE UserSpaceLib.s




; =============================================================================
; User application
; s0 = seconds, s1 = minutes, s2 = hours
; =============================================================================


START
    call            displayStartScreen


waitForStart
    li              a7, 5
    ecall
    andi            a0, a0, BTTN1
    beqz            a0, waitForStart


    li              s0, 0
    li              s1, 0
    li              s2, 0


    la              t0, tick_flag
    sw              zero, [t0]


    li              a7, 4              ; ensure timer starts cleanly
    ecall


    call            displayTime
    j               running


running
    ; Still poll buttons in user mode for pause.
    li              a7, 5
    ecall
    andi            t0, a0, BTTN2
    bnez            t0, paused


    ; Consume one-second tick set by timer interrupt handler.
    la              t0, tick_flag
    lw              t1, [t0]
    beqz            t1, running


    sw              zero, [t0]


    addi            s0, s0, 1
    li              t2, 60
    blt             s0, t2, showTime


    li              s0, 0
    addi            s1, s1, 1
    blt             s1, t2, showTime


    li              s1, 0
    addi            s2, s2, 1


showTime
    call            displayTime
    j               running


paused
    li              a7, 8
    ecall
    call            displayPauseScreen


pauseLoop
    li              a7, 5
    ecall


    andi            t0, a0, BTTN1
    bnez            t0, resumeTimer


    andi            t0, a0, BTTN3
    bnez            t0, resetTimer


    j               pauseLoop


resumeTimer
    li              a7, 9
    ecall
    call            displayTime
    j               running


resetTimer
    li              s0, 0
    li              s1, 0
    li              s2, 0
    la              t0, tick_flag
    sw              zero, [t0]
    j               START


END             j       .



