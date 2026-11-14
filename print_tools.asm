; ==============================================================================
; FILE:           print_tools.asm
; PROGETTO:       Libreria di Sistema (system.c64)
; TARGET:         ACME Assembler / MOS 6510 (Commodore 64)
; DESCRIZIONE:    Utilità per la stampa di caratteri, messaggi e tabelle di
;                 messaggi con supporto per il modo a Colore di Sfondo Esteso.
; CONTENUTO:      m_At            Posiziona il cursore sullo schermo
;                 PLOT_CHAR       Memorizza un carattere nella memoria schermo
;                 COLOR_CHAR      Cambia il colore di un carattere
;                 PRINT_MSG       Stampa una tabella di messaggi
;                 PRINT_NTH       Stampa un messaggio estratto da una tabella
;                 PRINT_RAW       Stampa un messaggio puntato da .A / .Y
;                 PRINT_IMM       Stampa il messaggio che segue la chiamata
;                 m_Put_ECM_Char  Invia un carattere gestendo il modo ECM
; DIPENDENZE:     <system/vic_ii_tools.asm>
; REQUISITI ZP:   __BG_COL
; ==============================================================================

; ******************************************************************************
; NOTE D'USO
; ******************************************************************************
;
; NOTA #01
; --------
; Le subroutine PRINT_MSG e PRINT_NTH lavorano su elenchi di messaggi
; organizzati in tavole. Ciascun messaggio è organizzato nel seguente formato:
;
;   !text <riga>, <colonna>, "messaggio", $00
;
; <riga> e <colonna> sono due byte che indicano la posizione sullo schermo
; alla quale andrà stampato il messaggio.
;
; Se <riga> == $FF e <colonna> != $FF il messaggio è stampato alla posizione
; corrente del cursore.
;
; Se <riga> == $FF e <colonna> == $FF la tavola è terminata.
;
;
; NOTA #02
; --------
; Le subroutine PRINT_* possono essere personalizzate con una propria subroutine
; di stampa modificando il valore del punto di configurazione __PUT_CHAR.
;
; Esempio 1: Driver di stampa in modo ECM.
;
; __PUT_CHAR:
;   +m_Put_ECM_Char               ; Stampa il carattere in modo ECM
;
; .Exit___PUT_CHAR:
;   rts
;
; Esempio 2: Driver di stampa in modo ECM a doppia spaziatura.
;
; __PUT_CHAR:
;   +m_Put_ECM_Char               ; Stampa il carattere in modo ECM
;   lda #$1D                      ; Codice PETSCII per spostare il cursore
;                                 ; a destra di una posizione
;   jsr CHROUT
;
; .Exit___PUT_CHAR:
;   rts
;
; Esempio 3: Driver di stampa in verticale.
;
; __PUT_CHAR:
;   jsr CHROUT                    ; Stampa il carattere
;
;   lda #$11                      ; Codice PETSCII per spostare il cursore
;                                 ; in basso di una posizione
;   jsr CHROUT
;   lda #$9D                      ; Codice PETSCII per spostare il cursore
;                                 ; a sinistra di una posizione
;   jsr CHROUT
;
; .Exit___PUT_CHAR:
;   rts
;
;
; NOTA #03
; --------
; Esempio di messaggio che utilizza i codici ECM_BG[0-3]:
;
;   !text $FF, $00, ECM_BG0, "Hello, ", ECM_BG1, "world!", ECM_BG0, $00
;
; L'ultimo ECM_BG0 serve a ripristinare il colore di sfondo iniziale
; altrimenti eventuali messaggi seguenti sarebbero stampati con il colore di
; sfondo ECM_BG1.
; ******************************************************************************

; PROVA TEMPORANEA: once sospeso (LIB-01).
; !source "vic_ii_tools.asm", once

; ==============================================================================
; MACRO: m_At
; ------------------------------------------------------------------------------
; Descrizione:  Posiziona il cursore sulla riga e sulla colonna specificata
;               dello schermo corrente, usando la chiamata PLOT del Kernal.
;
; Input:
;   - .row_ (1 byte, Macro) : Riga (0-24)
;   - .col_ (1 byte, Macro) : Colonna (0-39)
;
; Output:
;   - Nessuno
;
; Variazione Stack (.S):
;   - Stabile
;
; Registri Modificati:  .A, .X, .Y, .P (Negative, oVerflow, Zero, Carry)
; Dipendenze Esterne:   <c64/kernal.asm>
; ==============================================================================
!macro m_At .row_, .col_ {
    clc
    ldx #.row_
    ldy #.col_
    jsr PLOT
}

; ==============================================================================
; SUBROUTINE: PLOT_CHAR
; ------------------------------------------------------------------------------
; Descrizione:  Scrive un carattere sullo schermo alla riga e colonna
;               specificate e supporta in modo trasparente il modo Colore di
;               Sfondo Esteso. Se questo modo è attivo il codice Schermo del
;               carattere è automaticamente riportato all'intervallo 0-63 e
;               viene scritto utilizzando il registro colore che è codificato
;               in __BG_COL:
;                 __BG_COL = 0: Usa il colore memorizzato in BGCOL0
;                 __BG_COL = 1: Usa il colore memorizzato in BGCOL1
;                 __BG_COL = 2: Usa il colore memorizzato in BGCOL2
;                 __BG_COL = 3: Usa il colore memorizzato in BGCOL3
;               Richiede __USE_COMPUTE_CELL_ADDRESS = 1.
;
; Input:
;   - .A (1 byte, CPU)      : Codice Schermo del carattere
;   - .X (1 byte, CPU)      : Colonna della cella (0-39)
;   - .Y (1 byte, CPU)      : Riga della cella (0-24)
;   - __BG_COL (1 byte, ZP) : Selettore del registro di sfondo (0-3),
;                             solo in ECM
;
; Output:
;   - Cella (1 byte, RAM)   : Cella dello schermo alla riga e colonna indicate
;
; Variazione Stack (.S):
;   - Stabile
;
; Registri Modificati:  .P (Negative, oVerflow, Zero, Carry), INDEX2
; Dipendenze Esterne:   <c64/symbols.asm>
;                       <chip/vic_ii.asm>
;                       <system/standard.asm>
;                       <system/vic_ii_tools.asm>
; ==============================================================================
!if (__USE_PLOT_CHAR = 1) {
  !zone Plot_Char

    PLOT_CHAR:
      sta ._TEMPA
      +m_Push_AXY

      bit SCROLY                    ; Controlla se il modo Colore di Sfondo Esteso (ECM) è attivo
      bvc .Write_Char               ; e se non lo è vai direttamente al calcolo della cella.

      lda __BG_COL                  ; Trasforma il valore di __BG_COL in una maschera
      ror a                         ; di bit, spostandone il valore nei bit #6 e #7.
      ror a
      ror a
      and #%11000000
      sta ._ECM_MASK

      lda ._TEMPA                   ; Riprendi il codice Schermo dalla cella temporanea
      and #%00111111                ; cancella i 2 bit più significativi
      ora ._ECM_MASK                ; ed applica i bit di selezione del registro di colore.
      sta ._TEMPA

    .Write_Char:
      lda HIBASE                    ; Calcola la cella indicata da .X e .Y
      jsr COMPUTE_CELL_ADDRESS      ; a partire dalla base della memoria schermo,
      lda ._TEMPA                   ; poi recupera il valore del codice Schermo
      ldy #0                        ; e scrivilo in memoria alla posizione calcolata.
      sta (INDEX2),y
      +m_Pull_AXY

    .Exit_PLOT_CHAR:
      rts

    ._ECM_MASK:
      !byte 0

    ._TEMPA:
      !byte 0

  !zone
}

; ==============================================================================
; SUBROUTINE: COLOR_CHAR
; ------------------------------------------------------------------------------
; Descrizione:  Imposta il colore di primo piano del carattere localizzato alla
;               colonna ed alla riga specificati.
;               Richiede __USE_COMPUTE_CELL_ADDRESS = 1.
;
; Input:
;   - .A (1 byte, CPU)    : Codice del colore (0-15)
;   - .X (1 byte, CPU)    : Colonna della cella (0-39)
;   - .Y (1 byte, CPU)    : Riga della cella (0-24)
;
; Output:
;   - Cella (1 byte, RAM) : Cella della memoria colore indicata da .X e .Y
;
; Variazione Stack (.S):
;   - Stabile
;
; Registri Modificati:  .P (Negative, oVerflow, Zero, Carry), INDEX2
; Dipendenze Esterne:   <c64/symbols.asm>
;                       <system/standard.asm>
;                       <system/vic_ii_tools.asm>
; ==============================================================================
!if (__USE_COLOR_CHAR = 1) {
  !zone Color_Char

    COLOR_CHAR:
      sta ._TEMPA
      +m_Push_AXY

      lda #>COLRAM                  ; Calcola la cella indicata da .X e .Y
      jsr COMPUTE_CELL_ADDRESS      ; a partire dalla base della memoria colore,
      lda ._TEMPA                   ; poi recupera il valore del codice colore
      ldy #0                        ; e scrivilo in memoria alla posizione calcolata.
      sta (INDEX2),y
      +m_Pull_AXY

    .Exit_COLOR_CHAR:
      rts

    ._TEMPA:
      !byte 0

  !zone
}

; ==============================================================================
; SUBROUTINE: PRINT_MSG
; ------------------------------------------------------------------------------
; Descrizione:  PRINT_MSG percorre attraverso chiamate successive una tavola di
;               messaggi [NOTA #01]. L'indirizzo iniziale della tavola è dato da
;               un puntatore in ZP e l'indirizzo del puntatore è fornito in .A:
;               alla prima chiamata viene stampato il primo messaggio: in caso
;               di successo il flag di Carry è uguale a zero ed il puntatore in
;               ZP incrementato all'inizio del messaggio successivo. Il
;               raggiungimento della fine della tavola è segnalato da Carry = 1:
;               successive chiamate non avranno effetto finché il puntatore non
;               viene reinizializzato all'indirizzo iniziale della tavola.
;
; Input:
;   - .A (1 byte, CPU)       : Indirizzo in ZP del puntatore alla tavola
;   - Puntatore (2 byte, ZP) : Indirizzo del prossimo messaggio da stampare
;
; Output:
;   - Puntatore (2 byte, ZP) : Messaggio successivo o marcatore di fine tavola
;   - Flag Carry (1 bit, .P) : 0 = messaggio stampato; 1 = tavola terminata
;
; Variazione Stack (.S):
;   - Stabile
;
; Registri Modificati:  .A, .X, .Y, .P (Negative, oVerflow, Zero, Carry),
;                       puntatore in ZP
; Dipendenze Esterne:   <c64/kernal.asm>
;                       <system/standard.asm>
; ==============================================================================
!if (__USE_PRINT_MSG = 1) {
  !zone Print_Msg

    PRINT_MSG:
      ; ****************************************************************
      ; * TO-DO: B15 - dipendenza dai registri di __PUT_CHAR.          *
      ; *                                                              *
      ; * Dopo ogni jsr __PUT_CHAR la subroutine si aspetta che il     *
      ; * registro .X sia invariato. CHROUT lo preserva, ma una        *
      ; * subroutine di stampa personalizzata no, e in quel caso il    *
      ; * puntatore in ZP, indicizzato con .X, verrebbe letto e        *
      ; * scritto nella locazione sbagliata.                           *
      ; *                                                              *
      ; * Da correggere: salvare .X in una cella temporanea prima di   *
      ; * ogni jsr __PUT_CHAR e ripristinarlo dopo, senza imporre      *
      ; * condizioni a __PUT_CHAR.                                     *
      ; ****************************************************************

      tax                           ; Trasferisci l'indirizzo del puntatore in .X.

      lda ($00,x)                   ; Carica il primo byte
      pha                           ; e salvalo sullo stack.

      cmp #$FF                      ; Se è diverso da $FF allora è una coordinata.
      bne .Else_Coord

      inc $00,x                     ; Esamina il byte successivo:
      bne .No_Carry_Marker

      inc $01,x

    .No_Carry_Marker:
      lda ($00,x)
      cmp #$FF                      ; è il marcatore di fine messaggio?
      bne .Else_Print_Chars         ; No, allora stampa i caratteri che seguono nella posizione
                                    ; corrente del cursore.

    .Clear_Stack:
      pla                           ; Pulisci lo stack e riporta il puntatore all'inizio del
      lda $00,x                     ; marcatore di fine tabella così che successive chiamate alla
                                    ; subroutine non abbiano effetto.
      bne .No_Borrow_Pointer

      dec $01,x

    .No_Borrow_Pointer:
      dec $00,x

    .Exit_PRINT_MSG_End_Table:
      sec                           ; Setta C per segnalare la fine della tabella.
      rts

    .Else_Coord:
      inc $00,x                     ; Recupera il byte con il numero di colonna alla quale muovere
                                    ; il cursore.
      bne .No_Carry_Column

      inc $01,x

    .No_Carry_Column:
      stx ._TEMPX                   ; Salva .X.
      lda ($00,x)
      tay                           ; Il valore appena letto è la colonna dove muovere il cursore.
      pla                           ; Recupera la riga dallo stack
      tax

      clc                           ; e posiziona il cursore.
      jsr PLOT

      ldx ._TEMPX                   ; Ora recupera .X
      +m_Skip1                      ; e salta la prossima istruzione.

    .Else_Print_Chars:
      pla                           ; Pulisci lo stack.

      jmp .Loop_Check_Char          ; WHILE

    .Loop_Print_Char:
      jsr __PUT_CHAR                ; Stampa il carattere.

    .Loop_Check_Char:
      inc $00,x                     ; Punta al carattere da stampare.
      bne .No_Carry_Char

      inc $01,x

    .No_Carry_Char:
      lda ($00,x)
      bne .Loop_Print_Char          ; WHILE DO: il carattere non vale $00

      inc $00,x
      bne .Exit_PRINT_MSG

      inc $01,x

    .Exit_PRINT_MSG:
      clc                           ; Pulisci C per indicare che ci sono ancora messaggi
                                    ; in tabella.
      rts

    ._TEMPX:
      !byte 0

  !zone
}

; ==============================================================================
; SUBROUTINE: PRINT_NTH
; ------------------------------------------------------------------------------
; Descrizione:  PRINT_NTH stampa un messaggio singolo estraendolo da una tavola
;               di messaggi [NOTA #01]. L'indirizzo iniziale della tavola è dato
;               da un puntatore in ZP e l'indirizzo del puntatore è fornito in
;               .A mentre il numero d'ordine del messaggio è fornito in .Y (il
;               primo messaggio ha indice 0).
;               Richiede __USE_PRINT_MSG = 1.
;
; Input:
;   - .A (1 byte, CPU)       : Indirizzo in ZP del puntatore alla tavola
;   - .Y (1 byte, CPU)       : Indice del messaggio (0 = il primo)
;   - Puntatore (2 byte, ZP) : Indirizzo iniziale della tavola
;
; Output:
;   - Flag Carry (1 bit, .P) : 0 = messaggio stampato; 1 = indice oltre la fine
;
; Variazione Stack (.S):
;   - Stabile
;
; Registri Modificati:  .A, .X, .Y, .P (Negative, oVerflow, Zero, Carry)
; Dipendenze Esterne:   <system/standard.asm>
; ==============================================================================
!if (__USE_PRINT_NTH = 1) {
  !zone Print_Nth

    PRINT_NTH:
      ; ****************************************************************
      ; * TO-DO: B15 - vedi il TO-DO di PRINT_MSG.                     *
      ; *                                                              *
      ; * PRINT_NTH dipende dalla stessa condizione in modo indiretto: *
      ; * dopo jsr PRINT_MSG ripristina il puntatore con sta 1,x e sta *
      ; * 0,x e quindi si aspetta .X invariato, cosa che PRINT_MSG     *
      ; * garantisce solo se __PUT_CHAR preserva .X.                   *
      ; *                                                              *
      ; * Si risolve correggendo PRINT_MSG.                            *
      ; ****************************************************************

      tax                           ; Sposta l'indirizzo del puntatore in .X
      lda $00,x                     ; e salva l'indirizzo puntato sullo stack.
      pha
      lda $01,x
      pha

      cpy #0                        ; Se .Y vale 0 stampa subito ed esci.
      beq .Print

    .Loop_Scan_Table:
      ; Salta un messaggio della tavola: leggi il primo byte e
      ; incrementa il puntatore al byte precedente il corpo
      ; del messaggio.

      lda ($00,x)                   ; FOR (Corpo)
      inc $00,x
      bne .Check_2nd_Byte

      inc $01,x

    .Check_2nd_Byte:
      and ($00,x)                   ; Fai AND con il secondo byte:
      cmp #$FF                      ; se il risultato è $FF vuol dire che entrambi erano $FF
      beq .Exit_PRINT_NTH_Too_Large ; quindi siamo alla fine della tabella: esci con C=1 per
                                    ; segnalare l'errore.

    .Loop_Scan_Null:
      ; Porta il puntatore al primo carattere del messaggio vero e
      ; proprio e continua a leggere caratteri finché non trovi
      ; uno 0.

      inc $00,x                     ; REPEAT
      bne .Loop_Check_Null

      inc $01,x

    .Loop_Check_Null:
      lda ($00,x)
      bne .Loop_Scan_Null           ; REPEAT UNTIL: il carattere letto vale 0

      inc $00,x                     ; Una volta trovato lo 0, posiziona il puntatore all'inizio
                                    ; del messaggio successivo.
      bne .Next_Scan_Table

      inc $01,x

    .Next_Scan_Table:
      dey                           ; NEXT: decrementa il contatore dei messaggi
      bne .Loop_Scan_Table          ; NEXT: ripete finché .Y non vale 0

    .Print:
      txa                           ; Sposta l'indirizzo del puntatore in .A
      jsr PRINT_MSG                 ; poi stampa il messaggio ed esci.
      +m_Skip1

    .Exit_PRINT_NTH_Too_Large:
      sec

    .Exit_PRINT_NTH:
      pla                           ; Ripristina il contenuto originario del puntatore.
      sta $01,x
      pla
      sta $00,x

      rts

  !zone
}

; ==============================================================================
; SUBROUTINE: PRINT_RAW
; ------------------------------------------------------------------------------
; Descrizione:  La subroutine PRINT_RAW stampa una stringa di testo il cui
;               indirizzo è puntato da .YA: è pensata come sostituto della
;               subroutine di sistema STROUT in quanto non altera il contenuto
;               di FAC o ARG. Per mantenere la compatibilità con STROUT questa è
;               l'unica subroutine di stampa che non supporta i due byte di
;               posizionamento sullo schermo che precedono il messaggio.
;
; Input:
;   - .A (1 byte, CPU)  : Byte basso dell'indirizzo della stringa
;   - .Y (1 byte, CPU)  : Byte alto dell'indirizzo della stringa
;
; Output:
;   - Nessuno
;
; Variazione Stack (.S):
;   - Stabile
;
; Registri Modificati:  .A, .Y, .P (Negative, oVerflow, Zero, Carry), INDEX2
; Dipendenze Esterne:   <c64/symbols.asm>
;                       <mem/mem16.asm>
; ==============================================================================
!if (__USE_PRINT_RAW = 1) {
  !zone Print_Raw

    PRINT_RAW:
      ; ****************************************************************
      ; * TO-DO: B15 - dipendenza dai registri di __PUT_CHAR.          *
      ; *                                                              *
      ; * Dopo ogni jsr __PUT_CHAR la subroutine si aspetta che il     *
      ; * registro .Y sia invariato. CHROUT lo preserva, ma una        *
      ; * subroutine di stampa personalizzata no, e in quel caso       *
      ; * l'indice del loop, che vale 0, verrebbe alterato e lda       *
      ; * (INDEX2),y leggerebbe il carattere sbagliato.                *
      ; *                                                              *
      ; * Da correggere: azzerare .Y con ldy #0 prima di ogni lettura, *
      ; * o salvarlo prima del jsr __PUT_CHAR, senza imporre           *
      ; * condizioni a __PUT_CHAR.                                     *
      ; ****************************************************************

      sta INDEX2                    ; Inizializza il puntatore al messaggio.
      sty INDEX2+1

      ldy #0

      jmp .Loop_Check_Char          ; WHILE

    .Loop_Print_Char:
      jsr __PUT_CHAR                ; Stampa il carattere
      +m_Inc16 INDEX2               ; e passa al successivo.

    .Loop_Check_Char:
      lda (INDEX2),y                ; Carica il prossimo carattere da stampare in .A.
      bne .Loop_Print_Char          ; WHILE DO: il carattere non vale $00

    .Exit_PRINT_RAW:
      rts

  !zone
}

; ==============================================================================
; SUBROUTINE: PRINT_IMM
; ------------------------------------------------------------------------------
; Descrizione:  La subroutine PRINT_IMM stampa un messaggio (formattato come un
;               elemento di una tavola di messaggi [NOTA #01]) inserito nel
;               codice sorgente immediatamente dopo la sua chiamata:
;                 jsr PRINT_IMM
;                 !text $FF, $00, "Hello, world!", $0D, $00
;
; Input:
;   - Messaggio (n byte, RAM) : Dati dopo la chiamata (vedi [NOTA #01])
;
; Output:
;   - Nessuno
;
; Variazione Stack (.S):
;   - Stabile
;
; Registri Modificati:  .A, .X, .Y, .P (Negative, oVerflow, Zero, Carry), INDEX2
; Dipendenze Esterne:   <c64/kernal.asm>
;                       <c64/symbols.asm>
;                       <mem/mem16.asm>
;                       <system/branch.asm>
; ==============================================================================
!if (__USE_PRINT_IMM = 1) {
  !zone Print_Imm

    PRINT_IMM:
      ; ****************************************************************
      ; * TO-DO: B15 - dipendenza dai registri di __PUT_CHAR.          *
      ; *                                                              *
      ; * Dopo ogni jsr __PUT_CHAR la subroutine si aspetta che il     *
      ; * registro .Y sia invariato. CHROUT lo preserva, ma una        *
      ; * subroutine di stampa personalizzata no, e in quel caso       *
      ; * l'indice del loop, che vale 0, verrebbe alterato e lda       *
      ; * (INDEX2),y leggerebbe il carattere sbagliato.                *
      ; *                                                              *
      ; * Da correggere: azzerare .Y con ldy #0 prima di ogni lettura, *
      ; * o salvarlo prima del jsr __PUT_CHAR, senza imporre           *
      ; * condizioni a __PUT_CHAR.                                     *
      ; ****************************************************************

      pla                           ; Rimuovi l'indirizzo di ritorno dallo stack e memorizzalo
                                    ; in INDEX2.
      sta INDEX2
      pla
      sta INDEX2+1

      ldy #0
      +m_Inc16 INDEX2               ; Recupera la riga alla quale posizionare il cursore.

      lda (INDEX2),y
      cmp #$FF                      ; È il marcatore di "posizione attuale"?
      bne .Else_Coord               ; No, estrai le coordinate

      +m_Inc16 INDEX2               ; altrimenti scarta il byte successivo.
      +m_Bra .Print_Char

    .Else_Coord:
      pha
      iny                           ; Recupera anche la colonna.
      lda (INDEX2),y
      tay
      pla                           ; Sposta il valore della riga in .X
      tax
      clc                           ; e posiziona il cursore alle coordinate indicate.
      jsr PLOT
      +m_Inc16 INDEX2

    .Print_Char:
      ldy #0

      jmp .Loop_Check_Char          ; WHILE

    .Loop_Print_Char:
      jsr __PUT_CHAR

    .Loop_Check_Char:
      +m_Inc16 INDEX2
      lda (INDEX2),y
      bne .Loop_Print_Char          ; WHILE DO: il carattere non è 0

    .Exit_PRINT_IMM:
      lda INDEX2+1                  ; Rimetti l'indirizzo di ritorno sullo stack ed esci.
      pha
      lda INDEX2
      pha

      rts

  !zone
}

; ==============================================================================
; MACRO: m_Put_ECM_Char
; ------------------------------------------------------------------------------
; Descrizione:  Questa macro non è pensata per essere usata a sé stante, ma come
;               mattone da costruzione per un proprio driver di stampa da
;               utilizzare nel punto di configurazione __PUT_CHAR [NOTA #02]:
;               infatti la macro non termina con un RTS ma con un salto alla
;               fine del suo codice in modo da poter essere concatenata con
;               altre istruzioni [NOTA #02]. Nello specifico questa macro
;               implementa la logica per stampare a schermo un carattere PETSCII
;               in modo ECM con il colore di sfondo desiderato. La macro si
;               aspetta in .A il codice PETSCII del carattere da stampare e
;               restituisce .A, .X e .Y invariati.
;
;               I codici di controllo (0-31 e 128-159) sono trattati così: 0,
;               18 ({RVS} ON) e 146 ({RVS} OFF) sono ignorati, perché il modo
;               reverse è deciso da __BG_COL; quattro codici PETSCII non
;               utilizzati dal sistema operativo (1-4) sono reinterpretati come
;               codici di controllo che, come gli altri, hanno effetto fino al
;               loro cambiamento: essi sono ECM_BG[0-3] e selezionano il
;               registro del VIC-II contenente il colore di sfondo da
;               utilizzare, senza stampare nulla [NOTA #03]; tutti gli altri
;               sono inviati a CHROUT senza modifiche.
;
;               Gli altri codici PETSCII sono stampabili. Il codice è
;               normalizzato, cioè portato nell'intervallo 32-95 in cui il modo
;               ECM ha i suoi glifi, sostituendo i 3 bit più significativi
;               secondo la tabella .NORM_TABLE (con la macro m_Apply_Table di
;               <io/chars.asm>). Non è una transcodifica nel senso di
;               <io/chars.asm>, che conserva il glifo: in modo ECM il VIC-II
;               ignora i due bit più significativi del codice Schermo, quindi
;               la normalizzazione dà il codice il cui glifo è quello che
;               l'hardware mostrerebbe comunque. Per esempio il pigreco (255) è
;               stampato come la freccia in su: il suo codice 255 diventa 94, e
;               questo caso, che la tabella non copre, è trattato a parte con
;               la macro m_Scan_Exceptions. Poi il bit #0 di __BG_COL è copiato
;               nel bit #7 del codice normalizzato e il bit #1 di __BG_COL
;               decide il modo reverse (RVS = 0 normale, 1 inverso); il codice
;               è infine inviato a CHROUT. __BG_COL non cambia.
;
; Input:
;   - .A (1 byte, CPU)      : Codice PETSCII da stampare
;   - __BG_COL (1 byte, ZP) : Selettore del colore di sfondo (0-3)
;
; Output:
;   - __BG_COL (1 byte, ZP) : Nuovo selettore (se il codice è ECM_BG[0-3])
;   - RVS (1 byte, ZP)      : Modo reverse (bit #1 di __BG_COL), se il codice è
;                             stampabile
;
; Variazione Stack (.S):
;   - Stabile
;
; Registri Modificati:  .P (Negative, oVerflow, Zero, Carry), __BG_COL, RVS
; Dipendenze Esterne:   <c64/kernal.asm>
;                       <c64/symbols.asm>
;                       <io/chars.asm>
;                       <system/branch.asm>
; ==============================================================================
!macro m_Put_ECM_Char {
  !zone Put_ECM_Char

    .TABLE_SIZE     = .EXCEPTIONS_END-.EXCEPTIONS

      sta ._TEMPA                   ; Preserva il contenuto dei registri.
      stx ._TEMPX
      sty ._TEMPY

      tax                           ; Salva una copia del codice PETSCII originale.
      and #%01100000                ; Se i bit #6 e #5 non sono entrambi a zero il codice
      bne .Else_Printable           ; non è di controllo: passa alla stampa.

      txa                           ; Codice di controllo: se è 0 oppure {RVS} ON (18)
      beq .Exit_M_PUT_ECM_CHAR      ; oppure {RVS} OFF (146) esci senza stampare.

      cmp #$12
      beq .Exit_M_PUT_ECM_CHAR

      cmp #$92
      beq .Exit_M_PUT_ECM_CHAR

      cmp #$05                      ; Se non è un codice di cambio del colore di sfondo
      bcs .Output                   ; (1-4) stampalo ed esci.

      dex                           ; Altrimenti convertilo in 0-3,
      stx __BG_COL                  ; salvalo in __BG_COL
      jmp .Exit_M_PUT_ECM_CHAR      ; e finisci senza stampare.

    .Else_Printable:
      txa                           ; Codice stampabile: recupera il codice originale.

      ; Se il codice è un'eccezione (255) .A contiene già il codice
      ; normalizzato e la macro salta a .Apply_BGCOL.
      +m_Scan_Exceptions .EXCEPTIONS, .TABLE_SIZE, .Apply_BGCOL

      +m_Apply_Table .NORM_TABLE    ; Altrimenti sostituisce i 3 bit più significativi.

    .Apply_BGCOL:
      tax                           ; Salva il codice normalizzato.
      lda __BG_COL                  ; Il bit #0 di __BG_COL va nel Carry e il bit #1
      lsr a                         ; diventa il bit #0 di .A, cioè il modo reverse
      and #%00000001                ; (0 = normale, 1 = inverso).
      sta RVS

      txa                           ; Recupera il codice normalizzato. Se il bit #0 di
      bcc .Output                   ; __BG_COL è 0 stampalo così com'è, altrimenti

      ora #%10000000                ; setta il bit #7 prima di stamparlo.

    .Output:
      jsr CHROUT

    .Exit_M_PUT_ECM_CHAR:
      lda ._TEMPA                   ; Ripristina il contenuto dei registri.
      ldx ._TEMPX
      ldy ._TEMPY

      +m_Bra .Skip_Table            ; Salta oltre la tabella dei dati al codice che segue la
                                    ; macro: in tal modo è possibile costruire una subroutine
                                    ; __PUT_CHAR concatenando questa macro con altro codice.

    .EXCEPTIONS:
      !byte $FF, $5E                ; 255 > 94 (in ECM il pigreco appare come freccia in su)

    .EXCEPTIONS_END:

    .NORM_TABLE:
      !byte %00000000               ; 0-31    > 0-31      %000 > %000
      !byte %00100000               ; 32-63   > 32-63     %001 > %001
      !byte %01000000               ; 64-95   > 64-95     %010 > %010
      !byte %01000000               ; 96-127  > 64-95     %011 > %010
      !byte %10000000               ; 128-159 > 128-159   %100 > %100
      !byte %00100000               ; 160-191 > 32-63     %101 > %001
      !byte %01000000               ; 192-223 > 64-95     %110 > %010
      !byte %00100000               ; 224-255 > 32-63     %111 > %001

    ._TEMPA:
      !byte 0

    ._TEMPX:
      !byte 0

    ._TEMPY:
      !byte 0

    .Skip_Table:

  !zone
}
