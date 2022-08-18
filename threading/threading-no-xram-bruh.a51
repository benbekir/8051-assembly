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

; ============================================================================

; Scheduler
; addresses
; must be STACK_START = 0x8-1 = 7, because of the stack pointer
#DEFINE STACK_START			#07h
; universal buffer for 32 bit calculations
#DEFINE UINT32_00			30h
#DEFINE UINT32_01			31h
#DEFINE UINT32_02			32h
#DEFINE UINT32_03			33h
; second universal buffer for 32 bit calculations
#DEFINE UINT32_10			34h
#DEFINE UINT32_11			35h
#DEFINE UINT32_12			36h
#DEFINE UINT32_13			37h
#DEFINE TICK_COUNTER 		38h

; constants
; 40 at 4000Hz = 10 ms
#DEFINE TICK_RESET_VALUE	#40d
#DEFINE UINT32_0_PTR		#30h
#DEFINE UINT32_1_PTR		#34h

; ============================================================================

; SWAP area
#DEFINE SWAP_A			68h
#DEFINE SWAP_B			69h
#DEFINE SWAP_R0			6Ah
#DEFINE SWAP_R1			6Bh
#DEFINE SWAP_R2			6Ch
#DEFINE SWAP_R3			6Dh
#DEFINE SWAP_R4			6Eh
#DEFINE SWAP_R5			6Fh
#DEFINE SWAP_R6			70h
#DEFINE SWAP_R7			71h
#DEFINE SWAP_PSW		72h
; port 2 conflicts between XRAM access and temperature sensor
#DEFINE SWAP_P2			73h

#DEFINE SWAP_UINT32_00	74h
#DEFINE SWAP_UINT32_01	75h
#DEFINE SWAP_UINT32_02	76h
#DEFINE SWAP_UINT32_03	77h

#DEFINE SWAP_UINT32_10	78h
#DEFINE SWAP_UINT32_11	79h
#DEFINE SWAP_UINT32_12	7Ah
#DEFINE SWAP_UINT32_13	7Bh

; ============================================================================

; CLOCK
; memory addresses
#DEFINE CLOCK_HOURS_PTR			#40h
#DEFINE CLOCK_MINUTES_PTR		#41h
#DEFINE CLOCK_SECONDS_PTR		#42h
#DEFINE CLOCK_MAX_HOURS_PTR		#43h
#DEFINE CLOCK_MAX_MINUTES_PTR	#44h
#DEFINE CLOCK_MAX_SECONDS_PTR	#45h
#DEFINE CLOCK_TICK_COUNTER		46h		

; constants
#DEFINE CLOCK_MAX_HOURS			#23d
#DEFINE CLOCK_MAX_MINUTES		#59d
#DEFINE CLOCK_MAX_SECONDS		#59d
; 100 at 100Hz = 1s
#DEFINE CLOCK_TICK_RESET_VALUE	#100d

; ============================================================================

; TEMPERATURE
; memory addresses
#DEFINE TEMPERATURE_RING_BUFFER		#50h
#DEFINE TEMPERATURE_TICKS			5Ah
#DEFINE TEMPERATURE_AVERAGE			5Bh
#DEFINE TEMPERATURE_DRIFT			5Ch
#DEFINE TEMPERATURE_RING_BUFFER_PTR	5Dh
#DEFINE TEMPERATURE_SUM_LOW			5Eh
#DEFINE TEMPERATURE_SUM_HIGH		5Fh

; constants
#DEFINE TEMPERATURE_RING_BUFFER_SIZE	#10d
; 10 at 1Hz = 10s
#DEFINE TEMPERATURE_TICKS_RESET_VALUE	#10d
#DEFINE TEMPERATURE_DRIFT_FALLING		#0d
#DEFINE TEMPERATURE_DRIFT_RISING		#1d
#DEFINE TEMPERATURE_DRIFT_STEADY		#ffh

; ============================================================================
; <!-------------------- NO DEFINITIONS BELOW THIS LINE -------------------->
; ============================================================================

; must be up here if we want to preserve the MEMORY SETUP documentation
; the pre-assembler will strip everything until the first non-comment or #DEFINE
; so you won't see this comment in the generated code :)
#cpu = 89S8252    ; @12 MHz
#use LCALL

; ============================================================================
; 								MEMORY SETUP
; ============================================================================
;
;  Region        | Start | End   | Size | Description
;  --------------+-------+-------+------+----------------------------------------------
;  RESERVED      | 0x0	 | 0x8	 | 8    | register bank 0
;  --------------+-------+-------+------+----------------------------------------------
;  STACK         | 0x8	 | 0x2f	 | 24   | stack
;  --------------+-------+-------+------+----------------------------------------------
;  RAM 1	  	 | 0x30	 | 0x3f	 | 16   | RAM for Task 1: Scheduler
;  --------------+-------+-------+------+----------------------------------------------
;  RAM 2    	 | -	 | -	 | 0    | RAM for Task 2: Reaction (allocation free)
;  --------------+-------+-------+------+----------------------------------------------
;  RAM 3	  	 | 0x40	 | 0x4f	 | 16   | RAM for Task 3: Clock
;  --------------+-------+-------+------+----------------------------------------------
;  RAM 3B	  	 | 0x50	 | 0x5f	 | 16   | RAM for Task 3B: Temperature
;  --------------+-------+-------+------+----------------------------------------------
;  RAM 4  	 	 | 0x60	 | 0x67  | 8    | RAM for Task 4: Sorting
;  --------------+-------+-------+------+----------------------------------------------
;  SWAP 		 | 0x68	 | 0x7f	 | 24   | swap area for execution context

; < 10 ms @12 MHz <=> 0.01 s / cycle @12,000,000Hz @ ~2cycles / instruction 
; => ~60,000 instructions per interrupt
; more than enough for basically all tasks to run to completion (except sorting task)
; => use single stack for all tasks!
; expected program flow:
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
	lcall ResetTicks

	orl TMOD, # 02h    ; Timer 0 im 8-Bit Autoreload-Modus. 
	; Die �berlauffrequenz des Timer 0 betr�gt 4000 Hz, die Periodendauer 0,25 ms.
	mov TH0, # 06h    ; Reloadwert

	; Interrupts
	setb ET0    ; Timer 0 Interrupt freigeben
	setb EA    ; globale Interruptfreigabe
	setb TR0    ; Timer 0 l�uft.

	; initialize clock
	lcall Clock_Init
	lcall Temperature_Init

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
	mov SWAP_P2, p2
	; store UINT32_0
	mov SWAP_UINT32_00, UINT32_00
	mov SWAP_UINT32_01, UINT32_01
	mov SWAP_UINT32_02, UINT32_02
	mov SWAP_UINT32_03, UINT32_03
	; store UINT32_1
	mov SWAP_UINT32_10, UINT32_10
	mov SWAP_UINT32_11, UINT32_11
	mov SWAP_UINT32_12, UINT32_12
	mov SWAP_UINT32_13, UINT32_13
	ret

; restores the execution context from the swap area
EXC_RESTORE:
	; restore UINT32_1
	mov UINT32_13, SWAP_UINT32_13
	mov UINT32_12, SWAP_UINT32_12
	mov UINT32_11, SWAP_UINT32_11
	mov UINT32_10, SWAP_UINT32_10
	; restore UINT32_0
	mov UINT32_03, SWAP_UINT32_03
	mov UINT32_02, SWAP_UINT32_02
	mov UINT32_01, SWAP_UINT32_01
	mov UINT32_00, SWAP_UINT32_00
	mov p2, SWAP_P2
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

; modifies a, b, r0-r3
; void ShiftLeft32(uint32_t* value, byte count);
ShiftLeft32:
	; store our return address
	pop DIRECT_R3			; high byte to r3
	pop DIRECT_R2			; low byte to r2
	; now get parameters
	pop DIRECT_R1			; count to r1
	pop DIRECT_R0			; uint32_t* to r0
	mov b, r0 				; store backup of uint32_t* in b
	; shift left
__ShiftLeft32_Loop:
	mov a, r1				; count to a
	jz __ShiftLeft32_End	; if count == 0, we are done
	clr c					; clear carry
	; byte 0
	mov a, @r0				; get byte 0 (lowest byte) of uint32_t value to a
	rlc a					; rotate left through carry
	mov @r0, a				; store result in uint32_t value
	inc r0					; increment pointer to next byte
	; byte 1
	mov a, @r0				; get byte 1 of uint32_t value to a
	rlc a					; rotate left through carry
	mov @r0, a				; store result in uint32_t value
	inc r0					; increment pointer to next byte
	; byte 2
	mov a, @r0				; get byte 2 of uint32_t value to a
	rlc a					; rotate left through carry
	mov @r0, a				; store result in uint32_t value
	inc r0					; increment pointer to next byte
	; byte 3
	mov a, @r0				; get byte 3 of uint32_t value to a
	rlc a					; rotate left through carry
	mov @r0, a				; store result in uint32_t value
	mov r0, b				; restore uint32_t*
	; decrement count and loop
	dec r1					
	ljmp __ShiftLeft32_Loop
__ShiftLeft32_End:
	; now restore the return address
	push DIRECT_R2			; low byte to stack
	push DIRECT_R3			; high byte to stack
	ret

; modifies a, b, r0-r3
; void ShiftRight32(uint32_t* value, byte count);
ShiftRight32:
	; store our return address
	pop DIRECT_R3			; high byte to r3
	pop DIRECT_R2			; low byte to r2
	; now get parameters
	pop DIRECT_R1			; count to r1
	pop DIRECT_R0			; uint32_t* to r0
	; this time we need to start shifting at the highest byte
	mov a, r0 				; uint32_t* to a
	add a, #3				; add 3 to a to get pointer at highest byte
	mov r0, a				; store pointer back to r0
	mov b, a				; create backup of high byte pointer in b
	; right left
__ShiftRight32_Loop:
	mov a, r1				; count to a
	jz __ShiftRight32_End	; if count == 0, we are done
	clr c					; clear carry
	; byte 3
	mov a, @r0				; get byte 3 (highest byte) of uint32_t value to a
	rrc a					; rotate right through carry
	mov @r0, a				; store result in uint32_t value
	dec r0					; decrement pointer to next byte
	; byte 2
	mov a, @r0				; get byte 2 of uint32_t value to a
	rrc a					; rotate right through carry
	mov @r0, a				; store result in uint32_t value
	dec r0					; decrement pointer to next byte
	; byte 1
	mov a, @r0				; get byte 1 of uint32_t value to a
	rrc a					; rotate right through carry
	mov @r0, a				; store result in uint32_t value
	dec r0					; decrement pointer to next byte
	; byte 0
	mov a, @r0				; get byte 0 of uint32_t value to a
	rrc a					; rotate right through carry
	mov @r0, a				; store result in uint32_t value
	mov r0, b				; restore uint32_t* from b
	; decrement count and loop
	dec r1
	ljmp __ShiftRight32_Loop
__ShiftRight32_End:
	; now restore the return address
	push DIRECT_R2			; low byte to stack
	push DIRECT_R3			; high byte to stack
	ret

; adds the UINT32_0 to UINT32_1 and stores the result in UINT32_0
; void ShiftRight32();
Add32:
	; byte 0
	mov a, UINT32_00		; load byte 0 (low byte) of UINT32_0 to a
	add a, UINT32_10		; add byte 0 (low byte) of UINT32_1 to byte 0 of UINT32_0
	mov UINT32_00, a		; store result in UINT32_0 low byte
	; byte 1
	mov a, UINT32_01		; load byte 1 of UINT32_0 to a
	addc a, UINT32_11		; add byte 1 of UINT32_1 to byte 1 of UINT32_0
	mov UINT32_01, a		; store result in UINT32_0 byte 1
	; byte 2
	mov a, UINT32_02		; load byte 2 of UINT32_0 to a
	addc a, UINT32_12		; add byte 2 of UINT32_1 to byte 2 of UINT32_0
	mov UINT32_02, a		; store result in UINT32_0 byte 2
	; byte 3
	mov a, UINT32_03		; load byte 3 of UINT32_0 to a
	addc a, UINT32_13		; add byte 3 of UINT32_1 to byte 3 of UINT32_0
	mov UINT32_03, a		; store result in UINT32_0 byte 3
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
	anl a, #3h			; check mode bits only
	; if mode bits are not zero, set clock
	jnz __Clock_OnEachSecond_SetTime
__Clock_OnEachSecond_Normal:
	; normal mode, increment seconds
	lcall Clock_IncrementSeconds
	ljmp __Clock_OnEachSecond_End
__Clock_OnEachSecond_SetTime:
	; set time mode
	clr c						; clear carry flag
	rrc a						; rotate carry flag into a
	; a is now 0 (increment mode) or 1 (decrement mode)
	mov r0, a					; save mode mask to r0
	; now load selection
	mov a, r2					; copy port 0 to a
	anl a, #0ch					; check selection bits only
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
	mov r0, CLOCK_SECONDS_PTR		; load seconds pointer to r0
	push DIRECT_R0					; push pointer to stack
	mov r0, CLOCK_MAX_SECONDS_PTR	; load max seconds pointer to stack
	push DIRECT_R0					; push pointer to stack
	lcall Clock_Increment			; call Clock_Increment
	pop DIRECT_R0					; pop return value (overflow flag) from stack
	mov a, r0						; load overflow flag to a
	jz __Clock_IncrementSeconds_NoOverflow
	; overflow, so increment minutes
	lcall Clock_IncrementMinutes
__Clock_IncrementSeconds_NoOverflow:
	ret

Clock_IncrementMinutes:
	mov r0, CLOCK_MINUTES_PTR		; load minutes pointer to r0
	push DIRECT_R0					; push pointer to stack
	mov r0, CLOCK_MAX_MINUTES_PTR	; load max minutes pointer to stack
	push DIRECT_R0					; push pointer to stack
	lcall Clock_Increment			; call Clock_Increment
	pop DIRECT_R0					; pop return value (overflow flag) from stack
	mov a, r0						; load overflow flag to a
	jz __Clock_IncrementMinutes_NoOverflow
	; overflow, so increment hours
	lcall Clock_IncrementHours
__Clock_IncrementMinutes_NoOverflow:
	ret

Clock_IncrementHours:
	mov r0, CLOCK_HOURS_PTR		; load hours pointer to r0
	push DIRECT_R0				; push pointer to stack
	mov r0, CLOCK_MAX_HOURS_PTR	; load max hours pointer to stack
	push DIRECT_R0				; push pointer to stack
	lcall Clock_Increment		; call Clock_Increment
	pop DIRECT_R0				; discard return value (there are no days to increment)
	ret

; ============================================================================
;  								TEMPERATURE
; ============================================================================

; setup code for the temperature sensor
Temperature_Init:
	lcall Temperature_ResetTicks
	lcall Temperature_ResetRingBufferPointer
	; clear average
	mov TEMPERATURE_AVERAGE, #0h
	; set drift to "steady" for now
	mov TEMPERATURE_DRIFT, TEMPERATURE_DRIFT_STEADY
	; clear temperature buffer (all 0)

	; buffer--; // loop breaks before setting the first element :P
	; int i = buffer.Length + 1; // loop pre-decrements (add offset from previous line)
	; do 
	; {
	;	  if (--i == 0) break; 
	; 	  buffer[i] = 0;
	; } 
	; while (i > 0);
	mov r2, TEMPERATURE_RING_BUFFER 		; load ring buffer base address to r2
	dec r2									; dumb offset to get the first element
	mov r1, TEMPERATURE_RING_BUFFER_SIZE	; load buffer size to r1 (loop counter)
	inc r1									; add 1 to r1 (loop counter)
__Temperature_InitLoopHeader:
	djnz r1, __Temperature_InitLoop
	jmp __Temperature_InitLoopBreak
__Temperature_InitLoop:
	mov a, r2								; load ring buffer base address to a
	add a, r1								; add offfset to base address to a
	mov r0, a								; target address to r0
	mov @r0, #0								; set element to 0
	ljmp __Temperature_InitLoopHeader		; loop
__Temperature_InitLoopBreak:
	ret

; notifies the temperature sensor that a second has elapsed
; if (--temperature_ticks == 0) 
; {
;      Temperature_ResetTicks();
;      Temperature_Measure();
; }
Temperature_Notify:
	djnz TEMPERATURE_TICKS, __Temperature_NotifyEnd
	lcall Temperature_ResetTicks
	lcall Temperature_Measure
__Temperature_NotifyEnd:
	ret

Temperature_ResetTicks:
	; reset temperature ticks
	mov TEMPERATURE_TICKS, TEMPERATURE_TICKS_RESET_VALUE	
	ret

; reads the temperature from port 2.
Temperature_Measure:
	mov r2, p2							; get snapshot of current temperature
	mov r1, TEMPERATURE_RING_BUFFER_PTR	; load ring buffer pointer to r1
	mov a, TEMPERATURE_RING_BUFFER 		; load ring buffer base address to a
	add a, r1							; add ring buffer pointer to base address to a
	mov r0, a							; target address to r0
	mov a, r2							; load temperature to a
	mov @r0, a							; store temperature in ring buffer
	inc TEMPERATURE_RING_BUFFER_PTR		; increment ring buffer pointer
	; check if ring buffer pointer is at the end of the buffer
	mov a, TEMPERATURE_RING_BUFFER_SIZE	; load ring buffer size to a
	xrl a, TEMPERATURE_RING_BUFFER_PTR	; compare ring buffer pointer to size
	jnz __Temperature_MeasureRingBufferEnd
	; ring buffer pointer is at the end of the buffer, so reset it to 0
	lcall Temperature_ResetRingBufferPointer
__Temperature_MeasureRingBufferEnd:
	lcall Temperature_CalculateAverage
	ret

Temperature_ResetRingBufferPointer:
	; reset ring buffer pointer to 0
	mov TEMPERATURE_RING_BUFFER_PTR, #0h
	ret

; calculates the average of the temperature buffer and determines the temperature drift.
Temperature_CalculateAverage:
	; calculate average (sum of all elements in the buffer divided by the number of elements)
	; sum = 0;
	mov TEMPERATURE_SUM_LOW, #0h 		; low byte of sum
	mov TEMPERATURE_SUM_HIGH, #0h 		; high byte of sum
	; prepare loop:
	; for (uint8_t i = 0, uint8_t* p = buffer; i < buffer.Length; i++, p++)
	mov r1, #0							; uint8_t i = 0;
	mov r0, TEMPERATURE_RING_BUFFER		; uint8_t* p = buffer;
__Temperature_CalculateAverage_LoopHeader:
	mov a, TEMPERATURE_RING_BUFFER_SIZE	; load ring buffer size to a
	xrl a, r1							; i < buffer.Length
	jz __Temperature_CalculateAverage_LoopBreak
	mov a, @r0							; element = *p;
	; sum += element;
	add a, TEMPERATURE_SUM_LOW			; temp = element + sum.low 
	mov TEMPERATURE_SUM_LOW, a			; sum.low = temp
	mov a, #0
	addc a, TEMPERATURE_SUM_HIGH		; temp = carry + sum.high
	mov TEMPERATURE_SUM_HIGH, a			; sum.high = temp
	inc r1								; i++;
	inc r0								; p++;
	jmp __Temperature_CalculateAverage_LoopHeader
__Temperature_CalculateAverage_LoopBreak:
	; we now have the sum of all elements in the buffer in sum.low and sum.high
	; calculate average (divide sum by number of elements, divide by 10)
	lcall Temperature_16BitDivideBy10
	pop DIRECT_R1						; pop new average value into r1
	mov r0, TEMPERATURE_AVERAGE			; load old average to r0
	; calculate temperature drift (old average vs new average)
	; result goes in r5
	mov r5, TEMPERATURE_DRIFT_STEADY	; assume steady drift (old average == new average)
	mov a, r0							; load old average to a
	xrl a, r1							; compare old average to new average
	jz __Temperature_CalculateAverage_End
	; new average is different from old average, so determine temperature drift
	mov r5, TEMPERATURE_DRIFT_RISING	; assume rising drift
	mov a, r0							; load old average to a
	clr c								; clear carry
	subb a, r1							; a = old average - new average
	jc __Temperature_CalculateAverage_End
	; new average is lower than old average.
	mov r5, TEMPERATURE_DRIFT_FALLING
__Temperature_CalculateAverage_End:
	; we know the new average and the new temperature drift.
	; -> update the average and drift variables
	mov TEMPERATURE_AVERAGE, r1			; update average
	mov TEMPERATURE_DRIFT, r5			; update drift
	ret

; divides the temperature sum by 10 to produce the average temperature
; the result will be returned on the stack
Temperature_16BitDivideBy10:
	; we can't divide a 16 bit number by 10 on hardware, so we have to do it manually :P 
	; we start by multiplying the sum by 0xcccd.
	; the 0xcccd magic number was determined by C# compiler optimization.
	; see: https://sharplab.io/#v2:EYLgxg9gTgpgtADwGwBYA0AXEBDAzgWwB8ABAJgEYBYAKGIGYACMhgYQZoG8aGenGBXAJYA7DAwAiggG4AhAJ7kADAAohohlOwAbfjACU7arwZcjx3sQDsG7boYB6Bkv4BubrwC+ND0A
	; finally the result is shifted right by 19 bits (thogh we'll do some pointer magic to reduce operations).
	; also we can't multiply by 0xcccd on hardware, so we have to do that manually too oO
	; all of this is the same as dividing the 16 bit sum by 10.
	
	; multiply sum by 0xcccd
	; again, the multiplication has to be done manually using a lot of shifting...
	lcall Temperature_MultiplySumBy0xcccd
	; we now have the 32 bit intermediate_result in the custom UINT32_0 register.
	; in theory we have to shift the result right by 19 bits, but we can do that easier.
	; we know when shifting right by 19 bits the lower 2 bytes are just discarded, so
	; we can just grab the upper bytes and shift them right by 3 bits.
	; something like this:
	; uint16_t final_result = (uint16_t)(*((uint16_t*)&intermediate_result + 1) >> 3);
	; but you know the deal, we can't do that on hardware, so we have to do it manually :)
	mov r0, #4				; prepare loop counter (must be 4 because we pre-decrement :/)
__Temperature_DivideBy10_LoopHeader:
	djnz r0, __Temperature_DivideBy10_Loop
	ljmp __Temperature_DivideBy10_LoopBreak
__Temperature_DivideBy10_Loop:
	mov a, UINT32_03		; load upper byte of the two upper bytes of intermediate_result to a
	clr c					; clear carry flag
	rrc a					; rotate right through carry
	mov UINT32_03, a		; store upper byte back to byte 3 of UINT32_0

	mov a, UINT32_02		; load lower byte of the two upper bytes of intermediate_result to a
	; don't clear carry flag, we need to treat this as the lower byte of an uint16_t.
	rrc a					; rotate right through carry
	mov UINT32_02, a		; store lower byte back to byte 2 of UINT32_0
	ljmp __Temperature_DivideBy10_LoopHeader
__Temperature_DivideBy10_LoopBreak:
	; we did it :)
	; we also know that the average of uint8_t's will always be less than 0x100, so we can just
	; grab the lower byte of the upper two bytes of UINT32_0 and return it (byte 2).
	; first store our own return address
	pop DIRECT_R3			; pop return address high byte into r3
	pop DIRECT_R2			; pop return address low byte into r2
	; push result
	push UINT32_02			; push average temperature to stack
	; push return address
	push DIRECT_R2			; push return address low byte to stack
	push DIRECT_R3			; push return address high byte to stack
	ret

; multiplies the temperature sum by 0xcccd and returns the result in UINT32_0.
; helper function for Temperature_CalculateAverage
; modifies registers UINT32_0, UINT32_1 and a, b, r0-3
Temperature_MultiplySumBy0xcccd:
	; we can't multiply a 16 bit number by 0xcccd on hardware, so we have to do it manually :P
	; also the result will yield a 32 bit number, so we have to do some extra work so support shifts.
	; 0xcccd looks like 1100_1100_1100_1101 in binary. so any number n can be multiplied by 0xcccd by simply
	; doing *a lot* of shifts and adding.
	; result = n + (n << 2) + (n << 3) + (n << 6) + (n << 7) + (n << 10) + (n << 11) + (n << 14) + (n << 15)
	; where the shifts represnt the binary index of the 1's in 0xcccd :)

	; UINT32_0 will be the accumulator holding the result, 
	; UINT32_1 will be temporary storage for shifting
	; load uint16_t temperature sum to uint32_t "UINT32_0"
	; accumulate = sum;
	; low byte of sum to byte 0 (low byte) of UINT32_0
	mov UINT32_00, TEMPERATURE_SUM_LOW
	; high byte of sum to byte 1 of UINT32_0
	mov UINT32_01, TEMPERATURE_SUM_HIGH
	; clear high bytes of UINT32_0
	mov UINT32_02, #0
	mov UINT32_03, #0
	; accumulate += (sum << 2);	
	lcall Temperature_LoadSumToUINT32_1
	mov r0, UINT32_1_PTR
	push DIRECT_R0						; push (uint32_t*)&UINT32_1 to stack
	mov r0, #2d
	push DIRECT_R0						; push 2d to stack
	lcall ShiftLeft32					; sum << 2 to UINT32_1
	lcall Add32
	; accumulate += (sum << 3);
	lcall Temperature_LoadSumToUINT32_1
	mov r0, UINT32_1_PTR
	push DIRECT_R0						; push (uint32_t*)&UINT32_1 to stack
	mov r0, #3d
	push DIRECT_R0						; push 3d to stack
	lcall ShiftLeft32					; sum << 3 to UINT32_1
	lcall Add32
	; accumulate += (sum << 6);
	lcall Temperature_LoadSumToUINT32_1
	mov r0, UINT32_1_PTR
	push DIRECT_R0						; push (uint32_t*)&UINT32_1 to stack
	mov r0, #6d
	push DIRECT_R0						; push 6d to stack
	lcall ShiftLeft32					; sum << 6 to UINT32_1
	lcall Add32
	; accumulate += (sum << 7);
	lcall Temperature_LoadSumToUINT32_1
	mov r0, UINT32_1_PTR
	push DIRECT_R0						; push (uint32_t*)&UINT32_1 to stack
	mov r0, #7d
	push DIRECT_R0						; push 7d to stack
	lcall ShiftLeft32					; sum << 7 to UINT32_1
	lcall Add32
	; accumulate += (sum << 10);
	lcall Temperature_LoadSumToUINT32_1
	mov r0, UINT32_1_PTR
	push DIRECT_R0						; push (uint32_t*)&UINT32_1 to stack
	mov r0, #10d
	push DIRECT_R0						; push 10d to stack
	lcall ShiftLeft32					; sum << 10 to UINT32_1
	lcall Add32
	; accumulate += (sum << 11);
	lcall Temperature_LoadSumToUINT32_1
	mov r0, UINT32_1_PTR
	push DIRECT_R0						; push (uint32_t*)&UINT32_1 to stack
	mov r0, #11d
	push DIRECT_R0						; push 11d to stack
	lcall ShiftLeft32					; sum << 11 to UINT32_1
	lcall Add32
	; accumulate += (sum << 14);
	lcall Temperature_LoadSumToUINT32_1
	mov r0, UINT32_1_PTR
	push DIRECT_R0						; push (uint32_t*)&UINT32_1 to stack
	mov r0, #14d
	push DIRECT_R0						; push 14d to stack
	lcall ShiftLeft32					; sum << 14 to UINT32_1
	lcall Add32
	; accumulate += (sum << 15);
	lcall Temperature_LoadSumToUINT32_1
	mov r0, UINT32_1_PTR
	push DIRECT_R0						; push (uint32_t*)&UINT32_1 to stack
	mov r0, #15d
	push DIRECT_R0						; push 15d to stack
	lcall ShiftLeft32					; sum << 15 to UINT32_1
	lcall Add32
	; ez done :)
	ret

; loads and expands uint16_t temperature sum to uint32_t UINT32_1 register
Temperature_LoadSumToUINT32_1:
	; low byte of sum to byte 0 (low byte) of UINT32_1
	mov UINT32_10, TEMPERATURE_SUM_LOW
	; high byte of sum to byte 1 of UINT32_1
	mov UINT32_11, TEMPERATURE_SUM_HIGH
	; clear high bytes of UINT32_1
	mov UINT32_12, #0
	mov UINT32_13, #0
	ret

; ============================================================================
; 									SORT
; ============================================================================
; sorts the array of uin8_t values in XRAM

; called only once, when the program starts
Sort_Notify:
	; TODO
	ret