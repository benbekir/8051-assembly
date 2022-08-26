; ============================================================================
; 								   MACROS
; ============================================================================

; register macros for direct address mode
#DEFINE DIRECT_R0	00h
#DEFINE DIRECT_R1	01h
#DEFINE DIRECT_R2	02h
#DEFINE DIRECT_R3	03h
#DEFINE DIRECT_R4	04h
#DEFINE DIRECT_R5	05h
#DEFINE DIRECT_R6	06h
#DEFINE DIRECT_R7	07h

; ============================================================================
; 								MEMORY SETUP
; ============================================================================
;
;  Region        | Start | End   | Size | Description
;  --------------+-------+-------+------+----------------------------------------------
;  RESERVED      | 0x0	 | 0x8	 | 8    | register bank 0
;  --------------+-------+-------+------+----------------------------------------------
;  S_STACK		 | 0x8	 | 0x20	 | 24   | stack for the scheduler
;  --------------+-------+-------+------+----------------------------------------------
;  RESERVED  	 | 0x20	 | 0x30	 | 16   | bit addressable memory
;  --------------+-------+-------+------+----------------------------------------------
;  S_RAM 		 | 0x30	 | 0x3f	 | 16   | RAM for the scheduler and special addresses
;  --------------+-------+-------+------+----------------------------------------------
;  C_STACK		 | 0x40	 | 0x5f	 | 32   | stack for the client
;  --------------+-------+-------+------+----------------------------------------------
;  C_ALLOC_TBL	 | 0x60	 | 0x7f	 | 32   | Client allocation table (stack-like) (pointers at butterfly structures)
;

; start of the scheduler stack (stack size = 24 bytes -> max recursion depth = 12)
#DEFINE S_STACK_START				#08h
#DEFINE S_STACK_SIZE				#24d
; start of the client stack (stack size = 3 * 16 bytes = 48 bytes -> max recursion depth = 24)
#DEFINE C_STACK_START				#3fh
#DEFINE C_STACK_SIZE				#20h
; start of the client allocation table for butterfly pointer storage (RAM size = 32 bytes)
#DEFINE ALLOC_TBL_BASE				#60h 
; macro for direct address of volatile data buffer 1
#DEFINE DIRECT_DATA_1 				3eh
; macro for direct address of volatile data buffer 2
#DEFINE DIRECT_DATA_2				3dh
; macro for direct address of volatile data buffer 3
#DEFINE DIRECT_DATA_3				3ch
; macro for direct address to clock tick counter (16 bit LE)
#DEFINE S_CLOCK_TICK_COUNTER		#3ah
#DEFINE S_CLOCK_RESET_HIGH			#0fh
#DEFINE S_CLOCK_RESET_LOW			#a0h
; macro for direct address to client index
#DEFINE S_CLIENT_INDEX				39h
; macro for stack frame stack pointer in XRAM
#DEFINE S_STACK_FRAME_SP			#36h

;  ===============================================================================
;  								EXTERNAL RAM
; ===============================================================================
;
;  Region        | Start  | End    | Size  | Description
;  --------------+--------+--------+-------+----------------------------------------------
;  STACK_FRAMES  | 0x0	  | 0x7f   | 128   | stack frames for the clients
;  --------------+--------+--------+-------+----------------------------------------------
;  CLIENT_HEAP_1 | 0x80	  | 0x17f  | 256   | VRAM heap for client 1
;  --------------+--------+--------+-------+----------------------------------------------
;  CLIENT_HEAP_2 | 0x180  | 0x27f  | 256   | VRAM heap for client 2
;  --------------+--------+--------+-------+----------------------------------------------
;  CLIENT_PTR_1  | 0x280  | 0x2ff  | 32    | DATA Pointer buffer for client 1
;  --------------+--------+--------+-------+----------------------------------------------
;  CLIENT_PTR_2  | 0x300  | 0x31f  | 32    | DATA Pointer buffer for client 2
;  --------------+--------+--------+-------+----------------------------------------------
;  CLIENT_DATA_1 | 0x1000 | 0x200f | 4112  | DATA buffer for client 1 using butterfly structures
;  --------------+--------+--------+-------+----------------------------------------------
;  CLIENT_DATA_2 | 0x2010 | 0x301f | 4112  | DATA buffer for client 2 using butterfly structures
;  --------------+--------+--------+-------+----------------------------------------------
;  STACK_FRAME_1 | 0x3020 | 0x401f | 4096  | stack frame stack for client 1
;  --------------+--------+--------+-------+----------------------------------------------
;  STACK_FRAME_2 | 0x4020 | 0x501f | 4096  | stack frame stack for client 2

; ============================================================================
; 								BUTTERFLY STRUCTURE
; ============================================================================
;
; - similar to the butterfly structure used by JS, but with a simplified layout
; - stores the data itself in the heap, and the size of the data as a 8 bit word
; 
; 							 SIZE | DATA DATA DATA DATA DATA DATA ...
;							      ^
;							      |
;				    pointer ------+

; base address of execution context storage in external memory
#DEFINE EC_BASE_LOW					#00h
#DEFINE EC_BASE_HIGH				#00h
; size of each execution context in external memory
#DEFINE EC_SIZE						#40h

; physical base address of the start of the VRAM heap
#DEFINE VRAM_BASE_LOW				#80h
#DEFINE VRAM_BASE_HIGH				#00h
; size of each VRAM heap in 256 byte blocks
#DEFINE VRAM_SIZE					#1h
; size of each VRAM pointer buffer in bytes
#DEFINE VRAM_PTR_SIZE				#20h
; physical base address of the start of the DATA section
#DEFINE DATA_BASE_HIGH			#10h
#DEFINE DATA_BASE_LOW			#00h
; size of each DATA buffer in bytes
#DEFINE DATA_SIZE_HIGH			#10h
#DEFINE DATA_SIZE_LOW			#10h
; physical base address of the start of the DATA pointer section
#DEFINE DATA_PTR_BASE_HIGH		#02h
#DEFINE DATA_PTR_BASE_LOW		#80h
; size of each DATA pointer buffer in bytes
#DEFINE DATA_PTR_SIZE				#20h
; allocation pointer address for current client in internal memory
#DEFINE ALLOC_TBL_PTR				#38h
; base address of stack frame stack in external memory
#DEFINE STACK_FRAME_STACK_BASE_HIGH	#30h
#DEFINE STACK_FRAME_STACK_BASE_LOW	#20h
#DEFINE STACK_FRAME_STACK_SIZE		#4096d
; size of each stack frame in external memory
#DEFINE MAX_STACK_FRAME_SIZE		#16d

; ============================================================================
; 								VARIABLE DATA
; ============================================================================

#DATA_BUF _buffer
; Generates to
; #DEFINE _buffer					#[DATA_BUF index]
; pointer allocated in virtual pointer buffer for current client 
; uninitialized, needs to be VirtualAlloc'd to reserve space in DATA section
#DECLARE uint_8 _myByte
#DECLARE uint_16 _myShort
; Generates to
; #DEFINE _myVariable				#[DECLARE index]
; allocated in VRAM for the current client

#cpu = 89S8252    ; @12 MHz

ajmp Initialize

Timer 0:    ; Timer 0 Interrupt
    ajmp OnTick

Initialize:
	; setup stack
	mov	SP, S_STACK_START
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

	mov r0, _buffer
	push DIRECT_R0
	mov r1, #128d
	push DIRECT_R1
	lcall VirtualAlloc

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

; allocates a block of memory on the DATA heap
; [XRAM][Virtual][WordSize(8)] PTR -> [IRAM][Physical][WordSize(16)] PTR -> [XRAM][Physical] DATA
; void VirtualAlloc([From(Stack)]uint_8* target, [From(Stack)]uint_8 size);
VirtualAlloc:
	; STORE outer stack frame
	lcall SF_STORE
	mov r1, ALLOC_TBL_PTR	; load current allocation pointer* to r1
	mov a, @r1				; value of current allocation pointer
	jz __VirtualAlloc_NewClient	; if a is 0, jump to new client
	; a is not 0, we need to calculate the target address of the next allocation
	; get size of current allocation
	mov r0, a
	push DIRECT_R0			; push uint_16* to stack
	lcall GetAllocationSize
	pop DIRECT_R0			; pop size to r0
	mov a, @r1				; value of current allocation pointer*
	mov r1, a				; need pointer in r1 to dereference
	mov a, @r1				; load low byte of current allocation pointer to A
	setb c					; set carry flag to 1 (need to add 1 because of butterfly structure)
	addc a, r0				; add size + 1 to low byte of current allocation pointer
	mov r2, a				; save low byte of next allocation pointer to r2
	inc r1					; point to high byte of current allocation pointer
	mov a, @r1				; load high byte of current allocation pointer to a
	addc a, #0h				; handle carry flag / overflow
	mov r3, a				; save high byte of next allocation pointer to r3
	ljmp __VirtualAlloc_Allocate
__VirtualAlloc_NewClient:
	; new client
	; r1 contains the current allocation pointer
	mov a, ALLOC_TBL_BASE		; set current allocation pointer to client allocation table base address
	sub a, #2h					; subtract 2 from base address (will be incremented by 2 before next write)
	mov @r1, a					; save current allocation pointer to memory
	mov a, S_CLIENT_INDEX		; load client index to a
	mov b, DATA_SIZE_LOW		; load low byte of data buffer size to b
	mul ab 						; a is now 0 or low byte offset
	mov r0, DATA_BASE_LOW		; load low byte of data buffer base address to r0
	add a, r0					; add lower byte offset to base address
	mov r2, a					; save low byte of next allocation pointer to r2
	; save carry to r4
	mor r4, #0h					
	jnc __VirtualAlloc_NewClientNoCarry
	mov r4, #1h
__VirtualAlloc_NewClientNoCarry:
	mov a, S_CLIENT_INDEX		; load client index to a
	mov b, DATA_SIZE_HIGH		; load high byte of data buffer size to b
	mul ab 						; a is now 0 or high byte offset
	mov r0, DATA_BASE_HIGH		; load high byte of data buffer base address to r0
	add a, r0					; add higher byte offset to base address
	add a, r4					; add carry flag to base address
	mov r3, a					; save high byte of next allocation pointer to r3
__VirtualAlloc_Allocate:
	; load size from stack
	; safe our return address to r6 (low)/r7(high)
	pop DIRECT_R7				; pop high byte of return address to r7
	pop DIRECT_R6				; pop low byte of return address to r6
	pop DIRECT_R1				; pop size to r1
	mov a, r1					; load size to A
	mov p2, DIRECT_R3			; set port 2 to high byte of next allocation pointer
	mov r0, DIRECT_R2			; set r0 to low byte of next allocation pointer
	movx @r0, a					; write size to next allocation pointer
	inc r2						; create butterfly structure (inc low byte of next allocation pointer)
	mov a, r2					; handle overflow
	xrl a, #ffh					; check if A is 255 (0xFF)
	jnz __VirtualAlloc_AllocateNoOverflow
	inc r3						; high byte needs to be incremented
__VirtualAlloc_AllocateNoOverflow:	
	; write butterfly pointer back to allocation table
	mov a, ALLOC_TBL_PTR		; load current allocation pointer*
	add a, #2					; increment allocation table entry (16bit pointer)
	mov r0, a
	mov @r0, DIRECT_R2			; write low byte of new allocation pointer to memory
	inc r0						; increment to high byte of new allocation pointer
	mov @r0, DIRECT_R3			; write high byte of new allocation pointer to memory
	; now set the target VRAM pointer to the newly allocated memory
	pop DIRECT_R1				; pop target* to r1
	mov a, DATA_PTR_SIZE		; load size of data pointer section to A
	mov b, S_CLIENT_INDEX		; load client index to b
	mul ab 						; a is the offset relative to the data pointer section base address
	mov b, DATA_PTR_BASE_LOW	; load low byte of data pointer section base address to b
	add a, b					; get physical base address of virtual address space
	mov r4, a					; save low byte of physical base address of virtual address space to r4
	mov a, DATA_PTR_BASE_HIGH	; load high byte of data pointer section base address to a
	addc a, #0h					; handle carry flag / overflow
	mov r5, a					; save high byte of physical base address of virtual address space to r5
	mov a, r1					; load virtual target* to a
	add a, r4					; add low byte of physical base address of virtual address space to virtual pointer
	mov r0, a					; save low byte of physical target* to r0 
	mov a, r5					; load high byte of physical base address of virtual address space to a
	addc a, #0h					; handle carry flag / overflow
	mov p2, a					; set port 2 to high byte of physical target*
	mov r1, ALLOC_TBL_PTR		; set r1 to the current allocation pointer*
	mov a, @r1					; load physical IRAM address of the new allocation table entry to A
	movx @r0, a					; write physical IRAM address of the new allocation table entry to virtual pointer
	; restore our return address from r6 (low)/r7(high)
	push DIRECT_R6
	push DIRECT_R7 
	; restore outer stack frame
	lcall SF_RESTORE
	ret 
	
; uint_8 GetAllocationSize([From(Stack)][Physical][IRAM][WordSize(8)]uint_16* target);
GetAllocationSize:
	; STORE outer stack frame
	lcall SF_STORE
	; preserve our own return address
	pop DIRECT_R7	; pop high byte of return address to r7
	pop DIRECT_R6	; pop low byte of return address to r6
	pop DIRECT_R0	; pop parameter (uint_16*) to r1
	mov a, @r1		; get low byte of DATA*
	mov r0, a		; write to r0 (for xram addressing)
	inc r1			; point at high byte of DATA*
	mov a, @r1		; get high byte of target allocation address
	mov p2, a		; store in port 2 (for xram addressing)
	; now we have the address of the target allocation 
	; now: get size of target allocation
	dec r0			; decrement low byte of target allocation address
	; check for underflow
	mov a, #ffh
	xrl a, r0
	jnz __GetAllocationSize_NoUnderflow
	; underflow, decrement high byte of target allocation address
	dec p2			; decrement high byte of target allocation address
__GetAllocationSize_NoUnderflow:
	movx a, @r0		; load size of target allocation to a
	mov r2, a		; write to r2 (for stack operation)
	push DIRECT_R2	; push result to stack
	; restore our own return address
	push DIRECT_R6	; push low byte of return address to stack
	push DIRECT_R7	; push high byte of return address to stack
	; restore outer stack frame
	lcall SF_RESTORE
	ret

; can only load/devirtualize VirtualAlloc'd memory
; loads the VBUF address provided via stack params and returns the physical address on the stack (LE)
; [Physical][XRAM][WordSize(16)]void* VirtualLoad([VBUF][WordSize(8)]void* virtual);
VirtualLoadBuffer:
	ret

; uint_8 VirtualRead([VRAM][WordSize(8)]void* virtual);
VirtualRead:
	ret

; void VirtualWrite([VRAM][WordSize(8)]void* virtual, uint_8 value);
VirtualWrite:
	ret

; [Physical][XRAM][WordSize(16)]void* VirtualLoad([VRAM][WordSize(8)]void* virtual);
VirtualLoad:
	ret

; TODO: can't use DPTR anywhere :C, convert to VirtualRead/Write/Load
; loads the VRAM address pointed at by DPTR from ROM and returns the physical address on the stack
VirtualLoadOLD:
	; we need to preserve the outer execution context
	mov DIRECT_DATA, r0		; save r0 to temporary memory
	; now do the virtual load
	clr a
	movc a, @A+DPTR			; load VRAM address from memory
	mov b, VRAM_BASE_LOW	; load low byte of VRAM base address to b
	add a, b 				; add VRAM base address (low) to address space offset
	mov r0, a				; save physical address (low) to r0
	; VRAM_SIZE is always 1 (256 byte blocks, 8 bit addressable)
	mov a, VRAM_BASE_HIGH	; load high byte of VRAM base address to a
	mov b, S_CLIENT_INDEX	; load client index to b
	add a, b				; add client index to high byte of VRAM base address to get the physical address high byte
	mov p2, a				; save physical address high byte to port 2
	mov a, r0				; load physical address low byte to a
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

; stores all registers on the external stack frame stack and increments the SF stack pointer
; Offset table:
; 0 -> a
; 1 -> b
; 2 -> r0
; 3 -> r1
; 4 -> r2
; 5 -> r3
; 6 -> r4
; 7 -> r5
; 8 -> r6
; 9 -> r7
SF_STORE:
	; we need to preserve the outer execution context
	; save working registers in temporary memory
	mov DIRECT_DATA_1, a
	mov DIRECT_DATA_2, r0
	mov r0, S_STACK_FRAME_SP	; load stack frame pointer* to r0
	mov a, @r0					; get low byte of stack frame pointer
	inc r0						; increment stack frame pointer* to point at high byte
	mov p2, @r0					; store high byte of stack frame pointer to port 2
	mov r0, a					; move low byte of stack frame pointer to r0
	; store a
	mov a, DIRECT_DATA_1		; restore a from temporary memory
	movx @r0, a					; store a to stack frame
	inc r0						; increment stack frame pointer* to point at next register
	mov a, r0					; need to check for overflow
	jnz __SF_STORE_NoOverflowA
	inc p2						; handle overflow
__SF_STORE_NoOverflowA:
	; store b
	mov a, b
	movx @r0, a					; store b to stack frame
	inc r0						; increment stack frame pointer* to point at next register
	mov a, r0					; need to check for overflow
	jnz __SF_STORE_NoOverflowB
	inc p2						; handle overflow
__SF_STORE_NoOverflowB:
	; store r0
	mov a, DIRECT_DATA_2		; restore r0 from temporary memory
	movx @r0, a					; store r0 to stack frame
	inc r0						; increment stack frame pointer* to point at next register
	mov a, r0					; need to check for overflow
	jnz __SF_STORE_NoOverflowR0
	inc p2						; handle overflow
__SF_STORE_NoOverflowR0:
	; store r1
	mov a, r1
	movx @r0, a					; store r1 to stack frame
	inc r0						; increment stack frame pointer* to point at next register
	mov a, r0					; need to check for overflow
	jnz __SF_STORE_NoOverflowR1
	inc p2						; handle overflow
__SF_STORE_NoOverflowR1:
	; loop through remaining registers
	; for (int ri = 2; ri < 8; ri++, framePointer++)
	mov r1, #2					; reset loop counter to 2 (same as direct address of r2-7)
__SF_STORE_Loop:
	mov a, #8h					; load exclusive upper bound of registers to a
	xrl a, r1					; check
	jz __SF_STORE_LoopEnd		; if counter == 8, we are done
	mov a, @r1					; load register i to a
	movx @r0, a					; store register i to stack frame
	inc r0						; increment stack frame pointer* to point at next register
	mov a, r0					; need to check for overflow
	jnz __SF_STORE_NoOverflowRi
	inc p2						; handle overflow
__SF_STORE_NoOverflowRi:
	inc r1						; increment loop counter
	jmp __SF_STORE_Loop			; loop
__SF_STORE_LoopEnd:
	; update stack frame pointer*
	mov r1, S_STACK_FRAME_SP	; load stack frame pointer* to r0
	mov @r1, r0					; store stack frame pointer* (low) back to memory
	inc r1						; increment stack frame pointer* to point at high byte
	mov @r1, p2					; store stack frame pointer* (high) back to memory
	ret

; restores all registers from the external stack frame stack and decrements the SF stack pointer
; Offset table:
; 0 -> a
; 1 -> b
; 2 -> r0
; 3 -> r1
; 4 -> r2
; 5 -> r3
; 6 -> r4
; 7 -> r5
; 8 -> r6
; 9 -> r7 (top of the stack)
SF_RESTORE:
	mov r0, S_STACK_FRAME_SP	; load stack frame pointer* to r0
	mov a, @r0					; get low byte of stack frame pointer
	inc r0						; increment stack frame pointer* to point at high byte
	mov p2, @r0					; store high byte of stack frame pointer to port 2
	mov r0, a					; move low byte of stack frame pointer to r0
	; restore registers r2-7 in reverse order using loop
	; for (int ri = 7; ri > 1; ri--, framePointer--)
	mov r1, #7h					; reset loop counter to 7 (same as direct address of r7)
	__SF_RESTORE_Loop:
	mov a, #1h					; load exclusive lower bound of registers to a
	xrl a, r1					; check
	jz __SF_RESTORE_LoopEnd		; if counter == 1, we are done
	movx a, @r0					; load register i from stack frame
	mov @r1, a					; load a to register i 
	dec r0						; decrement stack frame pointer* to point at next register
	mov a, r0					; need to check for underflow
	xrl a, #ffh					; check for underflow
	jnz __SF_RESTORE_NoUnderflowRi
	dec p2						; handle underflow
	__SF_RESTORE_NoUnderflowRi:
	dec r1						; decrement loop counter
	jmp __SF_RESTORE_Loop		; loop
	__SF_RESTORE_LoopEnd:
	; load registers a, b, r0, r1 from stack frame
	movx a, @r0					; load r1 from stack frame
	mov DIRECT_DATA_1, a		; store r1 to DIRECT DATA 1 buffer
	dec r0						; decrement stack frame pointer* to point at next register
	mov a, r0					; need to check for underflow
	xrl a, #ffh					; check for underflow
	jnz __SF_RESTORE_NoUnderflowR1
	dec p2						; handle underflow
	__SF_RESTORE_NoUnderflowR1:
	movx a, @r0					; load r0 from stack frame
	mov DIRECT_DATA_2, a		; store r0 to DIRECT DATA 2 buffer
	dec r0						; decrement stack frame pointer* to point at next register
	mov a, r0					; need to check for underflow
	xrl a, #ffh					; check for underflow
	jnz __SF_RESTORE_NoUnderflowR0
	dec p2						; handle underflow
	__SF_RESTORE_NoUnderflowR0:
	movx a, @r0					; load b from stack frame
	mov b, a					; restore b
	dec r0						; decrement stack frame pointer* to point at next register
	mov a, r0					; need to check for underflow
	xrl a, #ffh					; check for underflow
	jnz __SF_RESTORE_NoUnderflowB
	dec p2						; handle underflow
	__SF_RESTORE_NoUnderflowB:
	movx a, @r0					; load a from stack frame
	mov DIRECT_DATA_3, a		; store a to DIRECT DATA 3 buffer
	; done popping registers from stack frame
	; update stack frame pointer*
	mov r1, S_STACK_FRAME_SP	; load stack frame pointer* to r0
	mov @r1, r0					; store stack frame pointer* (low) back to memory
	inc r1						; increment stack frame pointer* to point at high byte
	mov @r1, p2					; store stack frame pointer* (high) back to memory
	; restore working registers
	mov r1, DIRECT_DATA_1
	mov r0, DIRECT_DATA_2
	mov a, DIRECT_DATA_3
	ret