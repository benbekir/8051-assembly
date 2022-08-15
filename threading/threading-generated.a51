#cpu = 89S8252    ; @12 MHz

ajmp Initialize

Timer 0:    ; Timer 0 Interrupt
    ajmp OnTick

Initialize:
	; setup stack
	mov	SP, #3fh
	; set REGISTER_BANK_SELECT = 0
	mov 3fh, #0h
	; reset client index
	mov 39h, #1h

	; reset clock tick counter
	lcall S_ResetClockTicks

	orl TMOD, # 02h    ; Timer 0 im 8-Bit Autoreload-Modus. 
	; Die �berlauffrequenz des Timer 0 betr�gt 4000 Hz, die Periodendauer 0,25 ms.
	mov TH0, # 06h    ; Reloadwert

	; Interrupts
	setb ET0    ; Timer 0 Interrupt freigeben
	setb EA    ; globale Interruptfreigabe
	setb TR0    ; Timer 0 l�uft.

	; test
	mov dptr, #_test	; load VRAM address
	lcall VirtualLoad	; devirtualize
	pop 3dh		; get returned physical address
	mov r0, 3dh	
	mov a, #0h			; load target value
	movx @r0, a			; write target value

	end
; * * * Hauptprogramm Ende * * *

OnTick:
	; check if _clock_ticks is 0
	mov r0, #3ah	; load clock_ticks* to r0
	mov A, @r0						; load clock_ticks low byte to A
	inc r0							; increment clock_ticks* to target high byte
	orl A, @r0						; Low byte OR high byte to A
	jnz __OnTick_End				; if clock_ticks is not 0, jump to OnTick_End
	; clock_ticks is 0 (need to switch execution context)
	lcall S_ResetClockTicks
	lcall S_SwitchExecutionContext
__OnTick_End:
	; decrement _clock_ticks
	lcall S_DecrementClockTicks
	reti

S_SwitchExecutionContext:
	; TODO
	ret

; set clock ticks to 4000d
S_ResetClockTicks:
	mov r0, #3ah	; load clock_ticks* to r0
	mov @r0,	#a0h	; assign low byte
	inc r0							; increment to target high byte
	mov @r0,	#0fh	; assign high byte
	ret

; the address of LE 16bit integer is stored in DPTR
S_DecrementClockTicks:
	mov r0, #3ah	; load clock_ticks* to r0
	mov A, @r0						; load low byte of clock_ticks to A
	dec A							; decrement low byte of clock_ticks
	mov @r0, A						; save low byte of clock_ticks
	xrl A, #FFh						; check if A is 255 (0xFF)
	jnz __S_DecrementClockTicks_End	; if not, jump to end (no underflow)
	inc r0							; set r0 to high byte of clock_ticks
	dec @r0							; decrement high byte of clock_ticks
__S_DecrementClockTicks_End:
	ret

; loads the VRAM address pointed at by DPTR from ROM and returns the physical address on the stack
; INLINEABLE -> we can't use r0 - r7 here 
; return devirtualize(*DPTR);
VirtualLoad:
	; we need to preserve the outer execution context
	mov 3ch, r0		; save r0 to temporary memory
	; now do the virtual load
	clr A
	movc A, @A+DPTR			; load VRAM address from memory
	mov r0, A				; load VRAM address to r0
	mov A, #40h		; load VRAM size to A
	mov B, 39h	; load client index to B
	mul AB					; multiply VRAM size with client index
	mov b, #80h		; load VRAM base address to B
	add a, b 				; add VRAM base address to address space offset
	add a, r0				; add VRAM address to physical address offset
	; restore r0
	mov r0, 3ch
	; store return value on stack
	pop 3dh			; pop high byte of our return address from stack
	mov B, 3dh
	pop 3dh			; pop low byte of our return address from stack
	mov 3eh, A		; load return value to direct buffer
	push 3eh		; push return value to stack
	; restore own return address
	push 3dh			; push low byte of our return address to stack
	mov 3eh, B		; load high byte of our return address to direct buffer
	push 3eh		; push high byte of our return address to stack
	ret

; loads the VRAM address pointed at by (DPTR + offset) from ROM and returns the physical address on the stack
; INLINEABLE -> we can't use r0 - r7 here 
; return devirtualize(*(DPTR + [Params(1)]offset));
VirtualLoadOffset:
	; we need to preserve the outer execution context
	mov 3ch, r0			; save r0 to temporary memory
	; now load our parameter
	pop 3dh				; pop high byte of our return address from stack
	mov 3eh, 3dh	; save high byte of our return address to push buffer
	pop 3dh				; pop low byte of our return address from stack
	mov a, 3dh			; ret address low byte to A
	pop 3dh				; pop offset parameter from stack
	xch a, 3dh			; exchange offset parameter with return address low byte
	; now do the virtual load
	movc a, @A+DPTR				; load VRAM address from memory
	mov r0, a					; load VRAM address to r0
	mov a, #40h			; load VRAM size to A
	mov b, 39h		; load client index to B
	mul ab						; multiply VRAM size with client index
	mov b, #80h			; load VRAM base address to B
	add a, b 					; add VRAM base address to address space offset
	add a, r0					; add VRAM address to physical address offset
	; restore r0
	mov r0, 3ch
	; store return value on stack
	xch a, 3eh			; exchange return address high byte with return value
	push 3eh			; push return value to stack
	; restore own return address
	push 3dh				; push low byte of our return address to stack
	mov 3eh, a			; load high byte of our return address to direct buffer
	push 3eh			; push high byte of our return address to stack
	ret

_test:
	db 00h					; test
