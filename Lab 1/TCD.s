
	area	tcd,code,readonly
	export	__main
__main


	LDR	R3, =factorials		; location of the storage of the factorials
	LDR	R4, =nums		; location of the factorials to be calculated
	
	LDR	R5, [R4], #4		; get the length of the demo values
	
while
	LDR	R1, [R4], #4		; the number to get the factorial of
	LDR	R0, =0			; set the most significant bits of the result to be 0
	CMP	R5, #0			; while (length < 0) 
	BEQ	endwhile		; {
	BL	fact			; 	fact(number)
	
	; if there is an error at this point the Carry flag will be set and the result will be 0
	
	STR	R0, [R3], #4		; 	store most significant bits
	STR	R1, [R3], #4		;	store least significant bits
	
	SUB	R5, R5, #1		; 	length --
	
	B	while			; }
endwhile
	
	; program has ended and should have stored all values
	
finish	B	finish	


; fact
; takes a number and returns the 64 bit factorial of said number
; this is a recursive function
; parameters:
;	R1 - number to get factorial of n i.e. n!
; return
; 	R0 - the most signifcant bits of the factorial
;	R1 - the least significant bits of the factorial

fact 
	; save registers used
	STMFD	SP!, {LR, R2}
	
	CMP	R1, #0			; if (n == 0)
	BHI	notzero			; {
	MOV	R1, #1			;	return 1;
	B	finishrecursion		; }
notzero					; else {
	MOV	R2, R1			; 	n		
	SUB	R1, R1, #1		; 	n- 1
	
	; the recursive call
	BL 	fact			;	return fact(n-1)
	
	CMP	R1, #0			; 	if (error)
	BEQ	setCarry		;		branch to set the carry
					; }
	BL	multiply		; multiply the numbers as the function exits each level of recursion

	B	finishrecursion
	
setCarry
	MRS R0, CPSR 			; Read the CPSR
	
	BIC R0, R0, #0xf0000000 	; Clear all the flags (N, C, V, Z)
	MSR CPSR_f, R0 			; update the flag bits in the CPSR
	
	ORR R0, R0, #(1<<29)		; set the C flag
	MSR	CPSR_F, R0		; update the flag bits
	
	LDR	R0, =0			; ensure the result is 0
	LDR	R1, =0			; again, result is 0
	
	B	noclearcarry		; branch to ensure the carry flag is not immediately cleared
	
	; no errors so far so clear the flags
finishrecursion

	MRS R2, CPSR 			; Read the CPSR
	
	BIC R2, R2, #0xf0000000 	; Clear all the flags (N, C, V, Z)
	MSR CPSR_f, R2 			; update the flag bits in the CPSR
		
noclearcarry
	
	
	; restore registers used
	LDMFD SP!, {LR, R2}
	
	; branch back
	BX	LR


; multiply
; multiplies two unsigned numbers using shifting and adding
; returns zero of there is an error
; parameters:
; 	R0 - the most signifcant bits to multiply (a1)
;	R1 - the least significant bits to multiply (a2)
;	R2 - the number to multiply by (b)
; return
; 	R0 - the most signifcant bits (result1)
;	R1 - the least significant bits (result2)

multiply

	; save registers used
	STMFD	SP!, {LR, R2-R5}
	
	; setup of variables and whatnot
	MOV	R3, R2			; (b)
	MOV	R2, R1			; (a2)
	MOV	R5, R0			; (a1)
	MOV	R0, #0			; (result1)
	MOV	R1, #0			; (resutl2)
	
nextshift
	CMP	R3, #0			; while (b > 0)
	BLS	finishloop		; {
	
	AND	R4, R3, #1		; 	b & 1
	CMP	R4, #0			;	if ((b & 1) == 1)
	BEQ	notodd			;	{
	
	ADDS	R1, R1, R2		;		result2 += a2
	BCC	noaddcarry		;		if (carryset) {
	ADDS	R0, R0, #1		;			add carry to result1
	BCS	error			;	if there is an unsigned overflow
noaddcarry				;		}

	ADDS	R0, R0, R5		;		result1 += a1
	BCS	error			;	if there is an unsigned overflow
	
notodd					;	}

	LSLS	R5, R5, #1		;	a1 << 1
	BCS	error			;	if there is an unsigned overflow
	LSR	R3, R3, #1		;	b >> 1
	LSLS	R2, R2, #1		; 	a2 << 1
	BCC	noshiftcarry		; 	if (carryset) {
	ORR	R5, R5, #1		; 		insert carry into most significant bits (a1)
noshiftcarry				;	}
	
	B	nextshift			; }
	
error 
	LDR	R0, =0			; result is zero due to error
	LDR	R1, =0			; result is zero due to error

finishloop
	
	; restore registers used
	LDMFD SP!, {LR, R2-R5}
	
	; branch back
	BX	LR

;		all the data

;		numbers to get factorial of
		area	tcdrod, data, readonly
nums		DCD	4, 5, 14, 20, 30	; length of array and then array

;		location to store the numbers
		area	tcdram, data, readwrite		
factorials	space	8
	
	END