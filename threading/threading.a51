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

; global constants
; true xor false => true
#DEFINE TRUE 			#ffh
#DEFINE FALSE			#00h

; ============================================================================

; Timer 0 in 8-bit autoreload mode.
#DEFINE TIMER_MODE			#02h
; The overflow frequency of the timer 0 is 4000 Hz, the period duration 0.25 ms.
#DEFINE TIMER_RELOAD_VALUE	#06h
#DEFINE TIMER_VALUE			tl0
#DEFINE TIMER_RANGE			#250d

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

#DEFINE TICK_COUNTER 			38h

#DEFINE T0_RESUMED_MICRO_TICKS	39h
#DEFINE T0_RESUMED_TICKS		3ah

#DEFINE TX_START_TICKS			3bh
#DEFINE TX_START_MICRO_TICKS	3ch

; Task 0 (sorting) monitoring counter LE
#DEFINE T0_CTR32_0			40h
#DEFINE T0_CTR32_1			41h
#DEFINE T0_CTR32_2			42h
#DEFINE T0_CTR32_3			43h

; Task 1 (reaction) monitoring counter LE
#DEFINE T1_CTR32_0			44h
#DEFINE T1_CTR32_1			45h
#DEFINE T1_CTR32_2			46h
#DEFINE T1_CTR32_3			47h

; Task 2 (clock) monitoring counter LE
#DEFINE T2_CTR32_0			48h
#DEFINE T2_CTR32_1			49h
#DEFINE T2_CTR32_2			4ah
#DEFINE T2_CTR32_3			4bh

; Task 2 (temperature) monitoring counter LE
#DEFINE T3_CTR32_0			4ch
#DEFINE T3_CTR32_1			4dh
#DEFINE T3_CTR32_2			4eh
#DEFINE T3_CTR32_3			4fh

; constants
; 40 at 4000Hz = 10 ms
#DEFINE TICK_RESET_VALUE	#40d
; 32 bit register pointers
#DEFINE UINT32_0_PTR		#30h
#DEFINE UINT32_1_PTR		#34h
; monitoring counter pointers
#DEFINE MONITORING_BASE_PTR #40h
#DEFINE T0_CTR32_PTR		#40h
#DEFINE T1_CTR32_PTR		#44h
#DEFINE T2_CTR32_PTR		#48h
#DEFINE T3_CTR32_PTR		#4ch

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
#DEFINE SWAP_DPL		72h
#DEFINE SWAP_DPH		73h

#DEFINE SWAP_UINT32_00	74h
#DEFINE SWAP_UINT32_01	75h
#DEFINE SWAP_UINT32_02	76h
#DEFINE SWAP_UINT32_03	77h

#DEFINE SWAP_UINT32_10	78h
#DEFINE SWAP_UINT32_11	79h
#DEFINE SWAP_UINT32_12	7Ah
#DEFINE SWAP_UINT32_13	7Bh

#DEFINE SWAP_PSW		7Ch

; ============================================================================

; REACTION
; register-based variables
#DEFINE REACTION_INPUT			p1
#DEFINE REACTION_TEST_VALUE		r0
#DEFINE REACTION_OUTPUT			p3
#DEFINE REACTION_RETURN_VALUE 	r1
#DEFINE REACTION_CODE_LESS_100	#1h
#DEFINE REACTION_CODE_100		#3h
#DEFINE REACTION_CODE_100_200	#0h
#DEFINE REACTION_CODE_200_PLUS	#2h

; ============================================================================

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
; 100 at 100Hz = 1s
#DEFINE CLOCK_TICK_RESET_VALUE	#100d

; ============================================================================

; TEMPERATURE
; memory addresses
#DEFINE TEMPERATURE_RING_BUFFER		#58h
#DEFINE TEMPERATURE_TICKS			62h
#DEFINE TEMPERATURE_AVERAGE			63h
#DEFINE TEMPERATURE_DRIFT			64h
#DEFINE TEMPERATURE_RING_BUFFER_PTR	65h
#DEFINE TEMPERATURE_SUM_LOW			66h
#DEFINE TEMPERATURE_SUM_HIGH		67h

; constants
#DEFINE TEMPERATURE_RING_BUFFER_SIZE	#10d
; 10 at 1Hz = 10s
#DEFINE TEMPERATURE_TICKS_RESET_VALUE	#10d
#DEFINE TEMPERATURE_DRIFT_FALLING		#0d
#DEFINE TEMPERATURE_DRIFT_RISING		#1d
#DEFINE TEMPERATURE_DRIFT_STEADY		#ffh

; ============================================================================

; SORT

; variable registers
#DEFINE SORT_SWAPPED	b
#DEFINE SORT_I_HIGH		r5
#DEFINE SORT_I_LOW		r4
#DEFINE SORT_J_HIGH		r3
#DEFINE SORT_J_LOW		r2
#DEFINE SORT_CURRENT	r1
#DEFINE SORT_PREVIOUS	r0

; recursive direct address mode definition for variable i
; must be able to move register to register
#DEFINE SORT_I_LOW_DIRECT DIRECT_R4
#DEFINE SORT_I_HIGH_DIRECT DIRECT_R5
#DEFINE SORT_CURRENT_DIRECT DIRECT_R1

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
;  RAM S	  	 | 0x30	 | 0x4f	 | 32   | RAM for Scheduler
;  --------------+-------+-------+------+----------------------------------------------
;  RAM 1    	 | -	 | -	 | 0    | RAM for Task 1: Reaction (allocation free)
;  --------------+-------+-------+------+----------------------------------------------
;  RAM 2	  	 | 0x50	 | 0x57	 | 8    | RAM for Task 2: Clock
;  --------------+-------+-------+------+----------------------------------------------
;  RAM 3	  	 | 0x58	 | 0x67	 | 16   | RAM for Task 3: Temperature
;  --------------+-------+-------+------+----------------------------------------------
;  RAM 0  	 	 | -	 | -     | 0    | RAM for Task 0: Sorting (allocation free)
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
	; Timer 0 in 8-bit autoreload mode.
	orl TMOD, TIMER_MODE
	; The overflow frequency of the timer 0 is 4000 Hz, the period duration 0.25 ms.
	mov TH0, TIMER_RELOAD_VALUE
	; Timer 0 ticks at 1 MHz

	; Interrupts
	setb ET0    ; Timer 0 Interrupt freigeben
	setb EA    	; globale Interruptfreigabe
	
	; initialize monitoring
	lcall MON_Init

	;reset clock tick counter
	lcall ResetTicks

	; initialize clock
	lcall Clock_Init
	lcall Temperature_Init

	; setup monitoring variables for task 0 (sorting)
	mov T0_RESUMED_TICKS, TICK_RESET_VALUE
	; actually + time needed for setb and lcall
	mov T0_RESUMED_MICRO_TICKS, TIMER_RELOAD_VALUE

	setb TR0    ; Timer 0 l�uft.
	; run sorting task by default
	lcall Sort_Notify

	end ; <- return adderss on first interrupt
; * * * Hauptprogramm Ende * * *

; if (--interruptCounter == 0) 
; {
; 	  ResetTicks();
;	  TasksNotifyAll();
; }
OnTick:
	; T0 overflowed. T0 will be 06h (reset value) here.
	; can not use registers here, execution context is not yet stored
	djnz TICK_COUNTER, __OnTick_End
	; store execution context
	lcall EXC_STORE
	; immediately re-enable timer 0 interrupt (allow interrupting itself for accurate monitoring)
	; as we NEED to count timer overflows to "allow time to pass" while running all the tasks.
	; for some reason timer 0 seems to run at 12MHz too which doesn't make sense, because
	; 250 ticks timer range (reload value = 0x6) @12MHz is 48000Hz, not 4000Hz as the AS51 timer
	; config tool wants us make to believe.
	; So either we're running too fast or the simulator's timer is broken as it *should* tick @1MHz.
	; Still this code works: (only clock seconds may actually be 1/12th of a second) :P
	lcall RestoreInterruptLogic
	; stop measurement of T0 task
	; t0Elapsed += t0ResumedTicks * 250 - (t0ResumedMicroTicks - timerReloadValue)
	mov r2, T0_CTR32_PTR
	push DIRECT_R2			; push uint32_t* pCounterTask0 to stack
	; t0ResumedTicks * 250 - (t0ResumedMicroTicks - timerReloadValue)
	clr c
	mov a, T0_RESUMED_MICRO_TICKS	; t0ResumedMicroTicks to a
	subb a, TIMER_RELOAD_VALUE		; a = a - timerReloadValue
	mov r1, a						; r1 = a
	clr c
	mov a, T0_RESUMED_TICKS			; a = t0ResumedTicks
	mov b, TIMER_RANGE				; b = timerRange (250)
	mul ab
	clr c
	subb a, r1
	mov r2, a
	push DIRECT_R2					; push low elapsed to stack
	mov a, b
	subb a, #0
	mov r2, a
	push DIRECT_R2					; push high elapsed to stack
	lcall Add32_Dyn 				; 32 bit + 16 bit addition
	; 10 ms elapsed -> let all tasks run
	lcall ResetTicks
	lcall TasksNotifyAll
	; restore execution context
	lcall EXC_RESTORE
	; resume measurement of T0 task
	mov T0_RESUMED_TICKS, TICK_COUNTER		; snap copy of current tick counter
	mov T0_RESUMED_MICRO_TICKS, TIMER_VALUE	; snap copy of current timer value
	ret
__OnTick_End:
	reti

RestoreInterruptLogic:
	reti

TasksNotifyAll:
	; notify all tasks
	lcall MON_StartMeasurement	; start measurement of reaction task
	lcall Reaction_Notify
	lcall MON_StopMeasurement	; stop measurement
	; load target address of 32bit reaction time counter
	mov r0, T1_CTR32_PTR
	push DIRECT_R0
	lcall MON_StoreMeasurement	; store measuement

	lcall MON_StartMeasurement	; start measurement of clock task
	lcall Clock_Notify
	; return value of Clock (secondElapsed = true|false) to r4 (unused by monitoring)
	pop DIRECT_R4
	lcall MON_StopMeasurement	; stop measurement
	; load target address of 32bit clock time counter
	mov r0, T2_CTR32_PTR
	push DIRECT_R0
	lcall MON_StoreMeasurement	; store measuement

	lcall MON_StartMeasurement	; start measurement of temperature task
	mov a, r4					; load return value of clock & check if 10 seconds elapsed
	jz __TasksNotifyAll_SkipTemperature
	lcall Temperature_Notify
__TasksNotifyAll_SkipTemperature:
	lcall MON_StopMeasurement	; stop measurement
	; load target address of 32bit temperature time counter
	mov r0, T3_CTR32_PTR
	push DIRECT_R0
	lcall MON_StoreMeasurement	; store measuement
	ret

; reset ticks
ResetTicks:
	mov TICK_COUNTER, TICK_RESET_VALUE
	ret

; sets all monitoring counters to 0
MON_Init:
	; MemSet(monitoringBasePtr, 16, 0);
	mov r0, MONITORING_BASE_PTR	; load base pointer of counter region
	push DIRECT_R0				; push to stack
	mov r0, #16					; load size of counter region
	push DIRECT_R0				; push to stack
	mov r0, #0					; load target value = 0
	push DIRECT_R0				; push to stack
	lcall MemSet				; call memset
	ret
	
; snap a copy of the current interruptCounter and currentTimerValue. 
; locking would be nice here, to prevent interrupts from changing the interruptCounter
MON_StopMeasurement:
	mov r0, TIMER_VALUE
	mov r1, TICK_COUNTER
	; store return address
	pop DIRECT_R7
	pop DIRECT_R6
	; push result
	push DIRECT_R0
	push DIRECT_R1
	; restore return address
	push DIRECT_R6
	push DIRECT_R7
	ret

MON_StartMeasurement:
	mov TX_START_TICKS, TICK_COUNTER
	mov TX_START_MICRO_TICKS, TIMER_VALUE
	ret

; void MON_StoreMeasurement(uint8_t tickCounter, uint8_t timerValue, uint32_t* pCounter, );
; 	*pCounter += (startTicks - interruptCounter) * 250 + currentTimerValue - startMicroTicks;
MON_StoreMeasurement:
	; store our return address
	pop DIRECT_R7
	pop DIRECT_R6
	; pop parameters but leave pCounter on the stack
	pop DIRECT_R2				; pCounter to r2
	pop DIRECT_R1				; current interruptCounter to r1
	pop DIRECT_R0				; current currentTimerValue to r0
	; restore return address
	push DIRECT_R6
	push DIRECT_R7
	; pCounter is first parameter for Add32_Dyn
	push DIRECT_R2				; push pCounter back to stack
	; (startTicks - interruptCounter)
	mov a, TX_START_TICKS
	clr c
	subb a, r1					; assume no underflow here :)
	; (startTicks - interruptCounter) * 250 
	mov b, TIMER_RANGE
	mul ab
	; (startTicks - interruptCounter) * 250 + currentTimerValue
	add a, r0
	xch a, b
	addc a, #0
	xch a, b
	; (startTicks - interruptCounter) * 250 + currentTimerValue - startMicroTicks;
	clr c
	subb a, TX_START_MICRO_TICKS
	mov r2, a
	push DIRECT_R2
	mov a, b
	subb a, #0
	mov r2, a
	push DIRECT_R2
	;*pCounter += (startTicks - interruptCounter) * 250 + currentTimerValue - startMicroTicks;
	lcall Add32_Dyn				; 32-bit + 16-bit addition
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
	; store dptr
	mov SWAP_DPL, dpl
	mov SWAP_DPH, dph
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
	; restore dptr
	mov dph, SWAP_DPH
	mov dpl, SWAP_DPL
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

; adds the UINT32_0 to UINT32_1 and stores the result in UINT32_0
; void Add32();
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

; Dynamically adds summand to *pvalue and stores the result in *pvalue;
; void Add32_Dyn(uint32_t* pvalue, uint8_t summandLow, uint8_t summandHigh);
;     *value += summand;
Add32_Dyn:
	; store our return address
	pop DIRECT_R7			; high byte to r7
	pop DIRECT_R6			; low byte to r6
	; now get parameters
	pop DIRECT_R2			; summandHigh to r2
	pop DIRECT_R1			; summandLow to r1
	pop DIRECT_R0			; pvalue to r0
	; restore return address
	push DIRECT_R6
	push DIRECT_R7
	; byte 0
	mov a, r1
	add a, @r0
	mov @r0, a
	inc r0
	; byte 1
	mov a, r2
	addc a, @r0
	mov @r0, a
	inc r0
	; byte 2
	mov a, #0
	addc a, @r0
	mov @r0, a
	inc r0
	; byte 3
	mov a, #0
	addc a, @r0
	mov @r0, a
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

; void MemSet(void* ptr, uint8_t size, uint8_t value)
MemSet:
	; store our return address
	pop DIRECT_R7			; high byte to r7
	pop DIRECT_R6			; low byte to r6
	; now get parameters
	pop DIRECT_R2			; value to r2
	pop DIRECT_R1			; size to r1
	pop DIRECT_R0			; ptr to r0
	; calculate stop address for memset (ptr + size)
	mov a, r1
	add a, r0
	mov r1, a				; boundary address to r1
__MemSet_Loop:
	mov a, r1
	xrl a, r0
	jz __MemSet_LoopEnd
	mov a, r2
	mov @r0, a
	inc r0
	ljmp __MemSet_Loop
__MemSet_LoopEnd:
	; restore return address
	push DIRECT_R6
	push DIRECT_R7
	ret

; ============================================================================
; 									REACTION
; ============================================================================
; reads the uin8_t value from port 1, does bound checking and returns the result in lowest 2 bits in port 3
; Port 3: (XH, XL)
; 0,1: Wert < 100
; 1,1: Error (Wert == 100)
; 0,0: 100 < Wert < 200
; 1,0 : Wert >= 200
Reaction_Notify:
	; take snapshot of port 1
	mov REACTION_TEST_VALUE, REACTION_INPUT
	; store return value in r1, assume value < 100
	mov REACTION_RETURN_VALUE, REACTION_CODE_LESS_100
	; compare against < 100
	clr c
	mov a, #99d
	subb a, REACTION_TEST_VALUE	; subtract value from 99
	jnc __Reaction_NotifyEnd	; if no carry, value is <= 99
	; value is > 99, assume value == 100
	mov REACTION_RETURN_VALUE, REACTION_CODE_100
	; compare against 100
	mov a, #100d
	xrl a, REACTION_TEST_VALUE	; xor value with 100
	jz __Reaction_NotifyEnd		; if zero, value is 100
	; value is > 100, assume value < 200
	mov REACTION_RETURN_VALUE, REACTION_CODE_100_200
	; compare against < 200
	clr c
	mov a, #199d
	subb a, REACTION_TEST_VALUE	; subtract value from 199
	jnc __Reaction_NotifyEnd	; if no carry, value is <= 199
	; value is >= 200
	mov REACTION_RETURN_VALUE, REACTION_CODE_200_PLUS					
__Reaction_NotifyEnd:
	; store return value in port 3
	mov REACTION_OUTPUT, REACTION_RETURN_VALUE	
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


; returns true if a second has elapsed.
; bool Clock_Notify()
; if (--clock_tick_counter == 0) 
; {
; 	  Clock_ResetTicks();
;	  Clock_OnEachSecond();
; 	  return true; 
; }
; return false; 
Clock_Notify:
	mov r0, FALSE				; assume false by default
	djnz CLOCK_TICK_COUNTER, __Clock_NotifyEnd
	; a second has elapsed
	lcall Clock_ResetTicks
	lcall Clock_OnEachSecond
	mov r0, TRUE				; a second has elapsed -> return true
__Clock_NotifyEnd:
	; store return address
	pop DIRECT_R7
	pop DIRECT_R6
	; push return value
	push DIRECT_R0
	; restore return address
	push DIRECT_R6
	push DIRECT_R7
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
	; Memset(baseAddress, size, 0);
	mov r2, TEMPERATURE_RING_BUFFER 		; load ring buffer base address to r2
	push DIRECT_R2							; push to stack
	mov r2, TEMPERATURE_RING_BUFFER_SIZE	; load buffer size
	push DIRECT_R2							; push to stack
	mov r2, #0								; load target value
	push DIRECT_R2							; push to stack
	lcall MemSet							; call memset
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

; (from https://en.wikipedia.org/wiki/Bubble_sort)
; procedure bubbleSort(A : list of sortable items)
;     n := length(A)
;     repeat
;         swapped := false
;         for i := 1 to n-1 inclusive do
;             /* if this pair is out of order */
;             if A[i-1] > A[i] then
;                 /* swap them and remember something changed */
;                 swap(A[i-1], A[i])
;                 swapped := true
;             end if
;         end for
;     until not swapped
; end procedure

; our adaptation:
;void Bubblesort(uint8_t *array, uint16_t length)
;{
;	uint8_t swapped = true;
;	while (swapped != false)
;	{
;		swapped = false;
;		uint16_t i = 1;
;		uint16_t j = i - 1;
;		uint8_t previous = array[j];
;		while (j != length)
;		{
;			uint8_t current = array[i];
;			if (current - previous < 0)
;			{
;				array[i] = previous;
;				array[j] = current;
;				swapped = true;
;			}
;			else
;			{
;				previous = current;
;			}
;			j = i;
;			i++;
;		}
;	}
;}

; r7 unused / temp storage buffer
; r6 i high
; r5 i low
; r4 j high
; r3 j low
; r2 current value
; r1 previous value
; r0 unused
; b swapped (0x00 = false, 0xff = true)

; called only once, when the program starts
Sort_Notify:
	mov SORT_SWAPPED, TRUE		; uint8_t swapped = true;
__Sort_Notify_OuterLoop:
	; while (swapped != false)
	mov a, SORT_SWAPPED
	jz __Sort_Notify_OuterBreak
	mov SORT_SWAPPED, FALSE	; swapped = false;
	; uint16_t i = 1;
	mov SORT_I_LOW, #1				;  r5 (i low)
	mov SORT_I_HIGH, #0				;  r6 (i high)
	mov dptr, #0					;  DPTR = 0x0; (DPTR is previous value)
	; uint16_t j = i - 1; (or j = DPTR)
	mov SORT_J_LOW, dpl				; DP low to j low
	mov SORT_J_HIGH, dph			; DP high to j high
	; load initial value for previous variable
	movx a, @dptr					; load previous value (from dptr)
	mov SORT_PREVIOUS, a			; store previous value
__Sort_Notify_InnerLoop:
	; while (i - 1 != 0xffff) (upper bound is inclusive! => check for j != 0xffff)
	; (j_h ^ 0xff) | (j_l ^ 0xff) == 0 => jz inner_break :)
	mov a, SORT_J_HIGH
	xrl a, #ffh
	mov r7, a
	mov a, SORT_J_LOW
	xrl a, #ffh
	orl a, r7
	jz __Sort_Notify_InnerBreak
	; previous is already loaded in loop init and increment 
	; uint8_t current = XRAM[i];
	; remember i = j + 1
	inc dptr				; increment dptr
	movx a, @dptr			; load current value
	mov SORT_CURRENT, a		; store current value
	; if (current - previous < 0) same as previous > current => jnc continue
	clr c					; clear carry flag
	subb a, SORT_PREVIOUS	; a = current - previous
	jnc __Sort_Notify_NoSwap
	; swap current and previous and remember something changed
	; j is previous, i is current
	; previous is still loaded as XRAM address
	mov a, SORT_PREVIOUS	; load previous value
	movx @dptr, a			; write previous value to current location
	mov dpl, SORT_J_LOW		; load j low to dpl
	mov dph, SORT_J_HIGH	; load j high to dph
	mov a, SORT_CURRENT		; load current value
	movx @dptr, a			; write current value to previous location
	; remember we swapped something (swapped = true);
	mov SORT_SWAPPED, TRUE	
	ljmp __Sort_Notify_Continue
__Sort_Notify_NoSwap:
	; if we didn't swap anything, we need to update the previous value
	; if we swapped something, the previous value remains the same
	mov SORT_PREVIOUS, SORT_CURRENT_DIRECT
__Sort_Notify_Continue:
	; j = i via direct addressing;
	mov SORT_J_LOW, SORT_I_LOW_DIRECT
	mov SORT_J_HIGH, SORT_I_HIGH_DIRECT
	; set dptr = i
	mov dpl, SORT_I_LOW
	mov dph, SORT_I_HIGH
	; i++
	inc dptr
	; dptr is now i + 1
	; i = dptr;
	mov SORT_I_LOW, dpl
	mov SORT_I_HIGH, dph
	; restore dptr from j (dptr == j == i - 1)
	mov dpl, SORT_J_LOW
	mov dph, SORT_J_HIGH
	; inner loop
	ljmp __Sort_Notify_InnerLoop
__Sort_Notify_InnerBreak:
	; outer loop
	ljmp __Sort_Notify_OuterLoop
__Sort_Notify_OuterBreak:
	ret