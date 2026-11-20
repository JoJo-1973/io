; ==============================================================================
; FILE:           input_tools.asm
; PROGETTO:       Libreria di Sistema (io.c64)
; TARGET:         ACME Assembler / MOS 6510 (Commodore 64)
; DESCRIZIONE:    Lettura delle paddle del C64 con eliminazione del jitter.
; CONTENUTO:      PADDLE_READ   Legge le due paddle di una porta e i pulsanti
; DIPENDENZE:     <system/standard.asm>
; REQUISITI ZP:   Nessuno
; ==============================================================================

!source <system/standard.asm>, once

; ==============================================================================
; SUBROUTINE: PADDLE_READ
; ------------------------------------------------------------------------------
; Descrizione:  Legge le due paddle collegate a una porta joystick e i loro
;               pulsanti. Il Carry sceglie la porta: con Carry a 0 si leggono le
;               paddle #1 e #2, con Carry a 1 le paddle #3 e #4.
;
;               Dopo la scelta della porta attende 516 cicli (m_Delay_5n1),
;               perché il SID aggiorna POTX e POTY ogni 512 cicli circa (prova
;               su hardware: con 516 cicli la lettura è quella della porta
;               scelta, a meno di 1 di jitter). Poi, per eliminare il jitter,
;               legge ogni paddle 256 volte e calcola la media delle letture,
;               arrotondata all'intero più vicino. Le interruzioni sono
;               disabilitate durante la lettura, perché la scansione della
;               tastiera non influisca sulle paddle, e si riabilitano sempre
;               in uscita, anche se il chiamante le aveva già disabilitate.
;
;               Scrivendo in CIAPRA porta a 1 i bit #0-#5, cioè deseleziona le
;               righe da 0 a 5 della tastiera, e imposta i bit #6 e #7 per
;               scegliere la porta. Non li ripristina. Resta selezionata una
;               riga della tastiera (la 7 con la porta 1, la 6 con la porta 2):
;               i suoi tasti premuti falsano i pulsanti (confermato su
;               hardware): non si può evitare.
;
; Input:
;   - Flag Carry (1 bit, .P)       : 0 = paddle #1 e #2; 1 = paddle #3 e #4
;
; Output:
;   - .X (1 byte, CPU)             : Lettura della paddle #1 o #3
;   - .Y (1 byte, CPU)             : Lettura della paddle #2 o #4
;   - .A (1 byte, CPU)             : Pulsanti, 0 = rilasciato, 1 = premuto
;                                    (bit #0 = paddle #1 o #3, bit #1 =
;                                    paddle #2 o #4; gli altri bit sono 0)
;   - Flag Interrupt (1 bit, .P)   : sempre 0
;
; Variazione Stack (.S):
;   - Stabile
;
; Registri Modificati:  .A, .X, .Y, .P (Negative, oVerflow, Interrupt, Zero,
;                       Carry), CIAPRA
;
; Dipendenze Esterne:   <chip/cia.asm>
;                       <chip/sid.asm>
;                       <system/standard.asm>
; ==============================================================================
!if (__USE_PADDLE_READ = 1) {
  !zone Paddle_Read

    PADDLE_READ:
      sei                       ; La tastiera non disturba la lettura.

      lda #%00111111            ; Deseleziona le righe da 0 a 5.
      bcs .Select_Port_2        ; IF: Carry = 1

      ora #%01000000            ; Seleziona la porta joystick #1.
      +m_Skip2                  ; ALWAYS: salta l'istruzione seguente.

    .Select_Port_2:
      ora #%10000000            ; Seleziona la porta joystick #2.
      sta CIAPRA

      +m_Delay_5n1 ".X", 103    ; Attende 516 cicli: il SID aggiorna ogni 512.

      ; Lettura della prima paddle (#1 o #3).
      lda CIAPRB                ; Leggi subito il pulsante.
      and #%00000100            ; Isola il bit #2 e salvalo.
      sta ._TEMP

      ; Somma 256 letture partendo da 128 e scarta il byte basso: .Y
      ; conta i riporti, cioè il byte alto: la media arrotondata.
      lda #128                  ; Parte da 128 per arrotondare.
      ldy #0
      clc
      ldx #0                    ; FOR (Inizializzazione)

    .Loop_Sum_Paddle_1:
      adc POTX                  ; FOR (Corpo)

      bcc .Next_Sum_Paddle_1    ; IF: la somma ha un riporto

      iny                       ; Conta il riporto.
      clc                       ; Il riporto è già contato.

    .Next_Sum_Paddle_1:
      dex                       ; NEXT: 256 volte
      bne .Loop_Sum_Paddle_1    ; NEXT: 256 volte

      tya                       ; Conserva il risultato sullo stack.
      pha

      ; Lettura della seconda paddle (#2 o #4).
      lda CIAPRB                ; Leggi subito il pulsante.
      and #%00001000            ; Isola il bit #3 e uniscilo all'altro.
      ora ._TEMP
      sta ._TEMP

      ; Somma 256 letture partendo da 128 e scarta il byte basso: .Y
      ; conta i riporti, cioè il byte alto: la media arrotondata.
      lda #128                  ; Parte da 128 per arrotondare.
      ldy #0
      clc
      ldx #0                    ; FOR (Inizializzazione)

    .Loop_Sum_Paddle_2:
      adc POTY                  ; FOR (Corpo)

      bcc .Next_Sum_Paddle_2    ; IF: la somma ha un riporto

      iny                       ; Conta il riporto.
      clc                       ; Il riporto è già contato.

    .Next_Sum_Paddle_2:
      dex                       ; NEXT: 256 volte
      bne .Loop_Sum_Paddle_2    ; NEXT: 256 volte

      pla                       ; .X = lettura della prima paddle.
      tax

      lda ._TEMP                ; Recupera lo stato dei pulsanti,
      eor #%00001100            ; invertilo (0 = rilasciato) e
      lsr a                     ; portalo nei bit #0 e #1.
      lsr a

    .Exit_PADDLE_READ:
      cli                       ; Riabilita le interruzioni.
      rts

    ._TEMP:
      !byte 0

  !zone
}
