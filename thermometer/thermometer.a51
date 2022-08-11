; 09.08.2022 18:16:32

#cpu = 89S8252	; @12 MHz

#use LCALL

ajmp Initialisierung

Timer 0:	; Timer 0 Interrupt
	ajmp OnTick

Initialisierung:
orl TMOD, # 02h	; Timer 0 im 8-Bit Autoreload-Modus. 
; Die Überlauffrequenz des Timer 0 beträgt 4000 Hz, die Periodendauer 0,25 ms.
mov TH0, # 06h	; Reloadwert

; Interrupts
setb ET0	; Timer 0 Interrupt freigeben
setb EA	; globale Interruptfreigabe
setb TR0 ;Timer 0 läuft

; reset clock tick counter
lcall ResetClockTicks

;initialize_array
mov 40h, #0h
mov 41h, #0h
mov 42h, #0h
mov 43h, #0h
mov 44h, #0h
mov 45h, #0h
mov 46h, #0h
mov 47h, #0h
mov 48h, #0h
mov 49h, #0h

;initialize_seconds
mov DPTR, #_seconds
lcall LoadVariable
mov @r0, #0h

;initialize_pointer
mov DPTR, #_pointer
lcall LoadVariable
mov @r0, #40h

;initialize_average
mov DPTR, #_average
lcall LoadVariable
mov @r0, #0h

;initialize_average_rest
mov DPTR, #_average_rest
lcall LoadVariable
mov @r0, #0h

;initialize_loop_variable
mov DPTR, #_loop_variable
lcall LoadVariable
mov @r0, #0d

;initialize_tendenz
mov 4Eh, #2d

;initialize_old_average
mov r5, #0d

end
; * * * Hauptprogramm Ende * * *

OnTick:
	; check if _clock_ticks is 0
	mov DPTR, #_clock_ticks		; load clock_ticks** to dptr
	lcall LoadVariable			; load clock_ticks* to r0
	mov A, @r0					; load clock_ticks low byte to A
	inc r0						; increment clock_ticks* to target high byte
	orl A, @r0					; Low byte OR high byte to A
	jnz __OnTick_End			; if clock_ticks is not 0, jump to OnTick_End
	; clock_ticks is 0 (a second has passed)
	; reset _clock_ticks to 4000
	lcall ResetClockTicks
	; increment _seconds
	lcall DoAfterTenSeconds
__OnTick_End:
	; decrement _clock_ticks
	mov DPTR, #_clock_ticks		; load clock_ticks** to dptr
	lcall DecrementWord			; decrement clock_ticks by 1
	reti
	
DoAfterTenSeconds:
	; logic for reading from P2 and writing to address that the _pointer is pointing to
	mov DPTR, #_pointer
	lcall LoadVariable
	mov A, @r0
	xch A, r1
	mov @r1, P2
	lcall CalculateAverage
	mov DPTR, #_pointer
	lcall LoadVariable
	mov A, #49h	
	XRL A, @r0
	jnz __DoAfterTenSeconds_End ; if _pointer is not pointing at RAM Address 49h, skip below logic
	; logic when pointer was at last address (49h)
	mov 4Bh, #3Fh
__DoAfterTenSeconds_End:
	inc 4Bh
	ret
	
; will load the current loop_variable value into r1
; we dont actually need to load value into r1, we can also use it from r0, however, that means that while using the loop_variable, we cannot use r0
LoadLoopVariable: 
	mov DPTR, #_loop_variable
	lcall LoadVariable ; r0 will now point at 4Dh
	mov A, @r0 ; A will now point at 4Dh
	mov r1, A
	ret
	

; divide each integer stored in 40h-49h by 10 before summing them up in 4Ah
; the rest value of each integer division is stored in 4Ch and divided by 10 in the end. the result is then added to 4Ah (TODO)
CalculateAverage:
	; clear variables before loop
	mov B, #10d
	mov r1, #0
	clr A
	
	; Loop (A is empty, r4 has old average, B is #10d, r1 is empty)
	lcall LoadLoopVariable ; loop_variable will now be in r1
	mov A, #40h
	add A, r1 ; A will now hold Address 40h + n (for (n = 0, n < 10, n++))
	xch A, r1  
	mov A, @r1
	div AB
	add A, r5 
	mov r5, A ; r5 holds currently accumulated average
	mov A, B
	add A, 4Ch
	mov 4Ch, A
	
	; if #_loop_variable is at value #10d , end loop
	mov A, #10d
	mov DPTR, #_loop_variable
	lcall LoadVariable
	XRL A, @r0
	jz __CalculateAverage_End
	; logic when address' are not equal
	inc @r0 ; increment loop variable by 1
	sjmp CalculateAverage
__CalculateAverage_End: 
	; logic when address' are equal
	mov @r0, #0d		
	mov r4, 4Ah ; move old average to Address r4
	mov DPTR, #_average
	lcall LoadVariable
	mov A, r5 ; move currently accumulated average to Accumulator
	mov r5, #0d
	mov @r0, A 
	mov A, 4Ch
	mov 4Ch, #0h
	mov B, #10d
	div AB
	add A, @r0
	mov @r0, A
	lcall CompareAverages
	ret

; compare the last average with the current one and predict whether the temperature will rise or fall
CompareAverages:
	mov A, 4Ah
	mov B, r4
	div AB
	jz __CompareAverages_Zero
	mov 4Eh, #1d
	ret
	; if value at RAM Address 4Eh is 0 => new average was lower than previous || 1 => new average was equal or greater than old average
__CompareAverages_Zero:
	mov 4Eh, #0d	
	ret
	
; set clock ticks to 40000d
ResetClockTicks:
	mov DPTR, #_clock_ticks
	mov r2, #0Fh
	mov r3, #A0h ; !!! Change this back !!!
	;mov r2, #9Ch; high byte of target value 0x0FA0 (40000)
	;mov r3, #40h; low byte of target value 0x0FA0 (40000)
	lcall SetWord
	ret
	
; the address of target LE 16bit integer is stored in DPTR
; high byte of target value is stored in r2
; low byte of target value is stored in r3
SetWord:
	lcall LoadVariable		; load address of variable to r0
	xch A, r1				; save Acc to r1
	mov A, r3				; load low byte of target value to A
	mov @r0, A 				; save low byte of variable to r1
	mov A, r2				; load high byte of target value to A
	inc r0					; increment r0 to high byte of variable address
	mov @r0, A 				; save high byte of variable to r0
	xch A, r1				; restore Acc from r1
	ret
	
; the address of LE 16bit integer is stored in DPTR
DecrementWord:
	lcall LoadVariable 		; load address of variable to r0
	mov A, @r0				; load low byte of variable to A
	dec A					; decrement low byte of variable
	mov @r0, A				; save low byte of variable
	xrl A, #FFh				; check if A is 255 (0xFF)
	jnz __DecrementWord_End	; if not, jump to end (no underflow)
	inc r0					; set r0 to high byte of variable address
	dec @r0					; decrement high byte of variable
__DecrementWord_End:
	ret

; loads the variable address from memory to the return register r0
LoadVariable:
	xch A, r1 		; save Acc to r1
	clr A			; wipe Acc
	movc A, @A+DPTR	; load variable address from memory
	xch A, r0		; save variable address to return register r0 
	xch A, r1		; restore Acc from r1
	ret

_seconds:
	db 32h
_clock_ticks:
	db 33h ; 16 bit integer starting at RAM addr 0x33
_pointer: 
	db 4Bh ; 16 bit integer pointing from 40h to 49h
_average:
	db 4Ah ; 16 bit integer average of all 10 temperature measurements
_average_rest:
	db 4Ch ; 16 bit integer rest that accumulates when calculating average
_loop_variable:
	db 4Dh ; 16 bit integer from #0d to #10d for a loop of 10 cycles

