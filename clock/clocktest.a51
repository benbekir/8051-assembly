; 25.07.2022 13:31:55

; dptr variable pointer
; r0 return register
; r1 working register
; r2 - r7 parameter registers

#cpu = 89S8252    ; @12 MHz

ajmp Initialisierung

Timer 0:    ; Timer 0 Interrupt
    ajmp OnTick

Initialisierung:
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
	mov @r0, #0h

	; initialize _minutes
	mov DPTR, #_minutes
	lcall LoadVariable
	mov @r0, #0h

	; initialize _seconds
	mov DPTR, #_seconds
	lcall LoadVariable
	mov @r0, #0h

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
	lcall IncrementSeconds
__OnTick_End:
	; decrement _clock_ticks
	mov DPTR, #_clock_ticks		; load clock_ticks** to dptr
	lcall DecrementWord			; decrement clock_ticks by 1
	reti

IncrementSeconds:
	; increment _seconds
	mov DPTR, #_seconds			; load _seconds** to dptr
	lcall LoadVariable			; load _seconds* to r0
	; check if _seconds is 59
	mov A, #59d					; load 59 to A
	xrl A, @r0					; compare _seconds with 59
	jnz __IncrementSeconds_End	; if _seconds is not 59, jump to IncrementSeconds_End
	; _seconds is 59
	; reset _seconds to 0xFF (generate overflow to 0 in increment)
	mov @r0, #FFh				; load 0xFF to _seconds
	; increment _minutes
	lcall IncrementMinutes
	mov DPTR, #_seconds			; load _seconds** to dptr
	lcall LoadVariable			; load _seconds* to r0
__IncrementSeconds_End:
	inc @r0						; increment _seconds
	ret

IncrementMinutes:
	; increment _minutes
	mov DPTR, #_minutes			; load _minutes** to dptr
	lcall LoadVariable			; load _minutes* to r0
	; check if _minutes is 59
	mov A, #59d					; load 59 to A
	xrl A, @r0					; compare _minutes with 59
	jnz __IncrementMinutes_End	; if _minutes is not 59, jump to IncrementMinutes_End
	; _minutes is 59
	; reset _minutes to 0xFF (generate overflow to 0 in increment)
	mov @r0, #FFh				; load 0xFF to _minutes
	; increment _hours
	lcall IncrementHours
	mov DPTR, #_minutes			; load _minutes** to dptr
	lcall LoadVariable			; load _minutes* to r0
__IncrementMinutes_End:
	inc @r0						; increment _minutes
	ret

IncrementHours:
	; increment _hours
	mov DPTR, #_hours			; load _hours** to dptr
	lcall LoadVariable			; load _hours* to r0
	; check if _hours is 23
	mov A, #23d					; load 23 to A
	xrl A, @r0					; compare _hours with 23
	jnz __IncrementHours_End	; if _hours is not 23, jump to IncrementHours_End
	; _hours is 23
	; reset _hours to 0xFF (generate overflow to 0 in increment)
	mov @r0, #FFh				; load 0xFF to _hours
__IncrementHours_End:
	inc @r0						; increment _hours
	ret

; set clock ticks to 4000d
ResetClockTicks:
	mov DPTR, #_clock_ticks
	mov r2, #0Fh; high byte of target value 0x0FA0 (4000)
	mov r3, #A0h; low byte of target value 0x0FA0 (4000)
	lcall SetWord
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

; loads the variable address from memory to the return register r0
LoadVariable:
	xch A, r1 		; save Acc to r1
	clr A			; wipe Acc
	movc A, @A+DPTR	; load variable address from memory
	xch A, r0		; save variable address to return register r0 
	xch A, r1		; restore Acc from r1
	ret

_hours:
	db 30h
_minutes:
	db 31h
_seconds:
	db 32h
_clock_ticks:
	db 33h ; 16 bit integer starting at RAM addr 0x33