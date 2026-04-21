; =============================================================================
; Exercise 5: Counters and Timers
; Maria-Ioana Dicu
; 24 April 2026
;
; A stopwatch application adapted to run in user mode withn a primitive OS.
; The machine-mode section sets up trap handling and dispatches system calls,
; while the user-mode section contains the application logic.
;
; The program uses the hardware timer as a reference to count seconds
; accurately, with board buttons used to start, pause, and reset the count.
;
; External libraries:
;   - DisplayOperations.s   : LCD routines
;   - UserSpaceLib.s        : Screen-printing helpers
;
; Notes:
;   - The display-related logic was moved into helper libraries to reduce
;     repetition and keep the main application clearer.
;   - Timer access is performed through ECALLs to preserve hardware abstraction.
; =============================================================================


; =============================================================================
; OS SECTION
; Machine mode
; =============================================================================

ORG				0x0000_0000
j 				initialisation

INCLUDE 	DisplayOperations.s     ; Library with Display Operations


; =============================================================================
; Constants
; =============================================================================

mppMask			EQU 		0x18967F
ecall_max		EQU 		(ecall_end - ecall_0) / 4

bit0			EQU         0b1
bit31 			EQU 		0x8000_0000

initialisation
	li 		t0, mppMask			; Load MPP mask - bits 12 & 11
	csrc	MSTATUS, t0			; Clear MPP bits in status
	la 		t0, mhandler		; Point at trap handler code start
	csrw 	MTVEC, t0			; Save address in system CSR
	la 		t0, mstack_base		; Point at machine stack
	csrw 	MSCRATCH, t0		; Copy 'machine' SP for use in handler
	la 		sp, user_stack_base	; Change SP to user space
	la 		ra, user_code		; Point at user code start
	csrw 	MEPC, ra			; Save as 'return address'
	mret						; 'Return' to programme start


; =============================================================================
; Trap handler entry
; =============================================================================

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


; =============================================================================
; Trap dispatch table
; =============================================================================

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


; =============================================================================
; Trap handlers
; =============================================================================

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


; =============================================================================
; Ecall dispatch table
; =============================================================================

ecall_jump
	defw 	ecall_0				; Clear display
	defw	ecall_1				; Print character
	defw 	ecall_2				; Print string
	defw 	ecall_3 			; Move cursor to next line
	defw 	ecall_4				; Initialise counter
	defw 	ecall_5				; Read buttons
	defw 	ecall_6				; Read counter status registers
	defw 	ecall_7				; Bit 31 reset
	defw 	ecall_8				; Pause timer
	defw 	ecall_9				; Resume timer

trap_handler_9		j 	. 		; Environment call from S-mode
trap_handler_10		j 	. 		; Reserved
trap_handler_11 	j 	. 		; Environment call from M-mode
trap_handler_12 	j 	. 		; Instruction page fault
trap_handler_13 	j 	. 		; Load page fault
trap_handler_14 	j	. 		; Reserved for future standard use
trap_handler_15 	j	. 		; Store page fault


; =============================================================================
; Ecall service routines
; =============================================================================

ecall_range			j	. 		; It jumps here if out of range

ecall_0							; Clear display
	li 		a0, CLEAR_DIS
	li 		a1, LIGHT
	call 	lcdSendCommand
	j 		ecall_exit

ecall_1							; Print character
	call 	lcdSendCommand
	j 		ecall_exit

ecall_2							; Print string
	call 	printString
	j 		ecall_exit

ecall_3							; Move cursor to next line
	li 		a0, SHIFT_NEXT
    li 		a1, LIGHT
    call 	lcdSendCommand
	j 		ecall_exit 

ecall_4							; Initialise counter
	li 	    t0, MODULUS	
	li 		t1, TIME_PERIPH
	sw		t0, TIME_REG_LIMIT[t1]
	
	li 		t0, REGINIT
	sw 		t0, TIME_REG_CTRL [t1]	
	j 		ecall_exit

ecall_5							; Read buttons
	li 		t0, BUTTONS
	lb		a0, [t0]
	j 		ecall_exit

ecall_6							; Read counter status registers
	li		t0, TIME_PERIPH
	lw 		a0, TIME_REG_STATUS[t0]
	j 		ecall_exit

ecall_7							; Bit 31 reset
	li 		t0, bit31
	li		t1, TIME_PERIPH
	sw		t0, TIME_REG_CMD[t1]
	j 		ecall_exit

ecall_8							; Pause timer
	li 		t0, bit0
	li		t1, TIME_PERIPH
	sw		t0, TIME_REG_CMD[t1]
	j 		ecall_exit

ecall_9							; Resume timer
	li 		t0, bit0
	li		t1, TIME_PERIPH
	sw		t0, TIME_REG_CTRL [t1]
	j 		ecall_exit

ecall_end


; =============================================================================
; Return from ecall
; =============================================================================

ecall_exit
	csrrw 	t0, MEPC, t0		; Find the trapping instruction PC
	addi 	t0, t0, 4			; Correct to a return address
	csrrw 	t0, MEPC, t0		; Swap back in

	lw 		ra, [sp]			; Pop working registers
	lw		s0, 4[sp]
	lw		s1, 8[sp]
	addi 	sp, sp, 12
	csrrw 	sp, MSCRATCH, sp	; Save Machine SP, get User SP
	mret						; Return to user mode


; =============================================================================
; Machine stack
; =============================================================================

mstack 			defs	100
mstack_base		align




; =============================================================================
; USER SECTION
; User mode application
; =============================================================================

ORG		0x0004_0000

user_code
                la      sp, user_stack_base      ; Init user stack pointer
                j       START


; =============================================================================
; Constants
; =============================================================================

CLEAR_DIS       EQU     0b0000_0001         ; DB7-DB0 data to clear the display

SECOND 			EQU 	0x18967F
MODULUS			EQU 	999999
TIME_PERIPH		EQU		0x0001_0200
REGINIT			EQU		0b11
BUTTONS			EQU		0x0001_0001
BTTN1			EQU 	0b0001
BTTN2 			EQU     0b0010
BTTN3 			EQU 	0b0100

TIME_REG_LIMIT  	EQU     0x04
TIME_REG_STATUS 	EQU     0x0C
TIME_REG_CMD    	EQU     0x10
TIME_REG_CTRL   	EQU     0x14


; -----------------------------------------------------------------------------
; Strings
; -----------------------------------------------------------------------------

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


; =============================================================================
; User stack
; =============================================================================

user_stack           defs    100                 ; User stack
user_stack_base      align                       ; Full descending

INCLUDE UserSpaceLib.s     ; Library with Display Operations


; =============================================================================
; START
; Main application
;
; Time values stored in:
;   s0 = seconds
;   s1 = minutes
;   s2 = hours
; =============================================================================

START
	call displayStartScreen


; =============================================================================
; Wait for user to press SW1 to start
; =============================================================================

waitForStart
	li 		a7, 5
	ecall
	
	andi	a0, a0, BTTN1		; Check whether SW1 pressed
	beqz	a0, waitForStart

	li		s0, 0				; Seconds
	li		s1, 0				; Minutes
	li 		s2, 0				; Hours
	
	li		a7, 4				; Initialise counter
	ecall


; =============================================================================
; Main running state
; =============================================================================

running
	call 	displayTime

waitForCycle
	; Check whether SW2 is pressed to pause
	li		a7, 5
	ecall 
	andi    a0, a0, BTTN2
	bnez    a0, paused

	; Check timer status
	li		a7, 6
	ecall
	
	bgez	a0, waitForCycle	; Check bit 31 if 1 (completed a loop) else 

	li 		a7, 7				; Bit 31 reset
	ecall

	; Increment displayed time
	addi	s0, s0, 1
	li		t0, 60
	blt		s0, t0, running

	li      s0, 0
    addi    s1, s1, 1
    blt     s1, t0, running

    li      s1, 0
    addi    s2, s2, 1
    j       running


; =============================================================================
; Paused state
; =============================================================================

paused
    li      a7, 8             	; Pause timer
    ecall

    call    displayPauseScreen

waitPausedInput
    ; Check whether SW1 is pressed to resume
    li      a7, 5
    ecall
	
    andi    a0, a0, BTTN1
    bnez    a0, resumeTimer

    ; Check whether SW3 is pressed to reset
    li      a7, 5
    ecall

    andi    a0, a0, BTTN3
    bnez    a0, START

    j       waitPausedInput

resumeTimer
    li      a7, 9              	; Resume timer
    ecall

    j       running

j 	END

; =============================================================================
; End of program
; =============================================================================

END J . ; infinite loop to stop the program
