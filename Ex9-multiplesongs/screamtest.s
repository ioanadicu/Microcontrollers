; =============================================================================
; SCREAM TEST
; If the hardware works, this will make a continuous, loud tone.
; =============================================================================

ORG             0x0000_0000

; --- Hardware Addresses ---
SYS_CTRL_BASE   EQU     0x0001_0700
PIN_FUNC_OFFSET EQU     0x08
BUZZER_BASE     EQU     0x0002_0000

START
    ; 1. Route the physical pins (Bits 6 & 7) to our custom Verilog
    li      t0, SYS_CTRL_BASE
    li      t1, 0xC0               ; 0xC0 = 1100_0000 in binary
    sw      t1, PIN_FUNC_OFFSET[t0]

    ; 2. Turn the buzzer ON permanently with a ~1.3 kHz tone
    li      t0, BUZZER_BASE
    li      t1, 15000              ; Half-period for a clear, audible squeal
    sw      t1, 0[t0]

    ; 3. Freeze 
freeze
    j       freeze