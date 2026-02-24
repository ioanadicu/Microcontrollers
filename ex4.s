
;---------------------------------------------------------
;       Exercise 3: Nesting Procedure Calls
;       Maria-Ioana Dicu
;       19 February 2026
;
;       This programme prints 2 strings on the LCD display.
;       
;       External Libraries:
;       - uses DisplayOperations.s
;
;       Known bugs:
;       - none
;
;---------------------------------------------------------

                la      sp, stack_base      ; Set sp pointing to the end of our stack
                j       START

; Defining names to aid readability
CLEAR_DIS       EQU     0b0000_0001         ; DB7-DB0 data to clear the display
CLEAR_CTRL      EQU     0b1000              ; Controls when we want to clear the display

str1            defb    "Hello, world!\0"    ; String that we want to print
                align

str2            defb    "Happy birthday!\0"
                align

stack           defs    100                 ; Defining a chunk of memory (100 bytes) to be used for the stack
stack_base      align                       ; This label is 'just after' the stack base - FULL DESCENDING


ORG		0x0000_0000


;---------------------------------------------------------
; OS SECTION - Machine mode
;---------------------------------------------------------


mhandler
	csrrw sp, MSCRACTH, sp	; Save user SP, get machine SP
	subi sp, sp, 12			; Push working registers
	sw	s1, 8[sp]
	sw 	s0, 4[sp]
	sw 	ra, 0[sp]

	cssr t0, MCAUSE			; Read why we came here
	li 	t1, 8				; User ECALL cause
	beq t0, t1, ecall_handler


ecall_handler

ecall_exit
	csrrw t0, MEPC, t0		; Find the trapping instruction PC
	addi t0, t0, 4			; Correct to a return address
	csrrw t0, MEPC, t0		; Swap back in

	lw ra, [sp]				; Pop working registers
	lw	s0, 4[sp]
	lw	s1, 8[sp]
	addi sp, sp, 12
	csrrw sp, MSCRATCH, sp	; Save Machine SP, get User SP
	mret					; Return



; def start() - main function

; local variables
; - only uses a0, a1 to pass function parameters

START
    ; Clearing the display - we're calling lcdSendCommand for this but with the special clearing signals
    li a0, CLEAR_DIS
    li a1, CLEAR_CTRL
    call lcdSendCommand

    ; calling printString function with string1 as argument
    la a0, str1
    call printString

    ; calling the function to move the cursor to the next line of display
    call moveCursor

    ; calling printString function with string1 as argument
    la a0, str2
    call printString

J END

INCLUDE DisplayOperations.s                 ; Library with Display Operations

END J . ; infinite loop to stop the program

