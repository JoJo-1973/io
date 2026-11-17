; Routine per loeggere le paddle eliminando il jitter.

; Input: C=0 leggi le paddle #1 e #2
;        C=1 leggi le paddle #3 e #4
; Output: .X Lettura paddle #1 / #3
;         .Y Lettura paddle #2 / #4
;         .A Lettura pulsanti: bit 0 = Paddle #1 / #3
;                              bit 1 = Paddle #2 / #4
;                              0 = rilasciato, 1 = premuto

!source <system/standard.asm>
!source <chip/sid.asm>
!source <chip/cia.asm>

PADDLE_READ:

SEI                   ; Disabilita le interruzioni così che la scansione della tastiera non influisca sulla lettura delle paddle.

lda CIAPRA
and #%00111111
bcs .Select_Port_2
ora #%01000000        ;                       ; Seleziona la porta joystick #1.
+m_Skip2
.Select_Port_2:
ora #%10000000        ; Seleziona la porta joystick #2.
sta CIAPRA

.Paddle_A:
lda CIAPRB            ; Leggi subito lo stato del pulsante della paddle #1 / #3
and #%00000100        ; Isola il bit 2 e salvalo.
sta .TEMP

LDA #$00              ; Azzera i registri di conteggio per la lettura della prima paddle.
TAX
TAY

CLC

.Loop_Sum_A
ADC POTX         ; Somma per 256 volte la lettura di .PADDLE_A
BCC .No_Carry_A       ; ma scarta il byte basso della somma e conserva solo
INY                   ; il byte alto in .Y. Questo equivale a sommare 256 volte e dividere il totale per 256: in altre parole si calcola la media di 256 letture.

.No_Carry_A
DEX
BNE .Loop_Sum_A

tya            ; Conserva il risultato sullo stack.
pha

.Paddle_B:
lda CIAPRB            ; Leggi subito lo stato del pulsante della paddle #2 / #4
and #%00001000        ; Isola il bit 3 e salvalo insieme allo stato dell'altro pulsante.
ora .TEMP
sta .TEMP

LDA #$00              ; Azzera i registri di conteggio per la lettura della seconda paddle.
TAX
TAY

CLC

.Loop_Sum_B
ADC POTY         ; Somma per 256 volte la lettura di .PADDLE_B
BCC .No_Carry_B       ; ma scarta il byte basso della somma e conserva solo
INY                   ; il byte alto in .Y. Questo equivale a sommare 256 volte e dividere il totale per 256: in altre parole si calcola la media di 256 letture.

.No_Carry_B
DEX
BNE .Loop_Sum_B

pla             ; Il risultato della seconda lettura è in .Y.
tax   ; Recupera il risultato della prima lettura e conservalo in .X.

lda .TEMP       ; Ora recupera in .A il risultato della lettura dei pulsanti
eor #%00001100  ; invertine lo stato (0 = rilasciato, 1 = premuto)
lsr a           ; e spostalo nei bit 0-1.
lsr a

.Exit_PADDLE_READ
CLI           ; Riabilita le interruzioni per poter rileggere la tastiera.
RTS

.TEMP:
!byte 0