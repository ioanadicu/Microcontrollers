; =============================================================================
; Keypad Library
; Maria-Ioana Dicu
; 1 May 2026
;
; Provides keypad scanning, software debouncing and character buffering.
;
; The keypad is scanned every timer interrupt by activating one output line at a
; time and reading the four input lines. A key press is accepted only after the
; same key has been read as pressed for 8 consecutive scans.
;
; Keypad wiring:
;   - Output lines: bits 8-11
;   - Input lines : bits 12-15
;
; Functions provided:
;   - scan_keyboard()
;       Scans all keypad lines once and updates debounce state.
;
;   - fifo_put(char)
;       Adds a detected key character to the circular buffer.
;
;   - fifo_get()
;       Returns the next buffered key character, or 0 if the buffer is empty.
;
; Notes:
;   - scan_keyboard is called from the timer interrupt handler.
;   - fifo_get is called from ecall_10.
;   - fifo_buf is not cleared when characters are read; fifo_head/fifo_tail
;     determine whether the buffer is empty or contains unread characters.
; =============================================================================


; =============================================================================
; Keypad lookup tables
; =============================================================================

row_drive_table
    defw    0x00000100      ; Activate output bit 8
    defw    0x00000200      ; Activate output bit 9
    defw    0x00000400      ; Activate output bit 10
    defw    0x00000800      ; Activate output bit 11

key_ascii_table
    defb    "*741"          ; Bit 8 active, inputs 12, 13, 14, 15
    defb    "0852"          ; Bit 9 active, inputs 12, 13, 14, 15
    defb    "#963"        ; Bit 10 active, inputs 12, 13, 14, 15
    defb    "C=-+"          ; Bit 11 active, inputs 12, 13, 14, 15
    align


; =============================================================================
; Keypad state
; =============================================================================

key_history
    defs    16              ; One 8-bit debounce history per key
    align

key_state
    defs    16              ; 0 = released, 1 = already counted as pressed
    align


; =============================================================================
; Key character FIFO
; =============================================================================

fifo_buf
    defs    16              ; Circular buffer for detected key characters
    align

fifo_head
    defw    0               ; Next write position

fifo_tail
    defw    0               ; Next read position


; =============================================================================
; scan_keyboard
; =============================================================================
; Scans the full keypad once.
;
; For each output line:
;   1. Clear all output lines.
;   2. Activate one output line.
;   3. Read input bits 12-15.
;   4. Update each key's debounce history.
;   5. Add a character to the FIFO only on a new stable press.
;
; Debounce rule:
;   - history == 0xFF means stable pressed.
;   - history == 0x00 means stable released.
;
; Registers used:
;   t0 = output-line index
;   t1 = PIO base address
;   t2 = mask/table pointer
;   t3 = table offset / column mask
;   t4 = selected output-line bit pattern
;   t5 = current input sample
;   t6 = input-line index
;   a0-a6 = temporary values and FIFO argument
;
; =============================================================================

scan_keyboard
    subi    sp, sp, 4
    sw      ra, 0[sp]

    li      t0, 0                  ; Start with output line 0, corresponding to bit 8

scan_row_loop
    ; -------------------------------------------------------------------------
    ; Clear all output lines before activating the next one
    ; -------------------------------------------------------------------------

    li      t1, PIO_BASE            ; t1 = address of keyboard PIO device
    li      t2, ROW_MASK            ; t2 = mask for all ouput lines (ROW_MASK = bits 8, 9, 10, 11)
    sw      t2, PIO_CLR[t1]         ; offset 08, turn OFF all output lines

    nop
    nop
    nop
    nop


    ; -------------------------------------------------------------------------
    ; Activate one output line
    ; -------------------------------------------------------------------------

    la      t2, row_drive_table     ; t2 = address of the table containing bit 8, 9, 10, 11
    slli    t3, t0, 2               ; Word table offset = output index * 4
    add     t2, t2, t3              ; t2 now points to correct table entry
    lw      t4, [t2]                ; Load 0x100, 0x200, 0x400 or 0x800
    sw      t4, PIO_SET[t1]         ; offset 0C = data set, activating the line

    nop
    nop
    nop
    nop


    ; -------------------------------------------------------------------------
    ; Read input lines
    ; -------------------------------------------------------------------------

    lw      t5, PIO_DATA[t1]       ; Read PIO pin state
    li      t3, COL_MASK
    and     t5, t5, t3             ; Keep only bits 12-15
    srli    t5, t5, 12             ; Move input bits down to bits 0-3

    li      t6, 0                  ; Start checking input line 0, original bit 12


scan_col_loop
    ; -------------------------------------------------------------------------
    ; Extract current input bit
    ; -------------------------------------------------------------------------

    srl     a0, t5, t6             ; Move selected input bit into bit 0
    andi    a0, a0, 1              ; a0 = 1 if this key is currently active


    ; -------------------------------------------------------------------------
    ; Calculate key index
    ; -------------------------------------------------------------------------

    slli    a1, t0, 2              ; output_index * 4
    add     a1, a1, t6             ; key_index = output_index * 4 + input_index


    ; -------------------------------------------------------------------------
    ; Update debounce history
    ; -------------------------------------------------------------------------

    la      a2, key_history
    add     a2, a2, a1             ; Point to history byte for this key
    lbu     a3, [a2]               ; Load previous 8-bit history

    slli    a3, a3, 1              ; Shift previous samples left
    or      a3, a3, a0             ; Insert newest sample into bit 0
    andi    a3, a3, 0xFF           ; Keep only 8 samples
    sb      a3, [a2]               ; Store updated history


    ; -------------------------------------------------------------------------
    ; Load stable state for this key
    ; -------------------------------------------------------------------------

    la      a4, key_state
    add     a4, a4, a1             ; Point to state byte for this key
    lbu     a5, [a4]               ; 0 = released, 1 = already pressed


    ; -------------------------------------------------------------------------
    ; Detect new stable press
    ; -------------------------------------------------------------------------

    li      a6, 0xFF
    bne     a3, a6, check_key_release
    bnez    a5, next_key           ; Already counted, so do not repeat

    li      a5, 1
    sb      a5, [a4]               ; Mark key as pressed


    ; -------------------------------------------------------------------------
    ; Translate key position into ASCII character
    ; -------------------------------------------------------------------------

    la      a6, key_ascii_table     ; a6 = address of the table that maps key position to character
    add     a6, a6, a1              ; a6 = address of the character for this key index
    lbu     a0, [a6]                ; a0 = ASCII character for this key

    li      a2, ' '
    beq     a0, a2, next_key        ; Ignore blank entries


    ; -------------------------------------------------------------------------
    ; Add new key press to FIFO
    ; -------------------------------------------------------------------------

    subi    sp, sp, 8
    sw      t0, 4[sp]
    sw      t6, 0[sp]

    call    fifo_put

    lw      t6, 0[sp]
    lw      t0, 4[sp]
    addi    sp, sp, 8

    j       next_key


check_key_release
    ; -------------------------------------------------------------------------
    ; Detect stable release
    ; -------------------------------------------------------------------------

    bnez    a3, next_key           ; Not yet fully released
    beqz    a5, next_key           ; Already marked as released
    sb      zero, [a4]             ; Mark key as released


next_key
    ; -------------------------------------------------------------------------
    ; Move to next input or output line
    ; -------------------------------------------------------------------------

    addi    t6, t6, 1
    li      a0, 4
    blt     t6, a0, scan_col_loop

    addi    t0, t0, 1
    li      a0, 4
    blt     t0, a0, scan_row_loop


    ; -------------------------------------------------------------------------
    ; Turn all output lines off before returning
    ; -------------------------------------------------------------------------

    li      t1, PIO_BASE
    li      t2, ROW_MASK
    sw      t2, PIO_CLR[t1]

    lw      ra, 0[sp]
    addi    sp, sp, 4
    ret


; =============================================================================
; fifo_put
; =============================================================================
; Adds one character to the circular FIFO.
;
; Input:
;   a0 = ASCII character to enqueue
;
; Behaviour:
;   - If the FIFO is full, the new character is dropped.
;   - fifo_head points to the next write position.
;   - fifo_tail points to the next read position.
;
; Registers used:
;   t0-t5
; =============================================================================

fifo_put
    la      t0, fifo_head
    lw      t1, [t0]               ; t1 = current head

    la      t2, fifo_tail
    lw      t3, [t2]               ; t3 = current tail

    addi    t4, t1, 1
    andi    t4, t4, 0x0F           ; Wrap around 16-byte buffer

    beq     t4, t3, fifo_put_done  ; If next head equals tail, FIFO is full

    la      t5, fifo_buf
    add     t5, t5, t1
    sb      a0, [t5]               ; Store character at current head

    sw      t4, [t0]               ; Update head

fifo_put_done
    ret


; =============================================================================
; fifo_get
; =============================================================================
; Removes and returns one character from the circular FIFO.
;
; Output:
;   a0 = next ASCII character, or 0 if the FIFO is empty
;
; Behaviour:
;   - fifo_head == fifo_tail means the FIFO is empty.
;   - The character byte is not cleared from fifo_buf after reading.
;
; Registers used:
;   t0-t4
; =============================================================================

fifo_get
    la      t0, fifo_head
    lw      t1, [t0]               ; t1 = current head

    la      t2, fifo_tail
    lw      t3, [t2]               ; t3 = current tail

    beq     t1, t3, fifo_empty

    la      t4, fifo_buf
    add     t4, t4, t3
    lbu     a0, [t4]               ; Return oldest unread character

    addi    t3, t3, 1
    andi    t3, t3, 0x0F           ; Wrap around 16-byte buffer
    sw      t3, [t2]               ; Update tail

    ret

fifo_empty
    li      a0, 0
    ret