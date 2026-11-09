; ==============================================================================
; FILE:           keyboard_tools.asm
; PROGETTO:       Libreria di Sistema (io.c64)
; TARGET:         ACME Assembler / MOS 6510 (Commodore 64)
; DESCRIZIONE:    Lettura diretta della tastiera dalla matrice del CIA #1, senza
;                 passare dal Kernal. Deriva da quella del gioco Platoon,
;                 accorciata e con la serie storica integrata.
; CONTENUTO:      KEYSCAN   Scansiona un tasto della matrice della tastiera
; DIPENDENZE:     Nessuna
; REQUISITI ZP:   __KBD_HISTORY
; ==============================================================================

; ******************************************************************************
; NOTE D'USO
; ******************************************************************************
;
; NOTA #01
; --------
; KEYSCAN non cerca quale tasto sia premuto e non restituisce il codice tastiera
; di un tasto: fa l'inverso. Riceve il codice tastiera di un tasto e verifica se
; quel tasto è stato appena premuto. Non è adatta a scoprire quale tasto sia
; premuto tra tutti, perché non scansiona l'intera matrice.
;
; KEYSCAN controlla un tasto per volta e va chiamata a ogni passaggio di
; lettura. Segnala una nuova pressione una sola volta: finché il tasto resta
; premuto, le chiamate successive non riportano niente di nuovo. Un codice
; tastiera non valido (da KBD_NO_KEY in su) è un errore, come il falso tasto.
; Con il Carry a 0, il flag di Negative dice se il tasto è premuto e il flag di
; Zero se la pressione è nuova. Gli esempi sono nelle note da [NOTA #03] in poi.
;
;
; NOTA #02
; --------
; La serie storica, la cella in pagina zero __KBD_HISTORY, è un solo byte,
; condiviso da tutti i tasti, e ricorda la sola colonna dell'ultima pressione,
; non la riga. Il chiamante la azzera prima del primo uso. Quindi si controlla
; un tasto per volta: se nello stesso passaggio si scansionano tasti diversi,
; le chiamate si disturbano a vicenda e KEYSCAN segnala una nuova pressione a
; ogni passaggio finché uno dei tasti resta premuto. Due tasti della stessa
; colonna, poi, non si distinguono tra loro.
;
;
; NOTA #03
; --------
; Uso base: una scansione a ogni passaggio, per esempio dentro un gestore IRQ.
; Il Carry a 1 segnala un errore, il flag di Zero a 0 una nuova pressione.
; Esempio:
;
;   lda #KBD_SPACE                ; Tasto da scansionare.
;   jsr KEYSCAN
;   bcs .Exit_Handler             ; Falso tasto: ignora la lettura.
;
;   beq .Exit_Handler             ; Nessuna nuova pressione.
;
;   inc EXTCOL                    ; Nuova pressione: cambia il bordo.
;
; .Exit_Handler:
;   rts
;
;
; NOTA #04
; --------
; Debouncing. I contatti della tastiera rimbalzano per qualche millisecondo,
; sia premendo sia rilasciando il tasto. Il flag di Negative dice se il tasto
; è ancora premuto: una nuova pressione si conferma al passaggio successivo, e
; se il tasto non è più premuto era solo un rimbalzo. Lo snippet è per un
; gestore IRQ chiamato a ogni fotogramma, e _CANDIDATE è una cella di RAM del
; programma, azzerata all'avvio. Esempio:
;
;   lda #KBD_SPACE                ; Tasto da scansionare.
;   jsr KEYSCAN
;   bcs .Exit_Handler             ; Falso tasto: ignora la lettura.
;
;   bpl .Clear_Candidate          ; Il tasto non è premuto.
;
;   beq .Check_Candidate          ; Il tasto è tenuto.
;
;   lda #1                        ; Nuova pressione: la conferma
;   sta _CANDIDATE                ; arriva al prossimo passaggio.
;   rts
;
; .Clear_Candidate:
;   lda #0                        ; Rimbalzo o rilascio: annulla
;   sta _CANDIDATE                ; la pressione in attesa.
;   rts
;
; .Check_Candidate:
;   lda _CANDIDATE                ; C'è una pressione da confermare?
;
;   beq .Exit_Handler             ; No: il tasto è tenuto da prima.
;
;   lda #0                        ; Sì: la pressione è confermata.
;   sta _CANDIDATE
;
;   inc EXTCOL                    ; Cambia il bordo.
;
; .Exit_Handler:
;   rts
;
;
; NOTA #05
; --------
; Attesa della pressione e del rilascio. Il primo ciclo attende una nuova
; pressione, il secondo attende il rilascio: finché il tasto resta premuto il
; flag di Negative vale 1. Lo snippet è per il programma principale e non per
; un gestore IRQ, perché i cicli non cedono mai il controllo. Esempio:
;
; .Loop_Scan_Press:
;   lda #KBD_SPACE                ; REPEAT
;   jsr KEYSCAN
;   bcs .Loop_Scan_Press          ; Falso tasto: riprova.
;
; .Loop_Check_Press:
;   beq .Loop_Scan_Press          ; REPEAT UNTIL: nuova pressione
;
;   inc EXTCOL                    ; Tasto premuto: cambia il bordo.
;
; .Loop_Poll_Release:
;   lda #KBD_SPACE                ; REPEAT
;   jsr KEYSCAN
;   bcs .Loop_Poll_Release        ; Falso tasto: riprova.
;
; .Loop_Check_Release:
;   bmi .Loop_Poll_Release        ; REPEAT UNTIL: tasto non premuto
;
; ******************************************************************************

; ==============================================================================
; SUBROUTINE: KEYSCAN
; ------------------------------------------------------------------------------
; Descrizione:  Verifica se un tasto, indicato dal suo codice tastiera, è stato
;               appena premuto. Legge la matrice della tastiera direttamente dal
;               CIA #1 e presuppone che i registri di direzione dei suoi due
;               porti abbiano i valori predefiniti ($FF e $00).
;
;               Non cerca il tasto premuto e non ne restituisce il codice
;               tastiera: il codice tastiera è un dato in ingresso.
;
;               Un codice tastiera da KBD_NO_KEY in su non è valido: la
;               subroutine esce subito con il Carry a 1, senza toccare le porte.
;
;               Il codice tastiera è la posizione del tasto nella matrice, cioè
;               la riga per 8 più la colonna (KBD_*, da $00 a $3F). La serie
;               storica, __KBD_HISTORY, è un solo byte che ricorda l'ultima
;               colonna premuta.
;
;               Il Carry segnala il falso tasto: la colonna risulta bassa
;               anche senza nessuna riga selezionata, quindi la causa è
;               l'interferenza del joystick e non la tastiera. Con il Carry
;               a 0 il flag di Negative dice se il tasto è premuto e il flag
;               di Zero se la pressione è nuova.
;
; Input:
;   - .A (1 byte, CPU)             : Codice tastiera del tasto da scansionare
;   - __KBD_HISTORY (1 byte, ZP)   : Serie storica, da azzerare prima del
;                                    primo uso
;
; Output:
;   - __KBD_HISTORY (1 byte, ZP)   : Serie storica aggiornata
;   - Flag Negative (1 bit, .P)    : 0 = tasto non premuto; 1 = tasto premuto
;                                    (nuova pressione o tenuto). Indefinito se
;                                    Carry = 1
;   - Flag Zero (1 bit, .P)        : 0 = nuova pressione; 1 = tasto non premuto
;                                    o ancora tenuto. Indefinito se Carry = 1
;   - Flag Carry (1 bit, .P)       : 0 = lettura valida; 1 = falso tasto o
;                                    codice tastiera non valido
;
; Variazione Stack (.S):
;   - Stabile
;
; Registri Modificati:  .A, .P (Negative, Zero, Carry), CIAPRA, CIAPRB,
;                       __KBD_HISTORY
; Dipendenze Esterne:   <c64/keyboard.asm>
;                       <c64/symbols.asm>
;                       <chip/cia.asm>
; ==============================================================================
!if (__USE_KEYSCAN = 1) {
  !zone Keyscan

    KEYSCAN:
      ; ****************************************************************
      ; * TO-DO: soglia dei codici tastiera con __C128_C64_MODE = 1.   *
      ; *                                                              *
      ; * Che cosa fa il codice: scarta i codici tastiera da           *
      ; * KBD_NO_KEY in su e legge la matrice con le tabelle .KBD_ROW  *
      ; * e .KBD_COLUMN, che hanno 8 voci ciascuna.                    *
      ; *                                                              *
      ; * Che cosa succede davvero: con __C128_C64_MODE = 1 KBD_NO_KEY *
      ; * vale $58, quindi i codici extra del C128 da $40 a $57        *
      ; * superano il controllo e leggono oltre la fine delle tabelle. *
      ; *                                                              *
      ; * Conseguenze: la riga selezionata è un valore preso dai byte  *
      ; * che seguono le tabelle, e l'esito non ha senso.              *
      ; *                                                              *
      ; * Correzione: i tasti extra del C128 si leggono con un         *
      ; * meccanismo simile, ma da altre porte. Serve un ramo dedicato *
      ; * ai codici da $40 a $57, mentre questa subroutine resta       *
      ; * limitata alla matrice del C64.                               *
      ; *                                                              *
      ; * Fonte: segnalazione dell'utente, 2026-11-06.                 *
      ; ****************************************************************

      ; ****************************************************************
      ; * TO-DO: verificare l'influenza del secondo joystick.          *
      ; *                                                              *
      ; * Che cosa fa il codice: se la colonna risulta bassa, la       *
      ; * rilegge senza righe selezionate e la scarta come falso tasto *
      ; * se resta bassa. Il commento dice che il controllo vale per i *
      ; * joystick #1 e #2.                                            *
      ; *                                                              *
      ; * Che cosa succede davvero: il controllo è costruito sul       *
      ; * joystick nella porta 1, che si legge su PRB come la colonna. *
      ; * Il joystick nella porta 2 si legge su PRA, che KEYSCAN usa   *
      ; * per selezionare le righe: la sua influenza non è stata       *
      ; * ancora verificata.                                           *
      ; *                                                              *
      ; * Conseguenze: non è noto se il joystick nella porta 2 causi   *
      ; * falsi tasti o letture errate, né se il commento prometta più *
      ; * di quanto il codice garantisce.                              *
      ; *                                                              *
      ; * Correzione: provare KEYSCAN con il joystick nella porta 2,   *
      ; * su hardware o in VICE, e correggere il codice o il commento  *
      ; * secondo l'esito.                                             *
      ; *                                                              *
      ; * Fonte: segnalazione dell'utente, 2026-11-06.                 *
      ; ****************************************************************

      cmp #KBD_NO_KEY             ; Il codice tastiera è valido?
      bcs .Exit_KEYSCAN_Bad_Keycode

      pha                         ; Salva il codice tastiera.
      tya
      pha                         ; Salva .Y.
      txa
      pha                         ; Salva .X.

      tsx                         ; .X punta alla cima dello stack.
      lda STACK+3,x               ; Riprende il codice tastiera.
      lsr a                       ; Il codice diviso 8 indica la riga da selezionare.
      lsr a
      lsr a
      tay

      lda .KBD_ROW,y
      sta CIAPRA
      lda STACK+3,x               ; Riprende il codice tastiera.
      and #%00000111              ; I 3 bit meno significativi indicano
      tay                         ; la colonna da scansionare.

      lda CIAPRB
      and .KBD_COLUMN,y

      bne .No_Key                 ; Un risultato diverso da zero indica che il tasto non è
                                  ; stato premuto.

      lda #%11111111              ; Se invece il risultato è zero rileggi l'intera colonna
      sta CIAPRA                  ; per essere certi che i joystick #1 e #2
      lda CIAPRB                  ; non stiano interferendo.
      and .KBD_COLUMN,y

      beq .Exit_KEYSCAN_False_Key ; Ancora zero: è il joystick, non la tastiera.

      cmp __KBD_HISTORY           ; Confronta con la serie storica.
      beq .No_New_Press           ; Sono uguali: il tasto è ancora tenuto.

      sta __KBD_HISTORY           ; Nuova pressione: aggiorna la serie storica.
      lda #%10000000              ; Nuova pressione: Negative = 1, Zero = 0.
      bne .Exit_KEYSCAN

    .No_New_Press:
      lda #%10000010              ; Tasto tenuto: Negative = 1, Zero = 1.
      bne .Exit_KEYSCAN

    .No_Key:
      asl a                       ; Tasto non premuto: fai scorrere a sinistra la serie storica.
      sta __KBD_HISTORY

      lda #%00000010              ; Tasto non premuto: Negative = 0, Zero = 1.
      bne .Exit_KEYSCAN

    .Exit_KEYSCAN_Bad_Keycode:
      sec                         ; Codice tastiera non valido: Carry = 1.
      rts

    .Exit_KEYSCAN_False_Key:
      sta __KBD_HISTORY           ; .A vale 0: azzera la serie storica.
      lda #%00000001              ; Falso tasto: Carry = 1.

    .Exit_KEYSCAN:
      sta STACK+3,x               ; Salva i flag dell'esito al posto del codice tastiera.

      php
      pla                         ; .A = .P.

      and #%01111100              ; Conserva oVerflow, Break, Decimal e Interrupt.
      ora STACK+3,x               ; Aggiunge i flag dell'esito.
      sta STACK+3,x

      lda #%11111111              ; Rimetti le porte di lettura in stato di attesa.
      sta CIAPRA
      lda #%01111111
      sta CIAPRB

      pla
      tax                         ; Ripristina .X.
      pla
      tay                         ; Ripristina .Y.
      plp                         ; Ripristina l'esito.
      rts
      rts

    .KBD_ROW:
      !byte %11111110             ; Maschere di selezione della riga della matrice.
      !byte %11111101
      !byte %11111011
      !byte %11110111
      !byte %11101111
      !byte %11011111
      !byte %10111111
      !byte %01111111

    .KBD_COLUMN:
      !byte %00000001             ; Maschere di selezione della colonna della matrice.
      !byte %00000010
      !byte %00000100
      !byte %00001000
      !byte %00010000
      !byte %00100000
      !byte %01000000
      !byte %10000000

  !zone
}
