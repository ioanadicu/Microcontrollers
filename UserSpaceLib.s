printDec
    subi    sp, sp, 12
    sw      ra,  8[sp]
    sw      s0,  4[sp]
    sw      s1,  0[sp]

    mv      s0, a0          ; s0 = value
    li      s1, 0           ; s1 = digit count

    ; Special case: if value == 0, print '0' and return
    bnez    s0, dec_loop
    li      a0, '0'
    li      a1, LIGHT | RS

    li      a7, 1
    ecall 
    
    j       dec_done

dec_loop
    li      t1, 10
    remu    t0, s0, t1      ; t0 = s0 % 10
    divu    s0, s0, t1      ; s0 = s0 / 10
    addi    t0, t0, '0'     ; ASCII digit

    subi    sp, sp, 4
    sw      t0, 0[sp]       ; push ASCII digit as a word
    addi    s1, s1, 1
    bnez    s0, dec_loop

print_loop
    ; pop and print digits
    lw      a0, 0[sp]
    addi    sp, sp, 4
    li      a1, LIGHT | RS

    li      a7, 1
    ecall 
  

    addi    s1, s1, -1
    bnez    s1, print_loop

dec_done
    lw      s1,  0[sp]
    lw      s0,  4[sp]
    lw      ra,  8[sp]
    addi    sp, sp, 12
    ret

displayTime
    subi    sp, sp, 4
    sw      ra, 0[sp]

    li      a7, 0
    ecall

    la      a0, strw
    li      a7, 2
    ecall

    li      a7, 3
    ecall

    mv      a0, s2
    call    printDec

    la      a0, strh
    li      a7, 2
    ecall

    mv      a0, s1
    call    printDec

    la      a0, strm
    li      a7, 2
    ecall

    mv      a0, s0
    call    printDec

    la      a0, strs
    li      a7, 2
    ecall

    lw      ra, 0[sp]
    addi    sp, sp, 4
    ret


displayStartScreen
	subi    sp, sp, 4
    sw      ra, 0[sp]

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

	lw      ra, 0[sp]
    addi    sp, sp, 4
    ret

displayPauseScreen
	subi    sp, sp, 4
    sw      ra, 0[sp]

	li 		a7, 0
	ecall							; clear sc

	la 		a0, strp1				; print string
	li 		a7, 2
	ecall

	li		a7, 3					; next line
	ecall

	la 		a0, strp2				; print string
	li 		a7, 2
	ecall

	lw      ra, 0[sp]
    addi    sp, sp, 4
    ret

displayTime
    subi    sp, sp, 4
    sw      ra, 0[sp]

    li      a7, 0
    ecall

    la      a0, strw
    li      a7, 2
    ecall

    li      a7, 3
    ecall

    mv      a0, s2
    call    printDec

    la      a0, strh
    li      a7, 2
    ecall

    mv      a0, s1
    call    printDec

    la      a0, strm
    li      a7, 2
    ecall

    mv      a0, s0
    call    printDec

    la      a0, strs
    li      a7, 2
    ecall

    lw      ra, 0[sp]
    addi    sp, sp, 4
    ret


displayStartScreen
	subi    sp, sp, 4
    sw      ra, 0[sp]

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

	lw      ra, 0[sp]
    addi    sp, sp, 4
    ret

displayPauseScreen
	subi    sp, sp, 4
    sw      ra, 0[sp]

	li 		a7, 0
	ecall							; clear sc

	la 		a0, strp1				; print string
	li 		a7, 2
	ecall

	li		a7, 3					; next line
	ecall

	la 		a0, strp2				; print string
	li 		a7, 2
	ecall

	lw      ra, 0[sp]
    addi    sp, sp, 4
    ret