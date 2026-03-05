;---------------------------------------------------------
;       Exercise 4: System Calls
;       Maria-Ioana Dicu
;       26 February 2026
;
;       "Hello world" programme modified to run as an
;			application within a primitive OS
;       
;       External Libraries:
;       - uses DisplayOperations.s
;
;       Known bugs:
;       - none
;---------------------------------------------------------

ORG		0x0000_0000
J 		initialisation
INCLUDE DisplayOperations.s                 ; Library with Display Operations

;---------------------------------------------------------
; OS SECTION - Machine mode
;---------------------------------------------------------

initialisation
	li 		t0, 0x0000_1800		; Load MPP mask - bits 12 & 11
	csrc	MSTATUS, t0			; Clear MPP bits in status
	la 		t0, mhandler		; Point at trap handler code start
	csrw 	MTVEC, t0			; Save address in system CSR
	la 		t0, mstack_base		; Point at machine stack
	csrw 	MSCRATCH, t0		; Copy 'machine' SP for use in handler
	la 		sp, user_stack_base	; change SP to user space
	la 		ra, user_code		; Point at user code start
	csrw 	MEPC, ra			; Save as 'return address'
	mret						; 'Return' to programme start

mhandler
	csrrw 	sp, MSCRATCH, sp	; Save user SP, get machine SP
	subi 	sp, sp, 12			; Push working registers
	sw		s1, 8[sp]
	sw 		s0, 4[sp]
	sw 		ra, 0[sp]

	csrr 	t0, MCAUSE			; Read why we came here
	andi 	t0, t0, 0xF			; Cautious - guarantees in range
	la 		t1, trap_table		; Pointer to table
	slli 	t0, t0, 2			; Multiply cause to word offset
	add 	t1, t0, t1			; Index into table
	lw 		t1, [t1]			; Get handler address
	jr 		t1					; Call specific handler (RA is implicit)

trap_table
	defw	trap_handler_0		; Instruction address misaligned
	defw	trap_handler_1		; Instruction access fault
	defw	trap_handler_2		; Illegal instruction
	defw	trap_handler_3  	; Breakpoint
	defw	trap_handler_4		; Load address misaligned
	defw 	trap_handler_5  	; Load access fault
	defw	trap_handler_6 		; Store address misaligned
	defw	trap_handler_7		; Store access fault
	defw	trap_handler_8		; Environment call from U-mode
	defw	trap_handler_9		; Environment call from S-mode
	defw 	trap_handler_10		; Reserved
	defw 	trap_handler_11 	; Environment call from M-mode
	defw 	trap_handler_12 	; Instruction page fault
	defw 	trap_handler_13 	; Load page fault
	defw 	trap_handler_14 	; Reserved for future standard use
	defw 	trap_handler_15 	; Store page fault

trap_handler_0		j	.		; Instruction address misaligned
trap_handler_1		j 	.		; Instruction access fault
trap_handler_2		j 	.		; Illegal instruction
trap_handler_3  	j 	. 		; Breakpoint
trap_handler_4		j 	. 		; Load address misaligned
trap_handler_5  	j 	. 		; Load access fault
trap_handler_6 		j 	. 		; Store address misaligned
trap_handler_7		j 	. 		; Store access fault

trap_handler_8					; Environment call from U-mode
	li		t0, ecall_max		; Check argument is legitimate
	bgeu	a7, t0, ecall_range	; Out of range default
	la 		t0, ecall_jump		; Point at table
	slli	t1, a7, 2			; Calculate index (in words)
	add 	t0, t0, t1			;
	lw 		t0, [t0]			; Load address of service routine
	jr 		t0					;  and jump to it

ecall_jump
	defw 	ecall_0				; Ecall for cleaning screen
	defw	ecall_1				; Ecall for displaying a character
	defw 	ecall_2				; Ecall for displaying a string
	defw 	ecall_3 			; Ecall for going to next line on display
	defw 	ecall_4				; Initialising counter
	defw 	ecall_5				; Getting buttons
	defw 	ecall_6				; Getting Status register bits
	defw 	ecall_7				; Print Hex
	defw 	ecall_8				; bit 31 reset
	defw 	ecall_9				; Print decimal
	defw 	ecall_10			; Pause timer
	defw 	ecall_11 			; Resume timer

trap_handler_9		j 	. 		; Environment call from S-mode
trap_handler_10		j 	. 		; Reserved
trap_handler_11 	j 	. 		; Environment call from M-mode
trap_handler_12 	j 	. 		; Instruction page fault
trap_handler_13 	j 	. 		; Load page fault
trap_handler_14 	j	. 		; Reserved for future standard use
trap_handler_15 	j	. 		; Store page fault


ecall_range			j	. 		; It jumps here if out of range

ecall_0
	li 		a0, CLEAR_DIS
	li 		a1, CLEAR_CTRL
	call 	lcdSendCommand
	j 		ecall_exit

ecall_1	
	call 	lcdSendCommand
	j 		ecall_exit

ecall_2
	call 	printString
	j 		ecall_exit

ecall_3
	call 	moveCursor
	j 		ecall_exit

ecall_4
	li 	    t0, SECOND			; Setting the limit
	li 		t1, TIME_PERIPH
	sw		t0, 0x4[t1]
	
	li 		t0, REGINIT
	sw 		t0, 0x14[t1]	
	j 		ecall_exit

ecall_5
	li 		t0, BUTTONS
	lb		a0, [t0]
	j 		ecall_exit

ecall_6
	li		t0, TIME_PERIPH
	lw 		a0, OFFSETSTAT[t0]
	j 		ecall_exit

ecall_7
	call 	PrintHex8
	j 		ecall_exit

ecall_8
	li 		t0, 0x8000_0000
	li		t1, TIME_PERIPH
	sw		t0, 0x10[t1]
	j 		ecall_exit

ecall_9
	call 	PrintDecU32
	j 		ecall_exit

ecall_10
	li 		t0, 0b1
	li		t1, TIME_PERIPH
	sw		t0, 0x10[t1]

ecall_11
	li 		t0, 0b1
	li		t1, TIME_PERIPH
	sw		t0, 0x14[t1]

ecall_max		EQU 	0x12


ecall_exit
	csrrw 	t0, MEPC, t0	; Find the trapping instruction PC
	addi 	t0, t0, 4		; Correct to a return address
	csrrw 	t0, MEPC, t0	; Swap back in

	lw 		ra, [sp]		; Pop working registers
	lw		s0, 4[sp]
	lw		s1, 8[sp]
	addi 	sp, sp, 12
	csrrw 	sp, MSCRATCH, sp; Save Machine SP, get User SP
	mret					; Return

mstack 			defs	100
mstack_base		align


ORG		0x0004_0000
;---------------------------------------------------------
; USER SECTION
;---------------------------------------------------------
user_code
                la      sp, user_stack_base      ; Set sp pointing to the end of our stack
                j       START

; Defining names to aid readability
CLEAR_DIS       EQU     0b0000_0001         ; DB7-DB0 data to clear the display
CLEAR_CTRL      EQU     0b1000              ; Controls when we want to clear the display

;SECOND 			EQU 	0x98967F
SECOND 			EQU 	0x18967F
TIME_PERIPH		EQU		0x0001_0200
REGINIT			EQU		0b11
BUTTONS			EQU		0x0001_0001
BTTN1			EQU 	0b0001
BTTN2 			EQU     0b0010
BTTN3 			EQU 	0b0100
OFFSETSTAT		EQU     0x0C

str1            defb    "Press button SW1\0"    ; String that we want to print
                align

str11           defb    " to start.\0"    ; String that we want to print
                align


strw            defb    "Current time: \0"
                align

str3            defb    "On pause.\0"
                align

strh            defb    "h \0"
                align

strm            defb    "m \0"
                align

strs            defb    "s \0"
                align

strp1           defb    "Pause SW1-Resume\0"
                align

strp2           defb    "      SW3-Reset \0"
                align

str2            defb    "Time passed:\0"
                align

user_stack           defs    100                 ; Defining a chunk of memory (100 bytes) to be used for the stack
user_stack_base      align                       ; This label is 'just after' the stack base - FULL DESCENDING

; def start() - main function

; local variables
; - only uses a0, a1 to pass function parameters

; s0 - seconds
; s1 = minutes
; s2 = hours

START
	; Clearing the display - we're calling lcdSendCommand for this but with the special clearing signals
    li 		a7, 0
	ecall

    ; calling printString function with string1 as argument
    la 		a0, str1
	li 		a7, 2
	ecall

	li		a7, 3					; next line
	ecall

	la 		a0, str11
	li 		a7, 2
	ecall

waitUntilBttn
	li 		a7, 5
	ecall
	
	andi	a0, a0, BTTN1			; Check if button 1 is pressed so we can start our loop
	beqz	a0, waitUntilBttn

resetCounter
	li		s0, 0
	li		s1, 0
	li 		s2, 0
	
	li		a7, 4
	ecall

	li 		a7, 0
	ecall							;clear sc

	la 		a0, strw
	li 		a7, 2
	ecall

	li		a7, 3					; next line
	ecall
	
	mv      a0, s2
	li      a7, 9					; print hours
	ecall

	la 		a0, strh				; print string
	li 		a7, 2
	ecall

	mv      a0, s1
	li      a7, 9					; print hours
	ecall

	la 		a0, strm				; print string
	li 		a7, 2
	ecall

	mv      a0, s0
	li      a7, 9					; print hours
	ecall

	la 		a0, strs				; print string
	li 		a7, 2
	ecall

waitUntilReached

checkPause
	; check if pause button SW2 is pressed
	li		a7, 5
	ecall 
	andi    a0, a0, BTTN2
	bnez    a0, paused

	li		a7, 6
	ecall
	
	bgez	a0, waitUntilReached	; Chekcing bit 31 if 1 (completed a loop) else 

	li 		a7, 8					; bit 31 reset
	ecall

	; check if seconds > 60
	addi	s0, s0, 0b1
	li		t0, 0x3C
	blt		s0, t0, nomod

	subi 	s0, s0, 0x3C
	addi 	s1, s1, 0b1

	; check if minutes > 60
	blt 	s1, t0, nomod
	subi 	s1, s1, 0x3C
	addi 	s2, s2, 0b1

nomod	

	li 		a7, 0
	ecall							;clear sc


	la 		a0, strw
	li 		a7, 2
	ecall

	li		a7, 3					; next line
	ecall

	mv      a0, s2
	li      a7, 9					; print hours
	ecall

	la 		a0, strh				; print string
	li 		a7, 2
	ecall

	mv      a0, s1
	li      a7, 9					; print hours
	ecall

	la 		a0, strm				; print string
	li 		a7, 2
	ecall

	mv      a0, s0
	li      a7, 9					; print hours
	ecall

	la 		a0, strs				; print string
	li 		a7, 2
	ecall

	j waitUntilReached

paused

	;disable clock
	li 		a7, 10					; deenable clock
	ecall

	li 		a7, 0
	ecall							;clear sc

	la 		a0, strp1				; print string
	li 		a7, 2
	ecall

	li		a7, 3					; next line
	ecall

	la 		a0, strp2				; print string
	li 		a7, 2
	ecall

next_state
	; check if pause button SW2 is pressed
	li		a7, 5
	ecall 
	andi    a0, a0, BTTN1
	beqz    a0, chkrst

	; enable clock
	li 		a7, 11
	ecall

	j waitUntilReached

chkrst
	; check if pause button SW3 is pressed
	li		a7, 5
	ecall 
	andi    a0, a0, BTTN3
	beqz    a0, next_state

	j 		START

	j paused

J END



END J . ; infinite loop to stop the program
