; =============================================================================
; Definitions
; Maria-Ioana Dicu
; 12 March 2026
;
; Shared constants used by the Exercise 7 operating-system code, trap handler,
; timer setup, interrupt controller and memory-mapped I/O routines.
;
; This file contains only compile-time constants. It does not reserve memory or
; contain executable code.
;
; Notes:
;   - Hardware devices are accessed only from machine mode.
;   - The user application should access hardware indirectly through ecalls.
; =============================================================================


; =============================================================================
; General bit masks
; =============================================================================

bit0            EQU     0x0000_0001
bit31           EQU     0x8000_0000


; =============================================================================
; Machine status / interrupt control constants
; =============================================================================

mppMask         EQU     0x18967F        ; Mask used to clear MPP bits before mret

MSTATUS_MPIE    EQU     0x80            ; Previous machine interrupt enable
MIE_MEIE        EQU     0x800           ; Machine external interrupt enable


; =============================================================================
; Interrupt controller
; =============================================================================

INTR_CTRL       EQU     0x0001_0400
INTR_EN         EQU     0x04
INTR_RQ         EQU     0x08
INTR_MODE       EQU     0x0C

TIMER_INT       EQU     0b00_0001_0000  ; Timer interrupt source bit


; =============================================================================
; Timer peripheral
; =============================================================================

TIME_PERIPH     EQU     0x0001_0200

TIME_REG_LIMIT  EQU     0x04
TIME_REG_STATUS EQU     0x0C
TIME_REG_CMD    EQU     0x10
TIME_REG_CTRL   EQU     0x14


; =============================================================================
; Parallel I/O peripheral
; =============================================================================

PIO_BASE        EQU     0x0001_0300

PIO_DATA        EQU     0x00
PIO_DIR         EQU     0x04
PIO_CLR         EQU     0x08
PIO_SET         EQU     0x0C


; =============================================================================
; LCD command constants
; =============================================================================

CLEAR_DIS       EQU     0b0000_0001


; =============================================================================
; Keypad scan configuration
; =============================================================================

ROW_MASK        EQU     0x00000F00      ; Bits 8-11 are keypad output lines
COL_MASK        EQU     0x0000F000      ; Bits 12-15 are keypad input lines

KEY_DIR         EQU     0x0000F000      ; Bits 12-15 input, all other bits output

SCAN_MODULUS    EQU     999             ; 1 ms interrupt period, assuming 1 us timer ticks


; =============================================================================
; Ecall numbers
; =============================================================================

ECALL_CLEAR_DISPLAY     EQU     0
ECALL_PRINT_CHAR        EQU     1
ECALL_PRINT_STRING      EQU     2
ECALL_NEXT_LINE         EQU     3
ECALL_GET_KEY           EQU     10