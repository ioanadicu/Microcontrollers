; =============================================================================
; Exercise 7: Key Debouncing and Keyboard Scanning
; Maria-Ioana Dicu
; =============================================================================

ORG             0x0000_0000
j               initialisation

INCLUDE         Definitions.s
INCLUDE         DisplayOperations.s
INCLUDE         Keypad.s
INCLUDE         TrapHandler.s
INCLUDE         OS.s


; =============================================================================
; USER SECTION
; =============================================================================

ORG             0x0004_0000

user_code
    la      sp, user_stack_base
    j       START


; =============================================================================
; User strings / stack
; =============================================================================

msg1            defb    "Keypad input:\0"
                align

user_stack      defs    128
user_stack_base align

INCLUDE         UserSpaceLib.s


; =============================================================================
; User programme
; =============================================================================

START
    li      a7, ECALL_CLEAR_DISPLAY
    ecall

    la      a0, msg1
    li      a7, ECALL_PRINT_STRING
    ecall

    li      a7, ECALL_NEXT_LINE
    ecall

main_loop
    li      a7, ECALL_GET_KEY
    ecall

    beqz    a0, main_loop

    ; li      a1, LIGHT | RS
    li      a7, ECALL_PRINT_CHAR
    ecall

    j       main_loop

END
    j       END