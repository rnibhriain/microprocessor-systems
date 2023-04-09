; input - output program

	area	tcd,code,readonly
	export	__main
__main

IO1DIR	EQU	0xE0028018
IO1SET	EQU	0xE0028014
IO1CLR	EQU	0xE002801C
IO1PIN	EQU	0xE0028010
	
	; constants
	MOV	R2, #0x0f000000		; this is the original set of buttons 
	LDR	R4, = IO1PIN		; permanent location for the pin address
	
	; setup
	LDR	r0,=IO1DIR
	MOV	r1,#0x00FF0000		; make bits 16 to 23 outputs
	STR	r1,[r0]			; set the outputs
	
	; set D to 0
	LDR	R1, [R4]
	BIC	R1, #0x00FF0000		; clear bits 16 to 23 to set D to 0
	STR	R1, [R4]		; store this 0
	


poll					; while (true) {
	
wait					; 	do {		
	LDR	R0, [R4]		;		load pin value
	AND	R0, R2		;			isolate the values of the buttons we are polling
	CMP	R0, R2			; 	} while  
	BNE	button_pressed		;	 (!button_pressed)
	B	wait			
button_pressed	

	MOV	R3, R0			; 	temp = buttons	

check					; 	do {
	LDR	R0, [R4]		; 		load pin value
	AND	R0, R2			; 		isolate current values of buttons we are polling
	CMP	R0, R2			; 	} while
	BEQ	button_released		; 	 (!all_buttons_released)
	B	check	
button_released

	MOV	R0, R3			; 	current_value = temp
	LSR	R0, #24			;	right shift values to get the buttons
	LDR	R1, [R4]		;	load the pin value
	AND	R1, #0X00FF0000		;	isolate the the value of D
	LSR	R1, #16			; 	shift D 
	BL	input_detected		;	input has been detected so call function
	
	LSL	R1, #16			; 	shift D value back to bits 16 to 23
	LDR	R3, [R4]		;	load pin value
	BIC	R3, #0X00FF0000		;	clear value in D
	ORR	R1, R3			;	orr the D value back in
	STR	R1, [R4]		; 	store the pin
	
	B	poll			; }
	
finish  b	finish

; input_detected
; after any input is detected this detects which button was pressed and which operation needs
; to be performed on D
; parameters:
;	R0 - the button that was pressed will be a 0 bit in the value
;	R1 - current D value
; return
; 	R1 - the D value after the operation has been performed
input_detected
	STMFD 	SP!, {LR}	; save registers


	CMP 	R0, #0xE	; IF (BUTTON24) 
	BNE	not_24		; {
	ADD	R1, #1		; 	D++
	B	store

not_24				; }

	CMP	R0, #0xD	; ELSE IF (BUTTON25) {
	BNE 	not_25		; {
	SUB	R1, #1		; 	D--
	B	store

not_25				; }

	CMP	R0, #0xB	; ELSE IF (BUTTON26) {
	BNE	not_26		; {
	LSL	R1, #1		; 	D << 1
	B	store

not_26				; }
	
	CMP	R0, #7		; ELSE IF (BUTTON27) {
	BNE	store	; {
	LSR	R1, #1		; 	D >> 1				; }	

store
	AND	R1, #0x000000FF ; ensures that only the specific bits we need are returned
	
	LDMFD	SP!, {LR}	; restore registers
	BX	LR		; branch to link register	
	

	end