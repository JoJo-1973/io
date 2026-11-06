; ==============================================================================
; FILE:           disk_tools.asm
; PROGETTO:       Libreria di Sistema (io.c64)
; TARGET:         ACME Assembler / MOS 6510 (Commodore 64)
; DESCRIZIONE:    Utilità per la gestione delle unità disco.
; CONTENUTO:      DISK_STATUS         Legge lo stato dell'unità disco
;                 DECODE_DISK_STATUS  Decodifica lo stato dell'unità disco
;                 DISK_DIRECTORY      Stampa la directory del disco
; DIPENDENZE:     Nessuna
; REQUISITI ZP:   Nessuno
; ==============================================================================

; ==============================================================================
; SUBROUTINE: DISK_STATUS
; ------------------------------------------------------------------------------
; Descrizione:  Legge il messaggio di stato dell'unità disco dal canale comandi
;               (file logico 15, indirizzo secondario 15) e lo scrive in STACK,
;               la base della pagina dello stack, terminato da $00: il carattere
;               di ritorno a capo ($0D) che chiude il messaggio è sostituito
;               dallo zero finale. Il messaggio occupa al massimo 256 byte ed è
;               sovrascritto a ogni chiamata, quindi il chiamante lo usa subito
;               (per esempio con STROUT). Se il canale non si apre il buffer non
;               viene scritto.
;
;               Il flag di Carry dice solo se il messaggio è stato letto, non se
;               il disco ha segnalato un errore: per estrarne il codice si usa
;               DECODE_DISK_STATUS.
;
; Input:
;   - .A (1 byte, CPU)             : Numero dell'unità disco
;
; Output:
;   - STACK (fino a 256 byte, RAM) : Messaggio di stato terminato da $00
;   - Flag Carry (1 bit, .P)       : 0 = messaggio letto; 1 = canale non aperto
;
; Variazione Stack (.S):
;   - Stabile
;
; Registri Modificati:  .A, .X, .Y, .P (Negative, oVerflow, Zero, Carry),
;                       STACK (fino a 256 byte)
; Dipendenze Esterne:   <c64/kernal.asm>
;                       <c64/symbols.asm>
; ==============================================================================
!if (__USE_DISK_STATUS = 1) {
  !zone Disk_Status

    DISK_STATUS:
      tax                               ; Copia il numero dell'unità in .X.
      lda #15                           ; Numero del file logico.
      tay                               ; Indirizzo secondario: canale comandi.
      jsr SETLFS

      lda #0                            ; Nessun nome di file.
      jsr SETNAM

      jsr OPEN                          ; Apre il canale comandi.
      bcs .Exit_DISK_STATUS_Open_Error  ; Se ci sono errori chiude tutto ed esce.

      ldx #15                           ; L'input proverrà dal file logico 15.
      jsr CHKIN

      ldy #0

    .Loop_Read_Status:
      jsr READST                        ; REPEAT
      and #%01000000                    ; Il bit #6 indica la fine del file.
      bne .Break_Read_Status

      jsr CHRIN                         ; Legge il prossimo carattere e lo salva in STACK.
      sta STACK,y

    .Loop_Check_Status:
      iny
      bne .Loop_Read_Status             ; REPEAT UNTIL: il buffer è pieno

    .Break_Read_Status:
      dey                               ; Torna all'ultimo carattere letto ($0D) e lo
      lda #0                            ; sovrascrive con uno zero, così la stringa
      sta STACK,y                       ; si elabora più facilmente.

    .Exit_DISK_STATUS:
      clc                               ; Segnala il successo.

    ; Raggiunta con il Carry a 1 se OPEN è fallita: il Carry viene
    ; conservato durante la chiusura.
    .Exit_DISK_STATUS_Open_Error:
      php                               ; Salva il Carry: 0 = successo, 1 = errore.
      lda #15                           ; Chiude il file logico 15
      jsr CLOSE
      jsr CLRCHN                        ; e resetta i canali di I/O.
      plp                               ; Ripristina il Carry.
      rts

  !zone
}

; ==============================================================================
; SUBROUTINE: DECODE_DISK_STATUS
; ------------------------------------------------------------------------------
; Descrizione:  Decodifica il messaggio di stato dell'unità disco contenuto in
;               STACK (scritto da DISK_STATUS) e restituisce il codice
;               dell'errore e gli altri due numeri del messaggio. Il messaggio
;               ha la forma "NN,MESSAGGIO,TT,SS", dove le virgole fanno parte
;               del messaggio e le virgolette no: NN è il codice dell'errore,
;               MESSAGGIO una stringa descrittiva, TT e SS di norma la traccia e
;               il settore in cui è avvenuto l'errore (in alcuni casi hanno un
;               altro significato). Senza errori il messaggio è "00,OK,00,00". I
;               tre numeri hanno due cifre e si restituiscono in binario, da 0 a
;               99. Il messaggio non viene alterato e non supera i 40 caratteri:
;               la ricerca della virgola che precede TT si ferma alla
;               quarantesima posizione.
;
;               Il controllo del formato è minimo: la decodifica si ferma al
;               primo carattere diverso da quello previsto e in quel caso .A, .X
;               e .Y sono indefiniti. Il flag di Carry dice solo se il messaggio
;               è stato decodificato, non se il disco ha segnalato un errore:
;               per saperlo il chiamante guarda .A (0 = nessun errore).
;
; Input:
;   - STACK (fino a 40 byte, RAM) : Messaggio di stato terminato da $00
;
; Output:
;   - .A (1 byte, CPU)            : Codice dell'errore (NN)
;   - .X (1 byte, CPU)            : Primo numero dopo il messaggio (TT)
;   - .Y (1 byte, CPU)            : Secondo numero dopo il messaggio (SS)
;   - Flag Carry (1 bit, .P)      : 0 = messaggio decodificato; 1 = formato
;                                   non valido
;
; Variazione Stack (.S):
;   - Stabile
;
; Registri Modificati:  .A, .X, .Y, .P (Negative, oVerflow, Zero, Carry)
; Dipendenze Esterne:   <c64/symbols.asm>
; ==============================================================================
!if (__USE_DECODE_DISK_STATUS = 1) {
  !zone Decode_Disk_Status

    .MAX_LENGTH         = 40            ; Lunghezza massima del messaggio

    DECODE_DISK_STATUS:
      ldy #0

      jsr .Get_Number                   ; Legge il codice dell'errore (NN).
      bcs .Exit_DECODE_DISK_STATUS_Bad_Format

      sta ._ERROR_CODE

      lda STACK,y                       ; Dopo NN ci deve essere una virgola.
      iny

      cmp #$2C
      bne .Exit_DECODE_DISK_STATUS_Bad_Format

    ; Salta il messaggio fino alla virgola.
    .Loop_Skip_Message:
      lda STACK,y                       ; REPEAT
      beq .Exit_DECODE_DISK_STATUS_Bad_Format

      iny
      cpy #.MAX_LENGTH
      bcs .Exit_DECODE_DISK_STATUS_Bad_Format

    .Loop_Check_Message:
      cmp #$2C
      bne .Loop_Skip_Message            ; REPEAT UNTIL: il carattere è una virgola

      jsr .Get_Number                   ; Legge TT.
      bcs .Exit_DECODE_DISK_STATUS_Bad_Format

      sta ._TRACK

      lda STACK,y                       ; Dopo TT ci deve essere una virgola.
      iny

      cmp #$2C
      bne .Exit_DECODE_DISK_STATUS_Bad_Format

      jsr .Get_Number                   ; Legge SS.
      bcs .Exit_DECODE_DISK_STATUS_Bad_Format

      ldx STACK,y                       ; Dopo SS ci deve essere la fine del messaggio.
      bne .Exit_DECODE_DISK_STATUS_Bad_Format

      tay                               ; .Y = SS.
      ldx ._TRACK                       ; .X = TT.
      lda ._ERROR_CODE                  ; .A = NN.
      clc

    .Exit_DECODE_DISK_STATUS:
      rts

    .Exit_DECODE_DISK_STATUS_Bad_Format:
      sec
      rts

    ; Converte in binario due cifre decimali lette da STACK,y.
    .Get_Number:
      lda STACK,y
      iny
      sec

      sbc #$30                          ; Sottrae il codice della cifra "0".
      cmp #10
      bcs .Exit_DECODE_DISK_STATUS_Get_Number

      tax                               ; .X = decine.

      lda STACK,y
      iny
      sec

      sbc #$30
      cmp #10
      bcs .Exit_DECODE_DISK_STATUS_Get_Number

      cpx #0
      beq .Number_Valid

    ; Aggiunge 10 per ogni decina.
    .Loop_Add_Tens:
      clc                               ; REPEAT
      adc #10

    .Loop_Check_Tens:
      dex
      bne .Loop_Add_Tens                ; REPEAT UNTIL: le decine sono finite

    .Number_Valid:
      clc                               ; Segnala che le due cifre sono valide.

    .Exit_DECODE_DISK_STATUS_Get_Number:
      rts

      ._ERROR_CODE      !byte 0
      ._TRACK           !byte 0

  !zone
}

; ==============================================================================
; SUBROUTINE: DISK_DIRECTORY
; ------------------------------------------------------------------------------
; Descrizione:  Stampa la directory del disco dell'unità indicata, una voce per
;               linea: la lunghezza in blocchi, uno spazio e il nome. Apre un
;               canale dati (file logico 88, indirizzo secondario 0), legge la
;               directory come un programma e stampa ogni linea con __PUTCHAR.
;
;               I file da elencare si scelgono con un pattern: una stringa
;               terminata da $00 puntata da INDEX (per esempio "$0"). La
;               subroutine ne calcola la lunghezza e lo passa al sistema
;               operativo dell'unità senza altri controlli: un pattern nullo o
;               più lungo di 40 caratteri è un errore, e la subroutine esce
;               subito con il Carry a 1 senza stampare nulla. Un pattern non
;               valido per l'unità produce invece un errore dell'unità, trattato
;               come ogni altro.
;
;               Il flag di Carry è l'esito: se si verifica un errore dell'unità
;               la subroutine va a capo, stampa il messaggio di stato dell'unità
;               (letto con DISK_STATUS) ed esce con il Carry a 1. La stampa dei
;               numeri e del messaggio usa LINPRT e STROUT del BASIC, quindi il
;               contenuto di FAC non è garantito.
;
;               Richiede __USE_DISK_STATUS = 1.
;
; Input:
;   - .A (1 byte, CPU)             : Numero dell'unità disco
;   - INDEX (2 byte, ZP)           : Puntatore al pattern, terminato da $00
;
; Output:
;   - Flag Carry (1 bit, .P)       : 0 = directory stampata; 1 = pattern errato
;                                    o errore dell'unità
;
; Variazione Stack (.S):
;   - Stabile
;
; Registri Modificati:  .A, .X, .Y, .P (Negative, oVerflow, Zero, Carry), FAC,
;                       STACK (fino a 256 byte)
; Dipendenze Esterne:   <c64/kernal.asm>
;                       <c64/symbols.asm>
; ==============================================================================
!if (__USE_DISK_DIRECTORY = 1) {
  !zone Disk_Directory

    .MAX_PATTERN_LENGTH = 40            ; Lunghezza massima del pattern

    DISK_DIRECTORY:
      tax                               ; Copia il numero dell'unità in .X.
      lda #88                           ; Numero del file logico.
      ldy #0                            ; Indirizzo secondario: canale dati.
      jsr SETLFS

      ; Calcola la lunghezza del pattern puntato da INDEX, escluso
      ; lo $00 finale.
      ldy #0

    .Loop_Measure_Pattern:
      lda (INDEX),y                     ; REPEAT
      beq .Break_Measure_Pattern

      iny

    .Loop_Check_Pattern:
      cpy #.MAX_PATTERN_LENGTH+1
      bcc .Loop_Measure_Pattern         ; REPEAT UNTIL: il pattern è troppo lungo

    .Break_Measure_Pattern:
      tya                               ; .A = lunghezza del pattern.
      beq .Exit_DISK_DIRECTORY_Bad_Pattern

      cmp #.MAX_PATTERN_LENGTH+1
      bcs .Exit_DISK_DIRECTORY_Bad_Pattern

      ldx INDEX
      ldy INDEX+1
      jsr SETNAM

      jsr OPEN                          ; Apre il canale dati.
      bcs .Exit_DISK_DIRECTORY_Error    ; Se ci sono errori stampa lo stato ed esce.

      ldx #88                           ; L'input proverrà dal file logico 88.
      jsr CHKIN

      ; Scarta i primi due byte: contengono l'indirizzo al quale
      ; caricare la directory come se fosse un programma.
      jsr CHRIN
      jsr CHRIN

      jmp .Loop_Check_Line              ; WHILE

    .Loop_Print_Line:
      lda #$0D                          ; Va a capo prima di ogni linea.
      jsr __PUTCHAR

      ; Legge i due byte della lunghezza in blocchi (prima il byte
      ; basso) e li stampa.
      jsr CHRIN
      tax
      jsr CHRIN
      jsr LINPRT

      lda #$20                          ; Stampa uno spazio separatore.
      jsr __PUTCHAR

      jmp .Loop_Check_Char              ; WHILE

    .Loop_Print_Char:
      jsr __PUTCHAR

    .Loop_Check_Char:
      jsr READST
      bne .Exit_DISK_DIRECTORY_Error

      jsr CHRIN

      cmp #0
      bne .Loop_Print_Char              ; WHILE DO: il carattere non è 0

    .Loop_Check_Line:
      jsr READST
      bne .Exit_DISK_DIRECTORY_Error

      ; Legge i due byte del collegamento alla linea successiva: se
      ; entrambi valgono 0 la directory è finita.
      jsr CHRIN
      tay
      jsr CHRIN

      cmp #0
      bne .Loop_Print_Line              ; WHILE DO: il byte alto non è 0

      cpy #0
      bne .Loop_Print_Line              ; WHILE DO: il byte basso non è 0

      clc                               ; Segnala il successo
      bcc .Exit_DISK_DIRECTORY          ; e salta la stampa dell'errore.

    .Exit_DISK_DIRECTORY_Error:
      lda #$0D                          ; Va a capo
      jsr __PUTCHAR
      lda FA                            ; e legge il messaggio di stato.
      jsr DISK_STATUS
      bcs .Exit_DISK_DIRECTORY          ; Se non si legge, non stampa nulla.

      lda #<STACK
      ldy #>STACK
      jsr STROUT                        ; Stampa il messaggio di stato.

      sec                               ; Segnala l'errore.

    .Exit_DISK_DIRECTORY:
      php                               ; Salva il Carry: 0 = successo, 1 = errore.
      lda #88                           ; Chiude il file logico 88
      jsr CLOSE
      jsr CLRCHN                        ; e resetta i canali di I/O.
      plp                               ; Ripristina il Carry.
      rts

    .Exit_DISK_DIRECTORY_Bad_Pattern:
      sec                               ; Segnala l'errore: pattern errato.
      rts

  !zone
}
