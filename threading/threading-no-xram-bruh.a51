; ============================================================================
; 								   MACROS
; ============================================================================

; register macros for direct address mode
; register bank 0
#DEFINE DIRECT_R0		00h
#DEFINE DIRECT_R1		01h
#DEFINE DIRECT_R2		02h
#DEFINE DIRECT_R3		03h
#DEFINE DIRECT_R4		04h
#DEFINE DIRECT_R5		05h
#DEFINE DIRECT_R6		06h
#DEFINE DIRECT_R7		07h

; Scheduler
; addresses
#DEFINE STACK_START			#08h
#DEFINE TICK_COUNTER 		40h

; constants
#DEFINE TICK_RESET_VALUE	#40d ; 40 at 4000Hz = 10 ms

; SWAP area
#DEFINE SWAP_A			60h
#DEFINE SWAP_B			61h
#DEFINE SWAP_R0			62h
#DEFINE SWAP_R1			63h
#DEFINE SWAP_R2			64h
#DEFINE SWAP_R3			65h
#DEFINE SWAP_R4			66h
#DEFINE SWAP_R5			67h
#DEFINE SWAP_R6			68h
#DEFINE SWAP_R7			69h
#DEFINE SWAP_PSW		6Ah

; CLOCK
; memory addresses
#DEFINE CLOCK_HOURS_PTR			#50h
#DEFINE CLOCK_MINUTES_PTR		#51h
#DEFINE CLOCK_SECONDS_PTR		#52h
#DEFINE CLOCK_MAX_HOURS_PTR		#53h
#DEFINE CLOCK_MAX_MINUTES_PTR	#54h
#DEFINE CLOCK_MAX_SECONDS_PTR	#55h
#DEFINE CLOCK_TICK_COUNTER		56h		

; constants
#DEFINE CLOCK_MAX_HOURS			#23d
#DEFINE CLOCK_MAX_MINUTES		#59d
#DEFINE CLOCK_MAX_SECONDS		#59d
#DEFINE CLOCK_TICK_RESET_VALUE	#100d ; 100 at 100Hz = 1s

#cpu = 89S8252    ; @12 MHz

; ============================================================================
; 								MEMORY SETUP
; ============================================================================
;
;  Region        | Start | End   | Size | Description
;  --------------+-------+-------+------+----------------------------------------------
;  RESERVED      | 0x0	 | 0x8	 | 8    | register bank 0
;  --------------+-------+-------+------+----------------------------------------------
;  STACK         | 0x8	 | 0x3f	 | 40   | stack
;  --------------+-------+-------+------+----------------------------------------------
;  RAM 1	  	 | 0x40	 | 0x4f	 | 16   | RAM for Task 1: Scheduler
;  --------------+-------+-------+------+----------------------------------------------
;  RAM 2    	 | -	 | -	 | 0    | RAM for Task 2: Reaction (not needed)
;  --------------+-------+-------+------+----------------------------------------------
;  RAM 3	  	 | 0x50	 | 0x5f	 | 16   | RAM for Task 3: Clock + Temperature
;  --------------+-------+-------+------+----------------------------------------------
;  RAM 4  	 	 | -	 | -	 | 0    | RAM for Task 4: Sorting (not needed)
;  --------------+-------+-------+------+----------------------------------------------
;  SWAP 		 | 0x60	 | 0x6f	 | 16   | swap area for execution context
;  --------------+-------+-------+------+----------------------------------------------
;  UNUSED		 | 0x70	 | 0x7f	 | 16   | unused

; < 10 ms @12 MHz <=> 0.01 s / cycle @12,000,000 => ~60,000 instructions per interrupt
; Actually: single stack for all tasks!
; init -> 
; sorting task -> interrupt (store context) (can only ever interrupt sorting task) -> reaction task -> ret 
; -> clock -> temperature -> ret -> restore context -> return from interrupt -> continue sorting task (or -> end)
; interrupt (can only ever interrupt sorting task) -> only store context of sorting task

; INIT -> SORT ...                                                                                                 --> Continue sorting task
;                  \                                                                                              /
;                   -> Interrupt -> StoreContext() -> Reaction() -> Clock() -> RestoreContext() -> End Interrupt -

ajmp Initialize

Timer 0:    ; Timer 0 Interrupt
    ajmp OnTick

Initialize:
	; setup stack
	mov	SP, STACK_START

	; reset clock tick counter
	lcall ResetClockTicks

	orl TMOD, # 02h    ; Timer 0 im 8-Bit Autoreload-Modus. 
	; Die �berlauffrequenz des Timer 0 betr�gt 4000 Hz, die Periodendauer 0,25 ms.
	mov TH0, # 06h    ; Reloadwert

	; Interrupts
	setb ET0    ; Timer 0 Interrupt freigeben
	setb EA    ; globale Interruptfreigabe
	setb TR0    ; Timer 0 l�uft.

	lcall Clock_Init

	; run sorting task by default
	lcall Sort_Notify

	end ; <- return adderss on first interrupt
; * * * Hauptprogramm Ende * * *

; if (--tick_counter == 0) 
; {
; 	  ResetTicks();
;	  TasksNofityAll();
; }
OnTick:
	; can not use registers here, execution context is not yet stored
	djnz TICK_COUNTER, __OnTick_End
	; 10 ms elapsed -> let all tasks run
	lcall ResetTicks
	lcall TasksNofityAll
__OnTick_End:
	reti

TasksNofityAll:
	; store execution context
	lcall EXC_STORE
	; notify all tasks
	lcall Reaction_Notify
	lcall Clock_Notify
	; restore execution context
	lcall EXC_RESTORE
	ret

; reset ticks
ResetTicks:
	mov TICK_COUNTER, TICK_RESET_VALUE
	ret

; stores the execution context in the swap area
EXC_STORE:
	mov SWAP_PSW, psw
	mov SWAP_A, a
	mov SWAP_B, b
	mov SWAP_R0, r0
	mov SWAP_R1, r1
	mov SWAP_R2, r2
	mov SWAP_R3, r3
	mov SWAP_R4, r4
	mov SWAP_R5, r5
	mov SWAP_R6, r6
	mov SWAP_R7, r7
	ret

; restores the execution context from the swap area
EXC_RESTORE:
	mov r7, SWAP_R7
	mov r6, SWAP_R6
	mov r5, SWAP_R5
	mov r4, SWAP_R4
	mov r3, SWAP_R3
	mov r2, SWAP_R2
	mov r1, SWAP_R1
	mov r0, SWAP_R0
	mov b, SWAP_B
	mov a, SWAP_A
	mov psw, SWAP_PSW
	ret

; ============================================================================
; 									REACTION
; ============================================================================
; reads the uin8_t value from port 1, does bound checking and returns the result in lowerst 2 bits in port 3
; Port 3: (XH, XL)
; 0,1: Wert < 100
; 1,1: Error (Wert == 100)
; 0,0: 100 < Wert < 200
; 1,0 : Wert >= 200

Reaction_Notify:
	mov r0, p1					; take snapshot of port 1
	mov r1, #1h					; store return value in r1, assume value < 100
	; compare against < 100
	mov a, #99d
	clr c
	subb a, r0					; subtract value from 99
	jnc __Reaction_NotifyEnd	; if no carry, value is <= 99
	mov r1, #3h					; value is > 99, assume value == 100
	; compare against 100
	mov a, #100d
	xrl a, r0					; xor value with 100
	jz __Reaction_NotifyEnd		; if zero, value is 100
	mov r1, #0h					; value is > 100, assume value < 200
	; compare against < 200
	mov a, #199d
	clr c
	subb a, r0					; subtract value from 199
	jnc __Reaction_NotifyEnd	; if no carry, value is <= 199
	mov r1, #1h					; value is >= 200
__Reaction_NotifyEnd:
	mov p3, r1					; store return value in port 3
	ret

; ============================================================================
; 									CLOCK
; ============================================================================

; initializes the clock
Clock_Init:
	mov r0, CLOCK_HOURS_PTR
	mov @r0, #00h				; hours
	mov r0, CLOCK_MINUTES_PTR
	mov @r0, #00h				; minutes
	mov r0, CLOCK_SECONDS_PTR
	mov @r0, #00h				; seconds
	mov r0, CLOCK_MAX_HOURS_PTR
	mov @r0, CLOCK_MAX_HOURS
	mov r0, CLOCK_MAX_MINUTES_PTR
	mov @r0, CLOCK_MAX_MINUTES
	mov r0, CLOCK_MAX_SECONDS_PTR
	mov @r0, CLOCK_MAX_SECONDS
	lcall Clock_ResetTicks
	ret

; if (--clock_tick_counter == 0) 
; {
; 	  Clock_ResetTicks();
;	  Clock_OnEachSecond();
;  	  Temperature_Notify();
; }
Clock_Notify:
	djnz CLOCK_TICK_COUNTER, __Clock_NotifyEnd
	; a second has elapsed
	lcall Clock_ResetTicks
	lcall Clock_OnEachSecond
	lcall Temperature_Notify
__Clock_NotifyEnd:
	ret

Clock_ResetTicks:
	mov CLOCK_TICK_COUNTER, CLOCK_TICK_RESET_VALUE
	ret

; Called on each second and handles time set events or increments the seconds
; the lower nibble of port 0 is used to set the clock:
; - lower 2 bit controls mode
; - upper 2 bit controls the selcetion of the value to set 

; | mode | description |
; +------+-------------+
; | 0    | normal	   |
; | 1    | increment   |
; | 2    | decrement   |
; | 3    | invalid     |

; | selection | description |
; +-----------+-------------+
; | 0         | hours       |
; | 1         | minutes     |
; | 2         | seconds     |
; | 3         | invalid     |
Clock_OnEachSecond:
	mov r2, p0			; take snapshot of port 0
	mov a, r2			; copy port 0 to a
	anl a, #0x03		; check mode bits only
	; if mode bits are not zero, set clock
	jnz __Clock_OnEachSecond_SetTime
__Clock_OnEachSecond_Normal:
	; normal mode, increment seconds
	lcall Clock_IncrementSeconds
	jmp __Clock_OnEachSecond_End
__Clock_OnEachSecond_SetTime:
	; set time mode
	clr c						; clear carry flag
	rrc a						; rotate carry flag into a
	; a is now 0 (increment mode) or 1 (decrement mode)
	mov r0, a					; save mode mask to r0
	; now load selection
	mov a, r2					; copy port 0 to a
	anl a, #0x0c				; check selection bits only
	; create mask from selection bits (shift right by 2)
	rr a
	rr a
	mov r1, a					; save selection mask to r1
	; check if selection == 3 (invalid)
	xrl a, #3					; xor with 3
	; if selection == 3, ignore command and resume normal operation
	jz __Clock_OnEachSecond_Normal
	; selection is valid, set clock
	; prepare parameters for function call
	mov a, CLOCK_HOURS_PTR		; load hours pointer
	add a, r1					; add selection mask (offset) to pointer
	mov r3, a					; save pointer to r3
	push DIRECT_R3				; push pointer to stack
	mov a, CLOCK_MAX_HOURS_PTR	; load max hours pointer
	add a, r1					; add selection mask (offset) to pointer
	mov r3, a					; save pointer to r3
	push DIRECT_R3				; push pointer to stack
	; prepare function call
	mov a, r0					; load mode mask to a
	; if MODE mask is 0 -> increment, 1 -> decrement
	; register a now provides a nice offset :)
	; -> use branch table to call the correct function 
	; a = a * 8 to match offset in branch table
	rl A						; *2
	rl A						; *2
	rl A						; *2
	; load branch table to dptr
	mov dptr, #__Clock_OnEachSecond_BranchTable
	jmp @a+dptr					; execute branch table entry and return
__Clock_OnEachSecond_End:
	ret
	; Branch table with 8 byte offsets :)
	; BranchTable[0] = Increment
	; BranchTable[1] = Decrement
__Clock_OnEachSecond_BranchTable:
	lcall Clock_Increment		; 3 bytes
	pop DIRECT_R0				; 2 byte (discard return value)
	nop							; 1 byte
	nop							; 1 byte
	ret							; 1 byte
	lcall Clock_Decrement		; this is __OnEachSecond_Increment + 8 :)
	pop DIRECT_R0				; 2 byte (discard return value)
	nop							; 1 byte
	nop							; 1 byte
	ret							; 1 byte

; if the value surpasses the inclusive overflow value (in params), it is reset to 0
; both parameters passed via stack.
; returns 0xff if overflow, 0 otherwise
; void Clock_Increment(uint8_t* variable, uint8_t* inclusive_overflow_value);
Clock_Increment:
	; save our own return address :)
	pop DIRECT_R7				; high byte to r7
	pop DIRECT_R6				; low byte to r6
	; now load our parameters
	pop DIRECT_R1				; load inclusive_overflow_value* to r1
	pop DIRECT_R0				; load variable* to r0
	mov a, @r1					; dereference inclusive_overflow_value to a
	; now do the increment
	inc @r0						; increment variable
	; check if we overflowed
	mov r5, #00h				; use r5 for return value (assume no overflow)
	clr c						; clear carry flag
	subb a, @r0					; subtract variable from inclusive_overflow_value
	jnc __Clock_Increment_NoOverflow
	; overflow
	mov @r0, #00h				; reset variable to 0
	mov r5, #0ffh				; set return value to 0xff
__Clock_Increment_NoOverflow:
	push DIRECT_R5				; push return value to stack
	push DIRECT_R6				; restore return address (low byte)
	push DIRECT_R7				; restore return address (high byte)
	ret

; if the value reaches 0, it is reset the maximum value < 255 (via params)
; both parameter passed via stack.
; returns 0xff if underflow, 0 otherwise
; void Clock_Decrement(uint8_t* variable, uint8_t* inclusive_max_value);
Clock_Decrement:
	; save our own return address :)
	pop DIRECT_R7				; high byte to r7
	pop DIRECT_R6				; low byte to r6
	; now load our parameters
	pop DIRECT_R1				; load inclusive_max_value* to r1
	pop DIRECT_R0				; load variable* to r0
	mov a, @r1					; dereference inclusive_max_value to a
	; now do the decrement
	dec @r0						; decrement variable
	; check if we underflowed
	mov r5, #00h				; use r5 for return value (assume no underflow)
	clr c						; clear carry flag
	subb a, @r0					; subtract variable from inclusive_max_value
	jnc __Clock_Decrement_NoUnderflow
	; underflow
	mov a, @r1					; dereference inclusive_max_value to a
	mov @r0, a					; reset variable to inclusive_max_value
	mov r5, #0ffh				; set return value to 0xff
__Clock_Decrement_NoUnderflow:
	push DIRECT_R5				; push return value to stack
	push DIRECT_R6				; restore return address (low byte)
	push DIRECT_R7				; restore return address (high byte)
	ret

Clock_IncrementSeconds:
	push CLOCK_SECONDS_PTR		; load seconds pointer to stack
	push CLOCK_MAX_SECONDS_PTR	; load max seconds pointer to stack
	lcall Clock_Increment		; call Clock_Increment
	pop DIRECT_R0				; pop return value (overflow flag) from stack
	mov a, r0					; load overflow flag to a
	jz __Clock_IncrementSeconds_NoOverflow
	; overflow, so increment minutes
	lcall Clock_IncrementMinutes
__Clock_IncrementSeconds_NoOverflow:
	ret

Clock_IncrementMinutes:
	push CLOCK_MINUTES_PTR		; load minutes pointer to stack
	push CLOCK_MAX_MINUTES_PTR	; load max minutes pointer to stack
	lcall Clock_Increment		; call Clock_Increment
	pop DIRECT_R0				; pop return value (overflow flag) from stack
	mov a, r0					; load overflow flag to a
	jz __Clock_IncrementMinutes_NoOverflow
	; overflow, so increment hours
	lcall Clock_IncrementHours
__Clock_IncrementMinutes_NoOverflow:
	ret

Clock_IncrementHours:
	push CLOCK_HOURS_PTR		; load hours pointer to stack
	push CLOCK_MAX_HOURS_PTR	; load max hours pointer to stack
	lcall Clock_Increment		; call Clock_Increment
	pop DIRECT_R0				; discard return value (there are no days to increment)
	ret

; ============================================================================
;  								TEMPERATURE
; ============================================================================

; notifies the temperature sensor that a second has elapsed
Temperature_Notify:
	; TODO
	ret

; ============================================================================
; 									SORT
; ============================================================================
; sorts the array of uin8_t values in XRAM

Sort_Notify:
	; TODO
	ret