; Interrupt Handling Sample
; (c) Mike Brady, 2021.

	area	tcd,code,readonly
	export	__main
__main

; Definitions  -- references to 'UM' are to the User Manual.

; Timer Stuff -- UM, Table 173

T0	equ	0xE0004000		; Timer 0 Base Address
T1	equ	0xE0008000

IR	equ	0			; Add this to a timer's base address to get actual register address
TCR	equ	4
MCR	equ	0x14
MR0	equ	0x18

TimerCommandReset		equ	2
TimerCommandRun			equ	1
TimerModeResetAndInterrupt	equ	3
TimerResetTimer0Interrupt	equ	1
TimerResetAllInterrupts		equ	0xFF

; VIC Stuff -- UM, Table 41
VIC	equ	0xFFFFF000		; VIC Base Address
IntEnable	equ	0x10
VectAddr	equ	0x30
VectAddr0	equ	0x100
VectCtrl0	equ	0x200
	

Timer0ChannelNumber	equ	4	; UM, Table 63
Timer0Mask	equ	1<<Timer0ChannelNumber	; UM, Table 63
IRQslot_en	equ	5		; UM, Table 58
	
	
; GPIO stuff
IO1DIR	EQU	0xE0028018
IO1SET	EQU	0xE0028014
IO1CLR	EQU	0xE002801C
IO1PIN	EQU	0xE0028010
	
; other constants
SECONDS	EQU	0x000000

; INITIALISATION 

	; Initialise the VIC
	ldr	r0,=VIC			; looking at you, VIC!

	ldr	r1,=irqhan
	str	r1,[r0,#VectAddr0] 	; associate our interrupt handler with Vectored Interrupt 0

	mov	r1,#Timer0ChannelNumber+(1<<IRQslot_en)
	str	r1,[r0,#VectCtrl0] 	; make Timer 0 interrupts the source of Vectored Interrupt 0

	mov	r1,#Timer0Mask
	str	r1,[r0,#IntEnable]	; enable Timer 0 interrupts to be recognised by the VIC

	mov	r1,#0
	str	r1,[r0,#VectAddr]   	; remove any pending interrupt (may not be needed)
	

	; Initialise Timer 0
	ldr	r0,=T0			; looking at you, Timer 0!

	mov	r1,#TimerCommandReset
	str	r1,[r0,#TCR]

	mov	r1,#TimerResetAllInterrupts
	str	r1,[r0,#IR]

	; this is very slow in my program
	ldr	r1,=(14745600/100)-1	 ; 625 us = 1/1600 second
	str	r1,[r0,#MR0]

	mov	r1,#TimerModeResetAndInterrupt
	str	r1,[r0,#MCR]

	mov	r1,#TimerCommandRun
	str	r1,[r0,#TCR]
	
	
	; Initialise the GPIO

	; constants
	LDR	R4, = IO1CLR
	
	; setup
	LDR	r0,=IO1DIR
	MOV	r1,#0xFFFFFFFF		; make bits outputs
	STR	r1,[r0]			; set the outputs
	
	MOV	R1, #0xFFFFFFFF
	STR	R1, [R4]		;  Clear all the bits
	
	; set the spacers
	LDR	R4, =IO1SET		
	LDR	R1, =0xF00F00
	STR	R1, [R4]
	
; MAIN
	MOV	R2, #100		; number of interrupts (10ms) before a second is added	
	LDR	R0, =counter		; counter address
loop
	LDR	R1, [R0]		; load current value of counter
	SUBS	R1, R2			; take away number of interrupts
	BLO	loop			; if its not 100 branch back to load counter again
	
	; set counter back to 0
	MOV	R1, #0
	STR	R1, [R0]
	
	; call the subroutine to update time
	BL	update_time
	B	loop

finish	b finish


; subroutine to update the time in GPIO
; parameters:
;	- none other than time gotten from GPIO
; returns:
;	- up to date time in GPIO
; NOTES:
; The emulator time is very slow in comparison to real time 
; 	1 min in emulator = 5:26 min in real time
update_time
	STMFD 	SP!, {LR, R0-R2}	; save registers used
	
	LDR	R0, =IO1PIN		; pin address
	LDR	R1, [R0]		; load time

	; check if a single digit second can be added
	AND	R2, R1, #0xF
	CMP	R2, #9
	BLO	add_second
	
	; clear single digit seconds
	BIC	R1, #0xF
	
	; check if a ten of seconds can be added
	AND	R2, R1, #0xF0
	CMP	R2, #0x50
	BLO	add_ten_seconds
	
	; clears tens of seconds
	BIC	R1, #0xF0
	
	; check if a minute can be added
	AND	R2, R1, #0xF000
	CMP	R2, #0x9000
	BLO	add_minute
	
	; clear single digit minutes
	BIC	R1, #0xF000
	
	; check if a ten of minutes can be added
	AND	R2, R1, #0xF0000
	CMP	R2, #0x50000
	BLO	add_ten_minutes
	
	; clears the tens of minutes
	BIC	R1, #0xF0000
	
	; this section checks if the timer needs to be reset
	
	; checks if the tens of hours equal 2 and if not branches to add hours
	AND	R2, R1, #0xF0000000
	CMP	R2, #0x20000000
	BNE 	do_checks
	
	; checks if the single digit hours equal 3 and if it does then resets the clock
	AND	R2, R1, #0xF000000	
	CMP	R2, #0x3000000
	BEQ 	reset
	
do_checks

	; check if a single digit hour can be added
	AND	R2, R1, #0xF000000	
	CMP	R2, #0x9000000
	BLO	add_hour
	
	; clear single digit hours
	BIC	R1, #0xF000000
	
	;get tens of hours and branch to add one
	AND	R2, R1, #0xF0000000
	BL	add_ten_hours

reset	
	; restart at 23:59:59
	LDR	R1, =0xF00F00	
	
	B	storing
		
add_second
	; adds one second
	ADD	R1, #1
	B	storing
	
add_ten_seconds
	; this will add 1 to the nibble storing the tens of seconds
	LSR	R2, #4
	ADD	R2, #1
	LSL	R2, #4
	BIC	R1, #0xF0
	ORR	R1, R2
	
	B	storing
	
add_minute
	; this will add 1 to the nibble storing the singe digit minutes
	LSR	R2, #12
	ADD	R2, #1
	LSL	R2, #12
	BIC	R1, #0xF000
	ORR	R1, R2
	
	B	storing
	
add_ten_minutes
	; this will add 1 to the nibble storing the tens of minutes 
	LSR	R2, #16
	ADD	R2, #1
	LSL	R2, #16
	BIC	R1, #0xF0000
	ORR	R1, R2
	
	B	storing
	
add_hour
	; this will add 1 to the nibble storing the single digit hours
	LSR	R2, #24
	ADD	R2, #1
	LSL	R2, #24
	BIC	R1, #0xF000000
	ORR	R1, R2
	
	B	storing
	
add_ten_hours

	; this will add 1 to the nibble storing the tens of hours
	LSR	R2, #28
	ADD	R2, #1
	LSL	R2, #28
	BIC	R1, #0xF0000000
	ORR	R1, R2		

storing
	; clear GPIO
	LDR	R0, =IO1CLR
	LDR	R2, =0xFF0FF0FF
	STR	R2, [R0]
	
	; Store the correct time
	LDR	R0, =IO1SET
	STR	R1, [R0]
	
	LDMFD	SP!, {LR, R0-R2}	; restore registers
	BX	LR			; branch to link register	


	

	AREA	InterruptStuff, CODE, READONLY
irqhan	sub	lr,lr,#4
	stmfd	sp!,{r0-r1,lr}	; the lr will be restored to the pc

;this is the body of the interrupt handler

;here you'd put the unique part of your interrupt handler
;all the other stuff is "housekeeping" to save registers and acknowledge interrupts


	; add one to the counter and store
	LDR	R0, =counter
	LDR	R1, [R0]
	ADD	R1, #1
	STR	R1, [R0]
	

;this is where we stop the timer from making the interrupt request to the VIC
;i.e. we 'acknowledge' the interrupt
	ldr	r0,=T0
	mov	r1,#TimerResetTimer0Interrupt
	str	r1,[r0,#IR]	   	; remove MR0 interrupt request from timer

;here we stop the VIC from making the interrupt request to the CPU:
	ldr	r0,=VIC
	mov	r1,#0
	str	r1,[r0,#VectAddr]	; reset VIC

	ldmfd	sp!,{r0-r1,pc}^	; return from interrupt, restoring pc from lr
				; and also restoring the CPSR
				
	AREA 	interrupt_data, DATA, readwrite
counter		SPACE 	4

                END
