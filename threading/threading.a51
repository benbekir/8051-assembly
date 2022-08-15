; ============================================================================
; 								   MACROS
; ============================================================================

; ============================================================================
; 								MEMORY SETUP
; ============================================================================
;
;  Region        | Start | End   | Size | Description
;  --------------+-------+-------+------+----------------------------------------------
;  RESERVED      | 0x0	 | 0x30	 | 0x30 | register banks
;  --------------+-------+-------+------+----------------------------------------------
;  SCHEDULER_RAM | 0x30	 | 0x3f	 | 0x30 | RAM for the scheduler and special addresses
;  --------------+-------+-------+------+----------------------------------------------
;  SF_STACK		 | 0x40	 | 0x4f	 | 0x10 | stack for the scheduler
;  --------------+-------+-------+------+----------------------------------------------
;  C_STACK		 | 0x50	 | 0x6f	 | 0x20 | stack for the client
;  --------------+-------+-------+------+----------------------------------------------
;  UNUSED		 | 0x70	 | 0x7f	 | 0x10 | unused
;

; start of the scheduler stack (stack size = 16 bytes -> max recursion depth = 8)
#DEFINE S_STACK_START				#3fh
#DEFINE S_STACK_SIZE				#10h
; start of the client stack (stack size = 3 * 16 bytes = 48 bytes -> max recursion depth = 24)
#DEFINE C_STACK_START				#4fh
#DEFINE C_STACK_SIZE				#30h
; macro for direct address containing register bank index
#DEFINE S_REGISTER_BANK_SELECT 		3fh
; macro for direct address of push buffer
#DEFINE DIRECT_PUSH 				3eh
; macro for direct address of pop buffer
#DEFINE DIRECT_POP					3dh
; macro for direct address of volatile data buffer
#DEFINE DIRECT_DATA					3ch
; macro for direct address to clock tick counter (16 bit LE)
#DEFINE S_CLOCK_TICK_COUNTER		#3ah
#DEFINE S_CLOCK_RESET_HIGH			#0fh
#DEFINE S_CLOCK_RESET_LOW			#a0h
; macro for direct address to client index
#DEFINE S_CLIENT_INDEX				39h

;  ===============================================================================
;  								EXTERNAL RAM
; ===============================================================================
;
;  Region        | Start | End   | Size | Description
;  --------------+-------+-------+------+----------------------------------------------
;  STACK_FRAMES  | 0x0	 | 0x7f	 | 0x80 | stack frames for the clients
;  --------------+-------+-------+------+----------------------------------------------
;  CLIENT_HEAP_1 | 0x80	 | 0xbf  | 0x40 | VRAM heap for client 1
;  --------------+-------+-------+------+----------------------------------------------
;  CLIENT_HEAP_2 | 0xc0	 | 0xff  | 0x40 | VRAM heap for client 2

; base address of execution context storage in external memory
#DEFINE EC_BASE						#00h
; size of each execution context in external memory
#DEFINE EC_SIZE						#40h

; physical base address of the start of the VRAM heap
#DEFINE VRAM_BASE					#80h
; size of each VRAM heap
#DEFINE VRAM_SIZE					#40h

#cpu = 89S8252    ; @12 MHz

ajmp Initialize

Timer 0:    ; Timer 0 Interrupt
    ajmp OnTick

Initialize:
	; setup stack
	mov	SP, S_STACK_START
	; set REGISTER_BANK_SELECT = 0
	mov S_REGISTER_BANK_SELECT, #0h
	; reset client index
	mov S_CLIENT_INDEX, #1h

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
	pop DIRECT_POP		; get returned physical address
	mov r0, DIRECT_POP	
	mov a, #0h			; load target value
	movx @r0, a			; write target value

	end
; * * * Hauptprogramm Ende * * *

OnTick:
	; check if _clock_ticks is 0
	mov r0, S_CLOCK_TICK_COUNTER	; load clock_ticks* to r0
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
	mov r0, S_CLOCK_TICK_COUNTER	; load clock_ticks* to r0
	mov @r0,	S_CLOCK_RESET_LOW	; assign low byte
	inc r0							; increment to target high byte
	mov @r0,	S_CLOCK_RESET_HIGH	; assign high byte
	ret

; the address of LE 16bit integer is stored in DPTR
S_DecrementClockTicks:
	mov r0, S_CLOCK_TICK_COUNTER	; load clock_ticks* to r0
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
	mov DIRECT_DATA, r0		; save r0 to temporary memory
	; now do the virtual load
	clr A
	movc A, @A+DPTR			; load VRAM address from memory
	mov r0, A				; load VRAM address to r0
	mov A, VRAM_SIZE		; load VRAM size to A
	mov B, S_CLIENT_INDEX	; load client index to B
	mul AB					; multiply VRAM size with client index
	mov b, VRAM_BASE		; load VRAM base address to B
	add a, b 				; add VRAM base address to address space offset
	add a, r0				; add VRAM address to physical address offset
	; restore r0
	mov r0, DIRECT_DATA
	; store return value on stack
	pop DIRECT_POP			; pop high byte of our return address from stack
	mov B, DIRECT_POP
	pop DIRECT_POP			; pop low byte of our return address from stack
	mov DIRECT_PUSH, A		; load return value to direct buffer
	push DIRECT_PUSH		; push return value to stack
	; restore own return address
	push DIRECT_POP			; push low byte of our return address to stack
	mov DIRECT_PUSH, B		; load high byte of our return address to direct buffer
	push DIRECT_PUSH		; push high byte of our return address to stack
	ret

; loads the VRAM address pointed at by (DPTR + offset) from ROM and returns the physical address on the stack
; INLINEABLE -> we can't use r0 - r7 here 
; return devirtualize(*(DPTR + [Params(1)]offset));
VirtualLoadOffset:
	; we need to preserve the outer execution context
	mov DIRECT_DATA, r0			; save r0 to temporary memory
	; now load our parameter
	pop DIRECT_POP				; pop high byte of our return address from stack
	mov DIRECT_PUSH, DIRECT_POP	; save high byte of our return address to push buffer
	pop DIRECT_POP				; pop low byte of our return address from stack
	mov a, DIRECT_POP			; ret address low byte to A
	pop DIRECT_POP				; pop offset parameter from stack
	xch a, DIRECT_POP			; exchange offset parameter with return address low byte
	; now do the virtual load
	movc a, @A+DPTR				; load VRAM address from memory
	mov r0, a					; load VRAM address to r0
	mov a, VRAM_SIZE			; load VRAM size to A
	mov b, S_CLIENT_INDEX		; load client index to B
	mul ab						; multiply VRAM size with client index
	mov b, VRAM_BASE			; load VRAM base address to B
	add a, b 					; add VRAM base address to address space offset
	add a, r0					; add VRAM address to physical address offset
	; restore r0
	mov r0, DIRECT_DATA
	; store return value on stack
	xch a, DIRECT_PUSH			; exchange return address high byte with return value
	push DIRECT_PUSH			; push return value to stack
	; restore own return address
	push DIRECT_POP				; push low byte of our return address to stack
	mov DIRECT_PUSH, a			; load high byte of our return address to direct buffer
	push DIRECT_PUSH			; push high byte of our return address to stack
	ret

_test:
	db 00h					; test