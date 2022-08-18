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
	mov	SP, #07h

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
	djnz 38h, __OnTick_End
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
	mov 38h, #40d
	ret

; stores the execution context in the swap area
EXC_STORE:
	mov 72h, psw
	mov 68h, a
	mov 69h, b
	mov 6Ah, r0
	mov 6Bh, r1
	mov 6Ch, r2
	mov 6Dh, r3
	mov 6Eh, r4
	mov 6Fh, r5
	mov 70h, r6
	mov 71h, r7
	mov 73h, p2
	; store UINT32_0
	mov 74h, 30h
	mov 75h, 31h
	mov 76h, 32h
	mov 77h, 33h
	; store UINT32_1
	mov 78h, 34h
	mov 79h, 35h
	mov 7Ah, 36h
	mov 7Bh, 37h
	ret

; restores the execution context from the swap area
EXC_RESTORE:
	; restore UINT32_1
	mov 37h, 7Bh
	mov 36h, 7Ah
	mov 35h, 79h
	mov 34h, 78h
	; restore UINT32_0
	mov 33h, 77h
	mov 32h, 76h
	mov 31h, 75h
	mov 30h, 74h
	mov p2, 73h
	mov r7, 71h
	mov r6, 70h
	mov r5, 6Fh
	mov r4, 6Eh
	mov r3, 6Dh
	mov r2, 6Ch
	mov r1, 6Bh
	mov r0, 6Ah
	mov b, 69h
	mov a, 68h
	mov psw, 72h
	ret

; modifies a, b, r0-r3
; void ShiftLeft32(uint32_t* value, byte count);
ShiftLeft32:
	; store our return address
	pop 03h			; high byte to r3
	pop 02h			; low byte to r2
	; now get parameters
	pop 01h			; count to r1
	pop 00h			; uint32_t* to r0
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
	push 02h			; low byte to stack
	push 03h			; high byte to stack
	ret

; modifies a, b, r0-r3
; void ShiftRight32(uint32_t* value, byte count);
ShiftRight32:
	; store our return address
	pop 03h			; high byte to r3
	pop 02h			; low byte to r2
	; now get parameters
	pop 01h			; count to r1
	pop 00h			; uint32_t* to r0
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
	push 02h			; low byte to stack
	push 03h			; high byte to stack
	ret

; adds the UINT32_0 to UINT32_1 and stores the result in UINT32_0
; void ShiftRight32();
Add32:
	; byte 0
	mov a, 30h		; load byte 0 (low byte) of UINT32_0 to a
	add a, 34h		; add byte 0 (low byte) of UINT32_1 to byte 0 of UINT32_0
	mov 30h, a		; store result in UINT32_0 low byte
	; byte 1
	mov a, 31h		; load byte 1 of UINT32_0 to a
	addc a, 35h		; add byte 1 of UINT32_1 to byte 1 of UINT32_0
	mov 31h, a		; store result in UINT32_0 byte 1
	; byte 2
	mov a, 32h		; load byte 2 of UINT32_0 to a
	addc a, 36h		; add byte 2 of UINT32_1 to byte 2 of UINT32_0
	mov 32h, a		; store result in UINT32_0 byte 2
	; byte 3
	mov a, 33h		; load byte 3 of UINT32_0 to a
	addc a, 37h		; add byte 3 of UINT32_1 to byte 3 of UINT32_0
	mov 33h, a		; store result in UINT32_0 byte 3
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
	mov r0, #40h
	mov @r0, #00h				; hours
	mov r0, #41h
	mov @r0, #00h				; minutes
	mov r0, #42h
	mov @r0, #00h				; seconds
	mov r0, #43h
	mov @r0, #23d
	mov r0, #44h
	mov @r0, #59d
	mov r0, #45h
	mov @r0, #59d
	lcall Clock_ResetTicks
	ret

; if (--clock_tick_counter == 0) 
; {
; 	  Clock_ResetTicks();
;	  Clock_OnEachSecond();
;  	  Temperature_Notify();
; }
Clock_Notify:
	djnz 46h, __Clock_NotifyEnd
	; a second has elapsed
	lcall Clock_ResetTicks
	lcall Clock_OnEachSecond
	lcall Temperature_Notify
__Clock_NotifyEnd:
	ret

Clock_ResetTicks:
	mov 46h, #100d
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
	mov a, #40h		; load hours pointer
	add a, r1					; add selection mask (offset) to pointer
	mov r3, a					; save pointer to r3
	push 03h				; push pointer to stack
	mov a, #43h	; load max hours pointer
	add a, r1					; add selection mask (offset) to pointer
	mov r3, a					; save pointer to r3
	push 03h				; push pointer to stack
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
	pop 00h				; 2 byte (discard return value)
	nop							; 1 byte
	nop							; 1 byte
	ret							; 1 byte
	lcall Clock_Decrement		; this is __OnEachSecond_Increment + 8 :)
	pop 00h				; 2 byte (discard return value)
	nop							; 1 byte
	nop							; 1 byte
	ret							; 1 byte

; if the value surpasses the inclusive overflow value (in params), it is reset to 0
; both parameters passed via stack.
; returns 0xff if overflow, 0 otherwise
; void Clock_Increment(uint8_t* variable, uint8_t* inclusive_overflow_value);
Clock_Increment:
	; save our own return address :)
	pop 07h				; high byte to r7
	pop 06h				; low byte to r6
	; now load our parameters
	pop 01h				; load inclusive_overflow_value* to r1
	pop 00h				; load variable* to r0
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
	push 05h				; push return value to stack
	push 06h				; restore return address (low byte)
	push 07h				; restore return address (high byte)
	ret

; if the value reaches 0, it is reset the maximum value < 255 (via params)
; both parameter passed via stack.
; returns 0xff if underflow, 0 otherwise
; void Clock_Decrement(uint8_t* variable, uint8_t* inclusive_max_value);
Clock_Decrement:
	; save our own return address :)
	pop 07h				; high byte to r7
	pop 06h				; low byte to r6
	; now load our parameters
	pop 01h				; load inclusive_max_value* to r1
	pop 00h				; load variable* to r0
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
	push 05h				; push return value to stack
	push 06h				; restore return address (low byte)
	push 07h				; restore return address (high byte)
	ret

Clock_IncrementSeconds:
	mov r0, #42h		; load seconds pointer to r0
	push 00h					; push pointer to stack
	mov r0, #45h	; load max seconds pointer to stack
	push 00h					; push pointer to stack
	lcall Clock_Increment			; call Clock_Increment
	pop 00h					; pop return value (overflow flag) from stack
	mov a, r0						; load overflow flag to a
	jz __Clock_IncrementSeconds_NoOverflow
	; overflow, so increment minutes
	lcall Clock_IncrementMinutes
__Clock_IncrementSeconds_NoOverflow:
	ret

Clock_IncrementMinutes:
	mov r0, #41h		; load minutes pointer to r0
	push 00h					; push pointer to stack
	mov r0, #44h	; load max minutes pointer to stack
	push 00h					; push pointer to stack
	lcall Clock_Increment			; call Clock_Increment
	pop 00h					; pop return value (overflow flag) from stack
	mov a, r0						; load overflow flag to a
	jz __Clock_IncrementMinutes_NoOverflow
	; overflow, so increment hours
	lcall Clock_IncrementHours
__Clock_IncrementMinutes_NoOverflow:
	ret

Clock_IncrementHours:
	mov r0, #40h		; load hours pointer to r0
	push 00h				; push pointer to stack
	mov r0, #43h	; load max hours pointer to stack
	push 00h				; push pointer to stack
	lcall Clock_Increment		; call Clock_Increment
	pop 00h				; discard return value (there are no days to increment)
	ret

; ============================================================================
;  								TEMPERATURE
; ============================================================================

; setup code for the temperature sensor
Temperature_Init:
	lcall Temperature_ResetTicks
	lcall Temperature_ResetRingBufferPointer
	; clear average
	mov 5Bh, #0h
	; set drift to "steady" for now
	mov 5Ch, #ffh
	; clear temperature buffer (all 0)

	; buffer--; // loop breaks before setting the first element :P
	; int i = buffer.Length + 1; // loop pre-decrements (add offset from previous line)
	; do 
	; {
	;	  if (--i == 0) break; 
	; 	  buffer[i] = 0;
	; } 
	; while (i > 0);
	mov r2, #50h 		; load ring buffer base address to r2
	dec r2									; dumb offset to get the first element
	mov r1, #10d	; load buffer size to r1 (loop counter)
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
	djnz 5Ah, __Temperature_NotifyEnd
	lcall Temperature_ResetTicks
	lcall Temperature_Measure
__Temperature_NotifyEnd:
	ret

Temperature_ResetTicks:
	; reset temperature ticks
	mov 5Ah, #01d	
	ret

; reads the temperature from port 2.
Temperature_Measure:
	mov r2, p2							; get snapshot of current temperature
	mov r1, 5Dh	; load ring buffer pointer to r1
	mov a, #50h 		; load ring buffer base address to a
	add a, r1							; add ring buffer pointer to base address to a
	mov r0, a							; target address to r0
	mov a, r2							; load temperature to a
	mov @r0, a							; store temperature in ring buffer
	inc 5Dh		; increment ring buffer pointer
	; check if ring buffer pointer is at the end of the buffer
	mov a, #10d	; load ring buffer size to a
	xrl a, 5Dh	; compare ring buffer pointer to size
	jnz __Temperature_MeasureRingBufferEnd
	; ring buffer pointer is at the end of the buffer, so reset it to 0
	lcall Temperature_ResetRingBufferPointer
__Temperature_MeasureRingBufferEnd:
	lcall Temperature_CalculateAverage
	ret

Temperature_ResetRingBufferPointer:
	; reset ring buffer pointer to 0
	mov 5Dh, #0h
	ret

; calculates the average of the temperature buffer and determines the temperature drift.
Temperature_CalculateAverage:
	; calculate average (sum of all elements in the buffer divided by the number of elements)
	; sum = 0;
	mov 5Eh, #0h 		; low byte of sum
	mov 5Fh, #0h 		; high byte of sum
	; prepare loop:
	; for (uint8_t i = 0, uint8_t* p = buffer; i < buffer.Length; i++, p++)
	mov r1, #0							; uint8_t i = 0;
	mov r0, #50h		; uint8_t* p = buffer;
__Temperature_CalculateAverage_LoopHeader:
	mov a, #10d	; load ring buffer size to a
	xrl a, r1							; i < buffer.Length
	jz __Temperature_CalculateAverage_LoopBreak
	mov a, @r0							; element = *p;
	; sum += element;
	add a, 5Eh			; temp = element + sum.low 
	mov 5Eh, a			; sum.low = temp
	mov a, #0
	addc a, 5Fh		; temp = carry + sum.high
	mov 5Fh, a			; sum.high = temp
	inc r1								; i++;
	inc r0								; p++;
	jmp __Temperature_CalculateAverage_LoopHeader
__Temperature_CalculateAverage_LoopBreak:
	; we now have the sum of all elements in the buffer in sum.low and sum.high
	; calculate average (divide sum by number of elements, divide by 10)
	lcall Temperature_16BitDivideBy10
	pop 01h						; pop new average value into r1
	mov r0, 5Bh			; load old average to r0
	; calculate temperature drift (old average vs new average)
	; result goes in r5
	mov r5, #ffh	; assume steady drift (old average == new average)
	mov a, r0							; load old average to a
	xrl a, r1							; compare old average to new average
	jz __Temperature_CalculateAverage_End
	; new average is different from old average, so determine temperature drift
	mov r5, #1d	; assume rising drift
	mov a, r0							; load old average to a
	clr c								; clear carry
	subb a, r1							; a = old average - new average
	jc __Temperature_CalculateAverage_End
	; new average is lower than old average.
	mov r5, #0d
__Temperature_CalculateAverage_End:
	; we know the new average and the new temperature drift.
	; -> update the average and drift variables
	mov 5Bh, r1			; update average
	mov 5Ch, r5			; update drift
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
	mov a, 33h		; load upper byte of the two upper bytes of intermediate_result to a
	clr c					; clear carry flag
	rrc a					; rotate right through carry
	mov 33h, a		; store upper byte back to byte 3 of UINT32_0

	mov a, 32h		; load lower byte of the two upper bytes of intermediate_result to a
	; don't clear carry flag, we need to treat this as the lower byte of an uint16_t.
	rrc a					; rotate right through carry
	mov 32h, a		; store lower byte back to byte 2 of UINT32_0
	ljmp __Temperature_DivideBy10_LoopHeader
__Temperature_DivideBy10_LoopBreak:
	; we did it :)
	; we also know that the average of uint8_t's will always be less than 0x100, so we can just
	; grab the lower byte of the upper two bytes of UINT32_0 and return it (byte 2).
	; first store our own return address
	pop 03h			; pop return address high byte into r3
	pop 02h			; pop return address low byte into r2
	; push result
	push 32h			; push average temperature to stack
	; push return address
	push 02h			; push return address low byte to stack
	push 03h			; push return address high byte to stack
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
	mov 30h, 5Eh
	; high byte of sum to byte 1 of UINT32_0
	mov 31h, 5Fh
	; clear high bytes of UINT32_0
	mov 32h, #0
	mov 33h, #0
	; accumulate += (sum << 2);	
	lcall Temperature_LoadSumToUINT32_1
	mov r0, #34h
	push 00h						; push (uint32_t*)&UINT32_1 to stack
	mov r0, #2d
	push 00h						; push 2d to stack
	lcall ShiftLeft32					; sum << 2 to UINT32_1
	lcall Add32
	; accumulate += (sum << 3);
	lcall Temperature_LoadSumToUINT32_1
	mov r0, #34h
	push 00h						; push (uint32_t*)&UINT32_1 to stack
	mov r0, #3d
	push 00h						; push 3d to stack
	lcall ShiftLeft32					; sum << 3 to UINT32_1
	lcall Add32
	; accumulate += (sum << 6);
	lcall Temperature_LoadSumToUINT32_1
	mov r0, #34h
	push 00h						; push (uint32_t*)&UINT32_1 to stack
	mov r0, #6d
	push 00h						; push 6d to stack
	lcall ShiftLeft32					; sum << 6 to UINT32_1
	lcall Add32
	; accumulate += (sum << 7);
	lcall Temperature_LoadSumToUINT32_1
	mov r0, #34h
	push 00h						; push (uint32_t*)&UINT32_1 to stack
	mov r0, #7d
	push 00h						; push 7d to stack
	lcall ShiftLeft32					; sum << 7 to UINT32_1
	lcall Add32
	; accumulate += (sum << 10);
	lcall Temperature_LoadSumToUINT32_1
	mov r0, #34h
	push 00h						; push (uint32_t*)&UINT32_1 to stack
	mov r0, #10d
	push 00h						; push 10d to stack
	lcall ShiftLeft32					; sum << 10 to UINT32_1
	lcall Add32
	; accumulate += (sum << 11);
	lcall Temperature_LoadSumToUINT32_1
	mov r0, #34h
	push 00h						; push (uint32_t*)&UINT32_1 to stack
	mov r0, #11d
	push 00h						; push 11d to stack
	lcall ShiftLeft32					; sum << 11 to UINT32_1
	lcall Add32
	; accumulate += (sum << 14);
	lcall Temperature_LoadSumToUINT32_1
	mov r0, #34h
	push 00h						; push (uint32_t*)&UINT32_1 to stack
	mov r0, #14d
	push 00h						; push 14d to stack
	lcall ShiftLeft32					; sum << 14 to UINT32_1
	lcall Add32
	; accumulate += (sum << 15);
	lcall Temperature_LoadSumToUINT32_1
	mov r0, #34h
	push 00h						; push (uint32_t*)&UINT32_1 to stack
	mov r0, #15d
	push 00h						; push 15d to stack
	lcall ShiftLeft32					; sum << 15 to UINT32_1
	lcall Add32
	; ez done :)
	ret

; loads and expands uint16_t temperature sum to uint32_t UINT32_1 register
Temperature_LoadSumToUINT32_1:
	; low byte of sum to byte 0 (low byte) of UINT32_1
	mov 34h, 5Eh
	; high byte of sum to byte 1 of UINT32_1
	mov 35h, 5Fh
	; clear high bytes of UINT32_1
	mov 36h, #0
	mov 37h, #0
	ret

; ============================================================================
; 									SORT
; ============================================================================
; sorts the array of uin8_t values in XRAM

; called only once, when the program starts
Sort_Notify:
	; TODO
	ret
