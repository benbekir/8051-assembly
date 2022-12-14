; ============================================================================
; 								   MACROS
; ============================================================================

#DEFINE STACK_START				#3fh
; macro for direct address containing register bank index
#DEFINE SF_REGISTER_BANK_SELECT #3fh
; macro for direct address of push / pop buffer
#DEFINE SF_DIRECT 				3eh
; macro for direct address of push / pop buffer 2
#DEFINE SF_DIRECT_2				3dh

; ============================================================================
; 								STACK SETUP
; ============================================================================
;
; - internal stack starts at 0x40 and grows to 0x80
; - function SF_STORE is called to store the current stack frame (contents of r0 - r7).
; 		- if possible, this is done by switching register banks.
; 		- if not possible, the contents of r0 - r7 are stored on the stack where the top most entry is r7.
; - function SF_RESTORE is called to restore the stack frame (contents of r0 - r7).
; parameters and return values are also stored on the stack.

; NOTE: Weitere Dokumentation kann unter 'documentation/'documentation' gefunden werden.

#cpu = 89S8252    ; @12 MHz

ajmp Initialisierung

Timer 0:    ; Timer 0 Interrupt
    ajmp OnTick

Initialisierung:
	; setup stack
	mov	SP, STACK_START
	; set REGISTER_BANK_SELECT = 0
	mov r0, SF_REGISTER_BANK_SELECT
	mov @r0, #0h

	orl TMOD, # 02h    ; Timer 0 im 8-Bit Autoreload-Modus. 
	; Die �berlauffrequenz des Timer 0 betr�gt 4000 Hz, die Periodendauer 0,25 ms.
	mov TH0, # 06h    ; Reloadwert

	; Interrupts
	setb ET0    ; Timer 0 Interrupt freigeben
	setb EA    ; globale Interruptfreigabe
	setb TR0    ; Timer 0 l�uft.

	; reset clock tick counter
	lcall ResetClockTicks

	; set all timer vars
	; initialize _hours
	mov DPTR, #_hours
	lcall LoadVariable
	pop SF_DIRECT
	mov r0, SF_DIRECT
	mov @r0, #0h

	; initialize _minutes
	mov DPTR, #_minutes
	lcall LoadVariable
	pop SF_DIRECT
	mov r0, SF_DIRECT
	mov @r0, #0h

	; initialize _seconds
	mov DPTR, #_seconds
	lcall LoadVariable
	pop SF_DIRECT
	mov r0, SF_DIRECT
	mov @r0, #0h

	; initialize _max_hours
	mov DPTR, #_max_hours
	lcall LoadVariable
	pop SF_DIRECT
	mov r0, SF_DIRECT
	mov @r0, #23d

	; initialize _max_minutes
	mov DPTR, #_max_minutes
	lcall LoadVariable
	pop SF_DIRECT
	mov r0, SF_DIRECT
	mov @r0, #59d

	; initialize _max_seconds
	mov DPTR, #_max_seconds
	lcall LoadVariable
	pop SF_DIRECT
	mov r0, SF_DIRECT
	mov @r0, #59d

	end
; * * * Hauptprogramm Ende * * *

; Called every 1/4000 seconds and calls OnEachSecond every 4000 ticks
OnTick:
	; check if _clock_ticks is 0
	mov DPTR, #_clock_ticks		; load clock_ticks** to dptr
	lcall LoadVariable			
	pop SF_DIRECT				; pop clock_ticks* from stack
	mov r0, SF_DIRECT			; load clock_ticks* to r0
	mov A, @r0					; load clock_ticks low byte to A
	inc r0						; increment clock_ticks* to target high byte
	orl A, @r0					; Low byte OR high byte to A
	jnz __OnTick_End			; if clock_ticks is not 0, jump to OnTick_End
	; clock_ticks is 0 (a second has passed)
	; ResetClockTicks is inlibable (no need to store stack frame)
	lcall ResetClockTicks		; reset _clock_ticks to 4000
	lcall OnEachSecond 			; call OnEachSecond
__OnTick_End:
	; decrement _clock_ticks
	mov DPTR, #_clock_ticks		; load clock_ticks** to dptr
	; NOT inlinable (but don't need to preserve registers here)
	lcall DecrementWord			; decrement clock_ticks by 1
	reti

; Called on each second and handles time set events or increments the seconds
OnEachSecond:
	mov A, P0					; load P0 to A
	; check if P0 is 0
	jnz __OnEachSecond_SetTime
	; normal clock operation
	; IncrementSeconds is NOT inlibable (but don't need to preserve registers here)
	lcall IncrementSeconds		; increment _seconds
	jmp __OnEachSecond_End
	__OnEachSecond_SetTime:
	; set time
	clr C						; clear carry flag
	rrc A						; rotate carry flag into A
	; A is now 0 (increment mode) or 1 (decrement mode)
	mov r1, A					; save A to r1
	; check if P1 >= 3
	mov r0, P1					; load P1 to r0
	mov A, #2					; load 2 to A
	clr C						; clear carry flag
	subb A, r0					; 2 - P1 to A
	; if carry flag is set, jump to OnEachSecond_End (invalid P1)
	jc __OnEachSecond_End
	; P1 is valid
	mov DPTR, #_seconds			; load _seconds** to dptr
	mov SF_DIRECT, r0			; load offset to SF_DIRECT
	push SF_DIRECT				; push offset to stack
	lcall LoadVariableWithOffset
	; leave value* on stack
	mov DPTR, #_max_seconds		; load _max_seconds** to dptr
	mov SF_DIRECT, r0			; load offset to SF_DIRECT
	push SF_DIRECT				; push offset to stack
	lcall LoadVariableWithOffset
	; leave max* on stack
	mov A, r1					; restore MODE flag from B
	; if MODE flag is 0 -> increment, 1 -> decrement
	; A basically provides a nice offset here.
	; -> use branch table to call the correct function 
	; A = A * 8 to match offset in branch table
	rl A						; shift
	rl A						; shift
	rl A						; shift
	; load branch table to dptr
	mov DPTR, #__OnEachSecond_BranchTable	
	jmp @A+DPTR					; execute branch table entry and return
	__OnEachSecond_End:
	ret

	; Branch table with 8 byte offsets :)
	; BranchTable[0] = Increment
	; BranchTable[1] = Decrement
	__OnEachSecond_BranchTable:
	lcall Increment				; 3 bytes
	pop SF_DIRECT				; 2 byte
	nop							; 1 byte
	nop							; 1 byte
	ret							; 1 byte
	lcall Decrement				; this is __OnEachSecond_Increment + 8 :)
	pop SF_DIRECT				; 2 byte
	nop							; 1 byte
	nop							; 1 byte
	ret							; 1 byte

; param[0] = void* variable to increment
; param[1] = void* inclusive overflow value 
; if the value surpasses the inclusive overflow value (in params), it is reset to 0
; both parameters passed via stack.
; returns 0xff if overflow, 0 otherwise
Increment:
	pop SF_DIRECT				; pop our return address high byte
	mov r7, SF_DIRECT			; load our return address high byte to r7
	pop SF_DIRECT				; pop our return address low byte
	mov r6, SF_DIRECT			; load our return address low byte to r6
	pop SF_DIRECT				; pop our parameter (MAX_VALUE*)
	mov r1, SF_DIRECT			; load MAX_VALUE* to r1
	mov A, @r1					; dereference MAX_VALUE* to A
	pop SF_DIRECT				; pop value* from stack
	mov r0, SF_DIRECT			; load value* to r0
	inc @r0						; increment value
	; handle overflow
	mov SF_DIRECT, #00h			; assume no overflow by default
	clr C						; clear carry flag
	subb A, @r0					; subtract: MAX - (value)
	jnc __Increment_NoOverflow	; if no overflow, jump to Increment_NoOverflow
	; overflow
	mov @r0, #0					; reset value to 0
	mov SF_DIRECT, #ffh			; set return value to 0xff
	__Increment_NoOverflow:
	push SF_DIRECT				; push return value to stack
	mov SF_DIRECT, r6			; restore our return address low byte
	push SF_DIRECT				; push return address low byte to stack
	mov SF_DIRECT, r7			; restore our return address high byte
	push SF_DIRECT				; push return address high byte to stack
	ret

; param[0] = variable to decrement
; param[1] = inclusive MAX value 
; if the value reaches 0, it is reset to 0 the maximum value < 255 (via params)
; both parameter passed via stack.
; returns 0xff if underflow, 0 otherwise
Decrement:
	pop SF_DIRECT				; pop our return address high byte
	mov r7, SF_DIRECT			; load our return address high byte to r7
	pop SF_DIRECT				; pop our return address low byte
	mov r6, SF_DIRECT			; load our return address low byte to r6
	pop SF_DIRECT				; pop our parameter (MAX_VALUE)
	mov r1, SF_DIRECT			; load our parameter to r1
	pop SF_DIRECT				; pop value* from stack
	mov r0, SF_DIRECT			; load value* to r0
	dec @r0						; decrement value
	; handle underflow:
	; if value is > MAX_VALUE, reset value to MAX_VALUE,
	; also assume MAX_VALUE is != 0xFF
	mov SF_DIRECT, #0h			; assume no underflow by default
	clr C						; clear carry flag
	mov A, @r1					; load MAX_VALUE to A
	subb A, @r0					; subtract: MAX - (value)
	jnc __Decrement_NoUnderflow	; if no underflow, jump to Decrement_Underflow
	mov A, @r1 					; restore MAX_VALUE from r1
	mov @r0, A					; reset value to MAX_VALUE
	mov SF_DIRECT, #FFh			; set return value to 0xff
	__Decrement_NoUnderflow:
	push SF_DIRECT				; push return value to stack
	mov SF_DIRECT, r6			; restore our return address low byte
	push SF_DIRECT				; push return address low byte to stack
	mov SF_DIRECT, r7			; restore our return address high byte
	push SF_DIRECT				; push return address high byte to stack
	ret

IncrementSeconds:
	; increment _seconds
	mov DPTR, #_seconds			; load _seconds** to dptr
	lcall LoadVariable
	; leave value* on stack
	mov DPTR, #_max_seconds		; load _max_seconds** to dptr
	lcall LoadVariable
	; leave max_seconds* on stack
	lcall Increment				; call Increment
	pop SF_DIRECT				; pop return value (overflow flag) from stack
	mov A, SF_DIRECT			; load return value to A
	; if no overflow, jump to IncrementSeconds_NoOverflow
	jz __IncrementSeconds_NoOverflow
	; overflow, so increment _minutes
	lcall IncrementMinutes		; call IncrementMinutes
	__IncrementSeconds_NoOverflow:
	ret

IncrementMinutes:
	; increment _minutes
	mov DPTR, #_minutes			; load _minutes** to dptr
	lcall LoadVariable
	; leave value* on stack
	mov DPTR, #_max_minutes		; load _max_minutes** to dptr
	lcall LoadVariable
	; leave max_minutes* on stack
	lcall Increment				; call Increment
	pop SF_DIRECT				; pop return value (overflow flag) from stack
	mov A, SF_DIRECT			; load return value to A
	; if no overflow, jump to IncrementMinutes_NoOverflow
	jz __IncrementMinutes_NoOverflow
	; overflow, so increment _hours
	lcall IncrementHours		; call IncrementHours
	__IncrementMinutes_NoOverflow:
	ret

IncrementHours:
	; increment _hours
	mov DPTR, #_hours			; load _hours** to dptr
	lcall LoadVariable
	; leave value* on stack
	mov DPTR, #_max_hours		; load _max_hours** to dptr
	lcall LoadVariable
	; leave max_hours* on stack
	lcall Increment				; call Increment
	pop SF_DIRECT				; pop return value (overflow flag) from stack
	ret

; INLINEABLE
; set clock ticks to 4000d
ResetClockTicks:
	; prepare parameters
	mov DPTR, #_clock_ticks	; _clock_ticks** must be passed in dptr register
	; pass target value via stack
	mov SF_DIRECT, #0Fh		; high byte of target value 0x0FA0 (4000)
	push SF_DIRECT
	mov SF_DIRECT, #A0h		; low byte of target value 0x0FA0 (4000)
	push SF_DIRECT
	lcall SetWord
	ret

; the address of LE 16bit integer is stored in DPTR
DecrementWord:
	lcall LoadVariable 		; load address of variable to stack
	pop SF_DIRECT			; pop return value from LoadVariable
	mov r0, SF_DIRECT		; load variable pointer to r0
	mov A, @r0				; load low byte of variable to A
	dec A					; decrement low byte of variable
	mov @r0, A				; save low byte of variable
	xrl A, #FFh				; check if A is 255 (0xFF)
	jnz __DecrementWord_End	; if not, jump to end (no underflow)
	inc r0					; set r0 to high byte of variable address
	dec @r0					; decrement high byte of variable
__DecrementWord_End:
	ret

; the address of target LE 16bit integer is stored in DPTR
; 16 bit integer value is stored on the stack as big endian (top is low byte)
SetWord:
	lcall LoadVariable		; load address of variable to stack
	pop SF_DIRECT			; pop returned value from stack to DIRECT buffer
	mov r0, SF_DIRECT		; load low byte pointer to r0
	pop SF_DIRECT			; pop our own return addres high byte from the stack to access parameters
	mov A, SF_DIRECT		; save our return address high byte to A
	pop SF_DIRECT_2			; pop our own return address low byte from the stack to access parameters
	pop SF_DIRECT			; pop low byte of target value from parameter stack
	mov @r0, SF_DIRECT		; assign low byte of target value to low byte of variable
	inc r0					; increment r0 to high byte of variable address
	pop SF_DIRECT			; pop high byte of target value from parameter stack
	mov @r0, SF_DIRECT		; assign high byte of target value to high byte of variable
	; restore 16 bit return address
	push SF_DIRECT_2		; push our own return address low byte FIRST to stack
	mov SF_DIRECT, A		; ... followed by the high byte
	push SF_DIRECT			; push our own return address to the stack
	ret

; loads the variable address provided in DPTR from memory and returns it on the stack
; INLINEABLE -> we can't use r0 - r7 here 
LoadVariable:
	clr A				; wipe Acc
	movc A, @A+DPTR		; load variable address from memory
	pop SF_DIRECT		; save return address high byte to DIRECT
	pop SF_DIRECT_2		; save return address low byte to DIRECT_2 buffer
	xch A, SF_DIRECT	; swap variable address with return address high byte
	push SF_DIRECT		; save variable address to stack
	push SF_DIRECT_2	; push return address low byte on stack
	mov SF_DIRECT, A	; load return address high byte to DIRECT
	push SF_DIRECT		; restore full 16bit return address on stack
	ret

; loads the variable address provided in DPTR adding the offset provided via parameter 1
; from memory and returns it on the stack
; INLINEABLE -> we can't use r0 - r7 here 
LoadVariableWithOffset:
	pop SF_DIRECT_2		; save return address high byte to DIRECT_2
	mov A, SF_DIRECT_2	; load return address high byte to A
	mov B, A			; save return address high byte to B
	pop SF_DIRECT_2		; save return address low byte to DIRECT_2 buffer
	pop SF_DIRECT		; save offset to DIRECT buffer
	mov A, SF_DIRECT	; load offset to A
	movc A, @A+DPTR		; load variable address + offset from memory
	mov SF_DIRECT, A	; load variable address + offset to DIRECT
	push SF_DIRECT		; save variable address to stack
	push SF_DIRECT_2	; push return address low byte on stack
	mov SF_DIRECT, B	; load return address high byte to DIRECT
	push SF_DIRECT		; restore full 16bit return address on stack
	ret

; stores the current execution context (r0 - r7) to the stack
; or switches register banks if possible
SF_STORE:
	; we can't change r0, so store it in B for now
	mov A, r0						; save r0 to A
	mov B, A						; move r0 to B
	; now load the current register bank index
	mov r0, SF_REGISTER_BANK_SELECT	; move REGISTER_BANK_SELECT* to r0
	mov A, @r0						; load REGISTER_BANK_SELECT to A
	inc @r0							; *REGISTER_BANK_SELECT++;
	; check if we can just switch register banks (REGISTER_BANK_SELECT < 3)
	; REGISTER_BANK_SELECT - 3 < 0 ? switch bank : store context on stack
	clr C							; wipe carry
	subb A, #3						;  REGISTER_BANK_SELECT - 3
	jnc __SF_STORE_StoreContext		; if REGISTER_BANK_SELECT - 3 < 0, jump to StoreContext
	; we can use another bank to store the stack context :)
	mov A, @r0						; load new REGISTER_BANK_SELECT to A
	rl A							; shift REGISTER_BANK_SELECT to the left by 3 bits
	rl A
	rl A
	mov r0, A						; move mask to r0
	mov A, PSW						; move PSW to A
	anl A, #E7h						; clear bits 3 and 4 (RS0 and RS1)
	orl A, r0						; set bits 3 and 4 (RS0 and RS1) depending on REGISTER_BANK_SELECT
	; before switching register banks restore r0 from B
	xch A, B						; swap B to A
	mov r0, A						; move A to r0, DONE!
	mov A, B						; move B to A
	; now switch register banks
	mov PSW, A						; move PSW back to memory
	ljmp __SF_STORE_End
__SF_STORE_StoreContext:
	; we need to manually store contents of r0 - r7 on the stack
	; we can't use r1 - r7 here, r0 is stored in B
	; first restore r0 from B and save our return address from the stack to B
	pop SF_DIRECT_2					; store return address high byte to DIRECT_2
	mov A, SF_DIRECT_2				; move return address high byte to A
	xch A, B						; swap B to A, B is now our return address high byte
	pop SF_DIRECT_2					; store return address low byte to DIRECT_2
	; now store r0 - r7 on the stack
	mov SF_DIRECT, A				; instead of restoring r0, move it directly to the stack
	push SF_DIRECT					; push r0
	mov SF_DIRECT, r1				; move r1 to the stack
	push SF_DIRECT					; push r1
	mov SF_DIRECT, r2				; move r2 to the stack
	push SF_DIRECT					; push r2
	mov SF_DIRECT, r3				; move r3 to the stack
	push SF_DIRECT					; push r3
	mov SF_DIRECT, r4				; move r4 to the stack
	push SF_DIRECT					; push r4
	mov SF_DIRECT, r5				; move r5 to the stack
	push SF_DIRECT					; push r5
	mov SF_DIRECT, r6				; move r6 to the stack
	push SF_DIRECT					; push r6
	mov SF_DIRECT, r7				; move r7 to the stack
	push SF_DIRECT					; push r7
	; now we need to restore our return address from B
	push SF_DIRECT_2				; push return address low byte
	mov A, B
	mov SF_DIRECT_2, A				; move return address high byte to DIRECT_2
	push SF_DIRECT_2				; push return address high byte
__SF_STORE_End:
	ret

; restores the current execution context (r0 - r7) from the stack
; or switches back to previous register banks if possible
SF_RESTORE:
	; we can use all registers here :)
	mov r0, SF_REGISTER_BANK_SELECT	; move REGISTER_BANK_SELECT* to r0
	dec @r0							; *REGISTER_BANK_SELECT--
	mov A, @r0						; load REGISTER_BANK_SELECT to A
	; if REGISTER_BANK_SELECT < 3 we can just switch register banks
	; otherwise we need to restore the context from the stack
	; REGISTER_BANK_SELECT - 3 < 0 ? switch bank : store context on stack
	clr C							; wipe carry
	subb A, #3						;  REGISTER_BANK_SELECT - 3
	jnc __SF_RESTORE_RestoreContext	; if REGISTER_BANK_SELECT - 3 < 0, jump to RestoreContext
	; we still have the context on another bank, so restore it
	mov A, @r0						; load new REGISTER_BANK_SELECT to A
	rl A							; shift REGISTER_BANK_SELECT to the left by 3 bits
	rl A
	rl A
	mov r0, A						; move mask to r0
	mov A, PSW						; move PSW to A
	anl A, #E7h						; clear bits 3 and 4 (RS0 and RS1)
	orl A, r0						; set bits 3 and 4 (RS0 and RS1) depending on REGISTER_BANK_SELECT
	; now switch register banks
	mov PSW, A						; move PSW back to memory
	ljmp __SF_RESTORE_End
__SF_RESTORE_RestoreContext:
	; we need to manually restore contents of r0 - r7 from the stack
	; unless restored, we can use all registers here :)
	; first save our return address to B though
	pop SF_DIRECT_2					; store 16 bit return address high byte to DIRECT_2
	mov A, SF_DIRECT_2				; move return address to A
	xch A, B						; swap B to A, B is now our return address high byte
	pop SF_DIRECT_2					; store 16 bit return address low byte to DIRECT_2
	; now restore r0 - r7 from the stack
	pop SF_DIRECT					; restore r7 from the stack
	mov r7, SF_DIRECT
	pop SF_DIRECT					; restore r6 from the stack
	mov r6, SF_DIRECT
	pop SF_DIRECT					; restore r5 from the stack
	mov r5, SF_DIRECT
	pop SF_DIRECT					; restore r4 from the stack
	mov r4, SF_DIRECT
	pop SF_DIRECT					; restore r3 from the stack
	mov r3, SF_DIRECT
	pop SF_DIRECT					; restore r2 from the stack
	mov r2, SF_DIRECT
	pop SF_DIRECT					; restore r1 from the stack
	mov r1, SF_DIRECT
	pop SF_DIRECT					; restore r0 from the stack
	mov r0, SF_DIRECT
	; now restore our 16 bit return address from B and DIRECT_2
	push SF_DIRECT_2				; push return address low byte
	mov A, B
	mov SF_DIRECT_2, A				; move return address high byte back to DIRECT_2
	push SF_DIRECT_2				; push return address high byte
__SF_RESTORE_End:
	ret

; DON'T SWAP ORDERS OF THESE VARIABLES - START!
_seconds:
	db 32h
_minutes:
	db 31h
_hours:
	db 30h
_max_seconds:
	db 35h
_max_minutes:
	db 34h
_max_hours:
	db 33h
; DON'T SWAP ORDERS OF THESE VARIABLES - END!

_clock_ticks:
	db 36h ; 16 bit integer starting at RAM addr 0x36
