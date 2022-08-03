; 25.07.2022 13:31:55

#cpu = 89S8252    ; @12 MHz


ajmp Initialisierung

Timer 0:    ; Timer 0 Interrupt
    ajmp Timer 0 Interrupt

Initialisierung:
orl TMOD, # 02h    ; Timer 0 im 8-Bit Autoreload-Modus. 
; Die Überlauffrequenz des Timer 0 beträgt 4000 Hz, die Periodendauer 0,25 ms.
mov TH0, # 06h    ; Reloadwert

; Interrupts
setb ET0    ; Timer 0 Interrupt freigeben
setb EA    ; globale Interruptfreigabe
setb TR0    ; Timer 0 läuft.

; Variables
mov 36h, #0Fh  ; use two registers to create 4000d
mov A, #A0h

mov 30h, #0 ; set all timer vars
mov 31h, #0
mov 32h, #0
mov 33h, #25d
mov 34h, #61d
mov 35h, #61d

end
; * * * Hauptprogramm Ende * * *

Timer 0 Interrupt:
        lcall Dec Reg 1
reti

Dec Reg 1: 
    jz Dec Reg 2
    dec A
ret

Dec Reg 2:
    djnz 36h, 47h ; TODO skip one second passed logic
    lcall Inc Seconds ; <-- both registers are 0 so one second passed
    mov 36h, #0Fh
    mov A, #A0h
    ajmp 49h ; TODO skip to ret
    mov A, #FFh ; if not zero
ret

Inc Seconds:
    djnz 35h, 58h ; TODO skip to inc 
    lcall Inc Minutes
    mov 35h, #61d
    mov 32h, #0
    ajmp 5Ah ; TODO jump to ret
    inc 32h
ret

Inc Minutes:
    djnz 34h, 69h ; TODO skip to inc
    lcall Inc Hours
    mov 34h, #61d
    mov 31h, #0
    ajmp 6Bh ; TODO jump to ret
    inc 31h
ret

Inc Hours:
    djnz 33h, 77h ; TODO skip to inc 
    mov 33h, #25d
    mov 30h, #0
    ajmp 79h ; TODO jump to ret
    inc 30h
ret