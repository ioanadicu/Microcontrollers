SECOND 			EQU 	0x98967F
TIME_PERIPH		EQU		0x0001_0200
CHECK31			EQU		0b1000_0000_0000_0000_0000_0000_0000_0000
REGINIT			EQU		0b11
BUTTONS			EQU		0x0001_0001
BTTN1			EQU 	0b0001
BTTN2 			EQU     0b0010

init
	li 	    t0, SECOND			; Setting the limit
	li 		t1, TIME_PREIPH
	sw		t0, 04[t1]
	
	li 		t0, REGINIT
	sw 		t0, 14[t1]			

waitUntilBttn
	li 		t0, BUTTONS
	andi	t0, BTTN1			; Check if button 1 is pressed so we can start our loop
	beqz	t0, waitUntilBttn
	j start

start
	
waitUntilReached
	li		t0, TIME_PERIPH

checkPause
	li		t0, BUTTONS
	andi    t0, BTTN2
	bnez    t0, Paused

	lw 		t1, 0C[t0]
	andi	t1, CHECK31
	beqz	t1, waitUntilReached	; Chekcing bit 31 if 1 (completed a loop) else 
	
Paused
	j		. 
j start
